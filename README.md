# 🎬 Escolhe Aí

> *Chega de dúvida. O filme certo começa aqui.*

**Escolhe Aí** is an AI-powered movie and series recommendation platform built for the Brazilian streaming market. Tell it 3 productions you love — it returns 3 perfect recommendations, with trailers, cast info, and where to watch in Brazil.

🔗 **Live app:** [www.escolheai.net](https://www.escolheai.net)

---

## The Problem

Decision fatigue on streaming platforms is real. With hundreds of titles across Netflix, Prime Video, Globoplay, HBO Max, and more, choosing what to watch often takes longer than watching it. Escolhe Aí solves this with a simple, personal, and intelligent experience.

---

## How It Works

```
📺 Escolhe Aí
├── 1. You share 3 productions that moved you (any genre, era, or country)
├── 2. The algorithm analyzes themes, aesthetics, and emotion
└── 3. You get 3 tailored recommendations + trailer + cast + where to watch
```

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
| Back-end | Ruby on Rails 8 |
| Database | PostgreSQL + SQL |
| Front-end | JavaScript · HTML · SCSS · Bootstrap |
| AI | OpenAI API (natural language processing) |
| Authentication | Devise + Google OAuth |
| Containerization | Docker |
| Deployment | Heroku |
| Version Control | Git · GitHub |

---

## Architecture Decisions

**Why OpenAI API?**
The recommendation engine needed to understand nuance — not just genre tags, but tone, themes, and emotional register. The OpenAI API allowed natural language processing of user input to extract deeper taste patterns than a traditional filter system could.

**Why Ruby on Rails?**
Rails' convention-over-configuration approach allowed rapid development of a full-stack application with authentication, database management, and API integration within bootcamp constraints — while keeping the codebase organized and maintainable.

**Why Heroku for deployment?**
Heroku's seamless integration with Rails and simple CI/CD pipeline allowed the team to focus on building features rather than infrastructure, making it the practical choice for a bootcamp project with a tight timeline.

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
```
OPENAI_API_KEY=your_key_here
GOOGLE_CLIENT_ID=your_id_here
GOOGLE_CLIENT_SECRET=your_secret_here
```

---

## Roadmap

- [ ] Mood and director filters
- [ ] Personalized watchlist to save and organize recommendations
- [ ] User feedback loop to improve recommendation accuracy
- [ ] Series and novela recommendations (currently focused on films)
- [ ] Multilingual support (English and Spanish)

---

## Team

Escolhe Aí was built collaboratively by a team of four Le Wagon students:

| Name | Role |
|---|---|
| **Joana Dias** | AI integration — OpenAI API, prompt engineering, recommendation logic, Rails ↔ API connection |
| **Paulo Coelho** | — |
| **Douglas Reis** | Platform reliability, user authentication, and visual storytelling — Google OAuth integration, copywriting & content strategy, custom error experience (400, 404, 406, 420, 500), transactional messaging via SendGrid  |
| **Matheus Pereira** | — |

### Joana's Contribution — AI Layer

As the developer responsible for the AI layer, Joana designed and implemented:
- **OpenAI API integration** — connecting the Rails back-end to the OpenAI endpoint
- **Prompt engineering** — crafting the prompts that translate user input (3 productions) into meaningful taste analysis
- **Recommendation logic** — processing, filtering, and structuring the model's responses into usable recommendations
- **Rails ↔ API bridge** — the service layer connecting the AI responses to the rest of the application

- 🔗 [GitHub](https://github.com/Jou82)
- 💼 [LinkedIn](https://linkedin.com/in/joana-dias-57134425)
- 🌐 [Live App](https://www.escolheai.net)

---

## Stats

- 🎬 500+ films recommended
- 😊 98% user satisfaction
- ⚡ 3 inputs → 3 recommendations, instantly

---

*Developed during the AI Software Development Bootcamp at [Le Wagon](https://www.lewagon.com) (Brazil cohort), Jan/2026–March/2026.*

