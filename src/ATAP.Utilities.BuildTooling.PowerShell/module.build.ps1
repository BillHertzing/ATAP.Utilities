# This is the module.build.ps1 file used by Invoke-Build throughout all ATAP.Utilities modules and libraries
#  It is stored under the root directory of the SharedVSCode repository in github (insert link here)
#  It is symbolically linked to the root directory of each Powershell project in the ATAP.Utilities multiroot repository
#  It can be called directly, it can be launched by a VSC launch configuration, and it is called by the CI/CD pipeline

# depends on PSFramework

param(

  [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]  $ModuleRoot = './'
  # Custom build root, still the original $BuildRoot by default. # ToDo trying to ensure the build root is the current dir
  , [string] $BuildRoot = $BuildRoot
  # Custom test classifications (what the subdirectory under /tests/ are called)
  # ToDo: replace with an enumeration type
  , [ValidateSet('Unit', 'Integration', 'Gui')]
  [string[]]$testClassifications = @('Unit', 'Integration', 'Gui')
  # These are the providers for which the script will create a package
  # ToDO: Validation is done as follows:
  # [ValidateScript( { [ProviderNamesEnum]::IsDefined([ProviderNamesEnum], $_) } )]
  , [ValidateSet('NuGet', 'PowershellGet', 'ChocolateyGet', 'ChocolateyCLI')]
  # ToDO: default to an array of enumeration values ($global:settings)
  [string[]]$providerNames = @('NuGet', 'PowershellGet', 'ChocolateyGet', 'ChocolateyCLI')
  # These are the lifecycle stages for which the script will create a package
  # ToDo: replace with an enumeration type
  , [ValidateSet('QualityAssurance', 'Production')]
  # ToDO: default to an array of enumeration values ($global:settings)
  [string[]]$packageLifecycles = @('QualityAssurance', 'Production')
  , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
  # ToDO: default to a string array of constants ($global:settings)
  [string[]]$sourceDirectoriesNames = @( 'public', 'private', 'lib' )
  # [string] $commonSourceDirectoryName = 'src' # ToDO: default to a global variable
  , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
  # ToDO: default to a string array of constants ($global:settings)
  [string[]]$sourceExtensions = @('.ps1', '.clixml', '.dll')
  , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
  # ToDO: default to a string array of constants ($global:settings)
  [string[]] $testDirectoriesNames = @(, 'tests') # ToDO: default to a global variable
  , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
  # ToDO: default to a string array of constants ($global:settings)
  [string[]] $testExtensions = @(, '.tests.ps1')  # ToDO: default to a global variable
  , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
  [string] $Encoding # Often found in the $PSDefaultParameterValues preference variable
)

