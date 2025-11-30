@echo off
cls
echo ================================================
echo  SSHFS Connection Manager - GUI Launcher
echo ================================================
echo.
echo Starting SSHFS Manager...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sshfs-manager.ps1"

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to launch SSHFS Manager
    pause
)
