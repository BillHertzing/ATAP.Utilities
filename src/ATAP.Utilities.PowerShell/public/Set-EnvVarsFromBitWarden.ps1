<#
.SYNOPSIS
Retrieves API keys and tokens from Bitwarden vault and sets environment variables.

.DESCRIPTION
Accepts a declarative list of service configurations and retrieves their API keys or tokens
from the Bitwarden vault. For each entry, constructs an environment variable name, queries
Bitwarden for the specified item, extracts the value from the specified field, and stores it
in both process-scope and user-scope environment variables.

Failures for individual entries are logged and accumulated. Processing continues for remaining
entries even if one fails.

.PARAMETER EnvVarConfigs
Array of PSCustomObject entries, each containing:
- EnvVarName: Full name of the environment variable (e.g., 'GITHUB_API_TOKEN', 'CONTEXT7_API_KEY')
- BwSearchName: Name of the Bitwarden vault item to search for (e.g., 'Context7 API')
- BwFieldName: Field name in Bitwarden where the value is stored ('password', 'notes', or custom field name)

.OUTPUTS
PSCustomObject[]
Returns an array of result objects, one per config entry. Each object contains:
- EnvVarName: The constructed environment variable name
- Success: Boolean indicating whether the operation succeeded
- Message: Descriptive message about the result

.EXAMPLE
$configs = @(
  [PSCustomObject]@{ EnvVarName = 'GITHUB_API_TOKEN'; BwSearchName = 'GitHub API'; BwFieldName = 'password' }
  [PSCustomObject]@{ EnvVarName = 'CONTEXT7_API_KEY'; BwSearchName = 'Context7 API'; BwFieldName = 'password' }
)
$results = Set-EnvVarsFromBitWarden -EnvVarConfigs $configs

