
whoami
git --version
Write-EnvironmentVariablesIndented

$global:configRootKeys['DropboxAccessTokenConfigRootKey'] + ' = ' + [Environment]::GetEnvironmentVariable($global:configRootKeys['DropboxAccessTokenConfigRootKey'])
Write-output "OUTPUT"
Write-Host "HOST"
Write-Warning "WARNING"
Write-Error "ERROR"
#ipmo ATAP.Utilities.FileIO.Powershell
. ./Get-DropBoxFolderCursor.ps1
. ./Get-DropBoxAllFolderCursors.ps1


Get-DropBoxAllFolderCursors

