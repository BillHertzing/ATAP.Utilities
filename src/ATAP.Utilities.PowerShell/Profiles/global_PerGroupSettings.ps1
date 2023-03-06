

$defaultPerGroupSettings = @{
  # Group Settings
  'all'        = @{
  }

  'WindowsHosts'    = @{
    # The values of the environment variables for ProgramFiles and for ProgramData
    $global:configRootKeys['ProgramFilesConfigRootKey']                               = 'C:/Program Files'
    $global:configRootKeys['ProgramDataConfigRootKey']                                = 'C:/ProgramData'
    # The location where Chocolatey installs some packages and some programs
    $global:configRootKeys['ChocolateyLibDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/lib'
    $global:configRootKeys['ChocolateyBinDirConfigRootKey']                           = 'C:/ProgramData/chocolatey/bin'

    # Used by Create-AnsibleDirectoryStructures.ps1
    #  Used by Ansible to create a temporary directory on the remote host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']                         = 'C:/Temp/Ansible'
    $global:configRootKeys['AnsibleAllowPrereleaseConfigRootKey']                      = 'false'

    #  These are various cloud providers' manifestations on a local filesystem
    $global:configRootKeys['DropBoxBasePathConfigRootKey']                            = 'C:/Dropbox'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']                        = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']                           = 'Dummy' # Join-Path 'C:' 'OneDrive'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']                              = 'C:/Dropbox'
    # varous temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']                           = 'C:/Temp'
    $global:configRootKeys['BigTempBasePathConfigRootKey']                            = 'C:/Temp'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']                         = 'C:/Temp/Insecure'


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

    # Should only be set per machine if the machine is a Jenkins Controller Node
    $global:configRootKeys['JENKINS_HOMEConfigRootKey']                               = 'C:/Dropbox'

    # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
    #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
    #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
    #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
    #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    # )
    # $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = Join-Path 'C:' 'Program Files (x86)'' Microsoft SQL Server/150/Tools/Powershell/Modules'

    $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']                           = 'filesystem:' + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.Utilities' 'Databases' 'ATAPUtilities' 'Flyway' 'sql')
    $global:configRootKeys['FLYWAY_URLConfigRootKey']                                 = 'jdbC:sqlserver: / / localhost:1433; databaseName = ATAPUtilities'
    $global:configRootKeys['FLYWAY_USERConfigRootKey']                                = 'AUADMIN'
    $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']                            = 'NotSecret'
    $global:configRootKeys['FP__projectNameConfigRootKey']                            = 'ATAPUtilities'
    $global:configRootKeys['FP__projectDescriptionConfigRootKey']                     = 'Test Flyway and Pubs samples'

  }
  'WSL2Ubuntu' = @{
    # Used by Ansible
    $global:configRootKeys['ansible_remote_tmpConfigRootKey'] = '/Temp/Ansible'
  }
}


# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:PerGroupSettings) {
  Write-PSFMessage -Level Debug -Message 'global:PerGroupSettings are already defined '
}
else {
  Write-PSFMessage -Level Debug -Message 'global:PerGroupSettings are NOT defined'
  $global:PerGroupSettings = @{}
}

# Determine the roles that this computer belongs to
# populate global:settings with role settings that apply to this computer's
$forThisComputer = @('Windows')
$defaultHash = $defaultPerGroupSettings
$globalHash = $global:PerGroupSettings

for ($index = 0; $index -lt $forThisComputer.count; $index++) {
  # populate global:settings with settings that apply to this computer. If the hash already exists, overwrite previous values with later ones
  $keys = $defaultHash[$forThisComputer[$index]].Keys
  foreach ($key in $keys ) {
    # ToDo error handling if one fails
    $globalHash[$key] = $($defaultHash[$forThisComputer[$index]])[$key]
  }
}
