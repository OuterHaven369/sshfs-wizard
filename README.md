# SSHFS Wizard

A PowerShell-based automated installer for mounting remote Linux filesystems on Windows via SSHFS.

## What It Does

SSHFS Wizard automates the complete setup process for mounting remote Linux directories as Windows drive letters:

- **Automatic Dependency Installation**: Installs WinFsp and SSHFS-Win via winget
- **SSH Key Management**: Generates ed25519 SSH keys if needed
- **Passwordless Authentication**: Configures SSH key-based authentication to your VPS
- **Auto-Mount Scripts**: Creates reconnect and unmount scripts
- **Scheduled Tasks**: Automatically mounts on logon and unmounts on logoff
- **Connection Resilience**: Built-in retry logic with ping checks before mounting

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges
- winget (App Installer from Microsoft Store)
- Network access to your remote Linux server/VPS

## Installation

1. **Download and Extract**
   ```
   Extract SSHFS-Wizard.zip to a location like C:\Users\YourName\Downloads\SSHFS-Wizard
   ```

2. **Run as Administrator**
   ```powershell
   Right-click PowerShell → Run as administrator
   cd C:\Users\YourName\Downloads\SSHFS-Wizard
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

3. **Follow the Prompts**
   - Enter your VPS hostname or IP (e.g., `45.76.12.161`)
   - Enter your VPS username (e.g., `linuxuser`)
   - Choose drive letter (default: `X:`)
   - Optionally specify remote path (default: home directory)

## Usage

### Command-Line Parameters

```powershell
.\install.ps1 -Host "45.76.12.161" -User "linuxuser" -Drive "Z"
```

**Parameters:**
- `-Host`: VPS hostname or IP address
- `-User`: SSH username on the VPS
- `-Drive`: Windows drive letter to use (default: X)
- `-Auto`: Reserved for future automated installations

### What Gets Installed

The installer creates the following structure:

```
%USERPROFILE%\SSHFS\
├── settings.json              # Connection configuration
├── sshfs_reconnect.cmd        # Mount script
├── sshfs_unmount.cmd          # Unmount script
└── logs\
    ├── mount.log              # Mount operation logs
    └── unmount.log            # Unmount operation logs
```

### Scheduled Tasks

Two Windows scheduled tasks are created:
- `SSHFS_Mount_X` - Runs on user logon (10-second delay)
- `SSHFS_Unmount_X` - Runs on user logoff

### Manual Mount/Unmount

```cmd
# Mount manually
%USERPROFILE%\SSHFS\sshfs_reconnect.cmd

# Unmount manually
%USERPROFILE%\SSHFS\sshfs_unmount.cmd
```

## Troubleshooting

### Check Logs
```cmd
type %USERPROFILE%\SSHFS\logs\mount.log
type %USERPROFILE%\SSHFS\logs\unmount.log
```

### Verify Scheduled Tasks
```cmd
schtasks /Query /TN "SSHFS_Mount_X"
schtasks /Query /TN "SSHFS_Unmount_X"
```

### Test SSH Connection
```powershell
ssh user@host "echo ok"
```

### Common Issues

**"winget is not available"**
- Install "App Installer" from Microsoft Store

**"Passwordless SSH still not working"**
- Manually verify `~/.ssh/authorized_keys` permissions on the VPS (chmod 600)
- Check SSH server configuration allows key authentication

**"Mount command issued but drive not appearing"**
- Check if SSHFS-Win service is running: `Get-Service | Where-Object {$_.Name -like "*sshfs*"}`
- Verify firewall allows SSH connections (port 22)
- Check mount.log for specific errors

## Security Notes

- SSH keys are generated using ed25519 algorithm (modern, secure)
- Keys are stored in `%USERPROFILE%\.ssh\` with appropriate permissions
- No passwords are stored anywhere
- All authentication uses SSH key pairs

## Uninstallation

```powershell
# Remove scheduled tasks
schtasks /Delete /TN "SSHFS_Mount_X" /F
schtasks /Delete /TN "SSHFS_Unmount_X" /F

# Unmount drive
net use X: /delete /y

# Remove scripts and configuration
Remove-Item -Recurse -Force "$env:USERPROFILE\SSHFS"

# Optionally uninstall dependencies
winget uninstall SSHFS-Win.SSHFS-Win
winget uninstall WinFsp.WinFsp
```

## License

MIT License - See LICENSE file

## Contributing

Contributions welcome! Please open an issue or pull request on GitHub.

## Credits

- Built with WinFsp (https://winfsp.dev/)
- Uses SSHFS-Win (https://github.com/winfsp/sshfs-win)
