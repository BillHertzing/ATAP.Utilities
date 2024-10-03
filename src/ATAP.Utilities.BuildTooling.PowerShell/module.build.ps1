# This is the resource (template) version of the default build.ps1 file used by Invoke-Build throughout all ATAP.Utilities modules and libraries
# ToDo: figure out how to install the buildtooling powwershell module such that this file is found by default when invoke-build is run
# ToDo: until then use the following to link it (run this command in the powershell project's base subdirectory)
# Remove-Item -path (join-path '.' 'Module.Build.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path '.' 'Module.Build.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.Buildtooling.PowerShell' 'Resources' 'Module.Build.ps1')
# Remove-Item -path (join-path '.' 'Module.Build.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path '.' 'Module.Build.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.Buildtooling.PowerShell' 'Module.build.ps1')

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
  #  That module includes dependencies on other modules,
  # Include: build_utils, PFSMessage

  # By convention the module name and the final part of the $moduleRoot path are the same
  $moduleName = Split-Path $ModuleRoot -Leaf
  # ToDo: Move these strings to the global string constants file
  $moduleFilename = $moduleName + '.psm1'
  $manifestFilename = $moduleName + '.psd1'
  $NuSpecFilename = $moduleName + '.nuspec'

  # These are the providers for which the script will create a package
  # ToDo: replace with a n enumeration type
  $providerNames = ('NuGet', 'PowershellGet', 'ChocolateyGet')
  $packageLifecycles = ('Development', 'QualityAssurance', 'Production')
  $StorageMechanisms = ('FileSystem', 'InternalWebServer', 'PublicWebServer')

  $sourceDirectorys = @('./', 'public', 'private', 'Resources')
  $sourceExtensions = @('.ps1', '.clixml', '.dll')
  $sourceFiles = @()
  $sourceDirectorys | ForEach-Object {
    $subDirectory = Join-Path $moduleroot $_
    if (Test-Path -Path $subDirectory -PathType Container) {
      $sourceExtensions | ForEach-Object {
        $sourceFiles += Get-ChildItem -Path $subDirectory -Filter $('*' + $_)
      }
    }
  }

  # The following direcotry names for tests are 'opinionated'
  # ToDo: replace 'tests' with a string constant ($global:settings)
  $testsDirectoryComponentName = 'tests'
  $testClassifications = @('.UnitTests', '.IntegrationTests', '.GuiTests')
  $testsRootPath = $moduleroot -replace '\\src\\', "\$testsDirectoryComponentName\"
  $testExtensions = @(, '.tests.ps1')
  $testFileInfos = [System.Collections.ArrayList]::new()
  ForEach ($testClassification in $testClassifications) {
    $testDirectory = "$testsRootPath$testClassification"
    if (Test-Path -Path $testDirectory -PathType Container) {
      $testExtensions | ForEach-Object {
        $testExtension = $_
        $testFileInfos += Get-ChildItem -Path $testDirectory -Filter $('*' + $testExtension)
      }
    }
  }

  # The base directory for this module for generated powershell module packaging files
  $GeneratedPowershellModulePackagingDirectory = Join-Path $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingDirectoryConfigRootKey']] $moduleName
  # The  directory for generated powershell module .psm1 files
  $GeneratedPowershellModulePackagingSourceDirectory = Join-Path $GeneratedPowershellModulePackagingDirectory $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingSourceDirectoryConfigRootKey']]
  # The path to the generated powershell module .psm1 file
  $GeneratedModuleFilePath = Join-Path $GeneratedPowershellModulePackagingSourceDirectory $moduleFilename
  # The path to the generated powershell base module .psd1 file
  $GeneratedBaseManifestFilePath = Join-Path $GeneratedPowershellModulePackagingSourceDirectory $manifestFilename
  # The  directory for generated powershell module .psd1 files, nuspec files, readme files, test files, documentation files
  $GeneratedPowershellModulePackagingIntermediateDirectory = Join-Path $GeneratedPowershellModulePackagingDirectory $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingIntermediateDirectoryConfigRootKey']]
  # The directory for generated powershell module finished package files
  $GeneratedPowershellModulePackagingDistributionPackagesDirectory = Join-Path $GeneratedPowershellModulePackagingDirectory $global:settings[$global:configRootKeys['GeneratedPowershellModulePackagingDistributionPackagesDirectoryConfigRootKey']]

  Function makeitup {
    param(
      [string] $prefix
      , [string] $suffix
    )
    # ToDo: make it an arraylist of a new specific type
    $result = [System.Collections.ArrayList]::new()
    $providerNames | ForEach-Object { $providerName = $_
      $packageLifecycles | ForEach-Object { $packageLifecycle = $_
        [void]$result.Add(@{
            Path             = $(Join-Path $prefix $ProviderName $PackageLifecycle, $suffix)
            Provider         = $providerName
            PackageLifeCycle = $packageLifecycle
          })
      }
    }
    return $result
  }

  $sourceManifestPath = Join-Path $moduleRoot $manifestFilename
  # ToDo: replace 'ReadMe.md' with a string constant ($global:settings)
  $sourceReadMePath = Join-Path $moduleRoot 'ReadMe.md'
  # ToDo: replace 'ReleaseNotes.md' with a string constant ($global:settings)
  $sourceReleaseNotesPath = Join-Path $moduleRoot 'ReleaseNotes.md'
  Write-PSFMessage -Level Debug -Message "sourceManifestPath = $sourceManifestPath; GeneratedModuleFilePath = $GeneratedModuleFilePath"
  Write-PSFMessage -Level Debug -Message "ModuleRoot = $ModuleRoot; moduleName = $moduleName"
  # Write-PSFMessage -Level Debug -Message "sourceFiles = $sourceFiles"

  # The locations for QualityAssurance output file
  $GeneratedTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedTestResultsPathConfigRootKey']]
  $GeneratedUnitTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']]
  $GeneratedIntegrationTestResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']]
  $GeneratedTestCoverageResultsPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']]

  # The locations for documentation output file
  $GeneratedDocumentationDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']]
  $GeneratedStaticSiteDocumentationDestinationPath = Join-Path '.' $global:settings[$global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']]

  # The location in the project repository where the release packages, release notes, and test results are stored
  $releaseDirectory = Join-Path '.' 'Releases'
  # This top-level directory in the repository should be created during repository creation, throw an error if it is not found during module build time
  if (-not $(Test-Path -Path $releaseDirectory -PathType Container)) {
    $message = "The release directory $releaseDirectory was not found. This directory should be created during repository creation."
    Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
    throw $message
  }

  # The PSRepositories required for packages destined for public powershell Repositories
  # $RepositoryNamePowershellGetDevelopmentFilesystemName = $global:settings[$global:configRootKeys['RepositoryNamePowershellGetDevelopmentPackageFilesystemConfigRootKey']]

  # $TestFile = "$PSScriptRoot\output\TestResults_PS$PSVersion`_$TimeStamp.xml"


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
  Outputs = $GeneratedPowershellModulePackagingDirectory
  Jobs    = {
    Write-PSFMessage -Level Debug -Message "Starting Task Clean; Configuration = $Configuration; BuildRoot = $BuildRoot; Encoding = $Encoding"
    Write-PSFMessage -Level Debug -Message "OriginalLocation = $OriginalLocation; BuildFile = $BuildFile"
    Write-PSFMessage -Level Debug -Message "WhatIf:$WhatIfPreference; -Verbose:$Verbosepreference; -Confirm:$ConfirmPreference"

    # clean the GeneratedPowershellModulePackagingDirectory. Remove the subdirectory for $moduleName and all of its children
    if ($PSCmdlet.ShouldProcess("$GeneratedPowershellModulePackagingDirectory", "Remove-Item -Force -Recurse -Path <target> -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue")) {
      # as a safety measure, ensure the directory name includes the pathpart \temp\
      if ($GeneratedPowershellModulePackagingDirectory -notmatch '\\temp\\') {
        $message = "GeneratedPowershellModulePackagingDirectory does not contain \temp\. GeneratedPowershellModulePackagingDirectory = $GeneratedPowershellModulePackagingDirectory"
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
      if ($(Test-Path -Path $GeneratedPowershellModulePackagingDirectory -PathType Container)) {
        # if it exists, delete it
        Remove-Item -Force -Recurse -Path $GeneratedPowershellModulePackagingDirectory -Verbose:$Verbosepreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
      }
      # Create a new packaging directory
      New-Item -ItemType Directory -Force $GeneratedPowershellModulePackagingDirectory >$null
    }
    # create generated output paths for the module
    New-Item -ItemType Directory -Force $GeneratedPowershellModulePackagingSourceDirectory >$null
    New-Item -ItemType Directory -Force $GeneratedPowershellModulePackagingIntermediateDirectory >$null
    New-Item -ItemType Directory -Force $GeneratedPowershellModulePackagingDistributionPackagesDirectory >$null


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
    $inputPathPattern = '.ps1$'
    $($sourceFiles.fullname -match $inputPathPattern)
  }
  Outputs = { $GeneratedModuleFilePath }
  Jobs    = {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildPSM1; GeneratedModuleFilePath = $GeneratedModuleFilePath; sourceFiles = $sourceFiles"
    [System.Text.StringBuilder]$PSM1text = [System.Text.StringBuilder]::new()
    foreach ($filePath in $sourceFiles) {
      Write-PSFMessage -Level Debug -Message "Importing [.$filePath]"
      [void]$PSM1text.AppendLine( "# .$filePath" )
      [void]$PSM1text.AppendLine( [System.IO.File]::ReadAllText($filePath) )
    }
    if ($PSCmdlet.ShouldProcess("$GeneratedModuleFilePath", "Set-Content -Path $GeneratedModuleFilePath -Encoding $encoding -Verbose:$Verbosepreference -Confirm:$ConfirmPreference having $($PSM1text.Length) characters")) {
      Write-PSFMessage -Level Debug -Message "Creating module [$GeneratedModuleFilePath]"
      if (-not $(Test-Path $GeneratedPowershellModulePackagingSourceDirectory -PathType Container)) { New-Item $GeneratedPowershellModulePackagingSourceDirectory -ItemType Directory -Force >$null }
      Set-Content -Path $GeneratedModuleFilePath -Value $PSM1text.ToString() -Encoding $encoding
    }
  }
}

Task BuildBasePSD1 @{
  Inputs  = {
    $sourceManifestPath
    $GeneratedModuleFilePath
  }
  Outputs = { $GeneratedBaseManifestFilePath }
  Jobs    = 'BuildPSM1', {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildBasePSD1; Inputs = $Inputs; Outputs = $Outputs"
    $currentManifest = Invoke-Expression $($(Get-Content $sourceManifestPath ) -join [System.Environment]::NewLine)
    Copy-Item $sourceManifestPath $GeneratedBaseManifestFilePath
    # calculate the appropriate next version
    $nextSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 1, 'alpha003', '') # Get-NextSemanticVersionNumber $highestSemanticVersion $highestSemanticVersionPackage -manifest $GeneratedManifestFilePath
    $nextMicrosoftVersion = '0.0.3' # Get-NextMicrosoftVersion $currentManifest

    $newManifestParams = @{
      Path          = $GeneratedBaseManifestFilePath
      ModuleVersion = $nextMicrosoftVersion #$nextSemanticVersion
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
    $assemblyFiles = @()
    $requiredModuleFiles = @()
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
    $assembliesPathPattern = '.dll$'
    foreach ($filePath in $($sourceFiles.fullname -match $assembliesPathPattern)) {
      # ToDo: handle cases where the .dll is not in the root of the module source
      # ToDo: handle cases where the module should run on Linux or MacOS
      $assemblyFiles += $(Get-ChildItem $filePath | Select-Object -ExpandProperty Name) # '.\' +
    }
    #ToDo: replace following with $PSModuleContentsToExport and $PSModuleSuportingFilesToPackage
    if ($publicFunctions.count) { $newManifestParams['FunctionsToExport'] = $publicFunctions }
    if ($publicCmdlets.count) { $newManifestParams['CmdletsToExport'] = $publicCmdlets }
    if ($exportedAliases.count) { $newManifestParams['Aliases'] = $exportedAliases }
    if ($exportedVariables.count) { $newManifestParams['Variables'] = $exportedVariables }
    if ($formatFiles.count) { $newManifestParams['FormatsToProcess'] = $formatFiles }
    if ($dscResourceFiles.count) { $newManifestParams['DscResourcesToExport'] = $dscResourceFiles }
    if ($toolsFiles.count) { $newManifestParams['ToolsToProcess'] = $toolsFiles }
    #$oldPSModulePath = $env:PSModulePath
    # Add the module root to the PSModulePath so the Update-moduleManifest can find the assemblies
    # $env:PSModulePath = $moduleroot + ';' + $oldPSModulePath
    #$requiredModuleFiles = @(,'C:\Dropbox\whertzing\PowerShell\Modules\platyPS\0.14.2\YamlDotNet.dll') # @("C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1") #@(, 'platyPS')
    #$requiredModuleFiles = @(,'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.dll') # @("C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1") #@(, 'platyPS')
    #$requiredModuleFiles = @(,'.\ATAP.Utilities.BuildTooling.PowerShell.dll') # @("C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\ATAP.Utilities.FileIO.PowerShell.psm1") #@(, 'platyPS')
    #$assemblyfiles = @(,'.\ATAP.Utilities.BuildTooling.PowerShell.dll') #@(, 'platyPS\0.14.2\YamlDotNet.dll') #C:\Dropbox\whertzing\PowerShell\Modules\
    # if ($requiredModuleFiles.count) { $newManifestParams['NestedModules'] = $requiredModuleFiles }
    # if ($assemblyFiles.count -or $requiredModuleFiles.count) { $env:PSModulePath = $oldPSModulePath }
    if ($assemblyFiles.count) {
      #$newManifestParams['RequiredAssemblies'] = $assemblyFiles
      #  $newManifestParams['RequiredModules'] = $currentManifest['RequiredModules'] + $assemblyFiles
    }
    Write-PSFMessage -Level Debug -Message "PSModulePath = variable" #
    Write-PSFMessage -Level Debug -Message "RequiredAssemblies = $($newManifestParams['RequiredAssemblies'])"
    Write-PSFMessage -Level Debug -Message "RequiredModules = $($newManifestParams['RequiredModules'])"
    Update-ModuleManifest @newManifestParams

  }
}

Task BuildPackageSpecificPSD1 @{
  Inputs  = $GeneratedBaseManifestFilePath
  Outputs = {
    foreach ($destination in $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory)) {
      Join-Path $destination $manifestFilename
    }
  }
  Jobs    = 'BuildBasePSD1', {
    Write-PSFMessage -Level Debug -Message "Starting Task BuildPackageSpecificPSD1; Inputs = $Inputs; Outputs = $Outputs"
    # Each provider and PackageLifecycle needs its own .psd1 and .nuspec file, along with the basic .psm1 file, and additional files as appropriate for the provider and lifecycle
    foreach ($destination in $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory )) {
      if (-not $(Test-Path $destination.Path -PathType Container)) { New-Item $destination.Path -ItemType Directory -Force >$null }
      # Copy the generated module file to each package intermediate directory
      Copy-Item $GeneratedModuleFilePath $destination.Path
      # copy the generated manifest file to each package intermediate directory
      Copy-Item $GeneratedBaseManifestFilePath $destination.Path
      # ToDo: modify psm1 or psd1 if needed for each specific package source directory
    }
  }
}


