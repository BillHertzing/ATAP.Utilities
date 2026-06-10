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

# Command aliases (relocated here from the eponymous public function files so those
# files only DEFINE functions and execute nothing at load time). Created in module
# scope at import, exactly as the dot-sourced Set-Alias calls did before. Export is
# still governed by AliasesToExport in the .psd1 (currently @() = module-internal).
Set-Alias -Name New-BWSecret          -Value Set-BitWardenSecret
Set-Alias -Name Add-BitWardenLogin    -Value Set-BitWardenSecret
Set-Alias -Name Sync-DedicatedSecrets -Value Sync-BitWardenDedicatedSecrets
