#Requires -RunAsAdministrator
<#
.SYNOPSIS
    SSHFS Manager Uninstaller
.DESCRIPTION
    Completely removes SSHFS Manager from the system including shortcuts and registry entries.
#>

param(
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

# App metadata
$AppName = "SSHFS Manager"
$AppGuid = "{7E5F8A12-3B4C-4D5E-9F6A-1B2C3D4E5F6A}"

# Paths
$InstallPath = "$env:ProgramFiles\SSHFS Manager"
$StartMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$AppName"
$DesktopShortcut = "$env:PUBLIC\Desktop\$AppName.lnk"
$UninstallRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppGuid"
$UserDataPath = "$env:USERPROFILE\SSHFS"

function Write-Step {
    param([string]$Message)
    Write-Host "`n[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Main {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "    SSHFS Manager Uninstaller" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""

    if (-not $Silent) {
        Write-Host "This will remove SSHFS Manager from your system."
        Write-Host ""
        $confirm = Read-Host "Continue? (Y/N)"
        if ($confirm -notmatch "^[Yy]") {
            Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
            return
        }

        Write-Host ""
        $removeData = Read-Host "Also remove saved connections and settings? (Y/N)"
    }

    Write-Step "Stopping SSHFS Manager if running..."
    Get-Process | Where-Object { $_.MainWindowTitle -like "*SSHFS*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Write-Step "Removing shortcuts..."
    if (Test-Path $StartMenuPath) {
        Remove-Item $StartMenuPath -Recurse -Force
        Write-Success "Start Menu shortcuts removed"
    }
    if (Test-Path $DesktopShortcut) {
        Remove-Item $DesktopShortcut -Force
        Write-Success "Desktop shortcut removed"
    }

    Write-Step "Removing registry entries..."
    if (Test-Path $UninstallRegKey) {
        Remove-Item $UninstallRegKey -Force
        Write-Success "Registry entries removed"
    }

    Write-Step "Removing application files..."
    # We need to remove files but the uninstaller is running from there
    # Schedule removal after script exits
    $batchFile = "$env:TEMP\sshfs-cleanup.bat"
    $batchContent = @"
@echo off
ping 127.0.0.1 -n 3 > nul
rd /s /q "$InstallPath" 2>nul
del "%~f0"
"@
    $batchContent | Set-Content $batchFile -Encoding ASCII

    if (-not $Silent -and $removeData -match "^[Yy]") {
        Write-Step "Removing user data..."
        if (Test-Path $UserDataPath) {
            Remove-Item $UserDataPath -Recurse -Force
            Write-Success "User data removed"
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "    Uninstallation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "SSHFS Manager has been removed from your system."
    Write-Host ""
    Write-Host "Note: WinFsp and SSHFS-Win were NOT removed."
    Write-Host "To remove them, use Settings > Apps."
    Write-Host ""

    # Start cleanup batch to remove install folder
    Start-Process $batchFile -WindowStyle Hidden

    if (-not $Silent) {
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

Main
