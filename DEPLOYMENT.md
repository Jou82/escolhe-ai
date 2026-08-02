# Deployment Guide — escolheai.net (Railway)

## Quick Start

### 1. Create the Railway project

1. Go to [railway.app](https://railway.app) and sign in with GitHub
2. **New Project** → **Deploy from GitHub repo** → select `Jou82/escolhe-ai`
3. Railway detects the `Dockerfile` (see `railway.toml` → `builder = "docker"`)

### 2. Add PostgreSQL

1. In the project → **+ New** → **Database** → **PostgreSQL**
2. Railway injects `DATABASE_URL` into the web service automatically
3. Link the Postgres service to the web service if it is not linked yet

### 3. Environment variables

In the web service → **Variables**, set:

```
RAILS_ENV=production
RAILS_MASTER_KEY=<from config/master.key>
SECRET_KEY_BASE=<bundle exec rails secret>
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5

SENDGRID_API_KEY=<SendGrid API key>
GOOGLE_CLIENT_ID=<Google OAuth client id>
GOOGLE_CLIENT_SECRET=<Google OAuth client secret>
OPENAI_API_KEY=<or Anthropic key used by the app>
CLOUDINARY_URL=<if using Cloudinary>

# Optional — defaults to escolheai.net in production.rb
# APP_HOST=escolheai.net
# APP_PROTOCOL=https
```

`DATABASE_URL` is provided by the Railway Postgres plugin — do not hardcode it.

**RAILS_MASTER_KEY:**
```bash
cat config/master.key
```

**SECRET_KEY_BASE:**
```bash
bundle exec rails secret
```

### 4. Custom domain + DNS

1. Railway service → **Settings** → **Networking** → **Custom Domain**
2. Add `escolheai.net` and `www.escolheai.net`
3. At your DNS provider:
   - `escolheai.net` → CNAME/A as shown by Railway
   - `www.escolheai.net` → CNAME to the Railway target
4. Wait for DNS + Let's Encrypt provisioning

### 5. Google OAuth redirect URIs

In [Google Cloud Console](https://console.cloud.google.com/) → OAuth client, add:

```
https://escolheai.net/users/auth/google_oauth2/callback
https://www.escolheai.net/users/auth/google_oauth2/callback
```

(Also keep the Railway preview URL callback if you test on `*.up.railway.app`.)

### 6. Deploy

- Push to the connected branch (usually `master`) — Railway rebuilds automatically
- Or click **Deploy** in the Railway dashboard

On boot, `railway.toml` runs:

```
bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}
```

Health check: `GET /up` (timeout 120s).

---

## How it works

```
Browser
  ↓ HTTPS (Railway edge / Let's Encrypt)
Railway Proxy (SSL termination)
  ↓ HTTP + X-Forwarded-* headers
Web container (Puma on $PORT)
  ↓ DATABASE_URL
Railway PostgreSQL
```

Rails uses `config.assume_ssl = true` and excludes `/up` from HTTPS redirects so Railway's internal health probes succeed.

---

## Config files

| File | Role |
|------|------|
| `railway.toml` | Docker builder, start command, healthcheck, restart policy |
| `Dockerfile` | Ruby 3.3.5 image, Node for assets, `assets:precompile`, migrate + Puma |
| `config/environments/production.rb` | `assume_ssl`, `force_ssl`, hosts, mailer |

---

## Migrations & one-off tasks

```bash
# Via Railway CLI
railway run bundle exec rails db:migrate
railway run bundle exec rails db:seed
railway run bundle exec rails console
```

Or use **Railway dashboard → service → shell**.

---

## Logs & rollback

- **Logs:** Railway dashboard → service → **Deployments** / **Logs**
- **Rollback:** Redeploy a previous successful deployment from the Deployments list

---

## Checklist after cutover from Hetzner/Kamal

- [ ] Postgres provisioned and `DATABASE_URL` linked
- [ ] All secrets set in Railway Variables
- [ ] Domain DNS pointed to Railway
- [ ] SSL active on custom domain
- [ ] Google OAuth callbacks updated
- [ ] Smoke test: home, login, recommendations, email
- [ ] Data migrated from Hetzner Postgres if keeping existing users (`pg_dump` / `pg_restore`)
- [ ] Old Hetzner VPS / Kamal stack decommissioned when stable

---

## Cost (approximate)

| Item | Notes |
|------|--------|
| Railway Hobby / Pro | Usage-based compute + Postgres |
| Custom domain + SSL | Included |

Compare with previous Hetzner VPS (~€6–7/month fixed) — Railway trades fixed VPS cost for managed platform ops.

---

## References

- [Railway Docs](https://docs.railway.app)
- [Railway Docker](https://docs.railway.app/deploy/dockerfiles)
- [Rails on Railway](https://docs.railway.app/guides/rails)
