

$defaultPerRoleSettings = @{
  # Role Settings
  'AnsibleServers'           = @{
    # Used by Ansible to create a temporary directory on the remote host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey'] = 'C:/Temp/Ansible'

  }
  'Secrets Management'       = @{
  }
  'BuildServers'             = @{
    # These values are specific to the way an organization defines and sets up the access to and use of 3rd party applications
    $global:configRootKeys['MSBuildExePathConfigRootKey']                             = 'C:/Program Files/Microsoft Visual Studio/2022/Community/Msbuild/Current/Bin/MSBuild.exe'
    $global:configRootKeys['DotnetExePathConfigRootKey']                              = 'C:/Program Files/dotnet/dotnet.exe'
    $global:configRootKeys['DocFXExePathConfigRootKey']                               = 'C:/ProgramData/chocolatey/bin/docfx.exe'
    $global:configRootKeys['GraphvizExePathConfigRootKey']                            = 'C:/Program Files/graphviz/bin/dot.exe'
    $global:configRootKeys['ErlangHomeDirConfigRootKey']                              = 'C:/Program Files/erl-24.0'
    $global:configRootKeys['GitExePathConfigRootKey']                                 = 'C:/Program Files/Git/cmd/git.exe'
    $global:configRootKeys['JavaExePathConfigRootKey']                                = 'C:/Program Files/AdoptOpenJDK/jre-16.0.1.9-hotspot/bin/java.exe'
    $global:configRootKeys['CommonJarsBasePathConfigRootKey']                         = 'C:/ProgramData/CommonJars'
    $global:configRootKeys['BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'] = 'Build-ImageFromPlantUML.ps1'
    $global:configRootKeys['xUnitJenkinsPluginPackageConfigRootKey']                  = 'PathToxUnitJenkinsPlugin'
    $global:configRootKeys['xUnitConsoleTestRunnerPackageConfigRootKey']              = 'xUnitConsoleTestRunnerPackages'

  }
  'JenkinsControllerServers' = @{
    # Should only be set per machine if the machine is a Jenkins Controller Node
    $global:configRootKeys['JENKINS_HOMEConfigRootKey']                    = 'C:/Dropbox'
    $global:configRootKeys['JenkinsControllerServiceAccountConfigRootKey'] = 'JenkinsContrlSrvAcct'

  }
  'JenkinsAgentServers'      = @{
    # Jenkins CI/CD confguration keys
    # These used to access a Jenkins Controller and Authenticate
    $global:configRootKeys['JENKINS_URLConfigRootKey']       = 'http://utat022:4040/'
    $global:configRootKeys['JENKINS_USER_IDConfigRootKey']   = 'whertzing'
    $global:configRootKeys['JENKINS_API_TOKENConfigRootKey'] = '117e33cc37af54e0b4fc6cb05de92b3553' # the value from the configuration page ToDo: use Secrets GUID/file
  }
  'QualityAssuranceServers'  = @{
  }
  'WebServers'               = @{
  }

  'DatabaseServers'          = @{
    $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']       = 'filesystem:' + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities' 'Databases' 'ATAPUtilities' 'Flyway' 'sql')
    $global:configRootKeys['FLYWAY_URLConfigRootKey']             = 'jdbC:sqlserver: / / localhost:1433; databaseName = ATAPUtilities'
    $global:configRootKeys['FLYWAY_USERConfigRootKey']            = 'AUADMIN'
    $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']        = 'NotSecret'
    $global:configRootKeys['FP__projectNameConfigRootKey']        = 'ATAPUtilities'
    $global:configRootKeys['FP__projectDescriptionConfigRootKey'] = 'Test Flyway and Pubs samples'


    # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
    #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
    #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
    #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
    #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    # )
    # $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path 'C:' 'Program Files (x86)'' Microsoft SQL Server/150/Tools/Powershell/Modules'
    # $global:configRootKeys['PlantUmlClassDiagramGeneratorExePathConfigRootKey']       = Join-Path ([Environment]::GetFolderPath('MyDocuments')) '.dotnet' 'tools' 'puml-gen.exe'


  }
  'WSL2Ubuntu'               = @{
    # Used by Ansible
    $global:configRootKeys['ansible_remote_tmpConfigRootKey'] = '/Temp/Ansible'
  }
}

# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:PerRoleSettings) {
  Write-PSFMessage -Level Debug -Message 'global:PerRoleSettings are already defined '
}
else {
  Write-PSFMessage -Level Debug -Message 'global:PerRoleSettings are NOT defined'
  $global:PerRoleSettings = @{}
}

# Determine the roles that this computer belongs to
# populate global:settings with role settings that apply to this computer's

$defaultHash = $defaultPerRoleSettings
$forThisComputer = @('common')
$globalHash = $global:PerRoleSettings

for ($index = 0; $index -lt $forThisComputer.count; $index++) {
  # populate global:settings with settings that apply to this computer. If the hash already exists, overwrite previous values with later ones
  $keys = $defaultHash[$forThisComputer[$index]].Keys
  foreach ($key in $keys ) {
    # ToDo error handling if one fails
    $globalHash[$key] = $($defaultHash[$forThisComputer[$index]])[$key]
  }
}

