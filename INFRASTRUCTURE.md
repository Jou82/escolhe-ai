## Overview

EscolheAi runs in production on **Railway**: a Dockerized Rails 8 app with Railway-managed PostgreSQL. This document describes architecture, deployment, and operations.

### Why Railway?

**Managed ops:** Build, TLS, health checks, logs, and Postgres are handled by the platform.

**Git-based deploys:** Push to the connected GitHub branch (or redeploy from the dashboard). `Dockerfile` + `railway.toml` define build and runtime.

**Portable:** Standard Rails production config (`DATABASE_URL`, env secrets) — no host SSH required.

---

## Production Stack

| Component | Technology | Details |
|-----------|-----------|---------|
| **Compute** | Railway service | Docker build from repo root `Dockerfile` |
| **Framework** | Rails 8.1.3 | Ruby 3.3.5, Puma |
| **Database** | Railway PostgreSQL | Injected as `DATABASE_URL` |
| **Orchestration** | Railway | Build, deploy, healthcheck, restarts |
| **Reverse Proxy / TLS** | Railway edge | SSL termination; Rails `assume_ssl` |
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
2. Railway builds the Docker image (`railway.toml` → `builder = "DOCKERFILE"`)
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
builder = "DOCKERFILE"
dockerfilePath = "Dockerfile"

[deploy]
preDeployCommand = ["bundle exec rails db:migrate"]
startCommand = "bundle exec rails server -b 0.0.0.0"
healthcheckPath = "/up"
healthcheckTimeout = 120
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

### `Dockerfile`

- Base: `ruby:3.3.5`
- Installs Node 20 (asset precompile) + `postgresql-client`
- `SECRET_KEY_BASE_DUMMY=1` during `assets:precompile` (no master.key in image)
- Default CMD boots Puma; migrations run via Railway `preDeployCommand`

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

### SSL / hosts

- `config.assume_ssl = true` — Railway terminates TLS
- `force_ssl = true` with `/up` excluded from redirect
- Hosts allow `escolheai.net`, `www.escolheai.net`, and `*.up.railway.app`

---

## Database

- Production uses `ENV["DATABASE_URL"]` (`config/database.yml`)
- Solid Cache / Queue / Cable share the same primary URL unless split later
- Backups: use Railway Postgres backup/export; take a `pg_dump` before risky changes

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

## Security

- No secrets in git (`.env*` gitignored; Docker build excludes `.env*` and `master.key`)
- TLS at the edge; secure cookies via `force_ssl`
- Rotate secrets in Railway Variables and redeploy

---

## Future improvements

- Split Solid Queue into a Railway worker service if job volume grows
- Separate Postgres for cache/queue if needed
- GitHub Actions status checks before production promote
- Automated off-site `pg_dump` to object storage

---

## References

- [DEPLOYMENT.md](./DEPLOYMENT.md) — step-by-step Railway setup
- [Railway Docs](https://docs.railway.app)
