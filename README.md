# SSHFS Manager

A Windows application for mounting remote Linux filesystems as local drives via SSHFS. Features a modern GUI with system tray integration.

## Features

- **Graphical Connection Manager** - Modern Windows GUI for managing connections
- **System Tray Integration** - Runs quietly in the background with quick-access menu
- **Multiple Connections** - Manage multiple SSHFS mounts simultaneously
- **One-Click Connect/Disconnect** - Simple drive management
- **Auto-Start Option** - Launch automatically on Windows startup
- **Proper Windows Integration** - Appears in Start Menu and Add/Remove Programs
- **Placeholder Examples** - Input fields show examples for easy setup

## Installation

### Quick Install (Recommended)

1. **Download** the latest release or clone the repository
2. **Double-click `Setup.bat`**
3. **Click Yes** when prompted for administrator privileges
4. **Follow the on-screen prompts**

The installer automatically:
- Installs dependencies (WinFsp, SSHFS-Win) via winget
- Copies application to `C:\Program Files\SSHFS Manager`
- Creates Start Menu shortcuts
- Creates Desktop shortcut
- Registers in Windows **Add/Remove Programs**

### After Installation

Find **SSHFS Manager** in:
- Start Menu → SSHFS Manager
- Desktop shortcut
- System tray (after first launch)

## Uninstallation

**Option 1: Windows Settings**
1. Open **Settings** → **Apps** → **Apps & features**
2. Search for "SSHFS Manager"
3. Click **Uninstall**

**Option 2: Start Menu**
- Start Menu → SSHFS Manager → Uninstall SSHFS Manager

## Usage

### Adding a Connection

1. Click **+ Add** button
2. Fill in the connection details (placeholder examples shown):
   - **Name**: A friendly name (e.g., "My VPS Server")
   - **Host/IP**: Server address (e.g., "192.168.1.100")
   - **Username**: SSH username (e.g., "linuxuser")
   - **Drive**: Drive letter to mount (e.g., "X")
   - **Remote Path**: Path to mount (leave empty for home directory)
3. Click **Save**

### Connecting a Drive

1. Select a connection from the list
2. Click **Connect**
3. Status changes to "Connected" (green)
4. Drive appears in File Explorer

### Editing a Connection

1. Select the connection
2. Click **Edit**
3. Modify any fields
4. Click **Save**

### System Tray

The app minimizes to the system tray when you click X.

- **Double-click** tray icon → Open manager window
- **Right-click** tray icon → Quick actions menu:
  - Open Manager
  - Connect All
  - Disconnect All
  - Run at Startup (toggle)
  - Exit

## Prerequisites

The installer handles these automatically:

- Windows 10/11
- [WinFsp](https://winfsp.dev/) - Windows File System Proxy
- [SSHFS-Win](https://github.com/winfsp/sshfs-win) - SSHFS for Windows
- SSH key authentication configured for your servers

## SSH Key Setup

If you don't have SSH keys configured:

```powershell
# Generate SSH key
ssh-keygen -t ed25519

# Copy to server (replace user@host)
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh user@host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

## Project Structure

```
sshfs-wizard/
├── Setup.bat                      # Installer launcher (double-click this)
├── installer/
│   ├── Install-SSHFSManager.ps1   # Windows installer
│   └── Uninstall-SSHFSManager.ps1 # Uninstaller
├── src/
│   ├── sshfs-manager.ps1          # Main GUI application
│   └── sshfs-setup.ps1            # CLI setup tool
├── assets/                        # Icons and images
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## Configuration

User data is stored in:
```
%USERPROFILE%\SSHFS\
├── connections.json    # Saved connections
├── settings.json       # Mount settings
└── logs\               # Operation logs
```

## Troubleshooting

### Drive not appearing in File Explorer
- Verify SSH connection: `ssh user@host`
- Check WinFsp service is running
- Try Disconnect then Connect again
- Check logs in `%USERPROFILE%\SSHFS\logs\`

### SSH connection fails
- Ensure SSH key is set up correctly
- Verify server is reachable: `ping hostname`
- Check firewall allows port 22

### App won't start
- Try running as Administrator
- Check Windows Event Viewer for errors
- Reinstall using Setup.bat

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

Contributions welcome! Please open an issue or pull request.

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## Credits

- Built with [WinFsp](https://winfsp.dev/)
- Uses [SSHFS-Win](https://github.com/winfsp/sshfs-win)
