# START_DEVPOOL.ps1 — Multica Dev Pool starten (Windows)
# Ersatz fuer: make setup && make start

Set-Location $PSScriptRoot

# 1. .env anlegen falls nicht vorhanden
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "==> .env aus .env.example erstellt. Bitte JWT_SECRET aendern!" -ForegroundColor Yellow
}

# 2. Dependencies installieren
Write-Host "==> pnpm install..." -ForegroundColor Cyan
pnpm install

# 3. PostgreSQL via Docker starten
Write-Host "==> PostgreSQL starten..." -ForegroundColor Cyan
docker compose up -d postgres
Start-Sleep -Seconds 3

# 4. Datenbank migrieren
Write-Host "==> Migrationen laufen lassen..." -ForegroundColor Cyan
Set-Location server
go run ./cmd/migrate up
Set-Location ..

Write-Host ""
Write-Host "Setup abgeschlossen! Backend + Frontend werden jetzt gestartet..." -ForegroundColor Green
Write-Host "  Backend:  http://localhost:8080" -ForegroundColor White
Write-Host "  Frontend: http://localhost:3000" -ForegroundColor White
Write-Host ""

# 5. Backend + Frontend parallel starten (je in eigenem Fenster)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\server'; go run ./cmd/server" -WindowStyle Normal
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; pnpm dev:web" -WindowStyle Normal

Write-Host "Zwei Fenster geoeffnet. Warte bis beide ready sind, dann:" -ForegroundColor Green
Write-Host "  Browser: http://localhost:3000" -ForegroundColor Cyan
