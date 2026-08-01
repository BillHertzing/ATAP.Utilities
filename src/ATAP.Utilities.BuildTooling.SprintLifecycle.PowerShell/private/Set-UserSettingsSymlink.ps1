function Set-UserSettingsSymlink {
  <#
  .SYNOPSIS
    Retargets the VS Code user settings symlink to a SharedVSCode boundary root.

  .DESCRIPTION
    This private bridge is packaged with SprintLifecycle because
    Set-SprintBoundaryContext invokes it directly. Keeping the helper in the
    child package prevents an exact child-module import from depending on the
    umbrella module's private session state.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedVSCodeWorktreePath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    $sourcePath = Join-Path $SharedVSCodeWorktreePath 'UserSettings.jsonc'
    $targetPath = Join-Path $env:APPDATA 'Code' 'User' 'settings.json'

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
      throw "Source UserSettings.jsonc not found at '$sourcePath'"
    }

    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
      New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

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
