# This is the resource (template) version of the default build.ps1 file used by Invoke-Build throughout all ATAP.Utilities modules and libraries
# ToDo: figure out how to install the buildtooling powwershell module such that this file is found by default when invoke-build is run
# ToDo: until then use the following to link it (run this command in the powershell project's base subdirectroy)

 # Remove-Item -path (join-path '.' 'Module.Build.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path '.' 'Module.Build.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.Buildtooling.PowerShell' 'Resources' 'Module.Build.ps1')
 #[CmdletBinding(SupportsShouldProcess=$true)]
param(

    [ValidateSet('Debug', 'Production')]
    [string] $Configuration = 'Production'
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
    [string] $Encoding # Often found in the $PSDefaultParameterValues preference variable
)

Push-Location $PSScriptRoot

# The following are expected environment variables
$ModuleRoot = Join-Path 'C:' 'Dropbox' 'whertzing', 'GitHub'
$ModuleName = 'PlaygroundPowershellModule'
# CoverallsKey = $env:Coveralls_Key

# The following come from a Powershell Secrets vault
# NUGET_API = $env:NUGET_API

# All utility and helper functions needed to build Powershell modules can be found in the ATAP.Utilities.BuildTooling.Powershel;l module, which should be found in one of the directories listed in the $env:PSMModulePath
#  That module includes dependendcies on other modules,
# Include: build_utils, PFSMessage

# ToDo: make this the ATAP.Utilities.BuildTooling.Powershell module
#. './build.utilities.ps1'


$BuildRoot = Join-Path $ModuleRoot $ModuleName

$ManifestFilename = $ModuleName + '.psd1'
$ModuleFilename = $ModuleName + '.psm1'

# The following subdirectories are "opinionated"
$SourcePath = Join-Path $BuildRoot 'src'
$UnitTestsPath = Join-Path $BuildRoot $ModuleName 'tests'
$IntegrationTestsPath = Join-Path $BuildRoot $ModuleName 'IntegrationTests'

$ManifestCurrentPath = Join-Path $BuildRoot $($ModuleName + '.psd1')

# The locations for the final source code for packages destined for public powershell Repositories
$GeneratedPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedRelativePathConfigRootKey']]
$GeneratedModuleDestinationPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedPowershellModulesConfigRootKey']]
$GeneratedPowershellGalleryModulesPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedPowershellGalleryModulesConfigRootKey']]
$GeneratedNuGetPackageDestinationPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedPowershellNuGetModulesConfigRootKey']]
$GeneratedChocolateyPackageDestinationPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedPowershellChocolateyModulesConfigRootKey']]

# The locations for QualityAssurance output file
$GeneratedTestResultsPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedTestResultsPathConfigRootKey']]
$GeneratedUnitTestResultsPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']]
$GeneratedIntegrationTestResultsPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']]
$GeneratedTestCoverageResultsPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']]