Enter-Build {
  # Allow the DebugPreference to be set for this script and it's children tasks
  $DebugPreference = 'SilentlyContinue' # 'Continue' # 'SilentlyContinue'
  # For an unknown reason, the ConfirmPreference is set to High. Make it ignored, for this script
  $Script:ConfirmPreference = 'None'
  # By convention the module name and the final part of the $moduleRoot path are the same
  $moduleName = Split-Path $ModuleRoot -Leaf
  # Write-PSFMessage will write to its log file regardless of the value of $DebugPreference
  $message = @"
Starting Module.Build.ps1; ModuleRoot = $ModuleRoot; BuildRoot = $BuildRoot;
BuildFile = $BuildFile; providerNames = $providerNames; sourceDirectoriesNames = $sourceDirectoriesNames;
sourceExtensions = $($sourceExtensions -join ','); testDirectoriesNames = $testDirectoriesNames;
testExtensions = $testExtensions; testClassifications = $testClassifications;
packageLifecycles = $packageLifecycles; -WhatIf = $WhatIfPreference; -Verbose = $Verbosepreference;
-Confirm = $ConfirmPreference; Encoding = $Encoding
"@
  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'Enter-Build'

  # Things that abort the script if they are not found:
  # The location in the project repository where the release packages are stored
  # This top-level directory in the repository should be created during repository creation, throw an error if it is not found during module build time
  # ToDo: Move this string to the global string constants file
  $releaseDirectory = Join-Path $buildroot 'Releases'
  if (-not $(Test-Path -Path $releaseDirectory -PathType Container)) {
    $message = "The release directory $releaseDirectory was not found. This directory should be created during repository creation."
    Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'Enter-Build'
    throw $message
  }

  # validate required tools are present
  # Pester
  if (-not $(Get-Module -ListAvailable -Name 'Pester') ) {
    $message = 'Pester Powershell module not found'
    Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'Enter-Build'
    Throw $message
  }
  # PlatyPS
  if (-not $(Get-Module -ListAvailable -Name 'PlatyPS') ) {
    $message = 'PlatyPS Powershell module not found'
    Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'Enter-Build'
    Throw $message
  }
  # ATAP.Utilities.BuildTooling.Powershell (unless we are building that file)
  if (($moduleName -notmatch 'ATAP.Utilities.BuildTooling.Powershell') -and -not $(Get-Module -ListAvailable -Name 'ATAP.Utilities.BuildTooling.Powershell') ) { Throw 'ATAP.Utilities.BuildTooling.Powershell Powershell module not found' }
  # DocFx
  if (-not $(Get-Command -Name 'docfx.exe') ) {
    $message = 'docfx.exe module not found'
    Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'Enter-Build'
    Throw $message
  }
  # Java executable
  # if (-not $(Get-Command -Name 'java.exe') ) { Throw 'java.exe not found' }
  # Java libraries
  # PlantUML

  # The following are expected environment variables
  # CoverallsKey = $env:Coveralls_Key
  # The following come from a Powershell Secrets vault
  # ToDo: get from a vault depending on the provider and lifecycle and user
  # NUGET_API = $env:NUGET_API

  # ToDo: replace with an enumeration type
  # ToDo: default to an array of enumeration values ($global:settings)
  $script:RepositoryStorageMechanisms = @('FileSystem', 'QualityAssuranceWebServer', 'ProductionWebServer')

  # Validate the package repositories are mapped to a valid filesystem locations or web server URLs
  # Only check the ones needed for this run
  # if (-not $(Get-PSRepository -Name  )){


  # ToDo: Move these strings to the global string constants file
  $moduleFilename = $moduleName + '.psm1'
  $manifestFilename = $moduleName + '.psd1'
  $script:NuSpecFilename = $moduleName + '.nuspec'
  $script:NuSpecFileSuffix = '.nupkg'
  # By convention the module name and the final part of the $moduleRoot path are the same
  $moduleName = Split-Path $ModuleRoot -Leaf
  $script:ChocolateyPackageFilename = $moduleName

  $message = @"
RepositoryStorageMechanisms = $script:RepositoryStorageMechanisms; moduleFilename = $moduleFilename;
manifestFilename = $manifestFilename; NuSpecFilename = $script:NuSpecFilename;
NuSpecFileSuffix = $script:NuSpecFileSuffix; moduleName = $moduleName;
$script:ChocolateyPackageFilename = $script:ChocolateyPackageFilename
"@
  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'Enter-Build'

  $sourceFileHandles = [System.Collections.ArrayList]::new()
  for ($sourceDirectoriesNamesIndex = 0; $sourceDirectoriesNamesIndex -lt $sourceDirectoriesNames.Count; `
      $sourceDirectoriesNamesIndex++) {
    $sourceDirectoriesName = $sourceDirectoriesNames[$sourceDirectoriesNamesIndex]
    $subDirectory = Join-Path $moduleroot $sourceDirectoriesName
    if (Test-Path -Path $subDirectory -PathType Container) {
      for ($sourceExtensionsIndex = 0; $sourceExtensionsIndex -lt $sourceExtensions.Count; $sourceExtensionsIndex++) {
        $sourceExtension = $sourceExtensions[$sourceExtensionsIndex]
        $sourceFileHandles += Get-ChildItem -Path $subDirectory -Filter $('*' + $sourceExtension)
      }
    }
  }
  # throw an error if there are no source file handles found
  if ($sourceFileHandles.Count -eq 0) {
    $message = "There are no source file handles found under module root = $moduleroot"
    Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'Enter-Build'
    throw $message
  }

  # The following directory names for tests are 'opinionated'
  # $testsRootPath = Find-ComplementDirectory -sourcePath $moduleroot

  # ToDo: should we throw an error if there are no tests found?
  $testFileHandles = [System.Collections.ArrayList]::new()
  for ($testDirectoriesNamesIndex = 0; $testDirectoriesNamesIndex -lt $testDirectoriesNames.Count; `
      $testDirectoriesNamesIndex++) {
    $testDirectoriesName = $testDirectoriesNames[$testDirectoriesNamesIndex]
    $subDirectory = Join-Path $moduleroot $testDirectoriesName
    for ($testExtensionsIndex = 0; $testExtensionsIndex -lt $testExtensions.Count; $testExtensionsIndex++) {
      $testExtension = $testExtensions[$testExtensionsIndex]
      $testFileHandles += Get-ChildItem -Path $subDirectory -Filter $('*' + $testExtension)
    }
  }

  # The base directory for this module for generated powershell module packaging files
  $TemporaryPowershellModulePackagingDirectory = Join-Path $global:settings[$global:configRootKeys['TemporaryPowershellModulePackagingDirectoryConfigRootKey']] $moduleName
  # The  directory for generated powershell module .psm1 files
  $TemporaryPowershellModulePackagingSourceDirectory = Join-Path $TemporaryPowershellModulePackagingDirectory $global:settings[$global:configRootKeys['TemporaryPowershellModulePackagingSourceDirectoryConfigRootKey']]
  # The path to the generated powershell module .psm1 file
  $GeneratedModuleFilePath = Join-Path $TemporaryPowershellModulePackagingSourceDirectory $moduleFilename
  # The path to the generated powershell base module .psd1 file
  $script:GeneratedBaseManifestFilePath = Join-Path $TemporaryPowershellModulePackagingSourceDirectory $manifestFilename
  # The  directory for generated powershell module .psd1 files, nuspec files, readme files, test files, documentation files
  $script:TemporaryPowershellModulePackagingIntermediateDirectory = Join-Path $TemporaryPowershellModulePackagingDirectory $global:settings[$global:configRootKeys['TemporaryPowershellModulePackagingIntermediateDirectoryConfigRootKey']]
  # The directory for generated powershell module finished package files
  $script:TemporaryPowershellModulePackagingDistributionPackagesDirectory = Join-Path $TemporaryPowershellModulePackagingDirectory $global:settings[$global:configRootKeys['TemporaryPowershellModulePackagingDistributionPackagesDirectoryConfigRootKey']]
  $script:sourceManifestPath = Join-Path $moduleRoot $manifestFilename
  # ToDo: replace 'ReadMe.md' with a string constant ($global:settings)
  $readMeTextString = 'ReadMe.md'#
  $script:sourceReadMePath = Join-Path $moduleRoot $readMeTextString
  # ToDo: replace 'ReleaseNotes.md' with a string constant ($global:settings)
  $ReleaseNotesTextString = 'ReleaseNotes.md'
  $script:sourceReleaseNotesPath = Join-Path $moduleRoot $ReleaseNotesTextString

  $message = "TemporaryPowershellModulePackagingDirectory = $TemporaryPowershellModulePackagingDirectory; `
  TemporaryPowershellModulePackagingSourceDirectory = $TemporaryPowershellModulePackagingSourceDirectory; `
  GeneratedModuleFilePath = $GeneratedModuleFilePath; `
  GeneratedBaseManifestFilePath = $script:GeneratedBaseManifestFilePath"
  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'Enter-Build'

  # The locations for QualityAssurance output file
  $GeneratedTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedTestResultsPathConfigRootKey']]
  $GeneratedUnitTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']]
  $GeneratedIntegrationTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']]
  $GeneratedTestCoverageResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']]

  # The locations for documentation output file
  $GeneratedDocumentationDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']]
  $GeneratedStaticSiteDocumentationDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']]

  $message = "GeneratedTestResultsPath = $GeneratedTestResultsPath; `
  GeneratedUnitTestResultsPath = $GeneratedUnitTestResultsPath; `
  GeneratedIntegrationTestResultsPath = $GeneratedIntegrationTestResultsPath; `
  GeneratedTestCoverageResultsPath = $GeneratedTestCoverageResultsPath; `
  GeneratedDocumentationDestinationPath = $GeneratedDocumentationDestinationPath; `
  GeneratedStaticSiteDocumentationDestinationPath = $GeneratedStaticSiteDocumentationDestinationPath; `
  releaseDirectory = $releaseDirectory"
  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'Enter-Build'

  # validation testing
  # Items that may be missing, so create them if they are not present
  if (-not $(Test-Path -Path $GeneratedTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedTestResultsPath }
  if (-not $(Test-Path -Path $GeneratedUnitTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedUnitTestResultsPath }
  if (-not $(Test-Path -Path $GeneratedIntegrationTestResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedIntegrationTestResultsPath }
  if (-not $(Test-Path -Path $GeneratedTestCoverageResultsPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedTestCoverageResultsPath }
  if (-not $(Test-Path -Path $GeneratedDocumentationDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedDocumentationDestinationPath }
  if (-not $(Test-Path -Path $GeneratedStaticSiteDocumentationDestinationPath -PathType Container)) { $null = New-Item -ItemType Directory -Force $GeneratedStaticSiteDocumentationDestinationPath }

  Function CrossProduct {
    param(
      [string] $prefix
      , [string] $suffix
    )
    # ToDo: make it an arraylist of a new specific type
    $result = [System.Collections.ArrayList]::new()
    $providerNames | ForEach-Object { $providerName = $_
      $packageLifecycles | ForEach-Object { $packageLifecycle = $_
        # ToDo: create a type (class) for this
        [void]$result.Add(@{
            Path             = $(Join-Path $prefix $ProviderName $PackageLifecycle, $suffix)
            Provider         = $providerName
            PackageLifeCycle = $packageLifecycle
          })
      }
    }
    return $result
  }

  # $TestFile = "$PSScriptRoot\output\TestResults_PS$PSVersion`_$TimeStamp.xml"
}

