function Remove-SprintBitwardenSecrets {
  <#
  .SYNOPSIS
    Deletes per-sprint Bitwarden secure-note items for the Development and
    Experimental connection strings created by New-SprintBitwardenSecrets.
  .DESCRIPTION
    Mirrors the (database, host, tier) cross-product of New-SprintBitwardenSecrets
    and deletes each matching Bitwarden item by name.

    Databases:  master, ATAPUtilities, AceCommander  (or -Databases override)
    Hosts:      $env:COMPUTERNAME and 'localhost'  (or -HostList override)
    Tiers:      Dev, Exp

    Secret naming convention (must match what New-SprintBitwardenSecrets created):
      dbConnectionString-<Database>-<Host>-<Dev|Exp>-<DeveloperUsername>

    To locate each item, the cmdlet calls:
      bw list items --search <secretName> --session $env:BW_SESSION
    then filters the returned JSON array for an exact name match before calling:
      bw delete item <uuid> --session $env:BW_SESSION

    If a named item is not found in the vault, that entry is skipped with a
    warning (it may have already been deleted). All other items continue.

    ConfirmImpact is set to High. PowerShell will prompt for confirmation
    before any deletion unless -Confirm:$false or -Force is passed. -Force
    suppresses both the single safety prompt and PowerShell's high-impact
    ShouldProcess confirmation, but it does not override -WhatIf. Deletion is
    reversible only by re-running New-SprintBitwardenSecrets.

    The BW_SESSION environment variable must be set (by the login script at
    interactive logon). In agent-spawned shells it is read from User scope.

    Permanent tier secrets (Production, QA, Integration) are NOT deleted by
    this cmdlet — see New-PermanentBitwardenSecrets for one-time setup.
  .PARAMETER DeveloperUsername
    The developer's Windows username used as the suffix in the secret name.
    Defaults to $env:USERNAME.
  .PARAMETER HostList
    List of SQL Server host names whose secrets should be deleted.
    Defaults to @($env:COMPUTERNAME, 'localhost').
  .PARAMETER Databases
    List of database names whose secrets should be deleted.
    Defaults to @('master', 'ATAPUtilities', 'AceCommander').
  .PARAMETER Force
    Bypasses the high-impact confirmation prompts. Use for pipeline / agent
    invocations. Does not override -WhatIf.
  .OUTPUTS
    [PSCustomObject[]] — one entry per (database, host, tier) with fields:
    secretName, database, host, tier, deleted, skipped, error.
  .EXAMPLE
    $results = Remove-SprintBitwardenSecrets
    $results | Format-Table secretName, deleted, skipped, error
  .EXAMPLE
    Remove-SprintBitwardenSecrets -DeveloperUsername 'jsmith' -WhatIf
  .EXAMPLE
    Remove-SprintBitwardenSecrets -Force
  .NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
  .LINK
    New-SprintBitwardenSecrets
  .LINK
    Get-DatabaseCredentialsKey
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory = $false)]
    [string]$DeveloperUsername,

    [Parameter(Mandatory = $false)]
    [string[]]$HostList,

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Load helper functions. Fallback for running this file from source without
    # importing the module; a normal Import-Module already dot-sources the private
    # helper. Kept inside BEGIN so loading/dot-sourcing this file only DEFINES the
    # function and never executes anything at load time.
    if (-not (Get-Command -Name 'Invoke-BitwardenCliWithCleanTlsEnvironment' -ErrorAction SilentlyContinue)) {
      $bitwardenTlsHelperPath = Join-Path -Path $PSScriptRoot -ChildPath '..\private\Invoke-BitwardenCliWithCleanTlsEnvironment.ps1'
      if (Test-Path -LiteralPath $bitwardenTlsHelperPath -PathType Leaf) {
        . $bitwardenTlsHelperPath
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
      -Message "Removing Bitwarden sprint secrets for $DeveloperUsername; databases: $($Databases -join ', '); hosts: $($HostList -join ', ')"

    if ($Force) {
      $ConfirmPreference = 'None'
    }
  }

  process {
    # High-impact gate: warn the user once before any items are deleted.
    # -Force or -Confirm:$false suppresses this prompt for pipeline use.
    # NOTE: ShouldContinue ignores -Confirm:$false; we must check the bound parameter explicitly.
    $confirmExplicitlyFalse = $PSBoundParameters.ContainsKey('Confirm') -and ($PSBoundParameters['Confirm'] -eq $false)
    if (-not $Force -and -not $confirmExplicitlyFalse -and -not $PSCmdlet.ShouldContinue(
        "This will permanently delete Bitwarden secure-note items for the Dev and Exp connection strings for user '$DeveloperUsername'. " +
        'Deletion is reversible only by re-running New-SprintBitwardenSecrets. Continue?',
        'Confirm Bitwarden Secret Deletion')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Deletion cancelled by user.'
      return @()
    }

    $tiers = @('Dev', 'Exp')
    $results = [System.Collections.ArrayList]::new()

    foreach ($db in $Databases) {
      foreach ($sqlHost in $HostList) {
        foreach ($tier in $tiers) {

          # Canonical secret name — must match New-SprintBitwardenSecrets exactly
          $secretName = "dbConnectionString-${db}-${sqlHost}-${tier}-${DeveloperUsername}"

          $entry = [PSCustomObject]@{
            secretName = $secretName
            database   = $db
            host       = $sqlHost
            tier       = $tier
            deleted    = $false
            skipped    = $false
            error      = $null
          }

          if ($PSCmdlet.ShouldProcess($secretName, 'Delete Bitwarden secure note')) {
            try {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Searching Bitwarden for item: $secretName" -Tag 'BitwardenCLI'

              # bw list returns an array; --search does substring match so we filter for exact name
              $listOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
                & bw list items --search $secretName --session $env:BW_SESSION 2>&1
              }
              if ($LASTEXITCODE -ne 0) {
                throw "bw list items failed (exit $LASTEXITCODE): $listOutput"
              }

              $items = $listOutput | ConvertFrom-Json -ErrorAction Stop
              $match = @($items | Where-Object { $_.name -eq $secretName })

              if ($match.Count -eq 0) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "Bitwarden item not found (already deleted?): $secretName" -Tag 'BitwardenCLI'
                $entry.skipped = $true
                [void]$results.Add($entry)
                continue
              }

              $itemId = $match[0].id
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Deleting Bitwarden item $itemId ($secretName)" -Tag 'BitwardenCLI'

              $deleteOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
                & bw delete item $itemId --session $env:BW_SESSION 2>&1
              }
              if ($LASTEXITCODE -ne 0) {
                throw "bw delete item failed (exit $LASTEXITCODE): $deleteOutput"
              }

              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "Bitwarden secret deleted: $secretName"
              $entry.deleted = $true

            } catch {
              $errMsg = "Failed to delete Bitwarden item '$secretName'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
              $entry.error = $errMsg
            }
          }

          [void]$results.Add($entry)
        }
      }
    }

    # Sync vault so all clients see the deletions immediately
    if ($results.Where({ $_.deleted }).Count -gt 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Running bw sync to propagate deletions.' -Tag 'BitwardenCLI'
      $syncOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
        & bw sync --session $env:BW_SESSION 2>&1
      }
      if ($LASTEXITCODE -ne 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "bw sync failed (exit $LASTEXITCODE): $syncOutput" -Tag 'BitwardenCLI'
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'bw sync completed successfully.' -Tag 'BitwardenCLI'
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Remove-SprintBitwardenSecrets complete — $($results.Where({$_.deleted}).Count) deleted, $($results.Where({$_.skipped}).Count) skipped, $($results.Where({$_.error}).Count) errors"

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
