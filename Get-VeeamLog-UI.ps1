#Requires -Version 5.1
<#
================================================================================
  Silver Robot  --  Silver Robot -- Veeam Log Viewer  --  Native Windows WPF GUI
  Version : 2.1
  Author  : Affan
  Date    : 2026-03-05
================================================================================

MIT License

Copyright (c) 2026 Affan | https://affan.info

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

================================================================================
  DESCRIPTION
================================================================================

  A native Windows WPF GUI for browsing and tailing Veeam Backup log files.
  Covers both the main Backup folder and the Rescan subfolder.

  Search roots scanned at startup:
    C:\ProgramData\Veeam\Backup\           -- job logs, agent logs, session logs
    C:\ProgramData\Veeam\Backup\Rescan\    -- per-host rescan logs

================================================================================
  FEATURES
================================================================================

  3-Pane Layout
  -------------
    Left   : Folder tree grouped by source (Backup / Rescan).
             Click any node to load its log files.
    Middle : Log files sorted newest-first with size and age.
             Click a file to open it in the viewer.
    Right  : Colour-coded log content viewer.

  Toolbar Controls
  ----------------
    Search box    Search folders by IP address or hostname fragment.
                  Supports partial matches (e.g. "10.0.4" or "AD").
                  Press Enter or click the Search button.

    Filter box    Filter visible log lines by keyword.
                  Matching lines are highlighted with a yellow background.
                  Press Enter or click Filter. Click X to clear.

    Lines         Number of lines to load from the end of the file (default 100).

    Follow        Real-time tail mode. Polls the file every 800 ms using a raw
                  FileStream so it works while Veeam holds the file open.
                  Handles log rotation (file truncation) automatically.
                  Toggle ON/OFF with the Follow button (turns green when active).

    Reload        Re-read the current file from scratch.

  Colour Coding
  -------------
    Red     ERROR / EXCEPTION / FAILED / FAILURE / CRITICAL
    Orange  WARNING
    Green   SUCCESS / SUCCEEDED / COMPLETED / FINISH
    Cyan    INFO / START / BEGIN / INIT / CONNECT
    White   Everything else

================================================================================
  REQUIREMENTS
================================================================================

    Windows PowerShell 5.1 or later  (pre-installed on Windows 10 / 2016+)
    .NET Framework 4.5+              (pre-installed on Windows 10 / 2016+)
    WPF assemblies                   (included with .NET Framework)
    Veeam Backup & Replication       (log path must exist)

  No third-party modules required.

================================================================================
  USAGE
================================================================================

    # Open the GUI with no pre-filter
    powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1

    # Pre-fill the search box with an IP or hostname
    powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1 -Target 10.0.4.19
    powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1 -Target AD

  Parameters
  ----------
    -Target <string>   IP address or hostname fragment to pre-filter folders.
                       Optional. If omitted all folders are shown.

================================================================================
  CHANGE LOG
================================================================================

    2.1  2026-03-05  Fixed XAML encoding issues (ASCII-safe, no Unicode symbols).
                     Removed invalid LetterSpacing XAML property.
                     Added MIT licence and full documentation block.

    2.0  2026-03-04  Added WPF GUI with 3-pane layout, Follow mode, colour coding,
                     keyword filter and status bar.
                     Expanded search roots to cover both Backup and Rescan folders.

    1.0  2026-03-03  Initial CLI-only version with interactive menu, colour output
                     and basic tail-follow support.

================================================================================

.SYNOPSIS
    Silver Robot -- Veeam Log Viewer -- Native Windows WPF GUI

.DESCRIPTION
    Searches C:\ProgramData\Veeam\Backup (and \Rescan subfolder) for logs
    by IP / hostname. Displays results in a resizable WPF window with a
    folder tree, file list, colour-coded log viewer, real-time Follow mode,
    and keyword filter with highlight.

.PARAMETER Target
    IP address or hostname fragment to pre-filter the folder tree.
    Optional -- if omitted all folders are shown.

.EXAMPLE
    .\Get-VeeamLog-UI.ps1

.EXAMPLE
    .\Get-VeeamLog-UI.ps1 -Target 10.0.4.19

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1 -Target AD

.NOTES
    License : MIT
    Requires: PowerShell 5.1+, .NET Framework 4.5+, Windows 10 / Server 2016+
#>

