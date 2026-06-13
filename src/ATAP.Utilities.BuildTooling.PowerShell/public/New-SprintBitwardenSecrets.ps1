function New-SprintBitwardenSecrets {
  <#
  .SYNOPSIS
    Creates per-sprint Bitwarden Secrets Manager secrets containing SQL Server
    connection strings for the Development and Experimental instances.
  .DESCRIPTION
    For each combination of (database, host, tier), builds a SQL Server
    connection string and stores it as a Bitwarden Secrets Manager (BWS)
    secret via the `bws` CLI.

    Databases:  master, ATAPUtilities, AceCommander
    Hosts:      $env:COMPUTERNAME and 'localhost' by default
    Tiers:      Dev, Exp

    This yields 12 secrets per developer per sprint
    (3 databases × 2 hosts × 2 tiers).

    Secret naming convention (SprintInfrastructure-Naming.md §4.1):
      dbConnectionString-<Database>-<Host>-<Dev|Exp>-<DeveloperUsername>

    Connection string format:
      Server=<Host>\Dev<DeveloperUsername> (or Exp<DeveloperUsername>);Database=<Database>;Integrated Security=True;
      MultipleActiveResultSets=True;TrustServerCertificate=True;

    Authentication (SC-0175): the cmdlet uses the bws CLI with a machine
    access token. The token is resolved from process-scope
    $env:BWS_ACCESS_TOKEN first, then the DPAPI access-token file for the
    running account (Get-BWSAccessToken). There is no bw login, no unlock,
    and no BW_SESSION — sprint automation must never depend on the personal
    Password Manager session.

    Reads of these secrets go through:
      Get-SecretATAP -SecretName <name> -SecretStoreType 'BitwardenSecretsManager'

    Permanent tier secrets (Production, QA, Integration) are NOT created by
    this cmdlet — see New-PermanentBitwardenSecrets for that one-time setup.
  .PARAMETER SprintNumber
    The zero-padded 4-digit sprint number (e.g. '0006').
  .PARAMETER DeveloperUsername
    The developer's Windows username appended to the secret name.
    Defaults to $env:USERNAME.
  .PARAMETER HostList
    List of SQL Server host names to create secrets for.
    Defaults to @($env:COMPUTERNAME, 'localhost').
  .PARAMETER Databases
    List of database names to create secrets for.
    Defaults to @('master', 'ATAPUtilities', 'AceCommander').
  .PARAMETER ProjectName
    Bitwarden Secrets Manager project that owns the per-sprint secrets.
    Defaults to 'CI-Shared'. Ignored when -ProjectId is supplied.
  .PARAMETER ProjectId
    Explicit BWS project id (GUID). Skips the `bws project list` lookup.
  .OUTPUTS
    [PSCustomObject[]] — one entry per (database, host, tier) combination with
    fields: secretName, database, host, tier, created, alreadyExists, error.
  .EXAMPLE
    $secrets = New-SprintBitwardenSecrets -SprintNumber '0006'
    $secrets | Format-Table secretName, created, error
  .EXAMPLE
    New-SprintBitwardenSecrets -SprintNumber '0006' -DeveloperUsername 'jsmith' `
      -HostList @('utat022', 'localhost') -WhatIf
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintStage2
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
    # sibling public function. Kept inside BEGIN so loading/dot-sourcing this
    # file only DEFINES the function and never executes anything at load time.
    if (-not (Get-Command -Name 'Get-BWSAccessToken' -ErrorAction SilentlyContinue)) {
      $tokenReaderPath = Join-Path -Path $PSScriptRoot -ChildPath 'Get-BWSAccessToken.ps1'
      if (Test-Path -LiteralPath $tokenReaderPath -PathType Leaf) {
        . $tokenReaderPath
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

    # Validate bws CLI is available
    if (-not (Get-Command -Name 'bws' -ErrorAction SilentlyContinue)) {
      throw 'Bitwarden Secrets Manager CLI (bws) is required but was not found on PATH. Install it (NewComputerSetup.md §9.4.10.1) or add it to PATH.'
    }

    # Resolve the BWS access token: process scope first, then the DPAPI file
    # for the running account (NewComputerSetup.md §9.4.10). Never BW_SESSION.
    $bwsTokenWasSetHere = $false
    if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
      $cred = Get-BWSAccessToken -ErrorAction Stop
      $env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
      $bwsTokenWasSetHere = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BWS access token resolved from DPAPI file' -Tag 'bws-token'
    }
    if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
      throw 'No BWS access token in $env:BWS_ACCESS_TOKEN or the DPAPI token file. Provision it with Initialize-BWSAccessToken (NewComputerSetup.md §9.4.10).'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Sprint $SprintNumber — creating BWS secrets for $DeveloperUsername; databases: $($Databases -join ', '); hosts: $($HostList -join ', ')"
  }

  process {
    $tiers = @('Dev', 'Exp')
    $results = [System.Collections.ArrayList]::new()

    try {
      # Resolve the target project id once (unless supplied explicitly)
      if ([string]::IsNullOrWhiteSpace($ProjectId)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws project list' -Tag 'BWSCall'
        $projectOutput = & bws project list --output json 2>&1
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

      # List existing secrets once for the idempotency check
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws secret list' -Tag 'BWSCall'
      $listOutput = & bws secret list --output json 2>&1
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

          # Canonical secret name per SprintInfrastructure-Naming.md §4.1
          $secretName = "dbConnectionString-${db}-${sqlHost}-${tier}-${DeveloperUsername}"

          # SQL instance name: 3-char prefix (Dev/Exp) + developer username
          $instanceName = "${tier}${DeveloperUsername}"

          # Connection string: Integrated Security, MARS enabled (6.1-2)
          $connStr = "Server=${sqlHost}\${instanceName};Database=${db};Integrated Security=True;" +
          'MultipleActiveResultSets=True;TrustServerCertificate=True;'

          $entry = [PSCustomObject]@{
            secretName    = $secretName
            database      = $db
            host          = $sqlHost
            tier          = $tier
            created       = $false
            alreadyExists = $false
            error         = $null
          }

          if ($PSCmdlet.ShouldProcess($secretName, 'Create Bitwarden Secrets Manager secret with SQL Server connection string')) {
            try {
              if ($existingKeys -contains $secretName.ToLowerInvariant()) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                  -Message "BWS secret already exists, skipping: $secretName"
                $entry.alreadyExists = $true
              } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Calling bws secret create for $secretName" -Tag 'BWSCall'

                $note = "Sprint $SprintNumber connection string ($tier) created by New-SprintBitwardenSecrets"
                $createOutput = & bws secret create $secretName $connStr $ProjectId --note $note --output json 2>&1
                if ($LASTEXITCODE -ne 0) {
                  throw "bws secret create failed (exit $LASTEXITCODE): $createOutput"
                }

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "BWS secret created: $secretName"

                $entry.created = $true
              }

            } catch {
              $errMsg = "Failed to create or check BWS secret '$secretName'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
              $entry.error = $errMsg
            }
          }

          [void]$results.Add($entry)
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "New-SprintBitwardenSecrets complete — $($results.Where({$_.created}).Count) created, $($results.Where({$_.alreadyExists}).Count) skipped (already existed), $($results.Where({$_.error}).Count) errors"

    return $results.ToArray()
  }

  end {
    if ($bwsTokenWasSetHere) {
      Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