Task UnitTestPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildPSM1', {
    Write-PSFMessage -Level Debug -Message 'task = UnitTestPSModule'
    # [Pester Testing in Jenkins (Using NUNit)](https://sqlnotesfromtheunderground.wordpress.com/2017/01/20/pester-testing-in-jenkins-using-nunit/)
    # ToDo: update this so it collects test results and coverage results and publishes them to
    $TestResults = Invoke-Pester -Path $UnitTestsPath -PassThru -OutputFor JUnitXml -Tag Unit -ExcludeTag Slow, Disabled
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
  Jobs    = 'UnitTestPSModule', {
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
  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = GenerateHelpForPSModule'
  }
}

Task GenerateStaticSiteDocumentationForPSModule @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildPSM1', 'BuildPackageSpecificPSD1', 'UnitTestPSModule', 'IntegrationTestPSModule', 'GenerateReadMeMarkdownForPSModule', {
    Write-PSFMessage -Level Debug -Message 'task = GenerateStaticSiteDocumentationForPSModule'

  }
}

Task GenerateReadMeMarkdownForPSModule @{
  Inputs  = { $sourceReadMePath }
  Outputs = {
    # ToDo: replace 'ReadMe.md' with a string constant ($global:settings)
    foreach ($destination in $($(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory ))) {
      Join-Path $destination.Path 'ReadMe.md'
    }
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task = GenerateReadMeMarkdownForPSModule'
      $destinations = $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory )
    }
    Process {
      foreach ($sourcePath in $Inputs) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          Copy-Item $sourcePath $($destinations[$destinationIndex]).Path
        }
      }
    }
  }
}

