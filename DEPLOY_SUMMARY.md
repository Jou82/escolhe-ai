# Deploy Summary — Railway

## Status

Production: **Railway** (Docker + managed PostgreSQL).

## What’s in the repo

- `railway.toml` — Docker builder, migrate + Puma, healthcheck `/up`
- `Dockerfile` — Ruby 3.3.5, Node 20, assets precompile, `PORT`-aware server
- `config/environments/production.rb` — `assume_ssl`, SSL exclude for `/up`, hosts Railway
- `scripts/prepare-deployment.sh` — template de Variables para o painel Railway
- Docs: `DEPLOYMENT.md`, `DEPLOY_RAPIDO.md`, `INFRASTRUCTURE.md`, `DEPLOYMENT_CHECKLIST.md`

## Deploy flow

```
GitHub push → Railway Docker build → db:migrate → Puma($PORT) → health /up → live
```

## Env (Railway Variables)

`RAILS_ENV`, `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, `DATABASE_URL` (plugin),
`SENDGRID_API_KEY`, `GOOGLE_CLIENT_*`, app API keys, `RAILS_LOG_TO_STDOUT`.

## Operator steps

1. Create Railway project + Postgres
2. Set variables
3. Custom domain + OAuth callbacks
4. Deploy and verify
