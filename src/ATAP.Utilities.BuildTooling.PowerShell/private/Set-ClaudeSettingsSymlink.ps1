function Set-ClaudeSettingsSymlink {
  <#
  .SYNOPSIS
    Creates (or replaces) a symlink from the SharedVSCode sprint branch
    claude-settings.json to the user-profile claude settings path.
  .PARAMETER SharedVSCodeWorktreePath
    Path to the SharedVSCode sprint worktree containing claude-settings.json.
  .OUTPUTS
    None.
  .EXAMPLE
    Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-38-sprint-0005-work-items'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    New-SprintStage2
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedVSCodeWorktreePath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'SharedVSCode'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $sourcePath = Join-Path $SharedVSCodeWorktreePath 'claude-settings.json'
    $targetPath = Join-Path $env:USERPROFILE '.claude' 'settings.json'

    if (-not (Test-Path $sourcePath)) {
      throw "Source claude-settings.json not found at $sourcePath"
    }

    # Ensure the target directory exists
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
      New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Remove existing file/symlink at target so we can replace it
    if (Test-Path $targetPath) {
      $existingItem = Get-Item $targetPath -Force
      if ($existingItem.LinkType -eq 'SymbolicLink') {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "Removing existing symlink at $targetPath"
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Replacing non-symlink file at $targetPath with symlink"
      }
      Remove-Item $targetPath -Force
    }

    if ($PSCmdlet.ShouldProcess($targetPath, "Create symlink -> $sourcePath")) {
      New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Symlink created: $targetPath -> $sourcePath"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
