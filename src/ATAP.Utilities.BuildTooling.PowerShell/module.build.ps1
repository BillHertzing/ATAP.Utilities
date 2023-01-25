# This is the resource (template) version of the default build.ps1 file used by Invoke-Build throughout all ATAP.Utilities modules and libraries
# ToDo: figure out how to install the buildtooling powwershell module such that this file is found by default when invoke-build is run
# ToDo: until then use the following to link it (run this command in the powershell project's base subdirectroy)

# Remove-Item -path (join-path '.' 'Module.Build.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path '.' 'Module.Build.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.Buildtooling.PowerShell' 'Resources' 'Module.Build.ps1')
#[CmdletBinding(SupportsShouldProcess=$true)]
param(

  [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [string]  $ModuleRoot
  , [ValidateSet('Development', 'QualityAssurance', 'Production')]
  [string] $Configuration = 'Production'
  # Custom build root, still the original $BuildRoot by default.
  , [string] $BuildRoot = $BuildRoot
  , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
  [string] $Encoding # Often found in the $PSDefaultParameterValues preference variable
)

Enter-Build {
  # Allow the DebugPreference to be set for this script and it's children tasks
  $DebugPreference = 'SilentlyContinue' # 'Continue' # 'SilentlyContinue'
  # Write-PSFMessage will write to its log file regardless of the value of $DebugPreference
  Write-PSFMessage -Level Debug -Message "Starting Module.Build.ps1; Configuration = $Configuration; BuildRoot = $BuildRoot; Encoding = $Encoding"

  # The following are expected environment variables
  # CoverallsKey = $env:Coveralls_Key
  # The following come from a Powershell Secrets vault
  # NUGET_API = $env:NUGET_API

  # All utility and helper functions needed to build Powershell modules can be found in the ATAP.Utilities.BuildTooling.Powershell module, which should be found in one of the directories listed in the $env:PSModulePath
  #  That module includes dependendcies on other modules,
  # Include: build_utils, PFSMessage

  # By convention the module name and the final part of the $moduleRoot path are the same
  $moduleName = Split-Path $ModuleRoot -Leaf
  # ToDo: Move these strings to the global string constants file
  $moduleFilename = $moduleName + '.psm1'
  $manifestFilename = $moduleName + '.psd1'
  $NuSpecFilename = $moduleName + '.nuspec'

  $sourceSubDirectorys = @('public', 'private', 'Resources')
  $sourceExtensions = @('.ps1', '.clixml')
  $sourceFileInfos = $sourceSubDirectorys | ForEach-Object { $sourceSubDirectory = $_; $sourceExtensions | ForEach-Object { $sExtension = $_;
    (Get-ChildItem $(Join-Path $sourceSubDirectory $('*' + $sExtension)))
    } }
  $sourceFiles = $sourceSubDirectorys | ForEach-Object { $sourceSubDirectory = $_; $sourceExtensions | ForEach-Object { $sExtension = $_;
    (Get-Item $(Join-Path $sourceSubDirectory $('*' + $sExtension)))
    } }
  # The following subdirectories are "opinionated"
  # $SourcePath = Join-Path $BuildRoot 'src'
  # $UnitTestsPath = Join-Path $BuildRoot $ModuleName 'tests'
  # $IntegrationTestsPath = Join-Path $BuildRoot $ModuleName 'IntegrationTests'

  $sourceManifestPath = Join-Path $moduleRoot $manifestFilename

  $GeneratedPowerShellModuleSubdirectory = $global:settings[$global:configRootKeys['GeneratedPowershellModuleConfigRootKey']]
  $GeneratedModuleFilePath = Join-Path '.' $GeneratedPowerShellModuleSubdirectory $moduleFilename
  $GeneratedManifestFilePath = Join-Path '.' $GeneratedPowerShellModuleSubdirectory $manifestFilename
  $GeneratedNuSpecFilePath = Join-Path '.' $GeneratedPowerShellModuleSubdirectory $NuSpecFilename

  Write-PSFMessage -Level Debug -Message "ModuleRoot = $ModuleRoot; moduleName = $moduleName"
  Write-PSFMessage -Level Debug -Message "sourceFileInfos = $sourceFileInfos"
  Write-PSFMessage -Level Debug -Message "sourceFiles = $sourceFiles"
  Write-PSFMessage -Level Debug -Message "sourceManifestPath = $sourceManifestPath; GeneratedModuleFilePath = $GeneratedModuleFilePath; GeneratedManifestFilePath = $GeneratedManifestFilePath;"

  $GeneratedPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedRelativePathConfigRootKey']]
  $GeneratedModuleDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedPowershellModuleConfigRootKey']]
  #$GeneratedDevelopmentModuleDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedPowershellModuleConfigRootKey']]
  $GeneratedPowershellPackagesDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedPowershellPackagesConfigRootKey']]
  $GeneratedNuGetPackageDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedNuGetPackageConfigRootKey']]
  $GeneratedChocolateyPackageDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedChocolateyPackageConfigRootKey']]
  $GeneratedPowershellGetPackageDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedPowershellGetPackageConfigRootKey']]

  # The locations for QualityAssurance output file
  $GeneratedTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedTestResultsPathConfigRootKey']]
  $GeneratedUnitTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']]
  $GeneratedIntegrationTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']]
  $GeneratedTestCoverageResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']]

  # The locations for documentation output file
  $GeneratedDocumentationDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']]
  $GeneratedStaticSiteDocumentationDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']]

  # The PSRepositories required for packages destined for public powershell Repositories
  # $RepositoryNamePowershellGetDevelopmentFilesystemName = $global:settings[$global:configRootKeys['RepositoryNamePowershellGetDevelopmentPackageFilesystemConfigRootKey']]

  $TestFile = "$PSScriptRoot\output\TestResults_PS$PSVersion`_$TimeStamp.xml"


  # Validate or create required output paths
  if (-not $(Test-Path -Path $GeneratedPowerShellModuleSubdirectory -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedPowerShellModuleSubdirectory }
  if (-not $(Test-Path -Path $GeneratedNuGetPackageDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedNuGetPackageDestinationPath }
  if (-not $(Test-Path -Path $GeneratedChocolateyPackageDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedChocolateyPackageDestinationPath }
  if (-not $(Test-Path -Path $GeneratedPowershellGetPackageDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedPowershellGetPackageDestinationPath }
  if (-not $(Test-Path -Path $GeneratedTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedTestResultsPath }
  if (-not $(Test-Path -Path $GeneratedUnitTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedUnitTestResultsPath }
  if (-not $(Test-Path -Path $GeneratedIntegrationTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedIntegrationTestResultsPath }
  if (-not $(Test-Path -Path $GeneratedTestCoverageResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedTestCoverageResultsPath }
  if (-not $(Test-Path -Path $GeneratedDocumentationDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedDocumentationDestinationPath }
  if (-not $(Test-Path -Path $GeneratedStaticSiteDocumentationDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedStaticSiteDocumentationDestinationPath }

  # Validate the package repositories are mapped to a valid filesystem locations or web server URLs
  # if (-not $(Get-PSRepository -Name  )){


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
  #Write-PSFMessage -Level Debug -Message ('Environment variables at start of PSModule.build.ps1' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented 2 2) + [Environment]::NewLine )
}

Task Clean @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = {
    Write-PSFMessage -Level Debug -Message "Starting Task Clean; Configuration = $Configuration; BuildRoot = $BuildRoot; Encoding = $Encoding"
    Write-PSFMessage -Level Debug -Message "OriginalLocation = $OriginalLocation; BuildFile = $BuildFile"
    Write-PSFMessage -Level Debug -Message "WhatIf:$WhatIfPreference; -Verbose:$Verbosepreference; -Confirm:$ConfirmPreference"

    # clean the generated powershell module and the generated powershell metadata

    if ($PSCmdlet.ShouldProcess("$GeneratedModuleFilePath", "Remove-Item -Force -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
      Write-PSFMessage -Level Debug -Message "Removing [$GeneratedModuleFilePath]"
      Remove-Item -Force -Path $GeneratedModuleFilePath -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
    }
    if ($PSCmdlet.ShouldProcess("$GeneratedManifestFilePath", "Remove-Item -Force -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
      Write-PSFMessage -Level Debug -Message "Removing [$GeneratedManifestFilePath]"
      Remove-Item -Force -Path $GeneratedManifestFilePath -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
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
  }
}

# Task Checkout  If ($Env:CI -eq $true)  @{
#   Inputs  = $sourceFiles
#   Outputs = $GeneratedModuleFilePath
#   Jobs    = -{
#     Write-PSFMessage -Level Debug -Message 'Starting Task Checkout;'
#     # Execute only in pipeline build, not in developer's workspace...
#     # given a branch name, expect a Git repository's submodule
#     # Only when a CI agent is building the module
#     # Pull all the files found in the latest commit on that branch in that repository
#   }
# }

Task BuildPSM1 @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildPSM1; GeneratedModuleFilePath = $GeneratedModuleFilePath; sourceFiles = $sourceFiles"
    [System.Text.StringBuilder]$PSM1text = [System.Text.StringBuilder]::new()
    foreach ($filePath in $sourceFiles) {
      Write-PSFMessage -Level Debug -Message "Importing [.$filePath]"
      [void]$PSM1text.AppendLine( "# .$filePath" )
      [void]$PSM1text.AppendLine( [System.IO.File]::ReadAllText($filePath) )
    }
    if ($PSCmdlet.ShouldProcess("$GeneratedModuleFilePath", "Set-Content -Path $GeneratedModuleFilePath -Encoding $encoding -Verbose:$Verbosepreference -Confirm:$ConfirmPreference having $($PSM1text.Length) characters")) {
      Write-PSFMessage -Level Debug -Message "Creating module [$GeneratedModuleFilePath]"
      Set-Content -Path $GeneratedModuleFilePath -Value $PSM1text.ToString() -Encoding $encoding
    }
  }
}

Task BuildPSD1 @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildPSD1; GeneratedManifestFilePath = $GeneratedManifestFilePath; sourceManifestPath = $sourceManifestPath; inputs = $inputs"

    # ToDO Move to constants
    $lowestSemanticVersion = '0.0.1-alpha001'

    # ToDo: implement a cache with a reasonable timeout
    $repositoriesCache = $null

    # Validation of package repositories is handeled by confirm-tools when a container is started
    # create the in-memory manifest from the sourceManifestPath
    $manifest = Import-PowerShellDataFile Path $sourceManifestPath

    # Check all known production repositories for highest version of this $moduleName
    $highestSemanticVersion = $lowestSemanticVersion
    # ToDo: Replace with a mechanism or cache that speeds this up
    $RepositoryPackageSourceNames = @()
    ('NuGet', 'PowershellGet', 'Chocolatey') | ForEach-Object { $ProviderName = $_
      ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
      ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
        $RepositoryPackageSourceNames += $ProviderName + $ProviderLifecycle + $PackageLifecycle + 'Package'
      }}}
    $highestSemanticVersion, $highestSemanticVersionPackage = Get-HighestVersionOfModule -moduleName $moduleName -Sources $RepositoryPackageSourceNames
    $nextSemanticVersion = Get-NextSemanticVersionNumber $highestSemanticVersion $highestSemanticVersionPackage -manifest $GeneratedManifestFilePath

    # $foundOldModules = @{}
    # $foundOldVersions = @{}

    # $ProviderName =(xxx).Keys
    ('NuGet', 'PowershellGet', 'Chocolatey') | ForEach-Object { $ProviderName = $_
      switch ($ProviderName) {
        'NuGet' {
          ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
            switch ($ProviderLifecycle) {
              'Filesystem' {
                ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
                  $RepositoryPackageSourceName = $ProviderName + $ProviderLifecycle + $PackageLifecycle + 'Package'
                  # Only the highest version .psd1 file is needed
                  $allNugetFilesystemPackageVersions = Get-ChildItem -Recurse -Include "$moduleName*" -File -Path $global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']][$RepositoryPackageSourceName] | Sort-Object -Property BaseName -Desc
                  $highestNugetFilesystemPackageVersion = $allNugetFilesystemPackageVersions[0]
                  if ($allNugetFilesystemPackageVersions) {
                    #ToDo advanced Infrastructure as code : Turn the replacement pattern into a configuration thingy
                    $highestsemanticVersion = $allNugetFilesystemPackageVersions[0].basename -replace "^$modulename-", ''
                    # $foundOldModules[$ProviderName][$PackageSource][$Lifecycle] = $semanticVersion
                    # $foundOldVersions[$semanticVersion] = [PSCustomObject]@{
                    #   ProviderName     = $ProviderName
                    #   PackageSource = $PackageSource
                    #   Lifecycle          = $Lifecycle
                    # }
                  }
                  break
                }
              }
              'QualityAssuranceWebServer' {
                break
              }
              'ProductionWebServer' {
                break
              }
              default {
                # ToDo write error handling for missing location
              }
            }
          }
        }

        'PowershellGet' {
          ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $PackageSource = $_
            switch ($PackageSource) {
              'Filesystem' {
                break
              }
              'QualityAssuranceWebServer' {
                break
              }
              'ProductionWebServer' {
                break
              }
              default {
                # ToDo write error handling for missing location
              }
            }
          }
        }
        'Chocolatey' {
          ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $PackageSource = $_
            switch ($PackageSource) {
              'Filesystem' {
                break
              }
              'QualityAssuranceWebServer' {
                break
              }
              'ProductionWebServer' {
                break
              }
              default {
                # ToDo write error handling for missing location
              }
            }
          }
        }
        default {
          # ToDo write error handling for missing location
        }
      }
    }

    # Get the highest version of this module found in Production / QA / Development repositories and also the highest production version
    # Check across all sources
    # See https://devblogs.microsoft.com/nuget/introducing-package-source-mapping/
    $highestSemanticVersion = $highestNugetFilesystemPackageVersion #max($highestNugetFilesystemPackageVersion,$highestNugetFilesystemPackageVersion,$highestNugetFilesystemPackageVersion,...)
    $highestVersionManifestPath = $null
    if ($highestsemanticVersion) {
      # At least one version exists in Production / QA / Development repositories
    $nextSemanticVersion = '0.0.1-alpha001'
      $highestVersionManifestPath = $allNugetFilesystemPackageVersions[0] # or a path to a file download from a webserver
    }
    else {
      # No Other version exists, edge case when a module in $ProductLifecycle = Development is published for the very first time
      $nextSemanticVersion = '0.0.1-alpha001'
    }

    # Import the manifest from the highest version (including PreRelease) found across the Production / QA / Development repositories
    $highestVersionManifest = $null

    # import the manifest from the highest Production Version, if one exists
    $highestProductionManifest = $null


    # $highestVersion = [version] (Get-Metadata -Path $highestVersionManifestPath -PropertyName 'ModuleVersion')
    # $highestProductionVersion = [version] (Get-Metadata -Path $highestProductionVersionPath -PropertyName 'ModuleVersion')
    # $sourceManifestVersion = [version] (Get-Metadata -Path $sourceManifestPath -PropertyName 'ModuleVersion')

    # Compare the names of the Public / Private / Resource / Tools files in the $sourceFiles to the names of the Public / Private / Resource / Tools files in the highest production manifest, and
    # Determine if the source files represents a Major/Minor/Patch/PreRelease version bump compared to the highest production version (ToDo: allow manual indication for a version bump)
    #ToDo: when run by a developer (not CI) if source is a prerelease, but major/minor values disagree with $sourcefiles comparasion, prompt/guide user interaction to pick a correct semantic version value



    $bumpVersionType = '' #InitialDepoloyment, NewMajor, ,NewMajorPreRelease, NewMinor, NewMinorPreRelease, Patch, PatchPreRelease
    #$nextSemanticVersion

    # create the version number from the bump, the highest verion manifest, and the current source material

    $version = [version] (Get-Metadata -Path $highestVersionManifest -PropertyName 'ModuleVersion')

    # update the version number for the manifest

    # update the public, private, resource, and tools entries for the manifest

    # write the manifest to the $GeneratedManifestFilePath


    # Copy-Item $ManifestCurrentPath -Destination $ManifestOutputPath


    $publicFunctions = @()
    $privateFunctions = @()
    $resourceFiles = @()
    $toolFiles = @()

    $publicPathPattern = [IO.Path]::PathSeparator + 'public' + [IO.Path]::PathSeparator
    foreach ($filePath in $($inputs -match $publicPathPattern)) {
      $publicFunctions = Get-ChildItem $filePath | Select-Object -ExpandProperty basename
    }
    $privatePathPattern = [IO.Path]::PathSeparator + 'private' + [IO.Path]::PathSeparator
    foreach ($filePath in $($inputs -match $privatePathPattern)) {
      $privateFunctions = Get-ChildItem $filePath | Select-Object -ExpandProperty basename
    }
    $resourcesPathPattern = [IO.Path]::PathSeparator + 'resources' + [IO.Path]::PathSeparator
    foreach ($filePath in $($inputs -match $resourcesPathPattern)) {
      $resourceFiles = Get-ChildItem $filePath | Select-Object -ExpandProperty basename
    }
    $toolsPathPattern = [IO.Path]::PathSeparator + 'tools' + [IO.Path]::PathSeparator
    foreach ($filePath in $($inputs -match $toolsPathPattern)) {
      $toolFiles = Get-ChildItem $filePath | Select-Object -ExpandProperty basename
    }

    # ToDo handle a non-exisitant $sourceManifestPath and a manifest that has no exported functions

    $oldPublicFunctions = (Get-Metadata -Path $sourceManifestPath -PropertyName 'FunctionsToExport')

    # use the Update-PackageVersion cmdlet in the ATAP.Utilities.BuildTooling.Powershell module
    #  Major and Minor and Patch version number changes are made only when a new release branch is created. That release branch is 'Prerelease' until the very last commmit and CI/CD build
    #  UpdatePackageVersion takes care of incrementing the prerelease version number during development and testing cycles
    # at this point we are starting to generate the changed metadata manifest
    Update-PackageVersion -Path $ManifestOutputPath

    # are there any functions / cmdlets that are removed, or added, compared to the Current Manifest
    if ($($publicFunctions | Where-Object { $_ -notin $oldPublicFunctions })) { $bumpVersionType = 'Minor' }
    if ($($oldPublicFunctions | Where-Object { $_ -notin $publicFunctions })) { $bumpVersionType = 'Major' }

    Set-ModuleFunctions -Name $GeneratedManifestFilePath -FunctionsToExport $publicFunctions

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
}

Task UnitTestPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildPSD1', {
    Write-PSFMessage -Level Debug -Message 'task = UnitTestPSModule'
    # [Pester Testing in Jenkins (Using NUNit)](https://sqlnotesfromtheunderground.wordpress.com/2017/01/20/pester-testing-in-jenkins-using-nunit/)
    # ToDo: update this so it collects test results and coverage results and publishes them to
    $TestResults = Invoke-Pester -Path $UnitTestsPath -PassThru -OutputFor JUnitXml mat -Tag Unit -ExcludeTag Slow, Disabled
    # If the test results are not within expectations/margin, fail the build
    # ToDo: Xunit and perhaps Pester ? might be better tools for this step...
    if ($TestResults.FailedCount -gt 0) {
      # In a pipeline, return an exit code
      # Invoked by a dev, from a terminal or from a task, write a message and stop processing
      Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
    }
  }
}

Task IntegrationTestPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildPSD1', {
    Write-PSFMessage -Level Debug -Message 'task = IntegrationTestPSModule'
    # ToDo: update this so it collects test results and coverage results and publishes them to
    $TestResults = Invoke-Pester -Path $IntegrationTestsPath -PassThru -Tag Integration -ExcludeTag Slow, Disabled
    # If the test results are not within expectations/margin, fail the build
    # ToDo: Xunit and perhaps Pester ? might be better tools for this step...
    if ($TestResults.FailedCount -gt 0) {
      # In a pipeline, return an exit code
      # Invoked by a dev, from a terminal or from a task, write a message and stop processing
      Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
    }
  }
}

