#!/bin/sh

set -e

IMAGE="nodejs-zero-downtime:v2"
NETWORK="nodejs-zero-downtime_default"

echo "========================================"
echo " Node.js Zero-Downtime Deployment"
echo "========================================"

echo ""
echo "[1/6] Building v2 Docker image..."
docker build -t "$IMAGE" .

echo ""
echo "[2/6] Removing old v2 containers if present..."
docker rm -f zero-downtime-v2-1 2>/dev/null || true
docker rm -f zero-downtime-v2-2 2>/dev/null || true

echo ""
echo "[3/6] Starting v2 containers..."

docker run -d \
  --name zero-downtime-v2-1 \
  --network "$NETWORK" \
  -e VERSION=v2 \
  -e PORT=3000 \
  "$IMAGE"

docker run -d \
  --name zero-downtime-v2-2 \
  --network "$NETWORK" \
  -e VERSION=v2 \
  -e PORT=3000 \
  "$IMAGE"

echo ""
echo "Waiting for v2 containers..."
sleep 5

echo ""
echo "[4/6] Checking v2 health..."

docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-v2-1:3000/health

docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-v2-2:3000/health

echo ""
echo ""
echo "[5/6] Validating and reloading Nginx..."

docker exec zero-downtime-nginx nginx -t
docker exec zero-downtime-nginx nginx -s reload

echo ""
echo "[6/6] Verifying production endpoint..."

curl -f http://localhost:8888/health

echo ""
echo ""
echo "========================================"
echo " Zero-Downtime Deployment Successful"
echo "========================================"