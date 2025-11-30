#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SSHFS Manager Installer
.DESCRIPTION
    Installs SSHFS Manager as a Windows application with proper registry entries,
    Start Menu shortcuts, and Add/Remove Programs integration.
.NOTES
    Version: 1.3.0
    Author: SSHFS-Wizard Team
#>

param(
    [switch]$Silent,
    [string]$InstallPath = "$env:ProgramFiles\SSHFS Manager"
)

$ErrorActionPreference = "Stop"

# App metadata
$AppName = "SSHFS Manager"
$AppVersion = "1.3.0"
$AppPublisher = "SSHFS-Wizard"
$AppDescription = "Mount remote Linux directories as Windows drives via SSHFS"
$AppGuid = "{7E5F8A12-3B4C-4D5E-9F6A-1B2C3D4E5F6A}"

# Paths
$SourcePath = Split-Path -Parent $PSScriptRoot
$StartMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$AppName"
$DesktopShortcut = "$env:PUBLIC\Desktop\$AppName.lnk"
$UninstallRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppGuid"

function Write-Step {
    param([string]$Message)
    Write-Host "`n[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Step "Checking prerequisites..."

    # Check for WinFsp
    $winfsp = Get-ItemProperty "HKLM:\SOFTWARE\WinFsp\*" -ErrorAction SilentlyContinue
    if (-not $winfsp) {
        Write-Host "  WinFsp not found. Will be installed during setup." -ForegroundColor Yellow
    } else {
        Write-Success "WinFsp is installed"
    }

    # Check for SSHFS-Win
    $sshfsWin = Get-Command "sshfs-win.exe" -ErrorAction SilentlyContinue
    if (-not $sshfsWin) {
        Write-Host "  SSHFS-Win not found. Will be installed during setup." -ForegroundColor Yellow
    } else {
        Write-Success "SSHFS-Win is installed"
    }
}

# Install dependencies
function Install-Dependencies {
    Write-Step "Installing dependencies..."

    # Check if winget is available
    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Fail "winget not found. Please install App Installer from Microsoft Store."
        return $false
    }

    # Install WinFsp
    Write-Host "  Installing WinFsp..." -ForegroundColor Gray
    winget install -e --id WinFsp.WinFsp --accept-source-agreements --accept-package-agreements 2>$null

    # Install SSHFS-Win
    Write-Host "  Installing SSHFS-Win..." -ForegroundColor Gray
    winget install -e --id SSHFS-Win.SSHFS-Win --accept-source-agreements --accept-package-agreements 2>$null

    Write-Success "Dependencies installed"
    return $true
}

# Copy application files
function Install-AppFiles {
    Write-Step "Installing application files..."

    # Create install directory
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

    # Copy main application
    Copy-Item "$SourcePath\src\sshfs-manager.ps1" "$InstallPath\sshfs-manager.ps1"
    Copy-Item "$SourcePath\src\sshfs-setup.ps1" "$InstallPath\sshfs-setup.ps1"

    # Copy assets if they exist
    if (Test-Path "$SourcePath\assets") {
        Copy-Item "$SourcePath\assets\*" "$InstallPath\" -Recurse -ErrorAction SilentlyContinue
    }

    # Create launcher batch file
    $launcherContent = @"
@echo off
start "" /b powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0sshfs-manager.ps1"
"@
    $launcherContent | Set-Content "$InstallPath\SSHFS Manager.bat" -Encoding ASCII

    # Create uninstaller
    Copy-Item "$SourcePath\installer\Uninstall-SSHFSManager.ps1" "$InstallPath\Uninstall.ps1"

    # Create uninstaller batch
    $uninstallBat = @"
@echo off
echo Uninstalling SSHFS Manager...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Uninstall.ps1\"' -Verb RunAs"
"@
    $uninstallBat | Set-Content "$InstallPath\Uninstall.bat" -Encoding ASCII

    Write-Success "Application files installed to $InstallPath"
}

