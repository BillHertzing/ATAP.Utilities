function Get-DbConnectionStringSecretDescriptor {
  <#
  .SYNOPSIS
    Single source of truth for SQL connection-string secret names, plus an
    explicit provisioning-only value builder for sprint Dev/Exp secrets.

  .DESCRIPTION
    Database connection strings, including Development and Experimental sprint
    names, are vault-owned BWS secrets. Runtime readers must fetch them through
    Get-SecretATAP / BitwardenSecretsManager and fail loudly if the BWS secret is
    absent.

    This helper centralizes the canonical dbConnectionString-* naming convention.
    It can also build the Integrated-Security value for Dev/Exp names, but only
    when a caller explicitly supplies -DerivableTier. That mode is reserved for
    provisioning/writer flows such as New-SprintBitwardenSecrets, which creates or
    verifies the BWS entries. The default reader-facing classification is
    credentialed/vault-only, so Dev and Exp do not silently fall back to a local
    deterministic string.

    Two modes:

      ByName  - parse a canonical secret name into its parts and classify it.
                Used by diagnostics/tests to understand the name. By default this
                mode does not return a connection string.

      ByParts - build the canonical secret name (and, when derivable, the
                connection string) from explicit parts. Used by the writer to
                create/check the corresponding BWS secret.

    The connection string is ONLY produced when a caller opts into derivation with
    -DerivableTier. For credentialed/default secrets ConnectionString is $null -
    runtime callers MUST read the real value from the vault.

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
    The set of normalized tier tokens whose provisioning value can be generated
    locally. Defaults to empty so all tiers, including Dev and Exp, are BWS-only
    at runtime. New-SprintBitwardenSecrets passes @('Dev','Exp') explicitly while
    creating/checking BWS entries.

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
    # IsDerivable = $false by default; runtime must fetch the value from BWS.

  .EXAMPLE
    Get-DbConnectionStringSecretDescriptor -DatabaseName 'master' -DatabaseHost 'localhost' -Environment 'Exp' -UserName 'jsmith' -DerivableTier @('Dev','Exp')
    # SecretName = dbConnectionString-master-localhost-Exp-jsmith; provisioning value returned for BWS creation.

  .EXAMPLE
    Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-ATAPUtilities-sql01-Production'
    # IsDerivable = $false (permanent tier); ConnectionString = $null - must come from the vault.

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. See
    Research/Bitwarden-Secret-Write-Workaround.md for the historical design
    rationale and the Task 10.7 cleanup that made BWS the normal DB path.
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
    [string[]] $DerivableTier = @(),

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

    # The connection-string FORMAT - defined exactly once for provisioning flows.
    # Sprint instances are named <Tier><UserName> (e.g. Devjsmith) and use Windows
    # Integrated Security, so the seeded BWS value carries no password.
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
    #   * that tier is in the explicit derivable set (default empty),
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
