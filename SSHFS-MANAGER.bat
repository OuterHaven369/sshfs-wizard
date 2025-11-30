@echo off
:: Launch SSHFS Manager with hidden PowerShell window
start "" /b powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0sshfs-manager.ps1"
