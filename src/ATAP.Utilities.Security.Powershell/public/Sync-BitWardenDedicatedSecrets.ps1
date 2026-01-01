<#
.SYNOPSIS
Synchronizes Bitwarden secrets to a SecretManagement vault.

.DESCRIPTION
Retrieves items from Bitwarden CLI and syncs them to a registered SecretManagement vault.
Login items are split into separate Username and Password secrets. Secure notes are
stored as ApiKey secrets. Supports filtering by name pattern.

.PARAMETER VaultName
The name of the SecretManagement vault that maps to Bitwarden via SecretManagement.Warden.
Defaults to 'BitWarden'.

.PARAMETER NameFilter
Optional filter to only sync items whose names match the specified pattern (e.g., 'pcmsc' or 'api').

.OUTPUTS
None. Logs synchronization progress via Write-PSFMessage.

.EXAMPLE
Sync-BitWardenDedicatedSecrets

Syncs all Bitwarden items to the default vault.

.EXAMPLE
Sync-BitWardenDedicatedSecrets -VaultName 'MyVault' -NameFilter 'api'

Syncs only items containing 'api' in their name to the specified vault.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires BW_SESSION environment variable to be set and vault to be unlocked.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Sync-BitWardenDedicatedSecrets {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $false)]
    [string]$VaultName = 'BitWarden',

    [Parameter(Mandatory = $false)]
    [string]$NameFilter = ''
  )

  BEGIN {
    $fn = 'Sync-BitWardenDedicatedSecrets'
    $mn = 'ATAP.Utilities.Security.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Snippet: Check and populate optional parameter
    if (-not $PSBoundParameters.ContainsKey('VaultName')) {
      if ($global:settings -and $global:ConfigRootKeys -and $global:ConfigRootKeys.ContainsKey('BitWardenVaultNameConfigRootKey')) {
        $configValue = $global:settings[$global:ConfigRootKeys['BitWardenVaultNameConfigRootKey']]
        if ($configValue) {
          $VaultName = $configValue
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "VaultName parameter populated from configuration: $VaultName"
        }
      }
    }

    # Import required module
    try {
      Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Successfully imported Microsoft.PowerShell.SecretManagement module'
    }
    catch {
      $errorMessage = "Failed to import Microsoft.PowerShell.SecretManagement module. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Verifying SecretManagement vault: $VaultName"

      # Verify vault and force Bitwarden CLI sync via Test-SecretVault
      try {
        Test-SecretVault -Name $VaultName | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Vault '$VaultName' verified successfully"
      }
      catch {
        $errorMessage = "Failed to verify vault '$VaultName'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Retrieving items from Bitwarden CLI...'

      # Pull all Bitwarden items from the CLI cache
      try {
        $itemsJson = bw list items
        if (-not $itemsJson) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "No items returned from 'bw list items'. Is BW_SESSION set and vault unlocked?"
          return
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Successfully retrieved items from Bitwarden CLI'
      }
      catch {
        $errorMessage = "Failed to execute 'bw list items'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      $items = $itemsJson | ConvertFrom-Json
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieved $($items.Count) items from Bitwarden"

      # Filter by name if requested
      if ($NameFilter) {
        $items = $items | Where-Object { $_.name -like "*$NameFilter*" }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Filtered to $($items.Count) items matching '$NameFilter'"
      }

      # Defensive check: ensure items exist after filtering
      if ($null -eq $items -or @($items).Count -eq 0) {
        $warningMessage = if ($NameFilter) {
          "No items found matching filter '$NameFilter'. Nothing to sync."
        }
        else {
          'No items found in Bitwarden vault. Nothing to sync.'
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $warningMessage
        return
      }

      $syncedCount = 0
      $skippedCount = 0

      foreach ($item in $items) {
        # Skip items without a name
        if ([string]::IsNullOrWhiteSpace($item.name)) {
          $skippedCount++
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Skipping item with empty name'
          continue
        }

        # Basic classification: login vs. other (e.g., secure note used as API key)
        $isLogin = $null -ne $item.login
        $username = if ($isLogin) { $item.login.username } else { $null }
        $password = if ($isLogin) { $item.login.password } else { $null }
        # Extract URIs as semicolon-delimited string (easy to split back with -split ';')
        $uris = if ($isLogin -and $item.login.uris) { ($item.login.uris.uri -join ';') } else { $null }

        if ($isLogin) {
          # Store login as hashtable with Username, Password (SecureString), and URIs
          if ($username -and $password) {
            $secretName = "$($item.name)-Credential"
            if ($PSCmdlet.ShouldProcess($secretName, 'Sync credential to vault')) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Syncing credential '$secretName' from Bitwarden login '$($item.name)'"
              $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
              $secretHashtable = @{
                Username = $username
                Password = $securePassword
              }
              if ($uris) {
                $secretHashtable['URIs'] = $uris
              }
              Set-Secret -Name $secretName -Secret $secretHashtable -Vault $VaultName
              $syncedCount++
            }
          }
          elseif ($username) {
            # Username only - store as hashtable for consistency
            $secretName = "$($item.name)-Identity"
            if ($PSCmdlet.ShouldProcess($secretName, 'Sync identity to vault')) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Syncing identity '$secretName' from Bitwarden login '$($item.name)'"
              $secretHashtable = @{
                Username = $username
              }
              if ($uris) {
                $secretHashtable['URIs'] = $uris
              }
              Set-Secret -Name $secretName -Secret $secretHashtable -Vault $VaultName
              $syncedCount++
            }
          }
          elseif ($password) {
            # Password only - store as hashtable for consistency
            $secretName = "$($item.name)-Passcode"
            if ($PSCmdlet.ShouldProcess($secretName, 'Sync passcode to vault')) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Syncing passcode '$secretName' from Bitwarden login '$($item.name)'"
              $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
              $secretHashtable = @{
                Password = $securePassword
              }
              if ($uris) {
                $secretHashtable['URIs'] = $uris
              }
              Set-Secret -Name $secretName -Secret $secretHashtable -Vault $VaultName
              $syncedCount++
            }
          }
        }
        else {
          # Treat secure note or other item as a generic API key/secret
          if ($item.notes) {
            $secretName = "$($item.name)-ApiKey"
            if ($PSCmdlet.ShouldProcess($secretName, 'Sync API key to vault')) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Syncing API key '$secretName' from Bitwarden note '$($item.name)'"
              $secureNotes = ConvertTo-SecureString -String $item.notes -AsPlainText -Force
              $secretHashtable = @{
                ApiKey = $secureNotes
              }
              Set-Secret -Name $secretName -Secret $secretHashtable -Vault $VaultName
              $syncedCount++
            }
          }
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Synchronization complete. Synced: $syncedCount secrets, Skipped: $skippedCount items"
    }
    catch {
      $errorMessage = "Failed to sync Bitwarden secrets. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
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

Set-Alias -Name Sync-DedicatedSecrets -Value Sync-BitWardenDedicatedSecrets
