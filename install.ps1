# Blackwall one-line installer (Windows)
# Usage:
# iwr -useb https://get.blackwall.io/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$Repo = "creepymarshmallow117/blackwall"
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

# Run init
Write-Host "[blackwall] Running: blackwall init"
& $ExePath init

Write-Host "[blackwall] Done. Run 'blackwall --help' to get started."