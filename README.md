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

- 🤖 **AI-powered recommendations** — personalized based on taste analysis via OpenAI API
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
| **AI** | OpenAI API (natural language processing) |
| **Authentication** | Devise + Google OAuth |
| **Containerization** | Docker |
| **Platform** | Railway (Docker + managed PostgreSQL) |
| **Version Control** | Git · GitHub |

---

## 📋 Documentation

- **[Infrastructure & Operations](./INFRASTRUCTURE.md)** — Production architecture on Railway, deployment, security, and operational decisions
- **[Deployment Guide](./DEPLOYMENT.md)** — Step-by-step Railway setup (Postgres, env vars, domain, OAuth)

---

## Architecture Decisions

**Why OpenAI API?**
The recommendation engine needed to understand nuance — not just genre tags, but tone, themes, and emotional register. The OpenAI API allowed natural language processing of user input to extract deeper taste patterns than a traditional filter system could.

**Why Ruby on Rails?**
Rails' convention-over-configuration approach allowed rapid development of a full-stack application with authentication, database management, and API integration within bootcamp constraints — while keeping the codebase organized and maintainable.

**Why Railway?**
Production runs on Railway with a Docker image. Railway handles TLS, health checks, logs, and managed Postgres; deploys are git-driven via `Dockerfile` + `railway.toml`. The app stays portable (`DATABASE_URL`, standard Rails production config) without managing a VPS.

---

## Getting Started (Local Setup)

```bash
# Clone the repository
git clone https://github.com/Jou82/escolhe-ai.git
cd escolhe-ai

# Install dependencies
bundle install

# Set up environment variables
cp .env.example .env
# Add your OpenAI API key and Google OAuth credentials to .env

# Set up database
rails db:create db:migrate db:seed

# Start the server
rails server
```

**Required environment variables:**
OPENAI_API_KEY=your_key_here
GOOGLE_CLIENT_ID=your_id_here
GOOGLE_CLIENT_SECRET=your_secret_here

---

## 👥 Team & Contributions

Escolhe Aí was built collaboratively during Le Wagon's AI Software Development Bootcamp (Jan–Mar 2026).

### 🤖 Joana — AI & Operations

**Bootcamp contributions:**
- OpenAI API integration — connecting the Rails back-end to the OpenAI endpoint
- Prompt engineering — crafting prompts that translate user input into meaningful taste analysis
- Recommendation logic — processing and structuring AI responses into usable recommendations
- Rails ↔ API bridge — the service layer connecting AI to the application

**Post-bootcamp contributions:**
- **Infrastructure** — production on Railway (Docker + managed Postgres)
- **Containerization** — production Dockerfile and `railway.toml` (build, healthcheck, migrate-on-boot)
- **Secrets management** — secure credential handling (env vars, no git exposure)
- **Database operations** — PostgreSQL via `DATABASE_URL`, migrations on deploy, backup playbooks
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
