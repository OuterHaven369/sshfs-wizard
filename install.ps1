param(
    [string]$Host = "",
    [string]$User = "",
    [string]$Drive = "X",
    [switch]$Auto
)

function Write-Info($msg) {
    Write-Host "[*] $msg"
}

function Write-ErrorMsg($msg) {
    Write-Host "[!] $msg" -ForegroundColor Red
}

# Ensure running as administrator
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-ErrorMsg "This installer must be run as Administrator. Right-click PowerShell and select 'Run as administrator', then run:"
    Write-Host "    powershell -ExecutionPolicy Bypass -File .\install.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Info "Starting SSHFS Wizard installer..."

# Ensure winget exists
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg "winget is not available on this system. Please install the 'App Installer' from Microsoft Store, then re-run this script."
    exit 1
}

function Ensure-Package {
    param(
        [string]$Id,
        [string]$FriendlyName
    )
    Write-Info "Checking for $FriendlyName ($Id)..."
    $pkg = winget list --id $Id --accept-source-agreements 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $pkg) {
        Write-Info "$FriendlyName not found. Installing via winget..."
        winget install --id $Id --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Failed to install $FriendlyName using winget. Install it manually and re-run."
            exit 1
        }
    } else {
        Write-Info "$FriendlyName already installed."
    }
}

# 1) Ensure WinFsp and SSHFS-Win are installed
Ensure-Package -Id "WinFsp.WinFsp" -FriendlyName "WinFsp"
Ensure-Package -Id "SSHFS-Win.SSHFS-Win" -FriendlyName "SSHFS-Win"

# 2) Collect connection info
if (-not $Host) {
    $Host = Read-Host "Enter VPS hostname or IP (e.g. 45.76.12.161)"
}
if (-not $User) {
    $User = Read-Host "Enter VPS username (e.g. linuxuser)"
}
if (-not $Drive) {
    $Drive = "X"
}
$Drive = $Drive.TrimEnd(':').ToUpper()

# Optional: remote path (currently not used; home directory is default)
$RemotePath = Read-Host "Enter remote path to mount (default: home directory). Press ENTER to use default"
if (-not $RemotePath) {
    $RemotePath = ""
}

Write-Info "Using:"
Write-Host "  Host       : $Host"
Write-Host "  User       : $User"
Write-Host "  Drive      : $Drive`:"
if ($RemotePath) {
    Write-Host "  Remote path: $RemotePath"
} else {
    Write-Host "  Remote path: <home directory>"
}

# 3) Setup SSH key
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (-not (Test-Path $sshDir)) {
    Write-Info "Creating $sshDir..."
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

$keyFile = Join-Path $sshDir "id_ed25519"
$pubKeyFile = "$keyFile.pub"

if (-not (Test-Path $keyFile)) {
    Write-Info "No SSH key found at $keyFile. Generating new ed25519 key..."
    ssh-keygen -t ed25519 -f $keyFile -N "" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to generate SSH key."
        exit 1
    }
} else {
    Write-Info "Existing SSH key found at $keyFile."
}

# 4) Test passwordless SSH; if it fails, try to add key to authorized_keys
Write-Info "Testing passwordless SSH to $User@$Host..."
ssh "$User@$Host" "echo ok" 2>$null | Out-Null
$sshOk = ($LASTEXITCODE -eq 0)

if (-not $sshOk) {
    Write-Info "Passwordless SSH not yet configured. Attempting to upload public key..."
    if (-not (Test-Path $pubKeyFile)) {
        Write-ErrorMsg "Public key file $pubKeyFile not found."
        exit 1
    }
    $pubKey = Get-Content $pubKeyFile -Raw

    # This will prompt for password ONE last time
    Write-Info "You may be prompted for the VPS password."
    $cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    # Use SSH with bash -lc to avoid shell differences
    ssh "$User@$Host" "$cmd"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to upload SSH key to server. Please configure authorized_keys manually and re-run."
        exit 1
    }

    Write-Info "Re-testing passwordless SSH..."
    ssh "$User@$Host" "echo ok" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Passwordless SSH still not working. Aborting."
        exit 1
    }
}

Write-Info "Passwordless SSH verified."

# 5) Prepare local directory structure
$baseDir = Join-Path $env:USERPROFILE "SSHFS"
$logsDir = Join-Path $baseDir "logs"
if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

# Save config
$config = @{
    Host       = $Host
    User       = $User
    Drive      = $Drive
    RemotePath = $RemotePath
}
$configPath = Join-Path $baseDir "settings.json"
$config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8

Write-Info "Saved configuration to $configPath"

# 6) Create reconnect script
$reconnectScriptPath = Join-Path $baseDir "sshfs_reconnect.cmd"
$logPath = Join-Path $logsDir "mount.log"

$remotePrefix = "\\sshfs.k\\$User@$Host"
# Note: for now we always mount the user's home directory (Option A)

$reconnectScript = @"
@echo off
set LOG="$logPath"
echo [%date% %time%] Starting SSHFS reconnect... >> "%LOG%"
:retry
ping $Host -n 1 -w 1000 >nul
if errorlevel 1 (
    echo [%date% %time%] Host unreachable, retrying... >> "%LOG%"
    timeout /t 3 >nul
    goto retry
)
echo [%date% %time%] Host reachable, mounting... >> "%LOG%"
sshfs-win.exe svc $remotePrefix ${Drive}: -o IdentityFile="%USERPROFILE%\.ssh\id_ed25519"
echo [%date% %time%] Mount command issued. >> "%LOG%"
exit
"@

$reconnectScript | Set-Content -Path $reconnectScriptPath -Encoding ASCII
Write-Info "Created reconnect script at $reconnectScriptPath"

# 7) Create unmount script
$unmountScriptPath = Join-Path $baseDir "sshfs_unmount.cmd"
$unmountLogPath = Join-Path $logsDir "unmount.log"

$unmountScript = @"
@echo off
set LOG="$unmountLogPath"
echo [%date% %time%] Unmounting ${Drive}: ... >> "%LOG%"
net use ${Drive}: /delete /y
exit
"@

$unmountScript | Set-Content -Path $unmountScriptPath -Encoding ASCII
Write-Info "Created unmount script at $unmountScriptPath"

# 8) Create scheduled tasks
Write-Info "Creating scheduled task for auto-mount on logon..."

# Delete existing tasks if present
schtasks /Delete /TN "SSHFS_Mount_$Drive" /F 2>$null | Out-Null
schtasks /Delete /TN "SSHFS_Unmount_$Drive" /F 2>$null | Out-Null

# Mount on logon with 10-second delay
schtasks /Create /TN "SSHFS_Mount_$Drive" `
    /TR "`"$reconnectScriptPath`"" `
    /SC ONLOGON `
    /RL HIGHEST `
    /DELAY 0000:10 `
    /F

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to create SSHFS_Mount_$Drive task."
    exit 1
}

# Unmount on logoff
schtasks /Create /TN "SSHFS_Unmount_$Drive" `
    /TR "`"$unmountScriptPath`"" `
    /SC ONLOGOFF `
    /RL HIGHEST `
    /F

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to create SSHFS_Unmount_$Drive task."
    exit 1
}

Write-Info "Scheduled tasks created successfully."

# 9) Test mount now
Write-Info "Testing mount now..."
& $reconnectScriptPath

Write-Info "Installer finished. Check File Explorer for drive ${Drive}: pointing to your VPS home directory."
