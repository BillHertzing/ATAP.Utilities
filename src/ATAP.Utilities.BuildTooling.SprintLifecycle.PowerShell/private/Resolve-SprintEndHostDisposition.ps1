function Test-SprintEndEnvironmentVariablePresent {
  <#
  .SYNOPSIS
    Returns presence metadata without returning an environment variable value.
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name,
    [Parameter(Mandatory)][ValidateSet('Process', 'User', 'Machine')][string]$Scope
  )

  process {
    return -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name, $Scope))
  }
}

function Get-SprintEndHostContext {
  <#
  .SYNOPSIS
    Reads the effective local Windows host, identity and elevation metadata.
  .NOTES
    Private mockable context seam. No environment or credential values are read.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param()

  process {
    if (-not [OperatingSystem]::IsWindows()) {
      throw 'SprintEnd host disposition requires a supported Windows execution context.'
    }
    $identity = $null
    try {
      $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
      if ($null -eq $identity) { throw 'SprintEnd Windows identity is unavailable.' }
      $principal = [Security.Principal.WindowsPrincipal]::new($identity)
      return [PSCustomObject]@{
        HostName = [Environment]::MachineName
        Identity = $identity.Name
        IsElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
      }
    } finally {
      if ($null -ne $identity) { $identity.Dispose() }
    }
  }
}

