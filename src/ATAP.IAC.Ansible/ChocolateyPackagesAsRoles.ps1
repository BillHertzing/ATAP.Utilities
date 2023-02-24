
param(
    [string] $ymlGenericTemplate
  , [string] $directoryPath
  , [string] $roleName
  , [string] $packageVersion

)

function Contents {

return @"
- name: install package
  win_chocolatey:
    name: '$roleName'
    version: '$packageVersion'
    state: present
  register: install
  when:  "action_type == 'Install'"

- name: show the results of the install
  debug:
    var: install
  when:  "action_type == 'Install'"

- name: Gather Chocolatey facts
  win_chocolatey_facts:
  when:  "action_type == 'Check'"

- name: Select dictionary with name = '$roleName'
  set_fact:
    selected_dict: "{{ ansible_chocolatey.packages | selectattr('package', 'equalto', '$roleName') | first }}"

- name: validate actual version returned for $roleName is the expected value
  assert:
    that:
      - selected_dict.version == "$packageVersion"
    fail_msg: "installed version is incorrect"
    success_msg: "Correct"
  when:  "action_type == 'Check'"

"@
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', $("$roleName version $packageVersion")
  $ymlContents += Contents
  Set-Content -Path $(Join-Path $directoryPath "main.yml") -Value $ymlContents


  # loop: "{{ ansible_chocolatey.packages | selectattr('name', 'match', '^$roleName$') | list }}" # pick an item from a list of dictionaries based on the value of a field of the dictionary

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
#InstallDir = 'C:/temp/chocotesting'
# Value  = 'Desired State Configuration'`
# Target = 'Process'`
#        Ensure = 'Present'`

# - name: Copy DSC configuration script to target system
#   win_copy:
#     src: $dSCConfigurationAnsibleSourcePath
#     dest:  $dSCConfigurationTargetDestinationDirectory

#     # - name: Apply DSC configuration
#     #   ansible.windows.win_powershell:
#     #     executable: pwsh.exe
#     #     script:
#     #       Invoke-DscResource -Path $dSCConfigurationTargetDestinationDirectory -Name $dSCConfigurationName -Method Set -Verbose

#     #   $commonParams = @{
#     #     Name = 'WindowsFeature'
#     #     Property = @{ Name = 'cChocoInstaller'; InstallDir = 'C:/temp/chocotesting'}
#     #     ModuleName = 'cChoco'
#     #     Verbose = $true
#     # }

# - name: Apply DSC configuration
#   ansible.windows.win_powershell:
#     executable: pwsh.exe
#     script:
#       Invoke-DscResource -Name 'cChoco' -Method Test -Property @{`
#         Name   = 'cChocoInstaller'`
#       }
#     # args:
#     #   chdir: .


