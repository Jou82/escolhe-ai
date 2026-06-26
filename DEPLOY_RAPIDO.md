# Deploy Rápido — escolhe-ai.net em Hetzner + Coolify

**Tempo estimado:** 30-45 minutos

## 📋 Pré-requisitos (Você já tem tudo?)

- [x] Conta Hetzner
- [x] Domínio `escolhe-ai.net` registrado
- [x] SendGrid API key
- [x] Google OAuth (Client ID + Secret)
- [x] SSH key configurada no Hetzner

## 🚀 Começar o Deploy

### PASSO 1: Gerar Secrets (Na sua máquina)
```bash
cd /Users/joanadias/code/Jou82/escolhe-ai
bash scripts/prepare-deployment.sh
```
✅ Salva secrets em `.env.production.local`

### PASSO 2: Deploy Automático (Na sua máquina)
```bash
bash scripts/deploy-to-hetzner.sh
```

O script vai:
1. Pedir seus tokens (Hetzner, SendGrid, Google)
2. Criar VPS no Hetzner (CX22 - €5.50/mês)
3. Gerar senha do banco de dados
4. Mostrar instruções do Coolify

### PASSO 3: Instalar Coolify (No VPS)

Após o script, você verá um IP como: `195.201.xxx.xxx`

SSH no servidor:
```bash
ssh root@195.201.xxx.xxx
```

No servidor, rode:
```bash
curl -fsSL https://get.coool.app | bash
```

Aguarde ~5 minutos para Coolify estar pronto.

### PASSO 4: Configurar Coolify (No Dashboard)

Abra: `https://195.201.xxx.xxx:4000`

#### 4.1 Adicionar Repositório
- **Repositories** → **Add**
- GitHub Personal Access Token (crie em: https://github.com/settings/tokens)
  - Escopo: `repo` + `admin:repo_hook`
- Selecione: `Jou82/escolhe-ai`

#### 4.2 Criar PostgreSQL Service
- **Services** → **PostgreSQL**
- Name: `escolhe_ai_db`
- Username: `escolhe_ai`
- Password: (vem do script)
- Database: `escolhe_ai_production`

#### 4.3 Criar Application
- **Applications** → **New Application**
- Name: `escolhe-ai-prod`
- Repository: `Jou82/escolhe-ai`
- Branch: `master`
- Dockerfile: `./Dockerfile`

#### 4.4 Environment Variables
Copie do terminal (saída do script):
```
RAILS_ENV=production
RAILS_MASTER_KEY=...
SECRET_KEY_BASE=...
DATABASE_URL=...
SENDGRID_API_KEY=...
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
APP_HOST=escolhe-ai.net
APP_PROTOCOL=https
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
```

#### 4.5 Domínio + SSL
- **Application** → **Domains**
- Add: `escolhe-ai.net`
- Enable SSL (Let's Encrypt - automático)

#### 4.6 Healthcheck
- **Health**
- Path: `/up`
- Interval: 30s

#### 4.7 Deploy! 🚀
Clique em **Deploy** button
- Aguarde build (2-5 min)
- Veja logs
- Aguarde até status = **Running**

### PASSO 5: Verificar

```bash
# Teste local
curl https://escolhe-ai.net/up
# Deve retornar: {"status":"ok"}

# Abra no browser
open https://escolhe-ai.net
```

Se aparecer a app, você conseguiu! 🎉

---

## 🔧 Se Algo Dar Errado

### Build falhou?
```bash
# SSH no servidor
ssh root@195.201.xxx.xxx

# Ver logs do container
docker logs escolhe_ai_web

# Procura por erros de env vars, migrations, etc
```

### Banco de dados não conecta?
```bash
# Verificar se PostgreSQL está rodando
docker ps | grep postgres

# Testar conexão
docker exec escolhe_ai_db psql -U escolhe_ai -d escolhe_ai_production -c "SELECT 1"
```

### Domínio não funciona?
```bash
# Verificar DNS
nslookup escolhe-ai.net
dig escolhe-ai.net

# Deve mostrar o IP do seu servidor Hetzner
```

### SSL não está funcionando?
- Aguarde 5 minutos para Let's Encrypt processar
- Em Coolify: **Domains** → **Regenerate Certificate**

---

## 📊 O Que Você Tem Agora

```
escolhe-ai.net
    ↓
Hetzner VPS (Ubuntu 24.04, CX22)
    ├─ Coolify (painel de controle)
    ├─ Rails app (container Docker)
    ├─ PostgreSQL (container)
    └─ Nginx + Let's Encrypt (automático)

Custo: €5.50/mês (hosting)
Backups: Weekly (configurar depois em Coolify)
Alerts: Email (configurar depois em Coolify)
```

---

## 📌 Depois (Próximos Passos)

### Configurar Backups (Coolify)
- Backups → Enable
- Schedule: Sunday 2 AM
- Retention: 4 weeks

### Configurar Alerts
- Settings → Monitoring
- SMTP: SendGrid (já configurado na app)
- Email: joana.jou@gmail.com

### Deploy Automático (Via GitHub)
- Coolify criou webhook automático
- Cada `git push` ao `master` dispara deploy automático

---

## 🆘 Precisa de Ajuda?

Se algo ficar preso:

1. **Logs no Coolify:** Dashboard → Logs (real-time)
2. **SSH no servidor:** `ssh root@IP` → ver dockerlogs
3. **Consultando guias:**
   - `DEPLOYMENT.md` - Guia completo
   - `DEPLOYMENT_CHECKLIST.md` - Verificações
   - Coolify docs: https://coolify.io/docs

---

**Pronto? Comece com:**
```bash
bash scripts/deploy-to-hetzner.sh
```

Let's go! 🚀
