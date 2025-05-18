# Deep Dive on Building Modules and Publishing to Powershell Package Repositories

## Overview

SoftwarePackage repositories are a critically important part of the build tooling. SoftwarePackage repositories are the source for production SoftwarePackages used by all computers in an Enterprise. SoftwarePackage repositories are also the destinations of Powershell SoftwarePackages that are created by the Enterprise. There is a clear distinction between internal SoftwarePackage PackageRepositories and external SoftwarePackage PackageRepositories.

## Software Versions

The ATAP.Utilities identify the following steps in producing the new version of an enterprise's SoftwarePackageS: Alpha, Beta, QualityAssurance, ReleaseCandidate and Production. When versioning the software and SoftwarePackages, Alpha, Beta, QualityAssurance, ReleaseCandidate are all prerelease versions, with Production being the released version.

## SoftwarePackages

A SoftwarePackage is a related set of software products (files) that can be installed into a computer. There are only two types of SoftwarePackages released with a software product: a QualityAssurance SoftwarePackage and a Production SoftwarePackage. The Production SoftwarePackage for a final version includes all the files necessary to install the SoftwarePackage and make it useful, while the QualityAssurance SoftwarePackage also includes tests that an end user of the SoftwarePackage could chose to run to validate the functionality of the SoftwarePackage. There is no need of a Development SoftwarePackage type, as development is done on a DevOps's machine, and (usually) tracked by Git or a similar product. Installation of a development version on a DevOps machine is usually done with a `git clone` command

## Repositories and Repository Provider software

PackageRepository is usually the term used for the physical computer / cloud that stores SoftwarePackages. The physical machine runs software that provides the features that allow for the storage, indexing, searching, and upload /download of the SoftwarePackages. ATAP.Utilities supports the following providers: Filesystem; NuGet, PowershellGet, ChocolateyGet, and ChocolateyCLI.

## SoftwarePackages, Repositories, and Providers

QualityAssurance and Production SoftwarePackages are distributed (pushed) to repositories, usually via the provider running on the repository. Filesystem providers do not require active provider software, just access to a location on the filesystem. The NuGet, PowershellGet, ChocolateyGet, providers provide endpoints defined as Universal Resource Locators (URIs) and specific API protocols to accept SoftwarePackages pushed to them.

## External Package Repositories

External package repositories are public-facing repositories. The purpose of the external SoftwarePackage repositories is twofold. They are the authoritative source of third-party SoftwarePackages. External SoftwarePackages are validated as part of the software BOM security validation process and are then moved to the internal package repositories. The second purpose of the external tax repositories is to be a location to which the Enterprise pushes its quality assurance and production SoftwarePackages to make them available to the public

## Internal package Repositories

Internal package repositories are intranet facing repositories that the enterprise accesses from its internal computers via an enterprise's Intranet.

SoftwarePackages developed by the enterprise are pushed to the enterprise's internal production package repositories. Both the QualityAssurance and the Production versions of a SoftwarePackage are pushed, and then pulled and tested, to ensure that both packaging, delivery, and retrieval work as expected.

Internal package repositories are themselves participants in a lifecycle. The repository software undergoes periodic maintenance and release, so an enterprise will need to stand up Development and QualityAssurance versions of the repository software, to ensure that updates to these PackageRepositories do not break the package delivery automation

Package repositories may have a common URI for both uploading and downloading SoftwarePackages, or they may have separate URIs (usually different port numbers) for uploading and for downloading.

## SoftwarePackage formats

A SoftwarePackage is a collection of files that have been compressed (zipped) into a single archive file given the `.nupkg` file extension. All PackageProviders expect to find a `.nuspec` file inside a `.nupkg` file . This file provides meta-information about the SoftwarePackage. While much of the contents of the `.nuspec` file is common across all PackageProviders, there are a few tricky differences (see TBD). The `.nuSpec` file, along with the directory structure of and contents of the rest of the files that make up the SoftwarePackage, are organized in a way specific to each provider,

### SoftwarePackage structure for Filesystem providers