function Resolve-SprintEndHostDisposition {
  <#
  .SYNOPSIS
    Validates an explicit SprintEnd host disposition or selects strict defaults.
  .DESCRIPTION
    Binds the six-field nonsecret declaration to the effective Windows host and
    fully qualified identity. Only User/Process personal-vault session allowances
    for the whertzing account are supported. Task visibility remains a separate
    consumer check; IsElevated reports actual context and grants no authority.
  .PARAMETER HostDisposition
    Six-field declaration. Omission preserves strict behavior; explicit null is
    invalid. No arbitrary environment variable names or credential data is accepted.
  .OUTPUTS
    Normalized policy context and a detached six-field Metadata object.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [AllowNull()]
    [object]$HostDisposition
  )

  begin {
    $fn = 'Resolve-SprintEndHostDisposition'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
  }

  process {
    if (-not $PSBoundParameters.ContainsKey('HostDisposition')) {
      return [PSCustomObject]@{
        IsExplicit = $false
        DispositionId = 'StrictDefault'
        HostName = $null
        Identity = $null
        IsElevated = $false
        LoginTaskMode = 'RetainedPair'
        PersonalVaultSessionScopes = [string[]]@()
        Metadata = $null
      }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Validating explicit SprintEnd host disposition.'
    if ($null -eq $HostDisposition -or
      ($HostDisposition -isnot [Collections.IDictionary] -and $HostDisposition -isnot [PSCustomObject])) {
      throw 'HostDisposition must be a non-null six-field object.'
    }

    $fields = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($HostDisposition -is [Collections.IDictionary]) {
      foreach ($key in $HostDisposition.Keys) {
        if ($key -isnot [string] -or -not $fields.TryAdd($key, $HostDisposition[$key])) {
          throw 'HostDisposition contains an invalid or duplicate field.'
        }
      }
    } else {
      foreach ($property in $HostDisposition.PSObject.Properties) {
        if ($property.MemberType -ne [Management.Automation.PSMemberTypes]::NoteProperty -or
          -not $fields.TryAdd($property.Name, $property.Value)) {
          throw 'HostDisposition accepts distinct note properties only.'
        }
      }
    }
    $requiredFields = @('SchemaVersion', 'DispositionId', 'HostName', 'Identity', 'LoginTaskMode', 'PersonalVaultSessionScopes')
    if ($fields.Count -ne $requiredFields.Count -or @($requiredFields | Where-Object { -not $fields.ContainsKey($_) }).Count -gt 0) {
      throw 'HostDisposition requires exactly the six documented fields.'
    }
    $schema = $fields['SchemaVersion']
    $integerSchema = $schema -is [byte] -or $schema -is [sbyte] -or $schema -is [int16] -or $schema -is [uint16] -or
      $schema -is [int32] -or $schema -is [uint32] -or $schema -is [int64] -or $schema -is [uint64]
    if (-not $integerSchema -or $schema -ne 1) { throw 'HostDisposition SchemaVersion must be integer 1.' }
    if ($fields['DispositionId'] -isnot [string] -or $fields['DispositionId'] -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') {
      throw 'HostDisposition DispositionId must be a safe identifier of at most 80 characters.'
    }
    $hostPattern = '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
    $identityPattern = '^[A-Za-z0-9][A-Za-z0-9 ._$-]{0,127}\\[A-Za-z0-9][A-Za-z0-9 ._$-]{0,127}$'
    if ($fields['HostName'] -isnot [string] -or $fields['HostName'] -cnotmatch $hostPattern) {
      throw 'HostDisposition HostName must be an exact machine name without wildcards or qualifiers.'
    }
    if ($fields['Identity'] -isnot [string] -or $fields['Identity'] -cnotmatch $identityPattern -or
      @($fields['Identity'].Split([char]92) | Where-Object { $_ -cne $_.Trim() }).Count -gt 0) {
      throw 'HostDisposition Identity must be a fully qualified Windows identity without wildcards.'
    }
    if ($fields['LoginTaskMode'] -isnot [string] -or $fields['LoginTaskMode'] -notin @('RetainedPair', 'ExpectedAbsent')) {
      throw 'HostDisposition LoginTaskMode is unsupported.'
    }
    $scopes = $fields['PersonalVaultSessionScopes']
    if ($null -eq $scopes -or $scopes -isnot [Array] -or $scopes.Rank -ne 1) {
      throw 'HostDisposition PersonalVaultSessionScopes must be an array.'
    }
    $seenScopes = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($scope in $scopes) {
      if ($scope -isnot [string] -or $scope -notin @('User', 'Process') -or -not $seenScopes.Add($scope)) {
        throw 'HostDisposition permits distinct User/Process personal-vault scopes only.'
      }
    }
    $account = $fields['Identity'].Split([char]92)[1]
    if ($seenScopes.Count -gt 0 -and -not [StringComparer]::OrdinalIgnoreCase.Equals($account, 'whertzing')) {
      throw 'HostDisposition personal-vault session allowance is restricted to the whertzing account.'
    }

    $context = Get-SprintEndHostContext
    if ($null -eq $context -or $context -isnot [PSCustomObject] -or
      -not $context.PSObject.Properties['HostName'] -or -not $context.PSObject.Properties['Identity'] -or
      -not $context.PSObject.Properties['IsElevated'] -or $context.HostName -isnot [string] -or
      $context.Identity -isnot [string] -or $context.IsElevated -isnot [bool] -or
      $context.HostName -cnotmatch $hostPattern -or $context.Identity -cnotmatch $identityPattern -or
      @($context.Identity.Split([char]92) | Where-Object { $_ -cne $_.Trim() }).Count -gt 0) {
      throw 'SprintEnd host execution context could not be established.'
    }
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals($fields['HostName'], $context.HostName) -or
      -not [StringComparer]::OrdinalIgnoreCase.Equals($fields['Identity'], $context.Identity)) {
      throw 'HostDisposition does not match the effective host and fully qualified Windows identity.'
    }
    $normalizedScopes = [string[]]@('User', 'Process' | Where-Object { $seenScopes.Contains($_) })
    $normalizedMode = if ($fields['LoginTaskMode'] -ieq 'ExpectedAbsent') { 'ExpectedAbsent' } else { 'RetainedPair' }
    $metadata = [PSCustomObject][ordered]@{
      SchemaVersion = 1
      DispositionId = $fields['DispositionId']
      HostName = $context.HostName
      Identity = $context.Identity
      LoginTaskMode = $normalizedMode
      PersonalVaultSessionScopes = [string[]]@($normalizedScopes)
    }
    return [PSCustomObject]@{
      IsExplicit = $true
      DispositionId = $metadata.DispositionId
      HostName = $metadata.HostName
      Identity = $metadata.Identity
      IsElevated = $context.IsElevated
      LoginTaskMode = $metadata.LoginTaskMode
      PersonalVaultSessionScopes = [string[]]@($normalizedScopes)
      Metadata = $metadata
    }
  }
}
