#!/bin/bash
# Install and configure Coolify on Hetzner VPS
# Run this INSIDE the VPS after it's created

set -e

echo "🐳 COOLIFY INSTALLATION"
echo "======================="
echo ""

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git

# Install Coolify
echo ""
echo "⬇️  Installing Coolify..."
curl -fsSL https://get.coool.app | bash

echo ""
echo "✅ Coolify installed!"
echo ""
echo "📍 Access Coolify at: https://$(hostname -I | awk '{print $1}'):4000"
echo ""
echo "⏳ Waiting for Coolify to be ready (60 seconds)..."
sleep 60

echo ""
echo "✅ COOLIFY IS READY!"
echo ""
echo "📝 Next steps:"
echo "1. Open: https://$(hostname -I | awk '{print $1}'):4000"
echo "2. Login and set your admin password"
echo "3. Configure your application (see DEPLOYMENT guide)"
echo ""