# Default task.
# ToDo: replace the two package build tasks with a single task, having a switch and internal functions for each package to build
# ToDo: and / or make those build functions public so they can be called individually?
Task Short BuildPSM1, CopyAssembliesForPSModule, BuildBasePSD1, BuildPackageSpecificPSD1AndPSM1, BuildNuSpecFromManifest, BuildNuGetPackage , PublishPSPackage # BuildChocolateyPackage ,UnitTestPSModule,  PublishPSPackage #,  PublishPSPackage
Task NoDoc BuildPSM1, CopyAssembliesForPSModule, BuildBasePSD1, CopyTestFilesForPSModule, UnitTestPSModule, IntegrationTestPSModule, BuildPackageSpecificPSD1AndPSM1, BuildNuSpecFromManifest, BuildNuGetPackage , PublishPSPackage # BuildChocolateyPackage ,UnitTestPSModule,  PublishPSPackage #,  PublishPSPackage
Task NoTest BuildPSM1, CopyAssembliesForPSModule, BuildBasePSD1, GenerateReadMeMarkdownForPSModule, GenerateReleaseNotesMarkdownForPSModule, GenerateHelpForPSModule, GenerateStaticSiteDocumentationForPSModule, BuildPackageSpecificPSD1AndPSM1, BuildNuSpecFromManifest, BuildNuGetPackage , PublishPSPackage # BuildChocolateyPackage ,UnitTestPSModule,  PublishPSPackage #,  PublishPSPackage
Task All BuildPSM1, CopyAssembliesForPSModule, BuildBasePSD1, CopyTestFilesForPSModule, UnitTestPSModule, IntegrationTestPSModule, GenerateReadMeMarkdownForPSModule, GenerateReleaseNotesMarkdownForPSModule, GenerateHelpForPSModule, GenerateStaticSiteDocumentationForPSModule, BuildPackageSpecificPSD1AndPSM1, BuildNuSpecFromManifest, BuildNuGetPackage, BuildChocolateyPackage, SignPSPackages, PublishPSPackage
Task CleanAll Clean
#Task CleanBuildAll Clean All


Task Clean @{
  Jobs = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting): Clean;  BuildRoot = $BuildRoot;'
      Write-PSFMessage -Level Debug -Message "WhatIf:$WhatIfPreference; -Verbose:$Verbosepreference; -Confirm:$ConfirmPreference"
    }
    Process {
      # clean the TemporaryPowershellModulePackagingDirectory. Remove the subdirectory for $moduleName and all of its children
      if ($PSCmdlet.ShouldProcess("$TemporaryPowershellModulePackagingDirectory", "Remove-Item -Force -Recurse -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
        # as a safety measure, ensure the directory name includes the pathpart \temp\
        if ($TemporaryPowershellModulePackagingDirectory -notmatch '\\temp\\') {
          $message = "TemporaryPowershellModulePackagingDirectory does not contain \temp\. TemporaryPowershellModulePackagingDirectory = $TemporaryPowershellModulePackagingDirectory"
          Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
        if ($(Test-Path -Path $TemporaryPowershellModulePackagingDirectory -PathType Container)) {
          # if it exists, delete it
          Remove-Item -Force -Recurse -Path $TemporaryPowershellModulePackagingDirectory -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
        }
        # Create a new packaging directory
        New-Item -ItemType Directory -Force $TemporaryPowershellModulePackagingDirectory >$null
      }
      # create generated output paths for the module
      New-Item -ItemType Directory -Force $TemporaryPowershellModulePackagingSourceDirectory >$null
      New-Item -ItemType Directory -Force $script:TemporaryPowershellModulePackagingIntermediateDirectory >$null
      New-Item -ItemType Directory -Force $script:TemporaryPowershellModulePackagingDistributionPackagesDirectory >$null


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
        # Clean the generated PlantUML files
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done): Clean'
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
  Inputs  = {
    # ToDO: pull the string pattern out of string array of constants ($global:settings) ($sourceExtensions)
    $pSScriptExtension = '.ps1$'
    for ($sourceFileHandlesIndex = 0; $sourceFileHandlesIndex -lt $sourceFileHandles.Count; $sourceFileHandlesIndex++) {
      $sourceFileHandle = $sourceFileHandles[$sourceFileHandlesIndex]
      if ( $sourceFileHandle.extension -match $pSScriptExtension) {
        $sourceFileHandle.fullname
      }
    }
  }
  Outputs = { $GeneratedModuleFilePath }
  Jobs    = {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildPSM1; GeneratedModuleFilePath = $GeneratedModuleFilePath; sourceFiles = $sourceFileHandles" -Tag 'Invoke-Build', 'BuildPSM1'
    $pSScriptExtension = '.ps1'
    [System.Text.StringBuilder]$PSM1text = [System.Text.StringBuilder]::new()
    for ($sourceFileHandlesIndex = 0; $sourceFileHandlesIndex -lt $sourceFileHandles.Count; $sourceFileHandlesIndex++) {
      $sourceFileHandle = $sourceFileHandles[$sourceFileHandlesIndex]
      if ( $sourceFileHandle.extension -match $pSScriptExtension) {
        Write-PSFMessage -Level Debug -Message "Importing [.$filePath]" -Tag 'Invoke-Build', 'BuildPSM1'
        [void]$PSM1text.AppendLine( "# $sourceFileHandle.Name" )
        $text = [System.IO.File]::ReadAllText($sourceFileHandle)
        # ToDo: any 'using' directives must be moved to the top of the .psm1 file
        # ToDo: the target(s) of any 'Import-Module' directives must be recorded for use in the module manifest file
        [void]$PSM1text.AppendLine($text)
      }
    }
    Write-PSFMessage -Level Debug -Message "Creating module [$GeneratedModuleFilePath]" -Tag 'Invoke-Build', 'BuildPSM1'
    # $TemporaryPowershellModulePackagingSourceDirectory was created during enter-build, so does not need to be validated
    Set-Content -Path $GeneratedModuleFilePath -Value $PSM1text.ToString() -Encoding $encoding
  }
}

# ToDo: Make the manifest building dependent on the output of this task
Task CopyAssembliesForPSModule @{
  Inputs  = {
    $inputPathPattern = '.dll$'
    $($sourceFileHandles.fullname -match $inputPathPattern)
  }
  Outputs = {
    # ToDo: problem referenceing $Inputs inside of Outputs block
    $assembliesPathPattern = '.dll$'
    $($sourceFileHandles.fullname -match $assembliesPathPattern) | ForEach-Object {
      $AssemblyPathInfo = $_
      foreach ($destination in $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory )) ) {
        Join-Path $destination.Path $AssemblyPathInfo.name
      }
    }

  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting):CopyAssembliesForPSModule'
      $destinations = $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory ))
    }
    Process {
      #ToDO: FIX THIS instead of $inputs, loop
      foreach ($AssemblyPathInfo in $Inputs) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          # ToDo: handle cases where the .dll is not in the root of the module source
          # ToDo: handle cases where the module should run on Linux or MacOS
          Copy-Item $AssemblyPathInfo $destinations[$destinationIndex].Path
        }
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done):CopyAssembliesForPSModule'
    }
  }
}

# ToDo: copy dscResources
# ToDo: copy formats

