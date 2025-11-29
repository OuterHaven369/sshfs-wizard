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

   **Option A: Double-click installer (Recommended)**
   - Double-click `INSTALL.bat`
   - Click "Yes" when prompted for administrator privileges

   **Option B: Via PowerShell**
   ```powershell
   Right-click PowerShell → Run as administrator
   cd C:\Users\YourName\Downloads\SSHFS-Wizard
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

3. **Follow the Prompts**
   - **Enter your server hostname or IP** (e.g., `45.76.12.161`, `myserver.com`)
   - **Enter your SSH username** (e.g., `myuser`, `admin`)
   - **Choose drive letter** - installer will auto-detect available drives and let you pick
   - Optionally specify remote path (default: home directory)

## Usage

### Command-Line Parameters (Optional)

You can run the installer with parameters to skip prompts:

```powershell
# Automatic drive selection (prompts for hostname and username)
.\install.ps1

# Pre-specify server and user (auto-detects drive)
.\install.ps1 -HostName "your-server.com" -User "yourusername"

# Specify everything including preferred drive
.\install.ps1 -HostName "192.168.1.100" -User "admin" -Drive "Y"
```

**Parameters:**
- `-HostName`: (Optional) VPS hostname or IP address - **prompts if not provided**
- `-User`: (Optional) SSH username on the VPS - **prompts if not provided**
- `-Drive`: (Optional) Preferred Windows drive letter. Auto-detects if not specified
- `-Interactive`: (Optional) Enable wizard mode with prompts. **Default is automated (no prompts)**

**Examples:**
```powershell
# Default: Automated mode - no drive prompts (perfect for AI/scripts)
.\install.ps1 -HostName "192.168.50.10" -User "admin"

# Wizard mode - interactive prompts for drive selection
.\install.ps1 -HostName "myserver.example.com" -User "john" -Interactive

# Specify exact drive (skips auto-detection entirely)
.\install.ps1 -HostName "vps.company.net" -User "developer" -Drive "Y"
```

### Smart Drive Selection

The installer automatically:
- Detects all available drive letters (D-Z)
- Auto-selects the first available drive if none specified
- Warns you if your preferred drive is in use and shows alternatives
- Allows you to choose a different drive during installation
- Never overwrites existing drive mappings

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

One Windows scheduled task is created:
- `SSHFS_Mount_X` - Runs on user logon (10-second delay)

**Note**: Auto-unmount on logoff is not created by default due to Windows compatibility issues. The drive will persist across sessions, which is generally more reliable. You can manually unmount anytime using the unmount script.

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
