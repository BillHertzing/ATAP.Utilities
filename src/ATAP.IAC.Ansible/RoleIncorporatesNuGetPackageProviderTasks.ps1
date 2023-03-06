
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $dSCConfigurationName
  , [string] $dSCConfigurationFilename
  , [string] $dSCConfigurationSourcePath
  , [string] $dSCConfigurationAnsibleSourcePath
  , [string] $dSCConfigurationTargetDestinationDirectory
)

function Contents {

return @"
- name: install package
  win_chocolatey:
    name: 'cpu-z'
    state: present
  register: install

- name: show the results of the install
  debug:
    var: install

"@
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', $dSCConfigurationName
  $ymlContents += Contents
  Set-Content -Path $(Join-Path $directoryPath "main.yml") -Value $ymlContents


#   - name: show the ansible_user
#   debug:
#     var: ansible_user

# - name: Ensure module is present on target
#   win_psmodule:
#     name: cChoco
#     repository: PSGallery

  # - name: Set the cache location
  # win_chocolatey_config:
  #   name: cacheLocation
  #   state: present
  #   value: C:\Temp\chocotesting


  # - name: Apply DSC configuration to install chocolatey
#   win_dsc:
#     resource_name: cChocoInstaller
#       InstallDir = C:\Temp\chocotesting

  # InstallDir = 'C:\temp\chocotesting'
#  InstallDir = 'C:/temp/chocotesting'
# Value  = 'Desired State Configuration'`
# Target = 'Process'`
#        Ensure = 'Present'`

# - name: Copy DSC configuration script to target system
#   win_copy:
#     src: $dSCConfigurationAnsibleSourcePath
#     dest:  $dSCConfigurationTargetDestinationDirectory