Task BuildBasePSD1 @{
  Inputs  = {
    $script:sourceManifestPath
    $GeneratedModuleFilePath
  }
  Outputs = { $script:GeneratedBaseManifestFilePath }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting): BuildBasePSD1' -Tag 'Invoke-Build', 'BuildBasePSD1'
    }
    Process {
      # ToDo: replace 'public' with a string constant ($global:settings)
      $publicPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'public' + [System.IO.Path]::DirectorySeparatorChar)
      $privatePathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'private' + [System.IO.Path]::DirectorySeparatorChar)
      $cmdletPattern = [Regex]::Escape('[Cmdlet')
      $dscResourcesPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'DscResources' + [System.IO.Path]::DirectorySeparatorChar)
      $toolsPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'tools' + [System.IO.Path]::DirectorySeparatorChar)
      $formatsPathPattern = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar + 'formats' + [System.IO.Path]::DirectorySeparatorChar)
      $assembliesPathPattern = '.dll$'
      # copy the current source manifest to the temporary generated manifest
      Copy-Item $sourceManifestPath $script:GeneratedBaseManifestFilePath
      # read the temporary manifest into a data structure
      $currentManifest = Import-PowerShellDataFile $script:GeneratedBaseManifestFilePath
      if ($currentManifest.PrivateData.PSData.ContainsKey('Prerelease')) {
        $currentSemanticVersion = [System.Management.Automation.SemanticVersion]::new($currentManifest.ModuleVersion + '-' + $currentManifest.PrivateData.PSData.Prerelease)
      }
      else {
        $currentSemanticVersion = [System.Management.Automation.SemanticVersion]::new($currentManifest.ModuleVersion )
      }
      $newManifestParams = @{
        Path          = $script:GeneratedBaseManifestFilePath
        ModuleVersion = $currentSemanticVersion
      }
      # Generate the data for the manifest depending on what is in the module subdirectory
      #ToDo: replace the following arrays with a type [ATAP.Utilities.Powershell.PSModuleContentsToExport] and populate with a constructor that takes a path to the module subdirectory and looks for the .psm1 file and supporting
      $publicCmdlets = [System.Collections.ArrayList]::new() # will not be populated unless a .dll is provided (cmdlets must be compiled to a .dll) FIX CHECK THIS doesn't seem right
      $publicFunctions = [System.Collections.ArrayList]::new()
      $privateFunctions = [System.Collections.ArrayList]::new()
      $dscResourceFiles = [System.Collections.ArrayList]::new()
      $formatFiles = [System.Collections.ArrayList]::new()
      $toolFiles = [System.Collections.ArrayList]::new()
      $assemblyFiles = [System.Collections.ArrayList]::new()
      $exportedAliases = [System.Collections.ArrayList]::new()
      $exportedVariables = [System.Collections.ArrayList]::new()
      $requiredModuleFiles = [System.Collections.ArrayList]::new()

      # replace the following with methods on the PSModuleContentsToExport type
      for ($sourceFileHandlesIndex = 0; $sourceFileHandlesIndex -lt $sourceFileHandles.Count; $sourceFileHandlesIndex++) {
        $sourceFileHandle = $sourceFileHandles[$sourceFileHandlesIndex]
        switch ($sourceFileHandle.FullName) {
          { $sourceFileHandles.fullname -match $publicPathPattern } {
            $publicFunctions += $sourceFileHandle.basename
          }
          { $sourceFileHandles.fullname -match $privatePathPattern } {
            $privateFunctions += $sourceFileHandle.basename
          }
          { $sourceFileHandles.fullname -match $dscResourcesPathPattern } {
            $dscResourceFiles += $sourceFileHandle.basename
          }
          { $sourceFileHandles.fullname -match $toolsPathPattern } {
            $toolFiles += $sourceFileHandle.basename
          }
          { $sourceFileHandles.fullname -match $formatsPathPattern } {
            $formatFiles += $sourceFileHandle.basename
          }
          { $sourceFileHandles.fullname -match $assembliesPathPattern } {
            # Have to recreate the directory tree of assembly files in the project repro into the intermediate directory
            # ToDo: make sure the ephemeral directory root created for testing includes this directory structure
            # ToDo: Add support for native assemblies (.dll) using subdirectory
            # ToDO: named as the RunTimeIdentifiers (RID) and
            $assemblyFiles += $sourceFileHandle.FullName.Substring( $(Split-Path $ModuleRoot -Parent).count)
          }
          default {
            Write-PSFMessage -Level Debug -Message "Unknown file type: $($sourceFileHandle.FullName)" -Tag 'Invoke-Build', 'BuildBasePSD1'
          }
        }
      }
      # ToDo:Will need to parse all public files to get cmdlets
      # { $sourceFileHandles.fullname -match $cmdletPattern } {
      #   $publicCmdlets += # ToDo names of functions having the cmdlet pattern
      # }
      # Exported Aliases and Exported variables are manually added to the manifest
      #   $exportedAliases +=       # ToDo: Copy aliases from current manifest to new one
      #   $exportedVariables +=       # ToDo: Copy aliases from current manifest to new one
      # }
      #ToDo: replace following with $PSModuleContentsToExport and $PSModuleSuportingFilesToPackage
      if ($publicFunctions.count) { $newManifestParams['FunctionsToExport'] = $publicFunctions -join ',' }
      if ($publicCmdlets.count) { $newManifestParams['CmdletsToExport'] = $publicCmdlets }
      if ($exportedAliases.count) { $newManifestParams['Aliases'] = $exportedAliases }
      if ($exportedVariables.count) { $newManifestParams['Variables'] = $exportedVariables }
      if ($formatFiles.count) { $newManifestParams['FormatsToProcess'] = $formatFiles }
      if ($dscResourceFiles.count) { $newManifestParams['DscResourcesToExport'] = $dscResourceFiles }
      if ($toolsFiles.count) { $newManifestParams['ToolsToProcess'] = $toolsFiles }
      #$oldPSModulePath = $env:PSModulePath
      # Add the module root to the PSModulePath so the Update-moduleManifest can find the assemblies
      # $env:PSModulePath = $moduleroot + ';' + $oldPSModulePath
      #$script:requiredModuleFiles = @(,'C:\Dropbox\whertzing\PowerShell\Modules\platyPS\0.14.2\YamlDotNet.dll') # @("C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1") #@(, 'platyPS')
      #$script:requiredModuleFiles = @(,'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.dll') # @("C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1") #@(, 'platyPS')
      #$script:requiredModuleFiles = @(,'.\ATAP.Utilities.BuildTooling.PowerShell.dll') # @("C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1") #@(, 'platyPS')
      #$assemblyfiles = @(,'.\ATAP.Utilities.BuildTooling.PowerShell.dll') #@(, 'platyPS\0.14.2\YamlDotNet.dll') #C:\Dropbox\whertzing\PowerShell\Modules\
      # if ($script:requiredModuleFiles.count) { $newManifestParams['NestedModules'] = $script:requiredModuleFiles }
      # if ($assemblyFiles.count -or $script:requiredModuleFiles.count) { $env:PSModulePath = $oldPSModulePath }
      if ($assemblyFiles.count) {
        #$newManifestParams['RequiredAssemblies'] = $assemblyFiles
        #  $newManifestParams['RequiredModules'] = $currentManifest['RequiredModules'] + $assemblyFiles
      }
      Write-PSFMessage -Level Debug -Message "PSModulePath = $PSModulePath" #
      Write-PSFMessage -Level Debug -Message "RequiredAssemblies = $($newManifestParams['RequiredAssemblies'])"
      Write-PSFMessage -Level Debug -Message "RequiredModules = $($newManifestParams['RequiredModules'])"
      Update-ModuleManifest @newManifestParams
      # export the version
      $script:ModuleVersion = $script:nextSemanticVersion
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done): BuildBasePSD1'
    }
  }
}

Task BuildPackageSpecificPSD1AndPSM1 @{
  Inputs  = {
    # ToDo:
    $script:GeneratedBaseManifestFilePath
  }
  Outputs = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory $manifestFilename)
    , $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory $moduleFilename)
  }
  #   foreach ($destination in $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory)) {
  #     Join-Path $destination $manifestFilename
  #   }
  #  }
  Jobs    = {
    # Each provider and PackageLifecycle needs its own .psd1 and .nuspec file, along with the basic .psm1 file, and additional files as appropriate for the provider and lifecycle
    foreach ($destination in $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory )) {
      if (-not $(Test-Path $destination.Path -PathType Container)) { New-Item $destination.Path -ItemType Directory -Force >$null }
      # Copy the generated module file to each package intermediate directory
      Copy-Item $GeneratedModuleFilePath $destination.Path
      # copy the generated manifest file to each package intermediate directory
      Copy-Item $script:GeneratedBaseManifestFilePath $destination.Path
      # ToDo: modify psm1 or psd1 if needed for each specific package source directory
    }
  }
}

