SSHFS Wizard Installer
=======================

1. Extract this ZIP somewhere (e.g. C:\Users\YourName\Downloads\SSHFS-Wizard).
2. Open PowerShell as Administrator.
3. Run:

   powershell -ExecutionPolicy Bypass -File .\install.ps1

4. Follow the prompts.

The installer will:
- Ensure WinFsp and SSHFS-Win are installed via winget.
- Ensure you have an SSH key (~/.ssh/id_ed25519).
- Configure passwordless SSH to your VPS (if not already configured).
- Create reconnect and unmount scripts under %USERPROFILE%\SSHFS.
- Create scheduled tasks to auto-mount on logon and unmount on logoff.
- Test the mount immediately.

By default it mounts your VPS home directory (/home/<user>) as drive X:.
