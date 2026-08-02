# AGENTS.md

## Cursor Cloud specific instructions

### Product
Rails 8.1 app (**Escolhe Aí**) — movie recommendations (Anthropic + TMDB), Devise auth (email + Google OAuth), PostgreSQL.

### Services
| Service | How to run | Notes |
|---|---|---|
| PostgreSQL 16 | local `pg_ctlcluster` / system Postgres | `config/database.yml` uses `127.0.0.1:5432`, user `escolheai`, DB `escolhe_ai_development`. Trust auth is fine for empty `ESCOLHEAI_DATABASE_PASSWORD`. |
| Rails (Puma) | `bundle exec rails server -b 0.0.0.0 -p 3000` | Dev mode. Health: `GET /up`. |
| Optional APIs | env vars only | `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`, `SENDGRID_API_KEY`, `ANTHROPIC_API_KEY` (or OpenAI if used), `TMDB_API_KEY`, `CLOUDINARY_URL`. |

Standard setup commands live in `README.md` (`bundle install`, `rails db:create db:migrate`, `rails server`). Lint: `bin/rubocop` (prefer scoped paths under `app/`). Tests: `bundle exec rails test` (several scaffold controller tests have stale route helpers and error out).

### Gotchas
- **Google OAuth `client_id` missing in production:** OmniAuth reads `ENV['GOOGLE_CLIENT_ID']` / `ENV['GOOGLE_CLIENT_SECRET']` at boot (`config/initializers/devise.rb`). Cursor Cloud secrets are **not** Railway Variables — set the same keys on the **Railway web service** and **Redeploy**. Empty values produce Google error 400 `Missing required parameter: client_id` (redirect URL contains `client_id&` with no value).
- **Cloudinary required for authenticated UI:** Navbar/profile use `cl_image_tag` / `avatar_url`. Without `CLOUDINARY_URL`, logged-in pages that render the navbar avatar return 500 (`Must supply cloud_name`). Homepage and `/up` still work.
- **Devise `:confirmable`:** new email users need confirmation (or `skip_confirmation!` in console/seeds). Seeds file historically had merge-conflict markers — prefer creating users via console if `db:seed` fails.
- **Mail in development:** without `SENDGRID_API_KEY`, delivery is effectively off (`:test` path); production SMTP expects SendGrid + sender `suporte@escolheai.net`.
- **Pending migrations after pulls:** run `bundle exec rails db:migrate` (e.g. `terms_accepted_at` on users) or the server raises `PendingMigrationError` on requests.
- **Do not commit** `/venv/` or `/vendor/bundle/` (ignored). Ruby is **3.3.5** (see `.ruby-version`).
- **Custom domain vs Railway URL:** Until Namecheap CNAMEs for both `escolheai.net` and `www.escolheai.net` point at the Railway domain target **and** those hostnames are added under the **escolhe-ai** service → Settings → Domains (status **Active** + SSL), use `https://escolhe-ai-production-73c1.up.railway.app`. DNS-only without the Railway domain entry yields `x-railway-fallback: true` / “Application not found”. OmniAuth authorize is **POST** (`/users/auth/google_oauth2`); bare GET 404s.
- **Stale production image:** If production HTML still shows `<<<<<<<` conflict markers, the running deploy is behind current `master` / `deploy/railway` (layout is already clean in git). Redeploy the web service from the connected GitHub branch.
- **Recommendation flow stuck on “Processando…”:** Production Active Job uses Solid Queue. The Puma plugin must run (`SOLID_QUEUE_IN_PUMA=true`, default in `Dockerfile` / production). Also require `TMDB_API_KEY` + `ANTHROPIC_API_KEY`. Processing page polls `/movies/check_status`; failures now surface instead of polling forever. Rate limit is **3 completed searches / 24h** (stuck processing / failed do not count). Processing sessions older than 3 minutes are marked failed so the UI can exit.
- **Host authorization:** production must NOT use `config.hosts << /.*/`. Allow only the real domains + Railway `*.up.railway.app`; exclude `/up` via `host_authorization` so healthchecks keep working.