Task UnitTestPSModule @{
  Inputs  = $sourceFileHandles, $testFileHandles.fullname
  Outputs = $GeneratedModuleFilePath
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting): UnitTestPSModule'
    }
    Process {
      # [Pester Testing in Jenkins (Using NUNit)](https://sqlnotesfromtheunderground.wordpress.com/2017/01/20/pester-testing-in-jenkins-using-nunit/)
      # ToDo: update this so it collects test results and coverage results and publishes them to
      $TestResults = Invoke-Pester -Path $UnitTestsPath -PassThru -OutputFor JUnitXml -Tag Unit -ExcludeTag Slow, Disabled
      # If the test results are not within expectations/margin, fail the build
      # ToDo: Xunit and perhaps Pester ? might be better tools for this step...
      if ($TestResults.FailedCount -gt 0) {
        # In a pipeline, return an exit code
        # Invoked by a dev, from a terminal or from a task, write a message and stop processing
        Write-PSFMessage -Level Error -Message "Failed [$($TestResults.FailedCount)] Pester tests"
        Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done): UnitTestPSModule'
    }
  }
}

Task IntegrationTestPSModule @{
  Inputs  = $sourceFileHandles # add Unit testcoverage and test results
  Outputs = $GeneratedModuleFilePath  # add Integration testcoverage and test results
  Jobs    = {
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

Task GenerateReadMeMarkdownForPSModule @{
  Inputs  = { $script:sourceReadMePath }
  Outputs = {
    $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory $readMeTextString ))
    # # ToDo: replace 'ReadMe.md' with a string constant ($global:settings)
    # foreach ($destination in $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory ))) {
    #   Join-Path $destination.Path 'ReadMe.md'
    # }
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting): GenerateReadMeMarkdownForPSModule'
      # ToDo: work this into the build process so it is not hardcoded
      @'
      # MyPowerShellModule

      [![Build Status](https://github.com/yourorg/MyPowerShellModule/actions/workflows/test.yml/badge.svg)](https://github.com/yourorg/MyPowerShellModule/actions/workflows/test.yml)
      [![Coverage](https://img.shields.io/codecov/c/github/yourorg/MyPowerShellModule/main.svg)](https://app.codecov.io/gh/yourorg/MyPowerShellModule)
      [![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/MyPowerShellModule.svg)](https://www.powershellgallery.com/packages/MyPowerShellModule)
      [![License](https://img.shields.io/github/license/yourorg/MyPowerShellModule.svg)](LICENSE)

      > PowerShell module help build powershell modules.

'@
      $destinations = $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory )
    }
    Process {
      foreach ($sourcePath in $Inputs) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          Copy-Item $sourcePath $($destinations[$destinationIndex]).Path
        }
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done): GenerateReadMeMarkdownForPSModule'
    }
  }
}


Task GenerateReleaseNotesMarkdownForPSModule @{
  Inputs  = { $script:sourceReleaseNotesPath }
  Outputs = {
    $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory $ReleaseNotesTextString))
    #  # ToDo: replace 'ReleaseNotes.md' with a string constant ($global:settings)
    #  foreach ($destination in $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory ))) {
    #   Join-Path $destination.Path 'ReleaseNotes.md'
    #  }
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting): GenerateReleaseNotesMarkdownForPSModule'
      $destinations = $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory )
    }
    Process {
      foreach ($sourcePath in $Inputs) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          Copy-Item $sourcePath $($destinations[$destinationIndex]).Path
        }
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done): GenerateReleaseNotesMarkdownForPSModule'
    }
  }
}
# ToDo: move this before the module help and static site generation
Task GenerateHelpForPSModule @{
  Inputs  = $sourceFileHandles
  Outputs = $GeneratedModuleFilePath
  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = GenerateHelpForPSModule'
  }
}

Task GenerateStaticSiteDocumentationForPSModule @{
  Inputs  = $sourceFileHandles
  Outputs = $GeneratedModuleFilePath
  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = GenerateStaticSiteDocumentationForPSModule'
  }
}

Task CopyTestFilesForPSModule @{
  # ToDo: inputs should be the test files and the source files
  Inputs  = { $testFileHandles.fullname }
  Outputs = {
    # ToDo: outputs should be the test files copied into the $script:TemporaryPowershellModulePackagingIntermediateDirectory
    # ToDo: replace 'QualityAssurance' with an Enumeration ToString()
    # ToDo: replace 'tests' with a string constant ($global:settings)
    foreach ($destination in $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix 'tests')) | Where-Object { $_.PackageLifeCycle -match 'QualityAssurance' } ) {
      foreach ($testfileInfo in  [System.Collections.Generic.List[System.IO.FileInfo]] $testFileHandles) {
        Join-Path $destination.Path $testFileInfo.Name
      }
    }
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting): CopyTestFilesForPSModule'

      # The Test files are only copied to the Quality Assurance packages
      # ToDo: move the subdirectory 'test' into string constants ($global:settings)
      $destinations = $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix 'tests')) | Where-Object { $_.PackageLifeCycle -match 'QualityAssurance' }
    }
    Process {
      # powershell will cast an array of a single element to  a string if
      foreach ($testFileInfo in $testFileHandles) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          Copy-Item $testFileInfo.fullname $($destinations[$destinationIndex]).Path
        }
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done): CopyTestFilesForPSModule'
    }
  }
}


Task BuildNuSpecFromManifest @{
  Inputs  = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
  }
  Outputs = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $script:NuSpecFilename).Path
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task (starting):BuildNuSpecFromManifest inputs = $inputs ; outputs = $outputs'
      $destinations = $($(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory ))
    }
    Process {
      #$destinations = CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory
      foreach ($destination in $destinations) {
        # The NuSpec file is placed in the same directory as the manifest file
        $GeneratedManifestFilePath = Join-Path $destination.Path $manifestFilename
        try {
          # ToDo: make this hashtable a type
          # ToDo: remove after powershell package is installed
          . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-NuSpecFromManifest.ps1'
          Get-NuSpecFromManifest -ManifestPath $GeneratedManifestFilePath -DestinationFolder $destination.Path -ProviderName $destination.Provider
        }
        catch {
          $message = "calling Get-NuSpecFromManifest with -ManifestPath $GeneratedManifestFilePath -DestinationFolder $destination.Path -ProviderName $destination.ProviderName threw an error : $($error[0] | Select-Object * )"
          Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'BuildNuSpecFromManifest'
          # toDo catch the errors, add to 'Problems'
          Throw $message
        }
      }
    }
    End {
      Write-PSFMessage -Level Debug -Message 'task (done):BuildNuSpecFromManifest'
    }

  }
}

