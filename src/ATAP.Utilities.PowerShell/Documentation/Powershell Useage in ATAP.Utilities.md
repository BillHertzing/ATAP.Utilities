# Powershell Useage in ATAP.Utilities

## OVerview of this document

powershell is widelyused in the delivered ATAP.Utility packages, both as libraries of functions and cmdlets that cna be utilized in end-user software, and as build tooling used to creeate the developer and CI experience. This document outlines many of the conventions used in developing the Powershell packages and tools

## Powershell Desktop (currently V5) vs Powershell Core (currently V7)

Mostly written for V7 Cross-platform

## Settings

## Join-Path instead of path strings

## [Environment]::Get-EnvironmentVariable instead of $env

## Out-File instead of Get-Content

`Out-File` is the preferred (ATAP.Utilities opinionated) way of writing data to a file, mostly because of the difference in Read and Write locking. `Out-File` will not lock the output file, whereas `Get-Content` does lock it. The two use different encodings by default. Intermixing them, while unfortunate, is inevitable. If we set the encoding explicitly, they will "play better together".

[PowerShell Set-Content and Out-File - what is the difference?](https://stackoverflow.com/questions/10655788/powershell-set-content-and-out-file-what-is-the-difference)

### Encoding in the ATAP.Utilities Cmdlets

[Understanding Character Encoding in PowerShell](https://petri.com/understanding-character-encoding-in-powershell/)

ToDo: Provide the Paramater `-Encoding` in all ATAP.Utilities Cmdlets that read or write files

ToDo: Investigate the use of the Paramater `-Encoding` in all ATAP.Utilities Cmdlets that send to or read strings from external programs.

## Default Encoding for all Cmdlets

Lots of great information here:
[Changing PowerShell's default output encoding to UTF-8](https://stackoverflow.com/questions/40098771/changing-powershells-default-output-encoding-to-utf-8)
[Using PowerShell to write a file in UTF-8 without the BOM](https://stackoverflow.com/questions/5596982/using-powershell-to-write-a-file-in-utf-8-without-the-bom)

### Default Encoding for all Cmdlets in Powershell Core

This will apply to all Cmdlets that support the -Encoding parameter. Place this line in the machine profile. It will affect all users of the machine and their scripts. Test it before releasing to production. It ensures that files and strings in the ATAP libraries will have the same encoding.

`$PSDefaultParameterValues = @{ '*:Encoding' = 'utf8' }`  # ToDo: Benchmark the `'*'` vs a large list of specific Cmdlet names. `'*'` may be much longer....

### Default Encoding for all Cmdlets in Powershell Desktop

Very Complicated, See the prior citations and related body of work.. ToDo: investigate and resolve for PS V5.1

## Cross-Platform Environment variables

### Host vs Hostname vs computername

In the machine profile, we can setup a global variable using the .Net DNS name resolution library, and then assign all three environment variables (at a process scope) to the the same string.
`$hostName = ([System.Net.DNS]::GetHostByName($Null)).Hostname`

## Using classes defined in Powershell Modiles

Since the ATAP.Utilities repository contains a robust CI pipeline, it is very feasible to write the classes and enumerations in C# and targeting .Net (cross-platform), compile them to a .dll, and include them in a package. That way, other modules that want to work with the same classes and enumerations can simply include the .dlls exported by the module. (ToDo: Check this works as explained.  Also ToDo: Versioning the enumerations )

The following two seemed a good idea, but the work has languished.

[How to write Powershell modules with classes](https://stephanevg.github.io/powershell/class/module/DATA-How-To-Write-powershell-Modules-with-classes/)

[PSClassUtils](https://github.com/Stephanevg/PSClassUtils)


## ATAP.Utilities Powershell Package structure

Package structure hasa lot to do with the intention. A Production Package for a library, executable, or Script Module should have the stuff, and metadatat about the stuff. The ATAP.Utilities Packages also contain resources, installation tools, and authentication information. Testing packages include the production stuff, a version of stuff with tracing enabled, and a bunch of tests, and test results, test coverage, test benchmarks, and complexity metrics from the CI/CD run that built the package. There may be multiple Testing packages for a production package. A small library may have a single test package, while a large application or library may have e.g. Unittest, Integrationtest, BrowserTests, Databasetest etc. There may also be variations for each supported technology/platform/version.  Development packages include everything in the Production and all the Tests packages, along with things like debug symbols, Source Code pointers, development scripts etc.


## Using LINQ with PowershellFormat-GroupLikeLines

For getting the distinct elements of a collection, based on a simple comparasion of the objects

[Linq.Enumerable]::Distinct([string[]]@('a', 'a', 'b'))

For getting a unique subset of a collection based on the values of a property of the objects in a collection, LINQ DistinctBy is the fastest way (..NET Core)

### More stuff on LINQ in Powershell

[PowershellLINQSupport.cs](https://gist.github.com/jeremybeavon/fdb603ba4dfb19a1b40c)
[.NET Action, Func, Delegate, Lambda expression in PowerShell](https://www.reza-aghaei.com/net-action-func-delegate-lambda-expression-in-powershell/)

## Update the Packagemanagement module

[When PowerShellGet v1 fails to install the NuGet Provider](https://devblogs.microsoft.com/powershell/when-powershellget-v1-fails-to-install-the-nuget-provider/)
[PackageManagement 1.1.0.0](https://www.powershellgallery.com/packages/PackageManagement/1.1.0.0)

Upgrade package management.
Prerequisite is `Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force`
then
`Install-Module -Name PackageManagement -RequiredVersion 1.1.0.0`  Because version 1.0.0.1 will not use TLS 1.2, and that is required to use PowerShellGet

When using powershell Core, Note that if the path to the Powershell Desktop modules appear in the $ENV:PsModulePath before the path to the Powershell Core modules, then package management powershell commands will not work, The Desktop path contains a much older version of the PackageManagement module, one which does not use TLS 1.2

## Logging

Use PSFramework for logging
use the gelf logging provider configured as follows:

```Powershell
# ToDo: adding protocol = 'udp'; produces the error "A parameter cannot be found that matches parameter name 'protocol'."
# ToDo:   since UDP is the default protocol this is not an issue. But both of these command swork correctly
# ToDo:     Set-PSFConfig 'PSFramework.logging.gelf.protocol' 'udp'
# ToDo:     Get-PSFConfig 'PSFramework.logging.gelf.protocol'  - return 'udp'
$gelfLoggingProviderConfiguration =  @{Name='gelf'; instanceName = 'default'; GelfServer = '127.0.0.1'; port = 12201; Encrypt=$false; minlevel=1; maxlevel=9; Enabled=$true;Verbose=$true}
Set-PSFLoggingProvider @gelfLoggingProviderConfiguration
# Then explicitly initialize it
$null = Wait-PSFMessage -Timeout 1
# see if it has been initialized
Get-PSFLoggingProvider -Name gelf
```
or

```Powershell
Set-PSFLoggingProvider -Name 'gelf' -Enabled $false -Verbose
set-psfconfig 'LoggingProvider.gelf.AutoInstall' $true
get-psfconfig 'LoggingProvider.gelf.AutoInstall'
set-psfconfig 'PSFramework.Logging.gelf.encrypt' $false
get-psfconfig 'PSFramework.Logging.gelf.encrypt'
set-psfconfig 'PSFramework.Logging.gelf.gelfserver' '127.0.0.1'
get-psfconfig 'PSFramework.Logging.gelf.gelfserver'
set-psfconfig 'PSFramework.Logging.GELF.Port' '12201'
get-psfconfig 'PSFramework.Logging.GELF.port'
Set-PSFConfig 'PSFramework.logging.gelf.protocol' 'udp'
Get-PSFConfig 'PSFramework.logging.gelf.protocol'
set-psfconfig 'PSFramework.Logging.gelf.verbose' $true
get-psfconfig 'PSFramework.Logging.gelf.verbose'
set-psfconfig 'PSFramework.Logging.gelf.minlevel' 0
get-psfconfig 'PSFramework.Logging.gelf.minlevel'
set-psfconfig 'PSFramework.Logging.gelf.maxlevel' 9
get-psfconfig 'PSFramework.Logging.gelf.maxlevel'
set-psfconfig 'LoggingProvider.gelf.enabled' $true
get-psfconfig 'LoggingProvider.gelf.enabled'
Set-PSFLoggingProvider -Name 'gelf' -Enabled $true -Verbose
# Then explicitly initialize it
$null = Wait-PSFMessage -Timeout 1
# see if it has been initialized
Get-PSFLoggingProvider -Name gelf
Write-PSFMessage -Level Debug -Message "Testing Write-PFSMessage to GelfServer"
```
Get-PSFConfig 'PSFramework.Logging.Console.MinLevel'
Get-PSFConfig 'PSFramework.Logging.Console.MaxLevel'
Get-PSFConfig  'LoggingProvider.Console.enabled'
Get-PSFConfig 'PSFramework.Logging.Filesystem.MinLevel'
Get-PSFConfig 'PSFramework.Logging.Filesystem.MaxLevel'
Get-PSFConfig  'LoggingProvider.Filesystem.enabled'

use SEQ to listen for gelf formated messages on udp://127.0.0.1:12201

or this:
``` powerShell
# ToDo: variable instance name (?)
$gelfLoggingProviderConfiguration =  @{Name='gelf';instanceName='powerShellScriptXYZ'; gelfserver= 'localhost'; port=12201;Enabled=$true;Encrypt=$false}
Set-PSFLoggingProvider @gelfLoggingProviderConfiguration
```
