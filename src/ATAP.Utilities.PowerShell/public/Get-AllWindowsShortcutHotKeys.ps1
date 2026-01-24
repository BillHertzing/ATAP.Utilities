<#
.SYNOPSIS
    Retrieves all Windows shortcut hotkeys from common shell folders and optionally includes built-in Windows key shortcuts.

.DESCRIPTION
    Scans Windows shell folders (Desktop, Start Menu, Quick Launch) for shortcut files (.lnk)
    and returns information about any assigned hotkeys. This is useful for identifying
    keyboard shortcut conflicts or documenting existing hotkey assignments.

    Optionally includes a comprehensive list of built-in Windows key (Win+X) shortcuts that
    are hardcoded into the Windows operating system.

.PARAMETER IncludeQuickLaunch
    Include the Quick Launch folder in the search. Defaults to $true.

.PARAMETER Recurse
    Recursively search subfolders. Defaults to $true.

.PARAMETER IncludeBuiltInWinKeyShortcuts
    Include built-in Windows key shortcuts (Win+A, Win+D, etc.) in the output.
    These are system shortcuts not stored in .lnk files. Defaults to $false.

.PARAMETER OnlyBuiltInWinKeyShortcuts
    Only return built-in Windows key shortcuts, skip scanning shell folders.
    Defaults to $false.

.OUTPUTS
    PSCustomObject with properties: HotKey, ShortcutPath, ShortcutName, FolderSource

.EXAMPLE
    Get-AllWindowsShortcutHotKeys
    Returns all shortcut hotkeys from default shell folders.

.EXAMPLE
    Get-AllWindowsShortcutHotKeys -IncludeBuiltInWinKeyShortcuts
    Returns shortcut hotkeys plus all built-in Windows key combinations.

.EXAMPLE
    Get-AllWindowsShortcutHotKeys -OnlyBuiltInWinKeyShortcuts
    Returns only the built-in Windows key shortcuts.

.EXAMPLE
    Get-AllWindowsShortcutHotKeys | Where-Object { $_.HotKey -like '*Ctrl*' }
    Returns only shortcuts with Ctrl key combinations.

.EXAMPLE
    Get-AllWindowsShortcutHotKeys -IncludeBuiltInWinKeyShortcuts | Where-Object { $_.HotKey -like 'Win+*' }
    Returns all shortcuts that use the Windows key.

.EXAMPLE
    Get-AllWindowsShortcutHotKeys | Format-Table -AutoSize
    Displays all hotkeys in a formatted table.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines
    Converted from original VBScript implementation.
    Built-in Windows key shortcuts list based on Windows 10/11.

.LINK
    https://github.com/BillHertzing/ATAP.Utilities
