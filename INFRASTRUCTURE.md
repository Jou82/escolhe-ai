# Infrastructure & Deployment

## Overview

EscolheAi is deployed on a **Hetzner VPS** using **Kamal 2** for containerized deployment and orchestration. This document describes the production architecture, deployment process, and operational decisions.

### Why Hetzner + Kamal?

**Cost:** Migrating from Heroku reduced infrastructure costs by ~60% (~€80/month → ~€30/month) while maintaining reliability and adding operational control.

**Control:** Kamal enables infrastructure-as-code deployment with zero-downtime updates and instant rollback capabilities, crucial for a solo developer managing production systems.

**Scale:** For a medium-traffic Rails app (film recommendations + OAuth), a 4GB VPS with containerized workloads offers excellent price/performance.

---

## Production Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| **Compute** | Hetzner VPS (FSN1) | 4GB RAM, Ubuntu 24.04, IP 188.245.192.222 |
| **Framework** | Rails 8.1.3 | Ruby 3.3.5, Puma 7.2.0 |
| **Database** | PostgreSQL 16 | Docker container on same VPS; user `app` (port 5432 internally, 5433 on host) |
| **Orchestration** | Kamal 2 | Manages container build, registry, deploy, health checks, reverse proxy |
| **Reverse Proxy** | Traefik (via kamal-proxy) | Handles SSL (Let's Encrypt), routing, health checks |
| **Registry** | Docker Hub | Image storage: `jou82/escolhe_ai` |
| **External APIs** | TMDB, Google OAuth, SendGrid, Cloudinary | All API keys stored as env vars (never in git) |

---

## Deployment Architecture

```
User Browser
    ↓ HTTPS
Traefik/kamal-proxy (ports 80/443)
    ↓
Container: escolhe_ai-web (Puma on port 3000)
    ↓
Container: escolhe_ai-db (PostgreSQL port 5432)
```

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
- **Accessories:** PostgreSQL container as a managed accessory
- **Env vars:** Rails secrets, API keys pulled from `.kamal/secrets`
- **Healthcheck:** GET `/up` on port 3000, 30s timeout

**Key principle:** All credentials are env vars, never hardcoded.

### `.kamal/secrets`

This file references environment variables, **never contains raw values:**

```
RAILS_MASTER_KEY=$(cat config/master.key)
GOOGLE_CLIENT_ID=$(grep GOOGLE_CLIENT_ID .env.production.local | cut -d '=' -f2)
GOOGLE_CLIENT_SECRET=$(grep GOOGLE_CLIENT_SECRET .env.production.local | cut -d '=' -f2)
DOCKERHUB_PASSWORD=$DOCKERHUB_PASSWORD
DATABASE_URL=$DATABASE_URL
SECRET_KEY_BASE=$SECRET_KEY_BASE
CLOUDINARY_URL=$CLOUDINARY_URL
```

The actual values live in the deploy machine's environment (read from a secure `.env` file, not committed to git).

### Secrets Management

**On the deploy machine (your laptop or CI server):**
- `.env` file (git-ignored) contains actual API keys, database credentials, etc.
- `DOCKERHUB_PASSWORD`, `DATABASE_URL`, `SECRET_KEY_BASE` are sourced from `.env` at deploy time
- Kamal reads `.kamal/secrets`, interpolates env vars, and injects them into containers

**In production containers:**
- Env vars are mounted as Docker environment variables
- Rails reads them directly (e.g., `ENV['SECRET_KEY_BASE']`)
- At no point are secrets written to disk or git

**Credential rotation:**
- Rotate in place: update `.env`, run `kamal deploy`
- No secrets are committed; even in git history, only reference patterns like `$DATABASE_URL` appear

---

## Key Operational Decisions

### Why PostgreSQL in Docker on the same VPS?

**Pros:**
- Simpler than managing separate Postgres installation
- Volumes can be backed up as part of VPS snapshots
- All infrastructure in one place, single SSH access point

**Cons:**
- Single point of failure (no separate DB server)
- Requires careful backup strategy

**For a solo project:** Acceptable. In production, backups are automated (script in cron or CI).

### Why Traefik (via kamal-proxy)?

Kamal bundles Traefik as the reverse proxy. Benefits:
- **SSL termination:** Automatic Let's Encrypt cert provisioning
- **Health checks:** Routes only to healthy containers
- **Zero-downtime:** Gracefully drains connections during deploys
- **Simple routing:** Single entry point for all traffic

### Database Connection String

**Production:** `postgresql://app:PASSWORD@host.docker.internal:5433/escolhe_ai_production`

- User: `app` (created by Postgres initialization in Docker)
- Host: `host.docker.internal` — special Docker name that resolves to the VPS host from inside a container
- Port: 5433 on host → 5432 inside container (mapped in Kamal accessories)

---

## Deployment Process

### Prerequisites

1. Ensure all changes are committed to `master`
2. Local `.env` file with production secrets (never committed)
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
# Verify Postgres is running
docker exec -it escolhe_ai-db psql -U app -d escolhe_ai_production -c "SELECT 1"
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
docker exec -it escolhe_ai-db psql -U app -d escolhe_ai_production -c "\dt"

# Is Traefik routing correctly?
docker logs kamal-proxy --tail 50
```

### Backups

**Database backups** (scheduled via cron or external tool):
```bash
docker exec escolhe_ai-db pg_dump -U app escolhe_ai_production | gzip > /backups/escolhe_ai_$(date +%Y%m%d).sql.gz
```

**Full VPS snapshots:** Use Hetzner's snapshot feature in the console (captures entire filesystem).

---

## Security Considerations

### Credential Management

- **No secrets in git:** `.env` and `.kamal/secrets` values are environment variables, never committed
- **Rotation:** Change a secret → update `.env` → `kamal deploy` → done. Old value is never in a container
- **Audit:** All deploy actions happen via SSH with key-based auth (no password authentication)

### Network

- **SSH only:** VPS access requires private key; no password login
- **Traefik firewall:** Opens only ports 80 and 443 publicly; 3000 and 5432 are internal only
- **HTTPS enforced:** Let's Encrypt cert auto-renewed

### Database

- **User isolation:** Postgres user `app` has minimal privileges (can only access `escolhe_ai_production` DB)
- **Connection limits:** Docker container restricts concurrent connections

---

## Cost Breakdown

| Item | Cost | Notes |
|------|------|-------|
| Hetzner VPS (4GB) | ~€6/month | Includes 40GB disk, bandwidth |
| Domain (escolheai.net) | ~€1/month | Via Namecheap |
| SendGrid (free tier) | €0 | 100 emails/day included |
| Other APIs (TMDB, Cloudinary, Google) | €0 | Free tiers sufficient |
| **Total** | **~€7/month** | ~90% cheaper than Heroku (~€80/month) |

---

## Next Steps / Improvements

- **Automated backups:** Set up daily snapshots to Hetzner Cloud Backup or S3
- **Monitoring:** Deploy Prometheus/Grafana for CPU, memory, database metrics
- **CI/CD:** Automate `kamal deploy` on git push (GitHub Actions)
- **Separate DB server:** If traffic grows, migrate Postgres to a dedicated VM
- **Caching layer:** Add Redis for session storage and caching if needed

---

## References

- [Kamal Documentation](https://kamal-deploy.org)
- [Hetzner Cloud Console](https://console.hetzner.cloud)
- [Rails Production Checklist](https://guides.rubyonrails.org/configuring.html)
- [Docker Network Best Practices](https://docs.docker.com/network/)