Task GenerateReleaseNotesMarkdownForPSModule @{
  Inputs  = { $sourceReleaseNotesPath }
  Outputs = {
    # ToDo: replace 'ReadMe.md' with a string constant ($global:settings)
    foreach ($destination in $($(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory ))) {
      Join-Path $destination.Path 'ReleaseNotes.md'
    }
  }
  Jobs    = {
    Write-PSFMessage -Level Debug -Message 'task = GenerateReleaseNotesMarkdownForPSModule'
    $destinations = $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory )
    foreach ($sourcePath in $Inputs) {
      for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
        Copy-Item $sourcePath $($destinations[$destinationIndex]).Path
      }
    }
  }
}

Task CopyTestFilesForPSModule @{
  Inputs  = { $testFileInfos.fullname }
  Outputs = {
    # ToDo: would prefer to reference the $inputs instead of the contents of $inputs, but cant make it work
    # ToDo: replace 'QualityAssurance' with an Enumeration ToString()
    # ToDo: replace 'tests' with a string constant ($global:settings)
    foreach ($destination in $($(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix 'tests')) | Where-Object { $_.PackageLifeCycle -match 'QualityAssurance' } ) {
      foreach ($testfileInfo in  [System.Collections.Generic.List[System.IO.FileInfo]] $testFileInfos) {
        Join-Path $destination.Path $testFileInfo.Name
      }
    }
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task = CopyTestFilesForPSModule'
      # The Test files are only copied to the Quality Assurance packages
      # ToDo: move the subdirectory 'test' into string constants ($global:settings)
      $destinations = $($(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix 'tests')) | Where-Object { $_.PackageLifeCycle -match 'QualityAssurance' }
    }
    Process {
      # powershell will cast an array of a single element to  a string if
      foreach ($testFileInfo in $testFileInfos) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          Copy-Item $testFileInfo.fullname $($destinations[$destinationIndex]).Path
        }
      }
    }
  }
}

