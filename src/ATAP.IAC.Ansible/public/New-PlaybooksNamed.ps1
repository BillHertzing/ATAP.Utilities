
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
# Setup the PKI Infrastructure including the Trusted Root CA from our organization and the Server certification (SSL Cert)
# Reconfigure WinRM to use the new SSL Certificate only, disable Basic
# Install ATAP.Utilities.Powershell and its dependentPackages
# modify the generic profile and settings that came with the powershell package to the values specific for this WindowsHost
# Symlink in the machine-wide Powershell directory the profile and settings from the Powershell package's Resources\Profile subdirectory
# Symlink the users
- name: Everything from clean Windows Image setup to a working minimal Windows host for the organization
  hosts: all
  gather_facts: false
  tasks:
    # Install all pending updates and reboot as many times as needed
    - name: Install all updates and reboot as many times as needed
      ansible.windows.win_updates:
        category_names: '*'
        reboot: true
    # Chocolatey should already be installed via the boot image, here update it to the latest version
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
    # Install dotnet desktop runtime
    - name: Install the dotnet Chocolatey Package
      win_chocolatey:
       name: dotnet-desktopruntime
       state: present
    # Install Powershell Core
    - name: Install the Powershell Core Chocolatey Package
      win_chocolatey:
        name: powershell-core
        state: present
    # Setup PKI Infrastructure
    # Copy the organization's Root Certificate Authority (RootCA) Certificate to a temporary directory on the new computer
    - name: Copy the Root CA certificate to temp directory on the new computer
      win_copy:
        src: /mnt/c/Dropbox/Security/Certificates/Certificates/CN_ATAPUtilities.org__O_ATAPUtilities.org__C_US-CACertificate.crt
        dest: C:\\Temp\\CN_ATAPUtilities.org__O_ATAPUtilities.org__C_US-CACertificate.crt
    # Install the organization's Root Certificate Authority (RootCA)
    - name: Install Root CA
      ansible.windows.win_certificate_store:
        store_name: Root
        path: C:\\Temp\\CN_ATAPUtilities.org__O_ATAPUtilities.org__C_US-CACertificate.crt
        state: present
    # Delete the Root CA certificate Certificate from the temporary directory on the new computer
    - name: Delete the RootCertificate (CA) Certificate
      ansible.windows.win_file:
        path: C:\\Temp\\CN_ATAPUtilities.org__O_ATAPUtilities.org__C_US-CACertificate.crt
        state: absent
    # Copy this hosts Server Certification (SSL) Certificate to a temporary directory on the new computer
    - name: Copy the  Server Certification (SSL) Certificate to a temporary directory on the new computer
      win_copy:
        src: /mnt/c/Dropbox/Security/Certificates/Certificates/CN_utat022__OU_Development__O_ATAPUtilities.org__C_US-SSLServerCertificate.crt
        dest: C:\\Temp\\CN_utat022__OU_Development__O_ATAPUtilities.org__C_US-SSLServerCertificate.crt
    # Install this hosts Server Certification (SSL) Certificate
    - name: Install the Server Certification (SSL) Certificate
      ansible.windows.win_certificate_store:
        store_type: system # installs the certificate to the LocalMachine store
        path: C:\\Temp\\CN_utat022__OU_Development__O_ATAPUtilities.org__C_US-SSLServerCertificate.crt
        state: present
    # Delete this hosts Server Certification Certificate from the temporary directory on the new computer
    - name: Delete the Server Certification (SSL) Certificate Certificate from the temporary directory on the new computer
      ansible.windows.win_file:
        path: 'C:\\Temp\\CN_utat022__OU_Development__O_ATAPUtilities.org__C_US-SSLServerCertificate.crt'
        state: absent
