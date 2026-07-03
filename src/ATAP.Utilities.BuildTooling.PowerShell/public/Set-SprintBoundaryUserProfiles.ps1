function Set-SprintBoundaryUserProfiles {
  <#
  .SYNOPSIS
    Deploys sprint-boundary PowerShell user profiles for developers and local service accounts.
  .DESCRIPTION
    Resolves the active sprint or stable overview workspace to discover developer
    identities, bootstraps ATAP host settings to discover local service-account
    identities, and installs each applicable PowerShell 7 user profile as
    `<Home>\Documents\PowerShell\profile.ps1`.

    Developer profiles always point at
    `CurrentUserAllHostsV7CoreProfile.ps1` beneath the supplied
    `ATAPUtilitiesRoot`. Service-account profiles always point at
    `ProfileForServiceAccountUsers.ps1` beneath the same root. Missing or
    disabled service accounts are skipped with explicit warnings so SprintEnd can
    proceed safely on hosts that do not provision every account.

    The function is idempotent: if a target profile already points at or matches
    the expected source, it is left in place and reported as `AlreadyCurrent`.
    Every filesystem mutation runs under ShouldProcess.
  .PARAMETER ATAPUtilitiesRoot
    Repository or worktree root that owns the canonical profile sources.
  .PARAMETER ATAPIACRoot
    Repository or worktree root used to bootstrap host settings and discover
    service-account metadata.
  .PARAMETER GitRoot
    Parent directory containing the overview workspace files.
  .PARAMETER OverviewWorkspacePath
    Optional explicit path to the sprint or stable overview `.code-workspace`
    file. When omitted, the function prefers the newest `OverviewSprint*.code-workspace`
    beneath `GitRoot`, then falls back to `Overview.code-workspace` or
    `OverView.code-workspace`.
  .PARAMETER HomeDirectoryOverrides
    Optional map of identity name to home-directory path. Intended for tests and
    narrowly scoped repairs.
  .PARAMETER ThrowOnFailure
    Throws when any non-skipped developer or service-account profile could not be
    resolved or deployed.
  .OUTPUTS
    PSCustomObject with `Profiles`, `Warnings`, `Failures`, and `Ok`.
  .EXAMPLE
    Set-SprintBoundaryUserProfiles `
      -ATAPUtilitiesRoot 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-118-Sprint-0011-work-items' `
      -ATAPIACRoot 'C:\Dropbox\whertzing\GitHub\ATAP.IAC-wt-13-Sprint-0011-work-items'
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
    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [Parameter()]
    [string]$OverviewWorkspacePath,

    [Parameter()]
    [hashtable]$HomeDirectoryOverrides = @{},

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    foreach ($privateHelperName in @('Get-WorkspaceJson', 'Initialize-ATAPConfigurationGlobals')) {
      if (-not (Get-Command -Name $privateHelperName -CommandType Function -ErrorAction SilentlyContinue)) {
        $privateHelperPath = Join-Path $PSScriptRoot '..' 'private' "$privateHelperName.ps1"
        if (Test-Path -LiteralPath $privateHelperPath -PathType Leaf) {
          . $privateHelperPath
        }
      }
    }

    function Resolve-LeafName {
      param([string]$Identity)
      if ([string]::IsNullOrWhiteSpace($Identity)) {
        return $Identity
      }

      return ($Identity -replace '^[^\\]+\\', '' -replace '^\.\s*\\', '').Trim()
    }

    function Resolve-HomeDirectory {
      param(
        [string]$Identity,
        [string]$HostName
      )

      if ($HomeDirectoryOverrides.ContainsKey($Identity)) {
        return [IO.Path]::GetFullPath([string]$HomeDirectoryOverrides[$Identity])
      }

      $leafName = Resolve-LeafName -Identity $Identity
      if ($HomeDirectoryOverrides.ContainsKey($leafName)) {
        return [IO.Path]::GetFullPath([string]$HomeDirectoryOverrides[$leafName])
      }

      if ($HostName -and -not [string]::Equals($HostName, $env:COMPUTERNAME, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
      }

      if ([string]::Equals($leafName, $env:USERNAME, [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::GetFullPath($env:USERPROFILE)
      }

      $usersRoot = Join-Path ([IO.Path]::GetPathRoot($env:SystemDrive)) 'Users'
      $candidate = Join-Path $usersRoot $leafName
      if (Test-Path -LiteralPath $candidate -PathType Container) {
        return [IO.Path]::GetFullPath($candidate)
      }

      return $null
    }

    function Resolve-OverviewWorkspace {
      param([string]$WorkspacePath)

      if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
        return [IO.Path]::GetFullPath($WorkspacePath)
      }

      $candidates = @(
        Get-ChildItem -LiteralPath $GitRoot -File -Filter 'OverviewSprint*.code-workspace' -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending
      )
      if ($candidates.Count -gt 0) {
        return $candidates[0].FullName
      }

      foreach ($fallbackName in @('Overview.code-workspace', 'OverView.code-workspace')) {
        $fallbackPath = Join-Path $GitRoot $fallbackName
        if (Test-Path -LiteralPath $fallbackPath -PathType Leaf) {
          return $fallbackPath
        }
      }

      return $null
    }

    function Test-ProfileMatchesSource {
      param(
        [string]$ProfilePath,
        [string]$SourcePath
      )

      if (-not ((Test-Path -LiteralPath $ProfilePath -PathType Leaf) -and (Test-Path -LiteralPath $SourcePath -PathType Leaf))) {
        return $false
      }

      $existingItem = Get-Item -LiteralPath $ProfilePath -Force -ErrorAction SilentlyContinue
      $existingTarget = if ($existingItem -and $existingItem.PSObject.Properties['Target']) {
        @($existingItem.Target) | Select-Object -First 1
      } else {
        $null
      }

      if (-not [string]::IsNullOrWhiteSpace($existingTarget)) {
        $resolvedSource = [IO.Path]::GetFullPath($SourcePath)
        $resolvedTarget = [IO.Path]::GetFullPath([string]$existingTarget)
        if ([string]::Equals($resolvedSource, $resolvedTarget, [StringComparison]::OrdinalIgnoreCase)) {
          return $true
        }
      }

      return [string]::Equals(
        (Get-Content -LiteralPath $ProfilePath -Raw -ErrorAction SilentlyContinue),
        (Get-Content -LiteralPath $SourcePath -Raw -ErrorAction SilentlyContinue),
        [StringComparison]::Ordinal
      )
    }

    $developerSourcePath = Join-Path $ATAPUtilitiesRoot 'src\ATAP.Utilities.PowerShell\Profiles\CurrentUserAllHostsV7CoreProfile.ps1'
    $serviceSourcePath = Join-Path $ATAPUtilitiesRoot 'src\ATAP.Utilities.PowerShell\Profiles\ProfileForServiceAccountUsers.ps1'

    $profiles = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
  }

  process {
    $overviewWorkspace = Resolve-OverviewWorkspace -WorkspacePath $OverviewWorkspacePath
    $workspaceJson = if ($overviewWorkspace) { Get-WorkspaceJson -WorkspaceFile $overviewWorkspace } else { $null }

    $developerIdentities = @()
    if ($workspaceJson -and $workspaceJson.PSObject.Properties['developers']) {
      $developerIdentities = @($workspaceJson.developers)
    }

    foreach ($developer in $developerIdentities) {
      $username = [string]$developer.username
      if ([string]::IsNullOrWhiteSpace($username)) {
        continue
      }

      $developerHost = if ($developer.PSObject.Properties['host']) { [string]$developer.host } else { $null }
      $homeDirectory = Resolve-HomeDirectory -Identity $username -HostName $developerHost
      $profilePath = if ($homeDirectory) { Join-Path $homeDirectory 'Documents\PowerShell\profile.ps1' } else { $null }
      $skipReason = $null
      $isFailure = $false

      if ($developerHost -and -not [string]::Equals($developerHost, $env:COMPUTERNAME, [StringComparison]::OrdinalIgnoreCase)) {
        $skipReason = "Developer '$username' belongs to host '$developerHost', not '$env:COMPUTERNAME'."
        [void]$warnings.Add($skipReason)
      } elseif ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        $skipReason = "Home directory could not be resolved for developer '$username'."
        [void]$failures.Add($skipReason)
        $isFailure = $true
      }

      [void]$profiles.Add([PSCustomObject]@{
          Identity      = $username
          Kind          = 'Developer'
          Host          = $developerHost
          HomeDirectory = $homeDirectory
          ProfilePath   = $profilePath
          SourcePath    = $developerSourcePath
          Skipped       = [bool]$skipReason -and -not $isFailure
          Warning       = if ($isFailure) { $null } else { $skipReason }
          Error         = if ($isFailure) { $skipReason } else { $null }
          Succeeded     = $false
          Action        = $null
          LinkTarget    = $null
          SourceMatch   = $false
        })
    }

    Initialize-ATAPConfigurationGlobals `
      -RepositoryRoot $ATAPUtilitiesRoot `
      -IACBasePath $ATAPIACRoot `
      -Force `
      -Confirm:$false `
      -WhatIf:$false | Out-Null

    $servicePrefixes = @(
      $global:configRootKeys.Keys |
        Where-Object { $_ -match '^(?<Prefix>.+ServiceAccount)ConfigRootKey$' } |
        ForEach-Object { $Matches['Prefix'] } |
        Sort-Object -Unique
    )

    foreach ($prefix in $servicePrefixes) {
      $accountConfigKeyName = "${prefix}ConfigRootKey"
      $homeConfigKeyName = "${prefix}UserHomeDirectoryConfigRootKey"
      if (-not ($global:configRootKeys.ContainsKey($accountConfigKeyName) -and $global:configRootKeys.ContainsKey($homeConfigKeyName))) {
        continue
      }

      $accountSettingKey = [string]$global:configRootKeys[$accountConfigKeyName]
      $homeSettingKey = [string]$global:configRootKeys[$homeConfigKeyName]
      $identity = [string]$global:settings[$accountSettingKey]
      if ([string]::IsNullOrWhiteSpace($identity)) {
        continue
      }

      $configuredHome = [string]$global:settings[$homeSettingKey]
      $leafIdentity = Resolve-LeafName -Identity $identity
      $localUser = $null
      try {
        $localUser = Get-LocalUser -Name $leafIdentity -ErrorAction Stop
      } catch {
        $localUser = $null
      }

      $homeDirectory = if ($HomeDirectoryOverrides.ContainsKey($identity) -or $HomeDirectoryOverrides.ContainsKey($leafIdentity)) {
        Resolve-HomeDirectory -Identity $identity -HostName $null
      } elseif (-not [string]::IsNullOrWhiteSpace($configuredHome)) {
        [IO.Path]::GetFullPath($configuredHome)
      } else {
        $null
      }

      $profilePath = if ($homeDirectory) { Join-Path $homeDirectory 'Documents\PowerShell\profile.ps1' } else { $null }
      $skipReason = $null
      $isFailure = $false

      if ($null -eq $localUser) {
        $skipReason = "Service account '$identity' is not present on host '$env:COMPUTERNAME'."
        [void]$warnings.Add($skipReason)
      } elseif ($localUser.PSObject.Properties['Enabled'] -and -not [bool]$localUser.Enabled) {
        $skipReason = "Service account '$identity' is disabled on host '$env:COMPUTERNAME'."
        [void]$warnings.Add($skipReason)
      } elseif ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        $skipReason = "Home directory could not be resolved for service account '$identity'."
        [void]$failures.Add($skipReason)
        $isFailure = $true
      }

      [void]$profiles.Add([PSCustomObject]@{
          Identity      = $identity
          Kind          = 'ServiceAccount'
          Host          = $env:COMPUTERNAME
          HomeDirectory = $homeDirectory
          ProfilePath   = $profilePath
          SourcePath    = $serviceSourcePath
          Skipped       = [bool]$skipReason -and -not $isFailure
          Warning       = if ($isFailure) { $null } else { $skipReason }
          Error         = if ($isFailure) { $skipReason } else { $null }
          Succeeded     = $false
          Action        = $null
          LinkTarget    = $null
          SourceMatch   = $false
        })
    }

    foreach ($profile in $profiles) {
      if ($profile.Warning) {
        $profile.Action = 'Skipped'
        $profile.Succeeded = $true
        continue
      }

      if ($profile.Error) {
        $profile.Action = 'ResolveFailed'
        continue
      }

      if (-not (Test-Path -LiteralPath $profile.SourcePath -PathType Leaf)) {
        $profile.Action = 'SourceMissing'
        $profile.Error = "Profile source not found: '$($profile.SourcePath)'"
        [void]$failures.Add($profile.Error)
        continue
      }

      $profile.SourceMatch = Test-ProfileMatchesSource -ProfilePath $profile.ProfilePath -SourcePath $profile.SourcePath
      if ($profile.SourceMatch) {
        $existingItem = Get-Item -LiteralPath $profile.ProfilePath -Force -ErrorAction SilentlyContinue
        $profile.LinkTarget = if ($existingItem -and $existingItem.PSObject.Properties['Target']) {
          @($existingItem.Target) | Select-Object -First 1
        } else {
          $null
        }
        $profile.Action = 'AlreadyCurrent'
        $profile.Succeeded = $true
        continue
      }

      $profileDirectory = Split-Path -Path $profile.ProfilePath -Parent
      $actionDescription = "$($profile.Kind) profile for '$($profile.Identity)' -> '$($profile.SourcePath)'"
      if ($PSCmdlet.ShouldProcess($profile.ProfilePath, $actionDescription)) {
        try {
          if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
            New-Item -ItemType Directory -Path $profileDirectory -Force -ErrorAction Stop | Out-Null
          }

          if (Test-Path -LiteralPath $profile.ProfilePath -PathType Leaf) {
            Remove-Item -LiteralPath $profile.ProfilePath -Force -ErrorAction Stop
          }

          New-Item -ItemType SymbolicLink -Path $profile.ProfilePath -Target $profile.SourcePath -Force -ErrorAction Stop | Out-Null
          $existingItem = Get-Item -LiteralPath $profile.ProfilePath -Force -ErrorAction SilentlyContinue
          $profile.LinkTarget = if ($existingItem -and $existingItem.PSObject.Properties['Target']) {
            @($existingItem.Target) | Select-Object -First 1
          } else {
            $null
          }
          $profile.SourceMatch = Test-ProfileMatchesSource -ProfilePath $profile.ProfilePath -SourcePath $profile.SourcePath
          $profile.Action = 'Retargeted'
          $profile.Succeeded = $profile.SourceMatch
          if (-not $profile.Succeeded) {
            $profile.Error = "Profile deployment completed but '$($profile.ProfilePath)' does not match '$($profile.SourcePath)'."
            [void]$failures.Add($profile.Error)
          }
        } catch {
          $profile.Action = 'RetargetFailed'
          $profile.Error = "Failed to deploy profile '$($profile.ProfilePath)': $($_.Exception.Message)"
          [void]$failures.Add($profile.Error)
        }
      } else {
        $profile.Action = if (Test-Path -LiteralPath $profile.ProfilePath -PathType Leaf) { 'WouldRetarget' } else { 'WouldCreate' }
        $profile.Succeeded = $true
      }
    }

    $result = [PSCustomObject]@{
      Ok                   = ($failures.Count -eq 0)
      OverviewWorkspacePath = $overviewWorkspace
      Profiles             = $profiles.ToArray()
      Warnings             = $warnings.ToArray()
      Failures             = $failures.ToArray()
    }

    if (-not $result.Ok -and $ThrowOnFailure) {
      throw "Set-SprintBoundaryUserProfiles failed: $($result.Failures -join '; ')"
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
