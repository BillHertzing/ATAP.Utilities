# AI assisted using Powershell.instructions.md as guidelines
function Get-SecureEnvVar {
  <#
  .SYNOPSIS
    Retrieves a secure environment variable, fetching it from Bitwarden if absent.
  .DESCRIPTION
    Checks Process scope then User scope (registry) for an existing value of the
    named environment variable. If absent in both scopes, uses Bitwarden CLI with
    the supplied item ID to fetch the value, then sets it in Process scope for the
    current session.
    Per R-10: agent-spawned shells do not inherit interactive session variables;
    User-scope registry is always checked before calling Bitwarden.
  .PARAMETER VarName
    The name of the environment variable to retrieve or populate.
  .PARAMETER BitwardenItemId
    The Bitwarden item ID whose password field supplies the variable value.
  .OUTPUTS
    [string] The value of the environment variable.
  .EXAMPLE
    $apiKey = Get-SecureEnvVar -VarName 'MY_API_KEY' -BitwardenItemId 'abc123guid'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://github.com/BillHertzing/ATAP.Utilities
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$VarName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BitwardenItemId
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "BEGIN: VarName='$VarName'"
  }

  process {
    # Check Process scope first (fastest path)
    $existingValue = [System.Environment]::GetEnvironmentVariable($VarName, 'Process')
    if (-not [string]::IsNullOrWhiteSpace($existingValue)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found '$VarName' in Process scope."
      return $existingValue
    }

    # Check User scope (registry) — required for agent shells per R-10
    $existingValue = [System.Environment]::GetEnvironmentVariable($VarName, 'User')
    if (-not [string]::IsNullOrWhiteSpace($existingValue)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found '$VarName' in User scope; promoting to Process scope."
      [System.Environment]::SetEnvironmentVariable($VarName, $existingValue, 'Process')
      return $existingValue
    }

    # Resolve BW_SESSION: check Process scope then User scope per R-10
    $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'Process')
    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      $bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
    }

    if ([string]::IsNullOrWhiteSpace($bwSession)) {
      $errMsg = 'Bitwarden session not available (BW_SESSION absent in Process and User scope). Run the login script first.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
      throw $errMsg
    }

    # Fetch from Bitwarden CLI
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Fetching '$VarName' from Bitwarden item '$BitwardenItemId'."
    $value = bw get password $BitwardenItemId --session $bwSession 2>&1
    if ($LASTEXITCODE -ne 0) {
      $errMsg = "Failed to retrieve '$VarName' from Bitwarden (exit $LASTEXITCODE): $value"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
      throw $errMsg
    }

    # Cache in Process scope for this session
    [System.Environment]::SetEnvironmentVariable($VarName, $value, 'Process')
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Stored '$VarName' in Process scope."
    return $value
  }
}