Task CopyAssembliesForPSModule @{
  Inputs  = {
    $inputPathPattern = '.dll$'
    $($sourceFiles.fullname -match $inputPathPattern)
  }
  Outputs = {
    # ToDo: problem referenceing $Inputs inside of Outputs block
    $assembliesPathPattern = '.dll$'
    $($sourceFiles.fullname -match $assembliesPathPattern) | ForEach-Object {
      $AssemblyPathInfo = $_
      foreach ($destination in $($(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory )) ) {
        Join-Path $destination.Path $AssemblyPathInfo.name
      }
    }
    'test'
  }
  Jobs    = {
    Begin {
      Write-PSFMessage -Level Debug -Message 'task = CopyAssembliesForPSModule'
      $destinations = $($(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory ))
    }
    Process {
      foreach ($AssemblyPathInfo in $Inputs) {
        for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
          # ToDo: handle cases where the .dll is not in the root of the module source
          # ToDo: handle cases where the module should run on Linux or MacOS
          Copy-Item $AssemblyPathInfo $destinations[$destinationIndex].Path
        }
      }
    }
  }
}

Task BuildNuSpecFromManifest @{
  Inputs  = {
    $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
  }
  Outputs = {
    $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix $NuSpecFilename).Path
  }
  Jobs    = 'BuildPackageSpecificPSD1', 'GenerateReleaseNotesMarkdownForPSModule', 'GenerateReadMeMarkdownForPSModule', 'CopyTestFilesForPSModule', 'CopyAssembliesForPSModule', {
    Write-PSFMessage -Level Debug -Message 'task = BuildNuSpecFromManifest; inputs = $inputs ; outputs = $outputs'
    $destinations = makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory
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
        $message = "calling Get-NuSpecFromManifest with -ManifestPath $GeneratedManifestFilePath -DestinationFolder $destination.Path -ProviderName $destination.ProviderName threw an error : $($error[0]|Select-Object * )"
        Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'BuildNuSpecFromManifest'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
  }
}

