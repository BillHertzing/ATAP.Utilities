<#
.SYNOPSIS
    Loads environment variables from a file.

.DESCRIPTION
    Parses a .env format file and sets environment variables for the current process.
    Handles quoted values and ignores comments.

.PARAMETER FilePath
    Path to the environment file to load.

.PARAMETER FileDescription
    Description of the file for logging purposes.

.EXAMPLE
    Import-EnvFile -FilePath ".env" -FileDescription ".env"
#>
function Import-EnvFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [Parameter(Mandatory)]
    [string]$FileDescription
  )

  if (-not (Test-Path $FilePath)) {
    Write-PSFMessage -Level Verbose -Message "$FileDescription file not found at: $FilePath"
    return $false
  }

  $loadedCount = 0
  Get-Content $FilePath | ForEach-Object {
    $line = $_.Trim()

    # Skip empty lines and comments
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
      return
    }

    # Match KEY=VALUE pattern
    if ($line -match '^([^=]+)=(.*)$') {
      $name = $matches[1].Trim()
      $value = $matches[2].Trim()

      # Remove surrounding quotes if present
      if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
        $value = $matches[1]
      }

      # Set environment variable for current process
      [Environment]::SetEnvironmentVariable($name, $value, [EnvironmentVariableTarget]::Process)
      $loadedCount++
      Write-PSFMessage -Level Verbose -Message "Set environment variable: $name"

      # Verify it was set
      $verifyValue = [Environment]::GetEnvironmentVariable($name, [EnvironmentVariableTarget]::Process)
      if ($null -eq $verifyValue) {
        Write-PSFMessage -Level Warning -Message "Failed to verify environment variable: $name"
      }
    }
  }

  Write-PSFMessage -Level Important -Message "Loaded $loadedCount environment variables from $FileDescription file: $FilePath"
  return $true
}
