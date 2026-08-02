# 🎬 Escolhe Aí

> *Chega de dúvida. O filme certo começa aqui.*

**Escolhe Aí** is an AI-powered movie and series recommendation platform built for the Brazilian streaming market. Tell it 3 productions you love — it returns 3 perfect recommendations, with trailers, cast info, and where to watch in Brazil.

🔗 **Live app:** [www.escolheai.net](https://www.escolheai.net)

---

## The Problem

Decision fatigue on streaming platforms is real. With hundreds of titles across Netflix, Prime Video, Globoplay, HBO Max, and more, choosing what to watch often takes longer than watching it. Escolhe Aí solves this with a simple, personal, and intelligent experience.

---

## How It Works
📺 Escolhe Aí
├── 1. You share 3 productions that moved you (any genre, era, or country)
├── 2. The algorithm analyzes themes, aesthetics, and emotion
└── 3. You get 3 tailored recommendations + trailer + cast + where to watch

---

## Features

- 🤖 **AI-powered recommendations** — personalized taste analysis (Anthropic) + TMDB metadata
- 🔐 **User authentication** — sign up with email or Google (OAuth)
- 💾 **Save recommendations** — logged-in users can save and revisit picks
- 📺 **Where to watch** — streaming availability in Brazil (Netflix, Prime Video, Globoplay, etc.)
- 🎞️ **Rich content** — trailers, cast, and curated details for each recommendation
- 📱 **Responsive design** — works on desktop and mobile

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Back-end** | Ruby on Rails 8.1.3 |
| **Database** | PostgreSQL 16 |
| **Front-end** | JavaScript · HTML · SCSS · Bootstrap |
| **AI** | Anthropic Claude API (+ TMDB for catalog/streaming) |
| **Authentication** | Devise + Google OAuth |
| **Email** | SendGrid (SMTP) |
| **Media** | Cloudinary |
| **Containerization** | Docker |
| **Platform** | Railway (Docker + managed PostgreSQL) |
| **DNS** | Namecheap → Railway custom domains |
| **Version Control** | Git · GitHub |

---

## 📋 Documentation

- **[Infrastructure & Operations](./INFRASTRUCTURE.md)** — Production architecture on Railway, security, and ops
- **[Deployment Guide](./DEPLOYMENT.md)** — Full Railway checklist (Postgres, env vars, domain, OAuth)
- **[AGENTS.md](./AGENTS.md)** — Notes for cloud/dev agents (ports, env gotchas)

---

## Architecture Decisions

**Why Anthropic + TMDB?**
Recommendations need taste/nuance (Claude) plus Brazilian streaming metadata and posters (TMDB). The Rails service layer orchestrates both.

**Why Ruby on Rails?**
Convention-over-configuration enabled a full-stack app (auth, DB, jobs, mailers) quickly while staying maintainable.

**Why Railway?**
Production is a Dockerized Rails app with Railway-managed Postgres. TLS, health checks, logs, and git deploys come from the platform (`Dockerfile` + `railway.toml`). No VPS/SSH.

---

## Getting Started (Local Setup)

```bash
# Clone the repository
git clone https://github.com/Jou82/escolhe-ai.git
cd escolhe-ai

# Install dependencies (Ruby 3.3.5 — see .ruby-version)
bundle install

# Environment variables (create .env — never commit it)
# See list below

# Database (PostgreSQL on localhost:5432, user escolheai)
rails db:create db:migrate db:seed

# Start the server
rails server
# → http://localhost:3000  ·  health: GET /up
```

**Useful local env vars (`.env`):**

```bash
ANTHROPIC_API_KEY=
TMDB_API_KEY=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
CLOUDINARY_URL=
SENDGRID_API_KEY=          # optional in development
ESCOLHEAI_DATABASE_PASSWORD=  # optional if Postgres uses trust auth
```

---

## Production deploy (Railway)

Production host: **Railway** · custom domain **escolheai.net** / **www.escolheai.net** (DNS on **Namecheap**).

### Stack on Railway

| Piece | How |
|---|---|
| Web | Docker build (`Dockerfile` + `railway.toml`) |
| DB | Railway PostgreSQL plugin |
| Boot | `rails db:migrate` then Puma on `$PORT` (fallback `3000`) |
| Health | `GET /up` |
| TLS | Railway edge (`config.assume_ssl` in production) |

### 1. Services

1. Deploy the GitHub repo as a **web** service (`escolhe-ai`)
2. Add **Postgres** in the same project
3. On the **web** service, set:

```bash
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

Use the **private** URL (`…@postgres.railway.internal:5432/…`).  
Do **not** point production at `localhost` / `host.docker.internal`.  
Do **not** overwrite the Postgres service’s own `DATABASE_URL` (that breaks the plugin URL).

### 2. Variables (on the **web** service)

Set these as **literal** values on `escolhe-ai` (avoid broken Shared refs):

```bash
RAILS_ENV=production
RAILS_MASTER_KEY=          # from config/master.key
SECRET_KEY_BASE=           # bundle exec rails secret
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5

DATABASE_URL=${{Postgres.DATABASE_URL}}

GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
SENDGRID_API_KEY=
ANTHROPIC_API_KEY=
TMDB_API_KEY=
CLOUDINARY_URL=
```

CLI example (link the **web** service first — not Postgres):

```bash
railway service            # select escolhe-ai
railway variables set GOOGLE_CLIENT_ID="….apps.googleusercontent.com"
railway variables set DATABASE_URL='${{Postgres.DATABASE_URL}}'
railway redeploy
```

Verify before relying on a deploy:

```bash
railway run --service escolhe-ai bash -c 'echo ID_LEN=${#GOOGLE_CLIENT_ID}; echo "$DATABASE_URL" | sed "s/:[^@]*@/:***@/"'
# ID_LEN > 0
# host should look like postgres.railway.internal — never @:/railway or host.docker.internal
```

### 3. Custom domain (Railway + Namecheap)

1. Web service → **Settings** → **Networking** → **+ Custom Domain**
2. Add `www.escolheai.net` and `escolheai.net` (target port **3000**, matching Puma)
3. In **Namecheap → Advanced DNS**, use **CNAME** (not the old VPS IP):

| Type | Host | Value |
|---|---|---|
| CNAME | `www` | value from Railway (e.g. `xxxx.up.railway.app`) |
| CNAME | `@` | same Railway target for the apex |
| TXT | `_railway-verify` / `_railway-verify.www` | values Railway shows for ownership |

4. Keep existing **SendGrid** CNAMEs (`em1587`, `s1._domainkey`, `s2._domainkey`) and `_dmarc`
5. Wait until Railway shows domains **Active** and SSL is issued (browser `ERR_CERT_*` is normal until then)

### 4. Google OAuth

In [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → OAuth Web client:

**Authorized redirect URIs**

```
https://escolheai.net/users/auth/google_oauth2/callback
https://www.escolheai.net/users/auth/google_oauth2/callback
https://<your-service>.up.railway.app/users/auth/google_oauth2/callback
```

`GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` must be present on the **web** container (empty `client_id` in the Google URL means the env var never reached that service).

### 5. SendGrid

Changing host (VPS → Railway) does **not** require a new SendGrid “server”. Keep domain auth for `escolheai.net` and set `SENDGRID_API_KEY` on Railway. From address stays `suporte@escolheai.net`; mailer links use `https://escolheai.net`.

### 6. Deploy / smoke test

- Push to the connected branch or **Redeploy** in the dashboard
- Check logs if boot fails (`Database URL cannot be empty` → fix `DATABASE_URL` on **web**)
- Smoke: `/up`, home, Google login, confirmation email, one recommendation

More detail: **[DEPLOYMENT.md](./DEPLOYMENT.md)**.

---

## 👥 Team & Contributions

Escolhe Aí was built collaboratively during Le Wagon's AI Software Development Bootcamp (Jan–Mar 2026).

### 🤖 Joana — AI & Operations

**Bootcamp contributions:**
- AI API integration — connecting the Rails back-end to the recommendation model
- Prompt engineering — crafting prompts that translate user input into meaningful taste analysis
- Recommendation logic — processing and structuring AI responses into usable recommendations
- Rails ↔ API bridge — the service layer connecting AI to the application

**Post-bootcamp contributions:**
- **Infrastructure** — production on Railway (Docker + managed Postgres)
- **Containerization** — production Dockerfile and `railway.toml` (build, healthcheck, migrate-on-boot)
- **Secrets management** — env vars on the web service (Google, SendGrid, AI, TMDB, Cloudinary)
- **Database operations** — `DATABASE_URL` from Railway Postgres (`postgres.railway.internal`)
- **DNS / domain** — Namecheap CNAMEs → Railway custom domains + SSL
- **Deployment reliability** — `/up` health checks, SSL termination-aware Rails config (`assume_ssl`)

**Links:** [GitHub](https://github.com/Jou82) · [LinkedIn](https://linkedin.com/in/joana-dias-57134425)

---

### 🛡️ Douglas — Platform & UX

- Google OAuth integration — seamless third-party authentication
- Copywriting & brand voice — all site messaging and narrative
- Custom error UX — branded error states transforming technical failures into user-friendly moments
- SendGrid integration — transactional email for verification and notifications

**Links:** [GitHub](https://github.com/douglasreis65-bit) · [LinkedIn](https://www.linkedin.com/in/douglas-chagas-r/)

---

### 🎨 Paulo — Front-end & Design

- Full UI/UX design — visual identity (dark cinema aesthetic, palette, typography)
- Devise authentication — user registration, login, password recovery
- Modal system — dynamic auth modals built with Stimulus
- Homepage & components — hero section, search, trending, animations, polish

**Links:** [GitHub](https://github.com/pahdcpc) · [LinkedIn](https://linkedin.com/in/pahdcpc)

---

### 📊 Matheus — Data & Analysis

- Backend optimization
- Database queries & performance

**Links:** [GitHub](https://github.com/matheuspereirafx) · [LinkedIn](https://www.linkedin.com/in/matheus-pereira-8ba75820b/)

---

## Roadmap

- [ ] Filtered recommendations by streaming platform (user preference)
- [ ] "Random selection" button for decision paralysis
- [ ] User feedback loop to improve recommendation accuracy over time
- [ ] Expand input types: Movies, Series, and Soap Operas (currently films only)
- [ ] Recommendation history & trending analysis
- [ ] Multi-language support (Portuguese, Spanish, English)

---

## Stats

- 🎬 500+ films in recommendation database
- 😊 98% user satisfaction (bootcamp cohort feedback)
- ⚡ 3 inputs → 3 recommendations, instant response
- 🚀 Live since March 2026

---

## License

Proprietary — Built for the Brazilian streaming market.

---

*Originally developed during the AI Software Development Bootcamp at [Le Wagon](https://www.lewagon.com) (Brazil cohort, Jan–Mar 2026). Now maintained as a live production application with infrastructure responsibility and operational oversight.*
