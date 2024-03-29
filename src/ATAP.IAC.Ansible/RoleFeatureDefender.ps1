
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames
  , [string] $name
  , [string] $version

)

function ContentsTask {
@'
- name: Get Start Value for the Defenders services
  ansible.windows.win_powershell:
    executable: pwsh.exe
    script:
      # $allservices = Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services;
      # $servicesmatching = $allservices | Where-Object {
      #     $(Get-ItemProperty -Path $($_.name -replace 'HKEY_LOCAL_MACHINE','HKLM:') -Name 'Description' -ErrorAction SilentlyContinue) -match 'defend'
      # };
      # $servicesmatching += $allservices | Where-Object {$_.name -match 'mpssvc'};
      # $serviceDetails = @();
      # $servicesmatching | %{
      #   $path = $_ -replace 'HKEY_LOCAL_MACHINE','HKLM:';
      #   $name = $($_.name -split '\\')[-1];
      #   $serviceDetails += @{
      #     Name = $name;
      #     Start = Get-ItemPropertyValue -Name 'Start' -path $path;
      #     Description = Get-ItemPropertyValue -Name 'Description' -path $path;
      #   };
      # };
      # $serviceDetailsAsJSON = $serviceDetails| ConvertTo-Json -Depth 99;
      # $Ansible.result =$serviceDetailsAsJSON;
      $Ansible.result = & ./RoleFeatureDefenderScript.ps1

  register: fullresults
  # failed_when: fullresults.error | length > 0
  when:  "action_type == 'Check'"

- name: show returned information
  debug:
    var: fullresults
  ignore_errors: yes
'@
}
function ContentsVars {
@"
version: Dummy
allow_prerelease: false
"@
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|meta|files|templates|library|module_utils|lookup_plugins|scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $ymlContents = $($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', "RoleFeature$roleName"
  switch -regex ($roleSubdirectoryName) {
    '^tasks$' {
      $ymlContents += ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    '^vars$' {
      $ymlContents += ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    '^scripts$' {
      $scriptName = $roleName + 'Script.ps1'
      $scriptSourcePath = "./$scriptName"
      $scriptDestinationPath = join-path $roleSubdirectoryPath $scriptName
      Copy-Item -Path $scriptSourcePath -Destination $scriptDestinationPath
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}



# - name: Gather Chocolatey facts
#   win_chocolatey_facts:
#   when:  "action_type == 'Check'"

# - name: Select dictionary with name = '$name'
#   set_fact:
#     selected_dict: "{{ ansible_chocolatey.packages | selectattr('package', 'equalto', '$name') | first }}"
    # '^scripts$' {
    #   $scriptName = $roleName + 'Script.ps1'
    #   $scriptSourcePath = "./$scriptName"
    #   $scriptDestinationPath = join-path $roleSubdirectoryPath $scriptName
    #   Copy-Item -Path $scriptSourcePath -Destination $scriptDestinationPath
    # }

# - name: validate actual version returned for $name is the expected value
#   assert:
#     that:
#       - "'{{ selected_dict.version }}' == '{{ version }}'"
#     fail_msg: "installed version is incorrect. expecting '{{ version }}' got '{{selected_dict.version}}' "
#     success_msg: "Correct"
#   when:  "action_type == 'Check'"


# loop: "{{ ansible_chocolatey.packages | selectattr('name', 'match', '^$roleName$') | list }}" # pick an item from a list of dictionaries based on the value of a field of the dictionary

#   - name: show the ansible_user
#   debug:
#     var: ansible_user

# - name: Ensure module is present on target
#   win_psmodule:
#     name: cChoco
#     repository: PSGallery

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

