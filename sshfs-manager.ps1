# SSHFS Manager - System Tray GUI for managing SSHFS connections on Windows
# Requires: WinFsp, SSHFS-Win

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Extract icon from shell32.dll
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

public class IconExtractor {
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr ExtractIcon(IntPtr hInst, string lpszExeFileName, int nIconIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);

    public static Icon GetIcon(int index) {
        IntPtr hIcon = ExtractIcon(IntPtr.Zero, "shell32.dll", index);
        if (hIcon != IntPtr.Zero) {
            Icon icon = Icon.FromHandle(hIcon);
            return (Icon)icon.Clone();
        }
        return null;
    }
}
"@ -ReferencedAssemblies System.Drawing

# Configuration paths
$script:ConfigPath = Join-Path $env:USERPROFILE "SSHFS\connections.json"
$script:LogsPath = Join-Path $env:USERPROFILE "SSHFS\logs"

# Ensure directories exist
$baseDir = Join-Path $env:USERPROFILE "SSHFS"
if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
if (-not (Test-Path $script:LogsPath)) { New-Item -ItemType Directory -Path $script:LogsPath | Out-Null }

# Load or create connections config
function Load-Connections {
    if (Test-Path $script:ConfigPath) {
        try {
            $content = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            return @($content)
        } catch {
            return @()
        }
    } else {
        return @()
    }
}

function Save-Connections {
    param($Connections)
    $Connections | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ConfigPath -Encoding UTF8
}

function Get-MountedDrives {
    $mounted = @{}

    # Parse net use output - handle SSHFS drives that have no status prefix
    $netOutput = cmd /c "net use" 2>$null
    $lines = $netOutput -split "`r?`n"

    foreach ($line in $lines) {
        # Match: "             E:        \\sshfs.k\user@host"
        # Or:    "OK           Z:        \\192.168.x.x\share"
        if ($line -match '^\s*(OK|Unavailable|Disconnected|)\s+([A-Z]:)\s+(\\\\[^\s]+)') {
            $drive = $matches[2]
            $remote = $matches[3].Trim()
            $mounted[$drive] = $remote
        }
    }

    return $mounted
}

function Get-ConnectionStatus {
    param([string]$HostName, [string]$User, [string]$Drive)

    $mounted = Get-MountedDrives
    $driveKey = "$($Drive.TrimEnd(':').ToUpper()):"

    if ($mounted.ContainsKey($driveKey)) {
        $remote = $mounted[$driveKey]
        if ($remote -like "*$User*" -and $remote -like "*$HostName*") {
            return "Connected"
        } elseif ($remote -like "*sshfs*") {
            return "Wrong Mount"
        }
    }
    return "Disconnected"
}

