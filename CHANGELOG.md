# Changelog

All notable changes to SSHFS-Wizard will be documented in this file.

## [1.0.2] - 2025-11-28

### Added
- **NonInteractive mode** for AI agents and automation
  - New `-NonInteractive` flag skips all prompts
  - Auto-selects first available drive without user input
  - Perfect for unattended installations and AI automation

### Changed
- Default `-Drive` parameter changed from "X" to empty string (auto-detect)
- Removed deprecated `-Auto` parameter (replaced with `-NonInteractive`)

### Use Case
```powershell
# AI can now run fully automated
.\install.ps1 -HostName "server.com" -User "admin" -NonInteractive
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
