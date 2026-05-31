if (-not (Get-Command -Name 'Invoke-BitwardenCliWithCleanTlsEnvironment' -ErrorAction SilentlyContinue)) {
  $bitwardenTlsHelperPath = Join-Path -Path $PSScriptRoot -ChildPath '..\private\Invoke-BitwardenCliWithCleanTlsEnvironment.ps1'
  if (Test-Path -LiteralPath $bitwardenTlsHelperPath -PathType Leaf) {
    . $bitwardenTlsHelperPath
  }
}

function New-PermanentBitwardenSecrets {
  <#
  .SYNOPSIS
    Creates the permanent, per-workstation Bitwarden secure-note items
    containing SQL Server connection strings for the Integration, QA, and
    Production ecosystem tiers.
  .DESCRIPTION
    This is a ONE-TIME-PER-WORKSTATION cmdlet run during developer onboarding.
    It is NOT called by SprintStartAgent. Sprint-scoped secrets (Development
    and Experimental) are handled separately by New-SprintBitwardenSecrets.

    Creates one Bitwarden secure-note item per (database, tier) combination.
    The ecosystem SQL Server instances for Integration, QA, and Production
    reside on DEDICATED SERVER NAMES — not localhost or the developer's
    workstation.

    Default host resolution:
      Integration  →  -IntegrationHost  (default: 'utat022')
      QA           →  -QAHost           (default: 'utat022')
      Production   →  -ProductionHost   (default: 'utat022')

    Secret naming convention (no username suffix for permanent tiers):
      dbConnectionString-<Database>-<Host>-<Tier>

    Connection string format:
      Server=<Host>\<Tier>;Database=<Database>;Integrated Security=True;
      MultipleActiveResultSets=True;Application Name=<Database>-<Tier>;
      TrustServerCertificate=True;

    IDEMPOTENT: if an item with the same name already exists in the vault it
    is skipped (not overwritten). Use -Force to overwrite existing items.

    This yields 6 secrets per workstation
    (2 databases × 3 tiers, all on the ecosystem server):
      dbConnectionString-ATAPUtilities-utat022-Integration
      dbConnectionString-ATAPUtilities-utat022-QA
      dbConnectionString-ATAPUtilities-utat022-Production
      dbConnectionString-AceCommander-utat022-Integration
      dbConnectionString-AceCommander-utat022-QA
      dbConnectionString-AceCommander-utat022-Production

    The BW_SESSION environment variable must be set (by the login script at
    interactive logon). In agent-spawned shells it is read from User scope.
  .PARAMETER IntegrationHost
    Hostname of the dedicated Integration SQL Server instance.
    Defaults to 'utat022'.
  .PARAMETER QAHost
    Hostname of the dedicated QA SQL Server instance.
    Defaults to 'utat022'.
  .PARAMETER ProductionHost
    Hostname of the dedicated Production SQL Server instance.
    Defaults to 'utat022'.
  .PARAMETER Databases
    List of database names to create secrets for.
    Defaults to @('ATAPUtilities', 'AceCommander').
  .PARAMETER Force
    Overwrite an existing Bitwarden item if one with the same name already
    exists. Without -Force, existing items are skipped (idempotent behaviour).
  .OUTPUTS
    [PSCustomObject[]] — one entry per (database, tier) combination with fields:
    secretName, database, tier, host, created, skipped, error.
  .EXAMPLE
    # Dry run — shows what would be created without touching the vault
    New-PermanentBitwardenSecrets -WhatIf

  .EXAMPLE
    # Standard onboarding call — uses default ecosystem host 'utat022'
    $results = New-PermanentBitwardenSecrets
    $results | Format-Table secretName, created, skipped, error

  .EXAMPLE
    # Override all three tier hosts when they differ per tier
    New-PermanentBitwardenSecrets `
      -IntegrationHost 'sql-int-01' `
      -QAHost          'sql-qa-01' `
      -ProductionHost  'sql-prod-01'

  .NOTES
    Run during developer onboarding — not by SprintStartAgent.
    Per-sprint secrets (Development / Experimental) are managed by
    New-SprintBitwardenSecrets / Remove-SprintBitwardenSecrets.
    AI assisted using ./claude/Rules/Powershell.md as guidelines

  .LINK
    New-SprintBitwardenSecrets
  .LINK
    Remove-SprintBitwardenSecrets
  .LINK
    Get-DatabaseCredentialsKey
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$IntegrationHost = 'utat022',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$QAHost = 'utat022',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ProductionHost = 'utat022',

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Snippet: Check and populate simple parameter as Type - Databases
    if (-not $PSBoundParameters.ContainsKey('Databases') -or $null -eq $Databases -or $Databases.Count -eq 0) {
      $Databases = @('ATAPUtilities', 'AceCommander')
    }

    # Read BW_SESSION from User scope if not present in process scope (R-10 pattern)
    $bwSession = $env:BW_SESSION
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      throw 'BW_SESSION is not set in process scope or User-scope environment. Ensure the login script has run and Bitwarden is unlocked.'
    }
    # Ensure process scope is set so bw CLI invocations pick it up
    $env:BW_SESSION = $bwSession

    # Validate bw CLI is available
    if (-not (Get-Command -Name 'bw' -ErrorAction SilentlyContinue)) {
      throw 'Bitwarden CLI (bw) is required but was not found on PATH. Install it or add it to PATH.'
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Creating permanent Bitwarden secrets — Integration: $IntegrationHost, QA: $QAHost, Production: $ProductionHost; databases: $($Databases -join ', ')"
  }

  process {
    # Map each permanent tier to its ecosystem host
    $tierHostMap = [ordered]@{
      Integration = $IntegrationHost
      QA          = $QAHost
      Production  = $ProductionHost
    }

    $results = [System.Collections.ArrayList]::new()

    foreach ($db in $Databases) {
      foreach ($tierEntry in $tierHostMap.GetEnumerator()) {
        $tier = $tierEntry.Key
        $sqlHost = $tierEntry.Value

        # Canonical secret name — no username suffix for permanent tiers
        # (per Get-DatabaseCredentialsKey naming scheme)
        $secretName = "dbConnectionString-${db}-${sqlHost}-${tier}"

        # SQL Server instance name = <host>\<tier>
        $instanceName = $tier

        # Application Name embeds database + tier for traceability
        $appName = "${db}-${tier}"

        # Connection string: Integrated Security, MARS enabled
        $connStr = "Server=${sqlHost}\${instanceName};Database=${db};Integrated Security=True;" +
        "MultipleActiveResultSets=True;Application Name=${appName};TrustServerCertificate=True;"

        $entry = [PSCustomObject]@{
          secretName = $secretName
          database   = $db
          tier       = $tier
          host       = $sqlHost
          created    = $false
          skipped    = $false
          error      = $null
        }

        if ($PSCmdlet.ShouldProcess($secretName, 'Create permanent Bitwarden secure note with SQL Server connection string')) {
          try {
            # Idempotency check: search for existing item with this exact name
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Checking for existing Bitwarden item: $secretName" -Tag 'BitwardenCLI'

            $listOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
              & bw list items --search $secretName --session $env:BW_SESSION 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
              throw "bw list items failed (exit $LASTEXITCODE): $listOutput"
            }

            $existingItems = $listOutput | ConvertFrom-Json -ErrorAction Stop
            $existingMatch = @($existingItems | Where-Object { $_.name -eq $secretName })

            if ($existingMatch.Count -gt 0 -and -not $Force) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Bitwarden item already exists, skipping (use -Force to overwrite): $secretName" -Tag 'BitwardenCLI'
              $entry.skipped = $true
              [void]$results.Add($entry)
              continue
            }

            if ($existingMatch.Count -gt 0 -and $Force) {
              # Delete existing item before re-creating
              $existingId = $existingMatch[0].id
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "-Force specified — deleting existing item $existingId before re-creating $secretName" -Tag 'BitwardenCLI'
              $deleteOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
                & bw delete item $existingId --session $env:BW_SESSION 2>&1
              }
              if ($LASTEXITCODE -ne 0) {
                throw "bw delete item (pre-Force overwrite) failed (exit $LASTEXITCODE): $deleteOutput"
              }
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Creating Bitwarden item: $secretName" -Tag 'BitwardenCLI'

            # Build Bitwarden item JSON (Secure Note, type = 2)
            $bwItem = [ordered]@{
              organizationId = $null
              folderId       = $null
              type           = 2
              name           = $secretName
              notes          = $connStr
              secureNote     = [ordered]@{ type = 0 }
              fields         = @()
              reprompt       = 0
            }

            $itemJson = $bwItem | ConvertTo-Json -Depth 5 -Compress

            $encoded = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
              $itemJson | & bw encode --session $env:BW_SESSION
            }
            if ($LASTEXITCODE -ne 0) {
              throw "bw encode failed (exit $LASTEXITCODE)"
            }

            $createOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
              $encoded | & bw create item --session $env:BW_SESSION 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
              throw "bw create item failed (exit $LASTEXITCODE): $createOutput"
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Permanent Bitwarden secret created: $secretName"
            $entry.created = $true

          } catch {
            $errMsg = "Failed to create Bitwarden item '$secretName'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            $entry.error = $errMsg
          }
        }

        [void]$results.Add($entry)
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "New-PermanentBitwardenSecrets complete — $($results.Where({$_.created}).Count) created, $($results.Where({$_.skipped}).Count) skipped, $($results.Where({$_.error}).Count) errors"

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
