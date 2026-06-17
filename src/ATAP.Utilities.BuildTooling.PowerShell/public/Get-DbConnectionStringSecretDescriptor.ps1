function Get-DbConnectionStringSecretDescriptor {
  <#
  .SYNOPSIS
    Single source of truth for the SQL connection-string secret format AND the
    derivable-vs-credentialed classification used by the sprint secret writer and
    the database connection-string reader.

  .DESCRIPTION
    Task 9.22 (bws-write workaround). The per-sprint connection-string secrets
    (dbConnectionString-<db>-<host>-<Dev|Exp>-<user>) currently contain NO
    credential - they are deterministic Integrated-Security strings built entirely
    from host / tier / database / user, identical every sprint under the
    permanent-instance lifecycle. Because the Bitwarden Secrets Manager (bws) write
    path is broken, those secrets cannot be stored in the vault - but they also do
    not need to be, because the value can be regenerated at read time.

    This helper centralizes BOTH concerns in one place so the eventual switch to
    real credentialed secrets is a configuration change, not a rewrite:

      1. The connection-string FORMAT lives here once. Both the writer
         (New-SprintBitwardenSecrets) and the deterministic read-time fallback
         (Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName) call this
         helper rather than hand-building the string.

      2. The CLASSIFICATION lives here once. A secret is 'derivable' when its value
         can be reproduced with no credential (Integrated Security, sprint tier),
         or 'credentialed' when it MUST come from the vault (a real secret). The
         "is this derivable?" test is intentionally simple: a sprint tier
         (Dev / Exp) with no overriding credentialed flag is derivable; everything
         else is credentialed. When credentials are added later, those names are
         listed in -CredentialedSecretName (or their tier removed from
         -DerivableTier) and they stop being derived - without touching any caller.

    Two modes:

      ByName  - parse a canonical secret name into its parts and classify it.
                Used by the reader to decide whether a missing vault secret can be
                rebuilt deterministically.

      ByParts - build the canonical secret name (and, when derivable, the
                connection string) from explicit parts. Used by the writer to
                decide, per secret, whether a vault write is required at all.

    The deterministic connection string is ONLY produced for derivable secrets.
    For credentialed secrets ConnectionString is $null - the caller MUST read the
    real value from the vault and MUST fail loudly if it is absent. This helper
    never derives a credentialed string.

  .PARAMETER SecretName
    ByName mode. A canonical connection-string secret name of the form
    dbConnectionString-<Database>-<Host>-<Tier>[-<User>]. Database names and tier
    tokens contain no hyphens; hyphenated hosts/users are tolerated because the
    tier token is located by value, not position.

  .PARAMETER DatabaseName
    ByParts mode. The logical database name (e.g. 'ATAPUtilities', 'AceCommander').

  .PARAMETER DatabaseHost
    ByParts mode. The SQL Server host name (e.g. 'localhost' or the machine name).

  .PARAMETER Environment
    ByParts mode. The deployment tier. One of Production, QA, Integration,
    Development, Experimental, Dev, Exp. Development/Experimental are normalized to
    Dev/Exp.

  .PARAMETER UserName
    ByParts mode. The developer's Windows username, required for sprint tiers
    (Dev / Exp). Defaults to $env:USERNAME when omitted for a sprint tier.

  .PARAMETER DerivableTier
    The set of normalized tier tokens whose values can be reproduced with no
    credential. Defaults to @('Dev','Exp'). Narrow this (or list specific names in
    -CredentialedSecretName) when a tier starts carrying a real credential.

  .PARAMETER CredentialedSecretName
    Explicit secret names that MUST be treated as credentialed even if their tier
    would otherwise be derivable. The forward-compatibility seam for individual
    credentialed secrets.

  .OUTPUTS
    [pscustomobject] with properties:
      SecretName       - canonical secret name
      DatabaseName     - parsed/supplied database name (or $null if unparsable)
      DatabaseHost     - parsed/supplied host (or $null)
      Environment      - normalized tier token Dev|Exp|Production|QA|Integration (or $null)
      UserName         - developer username for sprint tiers (or $null)
      Classification   - 'derivable' or 'credentialed'
      IsDerivable      - [bool]
      ConnectionString - deterministic connection string when derivable, else $null

  .EXAMPLE
    Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'
    # IsDerivable = $true; ConnectionString built deterministically.

  .EXAMPLE
    Get-DbConnectionStringSecretDescriptor -DatabaseName 'master' -DatabaseHost 'localhost' -Environment 'Exp' -UserName 'jsmith'
    # SecretName = dbConnectionString-master-localhost-Exp-jsmith; derivable.

  .EXAMPLE
    Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-ATAPUtilities-sql01-Production'
    # IsDerivable = $false (permanent tier); ConnectionString = $null - must come from the vault.

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. See
    Research/Bitwarden-Secret-Write-Workaround.md for the design rationale.
  .LINK
    New-SprintBitwardenSecrets
  .LINK
    Get-DatabaseCredentialsKey
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialedSecretName',
    Justification = 'CredentialedSecretName is a list of vault secret NAMES, not credential values')]
  [CmdletBinding(DefaultParameterSetName = 'ByName')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string] $SecretName,

    [Parameter(ParameterSetName = 'ByParts', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string] $DatabaseName,

    [Parameter(ParameterSetName = 'ByParts', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string] $DatabaseHost,

    [Parameter(ParameterSetName = 'ByParts', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateSet('Production', 'QA', 'Integration', 'Development', 'Experimental', 'Dev', 'Exp')]
    [string] $Environment,

    [Parameter(ParameterSetName = 'ByParts', Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string] $UserName,

    [Parameter(Mandatory = $false)]
    [string[]] $DerivableTier = @('Dev', 'Exp'),

    [Parameter(Mandatory = $false)]
    [string[]] $CredentialedSecretName = @()
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # All recognized tier tokens, plus the long-form aliases normalized to the
    # short tokens the secret name uses.
    $script:knownTierTokens = @('Dev', 'Exp', 'Production', 'QA', 'Integration')
    $tierAliasMap = @{
      'Development'  = 'Dev'
      'Experimental' = 'Exp'
      'Dev'          = 'Dev'
      'Exp'          = 'Exp'
      'Production'   = 'Production'
      'QA'           = 'QA'
      'Integration'  = 'Integration'
    }

    $credentialedLookup = @{}
    foreach ($cn in $CredentialedSecretName) {
      if (-not [string]::IsNullOrWhiteSpace($cn)) {
        $credentialedLookup[$cn.ToLowerInvariant()] = $true
      }
    }

    # The connection-string FORMAT - defined exactly once for the whole ecosystem.
    # Derivable (sprint) instances are named <Tier><UserName> (e.g. Devjsmith) and
    # use Windows Integrated Security, so the value carries no credential.
    $buildDeterministicConnectionString = {
      param([string] $DbName, [string] $DbHost, [string] $Tier, [string] $User)
      $instanceName = "${Tier}${User}"
      return "Server=${DbHost}\${instanceName};Database=${DbName};Integrated Security=True;" +
      'MultipleActiveResultSets=True;TrustServerCertificate=True;'
    }
  }

  process {
    $parsedDatabaseName = $null
    $parsedDatabaseHost = $null
    $normalizedTier = $null
    $parsedUserName = $null
    $canonicalName = $null

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
      $canonicalName = $SecretName

      $prefix = 'dbConnectionString-'
      if (-not $SecretName.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        # Not a recognized connection-string secret name; cannot derive.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Secret name '$SecretName' does not match the dbConnectionString- convention; classified credentialed (vault-only)." -Tag 'ConnectionString'
      } else {
        $remainder = $SecretName.Substring($prefix.Length)
        $segments = @($remainder -split '-')

        if ($segments.Count -ge 3) {
          $parsedDatabaseName = $segments[0]

          # Locate the tier token by value (host names may contain hyphens, so a
          # positional parse is not reliable). Search from index 2 because the
          # host occupies at least segment[1].
          $tierIndex = -1
          for ($i = 2; $i -lt $segments.Count; $i++) {
            if ($tierAliasMap.ContainsKey($segments[$i])) {
              $tierIndex = $i
              break
            }
          }

          if ($tierIndex -ge 2) {
            $parsedDatabaseHost = ($segments[1..($tierIndex - 1)] -join '-')
            $normalizedTier = $tierAliasMap[$segments[$tierIndex]]
            if ($tierIndex -lt ($segments.Count - 1)) {
              $parsedUserName = ($segments[($tierIndex + 1)..($segments.Count - 1)] -join '-')
            }
          } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Secret name '$SecretName' has no recognizable tier token; classified credentialed (vault-only)." -Tag 'ConnectionString'
          }
        }
      }
    } else {
      # ByParts
      $parsedDatabaseName = $DatabaseName
      $parsedDatabaseHost = $DatabaseHost
      $normalizedTier = $tierAliasMap[$Environment]
      $parsedUserName = $UserName

      $sprintTier = $normalizedTier -in @('Dev', 'Exp')
      if ($sprintTier -and [string]::IsNullOrWhiteSpace($parsedUserName)) {
        $parsedUserName = $env:USERNAME
      }

      if ($sprintTier) {
        $canonicalName = "dbConnectionString-$parsedDatabaseName-$parsedDatabaseHost-$normalizedTier-$parsedUserName"
      } else {
        $canonicalName = "dbConnectionString-$parsedDatabaseName-$parsedDatabaseHost-$normalizedTier"
      }
    }

    # ---- Classification ----------------------------------------------------
    # A secret is derivable only when ALL of these hold:
    #   * it parsed into a known tier,
    #   * that tier is in the derivable set (default Dev/Exp),
    #   * a username is available (sprint instances are per-developer),
    #   * the name is not explicitly flagged credentialed.
    $isExplicitlyCredentialed = $false
    if ($canonicalName) {
      $isExplicitlyCredentialed = $credentialedLookup.ContainsKey($canonicalName.ToLowerInvariant())
    }

    $tierIsDerivable = $normalizedTier -and ($normalizedTier -in $DerivableTier)
    $hasUser = -not [string]::IsNullOrWhiteSpace($parsedUserName)

    $isDerivable = $tierIsDerivable -and $hasUser -and -not $isExplicitlyCredentialed

    $connectionString = $null
    if ($isDerivable) {
      $connectionString = & $buildDeterministicConnectionString `
        $parsedDatabaseName $parsedDatabaseHost $normalizedTier $parsedUserName
    }

    $classification = if ($isDerivable) { 'derivable' } else { 'credentialed' }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Descriptor for '$canonicalName': classification=$classification tier=$normalizedTier user=$parsedUserName" -Tag 'ConnectionString'

    return [pscustomobject]@{
      SecretName       = $canonicalName
      DatabaseName     = $parsedDatabaseName
      DatabaseHost     = $parsedDatabaseHost
      Environment      = $normalizedTier
      UserName         = $parsedUserName
      Classification   = $classification
      IsDerivable      = [bool]$isDerivable
      ConnectionString = $connectionString
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
