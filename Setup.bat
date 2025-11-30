@echo off
:: SSHFS Manager Setup
:: Run this file to install SSHFS Manager on your system

echo.
echo  ========================================
echo     SSHFS Manager Setup
echo  ========================================
echo.
echo  This will install SSHFS Manager to your system.
echo  You will be prompted for administrator privileges.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0installer\Install-SSHFSManager.ps1\"' -Verb RunAs -Wait"
