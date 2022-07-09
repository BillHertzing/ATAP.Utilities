
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

# only set the value of the Environment Environment variable if it has not been set by a calling process
$inheritedEnvironmentVariable = [System.Environment]::GetEnvironmentVariable('Environment')
$inProcessEnvironmentVariable = ''
if ($inheritedEnvironmentVariable) {
  $inProcessEnvironmentVariable = $inheritedEnvironmentVariable
}
else {
  $inProcessEnvironmentVariable = 'Production' # default for all machines is Production, can be overwritten on a per-process basis if needed
}


$global:MachineAndNodeSettings = @{
  # Settings common to all machines
  'AllCommon' = @{
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']        = Join-Path $env:ProgramData 'chocolatey' 'lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']        = Join-Path $env:ProgramData 'chocolatey' 'bin'

    # Jenkins CI/CD confguration keys
    # These used to access a Jenkins Controller and Authenticate

    $global:configRootKeys['JENKINS_URLConfigRootKey']             = 'http://utat022:4040/'
    $global:configRootKeys['JENKINS_USER_IDConfigRootKey']         = 'whertzing'
    $global:configRootKeys['JENKINS_API_TOKENConfigRootKey']       = '117e33cc37af54e0b4fc6cb05de92b3553' # the value from the configuration page ToDo: use Secrets GUID/file

    $global:configRootKeys['MSBuildExePathConfigRootKey']          = Join-Path $env:ProgramFiles 'Microsoft Visual Studio' '2022' 'Community' 'Msbuild' 'Current' 'Bin' 'MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']           = Join-Path $env:ProgramFiles 'dotnet' 'dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']            = Join-Path $env:ProgramData 'chocolatey' 'bin' 'docfx.exe'
    $global:configRootKeys['GraphvizExePathConfigRootKey']         = Join-Path $env:ProgramFiles 'graphviz' 'bin' 'dot.exe'
    $global:configRootKeys['CommonJarsBasePathConfigRootKey']      = Join-Path $env:ProgramData 'CommonJars'

    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # Join-Path 'C:' 'OneDrive'

    # Structure of package drop locations; File Server Shares (fss) and Web Server URLs for the Environment stages
    $global:configRootKeys['FileSystemDropsBasePathConfigRootKey'] = @{
      'Production'  = '\\fs\ProductionPackages'
      'Testing'     = '\\fs\TestingPackages'
      'Development' = '\\fs\DevelopmentPackages'
    }
    $global:configRootKeys['WebServerDropsBaseURLConfigRootKey']   = @{
      'Production'  = 'http://ws/ngf'
      'Testing'     = 'http://ws/ngf/qa'
      'Development' = 'http://ws/ngf/dev'
    }

    $global:configRootKeys['ENVIRONMENTConfigRootKey']             = $inProcessEnvironmentVariable

  }
}
switch ($hostname) {
  # Machine Settings
  'utat01' { $global:MachineAndNodeSettings['utat01'] = @{
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
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
  }
  'utat022' { $global:MachineAndNodeSettings['utat022'] = @{
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'D:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'D:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
      $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = Join-Path $env:ProgramFiles 'erl-24.0'
      $global:configRootKeys['GitExePathConfigRootKey']                                 = Join-Path $env:ProgramFiles 'Git' 'cmd' 'git.exe'
      $global:configRootKeys['JavaExePathConfigRootKey']                                = Join-Path $env:ProgramFiles 'Eclipse Adoptium' 'jre-17.0.2.8-hotspot','bin','java.exe'
      $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']                           = 'filesystem:' + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities' 'Databases' 'ATAPUtilities' 'Flyway' 'sql')
      $global:configRootKeys['FLYWAY_URLConfigRootKey']                                 = 'jdbc:sqlserver://localhost:1433;databaseName=ATAPUtilities'
      $global:configRootKeys['FLYWAY_USERConfigRootKey']                                = 'AUADMIN'
      $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']                            = 'NotSecret'
      $global:configRootKeys['FP__projectNameConfigRootKey']                            = 'ATAPUtilities'
      $global:configRootKeys['FP__projectDescriptionConfigRootKey']                     = 'Test Flyway and Pubs samples'
      $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
        $global:configRootKeys['WindowsCodeBuildConfigRootKey']
        , $global:configRootKeys['WindowsUnitTestConfigRootKey']
        , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
      )
      # Should only be set per machine if the machine is a Jenkins Controller Node
      $global:configRootKeys['JENKINS_HOMEConfigRootKey']                               = Join-Path 'C:' 'Dropbox' 'JenkinsHome','.jenkins'
      $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
      $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
      $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
      $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
      $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft SQL Server' '150' 'Tools' 'PowerShell' 'Modules'
    }
  }
  'ncat016' { $global:MachineAndNodeSettings['ncat016'] = @{
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'C:' 'Dropbox'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'D:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'D:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'D:' 'Temp' 'Insecure'
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
  'ncat041' { $global:MachineAndNodeSettings['ncat041'] = @{
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'c:' 'Dropbox'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
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
  }
  'ncat-ltb1' { $global:MachineAndNodeSettings['ncat-ltb1'] = @{
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'c:' 'Dropbox'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
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
  'ncat-ltjo' { $global:MachineAndNodeSettings['ncat-ltjo'] = @{
      $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
      $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = Join-Path 'D:' 'Dropbox'
      $global:configRootKeys['FastTempBasePathConfigRootKey']                           = Join-Path 'C:' 'Temp'
      $global:configRootKeys['BigTempBasePathConfigRootKey']                            = Join-Path 'C:' 'Temp'
      $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = Join-Path 'C:' 'Temp' 'Insecure'
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
}

# values that vary slightly from machine to machine, that are built upon per-machine settings in the same fashion
#  the values of these entries are EXECUTED in the profile

$local:ToBeExecutedGlobalSettings = [ordered]@{
}

# If a global variable already exists, append the local information
# This supports the ability to have multiple files define these values
if ($global:ToBeExecutedGlobalSettings) {
  # Load the $global:ToBeExecutedGlobalSettings with the $Local:ToBeExecutedGlobalSettings
  $global:ToBeExecutedGlobalSettings.Keys | ForEach-Object {
    # ToDo error hanlding if one fails
    $global:ToBeExecutedGlobalSettings[$_] = $local:ToBeExecutedGlobalSettings[$_] # Invoke-Expression $global:SecurityAndSecretsSettings[$_]
  }
}
else {
  $global:ToBeExecutedGlobalSettings = $Local:ToBeExecutedGlobalSettings
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
