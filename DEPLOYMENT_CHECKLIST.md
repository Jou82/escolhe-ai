# Pre-Deployment Checklist — escolhe-ai.net

Use este checklist antes de fazer deploy em produção.

## Before You Deploy

### Local Testing
- [ ] `docker-compose build` — sem erros
- [ ] `docker-compose up` — app inicia normalmente
- [ ] `curl http://localhost:3000/up` — retorna `{"status":"ok"}`
- [ ] `npm run lint` — sem erros
- [ ] `npm run typecheck` — sem erros (se tiver TS)
- [ ] `rails test` — suite passa 100%

### Configuration Review
- [ ] `RAILS_ENV=production` definido
- [ ] `RAILS_MASTER_KEY` está presente e correto
- [ ] `DATABASE_URL` aponta para banco correto
- [ ] `SENDGRID_API_KEY` configurado
- [ ] `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` configurados
- [ ] `SECRET_KEY_BASE` gerado (run: `bundle exec rails secret`)

### Secrets Management
- [ ] `.env.production.local` criado (via `scripts/prepare-deployment.sh`)
- [ ] `.env.production.local` NÃO commitado (verificar `.gitignore`)
- [ ] `config/master.key` NÃO commitado
- [ ] Nenhuma secret em hardcode no código

### Database
- [ ] Migrations testadas localmente
- [ ] `db/schema.rb` é válido
- [ ] ActiveStorage migrations rodadas (se usado)
- [ ] Seeds testadas (se tiver `db/seeds.rb`)

### Assets
- [ ] `rails assets:precompile` sem erros
- [ ] `public/assets/` gerado corretamente
- [ ] CSS/JS funcionando após precompile

### SSL/TLS
- [ ] `config.force_ssl = true` em production.rb
- [ ] `config.assume_ssl = true` em production.rb (Coolify/Nginx)
- [ ] HTTP→HTTPS redirect ativo

---

## Hetzner + Coolify Setup

### Hetzner VPS
- [ ] VPS criado (CX22+, Ubuntu 24.04)
- [ ] SSH key adicionada
- [ ] Firewall: portas 22, 80, 443 abertas
- [ ] DNS apontando para IP Hetzner
- [ ] `ping escolhe-ai.net` resolve corretamente

### Coolify Installation
- [ ] Coolify instalado no VPS
- [ ] Coolify accessible at `https://195.201.xxx.xxx:4000`
- [ ] Admin password criada
- [ ] Domain `coolify.escolhe-ai.net` configurado

### GitHub Connection
- [ ] Personal Access Token criado no GitHub
- [ ] Token com escopos: `repo`, `admin:repo_hook`
- [ ] Token adicionado no Coolify
- [ ] Repositório `Jou82/escolhe-ai` conectado

### Coolify Application
- [ ] Application criada: `escolhe-ai-prod`
- [ ] Repository: `Jou82/escolhe-ai`
- [ ] Branch: `master`
- [ ] Dockerfile path: `./Dockerfile`

### Environment Variables (Coolify UI)
- [ ] `RAILS_ENV=production`
- [ ] `RAILS_MASTER_KEY=<from config/master.key>`
- [ ] `SECRET_KEY_BASE=<generated>`
- [ ] `DATABASE_URL=postgresql://...`
- [ ] `SENDGRID_API_KEY=<your key>`
- [ ] `GOOGLE_CLIENT_ID=<your id>`
- [ ] `GOOGLE_CLIENT_SECRET=<your secret>`
- [ ] `APP_HOST=escolhe-ai.net`
- [ ] `APP_PROTOCOL=https`
- [ ] `RAILS_LOG_TO_STDOUT=true`
- [ ] `RAILS_MAX_THREADS=5`

### PostgreSQL Service (Coolify)
- [ ] Service created: `escolhe_ai_db`
- [ ] Username: `escolhe_ai`
- [ ] Password: Strong password set
- [ ] Database: `escolhe_ai_production`
- [ ] Port: 5432

### Application Configuration
- [ ] Container Port: 3000
- [ ] Domain: `escolhe-ai.net`
- [ ] Domain: `www.escolhe-ai.net` (optional)
- [ ] SSL Certificate: Let's Encrypt enabled
- [ ] Healthcheck path: `/up`
- [ ] Healthcheck interval: 30s
- [ ] Healthcheck timeout: 10s

### First Deploy
- [ ] All env vars saved in Coolify
- [ ] PostgreSQL service running
- [ ] **Deploy button** clicked
- [ ] Build logs showing no errors
- [ ] Container status: **Running**
- [ ] Application logs: No errors

### Post-Deploy Verification
- [ ] `curl https://escolhe-ai.net/up` returns `{"status":"ok"}`
- [ ] `https://escolhe-ai.net` loads in browser
- [ ] Google OAuth login works
- [ ] Database migrations ran successfully
- [ ] No 500 errors in logs
- [ ] SSL certificate valid (check browser 🔒)

---

## Monitoring Setup

### Email Alerts
- [ ] Coolify monitoring enabled
- [ ] SMTP configured with SendGrid
- [ ] Alert email: `joana.jou@gmail.com`
- [ ] Test alert sent and received

### Backup Configuration
- [ ] PostgreSQL backups enabled (Weekly)
- [ ] Backup schedule: Sunday 2 AM
- [ ] Retention: 4 weeks
- [ ] Backup location accessible

### Logging
- [ ] `RAILS_LOG_TO_STDOUT=true` enabled
- [ ] Logs visible in Coolify dashboard
- [ ] No sensitive data in logs

---

## Security Review

### Access Control
- [ ] SSH key-based auth only (no passwords)
- [ ] Coolify admin password strong
- [ ] GitHub token has minimal necessary scopes
- [ ] Database password is strong

### Secrets Management
- [ ] No secrets in git history (`git log --all --source -- '*'`)
- [ ] `.env.production.local` gitignored
- [ ] `config/master.key` never committed
- [ ] SendGrid API key is secret

### Network Security
- [ ] Firewall: only 22, 80, 443 open
- [ ] No public SSH password auth
- [ ] HTTPS enforced (force_ssl = true)
- [ ] HSTS headers enabled

---

## Handoff to Production

Once all checks pass:

1. ✅ Run this entire checklist
2. ✅ Get approval from team lead
3. ✅ Test one more time on staging (if available)
4. ✅ Do the deploy
5. ✅ Monitor logs for 10 minutes
6. ✅ Test basic user flows
7. ✅ Celebrate 🎉

---

## Rollback Plan

If something goes wrong:

```bash
# 1. Stop the application
docker stop escolhe_ai_web

# 2. Check what went wrong
docker logs escolhe_ai_web

# 3. Restore from backup (if needed)
# Contact Coolify support or manual restore

# 4. Deploy previous working version
# Push to old commit or create rollback branch
```

---

## Support Resources

- **Coolify Docs:** https://coolify.io/docs
- **Rails Deployment:** https://guides.rubyonrails.org/deployment.html
- **Hetzner Help:** https://docs.hetzner.cloud
- **Deployment Guide:** See `DEPLOYMENT.md`