function Test-SSHConnection {
    param([string]$HostName, [string]$User)
    try {
        $result = ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$User@$HostName" "echo ok" 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Mount-SSHFSDrive {
    param([string]$HostName, [string]$User, [string]$Drive, [string]$RemotePath = "")

    $Drive = $Drive.TrimEnd(':').ToUpper()
    $prefix = "\\sshfs.k\\$User@$HostName"
    if ($RemotePath -and $RemotePath -ne "(home)") {
        $prefix += "\$RemotePath"
    }

    $proc = Start-Process -FilePath "sshfs-win.exe" -ArgumentList "svc", $prefix, "$($Drive):" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    return $true
}

function Dismount-SSHFSDrive {
    param([string]$Drive)
    $Drive = $Drive.TrimEnd(':').ToUpper()
    cmd /c "net use $($Drive): /delete /y" 2>&1 | Out-Null
    return $true
}

# System Tray Functions
function Create-TrayIcon {
    $script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon

    # Use network drive icon from shell32.dll (index 9 = network drive, 275 = cloud)
    try {
        $icon = [IconExtractor]::GetIcon(9)
        if ($icon) {
            $script:notifyIcon.Icon = $icon
        } else {
            $script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
        }
    } catch {
        $script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    }

    $script:notifyIcon.Text = "SSHFS Manager"
    $script:notifyIcon.Visible = $true

    # Context menu
    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $showItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $showItem.Text = "Open Manager"
    $showItem.Add_Click({ Show-MainWindow })
    $contextMenu.Items.Add($showItem) | Out-Null

    $contextMenu.Items.Add("-") | Out-Null

    $connectAllItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $connectAllItem.Text = "Connect All"
    $connectAllItem.Add_Click({ Connect-AllDrives })
    $contextMenu.Items.Add($connectAllItem) | Out-Null

    $disconnectAllItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $disconnectAllItem.Text = "Disconnect All"
    $disconnectAllItem.Add_Click({ Disconnect-AllDrives })
    $contextMenu.Items.Add($disconnectAllItem) | Out-Null

    $contextMenu.Items.Add("-") | Out-Null

    $script:startupItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $script:startupItem.Text = "Run at Startup"
    $script:startupItem.CheckOnClick = $true
    $script:startupItem.Checked = (Test-StartupEnabled)
    $script:startupItem.Add_Click({ Toggle-Startup $script:startupItem.Checked })
    $contextMenu.Items.Add($script:startupItem) | Out-Null

    $contextMenu.Items.Add("-") | Out-Null

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "Exit"
    $exitItem.Add_Click({ Exit-Application })
    $contextMenu.Items.Add($exitItem) | Out-Null

    $script:notifyIcon.ContextMenuStrip = $contextMenu
    $script:notifyIcon.Add_DoubleClick({ Show-MainWindow })
}

function Test-StartupEnabled {
    $startupPath = Join-Path ([Environment]::GetFolderPath("Startup")) "SSHFS-Manager.lnk"
    return (Test-Path $startupPath)
}

function Toggle-Startup {
    param([bool]$Enable)

    $startupPath = Join-Path ([Environment]::GetFolderPath("Startup")) "SSHFS-Manager.lnk"
    $targetPath = Join-Path $PSScriptRoot "SSHFS-MANAGER.bat"

    if ($Enable) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($startupPath)
        $shortcut.TargetPath = $targetPath
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.WindowStyle = 7
        $shortcut.Save()
        $script:notifyIcon.ShowBalloonTip(2000, "SSHFS Manager", "Will start automatically with Windows", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        if (Test-Path $startupPath) { Remove-Item $startupPath -Force }
        $script:notifyIcon.ShowBalloonTip(2000, "SSHFS Manager", "Removed from startup", [System.Windows.Forms.ToolTipIcon]::Info)
    }
}

function Connect-AllDrives {
    $connections = Load-Connections
    foreach ($conn in $connections) {
        $status = Get-ConnectionStatus -HostName $conn.Host -User $conn.User -Drive $conn.Drive
        if ($status -ne "Connected") {
            Mount-SSHFSDrive -HostName $conn.Host -User $conn.User -Drive $conn.Drive -RemotePath $conn.RemotePath
        }
    }
    if ($script:connectionGrid) { Refresh-ConnectionList }
    Update-TrayTooltip
}

function Disconnect-AllDrives {
    $connections = Load-Connections
    foreach ($conn in $connections) {
        $status = Get-ConnectionStatus -HostName $conn.Host -User $conn.User -Drive $conn.Drive
        if ($status -eq "Connected") {
            Dismount-SSHFSDrive -Drive $conn.Drive
        }
    }
    if ($script:connectionGrid) { Refresh-ConnectionList }
    Update-TrayTooltip
}

function Update-TrayTooltip {
    $connections = Load-Connections
    $connected = 0
    foreach ($conn in $connections) {
        $status = Get-ConnectionStatus -HostName $conn.Host -User $conn.User -Drive $conn.Drive
        if ($status -eq "Connected") { $connected++ }
    }
    $script:notifyIcon.Text = "SSHFS Manager - $connected/$($connections.Count) connected"
}

function Show-MainWindow {
    if ($script:window) {
        $script:window.Show()
        $script:window.WindowState = "Normal"
        $script:window.Activate()
    }
}

$script:isExiting = $false

function Exit-Application {
    $script:isExiting = $true
    if ($script:notifyIcon) {
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
    }
    if ($script:hiddenForm) {
        $script:hiddenForm.Close()
    }
    [System.Windows.Forms.Application]::Exit()
    [Environment]::Exit(0)
}

# XAML UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SSHFS Connection Manager" Height="500" Width="800"
        WindowStartupLocation="CenterScreen" Background="#F5F5F5">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="MinWidth" Value="100"/>
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
    </Window.Resources>

    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="SSHFS Connection Manager" FontSize="22" FontWeight="SemiBold"/>
            <TextBlock Text="Mount remote Linux directories as Windows drives" Foreground="#666" Margin="0,3,0,0"/>
        </StackPanel>

        <DataGrid Grid.Row="1" Name="ConnectionGrid" AutoGenerateColumns="False"
                  IsReadOnly="True" SelectionMode="Single" CanUserAddRows="False"
                  GridLinesVisibility="Horizontal" AlternatingRowBackground="#FAFAFA"
                  RowHeight="32" Background="White" BorderBrush="#DDD">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="130"/>
                <DataGridTextColumn Header="Host" Binding="{Binding Host}" Width="120"/>
                <DataGridTextColumn Header="User" Binding="{Binding User}" Width="90"/>
                <DataGridTextColumn Header="Drive" Binding="{Binding Drive}" Width="55"/>
                <DataGridTemplateColumn Header="Status" Width="110">
                    <DataGridTemplateColumn.CellTemplate>
                        <DataTemplate>
                            <TextBlock Text="{Binding Status}" Padding="5,0" FontWeight="SemiBold">
                                <TextBlock.Style>
                                    <Style TargetType="TextBlock">
                                        <Setter Property="Foreground" Value="#D83B01"/>
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding Status}" Value="Connected">
                                                <Setter Property="Foreground" Value="#107C10"/>
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </TextBlock.Style>
                            </TextBlock>
                        </DataTemplate>
                    </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTextColumn Header="Remote Path" Binding="{Binding RemotePath}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>

        <WrapPanel Grid.Row="2" Margin="0,12,0,0">
            <Button Name="BtnAdd" Content="+ Add"/>
            <Button Name="BtnEdit" Content="Edit" Background="#744DA9"/>
            <Button Name="BtnRemove" Content="Remove" Background="#C42B1C"/>
            <Button Name="BtnConnect" Content="Connect" Background="#107C10"/>
            <Button Name="BtnDisconnect" Content="Disconnect" Background="#5C5C5C"/>
            <Button Name="BtnRefresh" Content="Refresh"/>
        </WrapPanel>

        <Border Grid.Row="3" Background="#E5E5E5" Padding="10,6" Margin="0,12,0,0" CornerRadius="3">
            <Grid>
                <TextBlock Name="StatusText" Text="Ready"/>
                <TextBlock HorizontalAlignment="Right" Foreground="#888" Text="Click X to minimize to tray"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Create window
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$script:window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$script:connectionGrid = $script:window.FindName("ConnectionGrid")
$btnAdd = $script:window.FindName("BtnAdd")
$btnEdit = $script:window.FindName("BtnEdit")
$btnRemove = $script:window.FindName("BtnRemove")
$btnConnect = $script:window.FindName("BtnConnect")
$btnDisconnect = $script:window.FindName("BtnDisconnect")
$btnRefresh = $script:window.FindName("BtnRefresh")
$script:statusText = $script:window.FindName("StatusText")

