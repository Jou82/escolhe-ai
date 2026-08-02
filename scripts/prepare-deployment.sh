#!/bin/bash
# Prepare environment variable template for Railway

set -e

echo "escolhe-ai — Railway deployment preparation"
echo "==========================================="
echo ""

if [ ! -f "Gemfile" ]; then
  echo "Error: Must run from Rails root directory"
  exit 1
fi

echo "Running in: $(pwd)"
echo ""

echo "1. RAILS_MASTER_KEY"
if [ -f "config/master.key" ]; then
  MASTER_KEY=$(cat config/master.key)
  echo "   Found in config/master.key"
else
  echo "   config/master.key not found — set RAILS_MASTER_KEY manually in Railway"
  MASTER_KEY=YOUR_RAILS_MASTER_KEY_HERE
fi

echo ""
echo "2. SECRET_KEY_BASE"
if command -v bundle >/dev/null 2>&1; then
  SECRET_KEY_BASE=$(bundle exec rails secret 2>/dev/null || true)
fi
if [ -z "$SECRET_KEY_BASE" ]; then
  SECRET_KEY_BASE=$(openssl rand -hex 64)
  echo "   Generated with openssl"
else
  echo "   Generated with rails secret"
fi

echo ""
echo "3. ENVIRONMENT VARIABLES — paste into Railway → Variables"
echo ""
cat << EOF
RAILS_ENV=production
RAILS_MASTER_KEY=$MASTER_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5

SENDGRID_API_KEY=YOUR_SENDGRID_API_KEY_HERE
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET_HERE

# DATABASE_URL is injected by Railway Postgres — do not hardcode
EOF
echo ""

cat > .env.production.local << EOF
RAILS_ENV=production
RAILS_MASTER_KEY=$MASTER_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
SENDGRID_API_KEY=YOUR_SENDGRID_API_KEY_HERE
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET_HERE
EOF
chmod 600 .env.production.local
echo "Saved reference copy to .env.production.local (git-ignored)"
echo ""
echo "Next: Railway project + Postgres + custom domain — see DEPLOY_RAPIDO.md"
