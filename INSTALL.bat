@echo off
cls
echo ================================================
echo           SSHFS-Wizard Installer
echo ================================================
echo.
echo This installer will:
echo   - Prompt you for your server IP/hostname
echo   - Prompt you for your SSH username
echo   - Auto-detect available drive letters
echo   - Let you choose which drive to use
echo   - Set up automatic mounting on login
echo.
echo Requirements:
echo   - Administrator privileges (will prompt)
echo   - SSH access to a remote Linux server
echo.
echo ================================================
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"Set-Location ''%~dp0''; Write-Host ''=== SSHFS-Wizard Installer ===' -ForegroundColor Cyan; Write-Host ''''; .\install.ps1; Write-Host ''''; Write-Host ''Installation finished.' -ForegroundColor Green; Write-Host ''''; Read-Host ''''Press ENTER to close''''\"' -Verb RunAs"

echo.
echo Installation window opened. Follow the prompts in the elevated window.
echo.
timeout /t 5 >nul

echo Checking installation results...
timeout /t 5 >nul

if exist "%USERPROFILE%\SSHFS\settings.json" (
    echo.
    echo ================================================
    echo  Installation Successful!
    echo ================================================
    echo.
    echo Configuration:
    type "%USERPROFILE%\SSHFS\settings.json"
    echo.
    echo.
    echo Check File Explorer - your SSHFS drive should be visible in "This PC"
    echo.
) else (
    echo.
    echo [!] Installation may not have completed
    echo     Check the installer window for details
    echo.
)

pause