param(
    [string]$Target = ''
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# -- Constants ------------------------------------------------------------------
$VeeamRoot  = "C:\ProgramData\Veeam\Backup"
$RescanRoot = Join-Path $VeeamRoot "Rescan"
$LogExts    = @('.log','.txt','.xml')

# -- XAML Layout ---------------------------------------------------------------
[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Silver Robot -- Veeam Log Viewer"
    Height="780" Width="1280" MinHeight="500" MinWidth="800"
    Background="#1A1D23" FontFamily="Consolas" FontSize="12"
    WindowStartupLocation="CenterScreen">

  <Window.Resources>
    <!-- Scrollbar style -->
    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="#252830"/>
      <Setter Property="Foreground" Value="#444C5E"/>
    </Style>

    <!-- Button style -->
    <Style TargetType="Button" x:Key="Btn">
      <Setter Property="Background"   Value="#2D3244"/>
      <Setter Property="Foreground"   Value="#C8D0E0"/>
      <Setter Property="BorderBrush"  Value="#3D4560"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"      Value="10,4"/>
      <Setter Property="Cursor"       Value="Hand"/>
      <Setter Property="FontFamily"   Value="Consolas"/>
      <Setter Property="FontSize"     Value="12"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#3D4560"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Setter Property="Background" Value="#00AEEF"/>
          <Setter Property="Foreground" Value="#FFFFFF"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Toggle Button (Follow mode) -->
    <Style TargetType="ToggleButton" x:Key="FollowBtn">
      <Setter Property="Background"   Value="#2D3244"/>
      <Setter Property="Foreground"   Value="#C8D0E0"/>
      <Setter Property="BorderBrush"  Value="#3D4560"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"      Value="10,4"/>
      <Setter Property="Cursor"       Value="Hand"/>
      <Setter Property="FontFamily"   Value="Consolas"/>
      <Setter Property="FontSize"     Value="12"/>
      <Style.Triggers>
        <Trigger Property="IsChecked" Value="True">
          <Setter Property="Background" Value="#007A3D"/>
          <Setter Property="Foreground" Value="#AAFFCC"/>
          <Setter Property="BorderBrush" Value="#00C060"/>
        </Trigger>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#3D4560"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- TextBox style -->
    <Style TargetType="TextBox" x:Key="SearchBox">
      <Setter Property="Background"        Value="#252830"/>
      <Setter Property="Foreground"        Value="#C8D0E0"/>
      <Setter Property="CaretBrush"        Value="#00AEEF"/>
      <Setter Property="BorderBrush"       Value="#3D4560"/>
      <Setter Property="BorderThickness"   Value="1"/>
      <Setter Property="Padding"           Value="6,3"/>
      <Setter Property="FontFamily"        Value="Consolas"/>
      <Setter Property="FontSize"          Value="12"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>

    <!-- ListBox style -->
    <Style TargetType="ListBox" x:Key="FileList">
      <Setter Property="Background"      Value="#1E2128"/>
      <Setter Property="Foreground"      Value="#C8D0E0"/>
      <Setter Property="BorderBrush"     Value="#2D3244"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"         Value="0"/>
      <Setter Property="FontFamily"      Value="Consolas"/>
      <Setter Property="FontSize"        Value="11"/>
    </Style>

    <Style TargetType="ListBoxItem">
      <Setter Property="Padding" Value="6,3"/>
      <Setter Property="Foreground" Value="#C8D0E0"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#00AEEF"/>
          <Setter Property="Foreground" Value="#FFFFFF"/>
        </Trigger>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#2D3244"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- TreeView style -->
    <Style TargetType="TreeView" x:Key="FolderTree">
      <Setter Property="Background"      Value="#1E2128"/>
      <Setter Property="Foreground"      Value="#C8D0E0"/>
      <Setter Property="BorderBrush"     Value="#2D3244"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontFamily"      Value="Consolas"/>
      <Setter Property="FontSize"        Value="11"/>
    </Style>

    <Style TargetType="TreeViewItem">
      <Setter Property="Foreground" Value="#C8D0E0"/>
      <Setter Property="Padding"    Value="4,2"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#00AEEF"/>
          <Setter Property="Foreground" Value="#FFFFFF"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="48"/>   <!-- Top toolbar -->
      <RowDefinition Height="*"/>    <!-- Main content -->
      <RowDefinition Height="28"/>   <!-- Status bar -->
    </Grid.RowDefinitions>

    <!-- TOP TOOLBAR -->
    <Border Grid.Row="0" Background="#141720" BorderBrush="#2D3244" BorderThickness="0,0,0,1">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="220"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="140"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <!-- Logo -->
        <TextBlock Grid.Column="0" Text=" ? VEEAM LOG VIEWER  " FontSize="14"
                   Foreground="#00AEEF" FontWeight="Bold" VerticalAlignment="Center" Margin="8,0"/>

        <!-- Target search -->
        <TextBox  Grid.Column="1" x:Name="TxtTarget" Style="{StaticResource SearchBox}"
                  ToolTip="IP address or hostname fragment"
                  Margin="0,8,6,8" Text="" />
        <Button   Grid.Column="2" x:Name="BtnSearch" Content="? Search" Style="{StaticResource Btn}"
                  Margin="0,8,8,8" ToolTip="Find folders matching IP / hostname"/>

        <!-- Log filter -->
        <TextBox  Grid.Column="3" x:Name="TxtFilter" Style="{StaticResource SearchBox}"
                  ToolTip="Filter log lines (keyword)" Margin="0,8,6,8"/>
        <Button   Grid.Column="4" x:Name="BtnFilter" Content="Filter" Style="{StaticResource Btn}"
                  Margin="0,8,6,8" ToolTip="Apply keyword filter to log view"/>
        <Button   Grid.Column="5" x:Name="BtnClearFilter" Content="?" Style="{StaticResource Btn}"
                  Margin="0,8,8,8" Width="28" ToolTip="Clear filter"/>

        <!-- Lines -->
        <TextBlock Grid.Column="6" Text="Lines:" Foreground="#6A7490" VerticalAlignment="Center" Margin="0,0,4,0"/>
        <TextBox   Grid.Column="7" x:Name="TxtLines" Style="{StaticResource SearchBox}"
                   Width="50" Margin="0,8,8,8" Text="100"/>

        <!-- Spacer -->
        <Grid Grid.Column="8"/>

        <!-- Follow + Refresh -->
        <ToggleButton Grid.Column="9"  x:Name="BtnFollow" Content="? Follow" Style="{StaticResource FollowBtn}"
                      Margin="0,8,6,8" ToolTip="Stream new log lines in real time"/>
        <Button       Grid.Column="10" x:Name="BtnRefresh" Content="? Reload" Style="{StaticResource Btn}"
                      Margin="0,8,8,8" ToolTip="Reload selected log file"/>
      </Grid>
    </Border>

    <!-- MAIN CONTENT 3 panes -->
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="240" MinWidth="160"/>
        <ColumnDefinition Width="5"/>
        <ColumnDefinition Width="220" MinWidth="140"/>
        <ColumnDefinition Width="5"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- LEFT: Folder tree -->
      <Grid Grid.Column="0">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#141720" Padding="8,5">
          <TextBlock Text="FOLDERS" FontSize="10" Foreground="#6A7490" FontWeight="Bold"/>
        </Border>
        <TreeView Grid.Row="1" x:Name="FolderTree" Style="{StaticResource FolderTree}"/>
      </Grid>

      <GridSplitter Grid.Column="1" Width="5" Background="#0D0F14"
                    HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Cursor="SizeWE"/>

      <!-- MIDDLE: Log file list -->
      <Grid Grid.Column="2">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#141720" Padding="8,5">
          <TextBlock Text="LOG FILES" FontSize="10" Foreground="#6A7490" FontWeight="Bold"/>
        </Border>
        <ListBox Grid.Row="1" x:Name="FileList" Style="{StaticResource FileList}"/>
      </Grid>

      <GridSplitter Grid.Column="3" Width="5" Background="#0D0F14"
                    HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Cursor="SizeWE"/>

      <!-- RIGHT: Log content -->
      <Grid Grid.Column="4">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#141720" Padding="8,5">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="LogTitle" Text="LOG CONTENT" FontSize="10"
                       Foreground="#6A7490" FontWeight="Bold" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
              <TextBlock Text="o ERR " Foreground="#FF5555" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <TextBlock Text="o WARN" Foreground="#FFB86C" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <TextBlock Text="o OK  " Foreground="#50FA7B" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0"/>
              <TextBlock Text="o INFO" Foreground="#8BE9FD" FontSize="10" VerticalAlignment="Center"/>
            </StackPanel>
          </Grid>
        </Border>

        <RichTextBox Grid.Row="1" x:Name="LogView"
                     Background="#1A1D23" Foreground="#C8D0E0"
                     BorderThickness="0" IsReadOnly="True"
                     FontFamily="Consolas" FontSize="12"
                     HorizontalScrollBarVisibility="Auto"
                     VerticalScrollBarVisibility="Auto"
                     Padding="8"/>
      </Grid>
    </Grid>

    <!-- STATUS BAR -->
    <Border Grid.Row="2" Background="#0D0F14" BorderBrush="#2D3244" BorderThickness="0,1,0,0">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="StatusPath"  Grid.Column="0" Foreground="#6A7490" VerticalAlignment="Center" Margin="8,0" TextTrimming="CharacterEllipsis"/>
        <TextBlock x:Name="StatusLines" Grid.Column="1" Foreground="#6A7490" VerticalAlignment="Center" Margin="0,0,16,0"/>
        <TextBlock x:Name="StatusTime"  Grid.Column="2" Foreground="#6A7490" VerticalAlignment="Center" Margin="0,0,8,0"/>
      </Grid>
    </Border>
  </Grid>
</Window>
"@

# -- Build WPF window -----------------------------------------------------------
$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Named controls
$TxtTarget     = $Window.FindName('TxtTarget')
$BtnSearch     = $Window.FindName('BtnSearch')
$TxtFilter     = $Window.FindName('TxtFilter')
$BtnFilter     = $Window.FindName('BtnFilter')
$BtnClearFilter= $Window.FindName('BtnClearFilter')
$TxtLines      = $Window.FindName('TxtLines')
$BtnFollow     = $Window.FindName('BtnFollow')
$BtnRefresh    = $Window.FindName('BtnRefresh')
$FolderTree    = $Window.FindName('FolderTree')
$FileList      = $Window.FindName('FileList')
$LogView       = $Window.FindName('LogView')
$LogTitle      = $Window.FindName('LogTitle')
$StatusPath    = $Window.FindName('StatusPath')
$StatusLines   = $Window.FindName('StatusLines')
$StatusTime    = $Window.FindName('StatusTime')

# Pre-fill target if passed via param
if ($Target) { $TxtTarget.Text = $Target }

# -- State ----------------------------------------------------------------------
$script:CurrentFile   = $null
$script:LastFileSize  = 0
$script:FilterKeyword = ''
$script:AllFolders    = @()   # hashtable list: {Label, FullPath, Source}
$script:FollowTimer   = $null

# -- Colour map for log line categories ----------------------------------------
function Get-LineColor ([string]$line) {
    if ($line -match '(?i)error|exception|failed|failure|critical|\[err\]')  { return '#FF5555' }
    if ($line -match '(?i)warn|warning|\[warn\]')                            { return '#FFB86C' }
    if ($line -match '(?i)success|succeeded|completed|finish|\[success\]')   { return '#50FA7B' }
    if ($line -match '(?i)start|begin|init|connect|info|\[info\]')           { return '#8BE9FD' }
    return '#C8D0E0'
}

# -- Append coloured lines to RichTextBox --------------------------------------
function Add-LogLines ([string[]]$lines, [bool]$clear = $false) {
    $doc = $LogView.Document
    if ($clear) { $doc.Blocks.Clear() }

    $para = New-Object System.Windows.Documents.Paragraph
    $para.Margin = New-Object System.Windows.Thickness(0)
    $para.LineHeight = 18

    foreach ($line in $lines) {
        if ($script:FilterKeyword -and $line -notmatch [regex]::Escape($script:FilterKeyword)) { continue }

        $run = New-Object System.Windows.Documents.Run
        $run.Text = $line + "`n"
        $color = Get-LineColor $line
        $run.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($color)

        # Highlight filter keyword
        if ($script:FilterKeyword -and $line -match [regex]::Escape($script:FilterKeyword)) {
            $run.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#4A3A00')
        }
        $para.Inlines.Add($run)
    }
    $doc.Blocks.Add($para)
}

# -- Load selected log file -----------------------------------------------------
function Load-LogFile ([string]$path) {
    $script:CurrentFile  = $path
    $script:LastFileSize = 0

    $n = [int]($TxtLines.Text -replace '[^\d]','')
    if ($n -lt 1) { $n = 100 }

    $lines = Get-Content -Path $path -Tail $n -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { $lines = @("[No readable content found in: $path]") }

    Add-LogLines -lines $lines -clear $true

    $fi = Get-Item $path -ErrorAction SilentlyContinue
    $script:LastFileSize = if ($fi) { $fi.Length } else { 0 }

    $LogTitle.Text    = "LOG CONTENT  --  $(Split-Path $path -Leaf)"
    $StatusPath.Text  = $path
    $StatusLines.Text = "$($lines.Count) lines shown"
    $StatusTime.Text  = if ($fi) { "Modified: $($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" } else { '' }

    # Scroll to end
    $LogView.ScrollToEnd()
}

# -- Follow / Tail timer tick ---------------------------------------------------
function Start-FollowTimer {
    if ($script:FollowTimer) { $script:FollowTimer.Stop() }
    $script:FollowTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:FollowTimer.Interval = [TimeSpan]::FromMilliseconds(800)
    $script:FollowTimer.Add_Tick({
        if (-not $script:CurrentFile) { return }
        $fi = Get-Item $script:CurrentFile -ErrorAction SilentlyContinue
        if (-not $fi) { return }

        if ($fi.Length -gt $script:LastFileSize) {
            try {
                $fs = [System.IO.File]::Open($script:CurrentFile,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::ReadWrite)
                $fs.Seek($script:LastFileSize, [System.IO.SeekOrigin]::Begin) | Out-Null
                $reader = New-Object System.IO.StreamReader($fs)
                $newLines = @()
                while (-not $reader.EndOfStream) { $newLines += $reader.ReadLine() }
                $reader.Close(); $fs.Close()
                if ($newLines.Count -gt 0) {
                    Add-LogLines -lines $newLines -clear $false
                    $LogView.ScrollToEnd()
                    $StatusLines.Text = "Following -- $(Get-Date -Format 'HH:mm:ss')"
                }
                $script:LastFileSize = $fi.Length
            } catch {}
        } elseif ($fi.Length -lt $script:LastFileSize) {
            # Rotated
            Load-LogFile $script:CurrentFile
        }
        $StatusTime.Text = "Last check: $(Get-Date -Format 'HH:mm:ss')"
    })
    $script:FollowTimer.Start()
}

function Stop-FollowTimer {
    if ($script:FollowTimer) { $script:FollowTimer.Stop(); $script:FollowTimer = $null }
}

# -- Discover all Veeam log folders --------------------------------------------
function Get-VeeamFolders ([string]$filter = '') {
    $results = [System.Collections.Generic.List[hashtable]]::new()

    # -- 1. Rescan folders --------------------------------------------------
    if (Test-Path $RescanRoot) {
        Get-ChildItem $RescanRoot -Directory | Sort-Object Name | ForEach-Object {
            $label = $_.Name -replace '^Rescan_of_', ''
            if (-not $filter -or $label -match [regex]::Escape($filter) -or $_.Name -match [regex]::Escape($filter)) {
                $results.Add(@{ Label = $label; FullPath = $_.FullName; Source = 'Rescan' })
            }
        }
    }

    # -- 2. Backup root folders (exclude Rescan itself) --------------------
    if (Test-Path $VeeamRoot) {
        Get-ChildItem $VeeamRoot -Directory |
            Where-Object { $_.Name -ne 'Rescan' } |
            Sort-Object Name | ForEach-Object {
                $label = $_.Name
                if (-not $filter -or $label -match [regex]::Escape($filter)) {
                    $results.Add(@{ Label = $label; FullPath = $_.FullName; Source = 'Backup' })
                }
            }
    }

    return $results
}

# -- Populate folder TreeView --------------------------------------------------
function Populate-Tree ([string]$filter = '') {
    $FolderTree.Items.Clear()
    $FileList.Items.Clear()
    $script:AllFolders = Get-VeeamFolders $filter

    # Group by Source
    $groups = $script:AllFolders | Group-Object { $_['Source'] }
    foreach ($grp in $groups) {
        $rootNode = New-Object System.Windows.Controls.TreeViewItem
        $rootNode.Header     = "? $($grp.Name)  ($($grp.Count))"
        $rootNode.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#00AEEF')
        $rootNode.IsExpanded = $true
        $rootNode.Tag        = $null

        foreach ($f in $grp.Group) {
            $child = New-Object System.Windows.Controls.TreeViewItem
            $child.Header = $f['Label']
            $child.Tag    = $f['FullPath']
            $child.ToolTip = $f['FullPath']
            $rootNode.Items.Add($child) | Out-Null
        }
        $FolderTree.Items.Add($rootNode) | Out-Null
    }

    $StatusPath.Text = if ($filter) { "Showing results for: '$filter'" } else { "All Veeam log folders loaded" }
}

# -- Populate file list for selected folder ------------------------------------
function Populate-FileList ([string]$folderPath) {
    $FileList.Items.Clear()
    $LogView.Document.Blocks.Clear()
    $script:CurrentFile = $null

    if (-not (Test-Path $folderPath)) {
        $StatusPath.Text = "Folder not found: $folderPath"
        return
    }

    $files = Get-ChildItem $folderPath -File -Recurse |
        Where-Object { $LogExts -contains $_.Extension.ToLower() -or $_.Name -match '\.log' } |
        Sort-Object LastWriteTime -Descending

    if (-not $files) {
        $files = Get-ChildItem $folderPath -File | Sort-Object LastWriteTime -Descending
    }

    foreach ($f in $files) {
        $age = (Get-Date) - $f.LastWriteTime
        $ageStr = if ($age.TotalMinutes -lt 60)  { "$([int]$age.TotalMinutes)m ago" }
                  elseif ($age.TotalHours  -lt 24) { "$([int]$age.TotalHours)h ago"  }
                  else                             { "$([int]$age.TotalDays)d ago"   }
        $sizeStr = if ($f.Length -gt 1MB) { "$([math]::Round($f.Length/1MB,1)) MB" }
                   else { "$([math]::Round($f.Length/1KB,0)) KB" }

        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = "$($f.Name)`n  $sizeStr  ?  $ageStr"
        $item.Tag     = $f.FullName
        $item.ToolTip = $f.FullName
        $item.Padding = New-Object System.Windows.Thickness(6,4,6,4)
        $FileList.Items.Add($item) | Out-Null
    }

    if ($FileList.Items.Count -gt 0) {
        $FileList.SelectedIndex = 0
    }
    $StatusPath.Text = "$folderPath  ($($files.Count) log file(s))"
}

# -----------------------------------------------------------------------------
# EVENT HANDLERS
# -----------------------------------------------------------------------------

# Search button
$BtnSearch.Add_Click({
    Stop-FollowTimer
    $BtnFollow.IsChecked = $false
    Populate-Tree $TxtTarget.Text.Trim()
})

# Enter key in target box
$TxtTarget.Add_KeyDown({
    param($s,$e)
    if ($e.Key -eq 'Return') { $BtnSearch.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
})

# Folder tree selection
$FolderTree.Add_SelectedItemChanged({
    $node = $FolderTree.SelectedItem
    if ($node -and $node.Tag) {
        Stop-FollowTimer
        $BtnFollow.IsChecked = $false
        Populate-FileList $node.Tag
    }
})

# File list selection
$FileList.Add_SelectionChanged({
    $item = $FileList.SelectedItem
    if ($item -and $item.Tag) {
        Load-LogFile $item.Tag
        if ($BtnFollow.IsChecked) { Start-FollowTimer }
    }
})

# Follow toggle
$BtnFollow.Add_Checked({
    if ($script:CurrentFile) { Start-FollowTimer }
})
$BtnFollow.Add_Unchecked({
    Stop-FollowTimer
    $StatusLines.Text = "Follow stopped"
})

# Reload button
$BtnRefresh.Add_Click({
    if ($script:CurrentFile) { Load-LogFile $script:CurrentFile }
})

# Filter button
$BtnFilter.Add_Click({
    $script:FilterKeyword = $TxtFilter.Text.Trim()
    if ($script:CurrentFile) { Load-LogFile $script:CurrentFile }
})
$TxtFilter.Add_KeyDown({
    param($s,$e)
    if ($e.Key -eq 'Return') { $BtnFilter.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
})

# Clear filter
$BtnClearFilter.Add_Click({
    $TxtFilter.Text = ''
    $script:FilterKeyword = ''
    if ($script:CurrentFile) { Load-LogFile $script:CurrentFile }
})

# Cleanup on close
$Window.Add_Closing({ Stop-FollowTimer })

# Clock in status bar
$clockTimer = New-Object System.Windows.Threading.DispatcherTimer
$clockTimer.Interval = [TimeSpan]::FromSeconds(1)
$clockTimer.Add_Tick({ $StatusTime.Text = Get-Date -Format 'yyyy-MM-dd HH:mm:ss' })
$clockTimer.Start()

# -- Initial load ---------------------------------------------------------------
Populate-Tree $Target

# -- Show window ----------------------------------------------------------------
$Window.ShowDialog() | Out-Null
