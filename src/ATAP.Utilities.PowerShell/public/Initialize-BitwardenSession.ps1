<#
.SYNOPSIS
Unlocks the interactive Bitwarden Password Manager vault and stores BW_SESSION.

.DESCRIPTION
Uses the Bitwarden CLI (`bw`) and locally stored Bitwarden credentials to unlock
an interactive user's Password Manager vault. The returned session key is stored
in both process and User-scope BW_SESSION so PowerShell profiles and interactive
commands can read personal-vault secrets without prompting again in the same
login context.

This command is for personal Password Manager access only. CI, BuildMaster,
service accounts, database connection strings, and project/runtime secrets must
use Bitwarden Secrets Manager through Get-SecretATAP / bws instead.

.OUTPUTS
PSCustomObject
Returns Success and Message fields describing the unlock result.

.EXAMPLE
Initialize-BitwardenSession

Unlocks the Bitwarden vault and writes BW_SESSION to Process and User scope.

.NOTES
Requires the Bitwarden CLI (`bw`) on PATH and Get-BitWardenCredential from
ATAP.Utilities.Security.Powershell.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Initialize-BitwardenSession {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param()

  begin {
    $fn = 'Initialize-BitwardenSession'
    $mn = 'ATAP.Utilities.Powershell'

    if (Get-Command -Name 'Set-PSFLoggingProvider' -ErrorAction SilentlyContinue) {
      try {
        Set-PSFLoggingProvider -Name logfile `
          -Enabled $true `
          -FilePath 'C:\Temp\PSFramework\Logs\startup.log' `
          -IncludeTags 'startup'
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Could not initialize startup logfile provider. Exception: $($_.Exception.Message)" -Tag 'startup'
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'startup'

    try {
      if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
        Import-Module ATAP.Utilities.Security.Powershell -ErrorAction SilentlyContinue
      }

      if (-not (Get-Command -Name 'Get-BitWardenCredential' -CommandType Function -ErrorAction SilentlyContinue)) {
        $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
        $repoRoot = Split-Path -Path (Split-Path -Path $moduleRoot -Parent) -Parent
        $candidatePaths = @(
          (Join-Path -Path $repoRoot -ChildPath 'src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenCredential.ps1'),
          'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-BitWardenCredential.ps1'
        )

        $credentialHelperPath = $candidatePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($credentialHelperPath)) {
          throw "Required function 'Get-BitWardenCredential' is not available and no source fallback was found."
        }

        . $credentialHelperPath
      }
    } catch {
      $errorMessage = "Failed to load required Bitwarden credential helper. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
      throw
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Attempting to unlock Bitwarden vault' -Tag 'startup'
  }

  process {
    $loginPassword = $null
    $unlockPassword = $null

    try {
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

      if (-not $PSCmdlet.ShouldProcess('Bitwarden Vault', 'Login and unlock, then store session key')) {
        return [PSCustomObject]@{
          Success = $true
          Message = 'WhatIf: would unlock Bitwarden vault and store BW_SESSION.'
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Retrieving Bitwarden credentials from encrypted files' -Tag 'startup'
      try {
        $credentials = Get-BitWardenCredential
        $loginCredential = $credentials['LoginCredential']
        $unlockCredential = $credentials['UnlockCredential']

        if ($null -eq $loginCredential -or $null -eq $unlockCredential) {
          throw 'Credential helper did not return both LoginCredential and UnlockCredential.'
        }

        $loginEmail = $loginCredential.UserName
        $loginPassword = $loginCredential.GetNetworkCredential().Password
        $unlockPassword = $unlockCredential.GetNetworkCredential().Password

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Login email: $loginEmail" -Tag 'startup'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Both credentials retrieved successfully' -Tag 'startup'
      } catch {
        $errorMessage = "Failed to retrieve Bitwarden credentials. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
        return [PSCustomObject]@{
          Success = $false
          Message = $errorMessage
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Checking Bitwarden login status' -Tag 'startup'
      $statusOutput = bw status 2>&1
      $statusExitCode = $LASTEXITCODE
      if ($statusExitCode -ne 0) {
        $errorMessage = "Failed to read Bitwarden status. Exit code: $statusExitCode. Output: $statusOutput"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
        return [PSCustomObject]@{
          Success = $false
          Message = $errorMessage
        }
      }

      $status = $statusOutput | ConvertFrom-Json -ErrorAction Stop
      $isLoggedIn = $status.status -ne 'unauthenticated'

      if (-not $isLoggedIn) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Not logged in, attempting to login to Bitwarden' -Tag 'startup'

        $env:BW_PASSWORD = $loginPassword
        $loginOutput = bw login $loginEmail --passwordenv BW_PASSWORD 2>&1
        $loginExitCode = $LASTEXITCODE
        Remove-Item Env:BW_PASSWORD -ErrorAction SilentlyContinue

        if ($loginExitCode -ne 0) {
          $errorMessage = "Failed to login to Bitwarden. Exit code: $loginExitCode. Output: $loginOutput"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
          return [PSCustomObject]@{
            Success = $false
            Message = $errorMessage
          }
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Successfully logged in to Bitwarden' -Tag 'startup'
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Already logged in to Bitwarden' -Tag 'startup'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'About to call bw unlock --raw --passwordenv BW_PASSWORD' -Tag 'startup'
      $env:BW_PASSWORD = $unlockPassword
      $sessionKey = bw unlock --raw --passwordenv BW_PASSWORD 2>&1
      $exitCode = $LASTEXITCODE
      Remove-Item Env:BW_PASSWORD -ErrorAction SilentlyContinue

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "bw unlock completed. Exit code: $exitCode" -Tag 'startup'
      $sessionKeyStr = if ($sessionKey) { $sessionKey.ToString() } else { $null }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Session key length: $(if ($sessionKeyStr) { $sessionKeyStr.Length } else { 'null or empty' })" -Tag 'startup'

      if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($sessionKeyStr)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Unlock successful, setting environment variables' -Tag 'startup'

        $env:BW_SESSION = $sessionKeyStr
        [System.Environment]::SetEnvironmentVariable('BW_SESSION', $sessionKeyStr, 'User')

        $processSession = $env:BW_SESSION
        $userSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Process BW_SESSION length: $(if ($processSession) { $processSession.Length } else { 'not set' })" -Tag 'startup'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "User BW_SESSION length: $(if ($userSession) { $userSession.Length } else { 'not set' })" -Tag 'startup'

        $successMessage = 'Bitwarden vault unlocked successfully and session key stored'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $successMessage -Tag 'startup'

        return [PSCustomObject]@{
          Success = $true
          Message = $successMessage
        }
      }

      if ($sessionKeyStr) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'bw unlock returned a non-empty error response.' -Tag 'startup'
      }

      $errorMessage = "Failed to unlock Bitwarden vault. Exit code: $exitCode."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

      return [PSCustomObject]@{
        Success = $false
        Message = $errorMessage
      }
    } catch {
      $errorMessage = "Failed to unlock Bitwarden vault. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'
      throw
    } finally {
      Remove-Item Env:BW_PASSWORD -ErrorAction SilentlyContinue
      $loginPassword = $null
      $unlockPassword = $null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Leaving Function $fn in module $mn" -Tag 'startup'
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Function completed' -Tag 'startup'
  }
}
