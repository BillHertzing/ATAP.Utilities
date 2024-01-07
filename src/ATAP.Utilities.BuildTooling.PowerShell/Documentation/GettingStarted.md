# Powershell module and scripts for building code and blogs

## Blog Post Image Pipeline

[Set hosting solution variables]
[Set media Queries parameters]
[Define cache and persistent storage of the dropboxlinks created by this process]

[paramters 'original file location, hosting solution's Blog Post Images location manifestation in a locally-accessable location]

Create List of file names in the hosting solution's Blog Post Images location manifestation

map transform {list of unique filenames sans `\(\d+). iterate this list
  identify the latest copy of each basename in the , compare to latest dropboxlinks in cache/persistent storage. identify discrepancies. remove all others with the same basename. report discrepancies
  rename the latest writetime to the base name
  copy attributes from the original to the latest copy
  remove ppi attributes
  iterate for number of mediaquerys needed
    create copies based on the width and height attributes, and the mediaquery parameter set's needs
    run the original through the VIP lib to resize it, and store the new image in a filename that follows the mediaquery convention for 'small', 'tablet', 'desktop', ...
  }
  Create a new sharing dropboxlink for each file that does not yet have a sharing link.
  Update the cache and persistent storage of dropboxlinks
  Create the list of links and report it
  Create the Gallery code block to incorporate into the YAML section of the blog post


## Diff-BlogImageList

## Get-ModuleAsSymbolicLink

## Rename-FilesDuplicatedAndMoved

## Copy-AttributesOfOther Files

## Build-ImageFromPlantUML.ps1


## Packaging, Testing, and Deploying powershell modules

### Development

ToDo: Insert UML or draw.io source code for creation of documentation image, for powershell Module layout on development computer

ToDo: Insert UML or draw.io source for creation of documentation image, for process flow for Module development, testing, and deployment

 -- RepositoryRoot/src/ModuleName/
   -- ModuleName.psd1
   -- ModuleName.psm1 (just dot-sources all files listed in public and private)
   -- ModuleName.pssproj
   -- public/
   --   script1.ps1
   -- private/
   --   script2.ps1
   -- types/
   -- formats/
   -- resources/

Using VSC and Ironman Pro Tools:

Create a build task for Powershell modules in VSC that will do the following:

 Create new module project from template (Plaster?)

  The .psd1 file from the template should have a nested section `['PSData']['PrivateData']['Prerelease']`, and the value should be `alpha001`

  Developer process:
  running "build (tbd??)" on the developer computer in the module directory should

   (if the prerelease version string -matches `'alpha'`)
    update the prerelease version string in the manifest (`.psd1`) file
    create a nuget package
    deploy the nuget package to a local fileshare (directory)
    Create a chocolatey package
    deploy the chocolatey package to a local chocolatey server
    run the unit tests (RepositoryRoot/tests/ModuleName.UnitTests/)
    Create test report
   (if the prerelease version string -matches `'beta'`)
    do all the steps for the `alpha` lifecycle stage
    run the integration tests (RepositoryRoot/tests/ModuleName.IntegrationTests/)
    Create test report
   (if the prerelease version string -matches `'RC'`)
    do all the steps for the `Beta` lifecycle stage
    run the PreRelease Deployment action
      upload the NuGet package to a prerelease NuGet server like MyGet
      upload the Chocolatey package to the Chocolatey.org server, but marked as a prerelease

  CI/CD Process:
  The CI/CD process occurs when a commit occurs in a Git-managed repository on a local computer.
  The ATAP repositories use Jenkins for the CI/CD processing
  Check-in any preproduction version of the module:
    Jenkins updates the preproduction string in the .psd1
    Jenkins runs all Unit and Integration tests per lifecycle stage
    Jenkins creates the Nuget and Chocolatey packages
    Jenkins deploys the prerelease packages to the local Nuget and chocolatey servers
  Pull Request (PR) to a local repository having a Production version of the module
    do all the steps for the `Beta` lifecycle stage
  Pull Request (PR) to merge local repository having a Production version of the module with the remote
    run the Release Deployment action
      upload the NuGet package to NuGet.org
      upload the Chocolatey package to Chocolatey.org
    update badges and info on the GitHub page


### Powershell module packaging and delivery

The powershell package providers supported by the ATAP.Utilities Powershell build tooling include

* PowerShell Gallery
* Nuget
* Chocolatey

Delivery to each powershell package provider needs to be supported and tested. This means that both developer machines and the CI/CD pipeline need to understand development and testing delivery.

The `invoke-build` script reads the module.build.ps1 file. In the module.build.ps1 file paths are created per-host that are based on the $global:Settings hash, specifically
```Powershell
 $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingDirectory']]
 $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingSourceDirectory']]
 $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingIntermediateDirectory']]
 $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingDistributionPackagesDirectory']]
```
 From these base locations, subdirectories are created for each powershell package provider, and below those, further subdirectories are created for each LifeCycle phase

 In each of these provider-lifecycle subdirectories, the module source files are created, the .nuspec file is created, and the .nupkg file is created


## PowerShell Gallery

Testing the PowerShell Gallery package provider should test delivery to a file system location, a local NuGet server, and a local PowerShell Gallery server, in increasing order of complexity.

### PowerShell Gallery Filesystem development and test respoitory

The PowerShell Gallery Filesystem development and test respoitory is a file system location on a developer machine and a CI/CD pipeline machine, that is a trusted location for the PowerShell Gallery package provider.

For each developer machine and CI/CD pipeline machine define an intermediate location to which the

  NOTE that the text below this line to end of file is obsolete 
TBD - replace with current information
During the build pipeline, copy the `ModuleName.psd1` and the `ModuleName.psm1` files to `_generated\Packages\PowerShell GalleryPackageSource\ModuleName`

Define the Filesystem location, per machine and user, for the Development PowerShellGallery repository. Define this in the globals. for example `"C:/Dropbox/Repositories/[Nuget|PowershellGet|Chocolatey]/DevelopmentPackages"`

Define a name for the filesystem development PowerShellGallery repository. define this in the globals. For example `DevelopmentFilesystemPowershellGalleryRepository `

during the build,

1. Ensure that PowerShellGet is a registered package provider (should be builtin and default), running `Get-PackageProvider` should return an entry whose names is `PowerShellGet`
1. Ensure that the filesystem location exists. for example `//utat022/FS/PowerShell GalleryFileRepository
1. Ensure that the filesystem location is a trusted PSRepository. Run the command `Set-PSRepository -Name "DevelopmentFilesystemPowershellGalleryRepository"   -InstallationPolicy Trusted -SourceLocation "\\utat022\fs\DevelopmentPackages"`
1. Deliver the new module/version to the filesystem development PowerShellGallery repository. Run the command `Publish-Module -Path "_generated\Packages\PowerShell GalleryPackageSource\ModuleName" -Repository DevelopmentFilesystemPowershellGalleryRepository -NuGetApiKey 'any'`
1. Ensure that the new module/version is available. run the command `Find-Module -Name ATAP.Utilities.BuildTooling.PowerShell`. Ensure that the name, version, and repository fields returned by the command match the expected values.
1. Install the new module or new version into the current user's scope
1. Run the tests using the newly installed module/version


### Create a subdirectory under _generated for the source of the PowerShell Gallery module


