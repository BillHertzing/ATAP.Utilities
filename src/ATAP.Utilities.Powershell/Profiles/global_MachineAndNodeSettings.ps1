
# $DropBoxBasePathConfigRootDefault = ''
# $FastTempPathConfigRootDefault = ''
# $PlantUmlClassDiagramGeneratorPathConfigRootKey = 'PlantUmlClassDiagramGeneratorPath'
# $GitExeConfigRootKey = 'GitPath'
# $GitExeConfigRootDefault = ''
$PathToProjectOrSolutionFilePattern = '(.*)\.(sln|csproj)'

#$global:RequiredMachineSettingsList = @($global:configRootKeys['CloudBasePathConfigRootKey'], $global:configRootKeys['FastTempPathConfigRootKey'])

# $global:SupportedJenkinsRolesList = @($global:configRootKeys['WindowsDocumentationBuildConfigRootKey'], $global:configRootKeys['WindowsCodeBuildConfigRootKey'], $global:configRootKeys['WindowsUnitTestConfigRootKey'], $global:configRootKeys['WindowsIntegrationTestConfigRootKey'])

$global:WindowsUnitTestList = @('Run-WindowsUnitTests')

$global:WindowsUnitTestArgumentsList = @('PathToProjectOrSolutionFilePattern', 'PathToTestLog')

# only set the value of the Environment Environment variable if it has not been set by a calling process
$inheritedEnvironmentVariable = [System.Environment]::GetEnvironmentVariable('Environment')
$inProcessEnvironmentVariable = ''
if ($inheritedEnvironmentVariable) {
  $inProcessEnvironmentVariable = $inheritedEnvironmentVariable
}
else {
  $inProcessEnvironmentVariable = 'Production' # default for all machines is Production, can be overwritten on a per-process basis if needed
}