Task GenerateHelpForPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildPSM1', 'BuildPSD1', {
    Write-PSFMessage -Level Debug -Message 'task = GenerateHelpForPSModule'
  }
}

Task GenerateStaticSiteDocumentationForPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildPSM1', 'BuildPSD1', 'UnitTestPSModule', 'IntegrationTestPSModule', 'GenerateHelpForPSModule', {
    Write-PSFMessage -Level Debug -Message 'task = GenerateStaticSiteDocumentationForPSModule'

  }
}

Task BuildNuSpecFromManifest @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', 'BuildPSM1', 'BuildPSD1', {
    Write-PSFMessage -Level Debug -Message 'task = BuildNuSpecFromManifest'
    try {
      Get-NuSpecFromManifest -ManifestPath $GeneratedManifestFilePath -DestinationFolder $GeneratedModuleDestinationPath
    }
    catch {
      # toDo catch the errors, add to 'Problems'
    }
  }
}

Task BuildNuGetPackage @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', 'BuildPSM1', 'BuildPSD1', 'BuildNuSpecFromManifest', {
    Write-PSFMessage -Level Debug -Message 'task = BuildNuGetPackage'
    # ToDo: logic to select Dev, QA, Production package(s) to build
    try {
      # Start-Process -FilePath $global:settings[$global:configRootKeys['NuGetExePathConfigRootKey']] -ArgumentList "-jar $jenkinsCliJarFile -groovy Get-JenkinsPlugins.groovy' -PassThru
      Start-Process NuGet -ArgumentList "pack $GeneratedNuSpecFilePath -OutputDirectory $GeneratedNuGetPackageDestinationPath -PassThru"
    }
    catch {
      # toDo catch the errors, add to 'Problems'
    }
  }
}

