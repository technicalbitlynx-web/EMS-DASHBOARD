# EMS Dashboard — Native Windows startup (no Docker required)
# Prerequisites: Node.js 20+, PostgreSQL 16 (local or Supabase), Mosquitto (optional)
# Run: .\start.ps1

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectDir

# Check .env exists
if (-not (Test-Path ".env")) {
    Write-Host "[!] No .env file found. Copying .env.example → .env" -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "[!] Edit .env and set DATABASE_URL (Supabase) or POSTGRES_* vars, then re-run." -ForegroundColor Yellow
    exit 1
}

# Install npm dependencies if node_modules is missing
if (-not (Test-Path "node_modules")) {
    Write-Host "[*] Installing dependencies..." -ForegroundColor Cyan
    npm install
    if ($LASTEXITCODE -ne 0) { Write-Host "[!] npm install failed" -ForegroundColor Red; exit 1 }
}

Write-Host "[*] Starting EMS Dashboard on http://localhost:3001" -ForegroundColor Green
node server/index.js
