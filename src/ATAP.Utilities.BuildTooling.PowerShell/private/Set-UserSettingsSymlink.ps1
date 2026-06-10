function Set-UserSettingsSymlink {
  <#
  .SYNOPSIS
    Creates (or replaces) the VS Code user settings symlink so that VS Code reads
    settings from the specified SharedVSCode worktree's UserSettings.jsonc.
  .DESCRIPTION
    The VS Code user settings file at `$env:APPDATA\Code\User\settings.json` is
    maintained as a symbolic link pointing to a `UserSettings.jsonc` file tracked
    under source control in the SharedVSCode repository. At sprint start this link
    is retargeted to the SharedVSCode sprint worktree copy so that sprint-specific
    VS Code settings are active. At sprint end the link is retargeted back to the
    stable SharedVSCode worktree copy.

    This function removes any existing file or symlink at the target path before
    creating the new symlink. Creating symbolic links on Windows requires either
    Developer Mode to be enabled or the session to be running with administrator
    privileges.
  .PARAMETER SharedVSCodeWorktreePath
    Path to the SharedVSCode worktree (sprint or stable) that contains
    `UserSettings.jsonc`. Pass the sprint worktree path at sprint start and the
    stable SharedVSCode path at sprint end.
  .OUTPUTS
    None.
  .EXAMPLE
    # Sprint start — retarget to sprint worktree
    Set-UserSettingsSymlink -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-42-Sprint-0007-work-items'
  .EXAMPLE
    # Sprint end — retarget back to stable
    Set-UserSettingsSymlink -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode'
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintStage2
    SprintEndAgent.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedVSCodeWorktreePath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $sourcePath = Join-Path $SharedVSCodeWorktreePath 'UserSettings.jsonc'
    $targetPath = Join-Path $env:APPDATA 'Code' 'User' 'settings.json'

    if (-not (Test-Path -LiteralPath $sourcePath)) {
      throw "Source UserSettings.jsonc not found at '$sourcePath'"
    }

    # Ensure the target directory exists
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path -LiteralPath $targetDir)) {
      New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Remove existing file or symlink at target so we can replace it
    if (Test-Path -LiteralPath $targetPath) {
      $existingItem = Get-Item -LiteralPath $targetPath -Force
      if ($existingItem.LinkType -eq 'SymbolicLink') {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Removing existing symlink at '$targetPath' (currently -> '$($existingItem.Target)')"
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Replacing non-symlink file at '$targetPath' with symlink"
      }
      Remove-Item -LiteralPath $targetPath -Force
    }

    if ($PSCmdlet.ShouldProcess($targetPath, "Create symlink -> $sourcePath")) {
      New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "VS Code UserSettings symlink created: '$targetPath' -> '$sourcePath'"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
