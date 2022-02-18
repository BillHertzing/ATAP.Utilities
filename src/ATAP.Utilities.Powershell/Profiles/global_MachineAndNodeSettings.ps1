
# $DropBoxBasePathConfigRootDefault = ''
# $FastTempPathConfigRootDefault = ''
# $PlantUmlClassDiagramGeneratorPathConfigRootKey = 'PlantUmlClassDiagramGeneratorPath'
# $GitExeConfigRootKey = 'GitPath'
# $GitExeConfigRootDefault = ''
$PathToProjectOrSolutionFilePattern = '(.*)\.(sln|csproj)'

$global:RequiredMachineSettingsList = @($global:configRootKeys['CloudBasePathConfigRootKey'], $global:configRootKeys['FastTempPathConfigRootKey'])

$global:SupportedJenkinsRolesList = @($global:configRootKeys['WindowsDocumentationBuildConfigRootKey'], $global:configRootKeys['WindowsCodeBuildConfigRootKey'], $global:configRootKeys['WindowsUnitTestConfigRootKey'])

$global:WindowsUnitTestList = @("Run-WindowsUnitTests")

$global:WindowsUnitTestArgumentsList = @("PathToProjectOrSolutionFilePattern", "PathToTestLog")

$global:MachineAndNodeSettings = @{
  # Machine Settings
  'utat01'    = @{
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'utat022'   = @{
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'D:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat016'   = @{
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'D:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat041'   = @{
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat-ltb1' = @{
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'D:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'
  }
  'ncat-ltjo' = @{
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'D:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']                            = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
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
    $global:configRootKeys['PSModulePathConfigRootKey']    = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
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
