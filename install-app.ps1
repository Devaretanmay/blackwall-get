# Blackwall - Step 2: App Installation (Windows)
# Usage: .\install-app.ps1 (Run as Administrator)

$ErrorActionPreference = "Stop"
$Repo = "Devaretanmay/blackwall-get"
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

# Download Function
function Get-Binaries {
    if (Test-Path ".\blackwall-platform.exe") { return }
    
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
    
    # Flatten
    $SubDir = Get-ChildItem -Directory | Where-Object { $_.Name -like "blackwall-windows*" } | Select-Object -First 1
    if ($SubDir) {
        Get-ChildItem $SubDir.FullName | Move-Item -Destination "." -Force
        Remove-Item $SubDir.FullName -Recurse -Force
    }
    Remove-Item "blackwall.zip" -Force
}


# 1. Check License
if (-not (Test-Path $LicensePath)) {
    Write-Host "❌ Error: License not found at $LicensePath" -ForegroundColor Red
    Write-Host "Please run '.\setup-license.ps1' first."
    exit 1
}

# 2. Install Binaries
Get-Binaries
Write-Host "Installing binaries..."
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

$Binaries = @("blackwall.exe", "blackwall-platform.exe", "blackwall-license.exe", "bw-cli.exe")
foreach ($bin in $Binaries) {
    if (Test-Path ".\$bin") {
        Copy-Item ".\$bin" $InstallDir -Force
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

$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
Set-ItemProperty -Path $RegPath -Name "Environment" -Value $EnvContent -Type MultiString

Write-Host "Starting Service..."
Start-Service $ServiceName

Write-Host ""
Write-Host "✅ Installation Complete!" -ForegroundColor Green
Write-Host "Service '$ServiceName' is running."
