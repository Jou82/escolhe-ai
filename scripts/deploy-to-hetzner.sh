#!/bin/bash
# Complete Hetzner + Coolify Deployment Automation
# This script handles everything: VPS, Coolify, App deployment

set -e

echo "🚀 ESCOLHE-AI HETZNER + COOLIFY DEPLOYMENT"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
  echo -e "${RED}❌ Error: Must run from Rails root directory${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Running in: $(pwd)${NC}"
echo ""

# ============= SECTION 1: GATHER CREDENTIALS =============
echo -e "${YELLOW}📋 SECTION 1: Gathering Credentials${NC}"
echo "========================================"
echo ""

echo "We need the following information:"
echo ""

# Hetzner API Token
read -p "🔑 Hetzner API Token (from https://console.hetzner.cloud/): " HETZNER_TOKEN
if [ -z "$HETZNER_TOKEN" ]; then
  echo -e "${RED}❌ Hetzner API token is required${NC}"
  exit 1
fi

# SendGrid API Key
read -p "📧 SendGrid API Key: " SENDGRID_KEY
if [ -z "$SENDGRID_KEY" ]; then
  echo -e "${RED}❌ SendGrid API key is required${NC}"
  exit 1
fi

# Google OAuth Credentials
read -p "🔐 Google OAuth Client ID: " GOOGLE_ID
if [ -z "$GOOGLE_ID" ]; then
  echo -e "${RED}❌ Google OAuth Client ID is required${NC}"
  exit 1
fi

read -p "🔐 Google OAuth Client Secret: " GOOGLE_SECRET
if [ -z "$GOOGLE_SECRET" ]; then
  echo -e "${RED}❌ Google OAuth Client Secret is required${NC}"
  exit 1
fi

# Email for alerts
read -p "📬 Email for alerts (default: joana.jou@gmail.com): " ALERT_EMAIL
ALERT_EMAIL=${ALERT_EMAIL:-joana.jou@gmail.com}

echo ""
echo -e "${GREEN}✅ Credentials gathered${NC}"
echo ""

# ============= SECTION 2: CREATE HETZNER VPS =============
echo -e "${YELLOW}🖥️  SECTION 2: Creating Hetzner VPS${NC}"
echo "========================================"
echo ""

# Check if hcloud CLI is installed
if ! command -v hcloud &> /dev/null; then
  echo -e "${RED}❌ hcloud CLI not found. Installing...${NC}"
  echo "Visit: https://github.com/hetznercloud/cli"
  echo "Or run: brew install hcloud (macOS) / apt install hcloud (Linux)"
  exit 1
fi

echo "Setting up hcloud CLI..."
export HCLOUD_TOKEN="$HETZNER_TOKEN"

# Check if VPS already exists
VPS_NAME="escolhe-ai-prod"
echo "Checking if VPS already exists..."

EXISTING_VPS=$(hcloud server describe $VPS_NAME 2>/dev/null || echo "")

if [ ! -z "$EXISTING_VPS" ]; then
  echo -e "${YELLOW}⚠️  VPS '$VPS_NAME' already exists${NC}"
  read -p "Use existing VPS? (y/n): " USE_EXISTING
  if [ "$USE_EXISTING" != "y" ]; then
    read -p "Delete existing and create new? (y/n): " DELETE_EXISTING
    if [ "$DELETE_EXISTING" = "y" ]; then
      echo "Deleting existing VPS..."
      hcloud server delete $VPS_NAME
    else
      echo "Skipping VPS creation"
      VPS_IP=$(hcloud server ip $VPS_NAME)
    fi
  else
    VPS_IP=$(hcloud server ip $VPS_NAME)
  fi
fi

# Create VPS if needed
if [ -z "$VPS_IP" ]; then
  echo -e "${GREEN}Creating new VPS...${NC}"
  hcloud server create \
    --name "$VPS_NAME" \
    --type cx22 \
    --image ubuntu-24.04 \
    --ssh-key default \
    --automount \
    --network default

  # Get the IP
  VPS_IP=$(hcloud server ip $VPS_NAME)
  echo -e "${GREEN}✅ VPS created with IP: $VPS_IP${NC}"
else
  echo -e "${GREEN}✅ Using existing VPS with IP: $VPS_IP${NC}"
fi

echo ""
echo "⏳ Waiting for VPS to be ready (30 seconds)..."
sleep 30

echo ""

# ============= SECTION 3: INSTALL COOLIFY =============
echo -e "${YELLOW}🐳 SECTION 3: Installing Coolify${NC}"
echo "========================================"
echo ""

echo "SSH into VPS and installing Coolify..."
echo "Command to run:"
echo ""
echo "ssh root@$VPS_IP"
echo ""
echo "Then run:"
echo "curl -fsSL https://get.coool.app | bash"
echo ""
echo "Press ENTER when Coolify is installed and dashboard is accessible"
read

echo ""
echo "Accessing Coolify dashboard at: https://$VPS_IP:4000"
echo ""