Task AddReadMeToNuSpec @{
  # this task modifies its inputs, so, there are no output dependencies, it has to run
  # Inputs  = {
  #   $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
  # }
  # Outputs = $GeneratedModuleFilePath
  Jobs = {
    Write-PSFMessage -Level Debug -Message 'task = AddReadMeToNuSpec'
    $destinations = CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory
    for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
      $nuSpecFilePath = Join-Path $destinations[$destinationIndex].Path $script:NuSpecFilename
      # Read the NuSpec file
      $nuSpecLines = [System.Collections.ArrayList](Get-Content $nuSpecFilePath )
      # Add the readme and any other files. Add before the </metadata> line
      # ToDo - define a lambda that matches the </metadata> line without needing to rely on exactly four spaces
      # then use the answer provided by DCastro in [Use regex inside Array.indexOf in c#.net to find the index of element(https://stackoverflow.com/questions/18758262/use-regex-inside-array-indexof-in-c-net-to-find-the-index-of-element)]
      # myList.FindIndex(s => new Regex(@"3\s*\-\s*6").Match(s).Success);
      # $insertIndex = $nuSpecLines.FindIndex(s => new Regex("metadata").Match(s).Success)
      # need the lambda that does the "s => new Regex("metadata").Match(s).Success" part of above
      # ToDo: wrap in a try/catch block if the IndexOf operation returns -1
      $insertIndex = $nuSpecLines.IndexOf('    </metadata>')
      # and then get the number of spaces found before the tag, and append that many spaces to the new lines
      $numberOfSpaces = 4
      # $nuSpecLines.Insert(($insertIndex + 1), " "*$numberOfSpaces + '<files>')
      # $nuSpecLines.Insert(($insertIndex + 2), " "*$numberOfSpaces + '  <file src="readme.md" target="" />')
      # $nuSpecLines.Insert(($insertIndex + 3), " "*$numberOfSpaces + '</files>')
      # add before the </metadata> line
      # temp why are there two lines?  $nuSpecLines.Insert(($insertIndex ), ' ' * $numberOfSpaces + '  <readme>readme.md</readme>')

      # <!-- Add files from an arbitrary folder that's not necessarily in the project -->
      # <file src="..\..\SomeRoot\**\*.*" target="" />

      # write the modified nuSpac lines back out to the nuSpec file
      $nuSpecLines | Set-Content $nuSpecFilePath
    }
    Write-PSFMessage -Level Debug -Message 'task (done):AddReadMeToNuSpec'

  }
}

Task BuildNuGetPackage @{
  Inputs  = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $script:NuSpecFilename).Path
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $moduleFilename).Path
  }

  Outputs = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingDistributionPackagesDirectory -suffix $moduleFilename).Path
  }
  Jobs    = {
    Write-PSFMessage -Level Debug -Message "task = BuildNuGetPackage, index = $index" -Tag 'Invoke-Build', 'BuildNuGetPackage'
    # ToDo: logic to select Dev, QA, Production package(s) to build
    $destinations = CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory
    for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
      $nuSpecFilePath = Join-Path $destinations[$destinationIndex].Path $script:NuSpecFilename
      $distributionPackagesDirectory = Join-Path $script:TemporaryPowershellModulePackagingDistributionPackagesDirectory $destinations[$destinationIndex].Provider $destinations[$destinationIndex].PackageLifeCycle
      # ensure the directory exists, silently create it if not
      if (-not $(Test-Path $distributionPackagesDirectory -PathType Container)) { New-Item $distributionPackagesDirectory -ItemType Directory -Force >$null }
      try {
        # Start-Process -FilePath $global:settings[$global:configRootKeys['NuGetExePathConfigRootKey']] -ArgumentList "-jar $jenkinsCliJarFile -groovy Get-JenkinsPlugins.groovy' -PassThru
        ## don't create window for this process.
        #  ToDo: -NoPackageAnalysis silences the warnings regarding test files in the QA package, but it would be better if the single warning could be silenced and still have package analysis to catch other errors
        # use the .Net object
        #Start-Process NuGet -ArgumentList "pack $nuSpecFilePath -OutputDirectory $distributionPackagesDirectory -Verbosity quiet -NoPackageAnalysis" -NoNewWindow
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.Arguments = 'pack', "$nuSpecFilePath", '-OutputDirectory', "$distributionPackagesDirectory"
        $processStartInfo.FileName = 'nuget.exe'
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.UseShellExecute = $false
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null
        $process.WaitForExit()
        # Capture stdout and stderr
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $message = "Nuget pack stdout : $stdout"
        Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'BuildNuGetPackage'
        $message = "Nuget pack stderr : $stderr"
        Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'BuildNuGetPackage'
      }
      catch {
        $message = "calling nuget with argument list pack $nuSpecFilePath -OutputDirectory $distributionPackagesDirectory threw an error "
        Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'BuildNuGetPackage'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
    Write-PSFMessage -Level Debug -Message 'task (done): BuildNuGetPackage'
  }
}

# param (
#     [Parameter(Mandatory)]
#     [string]$ModuleName,

#     [string]$ModuleVersion = '1.0.0',
#     [string]$Prerelease = '',
#     [string]$RepoOutput = "$PSScriptRoot\output",
#     [string]$ChocolateyTemplate = "$PSScriptRoot\choco"
# )

# # Ensure output folder
# $repoPath = Join-Path $RepoOutput 'powershell'
# $null = New-Item -ItemType Directory -Path $repoPath -Force

# # Paths
# $moduleSrc = Join-Path $PSScriptRoot $ModuleName
# $psd1Path = Join-Path $moduleSrc "$ModuleName.psd1"

# Write-Host "Building PowerShell module package..." -ForegroundColor Cyan

# # Update or create manifest
# Update-ModuleManifest -Path $psd1Path `
#     -ModuleVersion $ModuleVersion `
#     -Prerelease $Prerelease

# # 1️⃣ PowerShellGet-compatible nupkg
# Publish-Module -Path $moduleSrc -Repository LocalRepo -NuGetApiKey 'AnyKey' `
#     -SkipPublisherCheck -AllowPrerelease -Force `
#     -DestinationPath $repoPath

# Write-Host "PowerShell module packaged at $repoPath" -ForegroundColor Green

# # 2️⃣ NuGet-compatible .nupkg (optional - from .nuspec)
# Write-Host "Building NuGet .nupkg..." -ForegroundColor Cyan
# $nuspecPath = Join-Path $PSScriptRoot "$ModuleName.nuspec"

# if (!(Test-Path $nuspecPath)) {
#     @"
# <?xml version="1.0"?>
# <package >
#   <metadata>
#     <id>$ModuleName</id>
#     <version>$ModuleVersion</version>
#     <authors>YourName</authors>
#     <owners>YourOrg</owners>
#     <requireLicenseAcceptance>false</requireLicenseAcceptance>
#     <description>PowerShell module $ModuleName</description>
#     <tags>powershell</tags>
#   </metadata>
#   <files>
#     <file src="$moduleSrc\*" target="tools" />
#   </files>
# </package>
# "@ | Set-Content $nuspecPath
# }

# nuget pack $nuspecPath -OutputDirectory $repoPath

# # 3️⃣ Chocolatey .nupkg
# Write-Host "Building Chocolatey package..." -ForegroundColor Cyan

# $chocoNuspec = Join-Path $ChocolateyTemplate "$ModuleName.nuspec"

# if (!(Test-Path $chocoNuspec)) {
#     @"
# <?xml version="1.0"?>
# <package>
#   <metadata>
#     <id>$ModuleName</id>
#     <version>$ModuleVersion</version>
#     <authors>YourName</authors>
#     <description>Chocolatey package for $ModuleName</description>
#     <tags>chocolatey powershell</tags>
#   </metadata>
# </package>
# "@ | Set-Content $chocoNuspec

#     # Create chocolateyInstall.ps1
#     $toolsDir = Join-Path $ChocolateyTemplate 'tools'
#     New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null

