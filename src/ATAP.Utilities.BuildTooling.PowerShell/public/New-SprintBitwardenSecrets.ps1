function New-SprintBitwardenSecrets {
  <#
  .SYNOPSIS
    Creates or verifies the per-sprint SQL Server connection-string secrets for
    the Development and Experimental instances in Bitwarden Secrets Manager.
  .DESCRIPTION
    For each combination of (database, host, tier), this cmdlet produces a
    descriptor for the canonical connection-string secret via
    Get-DbConnectionStringSecretDescriptor (the single source of truth for the
    connection-string name and provisioning value format).

    Databases:  master, ATAPUtilities, AceCommander
    Hosts:      $env:COMPUTERNAME and 'localhost' by default
    Tiers:      Dev, Exp

    This yields 12 secrets per developer per sprint
    (3 databases x 2 hosts x 2 tiers).

    Secret naming convention (SprintInfrastructure-Naming.md 4.1):
      dbConnectionString-<Database>-<Host>-<Dev|Exp>-<DeveloperUsername>

    Connection string format (owned by Get-DbConnectionStringSecretDescriptor):
      Server=<Host>\Dev<DeveloperUsername> (or Exp<DeveloperUsername>);Database=<Database>;Integrated Security=True;
      MultipleActiveResultSets=True;TrustServerCertificate=True;

    Task 10.7 cleanup: Dev/Exp connection strings are now normal BWS secrets.
    The cmdlet uses the bws CLI with a machine/user access token resolved from
    $env:BWS_ACCESS_TOKEN first, then the DPAPI access-token file for the running
    Windows account (Get-BWSAccessToken) - never bw / BW_SESSION.

    The Integrated-Security string can still be generated here because this is a
    provisioning flow that writes the value into Bitwarden Secrets Manager. Runtime
    readers do not derive; they fetch the dbConnectionString-* value through
    Get-SecretATAP / BitwardenSecretsManager and fail if the BWS secret is absent.

    Reads of these secrets go through:
      Get-SecretATAP -SecretName <name> -SecretStoreType 'BitwardenSecretsManager'
    or, for an actual SqlConnection, Resolve-DatabaseSqlConnection, which fails
    when BWS cannot return the secret value.

    Permanent tier secrets (Production, QA, Integration) are NOT handled by this
    cmdlet.
  .PARAMETER SprintNumber
    The zero-padded 4-digit sprint number (e.g. '0006'). Recorded in the vault note
    when a secret is created.
  .PARAMETER DeveloperUsername
    The developer's Windows username appended to the secret name.
    Defaults to $env:USERNAME.
  .PARAMETER HostList
    List of SQL Server host names to create secrets for.
    Defaults to @($env:COMPUTERNAME, 'localhost').
  .PARAMETER Databases
    List of database names to create secrets for.
    Defaults to @('master', 'ATAPUtilities', 'AceCommander').
  .PARAMETER WriteDerivableToVault
    Compatibility switch retained for existing callers. Vault persistence is now
    the default and this switch no longer changes behavior.
  .PARAMETER ProjectName
    Bitwarden Secrets Manager project that owns the per-sprint secrets.
    Defaults to 'CI-Shared'. Ignored when -ProjectId is supplied.
  .PARAMETER ProjectId
    Explicit BWS project id (GUID). Skips the `bws project list` lookup.
  .OUTPUTS
    [PSCustomObject[]] - one entry per (database, host, tier) combination with
    fields: secretName, database, host, tier, classification, derived, created,
    alreadyExists, error.
  .EXAMPLE
    $secrets = New-SprintBitwardenSecrets -SprintNumber '0006'
    $secrets | Format-Table secretName, classification, derived, created, error
    # Default: missing Dev/Exp BWS secrets are created; existing keys are skipped.
  .EXAMPLE
    New-SprintBitwardenSecrets -SprintNumber '0006' -WriteDerivableToVault
    # Compatibility spelling; same behavior as the default.
  .EXAMPLE
    New-SprintBitwardenSecrets -SprintNumber '0006' -DeveloperUsername 'jsmith' `
      -HostList @('utat022', 'localhost') -WhatIf
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintStage2
  .LINK
    Get-DbConnectionStringSecretDescriptor
  .LINK
    Remove-SprintBitwardenSecrets
  .LINK
    Get-DatabaseCredentialsKey
  .LINK
    https://bitwarden.com/help/secrets-manager-cli/
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [string]$DeveloperUsername,

    [Parameter(Mandatory = $false)]
    [string[]]$HostList,

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [switch]$WriteDerivableToVault,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ProjectName = 'CI-Shared',

    [Parameter(Mandatory = $false)]
    [string]$ProjectId
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Load helper functions. Fallback for running this file from source without
    # importing the module; a normal Import-Module already dot-sources the
    # sibling public functions. Kept inside BEGIN so loading/dot-sourcing this
    # file only DEFINES the function and never executes anything at load time.
    foreach ($siblingHelper in @('Get-BWSAccessToken', 'Get-DbConnectionStringSecretDescriptor')) {
      if (-not (Get-Command -Name $siblingHelper -ErrorAction SilentlyContinue)) {
        $helperPath = Join-Path -Path $PSScriptRoot -ChildPath "$siblingHelper.ps1"
        if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
          . $helperPath
        }
      }
    }

    # Snippet: Check and populate simple parameter - DeveloperUsername
    if ([string]::IsNullOrWhiteSpace($DeveloperUsername)) {
      $DeveloperUsername = $env:USERNAME
    }
    if ([string]::IsNullOrWhiteSpace($DeveloperUsername)) {
      throw 'DeveloperUsername could not be determined: $env:USERNAME is empty.'
    }

    # Snippet: Check and populate simple parameter as Type - HostList
    if (-not $PSBoundParameters.ContainsKey('HostList') -or $null -eq $HostList -or $HostList.Count -eq 0) {
      $HostList = @($env:COMPUTERNAME, 'localhost')
    }

    # Snippet: Check and populate simple parameter as Type - Databases
    if (-not $PSBoundParameters.ContainsKey('Databases') -or $null -eq $Databases -or $Databases.Count -eq 0) {
      $Databases = @('master', 'ATAPUtilities', 'AceCommander')
    }

    # The bws CLI and an access token are required because Dev/Exp DB connection
    # strings are BWS secrets, not reader-side deterministic fallbacks.
    $bwsTokenWasSetHere = $false
    if (-not (Get-Command -Name 'bws' -ErrorAction SilentlyContinue)) {
      throw 'Bitwarden Secrets Manager CLI (bws) is required to create or verify Dev/Exp DB connection-string secrets but was not found on PATH. Install it (NewComputerSetup.md 9.4.10.1) or add it to PATH.'
    }

    if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
      $cred = Get-BWSAccessToken -ErrorAction Stop
      $env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
      $bwsTokenWasSetHere = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BWS access token resolved from DPAPI file' -Tag 'bws-token'
    }
    if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
      throw 'No BWS access token in $env:BWS_ACCESS_TOKEN or the DPAPI token file. Provision it with Initialize-BWSAccessToken (NewComputerSetup.md 9.4.10).'
    }

    if ($WriteDerivableToVault) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message '-WriteDerivableToVault was supplied; persistence is now the default, so the switch is treated as compatibility-only.'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Sprint $SprintNumber - creating/verifying sprint connection-string secrets for $DeveloperUsername; databases: $($Databases -join ', '); hosts: $($HostList -join ', '); project=$ProjectName"
  }

  process {
    $tiers = @('Dev', 'Exp')
    $results = [System.Collections.ArrayList]::new()

    # Resolve the project once and list existing secrets for the idempotency check.
    $existingKeys = @()
    try {
      if ([string]::IsNullOrWhiteSpace($ProjectId)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws project list' -Tag 'BWSCall'
        $projectOutput = & bws project list --output json --color no 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "bws project list failed (exit $LASTEXITCODE): $projectOutput"
        }
        $projects = $projectOutput | ConvertFrom-Json -ErrorAction Stop
        $projectMatch = @($projects | Where-Object { $_.name -and ($_.name.ToLowerInvariant() -eq $ProjectName.ToLowerInvariant()) })
        if ($projectMatch.Count -eq 0) {
          throw "No Bitwarden Secrets Manager project named '$ProjectName' is visible to this access token."
        }
        $ProjectId = [string]$projectMatch[0].id
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved BWS project '$ProjectName' to id $ProjectId"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws secret list' -Tag 'BWSCall'
      $listOutput = & bws secret list --output json --color no 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "bws secret list failed (exit $LASTEXITCODE): $listOutput"
      }
      $existingSecrets = @()
      if (-not [string]::IsNullOrWhiteSpace([string]$listOutput)) {
        $existingSecrets = @($listOutput | ConvertFrom-Json -ErrorAction Stop)
      }
      $existingKeys = @($existingSecrets | ForEach-Object { ([string]$_.key).ToLowerInvariant() })
    } catch {
      $errMsg = "Failed to prepare BWS context (project/secret list). Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
      throw
    }

    foreach ($db in $Databases) {
      foreach ($sqlHost in $HostList) {
        foreach ($tier in $tiers) {

          # Single source of truth for the canonical name, the format, and the
          # derivable-vs-credentialed classification.
          $descriptor = Get-DbConnectionStringSecretDescriptor `
            -DatabaseName $db -DatabaseHost $sqlHost -Environment $tier -UserName $DeveloperUsername -DerivableTier @('Dev', 'Exp')

          $entry = [PSCustomObject]@{
            secretName     = $descriptor.SecretName
            database       = $db
            host           = $sqlHost
            tier           = $tier
            classification = $descriptor.Classification
            derived        = $false
            created        = $false
            alreadyExists  = $false
            error          = $null
          }

          if (-not $descriptor.IsDerivable) {
            # The writer only knows how to seed Dev/Exp Integrated-Security values.
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Secret '$($descriptor.SecretName)' cannot be seeded by this cmdlet; provision it in Bitwarden Secrets Manager."
            $entry.error = "Secret '$($descriptor.SecretName)' cannot be seeded by New-SprintBitwardenSecrets."
            [void]$results.Add($entry)
            continue
          }

          if ($PSCmdlet.ShouldProcess($descriptor.SecretName, 'Create Bitwarden Secrets Manager secret with SQL Server connection string')) {
            try {
              if ($existingKeys -contains $descriptor.SecretName.ToLowerInvariant()) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                  -Message "BWS secret already exists, skipping: $($descriptor.SecretName)"
                $entry.alreadyExists = $true
              } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Calling bws secret create for $($descriptor.SecretName)" -Tag 'BWSCall'

                $note = "Sprint $SprintNumber connection string ($tier) created by New-SprintBitwardenSecrets"
                $createOutput = & bws secret create $descriptor.SecretName $descriptor.ConnectionString $ProjectId --note $note --output json 2>&1
                if ($LASTEXITCODE -ne 0) {
                  throw "bws secret create failed (exit $LASTEXITCODE): $createOutput"
                }

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "BWS secret created: $($descriptor.SecretName)"

                $entry.created = $true
              }
            } catch {
              $errMsg = "Failed to create or check BWS secret '$($descriptor.SecretName)'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
              $entry.error = $errMsg
            }
          }

          [void]$results.Add($entry)
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "New-SprintBitwardenSecrets complete - $($results.Where({$_.created}).Count) created, $($results.Where({$_.alreadyExists}).Count) skipped (already existed), $($results.Where({$_.error}).Count) errors"

    return $results.ToArray()
  }

  end {
    if ($bwsTokenWasSetHere) {
      Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
