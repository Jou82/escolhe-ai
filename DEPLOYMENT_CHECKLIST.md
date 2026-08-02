# Deployment Checklist — Railway

## Code / config

- [x] `railway.toml` (Docker builder, startCommand, `/up`, timeout 120s)
- [x] `Dockerfile` (Node + assets:precompile com `SECRET_KEY_BASE_DUMMY`)
- [x] `config.assume_ssl = true` + exclude `/up` do redirect SSL
- [x] Production usa `ENV["DATABASE_URL"]`
- [x] Deploy path: Railway only (`railway.toml` + `Dockerfile`)

## Railway project

- [ ] Projeto criado e repo GitHub conectado
- [ ] Branch de deploy correta (`master`)
- [ ] PostgreSQL provisionado e linkado
- [ ] Deploy bem-sucedido (healthcheck verde)

## Environment variables

- [ ] `RAILS_ENV=production`
- [ ] `RAILS_MASTER_KEY`
- [ ] `SECRET_KEY_BASE`
- [ ] `DATABASE_URL` (Railway)
- [ ] `SENDGRID_API_KEY`
- [ ] `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`
- [ ] Demais API keys (AI, Cloudinary, TMDB, …)
- [ ] `RAILS_LOG_TO_STDOUT=true`

## Domain & auth

- [ ] DNS `escolheai.net` / `www` → Railway
- [ ] SSL ativo
- [ ] Google OAuth redirect URIs atualizados
- [ ] Smoke: home, login Google, email, recomendações

## Ops

- [ ] `railway logs` / dashboard logs OK
- [ ] Rollback testado (redeploy de deployment anterior)
- [ ] Documentação alinhada (`DEPLOYMENT.md`, `INFRASTRUCTURE.md`)
