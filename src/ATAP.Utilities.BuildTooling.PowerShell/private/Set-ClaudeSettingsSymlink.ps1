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
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $sourcePath = Join-Path $SharedVSCodeWorktreePath 'claude-settings.json'
    $targetPath = Join-Path `
      -Path $env:USERPROFILE `
      -ChildPath '.claude' `
      -AdditionalChildPath 'settings.json'

    if (-not (Test-Path $sourcePath)) {
      throw "Source claude-settings.json not found at $sourcePath"
    }

    if ($PSCmdlet.ShouldProcess($targetPath, "Replace with symlink -> $sourcePath")) {
      # Ensure the target directory exists only after mutation approval.
      $targetDir = Split-Path $targetPath -Parent
      if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
      }

      # Remove only the exact settings file/link; never recurse into ~/.claude.
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

      New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath -Force | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Symlink created: $targetPath -> $sourcePath"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
