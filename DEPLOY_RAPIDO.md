# Deploy Rápido — escolheai.net na Railway

## Pré-requisitos

- [x] Conta [Railway](https://railway.app) (login com GitHub)
- [x] Repo `Jou82/escolhe-ai` acessível
- [x] Valores de `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, SendGrid, Google OAuth, API keys

## Passos

### 1. Projeto + repo

1. Railway → **New Project** → **Deploy from GitHub** → `escolhe-ai`
2. Confirme build via Docker (`railway.toml` já define `builder = "DOCKERFILE"`)

### 2. Postgres

1. **+ New** → **Database** → **PostgreSQL**
2. Garanta que o serviço web recebe `DATABASE_URL` (Reference Variable)

### 3. Variáveis

No serviço web → **Variables** (ou rode `bash scripts/prepare-deployment.sh`):

```
RAILS_ENV=production
RAILS_MASTER_KEY=...
SECRET_KEY_BASE=...
RAILS_LOG_TO_STDOUT=true
SENDGRID_API_KEY=...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
# + demais API keys do app
```

### 4. Domínio

1. **Settings** → **Networking** → custom domains: `escolheai.net`, `www.escolheai.net`
2. Aponte DNS conforme o painel Railway
3. Atualize callbacks OAuth no Google Cloud Console

### 5. Deploy

Push em `master` ou **Deploy** no dashboard. Healthcheck: `/up`.

## Comandos úteis

```bash
railway logs
railway run bundle exec rails console
railway run bundle exec rails db:migrate
```

## Docs

- [DEPLOYMENT.md](./DEPLOYMENT.md)
- [INFRASTRUCTURE.md](./INFRASTRUCTURE.md)