#     @"
# # chocolateyInstall.ps1
# Install-Module -Name $ModuleName -Repository PSGallery -Force -AllowClobber
# "@ | Set-Content (Join-Path $toolsDir 'chocolateyInstall.ps1')
# }

# choco pack $chocoNuspec --outputdirectory $RepoOutput

# Write-Host "All packages built successfully." -ForegroundColor Green


Task BuildChocolateyPackage @{
  Inputs  = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $script:ChocolateyPackageFilename).Path
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingIntermediateDirectory -suffix $moduleFilename).Path
  }

  Outputs = {
    $(CrossProduct -prefix $script:TemporaryPowershellModulePackagingDistributionPackagesDirectory -suffix $moduleFilename).Path
  }

  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = BuildChocolateyPackage' -Tag 'Invoke-Build', 'BuildChocolateyPackage'
    Write-PSFMessage -Level Debug -Message 'task (done:) BuildChocolateyPackage' -Tag 'Invoke-Build', 'BuildChocolateyPackage'
  }
}

Task SignPSPackages @{
  Inputs  = $sourceFileHandles
  Outputs = $GeneratedModuleFilePath
  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = SignPSPackages' -Tag 'Invoke-Build', 'SignPSPackages'
    Write-PSFMessage -Level Debug -Message 'task (done:) SignPSPackages' -Tag 'Invoke-Build', 'SignPSPackages'
  }
}

Task PublishPSPackage @{
  Inputs  = $sourceFileHandles
  Outputs = $GeneratedModuleFilePath
  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = PublishPSPackage' -Tag 'Invoke-Build', 'PublishPSPackage'
    $providerNames | ForEach-Object { $ProviderName = $_
      $packageLifecycles | ForEach-Object { $PackageLifecycle = $_
        # The Distrbution directory where the distribution package has been placed
        $GeneratedFullPackageDistributionDirectory = Join-Path $script:TemporaryPowershellModulePackagingDistributionPackagesDirectory $ProviderName $PackageLifecycle
        # The module manifest file
        $currentManifest = Import-PowerShellDataFile $script:GeneratedBaseManifestFilePath

        $moduleNameAndVersion = $moduleName + '.' + $currentManifest.ModuleVersion

        $script:RepositoryStorageMechanisms | ForEach-Object {
          $RepositoryStorageMechanism = $_
          # Lookup the details of the appropriate repository to publish to
          # ToDO: use global:settings or global:configrootKeys
          $PSRepositoryKey = 'Repository' + $ProviderName + $RepositoryStorageMechanism + $PackageLifecycle + 'Package'
          $PSRepositoryFeed = $global:settings.PackageRepositoriesCollection[$PSRepositoryKey]
          $NuGetAPIKey = 'whertzing'
          # ToDo: $nuGetApiValue = $global:settings[$global:configRootKeys['NuGetApiKeyConfigRootKey']]
          # Publish-Module below comes from the module PowerShellGet [How to Publish PowerShell Modules to a Private Repository](https://blog.inedo.com/powershell/private-repo/)
          switch ($RepositoryStorageMechanism) {
            # Publish all packages to the FileSystem repositories
            'FileSystem' {
              switch ($providerNames) {
                'NuGet' {
                  # Location of the package to be published
                  $packageName = $moduleNameAndVersion + '.nupkg'
                  $packagePath = Join-Path $GeneratedFullPackageDistributionDirectory $packageName
                  # If the package already exists at the feed, it must be removed first
                  $repositoryTargetPath = Join-Path $PSRepositoryFeed $moduleName $currentManifest.ModuleVersion
                  if (Test-Path $repositoryTargetPath) {
                    Remove-Item $repositoryTargetPath -Force -Recurse
                  }
                  # use the .Net object
                  $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
                  $processStartInfo.Arguments = 'add', "$packagePath", '-source', $PSRepositoryFeed
                  $processStartInfo.FileName = 'nuget.exe'
                  $processStartInfo.RedirectStandardError = $true
                  $processStartInfo.RedirectStandardOutput = $true
                  $processStartInfo.UseShellExecute = $false
                  $process = New-Object System.Diagnostics.Process
                  $process.StartInfo = $processStartInfo
                  $process.Start() | Out-Null
                  $process.WaitForExit()
                  # Capture stdout and stderr
                  # $stdout = $process.StandardOutput.ReadToEnd()
                  # $message =  $stdout"
                  Write-PSFMessage -Level Debug -Message "stdout from Nuget add : $($process.StandardOutput.ReadToEnd())" -Tag 'Invoke-Build', 'PublishPSPackage', 'FileSystem'
                  # $stderr = $process.StandardError.ReadToEnd()
                  # $message = "stderr from Nuget add : $stderr"
                  Write-PSFMessage -Level Debug -Message "stderr from Nuget add : $($process.StandardError.ReadToEnd())" -Tag 'Invoke-Build', 'PublishPSPackage', 'FileSystem'
                }
                'PowershellGet' {
                  $packageName = $moduleNameAndVersion + '.nupkg'
                  $packagePath = Join-Path $GeneratedFullPackageDistributionDirectory $packageName

                  $result = '' # Publish-Module -Path $packagePath -Repository $PSRepositoryFeed -NuGetApiKey $nuGetApiKey
                  $message = 'Publish-Module  returned:' + $result
                  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'PublishPSPackage'
                }
                'ChocolateyGet' {
                  $result = ''
                  $message = 'ChocolateyGet publish returned:' + $result
                  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'PublishPSPackage'
                }
              }

            }
            'QualityAssuranceWebServer' {
              # Publish all packages to the QualityAssuranceWebServer repositories
              $message = "Publishing to QualityAssuranceWebServer, PSRepositoryFeed = $PSRepositoryFeed"
              Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'PublishPSPackage' 'QualityAssuranceWebServer'
              switch ($providerNames) {
                'NuGet' {
                  # Location of the package to be published
                  $packageName = $moduleNameAndVersion + '.nupkg'
                  $packagePath = Join-Path $GeneratedFullPackageDistributionDirectory $packageName

                  Write-PSFMessage -Level Debug -Message "stderr from Nuget add : $process.StandardError.ReadToEnd()" -Tag 'Invoke-Build', 'PublishPSPackage', 'QualityAssuranceWebServer'
                }
                'PowershellGet' {
                  Write-PSFMessage -Level Debug -Message $message -Tag 'Invoke-Build', 'PublishPSPackage'
                }
                'ChocolateyGet' {
                }
              }
              $PSRepositoryFeed = 'InternalWebServerPSRepository'
            }
            'ProductionWebServer' {
              # publish production packages for the PublicWebServer to a "FinalInspectionStagingArea"
              $PSRepositoryFeed = 'PublicWebServerPSRepository'
            }
          }
        }
      }
    }

    # Switch on Environment
    # Publish to FileSystem
    #Publish-Module -Path $relativeModulePath -Repository $PSRepositoryFeed -NuGetApiKey $nuGetApiKey
    #Publish-Module -Name $GeneratedPowershellGetModulesPath -Repository LocalDevelopmentPSRepository
    # Copy last build artifacts into a .7zip file, name it after the ModuleName-Version-buildnumber (like C# project assemblies)
    # Check the 7Zip file into the SCM repository
    # Get SHA-256 and other CRC checksums, add that info to the SCM repository
    # Publish the Production PSModule to the three repositories
    # Publish the checksums to the internet
    # Update the SCM repository metadata to associate the published Module
  }
}


