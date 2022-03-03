
# ATAP.Utilities.BuildTooling.PowerShell

If you are viewing this `ReadMe.md` in GitHub, [here is this same ReadMe on the documentation site]()
## Introduction

This package provides PowerShell goodies make it easier when developing for .Net, and especially inside of Visual Studio.

## Autoloading

The .psm1 file handles dot-sourcing all the .ps1 scripts in the `private` and `public` subdirectories. But for Autoload to work, the functions and cmdlets should be listed in the .psd1 file. Here's a one-liner that will get you the function names

`   (gci C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\*.ps1).basename -join,"','"  `

## Building/Installation Note

Production versions of the modules goes through testing and packaging, along with deployment to a local chocolatey Repository Server, from which the new production version of the package is deployed using Chocolatey.

When developing new functions for the module, symbolic links make it easy to have the source development files linked to the production location of the module somewhere in the `$PSModulePath`, specifically in the user's Powershell modules directory. Doing so will ensure that the latest dev code is running when the module is autoloaded.

Work great, except... PowerShell will not autoload a symlinked .psd1 file. Its OK to symlink the .psm1 file, and the `public` and `private` subdirectories of the module, you just can't symlink the .psd1 file.

Cmdlets are found in their eponymous script files

### Get-ModulesForUserProfileAsSymbolicLinks

This function takes a module `$Name`, module `$Version`, and the `$sourcePath` to the root of the module's code. It creates a subdirectory under the user's Powershell modules' path (), for the module `$Name`, and under that a subdirectory for the `$Version`. In the `$Version` subdirectory, it creates three symbolic links, for `public` and `private`subdirectories, and the `$Name.psm1` file. It also copies any `$Name.psd1` files from the `$sourcePath` to the



