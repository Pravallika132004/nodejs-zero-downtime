#!/bin/sh

set -e

NETWORK="nodejs-zero-downtime_default"

echo "========================================"
echo " Zero-Downtime Rollback"
echo "========================================"

echo ""
echo "[1/4] Starting v1 containers..."

docker rm -f zero-downtime-app1 2>/dev/null || true
docker rm -f zero-downtime-app2 2>/dev/null || true

docker run -d \
  --name zero-downtime-app1 \
  --network "$NETWORK" \
  -e VERSION=v1 \
  -e PORT=3000 \
  nodejs-zero-downtime:v1

docker run -d \
  --name zero-downtime-app2 \
  --network "$NETWORK" \
  -e VERSION=v1 \
  -e PORT=3000 \
  nodejs-zero-downtime:v1

echo ""
echo "[2/4] Waiting for v1 containers..."
sleep 5

echo ""
echo "[3/4] Checking v1 health..."

docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-app1:3000/health

docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-app2:3000/health

echo ""
echo "[4/4] Switching Nginx traffic back to v1..."

sed -i \
  's/zero-downtime-v2-1/zero-downtime-app1/g;
   s/zero-downtime-v2-2/zero-downtime-app2/g' \
  nginx/nginx.conf

docker exec zero-downtime-nginx nginx -t
docker exec zero-downtime-nginx nginx -s reload

curl -f http://localhost:8888/health

echo ""
echo "========================================"
echo " Rollback Completed Successfully"
echo "========================================"