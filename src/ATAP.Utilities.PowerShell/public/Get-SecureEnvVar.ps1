# Add to $PROFILE
function Get-SecureEnvVar {
  param(
    [Parameter(Mandatory)]
    [string]$VarName,

    [Parameter(Mandatory)]
    [string]$BitwardenItemId
  )

  # Check if variable already exists in current session
  $existingValue = [Environment]::GetEnvironmentVariable($VarName, 'Process')
  if (-not [string]::IsNullOrWhiteSpace($existingValue)) {
    return $existingValue
  }

  # Check if Bitwarden session is available
  if (-not $env:BW_SESSION) {
    throw "Bitwarden session not available. Run login script first."
  }

  # Fetch from Bitwarden
  $value = bw get password $BitwardenItemId --session $env:BW_SESSION

  if ($LASTEXITCODE -eq 0) {
    # Set for current process only (doesn't persist)
    [Environment]::SetEnvironmentVariable($VarName, $value, 'Process')
    return $value
  }
  else {
    throw "Failed to retrieve $VarName from Bitwarden"
  }
}
