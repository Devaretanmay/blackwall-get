# Blackwall - Step 1: License Setup (Windows)
# Usage: .\setup-license.ps1

$ErrorActionPreference = "Stop"
$Repo = "creepymarshmallow117/blackwall"
$DataDir = "$env:APPDATA\Blackwall"
$LicenseTool = ".\blackwall-license.exe"

Write-Host "🔑 Blackwall License Setup" -ForegroundColor Cyan
Write-Host "=========================="

# Download Function
function Get-Binaries {
    if (Test-Path $LicenseTool) { return }
    
    Write-Host "Fetching latest release..."
    try {
        $Latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        $AssetUrl = $Latest.assets | Where-Object { $_.name -like "*windows*.zip" } | Select-Object -ExpandProperty browser_download_url -First 1
    } catch {
        Write-Error "Failed to fetch release info: $_"
        exit 1
    }
    
    if (-not $AssetUrl) { Write-Error "Could not find Windows release asset."; exit 1 }
    
    Write-Host "Downloading $AssetUrl..."
    Invoke-WebRequest -Uri $AssetUrl -OutFile "blackwall.zip"
    
    Write-Host "Extracting..."
    Expand-Archive -Path "blackwall.zip" -DestinationPath "." -Force
    
    # Move files from subfolder if needed (flatten)
    $SubDir = Get-ChildItem -Directory | Where-Object { $_.Name -like "blackwall-windows*" } | Select-Object -First 1
    if ($SubDir) {
        Get-ChildItem $SubDir.FullName | Move-Item -Destination "." -Force
        Remove-Item $SubDir.FullName -Recurse -Force
    }
    Remove-Item "blackwall.zip" -Force
}

Get-Binaries

if (-not (Test-Path $LicenseTool)) {
    Write-Error "blackwall-license.exe not found after download."
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
    Write-Host "Now run Step 2: .\install-app.ps1"
} else {
    Write-Host "❌ Failed to generate license." -ForegroundColor Red
    exit 1
}
