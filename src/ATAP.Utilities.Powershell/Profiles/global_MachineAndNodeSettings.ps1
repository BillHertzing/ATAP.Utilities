
$DropBoxBaseDirConfigRootDefault = ''
$FastTempPathConfigRootDefault = ''
$WindowsDocumentationBuildConfigRootKey = 'WindowsDocumentationBuild'
$WindowsDocumentationBuildConfigRootDefault = ''
$WindowsCodeBuildConfigRootKey = 'WindowsCodeBuild'
$WindowsCodeBuildConfigRootDefault = ''
$WindowsUnitTestConfigRootKey = 'WindowsUnitTest'
$WindowsUnitTestConfigRootDefault = ''
$PlantUmlClassDiagramGeneratorPathConfigRootKey = 'PlantUmlClassDiagramGeneratorPath'
$GitExeConfigRootKey = 'GitPath'
$GitExeConfigRootDefault = ''

$global:RequiredMachineSettingsList = @($DropBoxBaseDirConfigRootKey, $FastTempPathConfigRootKey)

$global:SupportedJenkinsRolesList = @($WindowsDocumentationBuildConfigRootKey, $WindowsCodeBuildConfigRootKey, $WindowsUnitTestConfigRootKey)

$global:MachineAndNodeSettings = @{
  # Machine Settings
  'utat01'                               = @{
    $global:configRootKeys['DropBoxBaseDirConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:\Program Files\Git\cmd\git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @{}
  }
  'ncat016'                              = @{
    $global:configRootKeys['DropBoxBaseDirConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'D:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'D:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:\Program Files\Git\cmd\git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @{
      $global:configRootKeys['WindowsCodeBuildConfigRootKey'] = @{
        $global:configRootKeys['MSBuildExePathConfigRootKey'] = 'C:\Program Files\Microsoft Visual Studio\2022\Community\Msbuild\Current\Bin\MSBuild.exe'
        $global:configRootKeys['DotnetExePathConfigRootKey'] = 'C:\Program Files\dotnet\dotnet.exe'
      }
      $global:configRootKeys['WindowsUnitTestConfigRootKey'] = @{}
      $global:configRootKeys['WindowsDocumentationBuildConfigRootKey'] = @{
        $global:configRootKeys['DocFXExePathConfigRootKey'] = 'C:\ProgramData\chocolatey\bin\docfx.exe'
        $global:configRootKeys['PlantUMLJarPathConfigRootKey'] = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
        $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey'] = 'C:\Users\whertzing\.dotnet\tools\puml-gen.exe'
        $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
      }
    }
  }
  'ncat041'                              = @{
    $global:configRootKeys['DropBoxBaseDirConfigRootKey'] = 'C:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:\Program Files\Git\cmd\git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @{}
  }
  'ncat-ltb1'                          = @{
    $global:configRootKeys['DropBoxBaseDirConfigRootKey'] = 'D:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:\Program Files\Git\cmd\git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @{}
  }
  'ncat-ltjo'                          = @{
    $global:configRootKeys['DropBoxBaseDirConfigRootKey'] = 'D:/Dropbox/'
    $global:configRootKeys['FastTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey'] = 'C:/Temp'
    $global:configRootKeys['GitExePathConfigRootKey'] = 'C:\Program Files\Git\cmd\git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey'] = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
    $global:configRootKeys['JenkinsNodeRolesConfigRootKey'] = @{}
  }
}

$global:JenkinsRoles = @{
  $WindowsDocumentationBuildConfigRootKey   = @{
    PowershellCmdlet = 'Build-ImageFromPlantUML.ps1'
  }
  $WindowsCodeBuildConfigRootKey            = @{
    DotnetToolExePath = 'C:\Program Files\dotnet\'
  }
  LinuxBuild                                = @{}
  MacOSBuild                                = @{}
  AndroidBuild                              = @{}
  iOSBuild                                  = @{}
  $WindowsUnitTestConfigRootKey             = @{
    xUnitConsoleTestRunnerPackage = ''
    xUnitJenkinsPluginPackage     = ''
  }
  LinuxUnitTest                             = @{}
  MacOSUnitTest                             = @{}
  AndroidUnitTest                           = @{}
  iOSUnitTest                               = @{}
  MSSQLDataBaseIntegrationTest              = @{
    ConnectionString = 'localhost:1433'
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
