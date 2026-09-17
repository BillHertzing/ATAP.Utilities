
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
  , $global:configRootKeys['ManimExePathConfigRootKey']
  , $global:configRootKeys['ArtifactsPathConfigRootKey']
  , $global:configRootKeys['CorpusAIConversationPathConfigRootKey']
  , $global:configRootKeys['CorpusGatherRecordsPathConfigRootKey']
  , $global:configRootKeys['CorpusGatherRecordsStagingPathConfigRootKey']
  , $global:configRootKeys['ConversationCorpusReconciliationIntervalConfigRootKey']
  , $global:configRootKeys['ConversationCorpusScrubIntervalConfigRootKey']
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

$utat01ArtifactsPath = 'C:\ATAPArtifacts'
$utat022ArtifactsPath = 'D:\ATAPArtifacts'

$defaultPerMachineSettings = @{
  # Machine Settings
  'utat01'    = @{
    $global:configRootKeys['ArtifactsPathConfigRootKey']                             = $utat01ArtifactsPath
    # [IO.Path]::Combine, not Join-Path: Join-Path is provider-aware and throws 'Cannot find drive'
    # when the drive letter does not exist on the host evaluating this table. Every host evaluates
    # every host's table, so a utat022-only D: drive must not break utat01 (Task 15.196.p).
    $global:configRootKeys['CorpusAIConversationPathConfigRootKey']                  = [IO.Path]::Combine($utat01ArtifactsPath, 'CorpusAIConversation')
    $global:configRootKeys['CorpusGatherRecordsPathConfigRootKey']                   = [IO.Path]::Combine($utat01ArtifactsPath, 'CorpusGatherRecords')
    $global:configRootKeys['CorpusGatherRecordsStagingPathConfigRootKey']            = [IO.Path]::Combine($utat01ArtifactsPath, 'CorpusGatherRecordsStaging')
    $global:configRootKeys['ConversationCorpusReconciliationIntervalConfigRootKey'] = [TimeSpan]::FromMinutes(15)
    $global:configRootKeys['ConversationCorpusScrubIntervalConfigRootKey']          = [TimeSpan]::FromDays(1)
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
    $global:configRootKeys['ArtifactsPathConfigRootKey']                             = $utat022ArtifactsPath
    $global:configRootKeys['CorpusAIConversationPathConfigRootKey']                  = [IO.Path]::Combine($utat022ArtifactsPath, 'CorpusAIConversation')
    $global:configRootKeys['CorpusGatherRecordsPathConfigRootKey']                   = [IO.Path]::Combine($utat022ArtifactsPath, 'CorpusGatherRecords')
    $global:configRootKeys['CorpusGatherRecordsStagingPathConfigRootKey']            = [IO.Path]::Combine($utat022ArtifactsPath, 'CorpusGatherRecordsStaging')
    $global:configRootKeys['ConversationCorpusReconciliationIntervalConfigRootKey'] = [TimeSpan]::FromMinutes(15)
    $global:configRootKeys['ConversationCorpusScrubIntervalConfigRootKey']          = [TimeSpan]::FromDays(1)
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

    # Manim executable — main worktree venv (stable path; .venv lives in ATAP.Utilities/ManimVideoGenerator/.venv/)
    $global:configRootKeys['ManimExePathConfigRootKey']            = 'C:/Dropbox/whertzing/GitHub/ATAP.Utilities/ManimVideoGenerator/.venv/Scripts/manim.exe'

    # $global:configRootKeys['JenkinsNodeRolesConfigRootKey']                           = @(
    #   $global:configRootKeys['WindowsCodeBuildConfigRootKey']
    #   , $global:configRootKeys['WindowsUnitTestConfigRootKey']
    #   , $global:configRootKeys['WindowsIntegrationTestConfigRootKey']
    #   , $global:configRootKeys['WindowsDocumentationBuildConfigRootKey']
    # )
    # $global:configRootKeys['SQLServerPSModulePathsConfigRootKey']                     = 'C:/Program Files (x86)'' Microsoft SQL Server', '150', 'Tools', 'Powershell', 'Modules/'

    # $global:configRootKeys['FLYWAY_LOCATIONSConfigRootKey']        = 'filesystem:' + $([Environment]::GetFolderPath('MyDocuments')) + '/GitHub/ATAP.Utilities/Databases/ATAPUtilities/Flyway/sql'
    # $global:configRootKeys['FLYWAY_URLConfigRootKey']              = 'jdbc:sqlserver: / / localhost:1433; databaseName = ATAPUtilities'
    # $global:configRootKeys['FLYWAY_USERConfigRootKey']             = 'AUADMIN'
    # $global:configRootKeys['FLYWAY_PASSWORDConfigRootKey']         = 'NotSecret'
    # $global:configRootKeys['FP__projectNameConfigRootKey']         = 'ATAPUtilities'
    # $global:configRootKeys['FP__projectDescriptionConfigRootKey']  = 'Test Flyway and Pubs samples'

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

# Validate the two source/config contracts before publishing settings for the current host.
# This is deliberately source-only: it does not create directories or mutate User/Machine
# environment variables. Other hosts retain their existing non-corpus settings.
$corpusConfigurationContract = @{
  $global:configRootKeys['CorpusAIConversationPathConfigRootKey']       = 'CorpusAIConversation'
  $global:configRootKeys['CorpusGatherRecordsPathConfigRootKey']        = 'CorpusGatherRecords'
  $global:configRootKeys['CorpusGatherRecordsStagingPathConfigRootKey'] = 'CorpusGatherRecordsStaging'
}
$supportedCorpusHosts = @('utat01', 'utat022')
foreach ($supportedCorpusHost in $supportedCorpusHosts) {
  $hostSettings = $defaultPerMachineSettings[$supportedCorpusHost]
  $artifactKey = $global:configRootKeys['ArtifactsPathConfigRootKey']
  if (-not $hostSettings.ContainsKey($artifactKey) -or
    -not [IO.Path]::IsPathFullyQualified([string]$hostSettings[$artifactKey])) {
    throw "Corpus configuration for host '$supportedCorpusHost' requires an absolute $artifactKey."
  }

  $artifactRoot = [IO.Path]::GetFullPath([string]$hostSettings[$artifactKey]).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $dropboxKey = $global:configRootKeys['DropBoxBasePathConfigRootKey']
  $dropboxRoot = [IO.Path]::GetFullPath([string]$hostSettings[$dropboxKey]).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  if ($artifactRoot.Equals($dropboxRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $artifactRoot.StartsWith($dropboxRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Corpus configuration for host '$supportedCorpusHost' cannot place $artifactKey under Dropbox."
  }

  foreach ($corpusPathKey in $corpusConfigurationContract.Keys) {
    $expectedCorpusPath = [IO.Path]::Combine($artifactRoot, $corpusConfigurationContract[$corpusPathKey])
    if (-not $hostSettings.ContainsKey($corpusPathKey) -or
      -not ([string]$hostSettings[$corpusPathKey]).Equals($expectedCorpusPath, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Corpus configuration for host '$supportedCorpusHost' requires $corpusPathKey to be derived from $artifactKey."
    }
  }

  foreach ($intervalKey in @(
      $global:configRootKeys['ConversationCorpusReconciliationIntervalConfigRootKey'],
      $global:configRootKeys['ConversationCorpusScrubIntervalConfigRootKey'])) {
    if (-not $hostSettings.ContainsKey($intervalKey) -or
      $hostSettings[$intervalKey] -isnot [TimeSpan] -or
      $hostSettings[$intervalKey] -le [TimeSpan]::Zero) {
      throw "Corpus configuration for host '$supportedCorpusHost' requires a positive TimeSpan value for $intervalKey."
    }
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

