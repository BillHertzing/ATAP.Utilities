$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-Flyway.ps1',
  [ref]$tokens,
  [ref]$errors
)
if ($errors.Count -eq 0) {
  Write-Host 'Syntax OK - no parse errors'
} else {
  foreach ($e in $errors) {
    Write-Host "ERROR: $($e.ToString())"
  }
}
