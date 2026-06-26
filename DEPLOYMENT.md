# Deployment Guide — escolhe-ai.net (Hetzner + Coolify)

## Quick Start

### 1. Infrastructure Setup (One-time)

#### 1.1 Create Hetzner VPS
- Login to [hetzner.com](https://www.hetzner.com/cloud)
- Create new project: "escolhe-ai"
- Create VM:
  - **OS:** Ubuntu 24.04 LTS
  - **Type:** CX22 (2vCPU, 4GB RAM, ~€5.50/month) — good for MVP
  - **Location:** Choose nearest (ex: Helsinki, Frankfurt)
  - **SSH Key:** Add your public key
- **IP Address:** Note the public IP (ex: `195.201.xxx.xxx`)

#### 1.2 Update DNS
- Go to your domain registrar
- Point `escolhe-ai.net` A record to your Hetzner IP
- Point `www.escolhe-ai.net` CNAME to `escolhe-ai.net` (or A record to same IP)
- **Wait 5-10 min** for DNS propagation

#### 1.3 Install Coolify on VPS
```bash
ssh root@195.201.xxx.xxx

# Download & install Coolify
curl -fsSL https://get.coool.app | bash

# Follow the prompts, set admin password
# Coolify will be available at: https://195.201.xxx.xxx:4000
```

#### 1.4 Initial Coolify Setup
1. Access https://195.201.xxx.xxx:4000
2. Login with your password
3. **Settings** → **Domains** → Add `coolify.escolhe-ai.net`
4. Generate SSL certificate (Let's Encrypt)

---

### 2. Repository Connection

#### 2.1 GitHub Personal Access Token
1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Generate new token (Personal access tokens → Tokens classic)
3. **Name:** Coolify Deploy
4. **Scopes:** `repo` (full control) + `admin:repo_hook` (webhooks)
5. **Copy the token** (save somewhere safe)

#### 2.2 Add Repository to Coolify
1. In Coolify dashboard → **Repositories**
2. Click **+ Add**
3. Paste GitHub token
4. Select repo: `Jou82/escolhe-ai`
5. **Connect**

---

### 3. Create Application in Coolify

#### 3.1 New Application
1. **Applications** → **+ New Application**
2. **Name:** `escolhe-ai-prod`
3. **Repository:** Select `Jou82/escolhe-ai`
4. **Branch:** `master`
5. **Dockerfile:** `./Dockerfile`

#### 3.2 Environment Variables
Add these in Coolify UI (**Environment** tab):

```
RAILS_ENV=production
RAILS_MASTER_KEY=<get from config/master.key>
SECRET_KEY_BASE=<run: bundle exec rails secret>

DATABASE_URL=postgresql://escolhe_ai:STRONG_PASSWORD@escolhe_ai_db:5432/escolhe_ai_production

SENDGRID_API_KEY=<your SendGrid API key>

GOOGLE_CLIENT_ID=<your Google OAuth ID>
GOOGLE_CLIENT_SECRET=<your Google OAuth secret>

APP_HOST=escolhe-ai.net
APP_PROTOCOL=https
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
```

**To get RAILS_MASTER_KEY:**
```bash
cat config/master.key
```

**To generate SECRET_KEY_BASE:**
```bash
bundle exec rails secret
```

#### 3.3 Create PostgreSQL Service
1. **Services** → **+ Add Service** → **PostgreSQL**
2. **Name:** `escolhe_ai_db`
3. **Password:** Generate a strong password
4. **Port:** 5432
5. **Database:** `escolhe_ai_production`
6. **Username:** `escolhe_ai`
7. **Save**

---

### 4. Configure Application Ports & Domain

#### 4.1 Port Mapping
1. Application **Ports** tab
2. **Container Port:** 3000
3. **Published Port:** Leave empty (Coolify auto-assigns)

#### 4.2 Domain & SSL
1. Application **Domains** tab
2. Add domain: `escolhe-ai.net`
3. Check **Generate SSL Certificate** (Let's Encrypt)
4. **Save**

#### 4.3 Healthcheck
1. Application **Health** tab
2. **Path:** `/up`
3. **Port:** 3000
4. **Interval:** 30s
5. **Timeout:** 10s
6. **Retries:** 3

---

### 5. Database Migration & Initial Deploy

#### 5.1 Prepare Database
Before first deploy, run migrations:

```bash
# Via Coolify terminal
docker exec escolhe_ai_web bundle exec rails db:migrate
docker exec escolhe_ai_web bundle exec rails db:seed  # If needed
```

Or configure auto-migration in Dockerfile:
```dockerfile
CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}"]
```

#### 5.2 Deploy
1. Coolify dashboard → Application
2. Click **Deploy** button
3. Watch logs (should take 2-5 min)
4. Check status → **Running** ✅

---

### 6. Post-Deployment Checks

#### 6.1 Verify App is Running
```bash
curl https://escolhe-ai.net/up
# Should return: {"status":"ok"}
```

#### 6.2 Check Logs
- Coolify dashboard → **Logs** tab
- Should see Rails startup messages, no errors

#### 6.3 Test Website
- Open https://escolhe-ai.net in browser
- Login with Google OAuth
- Test basic functionality

---

### 7. Backup Configuration

#### 7.1 PostgreSQL Backups (Weekly)
Option A: **Coolify Built-in** (if available)
1. Application **Backups** tab
2. Enable automatic backups
3. Schedule: Weekly (Sunday 2 AM)
4. Retention: 4 weeks

Option B: **Manual Backup Script**
```bash
# SSH into server and add to crontab
# Sunday 2 AM backup
0 2 * * 0 docker exec escolhe_ai_db pg_dump -U escolhe_ai escolhe_ai_production | gzip > /backups/db-$(date +\%Y\%m\%d).sql.gz
```

---

### 8. Email Alerts

#### 8.1 Coolify Monitoring
1. **Settings** → **Monitoring**
2. Enable SMTP alerts
3. Use SendGrid SMTP (already configured in app):
   - **Host:** smtp.sendgrid.net
   - **Port:** 587
   - **User:** `apikey`
   - **Password:** Your SendGrid API key
   - **To email:** joana.jou@gmail.com

#### 8.2 Alert Triggers
- Application down (healthcheck fails 3 times)
- Database connection lost
- Container restart
- Disk space low

---

## Maintenance & Updates

### Deploy Updates
```bash
# After pushing to master branch
git push origin master

# Coolify will auto-detect via webhook and redeploy
# Watch logs in dashboard
```

### Manual Redeploy
- Coolify dashboard → **Deploy** button
- Or: `git push origin master` (triggers webhook)

### Database Migrations
```bash
# SSH into server
docker exec escolhe_ai_web bundle exec rails db:migrate

# Or configure in Dockerfile to auto-migrate on boot (already done)
```

### View Logs
```bash
# Coolify UI: Logs tab (real-time)
# OR SSH:
docker logs -f escolhe_ai_web
docker logs -f escolhe_ai_db
```

### SSH into VPS
```bash
ssh root@195.201.xxx.xxx
docker ps  # View containers
docker exec -it escolhe_ai_web bash  # Shell into Rails app
```

---

## Troubleshooting

### App not starting?
```bash
docker logs escolhe_ai_web
# Check DATABASE_URL, RAILS_MASTER_KEY, RAILS_ENV
```

### Database connection refused?
```bash
docker logs escolhe_ai_db
# Check PostgreSQL is running
docker exec escolhe_ai_db psql -U escolhe_ai -d escolhe_ai_production -c "SELECT 1"
```

### SSL certificate not working?
```bash
# In Coolify: Domains tab → Regenerate certificate
# Or wait for auto-renewal (Let's Encrypt renews 30 days before expiry)
```

### Can't connect to domain?
```bash
# Check DNS propagation
nslookup escolhe-ai.net
dig escolhe-ai.net

# Check Hetzner firewall rules
# Make sure ports 80, 443, 22 are open
```

---

## Cost Estimate (Monthly)

| Service | Cost |
|---------|------|
| Hetzner CX22 VPS | €5.50 |
| Bandwidth | Free (20TB/month included) |
| Let's Encrypt SSL | Free |
| SendGrid (free tier) | Free (100 emails/day) |
| **Total** | **~€5.50/month** |

---

## Resources

- [Coolify Docs](https://coolify.io/docs)
- [Rails Deployment](https://guides.rubyonrails.org/deployment.html)
- [Hetzner Cloud Docs](https://docs.hetzner.cloud)
- [Let's Encrypt](https://letsencrypt.org)
