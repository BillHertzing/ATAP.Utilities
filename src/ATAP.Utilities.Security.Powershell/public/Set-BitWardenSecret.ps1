<#
.SYNOPSIS
Creates a new login secret in Bitwarden vault with semantic suffix naming.

.DESCRIPTION
Creates a new login item in Bitwarden using the CLI. The item name is automatically
suffixed based on the parameter set used:
  - Credential: Username AND Password (suffix: -Credential)
  - Identity: Username only (suffix: -Identity)
  - Passcode: Password only (suffix: -Passcode)
  - ApiKey: API key/notes (suffix: -ApiKey)

The item is created directly in Bitwarden, not via SecretManagement
(which is read-only for Bitwarden vaults).

.PARAMETER Name
The base name of the secret/login item. The appropriate suffix (-Credential, -Identity,
-Passcode, or -ApiKey) will be appended automatically based on the parameter set.

.PARAMETER Username
The username for the login item. Required for Credential and Identity parameter sets.

.PARAMETER Password
The password for the login item (clear text - will be stored securely in Bitwarden).
Required for Credential and Passcode parameter sets.

.PARAMETER ApiKey
The API key or secret value to store as a secure note. Required for ApiKey parameter set.

.PARAMETER URIs
An array of URIs associated with this login. Each URI will be added to the login item.
Available for Credential, Identity, and Passcode parameter sets.

.PARAMETER Notes
Optional notes to attach to the login item.

.PARAMETER FolderId
Optional folder ID to place the item in. Use 'bw list folders' to find folder IDs.

.PARAMETER Force
If the secret already exists, replace it with the new values. Without -Force,
the function will throw an error if the secret already exists.

.OUTPUTS
PSCustomObject representing the created Bitwarden item.

.EXAMPLE
Set-BitWardenSecret -Name 'PCMSCCE-bhertzing' -Username 'bhertzing' -Password 'mypass'

Creates 'PCMSCCE-bhertzing-Credential' with username and password.

.EXAMPLE
Set-BitWardenSecret -Name 'PCMSCCE-bhertzing' -Username 'bhertzing' -Password 'mypass' -URIs 'https://pcmsc.clubexpress.com/'

Creates 'PCMSCCE-bhertzing-Credential' with username, password, and URI.

.EXAMPLE
Set-BitWardenSecret -Name 'ServiceAccount' -Username 'svc_account'

Creates 'ServiceAccount-Identity' with username only.

.EXAMPLE
Set-BitWardenSecret -Name 'DatabaseKey' -Password 'secret123'

Creates 'DatabaseKey-Passcode' with password only.

.EXAMPLE
Set-BitWardenSecret -Name 'GitHubToken' -ApiKey 'ghp_xxxxxxxxxxxx'

