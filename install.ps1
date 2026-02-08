# Blackwall one-line installer (Windows)
# Usage:
# iwr -useb https://get.blackwall.io/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$Repo = "Devaretanmay/blackwall-get"
$BinaryName = "blackwall.exe"
$InstallDir = "$env:ProgramFiles\Blackwall"
$ExePath = Join-Path $InstallDir $BinaryName

# Detect arch
$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") { "amd64" } elseif ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { throw "Unsupported arch: $env:PROCESSOR_ARCHITECTURE" }

# Get latest release
$ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
$Tag = (Invoke-RestMethod -Uri $ApiUrl).tag_name
if (-not $Tag) { throw "Could not determine latest release tag" }

$Asset = "blackwall-windows-$Arch.exe"
$Url = "https://github.com/$Repo/releases/download/$Tag/$Asset"

Write-Host "[blackwall] Downloading $Asset ($Tag)..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Invoke-WebRequest -Uri $Url -OutFile $ExePath

Write-Host "[blackwall] Installed to $ExePath"

# Configure trust env file
$EnvDir = Join-Path $env:ProgramData "Blackwall"
$EnvFile = Join-Path $EnvDir "blackwall.env"
$LicensePathDefault = Join-Path $EnvDir "license.json"
$IssuerKeysDefault = "/duYovG0PEc69OHjqk7D8k2oCdcEkY/gaX2LSi8pCKs="
$LicensePath = if ($env:TRUST_LICENSE_PATH) { $env:TRUST_LICENSE_PATH } else { $LicensePathDefault }
$IssuerKeys = if ($env:TRUST_ISSUER_KEYS) { $env:TRUST_ISSUER_KEYS } else { $IssuerKeysDefault }

function New-JwtSecret {
  $bytes = New-Object byte[] 48
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  [Convert]::ToBase64String($bytes)
}

if (-not (Test-Path $EnvFile)) {
  Write-Host "[blackwall] Writing trust config to $EnvFile"
  New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
  @(
    "TRUST_LICENSE_PATH=$LicensePath",
    "TRUST_ISSUER_KEYS=$IssuerKeys",
    "JWT_SECRET=$(New-JwtSecret)",
    "ENCRYPTION_KEY=$(New-JwtSecret)",
    "ENCRYPTION_SALT=$([Guid]::NewGuid().ToString('N'))",
    "DB_REQUIRED=false"
  ) | Set-Content -Path $EnvFile -Encoding ASCII
} else {
  $content = Get-Content -Path $EnvFile -ErrorAction SilentlyContinue
  if ($content -notmatch '^JWT_SECRET=') {
    Write-Host "[blackwall] Adding JWT_SECRET to $EnvFile"
    "JWT_SECRET=$(New-JwtSecret)" | Add-Content -Path $EnvFile -Encoding ASCII
  }
  if ($content -notmatch '^ENCRYPTION_KEY=') {
    Write-Host "[blackwall] Adding ENCRYPTION_KEY to $EnvFile"
    "ENCRYPTION_KEY=$(New-JwtSecret)" | Add-Content -Path $EnvFile -Encoding ASCII
  }
  if ($content -notmatch '^ENCRYPTION_SALT=') {
    Write-Host "[blackwall] Adding ENCRYPTION_SALT to $EnvFile"
    "ENCRYPTION_SALT=$([Guid]::NewGuid().ToString('N'))" | Add-Content -Path $EnvFile -Encoding ASCII
  }
  if ($content -notmatch '^DB_REQUIRED=') {
    Write-Host "[blackwall] Adding DB_REQUIRED=false to $EnvFile"
    "DB_REQUIRED=false" | Add-Content -Path $EnvFile -Encoding ASCII
  }
}

# Run init
Write-Host "[blackwall] Running: blackwall init"
& $ExePath init

Write-Host "[blackwall] Done. Run 'blackwall --help' to get started."