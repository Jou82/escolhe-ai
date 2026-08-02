## Overview

EscolheAi is deployed on **Railway** using a Dockerized Rails 8 app and Railway-managed PostgreSQL. This document describes the production architecture, deployment process, and operational decisions.

### Why Railway?

**Managed ops:** Build, TLS, health checks, logs, and Postgres are handled by the platform — no VPS SSH, Traefik, or Kamal host maintenance.

**Git-based deploys:** Push to the connected GitHub branch (or redeploy from the dashboard). The `Dockerfile` + `railway.toml` define build and runtime.

**Fit:** For a medium-traffic Rails app (recommendations + OAuth + SendGrid), Railway keeps the stack simple while remaining portable (standard Docker + `DATABASE_URL`).

> Previous stack: Heroku → Hetzner VPS + Kamal 2. This migration moves production back to a managed PaaS (Railway) while keeping the same container image approach.

---

## Production Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| **Compute** | Railway service | Docker build from repo root `Dockerfile` |
| **Framework** | Rails 8.1.3 | Ruby 3.3.5, Puma |
| **Database** | Railway PostgreSQL | Injected as `DATABASE_URL` |
| **Orchestration** | Railway | Build, deploy, healthcheck, restarts |
| **Reverse Proxy / TLS** | Railway edge | SSL termination; Rails `assume_ssl` |
| **Registry** | Railway internal | Image built and stored by Railway |
| **External APIs** | TMDB / AI, Google OAuth, SendGrid, Cloudinary | Env vars only (never in git) |

---

## Deployment Architecture

```
User Browser
  ↓ HTTPS
Railway Proxy (ports 80/443, Let's Encrypt)
  ↓ HTTP (SSL terminated)
Container: web (Puma on $PORT)
  ↓ DATABASE_URL
Railway PostgreSQL
```

### How a deploy works

1. Push to the connected GitHub branch (or manual Deploy in Railway)
2. Railway builds the Docker image (`railway.toml` → `builder = "docker"`)
3. New container starts with start command from `railway.toml`:
   - `rails db:migrate`
   - `rails server -b 0.0.0.0 -p $PORT`
4. Health check: `GET /up` (timeout 120s)
5. On success, traffic switches to the new deployment

### Rollback

In Railway → **Deployments** → select a previous successful deploy → redeploy.

---

## Configuration

### `railway.toml`

```toml
[build]
builder = "docker"

[deploy]
startCommand = "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}"
healthcheckPath = "/up"
healthcheckTimeout = 120
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

### `Dockerfile`

- Base: `ruby:3.3.5`
- Installs Node 20 (asset precompile) + `postgresql-client`
- `SECRET_KEY_BASE_DUMMY=1` during `assets:precompile` (no master.key in image)
- Default CMD mirrors the Railway start command (migrate + Puma on `$PORT`)

### Secrets / env vars

Set in Railway → service → **Variables** (never commit):

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Decrypt credentials if used |
| `SECRET_KEY_BASE` | Session / cookie signing |
| `DATABASE_URL` | Auto from Railway Postgres |
| `SENDGRID_API_KEY` | Transactional email |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | OAuth |
| API keys (OpenAI/Anthropic, Cloudinary, TMDB) | App features |
| `RAILS_LOG_TO_STDOUT` | Log drain compatibility |

Local deploy machine may still keep `.env.production.local` (gitignored) for reference; production source of truth is Railway Variables.

### SSL / hosts

- `config.assume_ssl = true` — Railway terminates TLS
- `force_ssl = true` with `/up` excluded from redirect
- Hosts allow `escolheai.net`, `www.escolheai.net`, and `*.up.railway.app`

---

## Database

- Production uses `ENV["DATABASE_URL"]` (`config/database.yml`)
- Solid Cache / Queue / Cable share the same primary URL unless split later
- Backups: use Railway Postgres backup/export features; for major changes take a `pg_dump` before migrate

### Migrating data from Hetzner (one-time)

```bash
# On old host (example)
pg_dump -Fc escolhe_ai_production > escolhe_ai.dump

# Restore into Railway Postgres (DATABASE_URL from Railway)
pg_restore --clean --no-owner -d "$DATABASE_URL" escolhe_ai.dump
```

---

## Operations

### Deploy

```bash
git push origin master
# or: Railway dashboard → Deploy
```

### Console / rake

```bash
railway run bundle exec rails console
railway run bundle exec rails db:migrate
```

### Logs

Railway dashboard → service → Logs (or `railway logs`).

### Health

- Endpoint: `/up`
- Rails silences healthcheck logging via `config.silence_healthcheck_path`

---

## Security Considerations

- No secrets in git (`.env*` gitignored; Docker build excludes `.env*` and `master.key`)
- TLS at the edge; secure cookies via `force_ssl`
- Rotate secrets in Railway Variables and redeploy
- After cutover, shut down the old Hetzner VPS and revoke unused SSH keys / Docker Hub deploy credentials if no longer needed

---

## Cost notes

Railway is usage-based (compute + Postgres + egress). Previous Hetzner+Kamal stack was ~€6.53/month fixed. Prefer Railway when managed deploys and less host ops matter more than minimizing fixed VPS cost.

---

## Future improvements

- Split Solid Queue into a Railway worker service if job volume grows
- Separate Postgres add-ons for cache/queue if needed
- GitHub Actions status checks before production promote
- Automated off-site `pg_dump` to object storage

---

## References

- [DEPLOYMENT.md](./DEPLOYMENT.md) — step-by-step Railway setup
- [Railway Docs](https://docs.railway.app)
- [Kamal](https://kamal-deploy.org) — previous orchestration (retained in repo for reference / emergency)
