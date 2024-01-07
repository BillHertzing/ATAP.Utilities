
<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function New-PlaybooksNamed {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  # [Alias()]
  # [OutputType([Object])]
  Param (
    # Template help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $Template
    , # Name help description
    [Parameter(Mandatory = $true,
      Position = 1,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $Path
    , # InventoryStructure help description
    [Parameter(Mandatory = $true,
      Position = 2,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [PSCustomObject]$inventoryStructure
    , # AnsibleGroupName help description
    [Parameter(ParameterSetName = 'AnsibleGroupNames',
      Mandatory = $false,
      Position = 3,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $AnsibleGroupName

    , # hostName help description
    [Parameter(ParameterSetName = 'HostNames',
      Mandatory = $false,
      Position = 3,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $hostName

  )
  $parsedInventory = $InventoryStructure.AnsibleInventory

  [System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()
  $addedParametersScriptblock = {
    param(
      [string[]]$addedParameters
    )
    if ($addedParameters) {
      foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
      # [void]$sbAddedParameters.Append('"')
      $sbAddedParameters.ToString()
      [void]$sbAddedParameters.Clear()
    }
  }

  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

  # Move this to a parameter
  $InstallAllForHostPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.IAC.Ansible\public\HostPlaybook.yml'

  $PreambleForAnsibleGroupNameScriptBlock = {
    switch ($ansibleGroupName) {
      'WindowsHosts' {
        [void]$sb.Append(@"
# Ensure that Chocolatey and the chocolatey package installer are installed
- name: Install Chocolatey
  hosts: all
  gather_facts: false
  tasks:
    - name: Install Chocolatey
      win_chocolatey:
        name: chocolatey
        state: present
    - name: Configure chocolatey cache location
      win_chocolatey_config:
        name: cacheLocation
        state: present
        value: "{{ ChocolateyCacheLocation }}"
    # Configure Chocolatey to allow community packages ()'allowGlobalConfirmation,allowEmptyChecksums,allowEmptyChecksumsSecure,allowInsecureConfirmation,allowMultipleVersions')
    - name: allow Global confirmation when installing packages and their dependencies
      win_chocolatey_feature:
        name: allowGlobalConfirmation
        state: disabled
    # Configure Chocolatey to install community extensions
    - name: Install chocolatey-core.extension
      win_chocolatey:
        name: chocolatey-core.extension
        state: present
    # # Install the cChoco Poweshell module
    # - name: Ensure the cCHoco module from the PSGallery is present
    #   community.windows.win_psmodule:
    #     name: cChoco
    #     accept_license: true
    #     repository: PSGallery

  tags: [$ansiblegroupname, Preamble, InstallChocolatey]
"@)
      }
    }
  }

  $ChocolateyPackagesForAnsibleGroupNameScriptBlock = {
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('ChocolateyPackageNames')) { # process for $ansibleGroupName only if the ChocolateyPackageNames key exists
      if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ChocolateyPackageNames) {
        $chocolateyPackageNames = $($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).ChocolateyPackageNames
        [void]$sb.Append(@"

# ChocolateyPackages Per Group
- name: Install the Chocolatey Packages defined for the group '$ansibleGroupName'
  hosts: all
  gather_facts: false
  tasks:
    - name: Install the Chocolatey Packages
      # win_dsc:
      #   resource_name: cChocoPackageInstaller
      #   Name: "{{ item.name }}"
      #   Version: "{{ item.version }}"
      #   Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
      #   Params: "{{ item.AddedParameters if item.AddedParameters else omit }}"
      win_chocolatey:
        name: '{{ item.name }}'
        version: '{{ item.version }}'
        allow_prerelease: "{{ 'True' if (item.AllowPrerelease == 'true') else 'false'}}"
        state: "{{ 'absent' if (action_type == 'Uninstall') else 'present'}}"
        {% if item.AddedParameters is defined and item.AddedParameters|length %}
        'package_params: ' "{{ item.AddedParameters }}"
        {% endif %}
      failed_when: false # Setting this means if one package fails, the loop will continue. You can remove it if you don't want that behaviour.
      loop:

"@
        )
        for ($index = 0; $index -lt $chocolateyPackageNames.count; $index++) {
          $packageName = $chocolateyPackageNames[$index]
          $packageVersion = $chocolateyPackageNames[$index].Version
          $allowPrerelease = $($chocolateyPackageNames[$index]).AllowPrerelease
          $addedParameters = . $addedParametersScriptblock  $($chocolateyPackageNames[$index]).AddedParameters
          [void]$sb.Append("        - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
          [void]$sb.Append("`n")
        }
        [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names "
  tags: [$ansiblegroupname, ChocolateyPackages]
"@)
      }
    }
  }

  $PowershellModulesForAnsibleGroupNameScriptBlock = {
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('PowershellModuleNames')) { # process for $ansibleGroupName only if the PowershellModuleNames key exists
      if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).PowershellModuleNames) {
        $powershellModuleNames = $($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).PowershellModuleNames
        [void]$sb.Append(@"

# Powershell Modules per Group
- name: Install Powershell modules For $ansibleGroupName
  hosts: all
  gather_facts: false
  tasks:

    - name: Install the modules defined for each group
      community.windows.win_psmodule:
        name: "{{ item.name }}"
        state: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
        version: "{{ item.version }}"
        allow_prerelease: "{{ item.AllowPrerelease }}"
      loop:

"@)
        for ($index = 0; $index -lt $powershellModuleNames.count; $index++) {
          $moduleName =$powershellModuleNames[$index]
          $moduleVersion = $($powershellModuleNames[$moduleName]).Version
          $allowPrerelease = $($powershellModuleNames[$moduleName]).AllowPrerelease
          [void]$sb.Append("        - {name: $moduleName, version: $moduleVersion, AllowPrerelease: $allowPrerelease  }")
          [void]$sb.Append("`n")
        }
        [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names "
  tags: [$ansiblegroupname, PowershellModules]
"@)
      }
    }
  }

  $RegistrySettingsForAnsibleGroupNameScriptBlock = {
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('RegistrySettingsNames')) { # process for $ansibleGroupName only if the RegistrySettingsNames key exists
      if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).RegistrySettingsNames) {
        $registrySettingNames = $($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).RegistrySettingsNames

        [void]$sb.Append(@"

# Registry Settings per Group
- name: Install Registry Settings For $ansibleGroupName
  hosts: all
  gather_facts: false
  tasks:
    - name: Load Registry Settings information JSON file
      set_fact:
        registry_properties: "{{ lookup('file', '/mnt/c/Dropbox/whertzing/GitHub/ATAP.IAC/RegistrySettingsInfo.yml') | from_yaml }}"

    - name: Set Registry values for each group
      win_regedit:
        path: "{{ registry_properties[item]['path'] }}"
        name: "{{ registry_properties[item]['name'] }}"
        data: "{{ registry_properties[item]['data']|default(None) }}"
        type: "{{ registry_properties[item]['type']|default('dword') }}"
      loop:

"@)
        for ($index = 0; $index -lt $registrySettingNames.count; $index++) {
          [void]$sb.Append('          - ' + $($registrySettingNames[$index]))
          [void]$sb.Append("`n")
        }
        [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names"
  tags: [$ansiblegroupname,RegistrySettings]
"@)
      }
    }
  }
  #state: "{{ registry_properties[item]['state']|default( {{ 'Absent' if (action_type == 'Uninstall') else 'Present'}} ) }}"

  $RolesForAnsibleGroupNameScriptBlock = {
    # if($ansibleGroupName -ne 'WindowsHosts' ) {continue} # skip things for development
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('AnsibleRoleNames')) { # process for $ansibleGroupName only if the AnsibleRoleNames key exists
      if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).AnsibleRoleNames) {
        # playbooks are in the $basedirectory/playbooks, while roles are in basedirectory/roles. But roles are searched below the playbooks dir. So to find a role, requires a custom role path, ""../roles/""
        [void]$sb.Append(@"

# Roles per Group
- name: Install roles For $ansibleGroupName
  hosts: all
  gather_facts: false
  tasks:
    - name: Include the following role on all the hosts in $ansibleGroupName
      include_role:
        name: "{{ roleItem }}"
      loop:

"@)
        $roleNames = @($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).AnsibleRoleNames)
        for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
          $roleName = $roleNames[$roleNameIndex]
          # Ansible expects the roles subdirectory is relative to the playbook. If a child playbook is "included" in a parent playbook, and the child playbook includes a role, bu default it expects the roles subdirectory to be a child of the child playbook's subdirectory.
          #  Our Ansible directory layout places the roles subdirectory as a peer of the playbooks subdirectory, hence, when including a role, the path must go up to the parent, then down to roles subdirectory, i.e., ""../roles/""
          [void]$sb.Append('        - ../roles/' + $roleName)
          [void]$sb.Append("`n")
        }
        [void]$sb.Append(@"
      loop_control:
        loop_var: roleItem
      when: "'$ansibleGroupName' in group_names "

"@)
        # $roleNamesStr = $roleNames -join ',' # $roleNamesStr,
        [void]$sb.Append(@"
  tags: [$ansiblegroupname,Roles]
"@)
      }
    }
  }

  # ToDo: switch on paramtersetname
  switch ($PSCmdlet.ParameterSetName) {
    AnsibleGroupNames {
      [void]$sb.Append($($template -replace '\{2}', "ansibleGroupName $ansibleGroupName"))
      [void]$sb.Append("`n")
      $(if ($true) { $(. $PreambleForAnsibleGroupNameScriptBlock ) })
      $(if ($true) { $(. $ChocolateyPackagesForAnsibleGroupNameScriptBlock) })
      $(if ($true) { $(. $PowershellModulesForAnsibleGroupNameScriptBlock) })
      $(if ($true) { $(. $RegistrySettingsForAnsibleGroupNameScriptBlock) })
      $(if ($true) { $(. $RolesForAnsibleGroupNameScriptBlock) })
    }
    HostNames {
      [void]$sb.Append($($template -replace '\{2}', "ansibleGroupName $ansibleGroupName"))
      [void]$sb.Append("`n")
      [void]$sb.Append($(Get-Content $InstallAllForHostPath -Raw))
    }
    default {
      $message = "ParameterSetName = $($PSCmdlet.ParameterSetName)  has not been implemented yet"
      Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
      # toDo catch the errors, add to 'Problems'
      Throw $message
    }
  }
  Set-Content -Path $Path -Value $sb.ToString()

}

