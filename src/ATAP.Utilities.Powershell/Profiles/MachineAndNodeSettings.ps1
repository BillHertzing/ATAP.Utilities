
$DropBoxBaseDirConfigRootKey = 'DropBoxBaseDir'
$DropBoxBaseDirConfigRootDefault = ''
$FastTempPathConfigRootKey = 'FastTempPath'
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
  utat01                               = @{
    $DropBoxBaseDirConfigRootKey = 'C:/Dropbox/'
    $GitExeConfigRootKey                   = 'C:\Program Files\Git\cmd\git.exe'
  }
  ncat016                              = @{
    $DropBoxBaseDirConfigRootKey = 'C:/Dropbox/'
    $GitExeConfigRootKey                    = 'C:\Program Files\Git\cmd\git.exe'
  }
  'ncat-ltb1'                          = @{ $DropBoxBaseDirConfigRootKey = 'D:/Dropbox/' }
  # Jenkins Node Settings
  WindowsDocumentationBuildJenkinsNode = @{
    PlantUmlClassDiagramGeneratorPath = 'C:\Users\whertzing\.dotnet\tools\puml-gen.exe'
    javaPath                          = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
    plantUMLJarPath                   = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
    docfxPath                         = 'C:\ProgramData\chocolatey\bin\docfx.exe'
  }
  WindowsCodeBuildJenkinsNode          = @{
    dotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
  }
}

$global:JenkinsRoles = @{
  $WindowsDocumentationBuildConfigRootKey   = @{
    DocFxExePath     = C:\ProgramData\chocolatey\bin\docfx.exe
    JavaExePath      = C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe
    PlantUMLJarPath  = tbd
    PowershellCmdlet = 'Build-ImageFromPlantUML.ps1'
  }
  $WindowsCodeBuildConfigRootKey            = @{
    DotnetToolExePath = C:\Program Files\dotnet\
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
  SystemTextJsonSerializerIntegrationTest   = @{}
  SystemTextJsonSerializerIntegrationTest   = @{}
  DynamicSerializerIntegrationTest          = @{}
}