$local:MachineAndNodeSettings = @{

  # Settings common to all machines

  # The location where Chocolatey installs some packages and some programs
  $global:configRootKeys['ChocolateyLibDirConfigRootKey']                                                          = Join-Path $env:ProgramData 'chocolatey' 'lib'
  $global:configRootKeys['ChocolateyBinDirConfigRootKey']                                                          = Join-Path $env:ProgramData 'chocolatey' 'bin'

  # These values are specific to the way an organization defines and sets up the access to and use of 3rd party applications
  $global:configRootKeys['MSBuildExePathConfigRootKey']                                                            = Join-Path $env:ProgramFiles 'Microsoft Visual Studio' '2022' 'Community' 'Msbuild' 'Current' 'Bin' 'MSBuild.exe'
  $global:configRootKeys['DotnetExePathConfigRootKey']                                                             = Join-Path $env:ProgramFiles 'dotnet' 'dotnet.exe'
  $global:configRootKeys['DocFXExePathConfigRootKey']                                                              = Join-Path $env:ProgramData 'chocolatey' 'bin' 'docfx.exe'
  $global:configRootKeys['GraphvizExePathConfigRootKey']                                                           = Join-Path $env:ProgramFiles 'graphviz' 'bin' 'dot.exe'
  $global:configRootKeys['CommonJarsBasePathConfigRootKey']                                                        = Join-Path $env:ProgramData 'CommonJars'

  # Jenkins CI/CD confguration keys
  # These used to access a Jenkins Controller and Authenticate

  $global:configRootKeys['JENKINS_URLConfigRootKey']                                                               = 'http://utat022:4040/'
  $global:configRootKeys['JENKINS_USER_IDConfigRootKey']                                                           = 'whertzing'
  $global:configRootKeys['JENKINS_API_TOKENConfigRootKey']                                                         = '117e33cc37af54e0b4fc6cb05de92b3553' # the value from the configuration page ToDo: use Secrets GUID/file

  # The repository names by which each of the various repositories for Powershell packages are known

  # $global:configRootKeys['RepositoryNamePowershellGalleryFilesystemDevelopmentPackageConfigRootKey']               = 'ReposistoryPowershellGalleryFilesystemDevelopmentPackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryFilesystemQualityAssurancePackageConfigRootKey']          = 'RepositoryPowershellGalleryFilesystemQualityAssurancePackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryFilesystemProductionPackageConfigRootKey']                = 'RepositoryPowershellGalleryFilesystemProductionPackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryWebServerTestDevelopmentPackageConfigRootKey']            = 'ReposistoryPowershellGalleryWebServerTestDevelopmentPackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryWebServerTestQualityAssurancePackageConfigRootKey']       = 'RepositoryPowershellGalleryWebServerTestQualityAssurancePackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryWebServerTestProductionPackageConfigRootKey']             = 'RepositoryPowershellGalleryWebServerTestProductionPackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryWebServerProductionDevelopmentPackageConfigRootKey']      = 'RepositoryPowershellGalleryWebServerProductionDevelopmentPackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryWebServerProductionQualityAssurancePackageConfigRootKey'] = 'RepositoryPowershellGalleryWebServerProductionQualityAssurancePackage'
  # $global:configRootKeys['RepositoryNamePowershellGalleryWebServerProductionProductionPackageConfigRootKey']       = 'RepositoryPowershellGalleryWebServerProductionProductionPackage'

  # Package Repositories
  $global:configRootKeys['CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey']                       = '\\utat022\fs'
  $global:configRootKeys['CurrentLocalPSGalleryWebServerPackageDropLocationBasePathConfigRootKey']                 = 'http://utat022:1010/PSGallery/'
  $global:configRootKeys['CurrentLocalNugetWebServerPackageDropLocationBasePathConfigRootKey']                     = 'http://utat022:2020/nuget/'
  $global:configRootKeys['CurrentLocalChocolateyServerPackageDropLocationBasePathConfigRootKey']                   = 'http://utat022:3030/chocolatey/'
  $global:configRootKeys['PublicPSGalleryWebServerPackageDropLocationBasePathConfigRootKey']                       = 'https://TBD/'
  $global:configRootKeys['PublicNugetWebServerPackageDropLocationBasePathConfigRootKey']                           = 'https://TBD/'
  $global:configRootKeys['PublicChocolateyServerPackageDropLocationBasePathConfigRootKey']                         = 'https://TBD/'

  # $global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']                                             = @{
  #   $global:configRootKeys['RepositoryNamePowershellGalleryFilesystemDevelopmentPackageConfigRootKey']               = '$global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] ' + $(Join-Path 'PowershellGallery' 'Development')
  #   $global:configRootKeys['RepositoryNamePowershellGalleryFilesystemQualityAssurancePackageConfigRootKey']          = '$global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] ' + $(Join-Path 'PowershellGallery' 'QualityAssurance')
  #   $global:configRootKeys['RepositoryNamePowershellGalleryFilesystemProductionPackageConfigRootKey']                = '$global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] ' + $(Join-Path 'PowershellGallery' 'Production')
  #   $global:configRootKeys['RepositoryNamePowershellGalleryWebServerTestDevelopmentPackageConfigRootKey']            = '$global:settings[$global:configRootKeys["CurrentLocalPSGalleryWebServerPackageDropLocationBasePathConfigRootKey"]] ' + 'PowershellGallery/Development'
  #   $global:configRootKeys['RepositoryNamePowershellGalleryWebServerTestQualityAssurancePackageConfigRootKey']       = '$global:settings[$global:configRootKeys["CurrentLocalPSGalleryWebServerPackageDropLocationBasePathConfigRootKey"]] ' + 'PowershellGallery/QualityAssurance'
  #   $global:configRootKeys['RepositoryNamePowershellGalleryWebServerTestProductionPackageConfigRootKey']             = '$global:settings[$global:configRootKeys["CurrentLocalPSGalleryWebServerPackageDropLocationBasePathConfigRootKey"]] ' + 'PowershellGallery/Production'
  #   $global:configRootKeys['RepositoryNamePowershellGalleryWebServerProductionDevelopmentPackageConfigRootKey']      = '$global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] ' + 'PowershellGallery/Development'
  #   $global:configRootKeys['RepositoryNamePowershellGalleryWebServerProductionQualityAssurancePackageConfigRootKey'] = '$global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] ' + 'PowershellGallery/QualityAssurance'
  #   $global:configRootKeys['RepositoryNamePowershellGalleryWebServerProductionProductionPackageConfigRootKey']       = '$global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] ' + 'PowershellGallery/Production'
  # }


  #     # Structure of package drop locations; File Server Shares (fss) and Web Server URLs for the Environment stages
  #     # ToDo: replace left LHS (key) of sub-hash with a long ConfigRootKey
  #     $global:configRootKeys['CurrentFileSystemNetworkPackageDropLocationsConfigRootKey']                         = @{
  #     'PowershellProduction'  = 'Join-Path $global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] "Powershell" "PowershellGalleryPackages" "ProductionPackages"'
  #     'PowershellTesting'     = 'Join-Path $global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] "Powershell" "PowershellGalleryPackages" "TestingPackages"'
  #     'PowershellDevelopment' = 'Join-Path $global:settings[$global:configRootKeys["CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey"]] "Powershell" "PowershellGalleryPackages" "DevelopmentPackages"'
  #   }

  #   $global:configRootKeys['WebServerDropsBaseURLConfigRootKey']                           = @{
  #     'Production'  = 'http://ws/ngf'
  #     'Testing'     = 'http://ws/ngf/QualityAssurance'
  #     'Development' = 'http://ws/ngf/Development'
  #   }

  # Structure of the subdirectories generated during the process of building a Powershell Module for public distribution
  $global:configRootKeys['GeneratedRelativePathConfigRootKey']                                                     = '_generated'
  $global:configRootKeys['GeneratedPowershellModuleConfigRootKey']                                                 = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "PowershellModule"'
  $global:configRootKeys['GeneratedPowershellGalleryPackageConfigRootKey']                                         = 'Join-Path $global:settings[$global:configRootKeys["GeneratedPowershellModuleConfigRootKey"]] "PowershellGalleryPackages"'
  $global:configRootKeys['GeneratedPowershellNuGetPackageConfigRootKey']                                           = 'Join-Path $global:settings[$global:configRootKeys["GeneratedPowershellModuleConfigRootKey"]] "PowershellNuGetPackages"'
  $global:configRootKeys['GeneratedPowershellChocolateyPackageConfigRootKey']                                      = 'Join-Path $global:settings[$global:configRootKeys["GeneratedPowershellModuleConfigRootKey"]] "PowershellChocolateyPackages"'

  # Structure of the subdirectories generated during the process of testing a Powershell Module or .net .DLL for public distribution
  $global:configRootKeys['GeneratedTestResultsPathConfigRootKey']                                                  = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "TestResults"'
  $global:configRootKeys['GeneratedUnitTestResultsPathConfigRootKey']                                              = 'Join-Path $global:settings[$global:configRootKeys["GeneratedTestResultsPathConfigRootKey"]] "UnitTests"'
  $global:configRootKeys['GeneratedIntegrationTestResultsPathConfigRootKey']                                       = 'Join-Path $global:settings[$global:configRootKeys["GeneratedTestResultsPathConfigRootKey"]] "IntegrationTests"'
  $global:configRootKeys['GeneratedTestCoverageResultsPathConfigRootKey']                                          = 'Join-Path $global:settings[$global:configRootKeys["GeneratedTestResultsPathConfigRootKey"]] "TestCoverage"'

  # Structure of the subdirectories generated during the process of building documentation for a Powershell Module or .net .DLL for public distribution
  $global:configRootKeys['GeneratedDocumentationDestinationPathConfigRootKey']                                     = 'Join-Path $global:settings[$global:configRootKeys["GeneratedRelativePathConfigRootKey"]] "Documentation"'
  $global:configRootKeys['GeneratedStaticSiteDocumentationDestinationPathConfigRootKey']                           = 'Join-Path $global:settings[$global:configRootKeys["GeneratedDocumentationDestinationPathConfigRootKey"]] "StaticSite"'

  $global:configRootKeys['ENVIRONMENTConfigRootKey']                                                               = $inProcessEnvironmentVariable
}