Creates 'GitHubToken-ApiKey' as a secure note.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires BW_SESSION environment variable to be set and vault to be unlocked.
Use 'bw unlock' to get a session key, then set $env:BW_SESSION.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Set-BitWardenSecret {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Credential')]
  param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Credential')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Identity')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Passcode')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ApiKey')]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, ParameterSetName = 'Credential')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Identity')]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true, ParameterSetName = 'Credential')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Passcode')]
    [ValidateNotNullOrEmpty()]
    [string]$Password,

    [Parameter(Mandatory = $true, ParameterSetName = 'ApiKey')]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [Parameter(Mandatory = $false, ParameterSetName = 'Credential')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Identity')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Passcode')]
    [string[]]$URIs,

    [Parameter(Mandatory = $false)]
    [string]$Notes,

    [Parameter(Mandatory = $false)]
    [string]$FolderId,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  BEGIN {
    # Snippet: FunctionNameModuleName - Function and Module name variables for logging
    $fn = $MyInvocation.MyCommand.Name
    $mn = if ($MyInvocation.MyCommand.Module) { $MyInvocation.MyCommand.Module.Name } else { 'ATAP.Utilities.Security.Powershell' }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Determine suffix based on parameter set
    $suffix = switch ($PSCmdlet.ParameterSetName) {
      'Credential' { '-Credential' }
      'Identity' { '-Identity' }
      'Passcode' { '-Passcode' }
      'ApiKey' { '-ApiKey' }
    }
    $fullName = "$Name$suffix"

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parameter set: $($PSCmdlet.ParameterSetName), Full name: $fullName"

    # Verify BW_SESSION is set
    if ([string]::IsNullOrWhiteSpace($env:BW_SESSION)) {
      $errorMessage = 'BW_SESSION environment variable is not set. Run "bw unlock" and set the session key.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parameters validated: FullName='$fullName', ParameterSet='$($PSCmdlet.ParameterSetName)', URIs count=$($URIs.Count), Force=$Force"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Check if item already exists in Bitwarden
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Checking if item '$fullName' already exists in Bitwarden"
      $existingItemsJson = bw list items --search $fullName 2>&1
      $existingItems = $existingItemsJson | ConvertFrom-Json -ErrorAction SilentlyContinue
      $existingItem = $existingItems | Where-Object { $_.name -eq $fullName } | Select-Object -First 1

      if ($existingItem) {
        if ($Force) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Item '$fullName' exists (ID: $($existingItem.id)). -Force specified, deleting existing item."
          if ($PSCmdlet.ShouldProcess($fullName, 'Delete existing Bitwarden item')) {
            $deleteResult = bw delete item $existingItem.id 2>&1
            $deleteExitCode = $LASTEXITCODE
            if ($deleteExitCode -ne 0) {
              $errorMessage = "Failed to delete existing item '$fullName'. Exit code: $deleteExitCode. Output: $deleteResult"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
              throw $errorMessage
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully deleted existing item '$fullName'"
          }
        }
        else {
          $errorMessage = "A secret named '$fullName' already exists in Bitwarden (ID: $($existingItem.id)). Use -Force to replace it."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Creating Bitwarden item: $fullName"

      # Determine item type: 1 = Login, 2 = Secure Note
      $isSecureNote = $PSCmdlet.ParameterSetName -eq 'ApiKey'

      if ($isSecureNote) {
        # Build secure note item (type 2)
        $itemObject = @{
          type       = 2
          name       = $fullName
          notes      = $ApiKey
          secureNote = @{
            type = 0  # Generic secure note
          }
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Building secure note item for ApiKey'
      }
      else {
        # Build URIs array for Bitwarden login
        $uriObjects = @()
        if ($URIs -and $URIs.Count -gt 0) {
          foreach ($uri in $URIs) {
            if (-not [string]::IsNullOrWhiteSpace($uri)) {
              $uriObjects += @{
                uri   = $uri
                match = 0  # 0 or null = default matching
              }
            }
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Built $($uriObjects.Count) URI object(s)"
        }

        # Build the login object based on parameter set
        $loginObject = @{}
        if ($PSCmdlet.ParameterSetName -in @('Credential', 'Identity')) {
          $loginObject['username'] = $Username
        }
        if ($PSCmdlet.ParameterSetName -in @('Credential', 'Passcode')) {
          $loginObject['password'] = $Password
        }
        if ($uriObjects.Count -gt 0) {
          $loginObject['uris'] = $uriObjects
        }

        # Build the item object (type 1 = Login)
        $itemObject = @{
          type  = 1
          name  = $fullName
          login = $loginObject
        }
      }

      # Add optional notes (for login items, ApiKey already uses notes field)
      if (-not $isSecureNote -and -not [string]::IsNullOrWhiteSpace($Notes)) {
        $itemObject['notes'] = $Notes
      }
      if (-not [string]::IsNullOrWhiteSpace($FolderId)) {
        $itemObject['folderId'] = $FolderId
      }

      # Convert to JSON
      $itemJson = $itemObject | ConvertTo-Json -Depth 10 -Compress
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Generated item JSON for '$fullName' (sensitive data redacted)"

      # Encode to base64 (required by bw create)
      $encodedItem = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($itemJson))

      if ($PSCmdlet.ShouldProcess($fullName, 'Create Bitwarden item')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling bw create item' -Tag 'InvokeExpressionCall'

        try {
          $result = bw create item $encodedItem 2>&1
          $exitCode = $LASTEXITCODE

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Successfully returned from bw create item' -Tag 'InvokeExpressionCall'

          if ($exitCode -ne 0) {
            $errorMessage = "bw create item failed with exit code $exitCode. Output: $result"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw $errorMessage
          }

          # Parse the result (bw returns the created item as JSON)
          $createdItem = $result | ConvertFrom-Json
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully created Bitwarden item '$fullName' with ID: $($createdItem.id)"

          # Sync to update local cache
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Syncing Bitwarden vault'
          bw sync | Out-Null

          # Return the created item
          $createdItem
        }
        catch {
          $errorMessage = "Failed to create Bitwarden item. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw
        }
      }
    }
    catch {
      $errorMessage = "Failed to create Bitwarden secret '$fullName'. Exception: $($_.Exception.Message)"
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
