function Set-SprintBoundaryUserProfiles {
  <#
  .SYNOPSIS
    Deploys sprint-boundary PowerShell user profiles for developers and local service accounts.
  .DESCRIPTION
    Resolves the active sprint or stable overview workspace to discover developer
    identities, bootstraps ATAP host settings to discover local service-account
    identities, selects developer assignments for the current host, and copies
    each applicable PowerShell 7 user profile to the path that identity loads.
    For the interactive identity this is `$PROFILE.CurrentUserAllHosts`, which
    honors redirected Documents known folders. Service-account profiles retain
    their configured `<Home>\Documents\PowerShell\profile.ps1` targets.

    Developer profiles copy the ATAP.IAC `CurrentUserAllHostsV7CoreProfile.ps1`
    payload. Service-account profiles copy the ATAP.IAC administrator-managed
    payload. Missing or disabled service accounts are skipped
    with explicit warnings so SprintEnd can proceed safely on hosts that do not
    provision every account.

    The function is idempotent: a managed target profile matching the rendered
    template is left in place and reported as `AlreadyCurrent`. User-owned
    profiles remain protected by Set-UserScopeProfile and are never replaced
    without its explicit -Force option. Every filesystem mutation runs under
    ShouldProcess.
  .PARAMETER ATAPUtilitiesRoot
    Repository or worktree root used to bootstrap ATAP configuration globals.
    Profile payloads are never discovered beneath this root; ATAP.IAC owns them.
  .PARAMETER ATAPIACRoot
    Repository or worktree root used to bootstrap host settings and discover
    service-account metadata.
  .PARAMETER GitRoot
    Parent directory containing the overview workspace files.
  .PARAMETER OverviewWorkspacePath
    Optional explicit path to the sprint or stable overview `.code-workspace`
    file. When omitted, the function prefers the newest canonical
    `Overview.Sprint.NNNN.code-workspace` beneath `GitRoot`, then checks legacy
    sprint spellings for compatibility before falling back to
    `Overview.code-workspace`.
  .PARAMETER HomeDirectoryOverrides
    Optional map of identity name to home-directory path. Intended for tests and
    narrowly scoped repairs.
  .PARAMETER CurrentUserAllHostsProfilePath
    The actual PowerShell 7 CurrentUserAllHosts path for the interactive
    identity. Defaults to `$PROFILE.CurrentUserAllHosts`; the explicit parameter
    is intended for deterministic tests and verified repairs.
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
    [AllowNull()]
    [AllowEmptyString()]
    [string]$CurrentUserAllHostsProfilePath = $PROFILE.CurrentUserAllHosts,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CurrentIdentityName = [Security.Principal.WindowsIdentity]::GetCurrent().Name,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    $localComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ([string]::IsNullOrWhiteSpace($CurrentUserAllHostsProfilePath)) {
      $documentsRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
      if ([string]::IsNullOrWhiteSpace($documentsRoot)) {
        if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
          throw 'Unable to resolve the current-user PowerShell profile path: both MyDocuments and USERPROFILE are empty.'
        }
        $documentsRoot = Join-Path $env:USERPROFILE 'Documents'
      }
      $CurrentUserAllHostsProfilePath = Join-Path $documentsRoot 'PowerShell\profile.ps1'
    }

    foreach ($privateHelperName in @('Get-WorkspaceJson', 'Initialize-ATAPConfigurationGlobals')) {
      if (-not (Get-Command -Name $privateHelperName -CommandType Function -ErrorAction SilentlyContinue)) {
        $privateHelperPath = Join-Path $PSScriptRoot '..' 'private' "$privateHelperName.ps1"
        if (Test-Path -LiteralPath $privateHelperPath -PathType Leaf) {
          . $privateHelperPath
        }
      }
    }

    $setUserScopeProfilePath = Join-Path $ATAPUtilitiesRoot `
      'src\ATAP.Utilities.BuildTooling.PowerShell\public\Set-UserScopeProfile.ps1'
    $setUserScopeProfileCommand = Get-Command -Name Set-UserScopeProfile -CommandType Function -ErrorAction SilentlyContinue
    if (-not $setUserScopeProfileCommand -and (Test-Path -LiteralPath $setUserScopeProfilePath -PathType Leaf)) {
      . $setUserScopeProfilePath
      $setUserScopeProfileCommand = Get-Command -Name Set-UserScopeProfile -CommandType Function -ErrorAction SilentlyContinue
    }
    if (-not $setUserScopeProfileCommand) {
      throw "Set-UserScopeProfile was not found at '$setUserScopeProfilePath' or in the current session."
    }
    if (-not $setUserScopeProfileCommand.Parameters.ContainsKey('TargetProfilePath')) {
      throw "Set-UserScopeProfile does not expose the required TargetProfilePath parameter. Resolved command: '$($setUserScopeProfileCommand.Source)'."
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

      if ($HostName -and -not [string]::Equals($HostName, $localComputerName, [StringComparison]::OrdinalIgnoreCase)) {
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

      $workspaceFiles = @()
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'Overview.Sprint.*.code-workspace' -ErrorAction SilentlyContinue
      # Legacy compatibility only; new workspaces use Overview.Sprint.NNNN.
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'Overview.Sprint*.code-workspace' -ErrorAction SilentlyContinue
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'OverviewSprint*.code-workspace' -ErrorAction SilentlyContinue
      $workspaceFiles += Get-ChildItem -LiteralPath $GitRoot -File -Filter 'OverViewSprint*.code-workspace' -ErrorAction SilentlyContinue
      $candidates = @($workspaceFiles | Sort-Object LastWriteTime -Descending)
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

    $developerSourcePath = Join-Path $ATAPIACRoot 'Windows\ProfileTemplates\CurrentUserAllHostsV7CoreProfile.ps1'
    $serviceSourcePath = Join-Path $ATAPIACRoot 'Windows\ProfileTemplates\ProfileForServiceAccountUsers.ps1'
    $approvedServiceAccountPolicy = @{
      SvcBuildMaster = $true
      SvcProGet = $true
      SvcSQLServer = $true
      SvcSeq = $false
      SvcParityAudit = $false
    }

    $profiles = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
  }

  process {
    $overviewWorkspace = Resolve-OverviewWorkspace -WorkspacePath $OverviewWorkspacePath
    $workspaceJson = if ($overviewWorkspace) { Get-WorkspaceJson -WorkspaceFile $overviewWorkspace } else { $null }

    $developerIdentities = @()
    if ($workspaceJson -and $workspaceJson.PSObject.Properties['developers']) {
      $developerIdentities = @(
        $workspaceJson.developers |
          Where-Object {
            -not $_.PSObject.Properties['host'] -or
            [string]::IsNullOrWhiteSpace([string]$_.host) -or
            [string]::Equals([string]$_.host, $localComputerName, [StringComparison]::OrdinalIgnoreCase)
          }
      )
    }

    foreach ($developer in $developerIdentities) {
      $username = [string]$developer.username
      if ([string]::IsNullOrWhiteSpace($username)) {
        continue
      }

      $developerHost = if ($developer.PSObject.Properties['host']) { [string]$developer.host } else { $null }
      $homeDirectory = Resolve-HomeDirectory -Identity $username -HostName $developerHost
      $leafUsername = Resolve-LeafName -Identity $username
      $isCurrentIdentity = [string]::Equals($leafUsername, $env:USERNAME, [StringComparison]::OrdinalIgnoreCase)
      $profilePath = if ($homeDirectory -and $isCurrentIdentity) {
        [IO.Path]::GetFullPath($CurrentUserAllHostsProfilePath)
      } elseif ($homeDirectory) {
        Join-Path $homeDirectory 'Documents\PowerShell\profile.ps1'
      } else {
        $null
      }
      $skipReason = $null
      $isFailure = $false

      if ($developerHost -and -not [string]::Equals($developerHost, $localComputerName, [StringComparison]::OrdinalIgnoreCase)) {
        $skipReason = "Developer '$username' belongs to host '$developerHost', not '$localComputerName'."
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
      if (-not $approvedServiceAccountPolicy.ContainsKey($leafIdentity)) {
        [void]$warnings.Add("Ignoring discovered service account '$identity' because it is outside the user-approved Task 12.49 scope.")
        continue
      }
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
        $skipReason = "Service account '$identity' is not present on host '$localComputerName'."
        [void]$warnings.Add($skipReason)
      } elseif ($localUser.PSObject.Properties['Enabled'] -and -not [bool]$localUser.Enabled) {
        $skipReason = "Service account '$identity' is disabled on host '$localComputerName'."
        [void]$warnings.Add($skipReason)
      } elseif ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        $skipReason = "Home directory could not be resolved for service account '$identity'."
        [void]$failures.Add($skipReason)
        $isFailure = $true
      }

      [void]$profiles.Add([PSCustomObject]@{
          Identity      = $identity
          Kind          = 'ServiceAccount'
          Host          = $localComputerName
          HomeDirectory = $homeDirectory
          ProfilePath   = $profilePath
          SourcePath    = $serviceSourcePath
          RequiresSecret = [bool]$approvedServiceAccountPolicy[$leafIdentity]
          Skipped       = [bool]$skipReason -and -not $isFailure
          Warning       = if ($isFailure) { $null } else { $skipReason }
          Error         = if ($isFailure) { $skipReason } else { $null }
          Succeeded     = $false
          Action        = $null
          LinkTarget    = $null
          SourceMatch   = $false
        })
    }

    # ConfigRootKeys remain the preferred source because they can carry a
    # host-qualified identity and an explicit home. Some established ATAP
    # service accounts predate those keys, however. Merge in only approved
    # local accounts that are actually present, without broad account
    # discovery or changing the approved secret policy.
    $discoveredServiceLeafNames = @(
      $profiles |
        Where-Object Kind -EQ 'ServiceAccount' |
        ForEach-Object { Resolve-LeafName -Identity $_.Identity }
    )

    foreach ($approvedIdentity in @(
        $approvedServiceAccountPolicy.Keys |
          Where-Object { [bool]$approvedServiceAccountPolicy[$_] } |
          Sort-Object
      )) {
      if ($discoveredServiceLeafNames -contains $approvedIdentity) {
        continue
      }

      $localUser = $null
      try {
        $localUser = Get-LocalUser -Name $approvedIdentity -ErrorAction Stop
      } catch {
        $localUser = $null
      }

      if ($null -eq $localUser) {
        continue
      }

      $identity = [string]$localUser.Name
      $homeDirectory = Resolve-HomeDirectory -Identity $identity -HostName $null
      $profilePath = if ($homeDirectory) { Join-Path $homeDirectory 'Documents\PowerShell\profile.ps1' } else { $null }
      $skipReason = $null
      $isFailure = $false

      if ($localUser.PSObject.Properties['Enabled'] -and -not [bool]$localUser.Enabled) {
        $skipReason = "Service account '$identity' is disabled on host '$localComputerName'."
        [void]$warnings.Add($skipReason)
      } elseif ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        $skipReason = "Home directory could not be resolved for service account '$identity'."
        [void]$failures.Add($skipReason)
        $isFailure = $true
      }

      [void]$profiles.Add([PSCustomObject]@{
          Identity       = $identity
          Kind           = 'ServiceAccount'
          Host           = $localComputerName
          HomeDirectory  = $homeDirectory
          ProfilePath    = $profilePath
          SourcePath     = $serviceSourcePath
          RequiresSecret = [bool]$approvedServiceAccountPolicy[$approvedIdentity]
          Skipped        = [bool]$skipReason -and -not $isFailure
          Warning        = if ($isFailure) { $null } else { $skipReason }
          Error          = if ($isFailure) { $skipReason } else { $null }
          Succeeded      = $false
          Action         = $null
          LinkTarget     = $null
          SourceMatch    = $false
        })
    }
    $currentIdentityLeaf = Resolve-LeafName -Identity $CurrentIdentityName
    $currentIdentityIsApprovedServiceAccount = $approvedServiceAccountPolicy.ContainsKey($currentIdentityLeaf)
    foreach ($profile in $profiles) {
      if (
        $profile.Kind -eq 'ServiceAccount' -and
        $currentIdentityIsApprovedServiceAccount -and
        -not [string]::Equals(
          (Resolve-LeafName -Identity $profile.Identity),
          $currentIdentityLeaf,
          [StringComparison]::OrdinalIgnoreCase
        )
      ) {
        $profile.Warning = "Service identity '$currentIdentityLeaf' may verify only its own profile; cross-account profile management is skipped."
        [void]$warnings.Add($profile.Warning)
        $profile.Action = 'Skipped'
        $profile.Succeeded = $true
        continue
      }
      if ($profile.Warning) {
        $profile.Action = 'Skipped'
        $profile.Succeeded = $true
        continue
      }

      if ($profile.Error) {
        $profile.Action = 'ResolveFailed'
        continue
      }

      try {
        $profileResult = Set-UserScopeProfile `
          -AccountName $profile.Identity `
          -AccountClass $profile.Kind `
          -ATAPIACRoot $ATAPIACRoot `
          -ATAPUtilitiesRoot $ATAPUtilitiesRoot `
          -UserProfilePath $profile.HomeDirectory `
          -TargetProfilePath $profile.ProfilePath `
          -Confirm:$false `
          -WhatIf:$WhatIfPreference
        $profile.Action = $profileResult.Action
        $profile.Succeeded = $true
        $profile.SourceMatch = $profileResult.Action -eq 'AlreadyCurrent'
      } catch {
        $profile.Action = 'ProvisionFailed'
        $profile.Error = "Failed to provision profile '$($profile.ProfilePath)': $($_.Exception.Message)"
        [void]$failures.Add($profile.Error)
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
