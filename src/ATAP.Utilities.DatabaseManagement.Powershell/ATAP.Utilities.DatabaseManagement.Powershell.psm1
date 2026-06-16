# ToDo : Module comment-based help

try {
    Import-Module -Name dbatools -ErrorAction Stop
} catch {
    Write-Error "Failed to import dbatools before loading ATAP.Utilities.DatabaseManagement.Powershell. dbatools must be loaded first because public functions declare Microsoft.Data.SqlClient.SqlConnection parameters. Exception: $_"
    throw
}

# get the fileIO info for each file in the public and private subdirectories
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue)

$privateFunctions = @(Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue)
$allFunctions = $publicFunctions + $privateFunctions
# Dot-source the public and private files.
foreach ($import in $allFunctions) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}
# list the public cmdlet and function names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)
# list the private cmdlet names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)

# Back-compat command alias (relocated here from private/DatabaseSqlConnection.Helpers.ps1
# so that file only DEFINES functions and executes nothing at load time). Created in
# module scope at import, exactly as the dot-sourced Set-Alias did before.
Set-Alias -Name Resolve-DatabaseSqlConnectionFromBitwardenSecretName -Value Resolve-DatabaseSqlConnectionFromDBConnectionStringSecretName -ErrorAction SilentlyContinue
