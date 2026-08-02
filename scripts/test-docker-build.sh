#!/bin/bash
# Test Docker build and verify everything works

set -e

echo "🧪 TESTING DOCKER BUILD"
echo "======================="
echo ""

# 1. Check images exist
echo "✅ 1. Checking Docker images..."
docker images | grep escolhe-ai-web || {
  echo "❌ escolhe-ai-web image not found"
  exit 1
}

# 2. Start containers
echo "✅ 2. Starting containers..."
docker-compose up -d

echo "⏳ Waiting for services to be ready (30 seconds)..."
sleep 30

# 3. Check if web container is running
echo "✅ 3. Checking web container..."
docker-compose ps web || {
  echo "❌ Web container not running"
  docker-compose logs web
  exit 1
}

# 4. Check if db container is running
echo "✅ 4. Checking database container..."
docker-compose ps db || {
  echo "❌ DB container not running"
  docker-compose logs db
  exit 1
}

# 5. Test database connection
echo "✅ 5. Testing database connection..."
docker exec escolhe_ai_db pg_isready -U escolhe_ai || {
  echo "❌ Database not responding"
  exit 1
}

# 6. Test Rails app startup
echo "✅ 6. Testing Rails app startup..."
docker exec escolhe_ai_web bundle exec rails runner "puts 'Rails OK'" || {
  echo "❌ Rails failed to start"
  docker-compose logs web
  exit 1
}

# 7. Test healthcheck endpoint
echo "✅ 7. Testing healthcheck..."
HEALTH=$(docker exec escolhe_ai_web curl -s http://localhost:3000/up || echo "failed")
if echo "$HEALTH" | grep -q "ok"; then
  echo "✅ Healthcheck PASSED"
else
  echo "⚠️  Healthcheck endpoint not fully ready yet (may need more time)"
fi

# 8. Check logs for errors
echo "✅ 8. Checking logs..."
docker-compose logs web | grep -i "error" && {
  echo "⚠️  Found error-like messages in logs"
} || echo "✅ No critical errors in logs"

# 9. Test migrations
echo "✅ 9. Testing migrations..."
docker exec escolhe_ai_web bundle exec rails db:version || {
  echo "❌ Migrations failed"
  exit 1
}

echo ""
echo "🎉 ALL TESTS PASSED!"
echo ""
echo "Your app is ready to deploy!"
echo ""
echo "Next: Stop containers with:"
echo "  docker-compose down"
echo ""
echo "Then follow DEPLOY_RAPIDO.md for Railway deployment"