function Refresh-ConnectionList {
    $connections = Load-Connections
    $displayList = @()

    foreach ($conn in $connections) {
        $status = Get-ConnectionStatus -HostName $conn.Host -User $conn.User -Drive $conn.Drive

        $displayList += [PSCustomObject]@{
            Name = $conn.Name
            Host = $conn.Host
            User = $conn.User
            Drive = "$($conn.Drive):"
            RemotePath = if ($conn.RemotePath) { $conn.RemotePath } else { "(home)" }
            Status = $status
        }
    }

    $script:connectionGrid.ItemsSource = $displayList
    $connected = ($displayList | Where-Object { $_.Status -eq "Connected" }).Count
    $script:statusText.Text = "$($connections.Count) connections - $connected connected"
    Update-TrayTooltip
}

# Add Connection
$btnAdd.Add_Click({
    $addXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Add Connection" Height="340" Width="420"
        WindowStartupLocation="CenterOwner" Background="#F5F5F5" ResizeMode="NoResize">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="100"/><ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Text="Name:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="0" Grid.Column="1" Name="TxtName" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="1" Text="Host/IP:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="1" Grid.Column="1" Name="TxtHost" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="2" Text="Username:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="2" Grid.Column="1" Name="TxtUser" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="3" Text="Drive:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="3" Grid.Column="1" Name="TxtDrive" Margin="0,8" Padding="6,4" MaxLength="1" Width="50" HorizontalAlignment="Left"/>

        <TextBlock Grid.Row="4" Text="Remote Path:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="4" Grid.Column="1" Name="TxtRemotePath" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="5" Grid.ColumnSpan="2" Foreground="#666" FontSize="11" Margin="0,10" TextWrapping="Wrap">
            Leave Remote Path empty to mount user's home directory.
        </TextBlock>

        <StackPanel Grid.Row="6" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnSave" Content="Save" Width="80" Background="#107C10" Foreground="White" Padding="8,4" Margin="4"/>
            <Button Name="BtnCancel" Content="Cancel" Width="80" Background="#5C5C5C" Foreground="White" Padding="8,4" Margin="4"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $addReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($addXaml))
    $addWindow = [Windows.Markup.XamlReader]::Load($addReader)
    $addWindow.Owner = $script:window

    $txtName = $addWindow.FindName("TxtName")
    $txtHost = $addWindow.FindName("TxtHost")
    $txtUser = $addWindow.FindName("TxtUser")
    $txtDrive = $addWindow.FindName("TxtDrive")
    $txtRemotePath = $addWindow.FindName("TxtRemotePath")
    $btnSave = $addWindow.FindName("BtnSave")
    $btnCancel = $addWindow.FindName("BtnCancel")

    $btnSave.Add_Click({
        if (-not $txtName.Text -or -not $txtHost.Text -or -not $txtUser.Text -or -not $txtDrive.Text) {
            [System.Windows.MessageBox]::Show("Fill in all required fields.", "Required", "OK", "Warning")
            return
        }

        $connections = @(Load-Connections)
        $connections += @{
            Name = $txtName.Text
            Host = $txtHost.Text
            User = $txtUser.Text
            Drive = $txtDrive.Text.ToUpper()
            RemotePath = $txtRemotePath.Text
        }
        Save-Connections $connections
        $addWindow.Close()
        Refresh-ConnectionList
        $script:statusText.Text = "Added: $($txtName.Text)"
    })

    $btnCancel.Add_Click({ $addWindow.Close() })
    $addWindow.ShowDialog()
})

