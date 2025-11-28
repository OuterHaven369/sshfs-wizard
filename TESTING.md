# SSHFS-Wizard Testing Documentation

## Testing Environment

- **OS**: Windows 10/11
- **PowerShell**: 5.1+
- **Test Server**: Linux VPS (45.76.12.161)
- **Test User**: testuser
- **Date**: November 28, 2025

## Tests Performed

### 1. Syntax Validation
**Status**: ✅ PASSED

```powershell
.\validate-syntax.ps1
```

**Result**: PowerShell syntax validation: PASSED

### 2. Parameter Validation
**Status**: ✅ PASSED

**Issues Found & Fixed**:
- **$Host Variable Collision**: The parameter name `$Host` conflicted with PowerShell's built-in `$Host` variable
  - **Fix**: Renamed to `$HostName` throughout the script
  - **Impact**: CRITICAL - installer would not run without this fix

### 3. Drive Letter Auto-Detection
**Status**: ✅ IMPLEMENTED

**Functionality**:
- Scans all used drive letters via `Get-PSDrive` and `Get-WmiObject Win32_LogicalDisk`
- Returns available drives D-Z
- Auto-selects first available if none specified
- Warns user if requested drive is in use
- Allows interactive selection during installation

**Test Code**:
```powershell
Get-AvailableDriveLetters
# Returns: D, E, F, G, H, ... (excluding used drives)
```

### 4. SSH Key Generation
**Status**: ✅ VERIFIED

- Uses ed25519 algorithm (modern, secure)
- Creates `%USERPROFILE%\.ssh\id_ed25519` if not exists
- Properly detects existing keys

### 5. SSH Authentication
**Status**: ✅ WORKING

```bash
ssh testuser@45.76.12.161 "echo ok"
# Result: Connection successful (passwordless)
```

- Public key successfully uploaded to VPS
- Passwordless authentication verified
- `authorized_keys` configured correctly

### 6. SSHFS Mount Functionality
**Status**: ✅ FUNCTIONAL

**Verification**:
```
net use
# Shows: X: \\sshfs.k\linuxuser@45.76.12.161 (WinFsp.Np)

ls /x/
# Successfully lists remote Linux filesystem
```

**Observed**:
- Drive mounts correctly via WinFsp
- Files are accessible and readable
- Connection is stable

### 7. Dependency Installation
**Status**: ✅ VERIFIED (Pre-installed)

```
winget list --id "WinFsp.WinFsp"
# Found: WinFsp 2025 (version 2.1.25156)

winget list --id "SSHFS-Win.SSHFS-Win"
# Found: SSHFS-Win 2021 x64 (version 3.5.20357)
```

## Known Issues

### Issue 1: UAC Elevation Required
**Severity**: Expected Behavior
**Description**: Installer must run as Administrator to:
- Install software via winget
- Create scheduled tasks

**Workaround**: Right-click PowerShell → "Run as administrator"

### Issue 2: Drive Letter Conflicts
**Severity**: LOW (Now handled)
**Description**: Previous versions would fail if drive letter was in use
**Resolution**: Implemented smart drive selection with auto-detection

## Test Scripts Created

1. **validate-syntax.ps1** - PowerShell syntax checker
2. **check-installation.ps1** - Post-installation verification
3. **FINAL-TEST.bat** - Automated test harness with auto-drive selection
4. **QUICK-TEST.bat** - Manual drive specification test

## Recommendations for Users

1. **Before Installation**:
   - Ensure you have VPS/server credentials
   - Check network connectivity to server
   - Note any drive letters already in use

2. **During Installation**:
   - Approve UAC prompt when requested
   - Select preferred drive letter or accept auto-selected
   - Enter server password once if SSH key not configured

3. **After Installation**:
   - Verify drive appears in File Explorer
   - Check scheduled tasks in Task Scheduler
   - Test mount survives logoff/logon cycle

## Regression Testing Checklist

Before each release, verify:

- [ ] PowerShell syntax validation passes
- [ ] Script runs with `-HostName`, `-User`, `-Drive` parameters
- [ ] Script runs without parameters (prompts for input)
- [ ] Auto-drive detection finds available drives
- [ ] Warning displayed when preferred drive is in use
- [ ] SSH key generation works (when key doesn't exist)
- [ ] SSH key detection works (when key exists)
- [ ] Passwordless SSH configuration succeeds
- [ ] Mount scripts are created correctly
- [ ] Scheduled tasks are created
- [ ] Drive mounts successfully
- [ ] Files are accessible on mounted drive
- [ ] Unmount script works
- [ ] Logs are created in correct location

## Future Testing Needs

- [ ] Test on fresh Windows installation
- [ ] Test with multiple simultaneous SSHFS mounts
- [ ] Test custom remote path mounting (not just home directory)
- [ ] Test with various SSH server configurations
- [ ] Test scheduled task execution on actual logon/logoff
- [ ] Test error handling when VPS is unreachable
- [ ] Test behavior with slow/unstable connections
