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
  # For an unknown reason, the ConfirmPreference is set to High. Make it ignored, for this script
  $Script:ConfirmPreference = 'None'
  # Write-PSFMessage will write to its log file regardless of the value of $DebugPreference
  Write-PSFMessage -Level Debug -Message "Starting Module.Build.ps1; ModuleRoot = $ModuleRoot; Configuration = $Configuration; BuildRoot = $BuildRoot; Encoding = $Encoding"

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
  Write-PSFMessage -Level Debug -Message "sourceManifestPath = $sourceManifestPath; GeneratedModuleFilePath = $GeneratedModuleFilePath"

  $GeneratedPowerShellModulesDirectory = $global:settings[$global:configRootKeys['GeneratedPowershellModuleConfigRootKey']]
  $GeneratedModuleFilePath = Join-Path '.' $GeneratedPowerShellModulesDirectory $moduleFilename
  $GeneratedPowershellPackagesDirectory = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedPowershellPackagesConfigRootKey']]

  Write-PSFMessage -Level Debug -Message "ModuleRoot = $ModuleRoot; moduleName = $moduleName"
  Write-PSFMessage -Level Debug -Message "sourceFileInfos = $sourceFileInfos"
  Write-PSFMessage -Level Debug -Message "sourceFiles = $sourceFiles"


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
  if (-not $(Test-Path -Path $GeneratedPowerShellModulesDirectory -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedPowerShellModulesDirectory }
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

    # clean the generated powershell module, and all manifest and nuspec files in its subdirectories
    if ($PSCmdlet.ShouldProcess("$GeneratedPowerShellModulesDirectory", "Remove-Item -Force -Recurse -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
      Write-PSFMessage -Level Debug -Message "Removing [$GeneratedPowerShellModulesDirectory]"
      Remove-Item -Force -Recurse -Path $GeneratedPowerShellModulesDirectory -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
    }
    # clean the generated powershell packages, and all its subdirectories
    if ($PSCmdlet.ShouldProcess("$GeneratedPowershellPackagesDirectory", "Remove-Item -Recurse -Force -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
      Write-PSFMessage -Level Debug -Message "Removing [$GeneratedPowershellPackagesDirectory]"
      Remove-Item -Force -Recurse -Path $GeneratedPowershellPackagesDirectory -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
    }
    # Clean the Test Results and Text Coverage Results
    if ($PSCmdlet.ShouldProcess("$GeneratedTestResultsPath", "Remove-Item -Force -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
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
      if (-not $(Test-Path $GeneratedPowerShellModulesDirectory -PathType Container)) { New-Item $GeneratedPowerShellModulesDirectory -ItemType Directory -Force >$null }
      Set-Content -Path $GeneratedModuleFilePath -Value $PSM1text.ToString() -Encoding $encoding
    }
  }
}

Task BuildPSD1 @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildPSD1; sourceManifestPath = $sourceManifestPath; inputs = $inputs"

    # ToDO Move to settings (?) or constants
    $lowestSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 0, 'alpha000')

    # ToDo: implement a cache with a reasonable timeout
    $repositoriesCache = $null

    # Validation of package repositories is handeled by confirm-tools when a container is started
    # create the in-memory manifest from the sourceManifestPath
    # $sourceManifest = Import-PowerShellDataFile -Path $sourceManifestPath

    # Check all known production repositories for highest version of this $moduleName
    $highestSemanticVersion = $lowestSemanticVersion
    # ToDo: Replace with a mechanism or cache that speeds this up
    $RepositoryPackageSourceNames = @()
    ('NuGet', 'PowershellGet', 'ChocolateyGet') | ForEach-Object { $ProviderName = $_
      ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
      ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
          $RepositoryPackageSourceNames += $ProviderName + $ProviderLifecycle + $PackageLifecycle + 'Package'
          # Get highest version number for Development and production, and get highest version production manifest
        } } }
    # ToDo: this will not be needed as the function will be part of the installed module
    # . Get-ModuleHighestVersion.ps1
    $highestDevelopmentSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 1, 'alpha001', '')
    $highestProductionSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0)
    $highestProductionSemanticVersionPackage = $null
    $highestProductionSemanticVersionManifest = $null
    #Get-ModuleHighestVersion -moduleName $moduleName -Sources $RepositoryPackageSourceNames
    $nextSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 1, 'alpha002', '') # Get-NextSemanticVersionNumber $highestSemanticVersion $highestSemanticVersionPackage -manifest $GeneratedManifestFilePath

    # # $foundOldModules = @{}
    # # $foundOldVersions = @{}

    # # $ProviderName =(xxx).Keys
    # ('NuGet', 'PowershellGet', 'ChocolateyGet') | ForEach-Object { $ProviderName = $_
    #   switch ($ProviderName) {
    #     'NuGet' {
    #       ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
    #         switch ($ProviderLifecycle) {
    #           'Filesystem' {
    #             ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
    #               $RepositoryPackageSourceName = $ProviderName + $ProviderLifecycle + $PackageLifecycle + 'Package'
    #               # Only the highest version .psd1 file is needed
    #               $allNugetFilesystemPackageVersions = Get-ChildItem -Recurse -Include "$moduleName*" -File -Path $global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']][$RepositoryPackageSourceName] | Sort-Object -Property BaseName -Desc
    #               $highestNugetFilesystemPackageVersion = $allNugetFilesystemPackageVersions[0]
    #               if ($allNugetFilesystemPackageVersions) {
    #                 #ToDo advanced Infrastructure as code : Turn the replacement pattern into a configuration thingy
    #                 $highestsemanticVersion = $allNugetFilesystemPackageVersions[0].basename -replace "^$modulename-", ''
    #                 # $foundOldModules[$ProviderName][$PackageSource][$Lifecycle] = $semanticVersion
    #                 # $foundOldVersions[$semanticVersion] = [PSCustomObject]@{
    #                 #   ProviderName     = $ProviderName
    #                 #   PackageSource = $PackageSource
    #                 #   Lifecycle          = $Lifecycle
    #                 # }
    #               }
    #               break
    #             }
    #           }
    #           'QualityAssuranceWebServer' {
    #             break
    #           }
    #           'ProductionWebServer' {
    #             break
    #           }
    #           default {
    #             # ToDo write error handling for missing location
    #           }
    #         }
    #       }
    #     }

    #     'PowershellGet' {
    #       ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $PackageSource = $_
    #         switch ($PackageSource) {
    #           'Filesystem' {
    #             break
    #           }
    #           'QualityAssuranceWebServer' {
    #             break
    #           }
    #           'ProductionWebServer' {
    #             break
    #           }
    #           default {
    #             # ToDo write error handling for missing location
    #           }
    #         }
    #       }
    #     }
    #     'ChocolateyGet' {
    #       ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $PackageSource = $_
    #         switch ($PackageSource) {
    #           'Filesystem' {
    #             break
    #           }
    #           'QualityAssuranceWebServer' {
    #             break
    #           }
    #           'ProductionWebServer' {
    #             break
    #           }
    #           default {
    #             # ToDo write error handling for missing location
    #           }
    #         }
    #       }
    #     }
    #     default {
    #       # ToDo write error handling for missing location
    #     }
    #   }
    # }

    # # Get the highest version of this module found in Production / QA / Development repositories and also the highest production version
    # # Check across all sources
    # # See https://devblogs.microsoft.com/nuget/introducing-package-source-mapping/
    # $highestSemanticVersion = $highestNugetFilesystemPackageVersion #max($highestNugetFilesystemPackageVersion,$highestNugetFilesystemPackageVersion,$highestNugetFilesystemPackageVersion,...)
    # $highestVersionManifestPath = $null
    # if ($highestsemanticVersion) {
    #   # At least one version exists in Production / QA / Development repositories
    #   $nextSemanticVersion = '0.0.1-alpha001'
    #   $highestVersionManifestPath = $allNugetFilesystemPackageVersions[0] # or a path to a file download from a webserver
    # }
    # else {
    #   # No Other version exists, edge case when a module in $ProductLifecycle = Development is published for the very first time
    #   $nextSemanticVersion = '0.0.1-alpha001'
    # }

    # # Import the manifest from the highest version (including PreRelease) found across the Production / QA / Development repositories
    # $highestVersionManifest = $null

    # # import the manifest from the highest Production Version, if one exists
    # $highestProductionManifest = $null


    # # $highestVersion = [version] (Get-Metadata -Path $highestVersionManifestPath -PropertyName 'ModuleVersion')
    # # $highestProductionVersion = [version] (Get-Metadata -Path $highestProductionVersionPath -PropertyName 'ModuleVersion')
    # # $sourceManifestVersion = [version] (Get-Metadata -Path $sourceManifestPath -PropertyName 'ModuleVersion')

    # # Compare the names of the Public / Private / Resource / Tools files in the $sourceFiles to the names of the Public / Private / Resource / Tools files in the highest production manifest, and
    # # Determine if the source files represents a Major/Minor/Patch/PreRelease version bump compared to the highest production version (ToDo: allow manual indication for a version bump)
    # #ToDo: when run by a developer (not CI) if source is a prerelease, but major/minor values disagree with $sourcefiles comparasion, prompt/guide user interaction to pick a correct semantic version value



    # $bumpVersionType = '' #InitialDepoloyment, NewMajor, ,NewMajorPreRelease, NewMinor, NewMinorPreRelease, Patch, PatchPreRelease
    # #$nextSemanticVersion

    # # create the version number from the bump, the highest verion manifest, and the current source material

    # $version = [version] (Get-Metadata -Path $highestVersionManifest -PropertyName 'ModuleVersion')

    # # update the version number for the manifest

    # # update the public, private, resource, and tools entries for the manifest

    # # write the manifest to the $GeneratedManifestFilePath


    # # Copy-Item $ManifestCurrentPath -Destination $ManifestOutputPath

    # ToDo handle a non-exisitant $sourceManifestPath and a manifest that has no exported functions

    # $oldPublicFunctions = (Get-Metadata -Path $sourceManifestPath -PropertyName 'FunctionsToExport')

    # use the Update-PackageVersion cmdlet in the ATAP.Utilities.BuildTooling.Powershell module
    #  Major and Minor and Patch version number changes are made only when a new release branch is created. That release branch is 'Prerelease' until the very last commmit and CI/CD build
    #  UpdatePackageVersion takes care of incrementing the prerelease version number during development and testing cycles
    # at this point we are starting to generate the changed metadata manifest
    # Update-PackageVersion -Path $ManifestOutputPath

    # are there any functions / cmdlets that are removed, or added, compared to the Current Manifest
    #if ($($publicFunctions | Where-Object { $_ -notin $oldPublicFunctions })) { $bumpVersionType = 'Minor' }
    #if ($($oldPublicFunctions | Where-Object { $_ -notin $publicFunctions })) { $bumpVersionType = 'Major' }

    # Set-ModuleFunctions -Name $GeneratedManifestFilePath -FunctionsToExport $publicFunctions

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

    # Each provider and PackageLifecycle needs its own .psd1 and .nuspec file, along with the basic .psm1 file, and additional files as appropriate for the provider and lifecycle
    ('NuGet', 'PowershellGet', 'ChocolateyGet') | ForEach-Object { $ProviderName = $_
      ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
        $GeneratedManifestDirectory = Join-Path $GeneratedPowerShellModulesDirectory $ProviderName $PackageLifecycle
        $GeneratedManifestFilePath = Join-Path $GeneratedManifestDirectory $manifestFilename
        if (-not $(Test-Path $GeneratedManifestDirectory -PathType Container)) { New-Item $GeneratedManifestDirectory -ItemType Directory -Force >$null }

        # copy the source manifest file to the generated manifest path
        Copy-Item $sourceManifestPath $GeneratedManifestFilePath
        # Copy the generated module file to each manifest directory
        Copy-Item $GeneratedModuleFilePath $GeneratedManifestDirectory
        # ToDo: Copy additional files to the module subdirectory as appropriate for the provider and lifecycle


        $newManifestParams = @{
          Path          = $GeneratedManifestFilePath
          ModuleVersion = $nextSemanticVersion
        }
        if ($nextSemanticVersion.PreReleaseLabel) { $newManifestParams['PreRelease'] = $nextSemanticVersion.PreReleaseLabel }
        # Generate the data for the manifest depending on what is in the module subdirectory
        #region PSModuleContentsToExport
        #ToDo: replace the following arrays with a type [ATAP.Utilities.Powershell.PSModuleContentsToExport] and populate with a constructor that takes a path to the module subdirectory and looks for the .psm1 file and supporting
        $publicFunctions = @()
        $publicCmdlets = @()
        $privateFunctions = @()
        $exportedAliases = @()
        $exportedVariables = @()
        # $parsedOutput = [ATAP.Utilities.Powershell.PSModuleContentsToExport]::new()
        # replace the following with methods on the PSModuleContentsToExport type
        $publicPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'public' + [System.IO.Path]::DirectorySeparatorChar)
        foreach ($filePath in $($sourceFiles.fullname -match $publicPathPattern)) {
          $publicFunctions += Get-ChildItem $filePath | Select-Object -ExpandProperty basename
        }
        $privatePathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'private' + [System.IO.Path]::DirectorySeparatorChar)
        foreach ($filePath in $($sourceFiles.fullname -match $privatePathPattern)) {
          $privateFunctions += Get-ChildItem $filePath | Select-Object -ExpandProperty basename
        }

        #ToDo: replace following with $PSModuleSuportingFilesToPackage
        $dscResourceFiles = @()
        $formatFiles = @()
        $toolFiles = @()
        $dscResourcesPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'DscResources' + [System.IO.Path]::DirectorySeparatorChar)
        foreach ($filePath in $($sourceFiles.fullname -match $dscResourcesPathPattern)) {
          $dscResourceFiles += Get-ChildItem $filePath | Select-Object -ExpandProperty basename
        }
        $toolsPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'tools' + [System.IO.Path]::DirectorySeparatorChar)
        foreach ($filePath in $($sourceFiles.fullname -match $toolsPathPattern)) {
          $toolFiles += Get-ChildItem $filePath | Select-Object -ExpandProperty basename
        }
        $formatsPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'formats' + [System.IO.Path]::DirectorySeparatorChar)
        foreach ($filePath in $($sourceFiles.fullname -match $formatsPathPattern)) {
          $formatFiles += Get-ChildItem $filePath | Select-Object -ExpandProperty basename
        }

        #ToDo: replace following with $PSModuleContentsToExport and $PSModuleSuportingFilesToPackage
        if ($publicFunctions.count) { $newManifestParams['FunctionsToExport'] = $publicFunctions }
        if ($publicCmdlets.count) { $newManifestParams['CmdletsToExport'] = $publicCmdlets }
        if ($exportedAliases.count) { $newManifestParams['Aliases'] = $exportedAliases }
        if ($exportedVariables.count) { $newManifestParams['Variables'] = $exportedVariables }
        if ($formatFiles.count) { $newManifestParams['FormatsToProcess'] = $formatFiles }
        if ($dscResourceFiles.count) { $newManifestParams['DscResourcesToExport'] = $dscResourceFiles }
        if ($toolsFiles.count) { $newManifestParams['ToolsToProcess'] = $toolsFiles }

        Update-ModuleManifest @newManifestParams
      }

    }
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
    ('NuGet', 'PowershellGet', 'ChocolateyGet') | ForEach-Object { $ProviderName = $_
      ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
        # The NuSpec file is placed in the same directory as the manifest file
        $GeneratedManifestDirectory = Join-Path $GeneratedPowerShellModulesDirectory $ProviderName $PackageLifecycle
        # ensure the directory exists, error if not
        if (-not $(Test-Path $GeneratedManifestDirectory -PathType Container)) {
          $message = "GeneratedManifestDirectory = $GeneratedManifestDirectory does not exist"
          Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'BuildNuSpecFromManifest'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
        try {
          $GeneratedManifestFilePath = Join-Path $GeneratedManifestDirectory $manifestFilename
          # ToDo: remove after powershell package is installed
          . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-NuSpecFromManifest.ps1"
          Get-NuSpecFromManifest -ManifestPath $GeneratedManifestFilePath -DestinationFolder $GeneratedManifestDirectory -ProviderName $ProviderName
        }
        catch {
          $message = "calling Get-NuSpecFromManifest with -ManifestPath $GeneratedManifestFilePath -DestinationFolder $GeneratedManifestDirectory -ProviderName $ProviderName threw an error : $($error[0]|select-object * )"
          Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'BuildNuSpecFromManifest'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
      }
    }
  }
}