ToDo: replace the crude line drawings below with a better graphic
|
| `.nuspec` (metadata including version number and possibly pre-release information)
| `ReadMe.md`
-- `ModuleName.psd1`
-- `ModuleName.psm1`
-- `lib` (optional)
---- `.dll` (compiled assemblies suitable for any version of DotNet)
---- `runtimes` (also optional, as are the specific subdirectories below this)
------ `win-x64` (Run Time Identifier (RID) for Windows
-------- ```.dll` (assemblies compiled specifically for a particular RID)

------ `linux` (Run Time Identifier (RID) for Linux
-------- ```.dll` (assemblies compiled specifically for a particular RID)

------ `MacOS` (Run Time Identifier (RID) for MacOS
-------- ```.dll` (assemblies compiled specifically for a particular RID)

### SoftwarePackage structure for NuGet providers

Same as SoftwarePackage structure for Filesystem providers

### SoftwarePackage structure for PowershellGet providers

### SoftwarePackage structure for ChocolateyGet and ChocolateyCLI providers

Starting with the same SoftwarePackage structure for Filesystem providers, the SoftwarePackage must also include a direcotry `tools`
|- `/tools`
| `ChocolateyInstall.ps1`
| `ChocolateyUninstall.ps1` (optional)

#### Identifiable concepts:

Repository <-> 'API Endpoint' or 'Filesystem'

Repository attributes:
internal or external
Prerelease or released
push or pull

SoftwarePackage -> 'The file ending in .nupkg' -(contains) 'the organization of and content of the software within the SoftwarePackage including the `.nuspec` `

Version -> stored inside the `.nuspec` file. The presence of a non-null prerelease value in an existing prerelease field of the nuspec indicates a prerelease version., The absence of such a value indicated a released version

'SoftwarePackageType' -> There are two types of SoftwarePackages for each version of the SoftwarePackage, the 'QualityAssurance' type and the 'Production' type

'PackageVersion Lifecycle' -> Prerelease (alpha, beta, QualityAssurance (QA), ReleaseCandidate (RC)) -> Released

PackageProvider (FileSystem, NuGet, PowershellGet, ChocolateyGet, ChocolateyCLI)
SoftwarePackageType (QualityAssurance / Production)
SoftwareLifeCycle(Prerelease or Released)

Build:

- Copy all static to intermediate (include `./lib`, `./Documentation`, `./Resources`)
- Create Readme and ReleaseNotes
- copy existing manifest (.psd1)
- assign a 'Package Version Lifecycle' based on manifest
- assign 'Prelease' or 'released" (or use a function that accepts a version and returns an enumeration value)
- generate the module file from the individual functions
- generate dependency information from the module file and from existing manifest (SWBOM documentation and update manifest)
- generate Help for functions (platypus), update functions inline help, generate help files
- generate API documentation (Postman)
- generate static site documentation (FxDoc)
- update the ReadMe and ReleaseNotes (make release notes from commit messages)

Test:

- run all tests and create test reports
- if 'Package Version Lifecycle' is RC or Released
- - validate tests passed percentage exceeds some configurable percentage
- - validate test coverage percentage exceeds some configurable percentage
- update ReadeMe.md and ReleaseNotes.md with test results and test coverage

Package:

- identify the packageproviders for which SoftwarePackages will be made
- identify the number of unique SoftwarePackages (content and organization) which will need to be created
- (a) create the QA and production packaging structures and `.nuspec` file for the simplest packageprovider ('FilesystemGet' and NuGet package (supports alphanumeric prerelease versions (hyphens only)) in the `.nuspec`)
- (b) pack both the QA and production packages for FilesystemGet NuGet
- (c) generate a SHA256 hash for the QA and production `.nupkg` and record it
- repeat steps (a) and (b) and (c) for NuGet packageprovider
- repeat steps (a) and (b) and (c) for PowershellGet packageprovider (TBD - investigate limitations on prerelease version in PowershellGet)
- repeat steps (a) for ChocolateyGet packageprovider (TBD - investigate limitations on prerelease version in ChocolateyGet)
- - add the `tools` directory and `ChocolateyInstall.ps1` and `ChocolateyUninstall.ps1` files
- repeat steps (b) for ChocolateyGet packageprovider (TBD - investigate limitations on prerelease version in ChocolateyGet)
- repeat step (c) for the Ch

Hash the `.nupkg`: (for Build traceability)

TBD (what to do with the `.nupkg.sha256` file? publish it )

Sign: (for distribution integrity)

Publish:

- identify the PackageRepositories to which packages will be published
- starting with internal repositories
- - in order from least complex to most complex, publish the packages and record the results
- - - FilesystemGet - write both packages.
- - - - prereleaseQA to 'PackageRepositoryInternalPrereleaseFilesystemQAPath' (a filesystem URI)
- - - - prereleaseProduction to 'InternalPrereleaseFilesystemProductionPath (a filesystem URI)
- - - - ReleasedQA to 'InternalReleasedFilesystemQAPath' (a filesystem URI)
- - - - ReleasedProduction to 'InternalReleasedFilesystemProductionPath (a filesystem URI)
- - - NuGet - write both packages.
- - - - prereleaseQA to 'InternalPrereleaseNuGetQAPushUri' (a httpd URI)
- - - - prereleaseProduction to 'InternalPrereleaseNuGetProductionPushUri (a httpd URI)
- - - - ReleasedQA to 'InternalReleasedNuGetQAPushUri' (a httpd URI)
- - - - ReleasedProduction to 'InternalReleasedNuGetProductionPushUri(a httpd URI)
- - - PowershellGet - write both packages.
- - - - prereleaseQA to 'InternalPrereleasePowershellGetQAPushUri' (a httpd URI)
- - - - prereleaseProduction to 'InternalPrereleasePowershellGetProductionPushUri (a httpd URI)
- - - - ReleasedQA to 'InternalReleasedPowershellGetQAPushUri' (a httpd URI)
- - - - ReleasedProduction to 'InternalReleasedPowershellGetProductionPushUri(a httpd URI)
- - - ChocolateyGet - write both packages. QA to TBD, production to TBD
- - - - prereleaseQA to 'InternalPrereleaseChocolateyGetQAPushUri' (a httpd URI)
- - - - prereleaseProduction to 'InternalPrereleaseChocolateyGetProductionPushUri (a httpd URI)
- - - - ReleasedQA to 'InternalReleasedChocolateyGetQAPushUri' (a httpd URI)
- - - - ReleasedProduction to 'InternalReleasedChocolateyGetProductionPushUri(a httpd URI)

going on to external repositories

- Create scripts (or one-liners) that will publish to external repositories
- - PowershellGet
- - - prereleaseQA to 'ExternalPrereleasePowershellGetQAPushUri' (a httpd URI for external early access users)
- - - prereleaseProduction to 'ExternalPrereleasePowershellGetProductionPushUri (a httpd URI for external early access users)
- - - ReleasedQA to 'ExternalReleasedPowershellGetQAPushUri' (a httpd URI to the push api for the Powershell gallery)
- - - ReleasedProduction to 'ExternalReleasedPowershellGetProductionPushUri' (a httpd URI to the push api for the Powershell gallery)
- - ChocolateyGet
- - - prereleaseQA to 'ExternalPrereleaseChocolateyGetQAPushUri' (a httpd URI to the push api for the public Chocolatey server (for prerelease packages))
- - - prereleaseProduction to 'ExternalPrereleaseChocolateyGetProductionPushUri (a httpd URI for the public Chocolatey server (for prerelease packages))
- - - ReleasedQA to 'ExternalReleasedChocolateyGetQAPushUri' (a httpd URI to the push api for the public Chocolatey server (for Released packages))
- - - ReleasedProduction to 'ExternalReleasedChocolateyGetProductionPushUri(a httpd URI to the push api for public Chocolatey server (for Released packages))

  e-mail to users that have the role 'ExternalPublicationsReleaser' and are assigned to the subproject
  the scripts along with the test reports and instructions how to use the sripts to push the packages externally

Validate:

- identify the repositories to which packages have been published by reviewing the publishing results
- starting with internal repositories
- - in order from least complex to most complex, validate the packages
- - FilesystemGet
- - - read both packages.
- - - - prereleaseQA from 'InternalPrereleaseFilesystemQAPath' (a filesystem URI)
- - - - prereleaseProduction from 'InternalPrereleaseFilesystemProductionPath (a filesystem URI)
- - - - ReleasedQA from 'InternalReleasedFilesystemQAPath' (a filesystem URI)
- - - - ReleasedProduction from 'InternalReleasedFilesystemProductionPath (a filesystem URI)
- - - Verify signing
- - - Verify Hash
- - NuGet
- - - read both packages.
- - - - prereleaseQA to 'InternalPrereleaseNuGetQAPullUri' (a httpd URI)
- - - - prereleaseProduction to 'InternalPrereleaseNuGetProductionPullUri (a httpd URI)
- - - - ReleasedQA to 'InternalReleasedNuGetQAPullUri' (a httpd URI)
- - - - ReleasedProduction to 'InternalReleasedNuGetProductionPullUri(a httpd URI)
- - - Verify signing
- - - Verify Hash
- - PowerShellGet
- - - read both packages.
- - - - prereleaseQA to 'InternalPrereleasePowerShellGetQAPullUri' (a httpd URI)
- - - - prereleaseProduction to 'InternalPrereleasePowerShellGetProductionPullUri (a httpd URI)
- - - - ReleasedQA to 'InternalReleasedPowerShellGetQAPullUri' (a httpd URI)
- - - - ReleasedProduction to 'InternalReleasedPowerShellGetProductionPullUri(a httpd URI)
- - - Verify signing
- - - Verify Hash
- - ChocolateyGet
- - - read both packages.
- - - - prereleaseQA to 'InternalPrereleaseChocolateyGetQAPullUri' (a httpd URI)
- - - - prereleaseProduction to 'InternalPrereleaseChocolateyGetProductionPullUri (a httpd URI)
- - - - ReleasedQA to 'InternalReleasedChocolateyGetQAPullUri' (a httpd URI)
- - - - ReleasedProduction to 'InternalReleasedChocolateyGetProductionPullUri(a httpd URI)
- - - Verify signing
- - - Verify Hash

# ToDo: Finish steps of pull and validate...

## Summary of publishing destination endpoints

InternalPrereleaseFilesystemQAPath
InternalPrereleaseFilesystemProductionPath
InternalReleasedFilesystemQAPath
InternalReleasedFilesystemProductionPath
InternalPrereleaseNuGetQAPushUri
InternalPrereleaseNuGetProductionPushUri
InternalReleasedNuGetQAPushUri
InternalReleasedNuGetProductionPushUri
InternalPrereleasePowershellGetQAPushUri
InternalPrereleasePowershellGetProductionPushUri
InternalReleasedPowershellGetQAPushUri
InternalReleasedPowershellGetProductionPushUri
InternalPrereleaseChocolateyGetQAPushUri
InternalPrereleaseChocolateyGetProductionPushUri
InternalReleasedChocolateyGetQAPushUri
InternalReleasedChocolateyGetProductionPushUri
ExternalPrereleasePowershellGetQAPushUri
ExternalPrereleasePowershellGetProductionPushUri
ExternalReleasedPowershellGetQAPushUri
ExternalReleasedPowershellGetProductionPushUri
ExternalPrereleaseChocolateyGetQAPushUri
ExternalPrereleaseChocolateyGetProductionPushUri
ExternalReleasedChocolateyGetQAPushUri
ExternalReleasedChocolateyGetProductionPushUri

## Summary of pulling (fetching) destination endpoints

These identifiers are formed as follows
Common Prefix = PackageRepository
Internal (to the enterprise = Trusted and External (may be trusted for downloading, but not as a source for internal enterprise use))
Prerelease or Released
PackageProvider (Filesystem, NuGet, PowershellGet, ChocolateyGet)
SoftwarePackageType (QualityAssurance or Production)

FullKey consists of
'PackageRepository' + ('External' |'Internal' ) + ('Released' | 'Prerelease') + ('Filesystem' | 'NuGet' | 'PowershellGet' | 'ChocolateyGet') + ('Production' | 'QualityAssurance')

- `$global:configRootKeys['PackageRepositoryExternalReleasedNuGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriConfigRootKey']`
- `$global:configRootKeys['PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriConfigRootKey']`
- `$global:configRootKeys['PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriConfigRootKey']`
- `$global:configRootKeys['PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriConfigRootKey']`
- `$global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedFilesystemProductionPackagePathNameConfigRootKey']`
- `$global:configRootKeys['PackageRepositoryInternalReleasedFilesystemQualityAssurancePackagePathNameConfigRootKey']`

'PackageRepositoryInternalReleasedFilesystemProductionPackagePathNameConfigRootKey'
'PackageRepositoryInternalReleasedFilesystemQualityAssurancePackagePathNameConfigRootKey'