Retrieves GitHub and Context7 credentials and stores them in environment variables.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Requires Bitwarden CLI (bw.exe) to be installed and in PATH.
Requires active Bitwarden session (run Initialize-BitwardenSession first).

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>
function Set-EnvVarsFromBitWarden {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [PSCustomObject[]]$EnvVarConfigs
  )

  BEGIN {
    $fn = 'Set-EnvVarsFromBitWarden'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'startup'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Processing $($EnvVarConfigs.Count) environment variable configurations" -Tag 'startup'

    # Check if Bitwarden CLI is available
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Checking if Bitwarden CLI (bw.exe) is available' -Tag 'startup'
    $bwCommand = Get-Command -Name 'bw' -ErrorAction SilentlyContinue

    if (-not $bwCommand) {
      $errorMessage = 'Bitwarden CLI (bw.exe) not found in PATH. Please install Bitwarden CLI.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

      # Return failure result for all configs
      return $EnvVarConfigs | ForEach-Object {
        [PSCustomObject]@{
          EnvVarName = $_.EnvVarName
          Success    = $false
          Message    = $errorMessage
        }
      }
    }

    # Check if BW_SESSION environment variable is set
    $sessionKey = $env:BW_SESSION
    if ([string]::IsNullOrWhiteSpace($sessionKey)) {
      $errorMessage = 'BW_SESSION environment variable not set. Please run Initialize-BitwardenSession first.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

      # Return failure result for all configs
      return $EnvVarConfigs | ForEach-Object {
        [PSCustomObject]@{
          EnvVarName = $_.EnvVarName
          Success    = $false
          Message    = $errorMessage
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Active Bitwarden session found' -Tag 'startup'

    # Initialize results collection
    $results = @()
  }

  PROCESS {
    foreach ($config in $EnvVarConfigs) {
      # Get environment variable name from config
      $envVarName = $config.EnvVarName

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Processing config for $envVarName (searching for '$($config.BwSearchName)')" -Tag 'startup'

      try {
        if ($PSCmdlet.ShouldProcess($envVarName, "Retrieve from Bitwarden item '$($config.BwSearchName)' and set environment variable")) {
          # Search for the item in Bitwarden
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Searching for '$($config.BwSearchName)' in Bitwarden vault" -Tag 'startup'

          $searchOutput = bw list items --search $config.BwSearchName --session $sessionKey 2>&1
          $exitCode = $LASTEXITCODE

          if ($exitCode -ne 0) {
            $errorMessage = "Failed to search Bitwarden vault for '$($config.BwSearchName)'. Exit code: $exitCode. Output: $searchOutput"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

            $results += [PSCustomObject]@{
              EnvVarName = $envVarName
              Success    = $false
              Message    = $errorMessage
            }
            continue
          }

          try {
            $items = $searchOutput | ConvertFrom-Json

            if ($null -eq $items -or $items.Count -eq 0) {
              $errorMessage = "'$($config.BwSearchName)' not found in Bitwarden vault. Please add an item with this name."
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

              $results += [PSCustomObject]@{
                EnvVarName = $envVarName
                Success    = $false
                Message    = $errorMessage
              }
              continue
            }

            # Get the first matching item
            $item = $items[0]
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found item: $($item.name) (ID: $($item.id))" -Tag 'startup'

            # Extract the value based on the specified field name
            $value = $null

            switch ($config.BwFieldName.ToLower()) {
              'password' {
                if ($item.login -and $item.login.password) {
                  $value = $item.login.password
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Value retrieved from login password field" -Tag 'startup'
                }
              }
              'notes' {
                if ($item.notes) {
                  $value = $item.notes.Trim()
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Value retrieved from notes field" -Tag 'startup'
                }
              }
              'username' {
                if ($item.login -and $item.login.username) {
                  $value = $item.login.username
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Value retrieved from login username field" -Tag 'startup'
                }
              }
              default {
                # Custom field
                if ($item.fields) {
                  $customField = $item.fields | Where-Object { $_.name -eq $config.BwFieldName } | Select-Object -First 1
                  if ($customField) {
                    $value = $customField.value
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Value retrieved from custom field '$($config.BwFieldName)'" -Tag 'startup'
                  }
                }
              }
            }

            if ([string]::IsNullOrWhiteSpace($value)) {
              $errorMessage = "Value is empty or field '$($config.BwFieldName)' not found in '$($config.BwSearchName)' item."
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

              $results += [PSCustomObject]@{
                EnvVarName = $envVarName
                Success    = $false
                Message    = $errorMessage
              }
              continue
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Value length: $($value.Length)" -Tag 'startup'

            # Store value in process environment
            Set-Item -Path "env:$envVarName" -Value $value
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Value stored in process environment variable $envVarName" -Tag 'startup'

            # Store value in user-scope environment for current login session
            [System.Environment]::SetEnvironmentVariable($envVarName, $value, 'User')
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Value stored in user-scope environment variable $envVarName" -Tag 'startup'

            # Verify the environment variables were set
            $processValue = Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue
            $userValue = [System.Environment]::GetEnvironmentVariable($envVarName, 'User')
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Process $envVarName length: $(if($processValue){$processValue.Value.Length}else{'not set'})" -Tag 'startup'
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "User $envVarName length: $(if($userValue){$userValue.Length}else{'not set'})" -Tag 'startup'

            $successMessage = "$envVarName retrieved successfully from '$($config.BwSearchName)' and stored in environment variables"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $successMessage -Tag 'startup'

            $results += [PSCustomObject]@{
              EnvVarName = $envVarName
              Success    = $true
              Message    = $successMessage
            }
          }
          catch {
            $errorMessage = "Failed to parse Bitwarden output or extract value for '$($config.BwSearchName)'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

            $results += [PSCustomObject]@{
              EnvVarName = $envVarName
              Success    = $false
              Message    = $errorMessage
            }
          }
        }
      }
      catch {
        $errorMessage = "Failed to process configuration for $envVarName. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'startup'

        $results += [PSCustomObject]@{
          EnvVarName = $envVarName
          Success    = $false
          Message    = $errorMessage
        }
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Function completed. Processed $($results.Count) configurations: $($($results | Where-Object Success).Count) succeeded, $($($results | Where-Object { -not $_.Success }).Count) failed" -Tag 'startup'

    return $results
  }
}
