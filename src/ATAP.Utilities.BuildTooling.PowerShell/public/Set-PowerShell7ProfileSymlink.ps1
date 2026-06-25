function Set-PowerShell7ProfileSymlink {
  <#
  .SYNOPSIS
    Retargets the machine-wide PowerShell 7 profile symlinks to a given repository
    root and removes obsolete profile symlinks.

  .DESCRIPTION
    The PowerShell 7 install directory (C:\Program Files\PowerShell\7) holds two
    machine-wide symlinks that ATAP tooling owns:

      - profile.ps1     -> <ATAP.Utilities root>\src\ATAP.Utilities.PowerShell\Profiles\AllUsersAllHostsV7CoreProfile.ps1
      - HostSettings.ps1 -> <ATAP.IAC root>\Windows\HostSettings.ps1

    The AllUsersAllHosts core profile derives the active stable-vs-sprint context by
    reading the target of profile.ps1, so this symlink must track the worktree that
    owns the current session. HostSettings.ps1 follows the ATAP.IAC worktree the same
    way.

    Two formerly-deployed symlinks are no longer needed because the configuration
    globals are now bootstrapped in-process (Task 10.5,
    Initialize-ATAPConfigurationGlobals) rather than dot-sourced from
    C:\Program Files\PowerShell\7:

      - global_ConfigRootKeys.ps1
      - global_environmentVariables.ps1

    This worker removes those obsolete symlinks if present so no dangling or stale
    sprint-worktree link survives a sprint boundary.

    The caller decides which roots to pass: a sprint worktree at sprint start, the
    stable repository root at sprint end. Every mutation runs under ShouldProcess, so
    -WhatIf previews the full retarget without touching the install directory.

    Symlinks under C:\Program Files\PowerShell\7 are created with
    'New-Item -ItemType SymbolicLink -Force' (which overwrites in place); plain
    Remove-Item of an existing link can be blocked there without elevation, so
    obsolete-link removal is best-effort and reported per link rather than fatal.

  .PARAMETER ATAPUtilitiesRoot
    Repository or worktree root that owns profile.ps1's target. On sprint start this
    is the ATAP.Utilities sprint worktree; on sprint end it is the stable repository.

  .PARAMETER ATAPIACRoot
    Repository or worktree root that owns HostSettings.ps1's target. On sprint start
    this is the ATAP.IAC sprint worktree when one exists, else the stable repository;
    on sprint end it is the stable repository.

  .PARAMETER PowerShell7Path
    Directory containing the PowerShell 7 machine-wide symlinks. Defaults to
    '<ProgramFiles>\PowerShell\7'. Override for tests.

  .PARAMETER ProfileRelativePath
    Repo-relative path, under ATAPUtilitiesRoot, of the core profile that profile.ps1
    points at.

  .PARAMETER HostSettingsRelativePath
    Repo-relative path, under ATAPIACRoot, of the host settings file that
    HostSettings.ps1 points at.

  .PARAMETER ObsoleteLinkNames
    Symlink leaf names under PowerShell7Path that are no longer needed and should be
    removed if present.

  .PARAMETER ThrowOnFailure
    Throw when any managed link could not be retargeted or any obsolete link could
    not be removed.

  .OUTPUTS
    PSCustomObject with PowerShell7Path, DryRun, a per-link Links array, an aggregate
    Ok flag, and a Failures array.

  .EXAMPLE
    # Sprint start - point the machine profile at the sprint worktrees
    Set-PowerShell7ProfileSymlink `
      -ATAPUtilitiesRoot 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-115-Sprint-0010-work-items' `
      -ATAPIACRoot 'C:\Dropbox\whertzing\GitHub\ATAP.IAC-wt-11-Sprint-0010-work-items'

  .EXAMPLE
    # Sprint end - reset the machine profile back to the stable repositories
    Set-PowerShell7ProfileSymlink `
      -ATAPUtilitiesRoot 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities' `
      -ATAPIACRoot 'C:\Dropbox\whertzing\GitHub\ATAP.IAC'

  .NOTES
    AI assisted using ./.claude/Rules/Powershell.md as guidelines.
    Implements the deferred H09/SC-0188 profile-symlink retarget worker (Task 10.13).
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ATAPUtilitiesRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ATAPIACRoot,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PowerShell7Path = (Join-Path ${env:ProgramFiles} 'PowerShell\7'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProfileRelativePath = 'src\ATAP.Utilities.PowerShell\Profiles\AllUsersAllHostsV7CoreProfile.ps1',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$HostSettingsRelativePath = 'Windows\HostSettings.ps1',

    [Parameter()]
    [string[]]$ObsoleteLinkNames = @('global_ConfigRootKeys.ps1', 'global_environmentVariables.ps1'),

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
  }

  process {
    $links = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()

    # Managed links: link leaf name -> absolute target file the link must point at.
    $managed = [ordered]@{
      'profile.ps1'      = (Join-Path $ATAPUtilitiesRoot $ProfileRelativePath)
      'HostSettings.ps1' = (Join-Path $ATAPIACRoot $HostSettingsRelativePath)
    }

    foreach ($linkName in $managed.Keys) {
      $target = $managed[$linkName]
      $linkPath = Join-Path $PowerShell7Path $linkName
      $entry = [ordered]@{
        Name      = $linkName
        LinkPath  = $linkPath
        Target    = $target
        Action    = $null
        Succeeded = $false
        Error     = $null
      }

      # Never create a dangling link: the target file must exist first.
      if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $entry.Action = 'TargetMissing'
        $entry.Error = "Symlink target not found: '$target'"
        $failures.Add($entry.Error)
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.Error
        $links.Add([PSCustomObject]$entry)
        continue
      }

      if ($PSCmdlet.ShouldProcess($linkPath, "Retarget symlink -> '$target'")) {
        try {
          # -Force overwrites an existing link in place (Program Files-safe).
          New-Item -ItemType SymbolicLink -Path $linkPath -Target $target -Force -ErrorAction Stop | Out-Null
          $entry.Action = 'Retargeted'
          $entry.Succeeded = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retargeted '$linkPath' -> '$target'"
        } catch {
          $entry.Action = 'RetargetFailed'
          $entry.Error = "Failed to retarget '$linkPath': $($_.Exception.Message)"
          $failures.Add($entry.Error)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.Error
        }
      } else {
        $entry.Action = 'WouldRetarget'
        $entry.Succeeded = $true
      }

      $links.Add([PSCustomObject]$entry)
    }

    # Remove obsolete links that are no longer needed as symlinks.
    foreach ($linkName in @($ObsoleteLinkNames | Where-Object { $_ } | Select-Object -Unique)) {
      $linkPath = Join-Path $PowerShell7Path $linkName
      $entry = [ordered]@{
        Name      = $linkName
        LinkPath  = $linkPath
        Target    = $null
        Action    = $null
        Succeeded = $false
        Error     = $null
      }

      $existing = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
      if (-not $existing) {
        $entry.Action = 'ObsoleteAbsent'
        $entry.Succeeded = $true
        $links.Add([PSCustomObject]$entry)
        continue
      }

      $entry.Target = $existing.Target
      if ($PSCmdlet.ShouldProcess($linkPath, 'Remove obsolete symlink')) {
        try {
          # Removes only the link, never the target's contents. May require elevation
          # under Program Files; report rather than abort so an elevated run can finish.
          Remove-Item -LiteralPath $linkPath -Force -ErrorAction Stop
          $entry.Action = 'ObsoleteRemoved'
          $entry.Succeeded = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Removed obsolete symlink '$linkPath'"
        } catch {
          $entry.Action = 'ObsoleteRemoveFailed'
          $entry.Error = "Failed to remove obsolete symlink '$linkPath': $($_.Exception.Message)"
          $failures.Add($entry.Error)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.Error
        }
      } else {
        $entry.Action = 'WouldRemoveObsolete'
        $entry.Succeeded = $true
      }

      $links.Add([PSCustomObject]$entry)
    }

    $result = [PSCustomObject]@{
      PowerShell7Path = $PowerShell7Path
      DryRun          = [bool]$WhatIfPreference
      Links           = $links.ToArray()
      Failures        = $failures.ToArray()
      Ok              = ($failures.Count -eq 0)
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "Set-PowerShell7ProfileSymlink failed: $($result.Failures -join '; ')."
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
  }
}