Task GeneratePackages @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'Clean', 'BuildPSM1', 'BuildPSD1', 'BuildNuSpecFromManifest', {
    Write-PSFMessage -Level Debug -Message 'task = BuildNuGetPackage'
    # ToDo: logic to select Dev, QA, Production package(s) to build
    ('NuGet', 'PowershellGet', 'ChocolateyGet') | ForEach-Object { $ProviderName = $_
      ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
        # The NuSpec file is placed in the same directory as the manifest file
        $GeneratedManifestDirectory = Join-Path $GeneratedPowerShellModulesDirectory $ProviderName $PackageLifecycle
        # ensure the directory exists, error if not
        if (-not $(Test-Path $GeneratedManifestDirectory -PathType Container)) {
          $message = "GeneratedManifestDirectory = $GeneratedManifestDirectory does not exist"
          Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'GeneratePackages'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }

        $GeneratedNuSpecPath = Join-Path $GeneratedManifestDirectory $NuSpecFilename

        $GeneratedPackageDestinationDirectory = Join-Path $GeneratedPowershellPackagesDirectory $ProviderName $PackageLifecycle
        # ensure the directory exists, silently create it if not
        if (-not $(Test-Path $GeneratedPackageDestinationDirectory -PathType Container)) { New-Item $GeneratedPackageDestinationDirectory -ItemType Directory -Force >$null }
        try {
          # Start-Process -FilePath $global:settings[$global:configRootKeys['NuGetExePathConfigRootKey']] -ArgumentList "-jar $jenkinsCliJarFile -groovy Get-JenkinsPlugins.groovy' -PassThru
          # ToDo: Add options to not create a window
          Start-Process NuGet -ArgumentList "pack $GeneratedNuSpecPath -OutputDirectory $GeneratedPackageDestinationDirectory" >$null
        }
        catch {
          $message = "calling nuget with argument list pack $GeneratedNuSpecPath -OutputDirectory $GeneratedPackageDestinationDirectory threw an error "
          Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'GeneratePackages'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
      }
    }
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
    Publish-Module -name $GeneratedPowershellGetModulesPath -Repository LocalDevelopmentPSRepository
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