# The locations for documentation output file
$GeneratedDocumentationDestinationPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']]
$GeneratedStaticSiteDocumentationDestinationPath = Join-Path '.' $settings[$global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']]

# The location for the final source code for the module and the module manifest
$ModuleOutputPath = Join-Path $GeneratedModuleDestinationPath $($ModuleName + '.psm1')
$ManifestOutputPath = Join-Path $GeneratedModuleDestinationPath $($ModuleName + '.psd1')

# The PSRepositories required for packages destined for public powershell Repositories
$RepositoryNamePowershellGalleryDevelopmentFilesystemName = $settings[$global:configRootKeys['RepositoryNamePowershellGalleryDevelopmentPackageFilesystemConfigRootKey']]

# The locations that contain files that need to be part of the module's package
$Imports = ( 'private', 'public', 'classes' )



$TestFile = "$PSScriptRoot\output\TestResults_PS$PSVersion`_$TimeStamp.xml"

# validate required input paths

if (-not $(Test-Path -Path $BuildRoot)) { throw "BuildRoot not found :  $BuildRoot" }
if (-not $(Test-Path -Path $SourcePath)) { throw "Source not found :  $SourcePath" }

# Vaidate or create required output paths
if (-not $(Test-Path -Path $GeneratedPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedPath }
if (-not $(Test-Path -Path $GeneratedModuleDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedModuleDestinationPath }
if (-not $(Test-Path -Path $GeneratedPowershellGalleryModulesPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedPowershellGalleryModulesPath }
if (-not $(Test-Path -Path $GeneratedNuGetPackageDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedNuGetPackageDestinationPath }
if (-not $(Test-Path -Path $GeneratedChocolateyPackageDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedChocolateyPackageDestinationPath }
if (-not $(Test-Path -Path $GeneratedTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedTestResultsPath }
if (-not $(Test-Path -Path $GeneratedUnitTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedUnitTestResultsPath }
if (-not $(Test-Path -Path $GeneratedIntegrationTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedIntegrationTestResultsPath }
if (-not $(Test-Path -Path $GeneratedTestCoverageResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedTestCoverageResultsPath }
if (-not $(Test-Path -Path $GeneratedDocumentationDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedDocumentationDestinationPath }
if (-not $(Test-Path -Path $GeneratedStaticSiteDocumentationDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedStaticSiteDocumentationDestinationPath }

# Validate the package repositories are mapped to filesystem locations or web server URLs
if (-not $(Get-PSRepository -Name  )){}
# validate required tools are present
# Pester
if (-not $(Get-Module -ListAvailable -Name 'Pester') ) { Throw 'pester Powershell module not found' }
# PlatyPS
if (-not $(Get-Module -ListAvailable -Name 'PlatyPS') ) { Throw 'PlatyPS Powershell module not found' }
# ATAP.Utilities.BuildTooling.Powershell
if (-not $(Get-Module -ListAvailable -Name 'ATAP.Utilities.BuildTooling.Powershell') ) { Throw 'ATAP.Utilities.BuildTooling.Powershell Powershell module not found' }
# DocFx
if (-not $(Get-Command -Name 'docfx.exe') ) { Throw 'docfx.exe not found' }
# Java executable
if (-not $(Get-Command -Name 'java.exe') ) { Throw 'java.exe not found' }
# Java libraries
# PlantUML

# In Debug mode, write the environment variables
Write-PSFMessage -Level Debug -Message ('Environment variables at start of PSModule.build.ps1' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented 2 2) + [Environment]::NewLine )

Task Clean {
    # clean the generated powershell module and the generated powershell metadata

    Remove-Item -Path $(Join-Path $GeneratedModuleDestinationPath '*.*')
    # Clean the Test Results
    Remove-Item -Path $(Join-Path $GeneratedTestResultsPath '*.*')
    Remove-Item -Path $(Join-Path $GeneratedUnitTestResultsPath '*.*')
    Remove-Item -Path $(Join-Path $GeneratedIntegrationTestResultsPath '*.*')
    Remove-Item -Path $(Join-Path $GeneratedTestCoverageResultsPath '*.*')
    # Clean the generated Documentation
    Remove-Item -Path $(Join-Path $GeneratedDocumentationDestinationPath '*.*')
    Remove-Item -Path $(Join-Path $GeneratedStaticSiteDocumentationDestinationPath '*.*')

    # Clean the generated PlatyPS CLIXML file
}

Task Checkout {
    # Execute only in pipeline build, not in developer's workspace...
    # given a branch name, expect a Git repository's submodule
    # Only when a CI agent is building the module
    # Pull all the files found in the latest commit on that branch in that repository
}

Task BuildPSM1 -Inputs (Get-Item $(Join-Path $SourcePath '*' '*.ps1')) -Outputs $ModuleOutputPath {
    Write-PSFMessage -Level Debug -Message 'task = BuildPSM1'
    [System.Text.StringBuilder]$PSM1text = [System.Text.StringBuilder]::new()
    foreach ($folder in $imports ) {
        [void]$PSM1text.AppendLine( "Write-Verbose 'Importing from [$(Join-Path $SourcePath $folder)]'" )
        if (Test-Path $(Join-Path $SourcePath $folder)) {
            Write-PFSMessage -Level Verbose -Message "Importing $(Join-Path $SourcePath $folder)"
            $fileList = Get-ChildItem $(Join-Path $SourcePath $folder '*.ps1') # | Where-Object Name -NotLike '*.Tests.ps1'
            foreach ($file in $fileList) {
                $shortName = $file.fullname.replace($PSScriptRoot, '')
                Write-PFSMessage -Level Verbose -Message "Importing [.$shortName]"
                [void]$PSM1text.AppendLine( "# .$shortName" )
                [void]$PSM1text.AppendLine( [System.IO.File]::ReadAllText($file.fullname) )
            }
        }
    }
    Write-PFSMessage -Level Verbose -Message "Creating module [$ModuleOutputPath]"
    Set-Content -Path $ModuleOutputPath -Value $PSM1text.ToString()
}

Task BuildPSD1 -inputs (Get-ChildItem $SourcePath -Recurse -File) -Outputs $ManifestOutputPath {
    Write-PSFMessage -Level Debug -Message 'task = BuildPSD1'
    # Copy-Item $ManifestCurrentPath -Destination $ManifestOutputPath

    $bumpVersionType = 'Patch'

    $functions = Get-ChildItem $(Join-Path $SourcePath 'public' '*.ps1') | Select-Object -ExpandProperty basename

    # ToDo turn this into a buildtool that understands the concept of empty oldfunctions

    $oldFunctions = (Get-Metadata -Path $ManifestCurrentPath -PropertyName 'FunctionsToExport')

    # use the Update-PackageVersion cmdlet in the ATAP.Utilities.BuildTooling.Powershell module
    #  Major and Minor and Patch version number changes are made only when a new release branch is created. That release branch is 'Prerelease' until the very last commmit and CI/CD build
    #  UpdatePackageVersion takes care of incrementing the prerelease version number during development and testing cycles
    # at this point we are starting to generate the changed metadata manifest
    Update-PackageVersion -Path $ManifestOutputPath

    # are there and functions / cmdlets taht are removed, or added, compared to the Current Manifest
    $functions | where { $_ -notin $oldFunctions } | % { $bumpVersionType = 'Minor' }
    $oldFunctions | where { $_ -notin $Functions } | % { $bumpVersionType = 'Major' }

    Set-ModuleFunctions -name $ManifestOutputPath -FunctionsToExport $functions

    # ToDo: support for classes

    # # Bump the module version
    # # But only if Not Prerelease
    # $version = [version] (Get-Metadata -Path $ManifestOutputPath -PropertyName 'ModuleVersion')
    # $galleryVersion = Import-Clixml -Path "$output\version.xml"
    # if ( $version -lt $galleryVersion )
    # {
    # $version = $galleryVersion
    # }
    # Write-Output "  Stepping [$bumpVersionType] version [$version]"
    # $version = [version] (Step-Version $version -Type $bumpVersionType)
    # Write-Output "  Using version: $version"

    Update-Metadata -Path $ManifestOutputPath -PropertyName ModuleVersion -Value $version
}

Task UnitTestPSModule {
    Write-PSFMessage -Level Debug -Message 'task = UnitTestPSModule'
    # [Pester Testing in Jenkins (Using NUNit)](https://sqlnotesfromtheunderground.wordpress.com/2017/01/20/pester-testing-in-jenkins-using-nunit/)
    # ToDo: update this so it collects test results and coverage results and publishes them to
    $TestResults = Invoke-Pester -Path $UnitTestsPath -PassThru -OutputFor JUnitXml mat -Tag Unit -ExcludeTag Slow
    # If the test results are not within expectations/margin, fail the build
    # ToDo: Xunit and perhaps Pester ? might be better tools for this step...
    if ($TestResults.FailedCount -gt 0) {
        # In a pipeline, return an exit code
        # Invoked by a dev, from a terminal or from a task, write a message and stop processing
        Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
    }
}

Task IntegrationTestPSModule {
    Write-PSFMessage -Level Debug -Message 'task = IntegrationTestPSModule'
    # ToDo: update this so it collects test results and coverage results and publishes them to
    $TestResults = Invoke-Pester -Path $IntegrationTestsPath -PassThru -Tag Integration -ExcludeTag Slow
    # If the test results are not within expectations/margin, fail the build
    # ToDo: Xunit and perhaps Pester ? might be better tools for this step...
    if ($TestResults.FailedCount -gt 0) {
        # In a pipeline, return an exit code
        # Invoked by a dev, from a terminal or from a task, write a message and stop processing
        Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
    }
}

Task GenerateHelpForPSModule {
    Write-PSFMessage -Level Debug -Message 'task = GenerateHelpForPSModule'
}

Task GenerateStaticSiteDocumentationForPSModule {
    Write-PSFMessage -Level Debug -Message 'task = GenerateStaticSiteDocumentationForPSModule'

}

Task SignPSModule {
    Write-PSFMessage -Level Debug -Message 'task = SignPSModule'
}

Task PackagePSModule {
    Write-PSFMessage -Level Debug -Message 'task = PackagePSModule'
    # create the source for the PowershellGallery package
    Copy-Item $ModuleOutputPath $GeneratedPowershellGalleryModulesPath
    Copy-Item $ManifestOutputPath $GeneratedPowershellGalleryModulesPath
    # create the source for the Nuget package
    Copy-Item $ModuleOutputPath $GeneratedNuGetPackageDestinationPath
    Copy-Item $ManifestOutputPath $GeneratedNuGetPackageDestinationPath
    # create the .nuspec file from the Manifest
    Get-NuspecFromPSD1 -ManifestPath $ManifestOutputPath -DestinationFolder $GeneratedNuGetPackageDestinationPath
    # create the .nupkg file
    #T oDo: wrap in a try/catch
    # Nuget.exe pack
    # create the source for the chocolatey package
    Copy-Item $ModuleOutputPath $GeneratedChocolateyPackageDestinationPath
    Copy-Item $ManifestOutputPath $GenerateChocolateyPackageDestinationPath
    # ToDo: add install.txt and uninstall.txt to a tools subdirectory
}

Task PublishPSModule {
    Write-PSFMessage -Level Debug -Message 'task = PublishPSModule'
    # Switch on Environment
    # Publish to FileSystem
    Publish-Module -Path $relativeModulePath -Repository $PSRepositoryName -NuGetApiKey $nuGetApiKey
    Publish-Module -Name $GeneratedPowershellGalleryModulesPath -Repository LocalDevelopmentPSRepository
    # Copy last build artifacts into a .7zip file, name it after the ModuleName-Version-buildnumber (like C# project assemblies)
    # Check the 7Zip file into the SCM repository
    # Get SHA-256 and other CRC checksums, add that info to the SCM repository
    # Publish the Production PSModule to the three repositories
    # Publish the checksums to the internet
    # Update the SCM repository metadata to associate the published Module
}

# Task Dependencies

# Default task.
Task . clean PublishPSModule

Task BuildPSM1 Clean

Task BuildPSD1 BuildPSM1

Task UnitTestPSModule BuildPSD1

Task IntegrationTestPSModule UnitTestPSModule

Task GenerateHelpForPSModule BuildPSD1

Task GenerateStaticSiteDocumentationForPSModule GenerateHelpForPSModule

Task SignPSModule GenerateStaticSiteDocumentationForPSModule IntegrationTestPSModule

Task PackagePSModule SignPSModule

Task PublishPSModule PackagePSModule

