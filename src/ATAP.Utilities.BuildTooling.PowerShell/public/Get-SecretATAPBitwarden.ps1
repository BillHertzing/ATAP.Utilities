<#
.SYNOPSIS
Retrieves a single field from a PERSONAL Bitwarden Password Manager vault item
via the Bitwarden CLI. Reserved for per-user personal secrets only.

.DESCRIPTION
Get-SecretATAPBitwarden is the personal-vault (Bitwarden Password Manager)
provider behind Get-SecretATAP. It does NOT use
Microsoft.PowerShell.SecretManagement or any Bitwarden vault extension; it
shells out to the Bitwarden CLI (`bw`) and parses the resulting JSON.

QUARANTINED FOR CI/INFRA SECRETS (Task 9.21): CI/infrastructure secrets must
NEVER live in a user's personal vault. This provider refuses any SecretName that
looks like a CI/infra secret - SQL connection strings (dbConnectionString-*),
API keys (*_API_KEY, *.API.Key), ProGet/BuildMaster secrets, webhook secrets,
and service-account login items (e.g. *Svc*). Read those from Bitwarden Secrets
Manager via Get-SecretATAP (the default store for all accounts since SC-0175) or
use the deterministic connection-string fallback (Task 9.22). This path remains
only for genuine per-user personal secrets, and is opt-in: callers must select it
with Get-SecretATAP -SecretStoreType 'Bitwarden'.

Session handling:
1. Reads BW_SESSION from process scope. If empty, reads from User scope
   (the interactive LoginScript destination — a personal-vault unlock).
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
Get-SecretATAPBitwarden -SecretName 'my-personal-login'
Returns the password field from a personal Login-type item as plain text.

.EXAMPLE
Get-SecretATAPBitwarden -SecretName 'my-personal-note' -SecretField 'notes'
Returns the notes body of a personal Secure Note.

.EXAMPLE
Get-SecretATAPBitwarden -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-whertzing' -SecretField 'notes'
THROWS - a CI/infra connection-string secret is refused on the personal-vault
path (Task 9.21). Use Bitwarden Secrets Manager instead:
  Get-SecretATAP -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-whertzing' -SecretField 'notes'
which resolves through Bitwarden Secrets Manager by default.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Renamed from Get-BitwardenSecret and rewritten to use bw CLI directly (no SecretManagement).
Task 9.21: quarantined - refuses CI/infra secret names; personal-vault use only.

.LINK
https://bitwarden.com/help/cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
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
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving field '$SecretField' from Bitwarden item '$SecretName'"
  }

  PROCESS {
    try {
      # -- CI/infra secret quarantine (Task 9.21) ------------------------------
      # The personal-vault Bitwarden Password Manager path (this provider) must
      # NEVER serve CI/infrastructure secrets - those live only in Bitwarden
      # Secrets Manager (bws + DPAPI machine access token) or are produced by the
      # deterministic connection-string fallback (Task 9.22). Refuse any
      # SecretName that looks like a CI/infra secret so this bw path is reserved
      # for genuine per-user personal secrets only. This runs before any bw
      # invocation so the refusal is independent of session/CLI state.
      $ciSecretNamePatterns = @(
        '^dbConnectionString-'   # SQL connection strings (sprint + permanent tiers)
        '_API_KEY$'              # env-var style API keys (PROGET_ADMIN_API_KEY, *_API_KEY)
        'API[._-]?Key'           # BuildMaster.Admin.API.Key, *ApiKey
        '^PROGET[_.-]'           # ProGet infrastructure secrets
        '^BUILDMASTER[_.-]'      # BuildMaster infrastructure secrets
        'WEBHOOK'                # webhook signing secrets
        'Svc[A-Za-z0-9]'         # service-account login items (e.g. utat022-SvcBuildmaster-Production)
      )
      foreach ($ciPattern in $ciSecretNamePatterns) {
        if ($SecretName -imatch $ciPattern) {
          $msg = "Get-SecretATAPBitwarden refuses CI/infrastructure secret '$SecretName' (matched quarantine pattern '$ciPattern'). CI/infra secrets must never be read from a personal Bitwarden Password Manager vault (Task 9.21). Read it from Bitwarden Secrets Manager instead: Get-SecretATAP -SecretName '$SecretName' -SecretStoreType 'BitwardenSecretsManager' (the default for all accounts since SC-0175), or use the deterministic connection-string fallback (Task 9.22). The bw/personal-vault path is reserved for genuine per-user personal secrets only."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
          throw $msg
        }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Get-SecretATAPBitwarden (personal-vault bw provider) serving '$SecretName' - this path is reserved for per-user personal secrets only; CI/infrastructure secrets must use Bitwarden Secrets Manager (Get-SecretATAP default)."

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
        $msg = "BW_SESSION is not set in process or User scope. Unlock your personal Bitwarden vault (interactive LoginScript / 'bw unlock') before calling Get-SecretATAPBitwarden. This personal-vault path is for per-user personal secrets only; CI/infrastructure secrets use Bitwarden Secrets Manager (Get-SecretATAP default)."
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
        $msg = "bw status failed (exit $statusExit). Output: $statusOutput. BW_SESSION may be invalid; re-unlock your personal Bitwarden vault ('bw unlock')."
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