#>
function Get-AllWindowsShortcutHotKeys {
  [CmdletBinding()]
  param(
    [Parameter()]
    [switch]$IncludeQuickLaunch = $true,

    [Parameter()]
    [switch]$Recurse = $true,

    [Parameter()]
    [switch]$IncludeBuiltInWinKeyShortcuts,

    [Parameter()]
    [switch]$OnlyBuiltInWinKeyShortcuts
  )

  BEGIN {
    # Snippet: FunctionNameModuleName - Function and Module name variables for logging
    $fn = $MyInvocation.MyCommand.Name
    $mn = if ($MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { 'ATAP.Utilities.Powershell' }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting hotkey discovery'

    # Built-in Windows key shortcuts (Windows 10/11)
    $builtInWinKeyShortcuts = @(
      # Basic Windows key shortcuts
      @{ HotKey = 'Win'; Description = 'Open/Close Start menu' }
      @{ HotKey = 'Win+A'; Description = 'Open Action Center / Quick Settings (Win11)' }
      @{ HotKey = 'Win+B'; Description = 'Set focus to notification area / system tray' }
      @{ HotKey = 'Win+C'; Description = 'Open Cortana / Microsoft Teams chat (Win11)' }
      @{ HotKey = 'Win+D'; Description = 'Show/Hide desktop (toggle)' }
      @{ HotKey = 'Win+E'; Description = 'Open File Explorer' }
      @{ HotKey = 'Win+F'; Description = 'Open Feedback Hub' }
      @{ HotKey = 'Win+G'; Description = 'Open Xbox Game Bar' }
      @{ HotKey = 'Win+H'; Description = 'Open voice typing / dictation' }
      @{ HotKey = 'Win+I'; Description = 'Open Windows Settings' }
      @{ HotKey = 'Win+J'; Description = 'Set focus to Windows tip (when available)' }
      @{ HotKey = 'Win+K'; Description = 'Open Connect panel (cast to device)' }
      @{ HotKey = 'Win+L'; Description = 'Lock workstation' }
      @{ HotKey = 'Win+M'; Description = 'Minimize all windows' }
      @{ HotKey = 'Win+N'; Description = 'Open Notification Center / Calendar (Win11)' }
      @{ HotKey = 'Win+O'; Description = 'Lock device orientation' }
      @{ HotKey = 'Win+P'; Description = 'Open projection / display settings' }
      @{ HotKey = 'Win+Q'; Description = 'Open Search' }
      @{ HotKey = 'Win+R'; Description = 'Open Run dialog' }
      @{ HotKey = 'Win+S'; Description = 'Open Search' }
      @{ HotKey = 'Win+T'; Description = 'Cycle through taskbar apps' }
      @{ HotKey = 'Win+U'; Description = 'Open Accessibility / Ease of Access settings' }
      @{ HotKey = 'Win+V'; Description = 'Open Clipboard history' }
      @{ HotKey = 'Win+W'; Description = 'Open Widgets panel (Win11) / Windows Ink Workspace' }
      @{ HotKey = 'Win+X'; Description = 'Open Quick Link menu (Win+X menu)' }
      @{ HotKey = 'Win+Y'; Description = 'Switch input between Windows Mixed Reality and desktop' }
      @{ HotKey = 'Win+Z'; Description = 'Open Snap Layouts (Win11)' }

      # Windows key + numbers (taskbar)
      @{ HotKey = 'Win+1'; Description = 'Open/switch to 1st taskbar app' }
      @{ HotKey = 'Win+2'; Description = 'Open/switch to 2nd taskbar app' }
      @{ HotKey = 'Win+3'; Description = 'Open/switch to 3rd taskbar app' }
      @{ HotKey = 'Win+4'; Description = 'Open/switch to 4th taskbar app' }
      @{ HotKey = 'Win+5'; Description = 'Open/switch to 5th taskbar app' }
      @{ HotKey = 'Win+6'; Description = 'Open/switch to 6th taskbar app' }
      @{ HotKey = 'Win+7'; Description = 'Open/switch to 7th taskbar app' }
      @{ HotKey = 'Win+8'; Description = 'Open/switch to 8th taskbar app' }
      @{ HotKey = 'Win+9'; Description = 'Open/switch to 9th taskbar app' }
      @{ HotKey = 'Win+0'; Description = 'Open/switch to 10th taskbar app' }

      # Windows key + Shift + numbers
      @{ HotKey = 'Win+Shift+1'; Description = 'Open new instance of 1st taskbar app' }
      @{ HotKey = 'Win+Shift+2'; Description = 'Open new instance of 2nd taskbar app' }
      @{ HotKey = 'Win+Shift+3'; Description = 'Open new instance of 3rd taskbar app' }

      # Windows key + Ctrl + numbers
      @{ HotKey = 'Win+Ctrl+1'; Description = 'Switch to last active window of 1st taskbar app' }
      @{ HotKey = 'Win+Ctrl+2'; Description = 'Switch to last active window of 2nd taskbar app' }
      @{ HotKey = 'Win+Ctrl+3'; Description = 'Switch to last active window of 3rd taskbar app' }

      # Windows key + Alt + numbers
      @{ HotKey = 'Win+Alt+1'; Description = 'Open Jump List for 1st taskbar app' }
      @{ HotKey = 'Win+Alt+2'; Description = 'Open Jump List for 2nd taskbar app' }
      @{ HotKey = 'Win+Alt+3'; Description = 'Open Jump List for 3rd taskbar app' }

      # Windows key + function keys
      @{ HotKey = 'Win+F1'; Description = 'Open Windows Help (Bing search)' }
      @{ HotKey = 'Win+F4'; Description = 'Close active window (in some apps)' }

      # Windows key + arrows
      @{ HotKey = 'Win+Up'; Description = 'Maximize window' }
      @{ HotKey = 'Win+Down'; Description = 'Minimize/restore window' }
      @{ HotKey = 'Win+Left'; Description = 'Snap window to left half' }
      @{ HotKey = 'Win+Right'; Description = 'Snap window to right half' }
      @{ HotKey = 'Win+Shift+Up'; Description = 'Stretch window to top and bottom of screen' }
      @{ HotKey = 'Win+Shift+Down'; Description = 'Restore/minimize active desktop windows vertically' }
      @{ HotKey = 'Win+Shift+Left'; Description = 'Move window to monitor on left' }
      @{ HotKey = 'Win+Shift+Right'; Description = 'Move window to monitor on right' }
      @{ HotKey = 'Win+Home'; Description = 'Minimize all except active window (restore on second press)' }

      # Windows key + special keys
      @{ HotKey = 'Win+Space'; Description = 'Switch keyboard layout / input language' }
      @{ HotKey = 'Win+Tab'; Description = 'Open Task View' }
      @{ HotKey = 'Win+Enter'; Description = 'Open Narrator' }
      @{ HotKey = 'Win+Pause'; Description = 'Open System Properties / About' }
      @{ HotKey = 'Win+PrtSc'; Description = 'Screenshot entire screen to Pictures\Screenshots' }
      @{ HotKey = 'Win+Shift+S'; Description = 'Open Snipping Tool / Screen snip' }

      # Windows key + Ctrl combinations
      @{ HotKey = 'Win+Ctrl+D'; Description = 'Create new virtual desktop' }
      @{ HotKey = 'Win+Ctrl+F'; Description = 'Search for PCs (on domain network)' }
      @{ HotKey = 'Win+Ctrl+F4'; Description = 'Close current virtual desktop' }
      @{ HotKey = 'Win+Ctrl+Left'; Description = 'Switch to previous virtual desktop' }
      @{ HotKey = 'Win+Ctrl+Right'; Description = 'Switch to next virtual desktop' }
      @{ HotKey = 'Win+Ctrl+Q'; Description = 'Open Quick Assist' }
      @{ HotKey = 'Win+Ctrl+Enter'; Description = 'Open Narrator' }
      @{ HotKey = 'Win+Ctrl+Shift+B'; Description = 'Wake PC from blank/black screen, restart graphics driver' }

      # Windows key + Shift combinations
      @{ HotKey = 'Win+Shift+M'; Description = 'Restore minimized windows' }
      @{ HotKey = 'Win+Shift+V'; Description = 'Cycle through notifications in reverse' }

      # Windows key + Alt combinations
      @{ HotKey = 'Win+Alt+D'; Description = 'Show/hide date and time on desktop' }
      @{ HotKey = 'Win+Alt+G'; Description = 'Record last 30 seconds (Game Bar)' }
      @{ HotKey = 'Win+Alt+R'; Description = 'Start/stop recording (Game Bar)' }
      @{ HotKey = 'Win+Alt+PrtSc'; Description = 'Screenshot game window (Game Bar)' }
      @{ HotKey = 'Win+Alt+B'; Description = 'Toggle HDR on/off' }
      @{ HotKey = 'Win+Alt+K'; Description = 'Toggle microphone mute in supported apps' }

      # Accessibility shortcuts with Windows key
      @{ HotKey = 'Win++'; Description = 'Open Magnifier and zoom in' }
      @{ HotKey = 'Win+-'; Description = 'Zoom out with Magnifier' }
      @{ HotKey = 'Win+Esc'; Description = 'Close Magnifier' }
      @{ HotKey = 'Win+Ctrl+M'; Description = 'Open Magnifier settings' }
      @{ HotKey = 'Win+Ctrl+O'; Description = 'Open On-Screen Keyboard' }

      # Period/semicolon for emoji
      @{ HotKey = 'Win+.'; Description = 'Open emoji panel' }
      @{ HotKey = 'Win+;'; Description = 'Open emoji panel' }

      # Additional Windows 11 specific
      @{ HotKey = 'Win+Alt+Enter'; Description = 'Open HDR settings (on supported displays)' }
    )

    # Create WScript.Shell COM object for reading shortcut properties (only if needed)
    $wshShell = $null
    if (-not $OnlyBuiltInWinKeyShortcuts) {
      try {
        $wshShell = New-Object -ComObject WScript.Shell
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Created WScript.Shell COM object'
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to create WScript.Shell COM object: $_"
        throw
      }

      # Build list of folders to search
      $foldersToSearch = [System.Collections.Generic.List[string]]::new()
      # Add standard shell folders using .NET Environment
      $shellFolders = @(
        [Environment]::GetFolderPath('CommonDesktopDirectory')    # All Users Desktop
        [Environment]::GetFolderPath('Desktop')                    # User Desktop
        [Environment]::GetFolderPath('CommonStartMenu')            # All Users Start Menu
        [Environment]::GetFolderPath('StartMenu')                  # User Start Menu
      )

      foreach ($folder in $shellFolders) {
        if (-not [string]::IsNullOrWhiteSpace($folder) -and (Test-Path -Path $folder -PathType Container)) {
          $foldersToSearch.Add($folder)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Added folder to search: $folder"
        }
      }

      # Add Quick Launch folder if requested
      if ($IncludeQuickLaunch) {
        $quickLaunchPath = Join-Path -Path ([Environment]::GetFolderPath('ApplicationData')) -ChildPath 'Microsoft\Internet Explorer\Quick Launch'
        if (Test-Path -Path $quickLaunchPath -PathType Container) {
          $foldersToSearch.Add($quickLaunchPath)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Added Quick Launch folder: $quickLaunchPath"
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Will search $($foldersToSearch.Count) folder(s)"

      # Helper function to extract hotkeys from shortcuts in a folder
      function Get-ShortcutHotKeysFromFolder {
        param(
          [string]$FolderPath,
          [string]$SourceName,
          [bool]$SearchRecursively
        )

        $searchOption = if ($SearchRecursively) { 'AllDirectories' } else { 'TopDirectoryOnly' }

        try {
          $lnkFiles = [System.IO.Directory]::GetFiles($FolderPath, '*.lnk', $searchOption)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found $($lnkFiles.Count) .lnk files in $FolderPath"

          foreach ($lnkFile in $lnkFiles) {
            try {
              $shortcut = $wshShell.CreateShortcut($lnkFile)
              $hotkey = $shortcut.Hotkey

              if (-not [string]::IsNullOrWhiteSpace($hotkey)) {
                [PSCustomObject]@{
                  HotKey       = $hotkey.Trim()
                  ShortcutPath = $lnkFile
                  ShortcutName = [System.IO.Path]::GetFileNameWithoutExtension($lnkFile)
                  FolderSource = $SourceName
                }
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found hotkey [$hotkey] for $lnkFile"
              }
            }
            catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Could not read shortcut $lnkFile : $_"
            }
          }
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Error accessing folder $FolderPath : $_"
        }
      }
    }
  }

  PROCESS {
    try {
      $hotkeysFound = 0

      # Output built-in Windows key shortcuts if requested
      if ($IncludeBuiltInWinKeyShortcuts -or $OnlyBuiltInWinKeyShortcuts) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Including built-in Windows key shortcuts'
        foreach ($shortcut in $builtInWinKeyShortcuts) {
          $hotkeysFound++
          [PSCustomObject]@{
            HotKey       = $shortcut.HotKey
            ShortcutPath = 'N/A (Built-in)'
            ShortcutName = $shortcut.Description
            FolderSource = 'Windows Built-in'
          }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Added $($builtInWinKeyShortcuts.Count) built-in Windows key shortcuts"
      }

      # Scan shell folders for .lnk shortcuts (unless only built-in requested)
      if (-not $OnlyBuiltInWinKeyShortcuts) {
        foreach ($folder in $foldersToSearch) {
          # Determine friendly source name
          $sourceName = switch -Regex ($folder) {
            'CommonDesktop' { 'All Users Desktop' }
            '\\Desktop$' { 'User Desktop' }
            'CommonStartMenu' { 'All Users Start Menu' }
            '\\Start Menu$' { 'User Start Menu' }
            'Quick Launch' { 'Quick Launch' }
            default { $folder }
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Searching $sourceName"

          $results = Get-ShortcutHotKeysFromFolder -FolderPath $folder -SourceName $sourceName -SearchRecursively $Recurse
          foreach ($result in $results) {
            $hotkeysFound++
            $result
          }
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $hotkeysFound hotkey assignment(s)"
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Error during hotkey discovery: $_"
      throw
    }
  }

  END {
    # Clean up COM object
    if ($null -ne $wshShell) {
      try {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wshShell) | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Released WScript.Shell COM object'
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Error releasing COM object: $_"
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed hotkey discovery'
  }
}
