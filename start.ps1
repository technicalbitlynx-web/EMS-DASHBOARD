# EMS Dashboard — Native Windows startup (no Docker required)
# Run: .\start.ps1

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectDir

# Check .env exists
if (-not (Test-Path ".env")) {
    Write-Host "[!] No .env file found. Copy .env.example to .env and fill in your Supabase URL." -ForegroundColor Yellow
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