Task AddReadMeToNuSpec @{
  # this task modifies its inputs, so, there are no output dependencies, it has to run
  # Inputs  = {
  #   $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
  # }
  # Outputs = $GeneratedModuleFilePath
  Jobs = 'BuildNuSpecFromManifest', {
    Write-PSFMessage -Level Debug -Message 'task = BuildNuSpecFromManifest'
    $destinations = makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory
    for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
      $nuSpecFilePath = Join-Path $destinations[$destinationIndex].Path $NuSpecFilename
      # Read the NuSpec file
      $nuSpecLines = [System.Collections.ArrayList](Get-Content $nuSpecFilePath )
      # Add the readme and any other files. Add before the </metadata> line
      # ToDo - define a lambda that matches the </metadata> line without needing to rely on exactly four spaces
      # then use the answer provided by dcastro in [Use regex inside Array.indexof in c#.net to find the index of element(https://stackoverflow.com/questions/18758262/use-regex-inside-array-indexof-in-c-net-to-find-the-index-of-element)]
      # myList.FindIndex(s => new Regex(@"3\s*\-\s*6").Match(s).Success);
      # $insertIndex = $nuSpecLinest.FindIndex(s => new Regex("metadata").Match(s).Success)
      # need the lambda that does the "s => new Regex("metadata").Match(s).Success" part of above
      # ToDo: wrap in a try/catch block if the IndexOf operation returns -1
      $insertIndex = $nuSpecLines.IndexOf('    </metadata>')
      # and then get the number of spaces found before the tag, and append that many spaces to the new lines
      $numspaces = 4
      # $nuSpecLines.Insert(($insertIndex + 1), " "*$numspaces + '<files>')
      # $nuSpecLines.Insert(($insertIndex + 2), " "*$numspaces + '  <file src="readme.md" target="" />')
      # $nuSpecLines.Insert(($insertIndex + 3), " "*$numspaces + '</files>')
      # add before the </metadata> line
      $nuSpecLines.Insert(($insertIndex ), ' ' * $numspaces + '  <readme>readme.md</readme>')

      # <!-- Add files from an arbitrary folder that's not necessarily in the project -->
      # <file src="..\..\SomeRoot\**\*.*" target="" />

      # write the modified nuSpac lines back out to the nuSpec file
      $nuSpecLines | Set-Content $nuSpecFilePath
    }
  }
}

