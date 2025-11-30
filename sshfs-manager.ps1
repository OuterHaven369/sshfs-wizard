# SSHFS Manager - GUI for managing SSHFS connections on Windows
# Requires: WinFsp, SSHFS-Win

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Configuration file path
$script:ConfigPath = Join-Path $env:USERPROFILE "SSHFS\connections.json"
$script:LogsPath = Join-Path $env:USERPROFILE "SSHFS\logs"

# Ensure directories exist
$baseDir = Join-Path $env:USERPROFILE "SSHFS"
if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
if (-not (Test-Path $script:LogsPath)) { New-Item -ItemType Directory -Path $script:LogsPath | Out-Null }

# Load or create connections config
function Load-Connections {
    if (Test-Path $script:ConfigPath) {
        $content = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        return $content
    } else {
        return @()
    }
}

function Save-Connections {
    param($Connections)
    $Connections | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
}

function Get-MountedDrives {
    $mounted = @{}
    $netUse = net use 2>$null | Select-String "^\s*(OK|Unavailable|Disconnected)?\s+([A-Z]:)\s+(.+?)\s+(WinFsp\.Np|Microsoft)"
    foreach ($line in $netUse) {
        if ($line -match '\s([A-Z]:)\s+(.+?)\s+') {
            $drive = $matches[1]
            $remote = $matches[2].Trim()
            $mounted[$drive] = $remote
        }
    }
    return $mounted
}

