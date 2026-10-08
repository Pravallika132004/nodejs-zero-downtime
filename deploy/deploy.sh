#!/bin/sh

set -e

IMAGE="nodejs-zero-downtime:v2"
NETWORK="nodejs-zero-downtime_default"

echo "========================================"
echo " Node.js Zero-Downtime Deployment"
echo "========================================"

echo ""
echo "[1/7] Building v2 Docker image..."

docker build -t "$IMAGE" .

echo ""
echo "[2/7] Removing old v2 containers if present..."

docker rm -f zero-downtime-v2-1 2>/dev/null || true
docker rm -f zero-downtime-v2-2 2>/dev/null || true

echo ""
echo "[3/7] Starting v2 containers..."

docker run -d \
  --name zero-downtime-v2-1 \
  --network "$NETWORK" \
  -e NODE_ENV=production \
  -e VERSION=v2 \
  -e PORT=3000 \
  "$IMAGE"

docker run -d \
  --name zero-downtime-v2-2 \
  --network "$NETWORK" \
  -e NODE_ENV=production \
  -e VERSION=v2 \
  -e PORT=3000 \
  "$IMAGE"

echo ""
echo "Waiting for v2 containers..."
sleep 5

echo ""
echo "[4/7] Checking v2 containers directly..."

echo "Checking v2-1:"
docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-v2-1:3000/health

echo ""

echo "Checking v2-2:"
docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-v2-2:3000/health

echo ""
echo ""
echo "v2 containers are healthy."

echo ""
echo "[5/7] Switching Nginx configuration to v2..."

sed -i 's/zero-downtime-app1:3000/zero-downtime-v2-1:3000/g' nginx/nginx.conf
sed -i 's/zero-downtime-app2:3000/zero-downtime-v2-2:3000/g' nginx/nginx.conf

echo ""
echo "Nginx configuration on host:"
cat nginx/nginx.conf

echo ""
echo "Checking that v2 upstreams exist..."

grep -q "zero-downtime-v2-1:3000" nginx/nginx.conf
grep -q "zero-downtime-v2-2:3000" nginx/nginx.conf

echo "v2 upstream configuration confirmed."

echo ""
echo "Checking Nginx configuration inside container..."

docker exec zero-downtime-nginx \
  nginx -T 2>&1 | grep "zero-downtime-v2"

echo ""
echo "Testing Nginx configuration..."

docker exec zero-downtime-nginx nginx -t

echo ""
echo "Reloading Nginx..."

docker exec zero-downtime-nginx nginx -s reload

echo ""
echo "Nginx reload completed."

sleep 3

echo ""
echo "[6/7] Verifying v2 production endpoint..."

V2_READY=false

for i in $(seq 1 15); do

    echo ""
    echo "Validation attempt $i/15..."

    RESPONSE=$(curl -s --max-time 5 http://localhost:8888/health || true)

    echo "$RESPONSE"

    if echo "$RESPONSE" | grep -q '"version":"v2"'; then
        echo ""
        echo "v2 production endpoint is healthy."
        V2_READY=true
        break
    fi

    echo "v2 not active yet. Waiting 2 seconds..."
    sleep 2

done

if [ "$V2_READY" != "true" ]; then

    echo ""
    echo "ERROR: v2 production endpoint did not become healthy."

    echo ""
    echo "Current Nginx configuration:"
    docker exec zero-downtime-nginx nginx -T 2>&1 | grep -E "upstream|zero-downtime"

    echo ""
    echo "v2 container status:"
    docker ps -a --filter "name=zero-downtime-v2"

    echo ""
    echo "v2 container logs:"
    docker logs zero-downtime-v2-1 || true
    docker logs zero-downtime-v2-2 || true

    exit 1
fi

echo ""
echo "Final production health check..."

curl --fail --max-time 10 http://localhost:8888/health

echo ""
echo ""
echo "[7/7] Removing old v1 containers..."

docker rm -f zero-downtime-app1 2>/dev/null || true
docker rm -f zero-downtime-app2 2>/dev/null || true

echo ""
echo "========================================"
echo " Zero-Downtime Deployment Successful"
echo "========================================"