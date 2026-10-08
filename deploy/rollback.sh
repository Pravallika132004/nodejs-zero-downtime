#!/bin/sh

set -e

IMAGE="nodejs-zero-downtime:v1"
NETWORK="nodejs-zero-downtime_default"

echo "========================================"
echo " Zero-Downtime Rollback"
echo "========================================"

echo ""
echo "[1/5] Starting v1 containers..."

docker rm -f zero-downtime-app1 2>/dev/null || true
docker rm -f zero-downtime-app2 2>/dev/null || true

docker run -d \
  --name zero-downtime-app1 \
  --network "$NETWORK" \
  -e NODE_ENV=production \
  -e VERSION=v1 \
  -e PORT=3000 \
  "$IMAGE"

docker run -d \
  --name zero-downtime-app2 \
  --network "$NETWORK" \
  -e NODE_ENV=production \
  -e VERSION=v1 \
  -e PORT=3000 \
  "$IMAGE"

echo ""
echo "[2/5] Waiting for v1 containers..."

sleep 5

echo ""
echo "[3/5] Checking v1 health..."

echo "Checking app1:"
docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-app1:3000/health

echo ""

echo "Checking app2:"
docker exec zero-downtime-nginx \
  wget -qO- http://zero-downtime-app2:3000/health

echo ""
echo ""
echo "v1 containers are healthy."

echo ""
echo "[4/5] Switching Nginx traffic back to v1..."

# IMPORTANT:
# Modify the existing file in-place.
# Do NOT use sed -i because Docker is using nginx.conf
# as a bind mount.

python3 - <<'PY'
from pathlib import Path

path = Path("nginx/nginx.conf")

with path.open("r+", encoding="utf-8") as f:
    content = f.read()

    content = content.replace(
        "zero-downtime-v2-1:3000",
        "zero-downtime-app1:3000"
    )

    content = content.replace(
        "zero-downtime-v2-2:3000",
        "zero-downtime-app2:3000"
    )

    f.seek(0)
    f.write(content)
    f.truncate()
PY

echo ""
echo "Checking host Nginx configuration..."

cat nginx/nginx.conf

echo ""
echo "Checking that v1 upstreams exist..."

grep -q "zero-downtime-app1:3000" nginx/nginx.conf
grep -q "zero-downtime-app2:3000" nginx/nginx.conf

echo "v1 upstream configuration confirmed."

echo ""
echo "Checking Nginx container configuration..."

docker exec zero-downtime-nginx \
  grep -E "zero-downtime-(app1|app2):3000" \
  /etc/nginx/nginx.conf

echo ""
echo "Testing Nginx configuration..."

docker exec zero-downtime-nginx nginx -t

echo ""
echo "Reloading Nginx..."

docker exec zero-downtime-nginx nginx -s reload

sleep 3

echo ""
echo "Checking Nginx configuration after reload..."

docker exec zero-downtime-nginx \
  nginx -T 2>&1 | grep -E "zero-downtime-(app1|app2):3000"

echo ""
echo "[5/5] Verifying rollback..."

V1_READY=false

for i in $(seq 1 15)
do
    echo ""
    echo "Validation attempt $i/15..."

    RESPONSE=$(curl -s --max-time 5 \
      http://localhost:8888/health || true)

    echo "$RESPONSE"

    if echo "$RESPONSE" | grep -q '"version":"v1"'
    then
        echo ""
        echo "v1 production endpoint is healthy."
        V1_READY=true
        break
    fi

    echo "v1 not active yet. Waiting 2 seconds..."
    sleep 2
done

if [ "$V1_READY" != "true" ]
then
    echo ""
    echo "ERROR: v1 production endpoint did not become healthy."

    echo ""
    echo "Current Nginx configuration:"
    docker exec zero-downtime-nginx \
      nginx -T 2>&1 | grep -E "upstream|zero-downtime"

    echo ""
    echo "v1 container status:"
    docker ps -a --filter "name=zero-downtime-app"

    echo ""
    echo "v1 container logs:"

    docker logs zero-downtime-app1 || true
    docker logs zero-downtime-app2 || true

    exit 1
fi

echo ""
echo "Final rollback health check..."

curl --fail --max-time 10 \
  http://localhost:8888/health

echo ""
echo ""
echo "========================================"
echo " Rollback Completed Successfully"
echo "========================================"