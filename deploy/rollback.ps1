$ErrorActionPreference = "Stop"

$IMAGE = "nodejs-zero-downtime:v1"
$NETWORK = "nodejs-zero-downtime_default"

Write-Host "========================================"
Write-Host " Zero-Downtime Rollback"
Write-Host "========================================"

Write-Host ""
Write-Host "[1/4] Starting v1 containers..."

docker rm -f zero-downtime-app1 2>$null
docker rm -f zero-downtime-app2 2>$null

docker run -d `
  --name zero-downtime-app1 `
  --network $NETWORK `
  -e NODE_ENV=production `
  -e VERSION=v1 `
  -e PORT=3000 `
  $IMAGE

docker run -d `
  --name zero-downtime-app2 `
  --network $NETWORK `
  -e NODE_ENV=production `
  -e VERSION=v1 `
  -e PORT=3000 `
  $IMAGE

Write-Host ""
Write-Host "[2/4] Waiting for v1 containers..."
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "[3/4] Checking v1 health..."

docker exec zero-downtime-nginx wget -qO- http://zero-downtime-app1:3000/health
docker exec zero-downtime-nginx wget -qO- http://zero-downtime-app2:3000/health

Write-Host ""
Write-Host ""
Write-Host "v1 containers are healthy."

Write-Host ""
Write-Host "[4/4] Switching Nginx traffic back to v1..."

$nginxFile = "nginx/nginx.conf"
$content = Get-Content $nginxFile -Raw

$content = $content -replace "zero-downtime-v2-1:3000", "zero-downtime-app1:3000"
$content = $content -replace "zero-downtime-v2-2:3000", "zero-downtime-app2:3000"

Set-Content $nginxFile $content

docker exec zero-downtime-nginx nginx -t
docker exec zero-downtime-nginx nginx -s reload

Write-Host ""
Write-Host "Nginx switched back to v1."

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Verifying rollback..."

curl.exe -f http://localhost:8888/health

Write-Host ""
Write-Host ""
Write-Host "========================================"
Write-Host " Rollback Completed Successfully"
Write-Host "========================================"