function Test-SSHConnection {
    param([string]$Host, [string]$User)
    try {
        $result = ssh -o ConnectTimeout=3 -o BatchMode=yes "$User@$Host" "echo ok" 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Mount-SSHFSDrive {
    param([string]$Host, [string]$User, [string]$Drive, [string]$RemotePath = "")

    $Drive = $Drive.TrimEnd(':')
    $remotePrefix = "\sshfs.k\$User@$Host"
    if ($RemotePath) {
        $remotePrefix += "\$RemotePath"
    }

    $result = cmd /c "sshfs-win.exe svc \\sshfs.k\\$User@$Host $($Drive): 2>&1"
    return ($LASTEXITCODE -eq 0)
}

function Dismount-SSHFSDrive {
    param([string]$Drive)
    $Drive = $Drive.TrimEnd(':')
    net use "$($Drive):" /delete /y 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# XAML UI Definition
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SSHFS Connection Manager" Height="600" Width="900"
        WindowStartupLocation="CenterScreen" Background="#F0F0F0">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="MinWidth" Value="100"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="5"/>
            <Setter Property="Margin" Value="5,2"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Padding" Value="5,5,5,2"/>
        </Style>
    </Window.Resources>

    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Title -->
        <TextBlock Grid.Row="0" Text="SSHFS Connection Manager" FontSize="20" FontWeight="Bold" Margin="0,0,0,10"/>

        <!-- Connection List -->
        <DataGrid Grid.Row="1" Name="ConnectionGrid" AutoGenerateColumns="False"
                  IsReadOnly="True" SelectionMode="Single" CanUserAddRows="False"
                  GridLinesVisibility="Horizontal" AlternatingRowBackground="#F9F9F9">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="150"/>
                <DataGridTextColumn Header="Host" Binding="{Binding Host}" Width="150"/>
                <DataGridTextColumn Header="User" Binding="{Binding User}" Width="100"/>
                <DataGridTextColumn Header="Drive" Binding="{Binding Drive}" Width="60"/>
                <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="100"/>
                <DataGridTextColumn Header="Remote Path" Binding="{Binding RemotePath}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,10,0,0">
            <Button Name="BtnAdd" Content="➕ Add New"/>
            <Button Name="BtnEdit" Content="✏️ Edit"/>
            <Button Name="BtnRemove" Content="🗑️ Remove"/>
            <Button Name="BtnConnect" Content="🔌 Connect"/>
            <Button Name="BtnDisconnect" Content="⏏️ Disconnect"/>
            <Button Name="BtnRefresh" Content="🔄 Refresh"/>
        </StackPanel>

        <!-- Status Bar -->
        <Border Grid.Row="3" Background="#E0E0E0" Padding="5" Margin="0,10,0,0">
            <TextBlock Name="StatusText" Text="Ready"/>
        </Border>
    </Grid>
</Window>
"@

# Create and show window
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$connectionGrid = $window.FindName("ConnectionGrid")
$btnAdd = $window.FindName("BtnAdd")
$btnEdit = $window.FindName("BtnEdit")
$btnRemove = $window.FindName("BtnRemove")
$btnConnect = $window.FindName("BtnConnect")
$btnDisconnect = $window.FindName("BtnDisconnect")
$btnRefresh = $window.FindName("BtnRefresh")
$statusText = $window.FindName("StatusText")

# Load connections into grid
function Refresh-ConnectionList {
    $connections = Load-Connections
    $mounted = Get-MountedDrives

    $displayList = @()
    foreach ($conn in $connections) {
        $status = "Disconnected"
        $drive = "$($conn.Drive):"

        if ($mounted.ContainsKey($drive)) {
            $expectedRemote = "\\sshfs.k\$($conn.User)@$($conn.Host)"
            if ($mounted[$drive] -like "*$($conn.User)*$($conn.Host)*") {
                $status = "✅ Connected"
            }
        }

        $displayList += [PSCustomObject]@{
            Name = $conn.Name
            Host = $conn.Host
            User = $conn.User
            Drive = $conn.Drive
            RemotePath = if ($conn.RemotePath) { $conn.RemotePath } else { "(home)" }
            Status = $status
        }
    }

    $connectionGrid.ItemsSource = $displayList
    $statusText.Text = "Loaded $($connections.Count) connection(s)"
}

# Add New Connection Dialog
$btnAdd.Add_Click({
    $addXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Add SSHFS Connection" Height="400" Width="500"
        WindowStartupLocation="CenterScreen" Background="#F0F0F0">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Label Grid.Row="0" Content="Connection Name:"/>
        <TextBox Grid.Row="0" Name="TxtName" Margin="0,25,0,5"/>

        <Label Grid.Row="1" Content="Host (IP or hostname):"/>
        <TextBox Grid.Row="1" Name="TxtHost" Margin="0,25,0,5"/>

        <Label Grid.Row="2" Content="Username:"/>
        <TextBox Grid.Row="2" Name="TxtUser" Margin="0,25,0,5"/>

        <Label Grid.Row="3" Content="Drive Letter (e.g., X):"/>
        <TextBox Grid.Row="3" Name="TxtDrive" Margin="0,25,0,5" MaxLength="1"/>

        <Label Grid.Row="4" Content="Remote Path (optional, default: home):"/>
        <TextBox Grid.Row="4" Name="TxtRemotePath" Margin="0,25,0,5"/>

        <TextBlock Grid.Row="5" Margin="0,10" TextWrapping="Wrap" Foreground="#666">
            Note: SSH key authentication must be configured. Run install.ps1 first if needed.
        </TextBlock>

        <StackPanel Grid.Row="7" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="BtnSave" Content="💾 Save" IsDefault="True"/>
            <Button Name="BtnCancel" Content="❌ Cancel" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $addReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($addXaml))
    $addWindow = [Windows.Markup.XamlReader]::Load($addReader)

    $txtName = $addWindow.FindName("TxtName")
    $txtHost = $addWindow.FindName("TxtHost")
    $txtUser = $addWindow.FindName("TxtUser")
    $txtDrive = $addWindow.FindName("TxtDrive")
    $txtRemotePath = $addWindow.FindName("TxtRemotePath")
    $btnSave = $addWindow.FindName("BtnSave")
    $btnCancel = $addWindow.FindName("BtnCancel")

    $btnSave.Add_Click({
        if (-not $txtName.Text -or -not $txtHost.Text -or -not $txtUser.Text -or -not $txtDrive.Text) {
            [System.Windows.MessageBox]::Show("Please fill in all required fields.", "Validation Error", "OK", "Warning")
            return
        }

        $connections = Load-Connections
        $newConn = @{
            Name = $txtName.Text
            Host = $txtHost.Text
            User = $txtUser.Text
            Drive = $txtDrive.Text.ToUpper()
            RemotePath = $txtRemotePath.Text
        }

        $connections += $newConn
        Save-Connections $connections

        $addWindow.Close()
        Refresh-ConnectionList
        $statusText.Text = "Added connection: $($txtName.Text)"
    })

    $btnCancel.Add_Click({ $addWindow.Close() })

    $addWindow.ShowDialog()
})

# Remove Connection
$btnRemove.Add_Click({
    $selected = $connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a connection to remove.", "No Selection", "OK", "Warning")
        return
    }

    $result = [System.Windows.MessageBox]::Show(
        "Remove connection '$($selected.Name)'?",
        "Confirm Remove",
        "YesNo",
        "Question"
    )

    if ($result -eq "Yes") {
        $connections = Load-Connections
        $connections = $connections | Where-Object { $_.Name -ne $selected.Name }
        Save-Connections $connections
        Refresh-ConnectionList
        $statusText.Text = "Removed connection: $($selected.Name)"
    }
})

# Connect
$btnConnect.Add_Click({
    $selected = $connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a connection to connect.", "No Selection", "OK", "Warning")
        return
    }

    $statusText.Text = "Testing SSH connection to $($selected.Host)..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)

    $sshTest = Test-SSHConnection -Host $selected.Host -User $selected.User
    if (-not $sshTest) {
        [System.Windows.MessageBox]::Show(
            "SSH connection test failed. Please ensure SSH key authentication is configured.",
            "Connection Failed",
            "OK",
            "Error"
        )
        $statusText.Text = "SSH test failed for $($selected.Host)"
        return
    }

    $statusText.Text = "Mounting $($selected.Drive): ..."
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)

    $remotePath = if ($selected.RemotePath -eq "(home)") { "" } else { $selected.RemotePath }
    $success = Mount-SSHFSDrive -Host $selected.Host -User $selected.User -Drive $selected.Drive -RemotePath $remotePath

    if ($success) {
        $statusText.Text = "Connected: $($selected.Drive): → $($selected.User)@$($selected.Host)"
    } else {
        [System.Windows.MessageBox]::Show(
            "Mount failed. Check logs at $script:LogsPath",
            "Mount Error",
            "OK",
            "Error"
        )
        $statusText.Text = "Mount failed for $($selected.Drive):"
    }

    Refresh-ConnectionList
})

# Disconnect
$btnDisconnect.Add_Click({
    $selected = $connectionGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("Please select a connection to disconnect.", "No Selection", "OK", "Warning")
        return
    }

    if ($selected.Status -notlike "*Connected*") {
        [System.Windows.MessageBox]::Show("This connection is not currently mounted.", "Not Connected", "OK", "Information")
        return
    }

    $success = Dismount-SSHFSDrive -Drive $selected.Drive
    if ($success) {
        $statusText.Text = "Disconnected: $($selected.Drive):"
    } else {
        $statusText.Text = "Failed to disconnect $($selected.Drive):"
    }

    Refresh-ConnectionList
})

# Refresh
$btnRefresh.Add_Click({
    Refresh-ConnectionList
})

# Initial load
Refresh-ConnectionList

# Show window
$window.ShowDialog() | Out-Null
