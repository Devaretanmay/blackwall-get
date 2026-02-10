# Blackwall - Step 1: License Setup (Windows)
# Usage: .\setup-license.ps1

$ErrorActionPreference = "Stop"

$DataDir = "$env:APPDATA\Blackwall"
$LicenseTool = ".\blackwall-license.exe"

Write-Host "🔑 Blackwall License Setup" -ForegroundColor Cyan
Write-Host "=========================="

if (-not (Test-Path $LicenseTool)) {
    Write-Host "❌ Error: blackwall-license.exe not found in current folder." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
$LicensePath = Join-Path $DataDir "license.json"

if (Test-Path $LicensePath) {
    Write-Host "Found existing license at $LicensePath"
    & $LicenseTool status --license $LicensePath | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Existing license is valid." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Existing license invalid. Backing up..."
        Rename-Item $LicensePath "$LicensePath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    }
}

Write-Host "Generating new license..."
& $LicenseTool init --org "local-user" --type "trial" --duration "8760h" --features "full" --out $LicensePath

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Success! License saved to: $LicensePath" -ForegroundColor Green
    Write-Host "Now run: .\install-app.ps1"
} else {
    Write-Host "❌ Failed to generate license." -ForegroundColor Red
    exit 1
}
