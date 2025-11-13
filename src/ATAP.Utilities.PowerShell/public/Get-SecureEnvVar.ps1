# Add to $PROFILE
function Get-SecureEnvVar {
  param(
    [Parameter(Mandatory)]
    [string]$VarName,

    [Parameter(Mandatory)]
    [string]$BitwardenItemId
  )

  # Check if variable already exists in current session
  if ($env:$VarName) {
    return $env:$VarName
  }

  # Check if Bitwarden session is available
  if (-not $env:BW_SESSION) {
    throw "Bitwarden session not available. Run login script first."
  }

  # Fetch from Bitwarden
  $value = bw get password $BitwardenItemId --session $env:BW_SESSION

  if ($LASTEXITCODE -eq 0) {
    # Set for current process only (doesn't persist)
    $env:$VarName = $value
    return $value
  }
  else {
    throw "Failed to retrieve $VarName from Bitwarden"
  }
}