#    # Tell WinRM to use this certificate for its HTTPS listener
#    - name: modify the winRM listeners
#      ansible.windows.win_powershell:
#        executable: pwsh.exe
#        script: |
#          # $certificate = Get-ChildItem -Path 'cert:\LocalMachine\My' | Where-Object { $_.Subject -match "CN=$env:COMPUTERNAME" }
#          # $thumbprint = $certificate.Thumbprint
#          # "winrm create winrm/config/Listener?Address=*+Transport=HTTPS '@{Hostname=""$env:Computername"";CertificateThumbprint=""$thumbprint""}'" | iex
#          if ((Get-Item WSMan:\localhost\Service\Auth\Basic).Value -eq 'true') {
#           Set-Item WSMan:\localhost\Service\Auth\Basic -Value false
#          }  else {
#            $Ansible.Changed = $true
#          }
    # ToDo: Validate WinRM can connect to Windows Host using SSL and that the CA certificate and SSL certificate work
    # ToDo: disable HTTP Listener
    # ToDo: reconnect using the WinRM SSL link
    # ToDo: use chocolatey to install the ATAP Powershell package including profiles
    # Install it to a new subdirectory under Powershell Modules so it is there for all users
    #- name: use chocolatey to install the ATAP Powershell package including profiles
    # Workaround sequentially specify the steps to perform the installation
    - name: workaround Resources\Profiles
      ansible.windows.win_file:
        path: 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.Powershell\Resources\Profiles'
        state: directory
    # Install the ATAP Powershell package including profiles and RequiredPackages
    - name: workaround copy Profiles to new computer
      ansible.windows.win_copy:
        src: /mnt/c/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/Releases/Production/0.0.1/Resources/Profiles
        dest: 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.Powershell\Resources'
    - name: workaround copy the requiredModules into the location for global modules
      ansible.windows.win_copy:
        src: /mnt/c/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/Releases/Production/0.0.1/Resources/RequiredPackagesOfflineRepository/PSFramework
        dest: 'C:\Program Files\PowerShell\Modules'
    - name: workaround copy the package specification
      ansible.windows.win_copy:
        src: /mnt/c/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/Releases/Production/0.0.1/ATAP.Utilities.Powershell.psd1
        dest: 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.Powershell\ATAP.Utilities.Powershell.psd1'
    - name: workaround copy the package function library
      ansible.windows.win_copy:
        src: /mnt/c/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/Releases/Production/0.0.1/ATAP.Utilities.Powershell.psm1
        dest: 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.Powershell\ATAP.Utilities.Powershell.psm1'
    # end of workaround
    - name: Copy the hostSettings.ps1 file from the Ansible directory to Powershell
      ansible.windows.win_copy:
        src: ./scripts/hostSettings.ps1
        dest: 'C:\\Program Files\\PowerShell\\7'
    # Install everything to provide file indexing (Windows search is disabled in the ATAP minimal image)
    - name: Install the Everything file index and search Chocolatey Package
      win_chocolatey:
        name: everything
        state: present
    - name: link the global ALLUsersAllHosts profile and settings files to this machine's local machine's profile location
      ansible.windows.win_powershell:
        executable: pwsh.exe
        script: |
          Import-Module PSFramework
          Write-PSFMessage -Level Important -Message 'PSHOME = "$PSHOME"' -Tag 'Dev'
          New-SymbolicLink -symbolicLinkPath "$PSHOME\\profile.ps1"                      -targetPath "$PSHOME\\..\\Modules\\ATAP.Utilities.Powershell\\Resources\Profiles\\AllUsersAllHostsV7CoreProfile.ps1" -force
          New-SymbolicLink -symbolicLinkPath "$PSHOME\\\global_ConfigRootKeys.ps1"       -targetPath "$PSHOME\\..\\Modules\\ATAP.Utilities.Powershell\\Resources\Profiles\\global_ConfigRootKeys.ps1" -force
          New-SymbolicLink -symbolicLinkPath "$PSHOME\\global_EnvironmentVariables.ps1"  -targetPath "$PSHOME\\..\\Modules\\ATAP.Utilities.Powershell\\Resources\Profiles\\global_EnvironmentVariables.ps1" -force
          # ToDo: create a host-specific HostSettings and copy that
          #New-SymbolicLink -symbolicLinkPath 'C:\Program Files\PowerShell\HostSettings.ps1'                 -targetPath 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.Powershell\Resources\Profiles\HostSettings.ps1' -force

    # - name: enable insecure guest access to SMB shares in order to access to NetGear Nighthawk router SMB share
    #   win_regedit:
    #     path: HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters
    #     name: AllowInsecureGuestAuth
    #     data: 1
    #     type: dword

  tags: [$ansibleGroupName, Preamble, InstallChocolatey]

"@)
      }
    }
  }

  $ChocolateyPackagesForAnsibleGroupNameScriptBlock = {
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('ChocolateyPackageNames')) {
      # process for $ansibleGroupName only if the ChocolateyPackageNames key exists
      if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ChocolateyPackageNames) {
        $chocolateyPackageNames = $($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).ChocolateyPackageNames
        [void]$sb.Append(@"

# ChocolateyPackages Per Group
- name: Install the Chocolatey Packages defined for the group '$ansibleGroupName'
  hosts: all
  gather_facts: false
  tasks:
    - name: Install the Chocolatey Packages
      win_chocolatey:
        name: '{{ item.name }}'
        version: '{{ item.version }}'
        allow_prerelease: "{{ 'True' if (item.AllowPrerelease == 'true') else 'false'}}"
        state: "{{ 'absent' if (action_type == 'Uninstall') else 'present'}}"
        #package_params: "{{ '{{ item.AddedParameters }}' if item.AddedParameters is defined and item.AddedParameters|length}}"
      failed_when: false # Setting this means if one package fails, the loop will continue. You can remove it if you don't want that behavior.
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
  tags: [$ansibleGroupName, ChocolateyPackages]
"@)
      }
    }
  }

  $PowershellModulesForAnsibleGroupNameScriptBlock = {
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('PowershellModuleNames')) {
      # process for $ansibleGroupName only if the PowershellModuleNames key exists
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
          $moduleName = $powershellModuleNames[$index]
          $moduleVersion = $($powershellModuleNames[$moduleName]).Version
          $allowPrerelease = $($powershellModuleNames[$moduleName]).AllowPrerelease
          [void]$sb.Append("        - {name: $moduleName, version: $moduleVersion, AllowPrerelease: $allowPrerelease  }")
          [void]$sb.Append("`n")
        }
        [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names "
  tags: [$ansibleGroupName, PowershellModules]
"@)
      }
    }
  }

  $RegistrySettingsForAnsibleGroupNameScriptBlock = {
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('RegistrySettingsNames')) {
      # process for $ansibleGroupName only if the RegistrySettingsNames key exists
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
  tags: [$ansibleGroupName,RegistrySettings]
"@)
      }
    }
  }
  #state: "{{ registry_properties[item]['state']|default( {{ 'Absent' if (action_type == 'Uninstall') else 'Present'}} ) }}"

  $RolesForAnsibleGroupNameScriptBlock = {
    # if($ansibleGroupName -ne 'WindowsHosts' ) {continue} # skip things for development
    if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('AnsibleRoleNames')) {
      # process for $ansibleGroupName only if the AnsibleRoleNames key exists
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
  tags: [$ansibleGroupName,Roles]
"@)
      }
    }
  }

  # ToDo: switch on parametersetname
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