Task BuildNuGetPackage @{
  Inputs  = {
    $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix $manifestFilename).Path
    $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix $NuSpecFilename).Path
    $(makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory -suffix $moduleFilename).Path
  }

  Outputs = {
    $(makeitup -prefix $GeneratedPowershellModulePackagingDistributionPackagesDirectory -suffix $moduleFilename).Path
  }
  Jobs    = 'AddReadMeToNuSpec', {
    Write-PSFMessage -Level Debug -Message 'task = BuildNuGetPackage'
    # ToDo: logic to select Dev, QA, Production package(s) to build
    $destinations = makeitup -prefix $GeneratedPowershellModulePackagingIntermediateDirectory
    for ($destinationIndex = 0; $destinationIndex -lt $destinations.count; $destinationIndex++) {
      $nuSpecFilePath = Join-Path $destinations[$destinationIndex].Path $NuSpecFilename
      $distributionPackagesDirectory = Join-Path $GeneratedPowershellModulePackagingDistributionPackagesDirectory $destinations[$destinationIndex].Provider $destinations[$destinationIndex].PackageLifeCycle
      # ensure the directory exists, silently create it if not
      if (-not $(Test-Path $distributionPackagesDirectory -PathType Container)) { New-Item $distributionPackagesDirectory -ItemType Directory -Force >$null }
      try {
        # Start-Process -FilePath $global:settings[$global:configRootKeys['NuGetExePathConfigRootKey']] -ArgumentList "-jar $jenkinsCliJarFile -groovy Get-JenkinsPlugins.groovy' -PassThru
        ## don't create window for this process.
        #  ToDo: -NoPackageAnalysis silences the warnings regarding test files int eh QA package, but it would be better if the single warning could be silenced and still fo package analysis to catch other errors
        Start-Process NuGet -ArgumentList "pack $nuSpecFilePath -OutputDirectory $distributionPackagesDirectory -Verbosity quiet -NoPackageAnalysis" -NoNewWindow >$null
      }
      catch {
        $message = "calling nuget with argument list pack $nuSpecFilePath -OutputDirectory $distributionPackagesDirectory threw an error "
        Write-PSFMessage -Level Error -Message $message -Tag 'Invoke-Build', 'BuildNuGetPackage'
        # toDo catch the errors, add to 'Problems'
        Throw $message
      }
    }
  }
}


Task SignPSPackages @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'BuildNuGetPackage', {
    Write-PSFMessage -Level Debug -Message 'task = SignPSPackages'
  }
}

