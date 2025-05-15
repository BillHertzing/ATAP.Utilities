
$PerHostSettingsKeys = @(
  , $global:configRootKeys['DropBoxBasePathConfigRootKey']
  , $global:configRootKeys['GoogleDriveBasePathConfigRootKey']
  , $global:configRootKeys['OneDriveBasePathConfigRootKey']
  # This is the default cloud provider's manifestation
  , $global:configRootKeys['CloudBasePathConfigRootKey']
  # various temporary directories
  , $global:configRootKeys['FastTempBasePathConfigRootKey']
  , $global:configRootKeys['BigTempBasePathConfigRootKey']
  , $global:configRootKeys['SecureTempBasePathConfigRootKey']
  # Chocolatey settings on this host
  , $global:configRootKeys['ChocolateyCacheLocationConfigRootKey']
  # ansible settings on this host
  , $global:configRootKeys['ansible_remote_tmpConfigRootKey']
  , $global:configRootKeys['ansible_become_userConfigRootKey']
)

$scriptblock_perhost = {
  param(
    [string]$hostname
  )
  for ($hostSettingIndex = 0; $hostSettingIndex -lt $PerHostSettingsKeys.count; $hostSettingIndex++) {
    $hostSetting = $PerHostSettingsKeys[$hostSettingIndex]
    Join-Path 'T:' 'Temp'
  }
}

