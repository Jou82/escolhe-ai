#!/bin/bash
# Prepare deployment environment variables for Hetzner + Coolify

set -e

echo "🚀 escolhe-ai Deployment Preparation"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
  echo "❌ Error: Must run from Rails root directory"
  exit 1
fi

echo "✅ Running in: $(pwd)"
echo ""

# 1. Get RAILS_MASTER_KEY
echo "📝 1. RAILS_MASTER_KEY"
if [ -f "config/master.key" ]; then
  MASTER_KEY=$(cat config/master.key)
  echo "   Found in config/master.key"
else
  echo "   ⚠️  config/master.key not found!"
  exit 1
fi

# 2. Generate SECRET_KEY_BASE
echo ""
echo "🔐 2. SECRET_KEY_BASE"
echo "   Generating new secret..."
SECRET_KEY_BASE=$(bundle exec rails secret 2>/dev/null)

# 3. Display .env template
echo ""
echo "📋 3. ENVIRONMENT VARIABLES TEMPLATE"
echo "   Add these to Coolify (Environment tab):"
echo ""
echo "------- Copy below into Coolify -------"
cat << EOF
RAILS_ENV=production
RAILS_MASTER_KEY=$MASTER_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE

DATABASE_URL=postgresql://escolhe_ai:STRONG_PASSWORD@escolhe_ai_db:5432/escolhe_ai_production

SENDGRID_API_KEY=YOUR_SENDGRID_API_KEY_HERE
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET_HERE

APP_HOST=escolhe-ai.net
APP_PROTOCOL=https
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
EOF
echo "------- End of template -------"
echo ""

# 4. Save to local .env for reference
echo "💾 4. Saving to .env.production.local (for reference)"
cat > .env.production.local << EOF
RAILS_ENV=production
RAILS_MASTER_KEY=$MASTER_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE
DATABASE_URL=postgresql://escolhe_ai:STRONG_PASSWORD@escolhe_ai_db:5432/escolhe_ai_production
SENDGRID_API_KEY=YOUR_SENDGRID_API_KEY_HERE
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID_HERE
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET_HERE
APP_HOST=escolhe-ai.net
APP_PROTOCOL=https
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5
EOF
chmod 600 .env.production.local
echo "   ✅ Saved to .env.production.local (git-ignored)"
echo ""

# 5. Docker compose test
echo "🐳 5. Testing local Docker setup"
echo "   To test locally, run:"
echo "   $ docker-compose build"
echo "   $ docker-compose up"
echo ""

echo "✅ Deployment preparation complete!"
echo ""
echo "📌 Next steps:"
echo "   1. Create Hetzner VPS"
echo "   2. Install Coolify"
echo "   3. Add repo to Coolify"
echo "   4. Configure environment variables (use template above)"
echo "   5. Deploy!"
echo ""
echo "📖 Full guide: see DEPLOYMENT.md"
