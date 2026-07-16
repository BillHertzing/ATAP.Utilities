# ToDo : Module comment-based help

# get the fileIO info for each file in the lib, public, and private subdirectories.
# lib/ holds type-definition files (guarded Add-Type, no functions); it is dot-sourced
# first so C# types are loaded before the functions that reference them in param() blocks.
$libPath = Join-Path -Path $PSScriptRoot -ChildPath 'lib'
# @( ) wraps the whole if-expression: assignment from an if unwraps a one-element
# array to a scalar, which breaks the array concatenation below (Task 12.28 bug family)
$libFiles = @(if (Test-Path -LiteralPath $libPath -PathType Container) {
    Get-ChildItem -Path (Join-Path -Path $libPath -ChildPath '*.ps1') -ErrorAction SilentlyContinue
})
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue)

$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'private'
$privateFunctions = @(if (Test-Path -LiteralPath $privatePath -PathType Container) {
    Get-ChildItem -Path (Join-Path -Path $privatePath -ChildPath '*.ps1') -ErrorAction SilentlyContinue
})
$allFunctions = $libFiles + $publicFunctions + $privateFunctions
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