# ============= SECTION 4: PREPARE COOLIFY CONFIG =============
echo -e "${YELLOW}⚙️  SECTION 4: Preparing Coolify Configuration${NC}"
echo "========================================"
echo ""

# Get RAILS_MASTER_KEY and SECRET_KEY_BASE from earlier
MASTER_KEY=$(cat config/master.key)
SECRET_KEY=$(cat .env.production.local 2>/dev/null | grep SECRET_KEY_BASE | cut -d= -f2)
if [ -z "$SECRET_KEY" ]; then
  SECRET_KEY=$(bundle exec rails secret 2>/dev/null)
fi

DB_PASSWORD=$(openssl rand -base64 32)

cat > /tmp/coolify-config.txt << EOF
=== COOLIFY CONFIGURATION ===

VPS IP: $VPS_IP
Domain: escolhe-ai.net
Email: $ALERT_EMAIL

=== Environment Variables (copy to Coolify) ===

RAILS_ENV=production
RAILS_MASTER_KEY=$MASTER_KEY
SECRET_KEY_BASE=$SECRET_KEY
DATABASE_URL=postgresql://escolhe_ai:$DB_PASSWORD@escolhe_ai_db:5432/escolhe_ai_production
SENDGRID_API_KEY=$SENDGRID_KEY
GOOGLE_CLIENT_ID=$GOOGLE_ID
GOOGLE_CLIENT_SECRET=$GOOGLE_SECRET
APP_HOST=escolhe-ai.net
APP_PROTOCOL=https
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=5

=== PostgreSQL (create in Coolify) ===

Service Name: escolhe_ai_db
Username: escolhe_ai
Password: $DB_PASSWORD
Database: escolhe_ai_production
Port: 5432

=== Application Config ===

Repository: Jou82/escolhe-ai
Branch: master
Dockerfile: ./Dockerfile
Container Port: 3000
Domain: escolhe-ai.net
Healthcheck Path: /up

EOF

cat /tmp/coolify-config.txt
echo ""
echo -e "${GREEN}✅ Configuration saved to: /tmp/coolify-config.txt${NC}"
echo ""

# ============= SECTION 5: MANUAL COOLIFY SETUP =============
echo -e "${YELLOW}📱 SECTION 5: Manual Coolify Setup${NC}"
echo "========================================"
echo ""

echo "1. Login to Coolify at: https://$VPS_IP:4000"
echo ""
echo "2. Go to 'Repositories' and add:"
echo "   - GitHub Token: (create at https://github.com/settings/tokens)"
echo "   - Repository: Jou82/escolhe-ai"
echo ""
echo "3. Create new Application:"
echo "   - Name: escolhe-ai-prod"
echo "   - Repository: Jou82/escolhe-ai"
echo "   - Branch: master"
echo "   - Dockerfile: ./Dockerfile"
echo ""
echo "4. Create PostgreSQL Service:"
echo "   - Name: escolhe_ai_db"
echo "   - Username: escolhe_ai"
echo "   - Password: (from config above)"
echo "   - Database: escolhe_ai_production"
echo ""
echo "5. Add Environment Variables (copy from config above)"
echo ""
echo "6. Configure Domain:"
echo "   - Domain: escolhe-ai.net"
echo "   - SSL: Let's Encrypt (auto)"
echo ""
echo "7. Click 'Deploy'"
echo ""
echo "8. Monitor logs in Coolify dashboard"
echo ""

read -p "Press ENTER when Deploy is complete and app is running..."

echo ""
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo ""

# ============= SECTION 6: VERIFICATION =============
echo -e "${YELLOW}✅ SECTION 6: Verification${NC}"
echo "========================================"
echo ""

echo "Testing healthcheck..."
HEALTH_RESPONSE=$(curl -s https://escolhe-ai.net/up 2>/dev/null || echo "not ready")

if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
  echo -e "${GREEN}✅ Healthcheck PASSED${NC}"
else
  echo -e "${YELLOW}⚠️  Healthcheck not responding yet (may need more time)${NC}"
fi

echo ""
echo "Visit: https://escolhe-ai.net"
echo ""

# ============= SAVE DEPLOYMENT INFO =============
cat > .deployment-info << EOF
# Deployment Info
export VPS_IP=$VPS_IP
export HETZNER_TOKEN="$HETZNER_TOKEN"
export DB_PASSWORD="$DB_PASSWORD"
export SENDGRID_API_KEY="$SENDGRID_KEY"
export ALERT_EMAIL="$ALERT_EMAIL"

# Coolify Dashboard: https://$VPS_IP:4000
# Application: https://escolhe-ai.net
# Date: $(date)
EOF

echo -e "${GREEN}✅ Deployment info saved to: .deployment-info${NC}"
echo ""
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the app at: https://escolhe-ai.net"
echo "2. Monitor logs in Coolify dashboard"
echo "3. Setup backups in Coolify"
echo "4. Configure email alerts"
echo ""
