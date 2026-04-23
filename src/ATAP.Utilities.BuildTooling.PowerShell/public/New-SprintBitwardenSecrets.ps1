function New-SprintBitwardenSecrets {
  <#
  .SYNOPSIS
    Creates per-sprint Bitwarden secure-note items containing SQL Server
    connection strings for the Development and Experimental instances.
  .DESCRIPTION
    For each combination of (database, host, tier), builds a SQL Server
    connection string and stores it as a Bitwarden secure-note item.

    Databases:  ATAPUtilities, AceCommander
    Hosts:      $env:COMPUTERNAME and 'localhost' by default
    Tiers:      Dev, Exp

    This yields 8 secrets per developer per sprint
    (2 databases × 2 hosts × 2 tiers).

    Secret naming convention:
      dbConnectionString-<Database>-<Host>-<Dev|Exp>-<DeveloperUsername>

    Connection string format:
      Server=<Host>\Dev<DeveloperUsername> (or Exp<DeveloperUsername>);Database=<Database>;Integrated Security=True;
      MultipleActiveResultSets=True;TrustServerCertificate=True;

    The BW_SESSION environment variable must be set (by the login script at
    interactive logon). In agent-spawned shells it is read from User scope.

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
    Defaults to @('ATAPUtilities', 'AceCommander').
  .OUTPUTS
    [PSCustomObject[]] — one entry per (database, host, tier) combination with
    fields: secretName, database, host, tier, created, error.
  .EXAMPLE
    $secrets = New-SprintBitwardenSecrets -SprintNumber '0006'
    $secrets | Format-Table secretName, created, error
  .EXAMPLE
    New-SprintBitwardenSecrets -SprintNumber '0006' -DeveloperUsername 'jsmith' `
      -HostList @('devbox01', 'localhost') -WhatIf
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintStage2
  .LINK
    Remove-SprintBitwardenSecrets
  .LINK
    Get-DatabaseCredentialsKey
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
    [string[]]$Databases
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

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
      -Message "Sprint $SprintNumber — creating Bitwarden secrets for $DeveloperUsername; databases: $($Databases -join ', '); hosts: $($HostList -join ', ')"
  }

  process {
    $tiers = @('Dev', 'Exp')
    $results = [System.Collections.ArrayList]::new()

    foreach ($db in $Databases) {
      foreach ($sqlHost in $HostList) {
        foreach ($tier in $tiers) {

          # Canonical secret name per SprintInfrastructure-Naming.md §6
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

          if ($PSCmdlet.ShouldProcess($secretName, 'Create Bitwarden secure note with SQL Server connection string')) {
            try {
              # Idempotency check: skip if the item already exists
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Checking if Bitwarden item already exists: $secretName" -Tag 'BitwardenCLI'
              $listOutput = & bw list items --search $secretName --session $env:BW_SESSION 2>&1
              $existingItems = $null
              if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($listOutput)) {
                try { $existingItems = $listOutput | ConvertFrom-Json -ErrorAction SilentlyContinue } catch { }
              }
              if ($existingItems -and ($existingItems | Where-Object { $_.name -eq $secretName })) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
                  -Message "Bitwarden item already exists, skipping: $secretName"
                $entry.alreadyExists = $true
              } else {
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

                # Encode and create via bw CLI
                # Use .NET Base64 encoding instead of `bw encode` to avoid PowerShell
                # piping a UTF-8 BOM (0xEF BB BF) that would corrupt the base64 payload.
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Calling bw create item for $secretName" -Tag 'BitwardenCLI'

                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($itemJson))

                $createOutput = $encoded | & bw create item --session $env:BW_SESSION 2>&1
                if ($LASTEXITCODE -ne 0) {
                  throw "bw create item failed (exit $LASTEXITCODE): $createOutput"
                }

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                  -Message "Successfully created Bitwarden item: $secretName" -Tag 'BitwardenCLI'

                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "Bitwarden secret created: $secretName"

                $entry.created = $true
              }

            } catch {
              $errMsg = "Failed to create or check Bitwarden item '$secretName'. Exception: $($_.Exception.Message)"
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
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
