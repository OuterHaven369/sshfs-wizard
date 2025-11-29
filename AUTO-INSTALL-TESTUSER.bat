@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File C:\Users\Racin\Code\Packages\sshfs-wizard\install.ps1 -HostName 45.76.12.161 -User testuser' -Verb RunAs"
timeout /t 60
echo.
echo Checking installation results...
if exist "%USERPROFILE%\SSHFS\settings.json" (
    echo [SUCCESS] Installation completed!
    type "%USERPROFILE%\SSHFS\settings.json"
    echo.
    net use | findstr /i "sshfs testuser"
) else (
    echo [PENDING] Check the elevated window for progress
)
pause