# Edit Connection
$btnEdit.Add_Click({
    $selected = $script:connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Select a connection to edit.", "No Selection", "OK", "Warning")
        return
    }

    # Store original name to find and update the connection
    $originalName = $selected.Name

    $editXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Edit Connection" Height="340" Width="420"
        WindowStartupLocation="CenterOwner" Background="#F5F5F5" ResizeMode="NoResize">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="100"/><ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Text="Name:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="0" Grid.Column="1" Name="TxtName" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="1" Text="Host/IP:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="1" Grid.Column="1" Name="TxtHost" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="2" Text="Username:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="2" Grid.Column="1" Name="TxtUser" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="3" Text="Drive:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="3" Grid.Column="1" Name="TxtDrive" Margin="0,8" Padding="6,4" MaxLength="1" Width="50" HorizontalAlignment="Left"/>

        <TextBlock Grid.Row="4" Text="Remote Path:" VerticalAlignment="Center" Margin="0,8"/>
        <TextBox Grid.Row="4" Grid.Column="1" Name="TxtRemotePath" Margin="0,8" Padding="6,4"/>

        <TextBlock Grid.Row="5" Grid.ColumnSpan="2" Foreground="#666" FontSize="11" Margin="0,10" TextWrapping="Wrap">
            Leave Remote Path empty to mount user's home directory.
        </TextBlock>

        <StackPanel Grid.Row="6" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnSave" Content="Save" Width="80" Background="#744DA9" Foreground="White" Padding="8,4" Margin="4"/>
            <Button Name="BtnCancel" Content="Cancel" Width="80" Background="#5C5C5C" Foreground="White" Padding="8,4" Margin="4"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $editReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($editXaml))
    $editWindow = [Windows.Markup.XamlReader]::Load($editReader)
    $editWindow.Owner = $script:window

    $txtName = $editWindow.FindName("TxtName")
    $txtHost = $editWindow.FindName("TxtHost")
    $txtUser = $editWindow.FindName("TxtUser")
    $txtDrive = $editWindow.FindName("TxtDrive")
    $txtRemotePath = $editWindow.FindName("TxtRemotePath")
    $btnSave = $editWindow.FindName("BtnSave")
    $btnCancel = $editWindow.FindName("BtnCancel")

    # Pre-fill with existing values
    $txtName.Text = $selected.Name
    $txtHost.Text = $selected.Host
    $txtUser.Text = $selected.User
    $txtDrive.Text = $selected.Drive.TrimEnd(':')
    $txtRemotePath.Text = if ($selected.RemotePath -eq "(home)") { "" } else { $selected.RemotePath }

    $btnSave.Add_Click({
        if (-not $txtName.Text -or -not $txtHost.Text -or -not $txtUser.Text -or -not $txtDrive.Text) {
            [System.Windows.MessageBox]::Show("Fill in all required fields.", "Required", "OK", "Warning")
            return
        }

        $connections = @(Load-Connections)

        # Find and update the connection by original name
        for ($i = 0; $i -lt $connections.Count; $i++) {
            if ($connections[$i].Name -eq $originalName) {
                $connections[$i] = @{
                    Name = $txtName.Text
                    Host = $txtHost.Text
                    User = $txtUser.Text
                    Drive = $txtDrive.Text.ToUpper()
                    RemotePath = $txtRemotePath.Text
                }
                break
            }
        }

        Save-Connections $connections
        $editWindow.Close()
        Refresh-ConnectionList
        $script:statusText.Text = "Updated: $($txtName.Text)"
    })

    $btnCancel.Add_Click({ $editWindow.Close() })
    $editWindow.ShowDialog()
})

