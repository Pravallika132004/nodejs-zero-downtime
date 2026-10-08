$ErrorActionPreference = "Stop"

$IMAGE = "nodejs-zero-downtime:v2"
$NETWORK = "nodejs-zero-downtime_default"

Write-Host "========================================"
Write-Host " Node.js Zero-Downtime Deployment"
Write-Host "========================================"

Write-Host ""
Write-Host "[1/6] Building v2 Docker image..."
docker build -t $IMAGE .

Write-Host ""
Write-Host "[2/6] Removing old v2 containers if present..."

docker rm -f zero-downtime-v2-1 2>$null
docker rm -f zero-downtime-v2-2 2>$null

Write-Host ""
Write-Host "[3/6] Starting v2 containers..."

docker run -d `
  --name zero-downtime-v2-1 `
  --network $NETWORK `
  -e NODE_ENV=production `
  -e VERSION=v2 `
  -e PORT=3000 `
  $IMAGE

docker run -d `
  --name zero-downtime-v2-2 `
  --network $NETWORK `
  -e NODE_ENV=production `
  -e VERSION=v2 `
  -e PORT=3000 `
  $IMAGE

Write-Host ""
Write-Host "Waiting for v2 containers..."
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "[4/6] Checking v2 health..."

docker exec zero-downtime-nginx wget -qO- http://zero-downtime-v2-1:3000/health
docker exec zero-downtime-nginx wget -qO- http://zero-downtime-v2-2:3000/health

Write-Host ""
Write-Host ""
Write-Host "v2 containers are healthy."

Write-Host ""
Write-Host "[5/6] Switching Nginx traffic to v2..."

$nginxFile = "nginx/nginx.conf"

$content = Get-Content $nginxFile -Raw

$content = $content -replace "zero-downtime-app1:3000", "zero-downtime-v2-1:3000"
$content = $content -replace "zero-downtime-app2:3000", "zero-downtime-v2-2:3000"

Set-Content $nginxFile $content

docker exec zero-downtime-nginx nginx -t
docker exec zero-downtime-nginx nginx -s reload

Write-Host ""
Write-Host "Nginx switched to v2."

Write-Host ""
Write-Host "[6/6] Verifying production endpoint..."

Start-Sleep -Seconds 2

curl.exe -f http://localhost:8888/health

Write-Host ""
Write-Host ""
Write-Host "Removing old v1 containers..."

docker rm -f zero-downtime-app1 2>$null
docker rm -f zero-downtime-app2 2>$null

Write-Host ""
Write-Host "========================================"
Write-Host " Zero-Downtime Deployment Successful"
Write-Host "========================================"