<#
.SYNOPSIS
Retrieves a single field from a Bitwarden vault item using the Bitwarden CLI directly.

.DESCRIPTION
Get-SecretATAPBitwarden is the Bitwarden provider implementation behind
Get-SecretATAP. It does NOT use Microsoft.PowerShell.SecretManagement or any
Bitwarden vault extension; it shells out to the Bitwarden CLI (`bw`) and parses
the resulting JSON.

Session handling:
1. Reads BW_SESSION from process scope. If empty, reads from User scope
   (the LoginScript / Initialize-ServiceAccountBitwardenSession destination).
2. Calls `bw status --session <token>` to verify the vault is unlocked.
   Locked or expired sessions fail fast with a structured error pointing to
   the refresh task.
3. Calls `bw get item <SecretName> --session <token>` and parses JSON.

Field extraction (case-insensitive):
  - 'password' (default):
      * Login items   -> login.password
      * Secure Notes  -> notes
  - 'username'         -> login.username
  - 'notes'            -> notes
  - other / custom     -> fields[] entry whose name matches SecretField, .value

The function never logs secret values. Only the secret name and chosen field
are logged.

.PARAMETER SecretName
The Bitwarden item name. Hyphens, dots, and arbitrary username segments are
passed through unchanged. Required. Also accepts
`-BuildMasterAdminApiKeySecretName` as an alias for BuildMaster helper calls.

.PARAMETER SecretField
The named field inside the Bitwarden item to return. Defaults to 'password'.

.OUTPUTS
[string]
The plain-text value of the requested field.

.EXAMPLE
Get-SecretATAPBitwarden -SecretName 'PROGET_ADMIN_API_KEY'
Returns the password field from a Login-type item as plain text.

.EXAMPLE
Get-SecretATAPBitwarden -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-whertzing' -SecretField 'notes'
Returns the connection string stored in a Secure Note's notes body.

.EXAMPLE
Get-SecretATAPBitwarden -SecretName 'utat022-SvcBuildmaster-Production' -SecretField 'username'
Returns the Windows account name stored in the Login item's username field.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Renamed from Get-BitwardenSecret and rewritten to use bw CLI directly (no SecretManagement).

.LINK
https://bitwarden.com/help/cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
if (-not (Get-Command -Name 'Invoke-BitwardenCliWithCleanTlsEnvironment' -ErrorAction SilentlyContinue)) {
  $bitwardenTlsHelperPath = Join-Path -Path $PSScriptRoot -ChildPath '..\private\Invoke-BitwardenCliWithCleanTlsEnvironment.ps1'
  if (Test-Path -LiteralPath $bitwardenTlsHelperPath -PathType Leaf) {
    . $bitwardenTlsHelperPath
  }
}

function Get-SecretATAPBitwarden {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [Alias('BuildMasterAdminApiKeySecretName')]
    [string]$SecretName,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$SecretField = 'password'
  )

  BEGIN {
    $fn = 'Get-SecretATAPBitwarden'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving field '$SecretField' from Bitwarden item '$SecretName'"
  }

  PROCESS {
    try {
      # 1. Confirm the bw CLI is available on PATH.
      $bwCommand = Get-Command -Name 'bw' -ErrorAction SilentlyContinue
      if (-not $bwCommand) {
        $msg = "Bitwarden CLI (bw) was not found on PATH. Install Bitwarden CLI before using Get-SecretATAPBitwarden."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 2. Resolve BW_SESSION (process scope first, then User scope per R-10).
      $bwSession = $env:BW_SESSION
      if ([string]::IsNullOrWhiteSpace($bwSession)) {
        $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
        if (-not [string]::IsNullOrWhiteSpace($bwSession)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'BW_SESSION resolved from User-scope environment'
          $env:BW_SESSION = $bwSession
        }
      }
      if ([string]::IsNullOrWhiteSpace($bwSession)) {
        $msg = "BW_SESSION is not set in process or User scope. Run the LoginScript / Initialize-ServiceAccountBitwardenSession to establish a session before calling Get-SecretATAPBitwarden."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 3. Verify the vault is unlocked.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bw status to verify session validity' -Tag 'BWCall'
      $statusOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
        & bw status --session $bwSession 2>&1
      }
      $statusExit = $LASTEXITCODE
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "bw status exit code: $statusExit" -Tag 'BWCall'
      if ($statusExit -ne 0) {
        $msg = "bw status failed (exit $statusExit). Output: $statusOutput. BW_SESSION may be invalid; run Refresh-BWSession."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      $status = $statusOutput | ConvertFrom-Json -ErrorAction Stop
      if ($status.status -ne 'unlocked') {
        $msg = "Bitwarden vault is not unlocked (status: '$($status.status)'). Run Refresh-BWSession or the scheduled session-refresh task."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 4. Retrieve the item JSON.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling bw get item '$SecretName'" -Tag 'BWCall'
      $itemOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName $fn -ModuleName $mn {
        & bw get item $SecretName --session $bwSession 2>&1
      }
      $itemExit = $LASTEXITCODE
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "bw get item exit code: $itemExit" -Tag 'BWCall'
      if ($itemExit -ne 0) {
        $msg = "bw get item failed for '$SecretName' (exit $itemExit). Output: $itemOutput"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      $item = $null
      try {
        $item = $itemOutput | ConvertFrom-Json -ErrorAction Stop
      }
      catch {
        $msg = "Failed to parse JSON from bw get item for '$SecretName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      # 5. Extract the requested field.
      $normalizedField = $SecretField.ToLowerInvariant()
      $value = $null

      switch ($normalizedField) {
        'password' {
          if ($item.PSObject.Properties.Name -contains 'login' -and $null -ne $item.login -and -not [string]::IsNullOrEmpty([string]$item.login.password)) {
            $value = [string]$item.login.password
          }
          elseif ($item.PSObject.Properties.Name -contains 'notes' -and -not [string]::IsNullOrEmpty([string]$item.notes)) {
            $value = [string]$item.notes
          }
          else {
            $msg = "Bitwarden item '$SecretName' has neither a login.password nor a notes body for default 'password' lookup."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
          }
        }
        'username' {
          if ($item.PSObject.Properties.Name -contains 'login' -and $null -ne $item.login -and -not [string]::IsNullOrEmpty([string]$item.login.username)) {
            $value = [string]$item.login.username
          }
          else {
            $msg = "Bitwarden item '$SecretName' has no login.username field."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
          }
        }
        'notes' {
          if ($item.PSObject.Properties.Name -contains 'notes' -and -not [string]::IsNullOrEmpty([string]$item.notes)) {
            $value = [string]$item.notes
          }
          else {
            $msg = "Bitwarden item '$SecretName' has no notes body."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
          }
        }
        default {
          # Custom field lookup (case-insensitive match against fields[] name).
          if ($item.PSObject.Properties.Name -contains 'fields' -and $null -ne $item.fields) {
            $match = @($item.fields | Where-Object { $_.name -and ($_.name.ToLowerInvariant() -eq $normalizedField) })
            if ($match.Count -gt 0 -and -not [string]::IsNullOrEmpty([string]$match[0].value)) {
              $value = [string]$match[0].value
            }
          }
          if ($null -eq $value) {
            $msg = "Bitwarden item '$SecretName' has no custom field named '$SecretField'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
          }
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully retrieved field '$SecretField' from '$SecretName' (value redacted)"
      return $value
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-SecretATAPBitwarden failed for '$SecretName' field '$SecretField'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