# Create shortcuts
function Install-Shortcuts {
    Write-Step "Creating shortcuts..."

    $WshShell = New-Object -ComObject WScript.Shell

    # Create Start Menu folder
    if (-not (Test-Path $StartMenuPath)) {
        New-Item -ItemType Directory -Path $StartMenuPath -Force | Out-Null
    }

    # Start Menu shortcut
    $startMenuShortcut = $WshShell.CreateShortcut("$StartMenuPath\$AppName.lnk")
    $startMenuShortcut.TargetPath = "$InstallPath\SSHFS Manager.bat"
    $startMenuShortcut.WorkingDirectory = $InstallPath
    $startMenuShortcut.Description = $AppDescription
    $startMenuShortcut.WindowStyle = 7  # Minimized
    $startMenuShortcut.Save()
    Write-Success "Start Menu shortcut created"

    # Start Menu uninstall shortcut
    $uninstallShortcut = $WshShell.CreateShortcut("$StartMenuPath\Uninstall $AppName.lnk")
    $uninstallShortcut.TargetPath = "$InstallPath\Uninstall.bat"
    $uninstallShortcut.WorkingDirectory = $InstallPath
    $uninstallShortcut.Description = "Uninstall $AppName"
    $uninstallShortcut.Save()
    Write-Success "Uninstall shortcut created"

    # Desktop shortcut
    $desktopShortcut = $WshShell.CreateShortcut($DesktopShortcut)
    $desktopShortcut.TargetPath = "$InstallPath\SSHFS Manager.bat"
    $desktopShortcut.WorkingDirectory = $InstallPath
    $desktopShortcut.Description = $AppDescription
    $desktopShortcut.WindowStyle = 7
    $desktopShortcut.Save()
    Write-Success "Desktop shortcut created"
}

# Register in Add/Remove Programs
function Register-Application {
    Write-Step "Registering application..."

    # Calculate installed size (in KB)
    $size = [math]::Round((Get-ChildItem $InstallPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1KB)

    # Create registry entry
    New-Item -Path $UninstallRegKey -Force | Out-Null

    Set-ItemProperty -Path $UninstallRegKey -Name "DisplayName" -Value $AppName
    Set-ItemProperty -Path $UninstallRegKey -Name "DisplayVersion" -Value $AppVersion
    Set-ItemProperty -Path $UninstallRegKey -Name "Publisher" -Value $AppPublisher
    Set-ItemProperty -Path $UninstallRegKey -Name "InstallLocation" -Value $InstallPath
    Set-ItemProperty -Path $UninstallRegKey -Name "UninstallString" -Value "`"$InstallPath\Uninstall.bat`""
    Set-ItemProperty -Path $UninstallRegKey -Name "QuietUninstallString" -Value "powershell -ExecutionPolicy Bypass -File `"$InstallPath\Uninstall.ps1`" -Silent"
    Set-ItemProperty -Path $UninstallRegKey -Name "DisplayIcon" -Value "$InstallPath\SSHFS Manager.bat"
    Set-ItemProperty -Path $UninstallRegKey -Name "EstimatedSize" -Value $size -Type DWord
    Set-ItemProperty -Path $UninstallRegKey -Name "NoModify" -Value 1 -Type DWord
    Set-ItemProperty -Path $UninstallRegKey -Name "NoRepair" -Value 1 -Type DWord

    Write-Success "Application registered in Windows"
}

# Main installation
function Main {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "    SSHFS Manager Installer v$AppVersion" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will install SSHFS Manager to:"
    Write-Host "  $InstallPath" -ForegroundColor Yellow
    Write-Host ""

    if (-not $Silent) {
        $confirm = Read-Host "Continue? (Y/N)"
        if ($confirm -notmatch "^[Yy]") {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            return
        }
    }

    try {
        Test-Prerequisites
        Install-Dependencies
        Install-AppFiles
        Install-Shortcuts
        Register-Application

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "    Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now:"
        Write-Host "  - Find '$AppName' in the Start Menu"
        Write-Host "  - Use the Desktop shortcut"
        Write-Host "  - Uninstall via Settings > Apps"
        Write-Host ""

        if (-not $Silent) {
            $launch = Read-Host "Launch SSHFS Manager now? (Y/N)"
            if ($launch -match "^[Yy]") {
                Start-Process "$InstallPath\SSHFS Manager.bat"
            }
        }
    }
    catch {
        Write-Fail $_.Exception.Message
        Write-Host "Installation failed. Please check the error above." -ForegroundColor Red
    }
}

Main
