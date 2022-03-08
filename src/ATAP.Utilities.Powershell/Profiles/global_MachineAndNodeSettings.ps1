
# $DropBoxBasePathConfigRootDefault = ''
# $FastTempPathConfigRootDefault = ''
# $PlantUmlClassDiagramGeneratorPathConfigRootKey = 'PlantUmlClassDiagramGeneratorPath'
# $GitExeConfigRootKey = 'GitPath'
# $GitExeConfigRootDefault = ''
$PathToProjectOrSolutionFilePattern = '(.*)\.(sln|csproj)'

$global:RequiredMachineSettingsList = @($global:configRootKeys['CloudBasePathConfigRootKey'], $global:configRootKeys['FastTempPathConfigRootKey'])

$global:SupportedJenkinsRolesList = @($global:configRootKeys['WindowsDocumentationBuildConfigRootKey'], $global:configRootKeys['WindowsCodeBuildConfigRootKey'], $global:configRootKeys['WindowsUnitTestConfigRootKey'])

$global:WindowsUnitTestList = @('Run-WindowsUnitTests')

$global:WindowsUnitTestArgumentsList = @('PathToProjectOrSolutionFilePattern', 'PathToTestLog')

$global:MachineAndNodeSettings = @{
  # Settings common to all machines
  'AllCommon' = @{
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']  = Join-Path $env:ProgramData 'chocolatey' 'lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']  = Join-Path $env:ProgramData 'chocolatey' 'bin'

    $global:configRootKeys['JENKINS_URLConfigRootKey']       = 'http://ncat016:4040/'
    $global:configRootKeys['JENKINS_USER_IDConfigRootKey']   = 'whertzing'
    $global:configRootKeys['JENKINS_API_TOKENConfigRootKey'] = '117e33cc37af54e0b4fc6cb05de92b3553' # the value from the configuration page ToDo: use Secrets GUID/file

    $global:configRootKeys['MSBuildExePathConfigRootKey']    = Join-Path $env:ProgramFiles 'Microsoft Visual Studio' '2022' 'Community' 'Msbuild' 'Current' 'Bin' 'MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']     = Join-Path $env:ProgramFiles 'dotnet' 'dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']      = Join-Path $env:ProgramData 'chocolatey' 'bin' 'docfx.exe'
    $global:configRootKeys['GraphvizExePathConfigRootKey']   = Join-Path $env:ProgramFiles 'graphviz' 'bin' 'dot.exe'
    $global:configRootKeys['CommonJarsBasePathConfigRootKey']   = Join-Path $env:ProgramData 'CommonJars'

  }
  # Machine Settings
  'utat01'    = @{
    $global:configRootKeys['EnvironmentConfigRootKey']                                = 'Production'
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path -Path $env:HOMEDRIVE -ChildPath 'Dropbox'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'utat022'   = @{
    $global:configRootKeys['EnvironmentConfigRootKey']                                = 'Production'
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path -Path $env:HOMEDRIVE -ChildPath 'Dropbox'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'D:/Temp'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
    $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']                           = 'filesystem:' + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities' 'Databases' 'ATAPUtilities' 'Flyway' 'sql')
    $global:configRootKeys['FLYWAY_URLConfigRootKey']                                 = 'jdbc:sqlserver://localhost:1433;databaseName=ATAPUtilities'
    $global:configRootKeys['FLYWAY_USERConfigRootKey']                                = 'AUADMIN'
    $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']                            = 'NotSecret'
    $global:configRootKeys['FP__projectNameConfigRootKey']                            = 'ATAPUtilities'
    $global:configRootKeys['FP__projectDescriptionConfigRootKey']                     = 'Test Flyway and Pubs samples'
    $global:configRootKeys['JENKINS_URLConfigRootKey']                                = 'http://utat022:4040/'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'PowerShell' 'Modules'
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat016'   = @{
    $global:configRootKeys['EnvironmentConfigRootKey']                                = 'Production'
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path -Path $env:HOMEDRIVE -ChildPath 'Dropbox'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'D:/Temp'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'PowerShell' 'Modules'
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat041'   = @{
    $global:configRootKeys['EnvironmentConfigRootKey']                                = 'Production'
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path -Path $env:HOMEDRIVE -ChildPath 'Dropbox'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat-ltb1' = @{
    $global:configRootKeys['EnvironmentConfigRootKey']                                = 'Production'
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path -Path $env:HOMEDRIVE -ChildPath 'Dropbox'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'PowerShell' 'Modules'
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat-ltjo' = @{
    $global:configRootKeys['EnvironmentConfigRootKey']                                = 'Production'
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path -Path 'D:' -ChildPath 'Dropbox'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'AdoptOpenJDK' 'jre-16.0.1.9-hotspot' 'bin' 'java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'PowerShell' 'Modules'
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
}

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
    $global:configRootKeys['PSModulePathConfigRootKey']              = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'PowerShell' 'Modules'
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
