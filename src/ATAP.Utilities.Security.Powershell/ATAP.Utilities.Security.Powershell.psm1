# ToDo : Module comment-based help

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

# --- Re-export mode: ATAP.Utilities.Security.Secrets.PowerShell -------------------------
# The six Bitwarden functions and their three aliases moved to the Secrets child
# (Sprint 0012 Task 12.55.b). The umbrella imports the child into its own module scope and
# re-exports those names, so existing consumers that import only this module see an
# unchanged command surface. Maintained as one per-group list, not per-function proxies.
# Remove when the umbrella is thinned (plan Task 6.1).
$secretsChildName = 'ATAP.Utilities.Security.Secrets.PowerShell'
$secretsChildFunctions = @(
    'Get-BitWardenCredential'
    'List-BitwardenSecrets'
    'Load-BitwardenBackup'
    'New-BitwardenBackup'
    'Set-BitWardenSecret'
    'Sync-BitWardenDedicatedSecrets'
)
$secretsChildAliases = @(
    'New-BWSecret'
    'Add-BitWardenLogin'
    'Sync-DedicatedSecrets'
)

# Prefer the installed child from PSModulePath; fall back to the sibling source tree so the
# umbrella still imports when running from source (the child is not yet published).
$secretsChildSourceManifest = Join-Path $PSScriptRoot ".." $secretsChildName "$secretsChildName.psd1"
if (Get-Module -ListAvailable -Name $secretsChildName -ErrorAction SilentlyContinue) {
    Import-Module -Name $secretsChildName -ErrorAction Stop
} elseif (Test-Path -LiteralPath $secretsChildSourceManifest) {
    Import-Module -Name $secretsChildSourceManifest -ErrorAction Stop
} else {
    throw "Required child module '$secretsChildName' was not found on PSModulePath or at '$secretsChildSourceManifest'."
}

# This module previously had no Export-ModuleMember, so every dot-sourced function was a
# module member and .psd1 FunctionsToExport did the filtering. Calling Export-ModuleMember
# at all makes it authoritative, so the umbrella's OWN public functions must be listed here
# too or they would silently disappear from the command surface.
$ownFunctions = @($publicFunctions | ForEach-Object { $_.BaseName })

Export-ModuleMember -Function ($ownFunctions + $secretsChildFunctions) -Alias $secretsChildAliases
