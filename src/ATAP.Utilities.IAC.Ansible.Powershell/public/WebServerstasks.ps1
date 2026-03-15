
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $dSCConfigurationName
  , [string] $dSCConfigurationFilename
  , [string] $dSCConfigurationSourcePath
  , [string] $dSCConfigurationDestinationDirectory
)

function Contents {
# param(
#    [string] $dSCConfigurationName
#    , [string] $dSCConfigurationFilename
#    , [string] $dSCConfigurationSourcePath
#   , [string] $dSCConfigurationDestinationDirectory

# )
return @"
- name: Copy DSC configuration script to target system
  copy:
    src: $dSCConfigurationSourcePath
    dest:  $dSCConfigurationDestinationDirectory

- name: Apply DSC configuration
  ansible.windows.win_powershell:
    executable: pwsh.exe:
    script: |
      Invoke-DscResource -Path $dSCConfigurationDestinationDirectory -Name $dSCConfigurationFilename -Method Set -Verbose
    # args:
    #   chdir: .
"@
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', $dSCConfigurationName
  $ymlContents += Contents
  Set-Content -Path $(Join-Path $directoryPath "main.yml") -Value $ymlContents


