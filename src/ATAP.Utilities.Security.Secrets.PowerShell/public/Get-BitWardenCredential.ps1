<#
.SYNOPSIS
Retrieves or creates BitWarden login and unlock credentials for the current user and computer.

.DESCRIPTION
Loads existing encrypted BitWarden credentials from disk (login and unlock), or prompts the user
to create them if they don't exist. The credentials are stored encrypted in separate files and
can only be decrypted by the same user on the same computer. Returns a hashtable with both credentials.

.PARAMETER CredentialDirectory
Base directory where encrypted credentials are stored. Default is retrieved from global settings
or falls back to 'C:\Dropbox\Security\Credentials'.

.PARAMETER BitWardenUserName
BitWarden account email/username for login. Required when creating new credentials.

.PARAMETER BitWardenLoginPassword
BitWarden account password for login. Required when creating new credentials.

.PARAMETER BitWardenUnlockUserName
Username label for unlock credential (typically 'BitWarden'). Required when creating new credentials.

.PARAMETER BitWardenUnlockPassword
Master password for unlocking the vault. Required when creating new credentials.

.PARAMETER Replace
Forces recreation of the credential files by prompting for passwords even if files exist.
The existing credential files will be backed up before being replaced.

.OUTPUTS
System.Collections.Hashtable
Returns a hashtable with keys 'LoginCredential' and 'UnlockCredential'.

.EXAMPLE
$credentials = Get-BitWardenCredential
Retrieves or creates the BitWarden credentials for the current user.

.EXAMPLE
$credentials = Get-BitWardenCredential -BitWardenUserName 'user@example.com' -BitWardenLoginPassword 'loginPass' -BitWardenUnlockUserName 'BitWarden' -BitWardenUnlockPassword 'masterPass'
Creates new credentials with specified values.

