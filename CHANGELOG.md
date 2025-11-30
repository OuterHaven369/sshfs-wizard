# Changelog

All notable changes to SSHFS Manager will be documented in this file.

## [1.3.0] - 2025-11-30

### Added - Production Release
- **Proper Windows Installer**
  - `Setup.bat` for one-click installation
  - Installs to `C:\Program Files\SSHFS Manager`
  - Creates Start Menu folder with shortcuts
  - Creates Desktop shortcut
  - Registers in Windows Add/Remove Programs
  - Full uninstaller support

### Changed
- **Project Restructure**
  - Moved source files to `src/` directory
  - Created `installer/` directory for install scripts
  - Cleaned up old test files
  - Professional folder structure

### Features
- Uninstall via Windows Settings → Apps
- Uninstall via Start Menu shortcut
- Silent install option (`-Silent` flag)
- Custom install path option
- Automatic dependency installation (WinFsp, SSHFS-Win)

## [1.2.3] - 2025-11-30

### Added
- Placeholder examples in Add/Edit dialogs
- Hidden PowerShell console (no window appears)

## [1.2.2] - 2025-11-30

### Added
- Edit button to modify existing connections
- Pre-filled edit form with current values

## [1.2.1] - 2025-11-30

### Fixed
- Minimize to tray now works correctly
- Network drive icon from shell32.dll

## [1.2.0] - 2025-11-30

### Added
- System tray icon with context menu
- Minimize to tray on close
- Run at Startup option
- Connect All / Disconnect All from tray

### Fixed
- Drive status detection for SSHFS mounts

## [1.1.0] - 2025-11-30

### Added - MAJOR FEATURE
- **Graphical Connection Manager (sshfs-manager.ps1)**
  - Modern WPF-based GUI for managing SSHFS connections
  - View all connections with live status indicators (Connected/Disconnected)
  - Add/Edit/Remove connections through user-friendly forms
  - Connect/Disconnect drives with one-click buttons
  - Real-time status updates showing mounted drives
  - Persistent connection storage in %USERPROFILE%\SSHFS\connections.json
  - SSHFS-MANAGER.bat launcher for easy double-click access

### Features
- **Connection List DataGrid**: Displays Name, Host, User, Drive, Status, Remote Path
- **Add New Connection**: Form with fields for all connection parameters
- **Remove Connection**: Delete saved connections
- **Connect Button**: Mount selected connection with SSH test beforehand
- **Disconnect Button**: Unmount active drives
- **Refresh Button**: Update connection status display
- **Status Bar**: Real-time feedback for all operations

### User Experience
- No command-line knowledge required
- Works on Windows 10/11 with native WPF
- Automatically detects mounted vs unmounted drives
- SSH connectivity test before attempting mount
- Clear error messages for troubleshooting

## [1.0.3] - 2025-11-28

### Fixed - CRITICAL
- **Mount command now uses correct UNC path syntax**
  - Changed from double backslash (`\\sshfs.k\\`) to single backslash (`\sshfs.k\`)
  - This was preventing drives from mounting correctly in Windows File Explorer
  - Fixes "Cannot create WinFsp-FUSE file system" error
  - Drive now properly appears and is accessible in File Explorer

### Technical Details
- sshfs-win.exe requires single backslash in UNC paths per WinFsp documentation
- Previous double backslash syntax caused WinFsp service initialization failures
- Verified working with live VPS connection test

## [1.0.2] - 2025-11-28

### Changed - BREAKING
- **Default behavior is now automated (no prompts)**
  - Installer auto-selects first available drive by default
  - Use `-Interactive` flag to enable wizard mode with prompts
  - Better for AI agents and automation (zero-config by default)

### Added
- **Interactive mode** flag (`-Interactive`) for wizard experience
  - Prompts user to select from available drives
  - Optional - default is fully automated

### Removed
- Removed `-NonInteractive` flag (now the default behavior)
- Removed deprecated `-Auto` parameter

### Use Cases
```powershell
# Default: Automated (AI-friendly)
.\install.ps1 -HostName "server.com" -User "admin"

# Wizard mode (user-friendly)
.\install.ps1 -HostName "server.com" -User "admin" -Interactive
```

## [1.0.1] - 2025-11-28

### Bug Fixes
- **CRITICAL**: Fixed drive detection not recognizing network/SSHFS mounts
  - Enhanced `Get-AvailableDriveLetters` to parse `net use` output
  - Now correctly detects drives mounted via WinFsp, SSHFS, and network shares
  - Prevents mounting conflicts with existing drives
- **Fixed**: Removed auto-unmount on logoff task due to Windows compatibility issues
  - ONLOGOFF schedule type has inconsistent support across Windows versions
  - Persistent mounts are more reliable and user-friendly
  - Manual unmount script still provided

### Changed
- Auto-unmount on logoff removed (now optional via manual task creation)
- Drive persistence across sessions is now the default behavior

## [1.0.0] - 2025-11-28

### Initial Release

#### Features
- **Automated SSHFS Setup**: One-command installation of complete SSHFS environment on Windows
- **Dependency Management**: Automatic installation of WinFsp and SSHFS-Win via winget
- **SSH Key Management**: Generates ed25519 SSH keys if not present
- **Passwordless Authentication**: Automatically configures SSH key-based authentication
- **Smart Drive Selection**:
  - Auto-detects available drive letters (D-Z)
  - Allows manual drive selection
  - Warns if preferred drive is in use
  - Never overwrites existing mappings
- **Scheduled Tasks**: Auto-mount on logon, auto-unmount on logoff
- **Connection Resilience**: Built-in ping checks and retry logic before mounting
- **Comprehensive Logging**: Mount and unmount operations logged for troubleshooting

#### Bug Fixes (Pre-release)
- **CRITICAL**: Fixed `$Host` parameter name collision with PowerShell built-in variable (renamed to `$HostName`)
- Fixed PowerShell variable interpolation in embedded CMD scripts (used `${Drive}:` notation)

#### Technical Details
- PowerShell 5.1+ compatible
- Requires Windows 10/11
- Requires Administrator privileges for installation
- Uses WinFsp 2025 and SSHFS-Win 2021+

#### Files Included
- `install.ps1` - Main installer script
- `README.md` - Comprehensive documentation
- `LICENSE` - MIT License
- `README.txt` - Quick start guide
- `validate-syntax.ps1` - Syntax validation utility

### Testing
- Syntax validation: PASSED
- Live VPS connection test: VERIFIED (45.76.12.161)
- SSH key authentication: WORKING
- Drive mounting: FUNCTIONAL

### Known Limitations
- Windows only (uses WinFsp)
- Currently mounts home directory only (custom paths in development)
- Requires administrator rights for installation
