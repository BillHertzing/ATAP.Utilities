# ToDo : Module comment-based help

# Get the file information for each file in the public and optional private
# subdirectories. This module currently has no private implementation folder;
# guard the lookup so a normal Import-Module does not fail on that absence.
$publicPath = Join-Path $PSScriptRoot 'public'
$privatePath = Join-Path $PSScriptRoot 'private'
$publicFunctions = @(if (Test-Path -LiteralPath $publicPath -PathType Container) { Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' -File })
$privateFunctions = @(if (Test-Path -LiteralPath $privatePath -PathType Container) { Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1' -File })
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
# list the public functions names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)
# list the private cmdlet names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)