switch ($hostname) {
  # Machine Settings
  'utat01' {
    $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )%gl
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'utat022' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'D:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'D:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'Eclipse Adoptium' 'jre-17.0.2.8-hotspot', 'bin', 'java.exe'
      $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']                           = 'filesystem:' + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities' 'Databases' 'ATAPUtilities' 'Flyway' 'sql')
      $global:configRootKeys['FLYWAY_URLConfigRootKey']                                 = 'jdbc:sqlserver://localhost:1433;databaseName=ATAPUtilities'
      $global:configRootKeys['FLYWAY_USERConfigRootKey']                                = 'AUADMIN'
      $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']                            = 'NotSecret'
      $global:configRootKeys['FP__projectNameConfigRootKey']                            = 'ATAPUtilities'
      $global:configRootKeys['FP__projectDescriptionConfigRootKey']                     = 'Test Flyway and Pubs samples'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      # Should only be set per machine if the machine is a Jenkins Controller Node
      $global:configRootKeys['JENKINS_HOMEConfigRootKey']                               = Join-Path 'C:' 'Dropbox' 'JenkinsHome', '.jenkins'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
    }
  }
  'ncat016' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'D:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'D:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'D:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'ncat041' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/Powershell/Modules/')
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'ncat-ltb1' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
  'ncat-ltjo' { $local:MachineAndNodeSettings += @{
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'D:' 'Dropbox'
      $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
      $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = '$global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] '
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
      # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
      #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      # )
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'Join-Path $global:settings[$global:configRootKeys["ChocolateyLibDirConfigRootKey"]] "plantuml" "tools" "plantuml.jar"'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
    }
  }
}


