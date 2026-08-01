function Resolve-HostSuffixedSecretName {
  <#
  .SYNOPSIS
  Resolves the canonical host-suffixed SecretName for a placed ATAP service.

  .DESCRIPTION
  SC-0288 / Sprint 0013 Task 13.66 makes every ProGet and BuildMaster SecretName
  carry the host it belongs to, in the canonical form '<BaseName>.<host>'. The
  host is never hard-coded: it is derived from the reviewed service placement map
  in $global:Settings (ServicePlacementMap), which is the single human-controlled
  placement decision for the workspace.

  Resolution order:

    1. If -SettingName is supplied and $global:Settings carries a non-empty value
       for it, that value is authoritative and is returned unchanged. The host
       settings fragments already emit a host-suffixed SecretName there.
    2. Otherwise -BaseName is host-suffixed with the placement host for
       -ServiceName.

  The function fails closed whenever ATAP configuration is loaded but placement
  cannot be established: no placement map, the service absent from the map, an
  empty mapped value, a loopback placeholder, or a malformed host all throw
  rather than returning a suffixless or guessed name, because an incorrect
  SecretName silently authenticates against the wrong host's credential store.

  The one exception is a shell where no ATAP configuration exists at all -- both
  $global:Settings and $global:configRootKeys are null, as in a bare or hermetic
  test shell. There -BaseName is returned unchanged, because such a shell has no
  ProGet or BuildMaster endpoint configured either and cannot reach a service to
  authenticate against. That keeps the fail-closed guarantee where it matters (a
  configured shell whose placement is unknown or stale) without forcing every
  unrelated unit test to declare a placement map.

  Suffixing is idempotent and stale-suffix safe: a BaseName whose final segment
  matches a known host has that segment removed before the current placement host
  is appended. That keeps a legacy literal such as
  'BuildMaster.Admin.API.Key.utat01' correct after a DPOM failover to another
  host. Known hosts are the values present in the placement map, plus anything
  passed to -KnownHost, so the convention extends to hosts added later without a
  code change. A trailing segment that is not a known host is never stripped, so
  an ordinary SecretName base is left intact.

  .PARAMETER BaseName
  The canonical suffixless SecretName base, for example 'ProGet.Admin.API.Key'
  or 'BuildMaster.Admin.API.Key'. A trailing known-host segment is tolerated and
  replaced.

  .PARAMETER ServiceName
  The service key to look up in the placement map, for example 'ProGet' or
  'BuildMaster'.

  .PARAMETER SettingName
  Optional logical setting name (resolved through Resolve-BuildToolingSettingValue)
  holding an authoritative SecretName emitted by the host settings fragments. When
  it resolves to a non-empty value, that value wins.

  .PARAMETER PlacementHost
  Optional explicit placement host. Overrides the placement map. Intended for
  cross-host administration and for tests; production callers should let the map
  decide.

  .PARAMETER KnownHost
  Optional additional host names to recognize as stale suffixes on -BaseName.
  Use this to retire a decommissioned host's suffix that no longer appears in the
  placement map. Never used to choose the suffix, only to remove an old one.

  .OUTPUTS
  System.String. The host-suffixed SecretName. No secret value is read or returned.

  .EXAMPLE
  Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet'

  Returns 'ProGet.Admin.API.Key.utat022' when the placement map places ProGet on utat022.

  .EXAMPLE
  Resolve-HostSuffixedSecretName -BaseName 'BuildMaster.Admin.API.Key' -ServiceName 'BuildMaster' -PlacementHost 'utat01'

  Returns 'BuildMaster.Admin.API.Key.utat01' without consulting the placement map.

  .NOTES
  Returns names only. The value is resolved separately with Get-SecretATAP,
  immediately before the authenticated operation.

  .LINK
  Resolve-BuildToolingSettingValue
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'This resolver reads the repository-standard global configuration hashtables.'
  )]
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,

    [Parameter()]
    [string]$SettingName,

    [Parameter()]
    [string]$PlacementHost,

    [Parameter()]
    [string[]]$KnownHost = @()
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.Common.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Loopback aliases are never a credential-store identity; a SecretName suffixed
    # with one of these could not exist in the CI-Shared project.
    $nonPlacementHosts = @('localhost', '127.0.0.1', '::1', '.')
  }

  process {
    # ── 0. No ATAP configuration at all: nothing to place against ──
    # A shell in this state has no ProGet/BuildMaster endpoint either, so it can
    # reach no service; suffixing would be a guess and refusing would only break
    # unrelated hermetic tests. Any partially configured shell falls through to
    # the fail-closed checks below.
    if ($null -eq $global:Settings -and $null -eq $global:configRootKeys -and
      [string]::IsNullOrWhiteSpace($PlacementHost)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "No ATAP configuration is loaded; returning the unsuffixed SecretName base '$BaseName'."
      return $BaseName.Trim()
    }

    # ── 1. An authoritative setting from the host settings fragments wins ──
    if (-not [string]::IsNullOrWhiteSpace($SettingName) -and $null -ne $global:Settings) {
      $settingValue = $null
      try {
        $settingValue = Resolve-BuildToolingSettingValue -Name $SettingName -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Setting '$SettingName' is not available; deriving the SecretName from the placement map."
      }
      if ($null -ne $settingValue -and -not [string]::IsNullOrWhiteSpace([string]$settingValue)) {
        return ([string]$settingValue).Trim()
      }
    }

    # ── 2. Derive the placement host, failing closed when it is unknown ──
    $placementMap = $null
    if ($null -ne $global:Settings -and $null -ne $global:configRootKeys -and
      $global:configRootKeys.ContainsKey('ServicePlacementMapConfigRootKey')) {
      $placementMapKey = [string]$global:configRootKeys['ServicePlacementMapConfigRootKey']
      if (-not [string]::IsNullOrWhiteSpace($placementMapKey) -and $global:Settings.ContainsKey($placementMapKey)) {
        $placementMap = $global:Settings[$placementMapKey]
      }
    }

    $resolvedHost = $null
    if (-not [string]::IsNullOrWhiteSpace($PlacementHost)) {
      $resolvedHost = $PlacementHost.Trim()
    } elseif ($null -ne $placementMap -and $placementMap -is [System.Collections.IDictionary] -and
      $placementMap.Contains($ServiceName)) {
      $resolvedHost = [string]$placementMap[$ServiceName]
      if ($null -ne $resolvedHost) { $resolvedHost = $resolvedHost.Trim() }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedHost)) {
      $errorMessage = "The placement host for service '$ServiceName' could not be determined, so the host-suffixed SecretName for '$BaseName' cannot be built. Load the ATAP host settings so ServicePlacementMap is populated, or pass -PlacementHost explicitly."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    if ($nonPlacementHosts -contains $resolvedHost.ToLowerInvariant()) {
      $errorMessage = "Service '$ServiceName' resolved to the non-placement host '$resolvedHost'. A host-suffixed SecretName requires a real placement host; refusing to build a SecretName for '$BaseName'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
    if ($resolvedHost -notmatch '^[A-Za-z0-9]([A-Za-z0-9\-\.]*[A-Za-z0-9])?$') {
      $errorMessage = "Service '$ServiceName' resolved to '$resolvedHost', which is not a valid host name token. Refusing to build a SecretName for '$BaseName'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # ── 3. Strip a stale known-host suffix, then append the placement host ──
    # Known hosts are exactly the distinct values in the placement map plus the
    # resolved host, so the convention extends to new hosts without a code change.
    $knownHosts = [System.Collections.Generic.List[string]]::new()
    [void]$knownHosts.Add($resolvedHost)
    foreach ($extraHost in $KnownHost) {
      if (-not [string]::IsNullOrWhiteSpace($extraHost)) { [void]$knownHosts.Add($extraHost.Trim()) }
    }
    if ($null -ne $placementMap -and $placementMap -is [System.Collections.IDictionary]) {
      foreach ($placedHost in $placementMap.Values) {
        if (-not [string]::IsNullOrWhiteSpace([string]$placedHost)) {
          [void]$knownHosts.Add(([string]$placedHost).Trim())
        }
      }
    }

    $candidate = $BaseName.Trim()
    $lastSegment = $candidate.Substring($candidate.LastIndexOf('.') + 1)
    if ($candidate.Contains('.') -and
      ($knownHosts | Where-Object { $_ -ieq $lastSegment } | Select-Object -First 1)) {
      $candidate = $candidate.Substring(0, $candidate.LastIndexOf('.'))
    }

    if ([string]::IsNullOrWhiteSpace($candidate)) {
      $errorMessage = "SecretName base '$BaseName' reduced to an empty base after removing its host suffix; refusing to build a SecretName."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    return "$candidate.$resolvedHost"
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