Task BuildChocolateyPackage @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', 'BuildPSM1', 'BuildPSD1', 'BuildNuGetPackage', {
    Write-PSFMessage -Level Debug -Message 'task = BuildChocolateyPackage'
    # ToDo: logic to select Dev, QA, Production package(s) to build
    try { Get-NuSpecFromManifest -ManifestPath $GeneratedManifestFilePath -DestinationFolder $GeneratedNuGetPackageDestinationPath
    }
    catch {
      # toDo catch the errors, add to 'Problems'
    }
  }
}

Task GeneratePackagesForPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'GenerateStaticSiteDocumentationForPSModule', {
    Write-PSFMessage -Level Debug -Message 'task = GeneratePackagesForPSModule'
    # create the source for the PowershellGet package
    Copy-Item $ModuleOutputPath $GeneratedPowershellGetModulesPath
    Copy-Item $ManifestOutputPath $GeneratedPowershellGetModulesPath
    # create the source for the Nuget package
    Copy-Item $ModuleOutputPath $GeneratedNuGetPackageDestinationPath
    Copy-Item $ManifestOutputPath $GeneratedNuGetPackageDestinationPath
    # create the .nuspec file from the Manifest
    Get-NuspecFromPSD1 -ManifestPath $ManifestOutputPath -DestinationFolder $GeneratedNuGetPackageDestinationPath
    # create the .nupkg file
    # ToDo: wrap in a try/catch
    # Nuget.exe pack
    # create the source for the chocolatey package
    Copy-Item $ModuleOutputPath $GeneratedChocolateyPackageDestinationPath
    Copy-Item $ManifestOutputPath $GenerateChocolateyPackageDestinationPath
    # ToDo: add install.txt and uninstall.txt to a tools subdirectory
  }
}

Task SignPSPackages @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'GeneratePackagesForPSModule', {
    Write-PSFMessage -Level Debug -Message 'task = SignPSPackages'
  }
}


Task PublishPSPackage @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'SignPSPackages', {
    Write-PSFMessage -Level Debug -Message 'task = PublishPSPackage'
    # Switch on Environment
    # Publish to FileSystem
    Publish-Module -Path $relativeModulePath -Repository $PSRepositoryName -NuGetApiKey $nuGetApiKey
    Publish-Module -Name $GeneratedPowershellGetModulesPath -Repository LocalDevelopmentPSRepository
    # Copy last build artifacts into a .7zip file, name it after the ModuleName-Version-buildnumber (like C# project assemblies)
    # Check the 7Zip file into the SCM repository
    # Get SHA-256 and other CRC checksums, add that info to the SCM repository
    # Publish the Production PSModule to the three repositories
    # Publish the checksums to the internet
    # Update the SCM repository metadata to associate the published Module
  }
}

# Default task.
Task . Clean, BuildPSM1, BuildPSD1


