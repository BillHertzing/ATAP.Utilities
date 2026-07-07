function Remove-SprintBitwardenSecrets {
  <#
  .SYNOPSIS
    Deletes per-sprint Bitwarden Secrets Manager secrets for the Development and
    Experimental connection strings created by New-SprintBitwardenSecrets.
  .DESCRIPTION
    Mirrors the (database, host, tier) cross-product of New-SprintBitwardenSecrets
    and deletes each matching Bitwarden Secrets Manager (BWS) secret by key.

    Databases:  master, ATAPUtilities, AceCommander  (or -Databases override)
    Hosts:      $env:COMPUTERNAME and 'localhost'  (or -HostList override)
    Tiers:      Dev, Exp

    Secret naming convention (must match what New-SprintBitwardenSecrets created):
      dbConnectionString.<Database>.<Host>.<Dev|Exp>.<DeveloperUsername>

    To locate each secret, the cmdlet calls `bws secret list --output json`
    once, then filters the returned array for an exact key match
    (case-insensitive) before calling `bws secret delete <id>`.

    If a named secret is not found, that entry is skipped with a warning (it
    may have already been deleted). All other entries continue.

    ConfirmImpact is set to High. PowerShell will prompt for confirmation
    before any deletion unless -Confirm:$false or -Force is passed. -Force
    suppresses both the single safety prompt and PowerShell's high-impact
    ShouldProcess confirmation, but it does not override -WhatIf. Deletion is
    reversible only by re-running New-SprintBitwardenSecrets.

    Authentication (SC-0175): the cmdlet uses the bws CLI with a machine
    access token resolved from process-scope $env:BWS_ACCESS_TOKEN first,
    then the DPAPI access-token file for the running account
    (Get-BWSAccessToken). No bw login, no unlock, no BW_SESSION - sprint
    automation must never depend on the personal Password Manager session.

    Task 9.22 (bws-write workaround). Under the current scheme New-SprintBitwardenSecrets
    DERIVES the sprint connection strings at read time and does NOT write them to
    the vault, so there is usually nothing for this cmdlet to delete. When the bws
    CLI or a machine access token is unavailable, the cmdlet NO-OPS gracefully -
    it logs Important and returns each entry marked skipped, rather than throwing -
    so sprint end never fails on an absent vault. When bws IS available it deletes
    any matching secrets it finds (the -WriteDerivableToVault state).

    Permanent tier secrets (Production, QA, Integration) are NOT deleted by
    this cmdlet - see New-PermanentBitwardenSecrets for one-time setup.
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
    [PSCustomObject[]] - one entry per (database, host, tier) with fields:
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
  .LINK
    https://bitwarden.com/help/secrets-manager-cli/
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
    # importing the module; a normal Import-Module already dot-sources the
    # sibling public function. Kept inside BEGIN so loading/dot-sourcing this
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

    # Detect whether bws is usable. Task 9.22: do NOT throw when the CLI or token
    # is unavailable - the sprint connection strings are derived (not stored), so
    # there is nothing to delete and sprint end must not fail. No-op gracefully.
    $bwsTokenWasSetHere = $false
    $bwsAvailable = $true
    $bwsUnavailableReason = $null

    if (-not (Get-Command -Name 'bws' -ErrorAction SilentlyContinue)) {
      $bwsAvailable = $false
      $bwsUnavailableReason = 'the bws CLI was not found on PATH'
    } else {
      # Resolve the BWS access token: process scope first, then the DPAPI file
      # for the running account (NewComputerSetup.md 9.4.10). Never BW_SESSION.
      if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
        try {
          $cred = Get-BWSAccessToken -ErrorAction Stop
          $env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
          $bwsTokenWasSetHere = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BWS access token resolved from DPAPI file' -Tag 'bws-token'
        } catch {
          $bwsAvailable = $false
          $bwsUnavailableReason = "the BWS machine access token could not be resolved ($($_.Exception.Message))"
        }
      }
      if ($bwsAvailable -and [string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
        $bwsAvailable = $false
        $bwsUnavailableReason = 'no BWS access token in $env:BWS_ACCESS_TOKEN or the DPAPI token file'
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Removing BWS sprint secrets for $DeveloperUsername; databases: $($Databases -join ', '); hosts: $($HostList -join ', '); bwsAvailable=$bwsAvailable"

    if ($Force) {
      $ConfirmPreference = 'None'
    }
  }

  process {
    $tiers = @('Dev', 'Exp')
    $results = [System.Collections.ArrayList]::new()

    # Emit one skipped (no-op) entry per (database, host, tier) combination.
    $addNoOpEntries = {
      foreach ($db in $Databases) {
        foreach ($sqlHost in $HostList) {
          foreach ($tier in $tiers) {
            $descriptor = Get-DbConnectionStringSecretDescriptor `
              -DatabaseName $db -DatabaseHost $sqlHost -Environment $tier -UserName $DeveloperUsername
            [void]$results.Add([PSCustomObject]@{
                secretName = $descriptor.SecretName
                database   = $db
                host       = $sqlHost
                tier       = $tier
                deleted    = $false
                skipped    = $true
                error      = $null
              })
          }
        }
      }
    }

    # Task 9.22 no-op: when bws is unavailable, nothing was stored, so there is
    # nothing to delete. Log Important and return skipped entries - never throw.
    if (-not $bwsAvailable) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Bitwarden Secrets Manager is unavailable ($bwsUnavailableReason). Sprint connection strings are derived (not stored), so there is nothing to delete - no-op."
      & $addNoOpEntries
      return $results.ToArray()
    }

    # List secrets once; each delete then resolves its id from this snapshot.
    # If the list fails, degrade to a no-op rather than failing sprint end.
    $existingSecrets = @()
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bws secret list' -Tag 'BWSCall'
      $listOutput = & bws secret list --output json --color no 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "bws secret list failed (exit $LASTEXITCODE): $listOutput"
      }
      if (-not [string]::IsNullOrWhiteSpace([string]$listOutput)) {
        $existingSecrets = @($listOutput | ConvertFrom-Json -ErrorAction Stop)
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Failed to list BWS secrets ($($_.Exception.Message)) - treating as nothing to delete (no-op)."
      & $addNoOpEntries
      return $results.ToArray()
    }

    # High-impact gate: warn the user once before any secrets are deleted.
    # -Force or -Confirm:$false suppresses this prompt for pipeline use.
    # NOTE: ShouldContinue ignores -Confirm:$false; we must check the bound parameter explicitly.
    $confirmExplicitlyFalse = $PSBoundParameters.ContainsKey('Confirm') -and ($PSBoundParameters['Confirm'] -eq $false)
    if (-not $Force -and -not $confirmExplicitlyFalse -and -not $PSCmdlet.ShouldContinue(
        "This will permanently delete Bitwarden Secrets Manager secrets for the Dev and Exp connection strings for user '$DeveloperUsername'. " +
        'Deletion is reversible only by re-running New-SprintBitwardenSecrets. Continue?',
        'Confirm Bitwarden Secret Deletion')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message 'Deletion cancelled by user.'
      return @()
    }

    foreach ($db in $Databases) {
      foreach ($sqlHost in $HostList) {
        foreach ($tier in $tiers) {

          # Canonical secret name - must match New-SprintBitwardenSecrets exactly
          $secretName = "dbConnectionString.${db}.${sqlHost}.${tier}.${DeveloperUsername}"

          $entry = [PSCustomObject]@{
            secretName = $secretName
            database   = $db
            host       = $sqlHost
            tier       = $tier
            deleted    = $false
            skipped    = $false
            error      = $null
          }

          if ($PSCmdlet.ShouldProcess($secretName, 'Delete Bitwarden Secrets Manager secret')) {
            try {
              $match = @($existingSecrets | Where-Object { $_.key -and (([string]$_.key).ToLowerInvariant() -eq $secretName.ToLowerInvariant()) })

              if ($match.Count -eq 0) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                  -Message "BWS secret not found (already deleted?): $secretName" -Tag 'BWSCall'
                $entry.skipped = $true
                [void]$results.Add($entry)
                continue
              }

              $secretId = [string]$match[0].id
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "Calling bws secret delete for $secretId ($secretName)" -Tag 'BWSCall'

              $deleteOutput = & bws secret delete $secretId 2>&1
              if ($LASTEXITCODE -ne 0) {
                throw "bws secret delete failed (exit $LASTEXITCODE): $deleteOutput"
              }

              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                -Message "BWS secret deleted: $secretName"
              $entry.deleted = $true

            } catch {
              $errMsg = "Failed to delete BWS secret '$secretName'. Exception: $($_.Exception.Message)"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
              $entry.error = $errMsg
            }
          }

          [void]$results.Add($entry)
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Remove-SprintBitwardenSecrets complete - $($results.Where({$_.deleted}).Count) deleted, $($results.Where({$_.skipped}).Count) skipped, $($results.Where({$_.error}).Count) errors"

    return $results.ToArray()
  }

  end {
    if ($bwsTokenWasSetHere) {
      Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