# Remove
$btnRemove.Add_Click({
    $selected = $script:connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Select a connection first.", "No Selection", "OK", "Warning")
        return
    }

    $result = [System.Windows.MessageBox]::Show("Remove '$($selected.Name)'?", "Confirm", "YesNo", "Question")
    if ($result -eq "Yes") {
        $connections = @(Load-Connections) | Where-Object { $_.Name -ne $selected.Name }
        Save-Connections @($connections)
        Refresh-ConnectionList
        $script:statusText.Text = "Removed: $($selected.Name)"
    }
})

# Connect
$btnConnect.Add_Click({
    $selected = $script:connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Select a connection first.", "No Selection", "OK", "Warning")
        return
    }

    if ($selected.Status -eq "Connected") {
        [System.Windows.MessageBox]::Show("Already connected.", "Info", "OK", "Information")
        return
    }

    $script:statusText.Text = "Connecting to $($selected.Host)..."
    $script:window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)

    $hostName = $selected.Host
    $userName = $selected.User
    $drive = $selected.Drive.TrimEnd(':')
    $remotePath = if ($selected.RemotePath -eq "(home)") { "" } else { $selected.RemotePath }

    # Test SSH first
    $sshOk = Test-SSHConnection -HostName $hostName -User $userName
    if (-not $sshOk) {
        [System.Windows.MessageBox]::Show("SSH failed. Check key authentication.", "SSH Error", "OK", "Error")
        $script:statusText.Text = "SSH failed"
        return
    }

    Mount-SSHFSDrive -HostName $hostName -User $userName -Drive $drive -RemotePath $remotePath
    Start-Sleep -Seconds 2
    Refresh-ConnectionList

    $newStatus = Get-ConnectionStatus -HostName $hostName -User $userName -Drive $drive
    if ($newStatus -eq "Connected") {
        $script:statusText.Text = "Connected: $($drive):"
    } else {
        $script:statusText.Text = "Mount may have failed"
    }
})

# Disconnect
$btnDisconnect.Add_Click({
    $selected = $script:connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Select a connection first.", "No Selection", "OK", "Warning")
        return
    }

    if ($selected.Status -ne "Connected") {
        [System.Windows.MessageBox]::Show("Not connected.", "Info", "OK", "Information")
        return
    }

    Dismount-SSHFSDrive -Drive $selected.Drive
    Start-Sleep -Seconds 1
    Refresh-ConnectionList
    $script:statusText.Text = "Disconnected: $($selected.Drive)"
})

# Refresh
$btnRefresh.Add_Click({ Refresh-ConnectionList })

# Minimize to tray on close - use proper event handler
$script:window.add_Closing({
    param($sender, $eventArgs)
    # If exiting, allow close; otherwise minimize to tray
    if (-not $script:isExiting) {
        $eventArgs.Cancel = $true
        $script:window.Hide()
        $script:window.ShowInTaskbar = $false
        $script:notifyIcon.ShowBalloonTip(1500, "SSHFS Manager", "Running in system tray. Right-click icon for menu.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})

# Initialize
Create-TrayIcon
Refresh-ConnectionList

# Create hidden form to keep app alive when WPF window is hidden
$script:hiddenForm = New-Object System.Windows.Forms.Form
$script:hiddenForm.WindowState = "Minimized"
$script:hiddenForm.ShowInTaskbar = $false
$script:hiddenForm.Opacity = 0
$script:hiddenForm.FormBorderStyle = "None"
$script:hiddenForm.Size = New-Object System.Drawing.Size(0, 0)

# Override Show-MainWindow to restore taskbar
function Show-MainWindow {
    if ($script:window) {
        $script:window.ShowInTaskbar = $true
        $script:window.Show()
        $script:window.WindowState = "Normal"
        $script:window.Activate()
    }
}

# Show WPF window
$script:window.Show()

# Run application loop with hidden form
[System.Windows.Forms.Application]::Run($script:hiddenForm)
