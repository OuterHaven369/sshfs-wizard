param(
    [string]$HostName = "",
    [string]$User = "",
    [string]$Drive = "",
    [switch]$NonInteractive
)

function Write-Info($msg) {
    Write-Host "[*] $msg"
}

function Write-ErrorMsg($msg) {
    Write-Host "[!] $msg" -ForegroundColor Red
}

function Get-AvailableDriveLetters {
    # Get all currently used drive letters from multiple sources
    $usedDrives = @()

    # Source 1: PowerShell drives
    $usedDrives += Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name

    # Source 2: WMI logical disks
    $usedDrives += (Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID | ForEach-Object { $_.TrimEnd(':') })

    # Source 3: Network drives and SSHFS mounts (from net use)
    $netUseOutput = net use 2>$null | Select-String "^\s*(OK|Unavailable|Disconnected)?\s+([A-Z]:)"
    foreach ($line in $netUseOutput) {
        if ($line -match '\s([A-Z]):') {
            $usedDrives += $matches[1]
        }
    }

    # Remove duplicates
    $usedDrives = $usedDrives | Select-Object -Unique

    # All possible drive letters (excluding A, B, C which are typically system/reserved)
    $allDrives = 68..90 | ForEach-Object { [char]$_ } # D-Z

    # Return drives that are not in use
    $available = $allDrives | Where-Object { $usedDrives -notcontains $_ }
    return $available
}

function Select-DriveLetter {
    param([string]$PreferredDrive)

    $availableDrives = Get-AvailableDriveLetters

    if ($availableDrives.Count -eq 0) {
        Write-ErrorMsg "No available drive letters! All drives D-Z are in use."
        exit 1
    }

    # If a preferred drive was specified
    if ($PreferredDrive) {
        $PreferredDrive = $PreferredDrive.TrimEnd(':').ToUpper()
        if ($availableDrives -contains $PreferredDrive) {
            Write-Info "Using specified drive letter: $PreferredDrive"
            return $PreferredDrive
        } else {
            Write-Host "[!] Drive $PreferredDrive`: is already in use or invalid." -ForegroundColor Yellow
            Write-Host "    Available drives: $($availableDrives -join ', ')" -ForegroundColor Yellow
        }
    }

    # Auto-select first available
    $autoDrive = $availableDrives[0]
    Write-Info "Auto-selected drive: $autoDrive (first available)"
    Write-Host "    Available drives: $($availableDrives -join ', ')" -ForegroundColor Gray

    # Check if running in non-interactive mode
    if ($script:NonInteractive) {
        Write-Info "Non-interactive mode: using $autoDrive"
        return $autoDrive
    }

    Write-Host "    Press ENTER to use $autoDrive, or type a different letter: " -NoNewline -ForegroundColor Cyan

    $choice = Read-Host
    if ($choice) {
        $choice = $choice.TrimEnd(':').ToUpper()
        if ($availableDrives -contains $choice) {
            return $choice
        } else {
            Write-Host "[!] Invalid choice. Using auto-selected $autoDrive" -ForegroundColor Yellow
            return $autoDrive
        }
    }

    return $autoDrive
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
if (-not $HostName) {
    $HostName = Read-Host "Enter VPS hostname or IP (e.g. 45.76.12.161)"
}
if (-not $User) {
    $User = Read-Host "Enter VPS username (e.g. linuxuser)"
}

# Smart drive letter selection
if ($NonInteractive) {
    $Drive = Select-DriveLetter -PreferredDrive $Drive
    $script:NonInteractive = $true  # Make available to function
} else {
    $Drive = Select-DriveLetter -PreferredDrive $Drive
}

# Optional: remote path (currently not used; home directory is default)
$RemotePath = Read-Host "Enter remote path to mount (default: home directory). Press ENTER to use default"
if (-not $RemotePath) {
    $RemotePath = ""
}

Write-Info "Using:"
Write-Host "  Host       : $HostName"
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
Write-Info "Testing passwordless SSH to $User@$HostName..."
ssh "$User@$HostName" "echo ok" 2>$null | Out-Null
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
    ssh "$User@$HostName" "$cmd"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to upload SSH key to server. Please configure authorized_keys manually and re-run."
        exit 1
    }

    Write-Info "Re-testing passwordless SSH..."
    ssh "$User@$HostName" "echo ok" 2>$null | Out-Null
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
    Host       = $HostName
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

$remotePrefix = "\\sshfs.k\\$User@$HostName"
# Note: for now we always mount the user's home directory (Option A)

$reconnectScript = @"
@echo off
set LOG="$logPath"
echo [%date% %time%] Starting SSHFS reconnect... >> "%LOG%"
:retry
ping $HostName -n 1 -w 1000 >nul
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

# Unmount on logoff (optional - manual unmount also works)
Write-Info "Note: Auto-unmount on logoff is optional. The drive will persist across sessions."
Write-Host "      To manually unmount, run: $unmountScriptPath" -ForegroundColor Gray

# We skip auto-unmount task because:
# 1. ONLOGOFF has compatibility issues on some Windows versions
# 2. Persistent mounts are often desirable
# 3. Manual unmount script is available if needed
# Users can create the task manually if desired:
# schtasks /Create /TN "SSHFS_Unmount_$Drive" /TR "$unmountScriptPath" /SC ONLOGOFF /RU "$env:USERNAME"

Write-Info "Scheduled tasks created successfully."

# 9) Test mount now
Write-Info "Testing mount now..."
& $reconnectScriptPath

Write-Info "Installer finished. Check File Explorer for drive ${Drive}: pointing to your VPS home directory."
