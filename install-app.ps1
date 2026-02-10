# Blackwall - Step 2: App Installation (Windows)
# Usage: .\install-app.ps1 (Run as Administrator)

$ErrorActionPreference = "Stop"

$InstallDir = "C:\Program Files\Blackwall"
$DataDir = "$env:APPDATA\Blackwall"
$ConfigDir = "$env:PROGRAMDATA\Blackwall"
$LicensePath = Join-Path $DataDir "license.json"

Write-Host "🚀 Blackwall Application Installer" -ForegroundColor Cyan
Write-Host "=================================="

# Check Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ Error: Please run as Administrator." -ForegroundColor Red
    exit 1
}

# 1. Check License
if (-not (Test-Path $LicensePath)) {
    Write-Host "❌ Error: License not found at $LicensePath" -ForegroundColor Red
    Write-Host "Please run '.\setup-license.ps1' first."
    exit 1
}

# 2. Install Binaries
Write-Host "Installing binaries..."
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

$Binaries = @("blackwall.exe", "blackwall-platform.exe", "blackwall-license.exe", "bw-cli.exe")
foreach ($bin in $Binaries) {
    if (Test-Path ".\$bin") {
        Copy-Item ".\$bin" $InstallDir -Force
    } else {
        Write-Host "⚠️ Warning: $bin not found in source." -ForegroundColor Yellow
    }
}

# 3. Configure Env
Write-Host "Configuring environment..."
$EnvContent = @(
    "BLACKWALL_LICENSE_PATH=$LicensePath",
    "BLACKWALL_DATA_DIR=$DataDir",
    "LOG_LEVEL=info"
)
$EnvContent | Out-File -FilePath "$ConfigDir\blackwall.env" -Encoding ASCII

# 4. Windows Service
$ServiceName = "BlackwallPlatform"
$ServiceBin = "$InstallDir\blackwall-platform.exe"

$Existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($Existing) {
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

Write-Host "Creating Windows Service..."
sc.exe create $ServiceName binPath= "`"$ServiceBin`"" start= auto | Out-Null
sc.exe description $ServiceName "Blackwall AI Risk Platform" | Out-Null

# Set Environment (via Registry for Service)
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
Set-ItemProperty -Path $RegPath -Name "Environment" -Value $EnvContent -Type MultiString

Write-Host "Starting Service..."
Start-Service $ServiceName

Write-Host ""
Write-Host "✅ Installation Complete!" -ForegroundColor Green
Write-Host "Service '$ServiceName' is running."