# This function looks upwards from the module root until it finds a directory
#  that contains both the source and tests directories
#  and then looks down the directory tree to find the tests directory having a name that matches the modulename
# function Find-ComplementDirectory {
#   [CmdletBinding(DefaultParameterSetName = 'FindTests')]
#   param(
#     # [Parameter(ParameterSetName = 'FindTests')]
#     # [ValidateScript({ Test-Path $_ })]
#     # [string] $testsPath,
#     [Parameter(ParameterSetName = 'FindTests')]
#     [ValidateScript({ Test-Path $_ })]
#     [string] $sourcePath,
#     [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
#     [string] $sourceName = $commonSourceDirectoryName,
#     [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
#     [string] $commonTestsDirectoryName = $commonTestsDirectoryName
#   )
#   # from whatever directory the function starts in, look upward to find the common parent
#   $initialDirectory = [System.IO.DirectoryInfo]::new((Get-Location).Path)
#   $currentDir = $initialDirectory
#   $commonParentDirectory = $null
#   while ( $null -ne $currentDir) {
#     # Look for peer $testsName and $sourceName directories
#     if ((Test-Path -Path "$currentDir\$sourceName") -and (Test-Path -Path "$currentDir\$commonTestsDirectoryName")) {
#       $commonParentDirectory = $currentDir
#       break
#     } else {
#       #move up the directory tree
#       $currentDir = (Get-Item -Path $currentDir).Parent
#     }
#   }
#   if ( $null -eq $commonParentDirectory) {
#     $message = "searching upward from $initialDirectory found no parent having both $sourceName and $commonTestsDirectoryName"
#     Write-PSFMessage -Level Error -Message $message
#     throw $message
#   }

#   # if looking for tests given source, the $modulePackageName should be the directory upward from the initial that resides just one level below $commonParentDirectory
#   switch ($PSCmdlet.ParameterSetName) {
#     'FindTests' {
#       return Join-Path $commonParentDirectory $commonTestsDirectoryName $moduleName
#     }
#     'FindSource' {
#       return Join-Path $commonParentDirectory $sourceName $moduleName
#     }
#     default {
#       $message = "ParameterSetName $PSCmdlet.ParameterSetName has not been implemented yet"
#       Write-PSFMessage -Level Error -Message $message -Tag 'Module.build.ps1'
#       throw $message
#     }
#   }

# }

# Get-Next Version placeholder
# Validation of package repositories is handeled by confirm-tools when a container is started
# create the in-memory manifest from the sourceManifestPath
# $sourceManifest = Import-PowerShellDataFile -Path $sourceManifestPath

# ToDo: implement a cache with a reasonable timeout
# $repositoriesCache = $null
# # Check all known production repositories for highest version of this $moduleName
# # ToDO Move to settings (?) or constants
# $lowestSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 0, 'alpha000')
# $highestSemanticVersion = $lowestSemanticVersion
# # ToDo: Replace with a mechanism or cache that speeds this up
# $RepositoryPackageSourceNames = @()
# $providerNames | ForEach-Object { $ProviderName = $_
#         ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
#     $packageLifecycles | ForEach-Object { $PackageLifecycle = $_
#       $RepositoryPackageSourceNames += $ProviderName + $ProviderLifecycle + $PackageLifecycle + 'Package'
#       # Get highest version number for Development and production, and get highest version production manifest
#     } } }
# # ToDo: this will not be needed as the function will be part of the installed module
# # . Get-ModuleHighestVersion.ps1
# $highestDevelopmentSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 1, 'alpha001', '')
# $highestProductionSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0)
# $highestProductionSemanticVersionPackage = $null
# $highestProductionSemanticVersionManifest = $null
# #Get-ModuleHighestVersion -moduleName $moduleName -Sources $RepositoryPackageSourceNames
# $script:nextSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 1, 'alpha003', '') # Get-script:nextSemanticVersionNumber $highestSemanticVersion $highestSemanticVersionPackage -manifest $GeneratedManifestFilePath

# # $foundOldModules = @{}
# # $foundOldVersions = @{}

# # $ProviderName =(xxx).Keys
# $providerNames | ForEach-Object { $ProviderName = $_
#   switch ($ProviderName) {
#     'NuGet' {
#       ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
#         switch ($ProviderLifecycle) {
#           'Filesystem' {
#             $packageLifecycles  | ForEach-Object { $PackageLifecycle = $_
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
#   $script:nextSemanticVersion = '0.0.1-alpha001'
#   $highestVersionManifestPath = $allNugetFilesystemPackageVersions[0] # or a path to a file download from a webserver
# }
# else {
#   # No Other version exists, edge case when a module in $ProductLifecycle = Development is published for the very first time
#   $script:nextSemanticVersion = '0.0.1-alpha001'
# }

# # Import the manifest from the highest version (including PreRelease) found across the Production / QA / Development repositories
# $highestVersionManifest = $null

# # import the manifest from the highest Production Version, if one exists
# $highestVersionProductionManifest = $null


# # $highestVersion = [version] (Get-Metadata -Path $highestVersionManifestPath -PropertyName 'ModuleVersion')
# # $highestVersionProduction = [version] (Get-Metadata -Path $highestVersionProductionManifest -PropertyName 'ModuleVersion')
# # $sourceManifestVersion = [version] (Get-Metadata -Path $sourceManifestPath -PropertyName 'ModuleVersion')

# # Compare the names of the Public / Private / Resource / Tools files in the $sourceFiles to the names of the Public / Private / Resource / Tools files in the highest production manifest, and
# # Determine if the source files represents a Major/Minor/Patch/PreRelease version bump compared to the highest production version (ToDo: allow manual indication for a version bump)
# #ToDo: when run by a developer (not CI) if source is a prerelease, but major/minor values disagree with $sourcefiles comparasion, prompt/guide user interaction to pick a correct semantic version value


# $bumpVersionType = '' #InitialDeployment, NewMajor, ,NewMajorPreRelease, NewMinor, NewMinorPreRelease, Patch, PatchPreRelease
# #$script:nextSemanticVersion

# # create the version number from the bump, the highest version manifest, and the current source material

# $version = [version] (Get-Metadata -Path $highestVersionManifest -PropertyName 'ModuleVersion')

# # update the version number for the manifest

# # update the public, private, resource, and tools entries for the manifest

# # write the manifest to the $GeneratedManifestFilePath


# # Copy-Item $ManifestCurrentPath -Destination $ManifestOutputPath

# ToDo handle a non-existent $sourceManifestPath and a manifest that has no exported functions

# $oldPublicFunctions = (Get-Metadata -Path $sourceManifestPath -PropertyName 'FunctionsToExport')

# use the Update-PackageVersion cmdlet in the ATAP.Utilities.BuildTooling.Powershell module
#  Major and Minor and Patch version number changes are made only when a new release branch is created. That release branch is 'Prerelease' until the very last commmit and CI/CD build
#  UpdatePackageVersion takes care of incrementing the prerelease version number during development and testing cycles
# at this point we are starting to generate the changed metadata manifest
# Update-PackageVersion -Path $ManifestOutputPath

# are there any functions / cmdlets that are removed, or added, compared to the Current Manifest
#if ($($publicFunctions | Where-Object { $_ -notIn $oldPublicFunctions })) { $bumpVersionType = 'Minor' }
#if ($($oldPublicFunctions | Where-Object { $_ -notIn $publicFunctions })) { $bumpVersionType = 'Major' }

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




























# $version = $galleryVersion
# }
# Write-Output "  Stepping [$bumpVersionType] version [$version]"
# $version = [version] (Step-Version $version -Type $bumpVersionType)
# Write-Output "  Using version: $version"




