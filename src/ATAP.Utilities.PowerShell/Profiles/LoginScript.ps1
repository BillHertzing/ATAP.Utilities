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
      if (-not (Get-Command -Name 'Set-EnvVarsFromBitWarden' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Set-EnvVarsFromBitWarden.ps1'
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

  # Create event source if it doesn't exist (requires admin, do once)
  if (-not [System.Diagnostics.EventLog]::SourceExists('BitwardenLogin')) {
    try {
      New-EventLog -LogName Application -Source 'BitwardenLogin'
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not create event log source: $($_.Exception.Message)" -Tag 'startup'
    }
  }

  # Log script start to Event Log
  try {
    Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Information -EventId 1000 -Message "LoginScript execution started"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'LoginScript execution started' -Tag 'startup'
  }
  catch {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not write start event to Event Log: $($_.Exception.Message)" -Tag 'startup'
  }

  try {
    # Load required helper function for environment variable setting
    if (-not (Get-Command -Name 'Set-EnvVarsFromBitWarden' -CommandType Function -ErrorAction SilentlyContinue)) {
      . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Set-EnvVarsFromBitWarden.ps1'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Loaded Set-EnvVarsFromBitWarden function' -Tag 'startup'
    }

    # Initialize Bitwarden session first
    $result = Initialize-BitwardenSession

    # Check if Bitwarden session failed
    if (-not $result.Success) {
      $failureMessage = "LoginScript failed: Bitwarden session initialization failed. $($result.Message)"
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Error -EventId 2000 -Message $failureMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $failureMessage -Tag 'startup'
      return
    }

    # Bitwarden session successful, continue
    if ($result.Success) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $result.Message -Tag 'startup'

      # If Bitwarden session was successful, retrieve API keys and tokens
      $envVarConfigs = @(
        [PSCustomObject]@{ EnvVarName = 'GITHUB_API_TOKEN'; BwSearchName = 'GitHub_API_Token'; BwFieldName = 'token' }
        [PSCustomObject]@{ EnvVarName = 'CONTEXT7_API_KEY'; BwSearchName = 'Context7_API_Key'; BwFieldName = 'key' }
        [PSCustomObject]@{ EnvVarName = 'PERPLEXITY_API_KEY'; BwSearchName = 'Perplexity_API_Key'; BwFieldName = 'key' }
        [PSCustomObject]@{ EnvVarName = 'SYNCFUSION_API_KEY'; BwSearchName = 'SyncFusion_API_Key'; BwFieldName = 'key' }
        [PSCustomObject]@{ EnvVarName = 'CHATGPT_API_KEY'; BwSearchName = 'ChatGPT_API_Key'; BwFieldName = 'key' }
        [PSCustomObject]@{ EnvVarName = 'JENKINS_API_TOKEN'; BwSearchName = 'Jenkins_API_Token'; BwFieldName = 'token' }
        [PSCustomObject]@{ EnvVarName = 'ANSIBLE_API_TOKEN'; BwSearchName = 'Ansible_API_Token'; BwFieldName = 'token' }
        [PSCustomObject]@{ EnvVarName = 'PROGET_ADMIN_API_TOKEN'; BwSearchName = 'ProGet_Admin_API_Token'; BwFieldName = 'token' }
      )

      $envVarResults = Set-EnvVarsFromBitWarden -EnvVarConfigs $envVarConfigs

      # Collect results for logging
      $successCount = 0
      $failureCount = 0
      $failureDetails = @()

      # Log results for each environment variable
      foreach ($envVarResult in $envVarResults) {
        if ($envVarResult.Success) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $envVarResult.Message -Tag 'startup'
          $successCount++
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "$($envVarResult.EnvVarName) retrieval failed: $($envVarResult.Message)" -Tag 'startup'
          $failureCount++
          $failureDetails += "$($envVarResult.EnvVarName): $($envVarResult.Message)"
        }
      }

      # Write final success event to Event Log
      $successMessage = "LoginScript completed successfully. Bitwarden session established. Environment variables processed: $successCount succeeded, $failureCount failed."
      if ($failureCount -gt 0) {
        $successMessage += " Failures: $($failureDetails -join '; ')"
      }
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Information -EventId 1001 -Message $successMessage
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $successMessage -Tag 'startup'
    }
  }
  catch {
    $errorMessage = "✗ CRITICAL ERROR in LoginScript: $($_.Exception.Message). StackTrace: $($_.Exception.StackTrace)"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

    # Write failure to Event Log
    try {
      Write-EventLog -LogName Application -Source 'BitwardenLogin' -EntryType Error -EventId 2001 -Message $errorMessage
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not write error to Event Log: $($_.Exception.Message)" -Tag 'startup'
    }
  }
}
