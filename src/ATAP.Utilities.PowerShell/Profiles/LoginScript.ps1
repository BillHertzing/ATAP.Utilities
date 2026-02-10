<#
.SYNOPSIS
Unlocks Bitwarden vault and stores session key in environment variables.

.DESCRIPTION
Executes the Bitwarden CLI to unlock the vault and stores the session key in both the
process and user-scope environment variables for the current login session. Logs all
operations and results using PSFramework logging.

.PARAMETER None
This function does not accept parameters.

.OUTPUTS
PSCustomObject
Returns an object with Success (bool) and Message (string) properties.

.EXAMPLE
Initialize-BitwardenSession

Unlocks Bitwarden and stores the session key.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
This script is designed to run automatically at user logon.
Requires Bitwarden CLI (bw.exe) to be installed and in PATH.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Initialize-BitwardenSession {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param()

  BEGIN {
    $fn = 'Initialize-BitwardenSession'
    $mn = 'ATAP.Utilities.Powershell'

    # specialized logging for startup script
    # ToDo: make the logging location a setting
    Set-PSFLoggingProvider -Name logfile `
      -Enabled $true `
      -FilePath 'C:\Temp\PSFramework\Logs\startup.log' `
      -IncludeTags 'startup'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'startup'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
      if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenCredential.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }


    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Attempting to unlock Bitwarden vault' -Tag 'startup'

  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Check if Bitwarden CLI is available
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Checking if Bitwarden CLI (bw.exe) is available' -Tag 'startup'
      $bwCommand = Get-Command -Name 'bw' -ErrorAction SilentlyContinue

      if (-not $bwCommand) {
        $errorMessage = 'Bitwarden CLI (bw.exe) not found in PATH. Please install Bitwarden CLI.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
        return [PSCustomObject]@{
          Success = $false
          Message = $errorMessage
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Bitwarden CLI found at: $($bwCommand.Source)" -Tag 'startup'

      if ($PSCmdlet.ShouldProcess('Bitwarden Vault', 'Login and unlock, then store session key')) {
        # Get Bitwarden credentials from encrypted credential files
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Retrieving Bitwarden credentials from encrypted files' -Tag 'startup'
        try {
          $credentials = Get-BitWardenCredential
          $loginCredential = $credentials['LoginCredential']
          $unlockCredential = $credentials['UnlockCredential']

          $loginEmail = $loginCredential.UserName
          $loginPassword = $loginCredential.GetNetworkCredential().Password
          $unlockPassword = $unlockCredential.GetNetworkCredential().Password

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Login email: $loginEmail" -Tag 'startup'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Both credentials retrieved successfully' -Tag 'startup'
        }
        catch {
          $errorMessage = "Failed to retrieve Bitwarden credentials. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
          return [PSCustomObject]@{
            Success = $false
            Message = $errorMessage
          }
        }

        # Check if already logged in
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Checking Bitwarden login status' -Tag 'startup'
        $statusOutput = bw status 2>&1 | ConvertFrom-Json
        $isLoggedIn = $statusOutput.status -ne 'unauthenticated'

        if (-not $isLoggedIn) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Not logged in, attempting to login to Bitwarden' -Tag 'startup'

          # Login to Bitwarden using login credentials
          $env:BW_PASSWORD = $loginPassword
          $loginOutput = bw login $loginEmail --passwordenv BW_PASSWORD 2>&1
          $loginExitCode = $LASTEXITCODE
          Remove-Item Env:BW_PASSWORD

          if ($loginExitCode -ne 0) {
            $errorMessage = "Failed to login to Bitwarden. Exit code: $loginExitCode. Output: $loginOutput"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
            $loginPassword = $null
            $unlockPassword = $null
            return [PSCustomObject]@{
              Success = $false
              Message = $errorMessage
            }
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Successfully logged in to Bitwarden' -Tag 'startup'
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Already logged in to Bitwarden' -Tag 'startup'
        }

        # Clear login password from memory
        # $loginPassword = $null

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Executing: bw unlock --raw (with unlock password via envvar)' -Tag 'startup'

        # Execute bw unlock with unlock password via envvar and capture output
        $env:BW_PASSWORD = $loginPassword

        # Log before unlock attempt
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'About to call bw unlock --raw --passwordenv BW_PASSWORD' -Tag 'startup'

        $sessionKey = bw unlock --raw --passwordenv BW_PASSWORD 2>&1
        $exitCode = $LASTEXITCODE

        # Log immediately after unlock
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "bw unlock completed. Exit code: $exitCode" -Tag 'startup'

        # Convert session key to string for safe handling
        $sessionKeyStr = if ($sessionKey) { $sessionKey.ToString() } else { $null }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Session key length: $(if($sessionKeyStr){$sessionKeyStr.Length}else{'null or empty'})" -Tag 'startup'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Session key first 20 chars: $(if($sessionKeyStr -and $sessionKeyStr.Length -gt 0){$sessionKeyStr.Substring(0, [Math]::Min(20, $sessionKeyStr.Length))}else{'N/A'})" -Tag 'startup'

        Remove-Item Env:BW_PASSWORD
        # Clear unlock password from memory
        $unlockPassword = $null

        if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($sessionKeyStr)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Unlock successful, setting environment variables' -Tag 'startup'

          # Store session key in process environment
          $env:BW_SESSION = $sessionKeyStr
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Session key stored in process environment variable' -Tag 'startup'

          # Store session key in user-scope environment for current login session
          [System.Environment]::SetEnvironmentVariable('BW_SESSION', $sessionKeyStr, 'User')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Session key stored in user-scope environment variable' -Tag 'startup'

          # Verify the environment variables were actually set
          $processSession = $env:BW_SESSION
          $userSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Process BW_SESSION length: $(if($processSession){$processSession.Length}else{'not set'})" -Tag 'startup'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "User BW_SESSION length: $(if($userSession){$userSession.Length}else{'not set'})" -Tag 'startup'

          $successMessage = 'Bitwarden vault unlocked successfully and session key stored'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $successMessage -Tag 'startup'

          return [PSCustomObject]@{
            Success = $true
            Message = $successMessage
          }
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Unlock condition failed. Exit code: $exitCode, Session key empty: $([string]::IsNullOrWhiteSpace($sessionKeyStr))" -Tag 'startup'

          # Log the actual output from bw unlock (might contain error message)
          if ($sessionKeyStr) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "bw unlock output: $sessionKeyStr" -Tag 'startup'
          }

          $errorMessage = "Failed to unlock Bitwarden vault. Exit code: $exitCode. Output: $sessionKeyStr"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

          return [PSCustomObject]@{
            Success = $false
            Message = $errorMessage
          }
        }
      }
    }
    catch {
      $errorMessage = "Failed to unlock Bitwarden vault. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Leaving Function $fn in module $mn" -Tag 'startup'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Function completed' -Tag 'startup'
  }
}

# ============================================================================
# Script execution block - runs when script is executed directly
# ============================================================================

# Only execute if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
  $fn = 'LoginScript-ExecutionBlock'
  $mn = 'ATAP.Utilities.Powershell'

  try {
    $result = Initialize-BitwardenSession

    # Write to Windows Event Log for scheduled task visibility
    $eventLogParams = @{
      LogName   = 'Application'
      Source    = 'BitwardenLogin'
      EntryType = if ($result.Success) { 'Information' } else { 'Error' }
      EventId   = if ($result.Success) { 1000 } else { 2000 }
      Message   = $result.Message
    }

    # Create event source if it doesn't exist (requires admin, do once)
    if (-not [System.Diagnostics.EventLog]::SourceExists('BitwardenLogin')) {
      try {
        New-EventLog -LogName Application -Source 'BitwardenLogin'
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not create event log source: $($_.Exception.Message)" -Tag 'startup'
      }
    }

    Write-EventLog @eventLogParams

    # Also log via PSFramework
    if ($result.Success) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $result.Message -Tag 'startup'
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $result.Message -Tag 'startup'
    }
  }
  catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "✗ CRITICAL ERROR: $($_.Exception.Message)" -Tag 'startup'
  }
}


<#
.SYNOPSIS
Retrieves Context7 API key from Bitwarden vault and sets environment variable.

.DESCRIPTION
Uses Bitwarden CLI to retrieve the Context7 API key from the vault and stores it
in both process and user-scope environment variables. Requires an active Bitwarden
session (BW_SESSION environment variable must be set).

.PARAMETER None
This function does not accept parameters.

.OUTPUTS
PSCustomObject
Returns an object with Success (bool) and Message (string) properties.

.EXAMPLE
Set-Context7APIKey

Retrieves Context7 API key and stores it in CONTEXT7_API environment variable.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires Bitwarden CLI (bw.exe) to be installed and in PATH.
Requires active Bitwarden session (run Initialize-BitwardenSession first).

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Set-Context7APIKey {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param()

  BEGIN {
    $fn = 'Set-Context7APIKey'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'startup'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Attempting to retrieve Context7 API key from Bitwarden vault' -Tag 'startup'
  }

  PROCESS {
    try {
      # Check if Bitwarden CLI is available
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Checking if Bitwarden CLI (bw.exe) is available' -Tag 'startup'
      $bwCommand = Get-Command -Name 'bw' -ErrorAction SilentlyContinue

      if (-not $bwCommand) {
        $errorMessage = 'Bitwarden CLI (bw.exe) not found in PATH. Please install Bitwarden CLI.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
        return [PSCustomObject]@{
          Success = $false
          Message = $errorMessage
        }
      }

      # Check if BW_SESSION environment variable is set
      $sessionKey = $env:BW_SESSION
      if ([string]::IsNullOrWhiteSpace($sessionKey)) {
        $errorMessage = 'BW_SESSION environment variable not set. Please run Initialize-BitwardenSession first.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
        return [PSCustomObject]@{
          Success = $false
          Message = $errorMessage
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Active Bitwarden session found' -Tag 'startup'

      if ($PSCmdlet.ShouldProcess('Context7 API Key', 'Retrieve from Bitwarden and set environment variable')) {
        # Search for Context7 API key item in Bitwarden
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Searching for Context7 API key in Bitwarden vault' -Tag 'startup'

        $searchOutput = bw list items --search "Context7 API" --session $sessionKey 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
          $errorMessage = "Failed to search Bitwarden vault. Exit code: $exitCode. Output: $searchOutput"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
          return [PSCustomObject]@{
            Success = $false
            Message = $errorMessage
          }
        }

        try {
          $items = $searchOutput | ConvertFrom-Json

          if ($null -eq $items -or $items.Count -eq 0) {
            $errorMessage = 'Context7 API key not found in Bitwarden vault. Please add an item with name "Context7 API".'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
            return [PSCustomObject]@{
              Success = $false
              Message = $errorMessage
            }
          }

          # Get the first matching item
          $item = $items[0]
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found item: $($item.name) (ID: $($item.id))" -Tag 'startup'

          # Extract the API key - check for different field types
          $apiKey = $null
          if ($item.login -and $item.login.password) {
            # API key stored as password
            $apiKey = $item.login.password
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'API key retrieved from login password field' -Tag 'startup'
          }
          elseif ($item.notes) {
            # API key stored in notes
            $apiKey = $item.notes.Trim()
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'API key retrieved from notes field' -Tag 'startup'
          }
          elseif ($item.fields) {
            # API key stored in custom field
            $apiKeyField = $item.fields | Where-Object { $_.name -eq 'apikey' -or $_.name -eq 'api_key' } | Select-Object -First 1
            if ($apiKeyField) {
              $apiKey = $apiKeyField.value
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'API key retrieved from custom field' -Tag 'startup'
            }
          }

          if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $errorMessage = 'Context7 API key value is empty or not found in expected fields (password, notes, or custom fields).'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
            return [PSCustomObject]@{
              Success = $false
              Message = $errorMessage
            }
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "API key length: $($apiKey.Length)" -Tag 'startup'

          # Store API key in process environment
          $env:CONTEXT7_API = $apiKey
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'API key stored in process environment variable' -Tag 'startup'

          # Store API key in user-scope environment for current login session
          [System.Environment]::SetEnvironmentVariable('CONTEXT7_API', $apiKey, 'User')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'API key stored in user-scope environment variable' -Tag 'startup'

          # Verify the environment variables were set
          $processApi = $env:CONTEXT7_API
          $userApi = [System.Environment]::GetEnvironmentVariable('CONTEXT7_API', 'User')
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Process CONTEXT7_API length: $(if($processApi){$processApi.Length}else{'not set'})" -Tag 'startup'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "User CONTEXT7_API length: $(if($userApi){$userApi.Length}else{'not set'})" -Tag 'startup'

          $successMessage = 'Context7 API key retrieved successfully and stored in environment variable'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $successMessage -Tag 'startup'

          return [PSCustomObject]@{
            Success = $true
            Message = $successMessage
          }
        }
        catch {
          $errorMessage = "Failed to parse Bitwarden output or extract API key. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
          return [PSCustomObject]@{
            Success = $false
            Message = $errorMessage
          }
        }
      }
    }
    catch {
      $errorMessage = "Failed to retrieve Context7 API key. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Leaving Function $fn in module $mn" -Tag 'startup'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Function completed' -Tag 'startup'
  }
}


# ============================================================================
# Script execution block - runs when script is executed directly
# ============================================================================

# Only execute if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
  $fn = 'LoginScript-ExecutionBlock'
  $mn = 'ATAP.Utilities.Powershell'

  try {
    # Initialize Bitwarden session first
    $result = Initialize-BitwardenSession

    # Write to Windows Event Log for scheduled task visibility
    $eventLogParams = @{
      LogName   = 'Application'
      Source    = 'BitwardenLogin'
      EntryType = if ($result.Success) { 'Information' } else { 'Error' }
      EventId   = if ($result.Success) { 1000 } else { 2000 }
      Message   = $result.Message
    }

    # Create event source if it doesn't exist (requires admin, do once)
    if (-not [System.Diagnostics.EventLog]::SourceExists('BitwardenLogin')) {
      try {
        New-EventLog -LogName Application -Source 'BitwardenLogin'
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not create event log source: $($_.Exception.Message)" -Tag 'startup'
      }
    }

    Write-EventLog @eventLogParams

    # Also log via PSFramework
    if ($result.Success) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $result.Message -Tag 'startup'

      # If Bitwarden session was successful, retrieve Context7 API key
      $apiKeyResult = Set-Context7APIKey

      if ($apiKeyResult.Success) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $apiKeyResult.Message -Tag 'startup'
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Context7 API key retrieval failed: $($apiKeyResult.Message)" -Tag 'startup'
      }
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $result.Message -Tag 'startup'
    }
  }
  catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "✗ CRITICAL ERROR: $($_.Exception.Message)" -Tag 'startup'
  }
}
