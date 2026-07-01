## Overview

EscolheAi is deployed on a **Hetzner VPS** using **Kamal 2** for containerized deployment and orchestration. This document describes the production architecture, deployment process, and operational decisions.

### Why Hetzner + Kamal?

**Cost:** Migrating from Heroku reduced infrastructure costs by ~61% (~$19/month ≈ €16.68/month → €6.53/month) while maintaining reliability and adding operational control.

**Control:** Kamal enables infrastructure-as-code deployment with zero-downtime updates and instant rollback capabilities, crucial for a solo developer managing production systems.

**Scale:** For a medium-traffic Rails app (film recommendations + OAuth), a 4GB VPS with containerized workloads offers excellent price/performance.

---

## Production Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| **Compute** | Hetzner VPS (FSN1) | 4GB RAM, Ubuntu 26.04, IP 188.245.192.222 |
| **Framework** | Rails 8.1.3 | Ruby 3.3.5, Puma 7.2.0 |
| **Database** | PostgreSQL 16 | Native install on VPS via systemd (not containerized); user `escolheai`, port 5433, db `escolhe_ai_production` |
| **Orchestration** | Kamal 2 | Manages container build, registry, deploy, health checks, reverse proxy |
| **Reverse Proxy** | Traefik (via kamal-proxy) | Handles SSL (Let's Encrypt), routing, health checks |
| **Registry** | Docker Hub | Image storage: `jou82/escolhe_ai` |
| **External APIs** | TMDB, Google OAuth, SendGrid, Cloudinary | All API keys stored as env vars (never in git) |

---

## Deployment Architecture
User Browser
↓ HTTPS
Traefik/kamal-proxy (ports 80/443)
↓
Container: escolhe_ai-web (Puma on port 3000)
↓
PostgreSQL (native systemd service on host, port 5433)
accessed via host.docker.internal:5433

### How Kamal Deploy Works

1. **Local machine:** Run `kamal deploy`
2. **Build phase:** Build Docker image locally, push to Docker Hub
3. **Remote phase:** SSH into Hetzner VPS
   - Pull latest image from Docker Hub
   - Run health check on new container
   - If healthy, swap Traefik routing to new container
   - Remove old container
4. **Result:** Zero-downtime deployment, old container still running until new one is healthy

### Rollback

If a deploy breaks production:
```bash
kamal rollback
```
Instantly reverts to the previous container image.

---

## Configuration

### `config/deploy.yml`

Kamal's main configuration file defines:
- **Registry:** Docker Hub credentials via `DOCKERHUB_PASSWORD` env var
- **Servers:** Single server at `188.245.192.222`
- **Image:** `jou82/escolhe_ai` with Git SHA tag
- **Accessories:** none currently (PostgreSQL runs natively on the host, not as a Kamal accessory)
- **Env vars:** Rails secrets, API keys pulled from `.kamal/secrets`
- **Healthcheck:** GET `/up` on port 3000, 30s timeout
- **SSH user:** not explicitly set (`ssh: user` is commented out), so Kamal connects as `root` by default, using key-based auth

**Key principle:** All credentials are env vars, never hardcoded.

### `.kamal/secrets`

This file references environment variables, **never contains raw values:**
RAILS_MASTER_KEY=$(cat config/master.key)
RAILS_ENV=production
GOOGLE_CLIENT_ID=$(grep GOOGLE_CLIENT_ID .env.production.local | cut -d '=' -f2)
GOOGLE_CLIENT_SECRET=$(grep GOOGLE_CLIENT_SECRET .env.production.local | cut -d '=' -f2)
DOCKERHUB_PASSWORD=$(grep DOCKERHUB_PASSWORD .env.production.local | cut -d '=' -f2)
DATABASE_URL=$(grep DATABASE_URL .env.production.local | cut -d '=' -f2-)
SECRET_KEY_BASE=$(grep SECRET_KEY_BASE .env.production.local | cut -d '=' -f2-)

The actual values live in `.env.production.local` on the deploy machine, which is git-ignored (`.env*` in `.gitignore`) and never committed.

### Secrets Management

**On the deploy machine (your laptop or CI server):**
- `.env.production.local` file (git-ignored) contains actual API keys, database credentials, etc.
- `DOCKERHUB_PASSWORD`, `DATABASE_URL`, `SECRET_KEY_BASE`, `GOOGLE_CLIENT_ID/SECRET` are sourced from `.env.production.local` at deploy time
- Kamal reads `.kamal/secrets`, interpolates env vars, and injects them into containers

**In production containers:**
- Env vars are mounted as Docker environment variables
- Rails reads them directly (e.g., `ENV['SECRET_KEY_BASE']`)
- At no point are secrets written to disk or git

**Credential rotation:**
- Rotate in place: update `.env.production.local`, run `kamal deploy`
- No secrets are committed; even in git history, only reference patterns like `$DATABASE_URL` appear

---

## Key Operational Decisions

### Why PostgreSQL native on the VPS (not Docker)?

**Pros:**
- Direct systemd management, standard Ubuntu tooling for backups/monitoring
- Avoids extra Docker networking layer for the database
- All infrastructure in one place, single SSH access point

**Cons:**
- Single point of failure (no separate DB server)
- Requires careful firewall rules, since the app container must reach the host's Postgres via `host.docker.internal`
- Requires careful backup strategy

**For a solo project:** Acceptable. In production, backups are automated (script in cron or CI).

### Why Traefik (via kamal-proxy)?

Kamal bundles Traefik as the reverse proxy. Benefits:
- **SSL termination:** Automatic Let's Encrypt cert provisioning
- **Health checks:** Routes only to healthy containers
- **Zero-downtime:** Gracefully drains connections during deploys
- **Simple routing:** Single entry point for all traffic

### Database Connection String

**Production:** `postgresql://escolheai:PASSWORD@host.docker.internal:5433/escolhe_ai_production`

- User: `escolheai`
- Host: `host.docker.internal` — special Docker name that resolves to the VPS host from inside a container
- Port: `5433` — PostgreSQL runs natively via systemd on the host, not in a container.

> **Note:** An older Kamal-accessory Postgres container (`escolhe_ai-db`, port 5432) existed as a leftover from an earlier setup. It held stale/outdated data (frozen since 25/06/2026, test user only) and was unrelated to the real production database. It was found publicly exposed to the internet and removed on 01/07/2026 as part of a security audit — see Security Considerations below.

---

## Deployment Process

### Prerequisites

1. Ensure all changes are committed to `master`
2. Local `.env.production.local` file with production secrets (never committed)
3. Docker installed and logged in to Docker Hub
4. SSH key for Hetzner VPS access

### Deploy Command

```bash
cd /var/www/escolhe-ai
kamal deploy
```

What happens:
- Build image locally (with `RAILS_ENV=production`, assets precompiled)
- Push to Docker Hub
- SSH to Hetzner server
- Pull image, start new container, health check
- Swap traffic once healthy
- Stop old container

**Time:** ~3–5 minutes (mostly waiting for image build/push)

### Troubleshooting a Failed Deploy

**Health check timed out:**
```bash
# Check logs of the newly started container
docker logs escolhe_ai-web-<SHA> --tail 50
```

**Database connection error:**
```bash
# Verify Postgres is running (native systemd service)
sudo systemctl status postgresql
psql -U escolheai -d escolhe_ai_production -h localhost -p 5433 -c "SELECT 1"
```

**Can't push to Docker Hub:**
- Verify `DOCKERHUB_PASSWORD` in deploy machine's environment
- Re-authenticate locally: `docker login`

**Rollback to previous version:**
```bash
kamal rollback
```

---

## Monitoring & Maintenance

### Health Checks

Kamal continuously pings `/up` on port 3000. If it fails:
- Old container remains running
- New container is stopped
- Deploy is marked as failed

### Manual Checks

```bash
# Is the container running?
docker ps | grep escolhe_ai-web

# Recent logs?
docker logs escolhe_ai-web-<SHA> --tail 50 --follow

# Is the database accessible?
psql -U escolheai -d escolhe_ai_production -h localhost -p 5433 -c "\dt"

# Is Traefik routing correctly?
docker logs kamal-proxy --tail 50

# Is fail2ban active and are there banned IPs?
sudo fail2ban-client status sshd
```

### Backups

**Database backups** (scheduled via cron or external tool):
```bash
pg_dump -U escolheai -h localhost -p 5433 escolhe_ai_production | gzip > /backups/escolhe_ai_$(date +%Y%m%d).sql.gz
```

**Full VPS snapshots:** Use Hetzner's snapshot feature in the console (captures entire filesystem).

---

## Security Considerations

_Last hardening audit: 01/07/2026_

### SSH Access

- **Operational user:** `joana` — key-based SSH login + sudo (password required for sudo only)
- **Root:** key-based login only (`PermitRootLogin prohibit-password`), no password fallback. Used by Kamal for deploys (`config/deploy.yml` doesn't set `ssh: user`, so it defaults to root)
- **Password authentication:** disabled globally (`PasswordAuthentication no`) — no user can log in with a password, only SSH keys
- **fail2ban:** active on the `sshd` jail — 5 failed attempts within 10 min triggers a 1h ban. Already blocked several brute-force attempts in production.

### Firewall (ufw)

Only these ports are open:
- `22/tcp` (SSH) — any origin
- `80/tcp`, `443/tcp` (HTTP/HTTPS) — any origin
- `5433/tcp` (native PostgreSQL) — restricted to internal Docker subnets only (`172.17.0.0/16`, `172.18.0.0/16`), so the `escolhe_ai-web` container (on the `kamal` network) can reach Postgres via `host.docker.internal`. Not reachable from the public internet.

All other ports (including the old 5432, and leftover local-registry ports 5555/5000) are closed and not listening.

### Credential Management

- **No secrets in git:** `.env.production.local` and `.kamal/secrets` values are environment variables, never committed (`.env*` is in `.gitignore`)
- **Rotation:** Change a secret → update `.env.production.local` → `kamal deploy` → done. Old value is never in a container
- **Audit:** All deploy actions happen via SSH with key-based auth (no password authentication)

### Database

- **User isolation:** Postgres user `escolheai` has minimal privileges (can only access `escolhe_ai_production` DB)
- **Native, not containerized:** runs via systemd directly on the host, port 5433
- **Cleanup:** a stale Kamal-accessory Postgres container (`escolhe_ai-db`, port 5432) — a leftover with outdated/frozen data, unrelated to the real production DB — was found publicly exposed and removed on 01/07/2026. A local development `docker-compose.yml` with a hardcoded password was also found and removed.

### Known follow-ups

- Consider changing the default SSH port (defense in depth, low priority)
- Periodically rotate the production Postgres (5433) credentials
- Review `fail2ban-client status sshd` occasionally for banned IPs

---

## Cost Breakdown

| Item | Cost | Notes |
|------|------|-------|
| Hetzner VPS (4GB) | ~€6/month | Includes 40GB disk, bandwidth |
| Domain (escolheai.net) | ~€1/month | Via Namecheap |
| SendGrid (free tier) | €0 | 100 emails/day included |
| Other APIs (TMDB, Cloudinary, Google) | €0 | Free tiers sufficient |
| **Total** | **€6.53/month** | ~61% cheaper than Heroku ($19/month ≈ €16.68/month) |

---

## Next Steps / Improvements

- **Automated backups:** Set up daily snapshots to Hetzner Cloud Backup or S3
- **Monitoring:** Deploy Prometheus/Grafana for CPU, memory, database metrics
- **CI/CD:** Automate `kamal deploy` on git push (GitHub Actions)
- **Separate DB server:** If traffic grows, migrate Postgres to a dedicated VM
- **Caching layer:** Add Redis for session storage and caching if needed
- **SSH port change:** Consider moving off port 22 (defense in depth, low priority)

---

## References

- [Kamal Documentation](https://kamal-deploy.org)
- [Hetzner Cloud Console](https://console.hetzner.cloud)
- [Rails Production Checklist](https://guides.rubyonrails.org/configuring.html)
- [Docker Network Best Practices](https://docs.docker.com/network/)
