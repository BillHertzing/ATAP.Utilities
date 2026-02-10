# Rebuild-All script for Philotes database
# This script rebuilds the Philotes database and loads initial data

# Set the database name
$databaseName = 'Philotes'
# Set the environment to use
$environment = 'Experimental'
# Set the database host
$databaseHost = 'localhost'

Write-PSFMessage -Level Important -Message "=== Starting Philotes Database Rebuild ==="
Write-PSFMessage -Level Important -Message "Database: $databaseName"
Write-PSFMessage -Level Important -Message "Environment: $environment"
Write-PSFMessage -Level Important -Message "Host: $databaseHost"

# Load the shared database rebuild function
try {
  if (-not (Get-Command -Name 'Rebuild-DatabaseFromFlyway' -CommandType Function -ErrorAction SilentlyContinue)) {
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Rebuild-DatabaseFromFlyway.ps1'
  }
}
catch {
  $errorMessage = "Failed to load Rebuild-DatabaseFromFlyway. Exception: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message $errorMessage
  throw
}

# Rebuild the database using Flyway migrations
try {
  Write-PSFMessage -Level Important -Message "Rebuilding database from Flyway migrations..."

  $rebuildResult = Rebuild-DatabaseFromFlyway `
    -DatabaseName $databaseName `
    -Environment $environment `
    -DatabaseHost $databaseHost `
    -flywayBasePath "..\..\Database\Flyway" `
    -Verbose:$VerbosePreference

  if (-not $rebuildResult.Success) {
    throw "Database rebuild failed. Errors: $($rebuildResult.Errors -join '; ')"
  }

  Write-PSFMessage -Level Important -Message "Database rebuild completed successfully"
}
catch {
  Write-PSFMessage -Level Error -Message "Database rebuild failed: $($_.Exception.Message)"
  Write-PSFMessage -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
  throw
}

# After successful rebuild, load the data into the database
try {
  Write-PSFMessage -Level Important -Message "Loading $databaseName data into database..."

  # Load the data loading function
  if (-not (Get-Command -Name 'Load-Philotes' -CommandType Function -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'Load-Philotes.ps1')
  }

  # Load tag data
  Load-Philotes `
    -DatabaseHost $databaseHost `
    -DatabaseName $databaseName `
    -Environment $environment `
    -IntegratedSecurity `
    -Verbose:$VerbosePreference

  Write-PSFMessage -Level Important -Message "=== Philotes Database Rebuild Complete ==="
}
catch {
  Write-PSFMessage -Level Error -Message "Load-Philotes failed: $($_.Exception.Message)"
  throw
}
