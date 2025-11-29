@echo off
cls
echo ================================================
echo  SSHFS-Wizard - Automated Installation Test
echo ================================================
echo.
echo This will install with ZERO prompts:
echo   Server: testuser@45.76.12.161
echo   Drive: Auto-detected (first available)
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"cd ''C:\Users\Racin\Code\Packages\sshfs-wizard''; .\install.ps1 -HostName 45.76.12.161 -User testuser; timeout /t 15; Read-Host ''''Installation finished. Press ENTER to close''''\"' -Verb RunAs"

echo.
echo Waiting for installation to complete...
timeout /t 20 >nul

echo.
echo ================================================
echo  Checking Results
echo ================================================
echo.

if exist "%USERPROFILE%\SSHFS\settings.json" (
    echo [SUCCESS] Configuration:
    type "%USERPROFILE%\SSHFS\settings.json"
    echo.
    echo Network drives:
    net use
    echo.
    echo Check File Explorer - your drive should be visible!
) else (
    echo [FAILED] Installation incomplete
)

pause