Task PublishPSPackage @{
  Inputs  = $sourceFiles
  Outputs = $GeneratedModuleFilePath
  Jobs    = 'SignPSPackages', { #
    Write-PSFMessage -Level Debug -Message 'task = PublishPSPackage'
    $providerNames | ForEach-Object { $ProviderName = $_
      $packageLifecycles | ForEach-Object { $PackageLifecycle = $_
        # The NuPackage file has been generated to the same directory as the manifest file
        $GeneratedFullPackageIntermediateDirectory = Join-Path $GeneratedPowershellModulePackagingIntermediateDirectory $ProviderName $PackageLifecycle
        #temp
        $moduleNameAndVersion = 'ATAP.Utilities.BuildTooling.PowerShell.0.0.1-alpha003'
        $GeneratedFullPackageDestinationPath = Join-Path $GeneratedFullPackageIntermediateDirectory $($moduleNameAndVersion + '.nupkg')

        # Publish all packages to the FileSystem repositories
        # Publish all packages to the Internal

        $StorageMechanisms | ForEach-Object { $StorageMechanism = $_

          # Lookup the details of the appropriate repository to publish to
          # ToDO: use global:settings or global:configrootKeys

          $PSRepositoryKey = 'Repository' + $ProviderName + $PackageLifecycle + $StorageMechanism + 'Package'
          $PSRepositoryName = $global:settings.PackageRepositoriesCollection[$PSRepositoryKey]
          $NuGetAPIKey = 'Repository' + $ProviderName + $PackageLifecycle + $StorageMechanism + 'Package'
          $nuGetApiValue = $global:settings[$global:configRootKeys['NuGetApiKeyConfigRootKey']]

          switch ($StorageMechanism) {
            'FileSystem' {
              $PSRepositoryName = 'LocalDevelopmentPSRepository'
              Publish-Module -Path $relativeModulePath -Repository $PSRepositoryName -NuGetApiKey $nuGetApiKey

            }
            'InternalWebServer' {
              $PSRepositoryName = 'InternalWebServerPSRepository'
            }
            'PublicWebServer' {
              $PSRepositoryName = 'PublicWebServerPSRepository'
            }
          }
          # Publish all packages to the FileSystem repositories
          # Publish all packages to the InternalWebServer repositories
          # publish production packages for the PublicWebServer to a "FinalInspectionStagingArea"

        }
      }
    }
    # Switch on Environment
    # Publish to FileSystem
    #Publish-Module -Path $relativeModulePath -Repository $PSRepositoryName -NuGetApiKey $nuGetApiKey
    #Publish-Module -Name $GeneratedPowershellGetModulesPath -Repository LocalDevelopmentPSRepository
    # Copy last build artifacts into a .7zip file, name it after the ModuleName-Version-buildnumber (like C# project assemblies)
    # Check the 7Zip file into the SCM repository
    # Get SHA-256 and other CRC checksums, add that info to the SCM repository
    # Publish the Production PSModule to the three repositories
    # Publish the checksums to the internet
    # Update the SCM repository metadata to associate the published Module
  }
}

# Default task.
Task . BuildPSM1, BuildPSD1, BuildPackageSpecificPSD1, BuildNuSpecFromManifest, BuildNuGetPackage , PublishPSPackage # UnitTestPSModule


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
# $nextSemanticVersion = [System.Management.Automation.SemanticVersion]::new(0, 0, 1, 'alpha003', '') # Get-NextSemanticVersionNumber $highestSemanticVersion $highestSemanticVersionPackage -manifest $GeneratedManifestFilePath

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
# $highestVersionProductionManifest = $null


# # $highestVersion = [version] (Get-Metadata -Path $highestVersionManifestPath -PropertyName 'ModuleVersion')
# # $highestVersionProduction = [version] (Get-Metadata -Path $highestVersionProductionManifest -PropertyName 'ModuleVersion')
# # $sourceManifestVersion = [version] (Get-Metadata -Path $sourceManifestPath -PropertyName 'ModuleVersion')

# # Compare the names of the Public / Private / Resource / Tools files in the $sourceFiles to the names of the Public / Private / Resource / Tools files in the highest production manifest, and
# # Determine if the source files represents a Major/Minor/Patch/PreRelease version bump compared to the highest production version (ToDo: allow manual indication for a version bump)
# #ToDo: when run by a developer (not CI) if source is a prerelease, but major/minor values disagree with $sourcefiles comparasion, prompt/guide user interaction to pick a correct semantic version value


# $bumpVersionType = '' #InitialDeployment, NewMajor, ,NewMajorPreRelease, NewMinor, NewMinorPreRelease, Patch, PatchPreRelease
# #$nextSemanticVersion

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


