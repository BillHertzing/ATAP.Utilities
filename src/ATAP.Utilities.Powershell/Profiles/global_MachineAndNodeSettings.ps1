
# $DropBoxBasePathConfigRootDefault = ''
# $FastTempPathConfigRootDefault = ''
# $WindowsDocumentationBuildConfigRootKey = 'WindowsDocumentationBuild'
# $WindowsDocumentationBuildConfigRootDefault = ''
# $WindowsCodeBuildConfigRootKey = 'WindowsCodeBuild'
# $WindowsCodeBuildConfigRootDefault = ''
# $WindowsUnitTestConfigRootKey = 'WindowsUnitTest'
# $WindowsUnitTestConfigRootDefault = ''
# $PlantUmlClassDiagramGeneratorPathConfigRootKey = 'PlantUmlClassDiagramGeneratorPath'
# $GitExeConfigRootKey = 'GitPath'
# $GitExeConfigRootDefault = ''

$global:RequiredMachineSettingsList = @($global:configRootKeys['CloudBasePathConfigRootKey'], $global:configRootKeys['FastTempPathConfigRootKey'])

$global:SupportedJenkinsRolesList = @($global:configRootKeys['WindowsDocumentationBuildConfigRootKey'], $global:configRootKeys['WindowsCodeBuildConfigRootKey'], $global:configRootKeys['WindowsUnitTestConfigRootKey'])

$global:MachineAndNodeSettings = @{
  # Machine Settings
  'utat01'                               = @{
    $global:configRootKeys['CloudBasePathConfigRootKey'] = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey'] = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey'] = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:/Program Files/dotnet/dotnet.exe'
  }
  'utat022'                              = @{
    $global:configRootKeys['CloudBasePathConfigRootKey'] = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'D:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey'] = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey'] = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey'] = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey'] = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey'] = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey'] = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
  }
  'ncat016'                              = @{
    $global:configRootKeys['CloudBasePathConfigRootKey'] = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'D:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey'] = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey'] = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey'] = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey'] = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey'] = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey'] = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
  }
  'ncat041'                              = @{
    $global:configRootKeys['CloudBasePathConfigRootKey'] = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey'] = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey'] = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey'] = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey'] = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey'] = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
}
  'ncat-ltb1'                          = @{
    $global:configRootKeys['CloudBasePathConfigRootKey'] = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey'] = 'D:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey'] = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey'] = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey'] = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey'] = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey'] = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
}
  'ncat-ltjo'                          = @{
    $global:configRootKeys['CloudBasePathConfigRootKey'] = $global:configRootKeys['DropBoxBasePathConfigRootKey']
    $global:configRootKeys['DropBoxBasePathConfigRootKey'] = 'D:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['ChocolateyLibDirConfigRootKey'] = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey'] = 'C:/ProgramData/chocolatey/bin'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @(
      $global:configRootKeys['WindowsCodeBuildConfigRootKey']
      , $global:configRootKeys['WindowsUnitTestConfigRootKey']
      , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    )
    $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey'] = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['PlantUMLJarPathConfigRootKey'] = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey'] = 'C:/Users/whertzing/.dotnet/tools/puml-gen.exe'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
}
}

$global:JenkinsRoles = @{
  $global:configRootKeys['WindowsCodeBuildConfigRootKey']            = @(
    $global:configRootKeys['MSBuildExePathConfigRootKey']
    $global:configRootKeys['DotnetExePathConfigRootKey']
  )
  $global:configRootKeys['WindowsUnitTestConfigRootKey']             = @(
    $global:configRootKeys['xUnitConsoleTestRunnerPackage']
    $global:configRootKeys['xUnitJenkinsPluginPackage']
  )
  $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']   = @(
    $global:configRootKeys['PlantUMLJarPathConfigRootKey']
    , $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']
    ,  $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey']

  )
  LinuxBuild                                = @{}
  MacOSBuild                                = @{}
  AndroidBuild                              = @{}
  iOSBuild                                  = @{}
  LinuxUnitTest                             = @{}
  MacOSUnitTest                             = @{}
  AndroidUnitTest                           = @{}
  iOSUnitTest                               = @{}
  MSSQLDataBaseIntegrationTest              = @{
    # if the machine node has SQL server loaded, add to PSModulePath
    $global:configRootKeys['SQLServerPSModulePathsConfigRootKey'] = @('C:/Program Files (x86)/Microsoft SQL Server/150/Tools/PowerShell/Modules/')
    $global:configRootKeys['SQLServerConnectionStringConfigRootKey'] = 'localhost:1433'
    Credentials      = ''
  }
  MySQLDataBaseIntegrationTest              = @{}
  SQLiteDataBaseIntegrationTest             = @{}
  ServiceStackMSSQLDataBaseIntegrationTest  = @{
    SERVICESTACK_LICENSE = '' # secrets guid
  }
  ServiceStackMySQLDataBaseIntegrationTest  = @{}
  ServiceStackSQLiteDataBaseIntegrationTest = @{}
  DapperMSSQLDataBaseIntegrationTest        = @{}
  DapperMySQLDataBaseIntegrationTest        = @{}
  DapperSQLiteDataBaseIntegrationTest       = @{}
  EFCoreMSSQLDataBaseIntegrationTest        = @{}
  DynamicDataBaseIntegrationTest            = @{}
  SystemTextJsonSerializerIntegrationTest   = @{}
  NewstonsoftSerializerIntegrationTest      = @{}
  ServiceStackSerializerIntegrationTest     = @{}
  DynamicSerializerIntegrationTest          = @{}
}