.EXAMPLE
$credentials = Get-BitWardenCredential -Replace
Forces recreation of both credential files, backing up the old ones.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
The encrypted credential files are user and computer specific.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-BitWardenCredential {
  [CmdletBinding()]
  [OutputType([System.Collections.Hashtable])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$CredentialDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BitWardenUserName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BitWardenLoginPassword,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BitWardenUnlockUserName = 'BitWarden',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BitWardenUnlockPassword,

    [Parameter(Mandatory = $false)]
    [switch]$Replace
  )

  BEGIN {
    $fn = 'Get-BitWardenCredential'
    $mn = 'ATAP.Utilities.Security.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        # Resolve sibling module path relative to this script so the function works in
        # both the active sprint worktree and the stable repo without hardcoding.
        $siblingGetPVal = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1') -ErrorAction Stop
        . $siblingGetPVal.ProviderPath
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet: Check and populate simple parameter - CredentialDirectory
    if (-not $PSBoundParameters.ContainsKey('CredentialDirectory')) {
      if ($global:settings -and $global:settings.ContainsKey('CredentialDirectory')) {
        $CredentialDirectory = $global:settings['CredentialDirectory']
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using CredentialDirectory from global settings: $CredentialDirectory"
      }
      else {
        $CredentialDirectory = 'C:\Dropbox\Security\Credentials'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using default CredentialDirectory: $CredentialDirectory"
      }
    }
    else {
      $CredentialDirectory = Get-PVal -ParameterName 'CredentialDirectory' -originalPSBoundParameters $PSBoundParameters -dottedPath 'CredentialDirectory' -DefaultValue $CredentialDirectory
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using provided CredentialDirectory: $CredentialDirectory"
    }

    # Build credential file paths (user-specific and host-specific).
    # Derive the username token from [WindowsIdentity]::GetCurrent() rather than
    # $env:USERNAME because $env:USERNAME is inherited from the launching process
    # and is NOT refreshed when Start-Process -Credential switches the security
    # token (especially under -NoProfile). Using $env:USERNAME here produces
    # filenames tagged with the launcher account even though DPAPI correctly
    # encrypts under the spawned identity, which breaks subsequent lookups by
    # Refresh-BWSession running as the service account at boot/refresh time.
    $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    $loginCredFileName = "$env:COMPUTERNAME`_$currentSamName`_BW_Login_Credential.xml"
    $unlockCredFileName = "$env:COMPUTERNAME`_$currentSamName`_BW_Unlock_Credential.xml"
    $loginCredPath = Join-Path $CredentialDirectory $loginCredFileName
    $unlockCredPath = Join-Path $CredentialDirectory $unlockCredFileName

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Login credential file path: $loginCredPath"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Unlock credential file path: $unlockCredPath"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      $shouldCreateNew = $false
      $loginCredential = $null
      $unlockCredential = $null

      # Check if both credential files exist
      $loginExists = Test-Path $loginCredPath
      $unlockExists = Test-Path $unlockCredPath

      if ($loginExists -and $unlockExists -and -not $Replace) {
        # Load existing credentials
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Loading existing credentials from disk'
        $loginCredential = Import-Clixml -Path $loginCredPath -ErrorAction Stop
        $unlockCredential = Import-Clixml -Path $unlockCredPath -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully loaded login credential for user: $($loginCredential.UserName)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully loaded unlock credential for user: $($unlockCredential.UserName)"
      }
      else {
        # Need to create new credentials
        if ($Replace -and $loginExists -and $unlockExists) {
          # Backup existing credential files
          $loginBackupPath = "$loginCredPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
          $unlockBackupPath = "$unlockCredPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Replace parameter specified. Backing up existing credentials"
          Copy-Item -Path $loginCredPath -Destination $loginBackupPath -Force -ErrorAction Stop
          Copy-Item -Path $unlockCredPath -Destination $unlockBackupPath -Force -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Existing credentials backed up successfully"
        }

        $shouldCreateNew = $true
      }

      if ($shouldCreateNew) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Creating new credential files'

        # Validate all required parameters are provided for creation
        if ([string]::IsNullOrWhiteSpace($BitWardenUserName)) {
          $errorMessage = 'BitWardenUserName parameter is required when creating new credentials'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        if ([string]::IsNullOrWhiteSpace($BitWardenLoginPassword)) {
          $errorMessage = 'BitWardenLoginPassword parameter is required when creating new credentials'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        if ([string]::IsNullOrWhiteSpace($BitWardenUnlockPassword)) {
          $errorMessage = 'BitWardenUnlockPassword parameter is required when creating new credentials'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }

        # Create login credential
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating login credential for user: $BitWardenUserName"
        $secureLoginPassword = ConvertTo-SecureString $BitWardenLoginPassword -AsPlainText -Force
        $loginCredential = New-Object System.Management.Automation.PSCredential($BitWardenUserName, $secureLoginPassword)

        # Create unlock credential
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating unlock credential for user: $BitWardenUnlockUserName"
        $secureUnlockPassword = ConvertTo-SecureString $BitWardenUnlockPassword -AsPlainText -Force
        $unlockCredential = New-Object System.Management.Automation.PSCredential($BitWardenUnlockUserName, $secureUnlockPassword)

        # Ensure directory exists
        $credDir = Split-Path $loginCredPath -Parent
        if (-not (Test-Path $credDir)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating credential directory: $credDir"
          New-Item -Path $credDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created credential directory: $credDir"
        }

        # Save encrypted credentials
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Saving encrypted login credential to: $loginCredPath"
        $loginCredential | Export-Clixml -Path $loginCredPath -ErrorAction Stop

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Saving encrypted unlock credential to: $unlockCredPath"
        $unlockCredential | Export-Clixml -Path $unlockCredPath -ErrorAction Stop

        if ($Replace) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully replaced and saved credentials for login user: $($loginCredential.UserName)"
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully created and saved new credentials for login user: $($loginCredential.UserName)"
        }
      }

      # Return hashtable with both credentials
      $credentialHashtable = @{
        LoginCredential  = $loginCredential
        UnlockCredential = $unlockCredential
      }

      return $credentialHashtable
    }
    catch {
      $errorMessage = "Failed to retrieve or create BitWarden credentials. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