$defaultPerMachineSettings = @{
  # Machine Settings
  'utat01'    = @{
    $global:configRootKeys['DropBoxBasePathConfigRootKey']         = 'C:/Dropbox/'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # 'C:/OneDrive/'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']           = 'C:/Dropbox/'
    # various temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']        = 'C:/Temp/'
    $global:configRootKeys['BigTempBasePathConfigRootKey']         = 'C:/Temp/'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']      = 'C:/Temp/Insecure/'
    # Chocolatey settings on this host
    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'] = 'C:/Temp/ChocolateyCache'
    # ansible settings on this host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']      = 'C:/Temp/Ansible'
    $global:configRootKeys['ansible_become_userConfigRootKey']     = 'whertzing'
  }

  'utat022'   = @{
    $global:configRootKeys['DropBoxBasePathConfigRootKey']         = 'C:/Dropbox/'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # 'C:/OneDrive/'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']           = 'C:/Dropbox/'
    # various temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']        = 'C:/Temp/'
    $global:configRootKeys['BigTempBasePathConfigRootKey']         = 'C:/Temp/'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']      = 'C:/Temp/Insecure/'
    # Chocolatey settings on this host
    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'] = 'C:/Temp/ChocolateyCache'
    # ansible settings on this host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']      = 'C:/Temp/Ansible'
    $global:configRootKeys['ansible_become_userConfigRootKey']     = 'whertzing'

    # Should only be set per machine if the machine is a Jenkins Controller Node
    $global:configRootKeys['JENKINS_HOMEConfigRootKey']            = 'C:/Dropbox/'

    # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
    #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
    #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
    #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
    #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    # )
    # $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = 'C:/Program Files (x86)'' Microsoft SQL Server', '150', 'Tools', 'Powershell', 'Modules/'

    $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']        = 'filesystem:' + $([Environment]::GetFolderPath('MyDocuments')) + '/GitHub/ATAP.Utilities/Databases/ATAPUtilities/Flyway/sql'
    $global:configRootKeys['FLYWAY_URLConfigRootKey']              = 'jdbc:sqlserver: / / localhost:1433; databaseName = ATAPUtilities'
    $global:configRootKeys['FLYWAY_USERConfigRootKey']             = 'AUADMIN'
    $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']         = 'NotSecret'
    $global:configRootKeys['FP__projectNameConfigRootKey']         = 'ATAPUtilities'
    $global:configRootKeys['FP__projectDescriptionConfigRootKey']  = 'Test Flyway and Pubs samples'

  }
  'ncat016'   = @{
    #  These are various cloud providers' manifestations on a local filesystem
    $global:configRootKeys['DropBoxBasePathConfigRootKey']         = 'D:/Dropbox/'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # 'C:/OneDrive/'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']           = 'D:/Dropbox/'
    # various temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']        = 'D:/Temp/'
    $global:configRootKeys['BigTempBasePathConfigRootKey']         = 'D:/Temp/'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']      = 'D:/Temp/Insecure/'
    # Chocolatey settings on this host
    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'] = 'C:/Temp/ChocolateyCache'
    # ansible settings on this host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']      = 'D:/Temp/Ansible'
    $global:configRootKeys['ansible_become_userConfigRootKey']     = 'whertzing56'
  }
  'ncat041'   = @{
    #  These are various cloud providers' manifestations on a local filesystem
    $global:configRootKeys['DropBoxBasePathConfigRootKey']         = 'C:/Dropbox/'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # 'C:/OneDrive/'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']           = 'C:/Dropbox/'
    # various temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']        = 'C:/Temp/'
    $global:configRootKeys['BigTempBasePathConfigRootKey']         = 'C:/Temp/'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']      = 'C:/Temp/Insecure/'
    # Chocolatey settings on this host
    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'] = 'C:/Temp/ChocolateyCache'
    # ansible settings on this host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']      = 'C:/Temp/Ansible'
    $global:configRootKeys['ansible_become_userConfigRootKey']     = 'whertzing'

  }
  'ncat-ltb1' = @{
    #  These are various cloud providers' manifestations on a local filesystem
    $global:configRootKeys['DropBoxBasePathConfigRootKey']         = 'D:/Dropbox/'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # 'C:/OneDrive/'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']           = 'D:/Dropbox/'
    # various temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']        = 'D:/Temp/'
    $global:configRootKeys['BigTempBasePathConfigRootKey']         = 'D:/Temp/'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']      = 'D:/Temp/Insecure/'
    # Chocolatey settings on this host
    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'] = 'D:/Temp/ChocolateyCache'
    # ansible settings on this host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']      = 'D:/Temp/Ansible'
    $global:configRootKeys['ansible_become_userConfigRootKey']     = 'whertzing56'

  }
  'ncat-ltjo' = @{
    #  These are various cloud providers' manifestations on a local filesystem
    $global:configRootKeys['DropBoxBasePathConfigRootKey']         = 'D:/Dropbox/'
    $global:configRootKeys['GoogleDriveBasePathConfigRootKey']     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
    $global:configRootKeys['OneDriveBasePathConfigRootKey']        = 'Dummy' # 'C:/OneDrive/'
    # This is the default cloud provider's manifestation
    $global:configRootKeys['CloudBasePathConfigRootKey']           = 'D:/Dropbox/'
    # various temporary directories
    $global:configRootKeys['FastTempBasePathConfigRootKey']        = 'D:/Temp/'
    $global:configRootKeys['BigTempBasePathConfigRootKey']         = 'D:/Temp/'
    $global:configRootKeys['SecureTempBasePathConfigRootKey']      = 'D:/Temp/Insecure/'
    # Chocolatey settings on this host
    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'] = 'D:/Temp/ChocolateyCache'
    # ansible settings on this host
    $global:configRootKeys['ansible_remote_tmpConfigRootKey']      = 'D:/Temp/Ansible'
    $global:configRootKeys['ansible_become_userConfigRootKey']     = 'whertzing'
  }
}

# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:PerMachineSettings) {
  Write-PSFMessage -Level Debug -Message 'global:PerMachineSettings are already defined '
} else {
  Write-PSFMessage -Level Debug -Message 'global:PerMachineSettings are NOT defined'
  $global:PerMachineSettings = @{}
}

$defaultHash = $defaultPerMachineSettings
$forThisComputer = @('common')
$globalHash = $global:PerMachineSettings

# populate global:settings with settings that apply to this computer. If the hash already exists, overwrite previous values with later ones
$keys = $defaultHash[$env:hostname].Keys
foreach ($key in $keys ) {
  # ToDo error handling if one fails
  $globalHash[$key] = $($defaultHash[$env:hostname])[$key]
}