# If a global variable already exists, append the local information
# This supports the ability to have multiple files define these values
# if ($global:ToBeExecutedGlobalSettings) {
#   # Load the $global:ToBeExecutedGlobalSettings with the $Local:ToBeExecutedGlobalSettings
#   $global:ToBeExecutedGlobalSettings.Keys | ForEach-Object {
#     # ToDo error hanlding if one fails
#     $global:ToBeExecutedGlobalSettings[$_] = $local:ToBeExecutedGlobalSettings[$_] # Invoke-Expression $global:SecurityAndSecretsSettings[$_]
#   }
# }
# else {
#   $global:ToBeExecutedGlobalSettings = $Local:ToBeExecutedGlobalSettings
# }


# Powershell Module Paths to be added for all users, per machine
# PSModulePathConfigRootKey

$global:JenkinsRoles = @{
  $global:configRootKeys['WindowsCodeBuildConfigRootKey']          = @(
    $global:configRootKeys['MSBuildExePathConfigRootKey']
    $global:configRootKeys['DotnetExePathConfigRootKey']
  )
  $global:configRootKeys['WindowsUnitTestConfigRootKey']           = @(
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']
  )
  $global:configRootKeys['WindowsDocumentationBuildConfigRootKey'] = @(
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']
    , $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']
    , $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey']

  )
  LinuxBuild                                                       = @{}
  MacOSBuild                                                       = @{}
  AndroidBuild                                                     = @{}
  iOSBuild                                                         = @{}
  LinuxUnitTest                                                    = @{}
  MacOSUnitTest                                                    = @{}
  AndroidUnitTest                                                  = @{}
  iOSUnitTest                                                      = @{}
  MSSQLDataBaseIntegrationTest                                     = @{
    # if the machine node has SQL server loaded, add to PSModulePath
    $global:configRootKeys['PSModulePathConfigRootKey']              = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'Powershell' 'Modules'
    $global:configRootKeys['SQLServerConnectionStringConfigRootKey'] = 'localhost:1433'
    Credentials                                                      = ''
  }
  MySQLDataBaseIntegrationTest                                     = @{}
  SQLiteDataBaseIntegrationTest                                    = @{}
  ServiceStackMSSQLDataBaseIntegrationTest                         = @{
    SERVICESTACK_LICENSE = '' # secrets guid
  }
  ServiceStackMySQLDataBaseIntegrationTest                         = @{}
  ServiceStackSQLiteDataBaseIntegrationTest                        = @{}
  DapperMSSQLDataBaseIntegrationTest                               = @{}
  DapperMySQLDataBaseIntegrationTest                               = @{}
  DapperSQLiteDataBaseIntegrationTest                              = @{}
  EFCoreMSSQLDataBaseIntegrationTest                               = @{}
  DynamicDataBaseIntegrationTest                                   = @{}
  SystemTextJsonSerializerIntegrationTest                          = @{}
  NewstonsoftSerializerIntegrationTest                             = @{}
  ServiceStackSerializerIntegrationTest                            = @{}
  DynamicSerializerIntegrationTest                                 = @{}
}

# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:MachineAndNodeSettings) {
  Write-PSFMessage -Level Debug -Message 'global:MachineAndNodeSettings are already defined '
  # Load the $global:MachineAndNodeSettings with the $Local:MachineAndNodeSettings
  $keys = $local_MachineAndNodeSettings.Keys
  foreach ($key in $keys ) {
    # ToDo error handling if one fails
    $global:MachineAndNodeSettings[$key] = $local_MachineAndNodeSettings[$key]
  }
}
else {
  Write-PSFMessage -Level Debug -Message 'global:MachineAndNodeSettings are NOT defined'
  $global:MachineAndNodeSettings = $local_MachineAndNodeSettings
}
