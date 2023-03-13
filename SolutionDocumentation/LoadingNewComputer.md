# Setup a new computer

## Introduction

Setting up a new computer can be a daunting task when there are hundreds of customizations needed to make the computer a productive element of an organizations infrastructure.  Infrastructure As Code (IAC) is the discipline that is concerned with formalizing how to codify the customizations, and executing on the configuration to make a computer conform to the customizations desired.

The ATAP utilities repository uses the automation software Ansible to control the setup and upgrade of the hosts in our organization. The sub-repository ATAP.IAC.Ansible contains IAC code that defines the organizatiopns hosts, their roles, and the specific software and configuration needed on the hosts for them to fulfill their roles. See the ATAP.IAC.Ansible [readme] for furhter information on this

However, a new computer / host requires some setup steps before it can communicate with an IAC Controller host. The purpose of this document is to detail the bootstrapping steps to setup a Window's host so it can communicate with Ansible for the remainder of the setup process. Bootstrapping is the process of initial machine configuration.

Eventually, some of these steps will be incorporated into a Powershell module ad functions that can be loaded and executed

This document starts with the assumption that a new computer is operational, has a monitor and keyboard connected, and can vbe booted into the BIOS.

## BIOS modifications

BIOS changes can be made before an operating system is installed. These will be unique to a given machine configuration. These must be done manually when a machine is first powered up.


### utat022 host BIOS modifications

- Change PCIE configuration from "M2 extension card" to "dual M2 SSD"
- Ensure SATA controllers are On
- X.M.P is enabled
- Intel Rapid Storage technology is OFF
- change hotswap notification to "enabled"
- Boot disk order should list teh removable drives first

## Install the Operating system

Operating systems can be installed from ISO images, or from other image sources. This will describe how to manually install the OS from an ISO image on a USB stick. These instructions are for the Windows OS.

These instructions are for adding a machine to a non-domain workgroup, and creating local users and groups on the machine.

### Create a Windows bootable USB stick

Create latest Windows 11 bootable USB stick (Instructions TBD)
Print latest Windows 11 Pro license Key

### utat022 OS instructions

unplug SATA drives, leave just PCIE drive in
disconnect the machine from the internet
plug USB stick into bootable usb port
Power up the machine, boot through the USB strick
Install Windows 11 Pro to (unformatted) drive 0
When asked for the name of the first administrative user, enter `<YourInitialAdministratorUserID>` and `<YourInitialAdministratorPassword>`
Login to the new machine using the first administrative user

### Document the Operating System baseline

run the program 'Everything' from a USB stick, get list to a file "01 Clean Windows 11 install, Step 01 Files.efu"

## Boostrap a new host for accepting communications from the IAC controller

Before any IAC controller can configure a new host, the IAC controller software must be able to connect to the host.

### Bootstrap a new host accepting communications from Ansible

Ansible (for Windows) uses WinRM to communicate from the AnsibleController host to the remote hosts.  WinRM must be setup durring the bootstrap process.

#### Enable WinRM

Setup the initial WinRM configuration. Run the command ```winrm qc```

#### Allow Powershell script execution

During the bootstrapping process, we will use the version of the Powershell executable that came with the Windows OS install. During the bootstrapping process, Powershell will be configured to allow running scripts that are unsigned. After the initial configuration, the Powershell ExecutionPolicy will be changed so that only signed scripts will be allowed.

Run the command ```Set-ExecutionPolicy Bypass```

#### Allow Powershell remote access from Ansible

Ansible suplies a Powershell script that configures a host to accept a connection from an AnsibleController host. This file must be downloaded from github and transferred to the new host The script is named ConfigureRemotingForAnsible.ps1, and can be retrieved from [ConfigureRemotingForAnsible.ps1] (https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1)

This script will create a new self-signed SSL certificate. It should be removed in a later step after the new host has been configured. (TBD!)

Note that this command will require an internet connection. A safer method would be to download the script, check it for malware, thn put it on a USB stick and copy the file from the USB stick

```Powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"
(New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
powershell.exe -ExecutionPolicy ByPass -File $file -EnableCredSSP -DisableBasicAuth
```

#### Validate the WinRM initial listener configuration

Run the command ```winrm enumerate winrm/config/Listener```. Expected response should be

```Markdown
Listener
    Address = *
    Transport = HTTP
    Port = 5985
    Hostname
    Enabled = true
    URLPrefix = wsman
    CertificateThumbprint
    ListeningOn = 127.0.0.1, 169.254.57.70, 169.254.70.187, 169.254.112.251, 169.254.190.156, 169.254.216.213, 169.254.226.151, 169.254.243.235, 192.168.1.30, ::1, fe80::1d36:2a1:1009:ba9f%8, fe80::3771:cebf:b9b8:bfab%22, fe80::38a8:8571:2350:4160%15, fe80::9479:9073:1303:6f08%12, fe80::d9b2:fccb:bdc:d011%11, fe80::dd23:2447:54ef:973b%14, fe80::e8ba:3244:9cf0:32ec%10, fe80::eca8:c27b:1692:6f95%7

Listener
    Address = *
    Transport = HTTPS
    Port = 5986
    Hostname = <NewHost_HostName>
    Enabled = true
    URLPrefix = wsman
    CertificateThumbprint = 02CCB8C348080EC5C75AE2C0EB844D3EA12A2B16
    ListeningOn = 127.0.0.1, 169.254.57.70, 169.254.70.187, 169.254.112.251, 169.254.190.156, 169.254.216.213, 169.254.226.151, 169.254.243.235, 192.168.1.30, ::1, fe80::1d36:2a1:1009:ba9f%8, fe80::3771:cebf:b9b8:bfab%22, fe80::38a8:8571:2350:4160%15, fe80::9479:9073:1303:6f08%12, fe80::d9b2:fccb:bdc:d011%11, fe80::dd23:2447:54ef:973b%14, fe80::e8ba:3244:9cf0:32ec%10, fe80::eca8:c27b:1692:6f95%7```

Notes:

- The IP address that start with `169.254.x.x` are unexpected, and according to this article [WinRM Strange ListeningOn Addresses](https://social.technet.microsoft.com/Forums/windows/en-US/3082d5ab-b018-4d99-8697-81cefc4b3543/winrm-strange-listeningon-addresses), come from the "Microsoft Failover Cluster Virtual Adapter", which is hidden.
- Later steps will remove the Failover Clustering feature
- Later steps will disable the HTTP listener, and install a WSMan certificate generated by the organizations internal PKI infrastructure.
- Later steps will setup the TrustedHosts list for the WWSman service
- The hostname shown will be the initial host name generated when the OS is installed. Later steps will change the hostname, and modify the hostname entries in the WinRM Listener

```

#### Enable Wake-on-LAN (WoL)

Wake-on-LAN (WoL) is enabled to automatically turn on systems when doing maintenance. Most systems are configured this way automatically, however in some cases they need specific changes to make them work.

Detailed instructions are TBD and are per-host

## Add new host to the IAC configuration

At this point, the new host is ready to accept further configuration from the AnsibleController host. See [TBD] for the next steps

TBD: The IAC configuration is stored in the project database. The project database includes code that will output a complete Ansible directory structure and its contents, for managing the organizations hosts.

Current: The IAC configuration is stored in the subrepository `ATAP.IAC.Ansible`. The script `Create-AnsibleDirectoryStructure.ps1` from that repository can be run in to output a complete Ansible directory structure and its contents.
Documentation can be found [here; TBD]
```markdown


### Groups to which the new computer utat022 belongs

- Development Computer
- SSH Server
- Secrets Management
  - Hashicorp
  - KeePass
  - Powershell Secrets
- Certification Authority
- Certification Issuer
  - DEC certificate
  - SSL Certificate
  - CodeSigning Certificate
- Database
  - SQLServer
  - MySQL
- WebServer
  - Kestrel
  - IIS

```yml
---
- Windows
  - PrivateKey
  - WSL 2
    - Ubuntu
      - Private Key
- Lifecycle
  Production: yes
  QualityAssurance: yes
  Development: yes

```




rename computer (utat022)
turn off edge pre-load
get IP and MAC, for wired and wireless
wired 50-eb-f6-78-80-5a
wireless 00-91-9e-7c-45-f2
Update NetGear router DHCP leases
wired: utat022 192.168.1.22 50:EB:F6:78:80:5A wired:atap_24

Update the organizations master Hosts file and the Roles' Hosts file
Copy the Roles Hosts file to the new computer

apply updates to windows 11

run Everything from USB stick, get list to a file "01 Clean Windows 11 install, Step 02 Files.efu"

Create c:\Dropbox, c:\dropbox\<LocalUserName>,

Create Network share on a fast drive named \\FS, share it with everybody on the network

ToDo: replace this with Ansible push
Copy InstChoco and packagesconfig to Filesharecopy from fileshare to \\mydocuments\ChocolateyPackageListBackup
copy hosts to \\utat022\fileshare and then to new computer
Start Powershell (old), run Instchoco.exe as admin

Install Dropbox to c:\

Set Locations for MyDocuments, Pictures, Videos, Downloads to c:\Dropbox-

see also C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\MapUserShellFoldersToDropBox.ps1

uninstall Everything

## Installing the user's 'standard' applications

### Standard applications on Windows

There are two main tools used to install software. One tool supports 'portable applications' the other support's applications installed locally

#### Standard Portable Applications

Portable applications are installed to the `Dropbox\PortableApplications` directory. Almost all of the work is done simply by connecting the new computer to dropbox, and waiting for synchronization to complete. All of the executables and libraries are present, as are the configuration settings. However, some applications work better when information that should remain specific to a computer is stored outside of the PortableApps subdirectory.

- CPU-Z
- GPU-Z
-

##### Ditto portable

1. Configure Ditto so the Ditto.db is %apdatalocal%/Ditto/Ditto.db
1. Remove the Ditto.db that is under portableapps, that was created when Ditto started for the first time on the computer
1. Configure Ditto to start when the user logs in, and to start minimized

##### 7-ZipPortable

1. Associate all the possible extensions to 7Zip for the user
1. The shared settings will specify paths for the editor and diff tool. These should point to the chocolatey bin location executables for notepad and beyond compare

## Install Chocolatey packages

Reinstall all chocolatey packages

- Notepad++ - use x86 version, many more plugins available
- Add to List:
  Freevideoeditor
powershell INvoke-Build module

After chocolatey install, configure as follows:

- Everything
  - Use appdata for ini and db location
  - DoubleClick path to navigate to that path (ToDo: screenshot)
- Ditto - configure Friends and network password
- Notepad++ - Configure cloud location (Dropbox/Notepad++), add plugins
- BeyondCompare - enter license text
- 7Zip - Associate file extensions, set view, edit, and diff tools to Notepad++ and Beyondcompare
- Git - ?
- Fiddler -
- VisualStudioCode - Turn on settings sync, for Settings and extensions, state, etc
- Avast Premium - enter license
- ServiceStack - enter license
- Rider Ultimate - enter license
- FreeVideoEditor VSDC - enter license
- Fiddler

  - Turn on 'capture https'
  - [Fiddler Compare Tools](https://fiddlerbook.com/fiddler/help/CompareTool.asp)
    -Setup Git
    in file ~/.gitconfig

  ```text
    [filter "lfs"]
      smudge = git-lfs smudge -- %f
      process = git-lfs filter-process
      required = true
      clean = git-lfs clean -- %f
    [user]
      name = Bill Hertzing
      email = bill.hertzing@gmail.com
    [diff]
      tool = bc3
    [difftool]
      prompt = false
    [merge]
      tool = bc3
    [mergetool]
      prompt = false
    [difftool "bc3"]
      path = "C:/Program Files/Beyond Compare 4/bcomp.exe"
    [mergetool "bc3"]
      path = "C:/Program Files/Beyond Compare 4/bcomp.exe"
    [mergetool "bc3"]
      trustExitCode = true
    [alias]
      mydiff = difftool --dir-diff --tool=bc3 --no-prompt
      bcreview = "!f() { local SHA=${1:-HEAD}; local BRANCH=${2:-master}; if [ $SHA == $BRANCH ]; then SHA=HEAD; fi; git difftool -y -t bc $BRANCH...$SHA; }; f"
    [core]
      autocrlf = true
      editor = code --wait
    [commit]
      template = GitTemplates/git.commit.template.txt
    [merge "keep-local-changes"]
      name = A custom merge driver which always keeps the local changes
      driver = true
  ```

vault - Hashicorp free level Vault server

### Setup Hosts file (for computers in a Workgroup, i.e., not joined to a Domain)

copy role-appropriate hosts file to new computer

## Security and PKI

If the role specifies that the computer will be a primary or backup Hashicorp Vault server, run the following steps

- Create a user under which the Hashicorp Vault server will run (Name cannot exceed 25 characters)

  - Install-Module Microsoft.PowerShell.LocalAccounts
  - New-LocalUser -Name "HashicorpVaultServiceAcct" -Description "Runs Vault Server task" -NoPassword # ToDo - if password where will it get the credential from?
  -

## Install Powershell Packages

Powershell packages are managed on a per-host nad per-group basis using Ansible

- as the first admin user, run the command to install the NuGet PackageProvider
  `Install-PackageProvider -Name NuGet -Force`
- as the first admin user, run the command to trust the PSGallery repository
  `Register-PSRepository -Default`
  `Get-PSRepository` # ToDo: validate that PSGallery appears
  `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted`
- Install the following 3rd-party packages machine-wide. Run the following as an administrator on the new computer
   `Microsoft.PowerShell.SecretManagement`, `Microsoft.PowerShell.SecretStore` and `SecretManagement.Keepass` are for development credentials and secret,
   `PSFramework` is for logging
   ToDo: `SecretManagement.Hashicorp` is for an alternate secrets vault
   ToDO: `DISM` is for enabling Windows Features, but it is not available for direct download. See
  `@('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore', 'SecretManagement.Keepass', 'PSFramework', 'DISM') | ForEach-Object { if (-not (Get-Module -ListAvailable -Name  $_)) { Install-Module -Name $_ -Scope AllUsers}}`

- 32-Bit powershel Desktop Modules will not import automatically, run the foillowing lines
  - for installing any certificates via powershell
  `Import-Module -Name C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PKI\pki.psd1`

  - For NetTCIP functionslike `test-port`
  `Import-Module -Name "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\NetTCPIP\NetTCPIP.psd1"`

- Install the following ATAP.Utilities packages machine-wide
  Before Package Management
  After Package Management

- Install the machine profile files
  After Package Management


  Before Package Management

  Symlink the profile files for the machine as follows:

  - `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'profile.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")} 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities. PowerShell' 'profiles' 'AllUsersAllHostsV7CoreProfile.ps1')`

  - `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_ConfigRootKeys.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_ConfigRootKeys.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")} 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'global_ConfigRootKeys.ps1')`

  - `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_MachineAndNodeSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_MachineAndNodeSettings.ps1') -Target (join-path -path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','global_MachineAndNodeSettings.ps1'))`

  - `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_PerMachineSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_PerMachineSettings.ps1') -Target (join-path -path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','global_PerMachineSettings.ps1'))`

  - `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_PerGroupSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_PerGroupSettings.ps1') -Target (join-path -path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','global_PerGroupSettings.ps1'))`

  - `Remove-Item -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_PerRoleSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_PerRoleSettings.ps1') -Target (join-path -path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','global_PerRoleSettings.ps1'))`

  - `Remove-Item -path (join-path ($env:ProgramFiles) 'PowerShell' '7' 'global_EnvironmentVariables.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles 'PowerShell' '7' 'global_EnvironmentVariables.ps1') -Target (join-path ([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP. Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'global_EnvironmentVariables.ps1')`

  Symlink the profile file for the first admin user on this machine

  - `Remove-Item -path (join-path ([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path ([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.PowerShell_profile.ps1') -Target (join-path ( [Environment]::GetFolderPath("MyDocuments")} 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'CurrentUserAllHostsV7CoreProfile.ps1')`



  Note: For development computer: Manually Symlink the Atap.Utilities.Building.Powershell module. TBD -install it as a package

## Per machine configuration

- setup the registry to support "preview as perceived type text" for additional file types

  - Set-PerceivedTypeInRegistryForPreviewPane from module
  - C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Set-PerceivedTypeInRegistryForPreviewPane.ps1

- Disable Windows Search Service Indexing background task
  Change list of drives indexed to only "start programs"
  Delete and rebuild index
  Disable windows indexing service "Windows Search" manually using services applet

  It turns out that Avast has a problem with Powershell when Powershell starts with -EncodedCommand. Avast refuses to allow any mitigation or excpetion to stop Avast from halting Powershell. Windows Defender does not have this problem. So we will NOT replace Windows Defender with Avast.

- Replace Windows Defender with AVAST # obsolete 2023-03-02
  stop Windows Defender Firewall
  stop windows defender service
  stop MsSense service
  disable MsSense service

- Ensure that any service that starts  with 'wd' and include 'Windows Defender' in the description is set to Autostart WindowsDefender and WindowsDefenderFirewall is running
- [Disable Windows Defender in Windows 10](https://superuser.com/questions/947873/disable-windows-defender-in-windows-10) has a deep dive into security settings and permissions for any service,
    browse the registry to `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services`,
a partial list of serices includes wdboot, wdfilter, wdnisdrv, wdnissvc, windefend. another that needs starting is `mpssvc` Windows Defender Firewall
This script will show the Start property for all services with 'Defend' in their description
`Get-ItemProperty -Name 'Start' -path $($((gci HKLM:\SYSTEM\CurrentControlSet\Services).name | ?{$(Get-ItemProperty -Path $($_-replace 'HKEY_LOCAL_MACHINE','HKLM:') -Name 'Description' -ErrorAction SilentlyContinue) -match 'defend'}) -replace 'HKEY_LOCAL_MACHINE','HKLM:')`
Run this command while Avast is installed and it shows all Start key values = 3. Run the command after uninstalling AVASt, and the Start key values are 0 and 2

After uninstalling the Avast

- remove the default version of Pester that comes with windows

  ```Powershell
  $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
  takeown /F $module /A /R
  icacls $module /reset
  icacls $module /grant "*S-1-5-32-544:F" /inheritance:d /T
  Remove-Item -Path $module -Recurse -Force -Confirm:$false
  ```

- Install Pester for PS V7
  - `Install-Module pester -scope 'AllUsers'`
  - Fix Pester installation and or path variable for PS V5 and PS V7

- Install Powershell Script Analyzer (PSScriptAnalyzer)
  - `Install-Module PSScriptAnalyzer -scope 'AllUsers'`
  - Fix PSScriptAnalyzer installation and or path variable for settings specific to the machine

Setup machine-wide Autoruns and startups
avast
ditto
dropbox
nordvpn
sharex

## Per user configuration (as per Role)

### First admin user on the machine

Setup Role-wide Autoruns and startups
avast
ditto
dropbox
nordvpn
sharex

### Set global file associations for notepad++

```Powershell
$suffixs = @('.txt','.log', '.ini', '.inf', '.props', '.java', '.cs', '.inc', 'html', '.asp', '.aspx', '.css', '.js', '.jsp', '.xml', '.sh', '.bash', '.bat', '.cmd', '.py', '.sql', '.ps1','.psm1','.psd1')
Install-ChocolateyFileAssociation  $suffixs "$($env:ProgramFiles)\Notepad++\notepad++.exe"
```

### Service Accounts on the machine (as per Role)

#### Everything Client Service Account

Everything.exe -install-client-service

#### Jenkins Controller Service account


create the subdirectory `Powershell` in the Jenkins Controller Service Account User's home directory
In the newly created Powershell subdirectory, run the following command
`Remove-Item -path (join-path 'C:' 'Users' 'JenkinsServiceAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path 'C:' 'Users' 'JenkinsServiceAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -Target (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','ProfileForServiceAccountUsers.ps1')`

ToDo: figure out how to do this with a published package instead of a symbolic link
ToDo: Figure out how to handle drive/path differences for source

#### Jenkins Client Service account
create the subdirectory `Powershell` in the Jenkins Client Service Account User's home directory
In the newly created Powershell subdirectory, run the following command
`Remove-Item -path (join-path 'C:' 'Users' 'JenkinsAgentSrvAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path 'C:' 'Users' 'JenkinsAgentSrvAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -Target (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','ProfileForServiceAccountUsers.ps1')`

#### MSSQL Service Account

#### IIS Controller Service Account



### Setup Role-wide Autoruns and startups



#### Role:Developer

Install the Powershell build tools. Run the following command `install-module PSScriptAnalyzer -Repository PSGallery -Scope CurrentUser`

Install the Powershell script analysis tools. Run the following command `install-module PSScriptAnalyzer -Repository PSGallery -Scope CurrentUser`
#### Role:QualityAssurance

Install the Powershell script analysis tools. Run the following command `install-module PSScriptAnalyzer -Repository PSGallery -Scope CurrentUser`

#### Install

resx Resource Manager
Voiceattack
Steam
jexus manager (iis manager)

## Setup Printer

Setup HP Printer

## Issues To Be investigated

1. debug response time issues and network issues
   Visual Studio Code terminal and file editing; characters don't appear quickly in response to keyboard input

1. Windows media player
   options - do not save history

1. Inspect Windows Event Logs and remediate

1. "BITS has encountered an error communicating with an Internet Gateway Device"
   Set the Service by the name of "Background Intelligent Transfer Service" to manual

1. "The shadow copies of volume C: were aborted because the shadow copy storage could not grow due to a user imposed limit." Event Id 36 VolSnap
   Disable restore points on all drives ()
   Search settings for "system protection"
   click "create a restore point"
   scan the list of drives for any with "Protection settings = ON"
   turn it off and delete any existing restore points
   Disable the 'Volume Shadow Copy" service

Link Pushbullet to phone


File Extension helpers

setup gopro

from C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\TealeafCommonComputer.ps1

## Pin the services applet to the taskbar

Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\services.msc"

## Pin the event viewer applet to the taskbar

Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\eventvwr.msc"

## Use SQLExpress for Server 2012 if possible

## Allow mixedmode authentication

-ia '/value1=''some value'' '

# Enable SQLServerAgent

choco install MsSqlServer2012Express -ia '/SECURITYMODE=SQL'
Install-ChocolateyPinnedTaskBarItem "C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio\Ssms.exe"

C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\DeveloperComputer.ps1

programs to pin:
perfView
taskManager
scheduled tasks
OneNote
Outlook
RDP
nmap-zenmap
Fiddler
postman
Firefox
Chrome
Edge
Brave
Explorer
Notepadplusplus
VisualStudioCode
structuredBuildlogViewer
ILSpy
Rider
resXResourceManager
pwsh
MSSMS
Voiceattack
Everything

VS Code Extensions
c#

gitignore
gitlens
git graph
ResExExpress
Powershell (from Microsoft)
PowerShell Pro Tools for Visual Studio Code (from Ironman Software)
Draw.io Integration
prettier
Remove TestExplorerUI if it is installed, instead set the settings testExplorer.useNativeTesting to true
git user and password for each repository
PlantUML extension requires the environment variable GRAPHVIZ_DOT= ' c:\program files\graphviz\bin\dot.exe' which is the location where chocolatey installs the local plantuml server
Markdownlint

use the command `code --list-extensions --show-versions > "\\UTAT022\FileShare\$($env:COMPUTERNAME)extensions.list.txt"`

VS Code Options:
testExplorer.useNativeTesting to true
Copy settings from current (ncat016) vscode. Investigate VSC settings sync to keep them aligned

GoogleDrive
download and install the [Google Drive for Windows](Tbd)
Sign In with google account credentials
Create a directory GoogleDrive on the drive of your choice (I chose c:/GoogleDrive)
record in global*MachineAndNodeSettings.ps1 file for all computers, use the following `Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $*.VolumeLabel -eq "Google Drive" } | Select-Object -ExpandProperty 'Name') 'My Drive' `
Join-Path ([Environment]::GetEnvironmentVariable($global:configRootKeys['GoogleDriveBasePathConfigRootKey'])) 'DatedDropboxCursors.json'

Chocolatey package List Backup
ensure the dropbox location is added
ensure the GoogleDrive location is added

## Enable PSRemoting on the new computer

Run the following commands as a local admin on the new computer. Do this in both Powershell Desktop (5.1) and also in Core (Currently Powershell 7.x)

- `Enable-PSRemoting -Force`
- in Powershell core, run `Get-PSSessionConfiguration`
    validate a powershell 7 endpoint now exists
- The machine profile for Powershell Core () should have the line `$PSSessionConfigurationName = 'PowerShell.7'`
    That will make PSRemoting on a client use the Powershell Core configuration endpoint on the server computer

### Add the other computers in the group to existing trustedhosts for WinRM remote management

set-item WSMan:localhost\client\trustedhosts -value $('<NewComputerHostname>,' + (get-Item WSMan:localhost\client\trustedhosts).value)

Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'utat022,utat01,ncat-ltjo,ncat-ltb1,ncat016,ncat041' # ToDo - add wireless hostnames?

### Add the new computer as a trusted host on other computers in the group

### Setup PSRemoting Configuration `WithProfile`

PSRemoting sessions do not run any `profile` files when starting. To do so requires a custom PSRemoting configuration.

- Validate the custom Session Configuration File exists
  `Test-Path "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Profiles\WithProfiles.pssc"`
- Create the subdirectory `C:\Program Files\PowerShell\7\SessionConfig`
  `New-Item -ItemType Directory -Force 'C:\Program Files\PowerShell\7\SessionConfig'`
- Register the new PSSessionConfiguration
  `Register-PSSessionConfiguration -Name 'WithProfile' -path "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Profiles\WithProfiles.pssc"`
- Validate
  `Get-PSSessionConfiguration | Where-Object {$_.Name -eq 'WithProfile'}`

[about_Session_Configurations](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_session_configurations?view=powershell-7.2)
[about_Session_Configuration_Files](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_session_configuration_files?view=powershell-7.2)

### Enable HTTPS on WSMan


### Generate a trusted SSL Certificate for this computer


Until you get a SSL certificate for the new computer, you can TEMPORARILY use unencrypted, but you WILL be putting your password out on the network for any sniffer to see
`winrm set winrm/config/client @{AllowUnencrypted="true"}` # run as admin on the new computer, and on any computer that you want to connect FROM
`winrm set winrm/config/service @{AllowUnencrypted="true"}` # run as admin on the new computer, and on any computer that you want to connect TO

Better, though, is to configure WinRM for HTTPS
[How to configure WINRM for HTTPS](https://docs.microsoft.com/en-us/troubleshoot/windows-client/system-management-components/configure-winrm-for-https)

However, "WinRM HTTPS requires a local computer Server Authentication certificate with a CN matching the hostname to be installed. The certificate mustn't be expired, revoked, or self-signed." Which means you will need

[OpenSSL create client certificate & server certificate with example](https://www.golinuxcloud.com/openssl-create-client-server-certificate/)
[Creating simple SSL certificates for server authentication using OpenSSL](https://blog.oholics.net/creating-simple-ssl-certificates-for-server-authentication-using-openssl/)
[HOW TO CREATE DIGITAL CERTIFICATES USING OPENSSL](https://www.aemcorp.com/managedservices/blog/creating-digital-certificates-using-openssl)

### Authentication for WinRM

Basic Authentication on both the Client and the service

### Powershell PSRemoting maintenance

After any upgrade of Powershell to a new version, the WSMan PSSessionConfiguration needs updating. Run `enable-psremoting` and that will create a new endpoint for the latest configuration, and it will set the endpoint for `powershell.7` to point to the latest version

### Using PSSession

Note that the `WithProfile` configuration must be setup on each of the remote computers
Also note that any errors in the profile file will cause the remote session initialization to fail
`$Computers = ('utat01','utat022','ncat016')`
`$Session = New-PSSession -ComputerName $Computers -ConfigurationName WithProfile`

## Setup Logitech G510s software and drivers

## setup HP Scan software and

## Setup Fiddler Options

## Setup Java

Many of the development and CI tools need Java. Jenkins, PlantUML, diagram generator TBD and TBD all use Java. Managing multiple versions of the Java engine is reuired because not all of these tools will work with just one version.

### Java 17

The jenkins CI tool is the primary Java application. Currently (July 2022), the Jenkins project recommends Java 17.

The code is installed to "C:\Program Files\Eclipse Adoptium\jre-17.0.2.8-hotspot\bin\java.exe", and the PATH variable (Machine scope)  is modified to include `"C:\Program Files\Eclipse Adoptium\jre-17.0.2.8-hotspot\bin\"`


## Setup Jenkins Controller

Everything necessary  to run jenkins is found in the `$ENV:JENKINS_HOME` subdirectory. For any machine having the role of the Jenkins Controller, the value of `$ENV:JENKINS_HOME`is set to the machine' settings' path `$global:configRootKeys['CloudBasePathConfigRootKey']` and`JenkinsHome`. This is assigned at the machine level, so when the Jenkins Controller Service starts, it uses the data in this directory. Note that only one machine in the organization should be designated the Jenkins Controller. (ToDo: add section on High-availability amd scaling for the Jenkins Controller)

The machine name of the Jenkins Controller will be referred to in this document as `JenkinsControllerMachine`

ToDo: how to change the jenkins agents to communicate with the new master

### Change Powershell from V5 to V7 on Controller and Agents

`http://JenkinsControllerMachine:4040/configureTools/`
Jenkins->Configure->Tools->Powershell Installations: Defaultwindows =`C:\Program Files\PowerShell\7\pwsh.exe`

Scheduled Job (within Jenkins) to run the `Get-DropBoxAllFolderCursors-Nightly` job every day. The job imports the eponymous script `Get-DropBoxAllFolderCursors-Nightly.ps1`, then executes the function `Get-DropBoxAllFolderCursors-Nightly`

Scheduled Job (within Jenkins) to run the `Confirm-GitFSCK-Nightly` job every day. The job imports the eponymous script `Confirm-GitFSCK-Nightly.ps1`, then executes the function ``Confirm-GitFSCK-Nightly`

Jenkins reporting of the Validate Tools scripts

PackageManagement for powershell

`Register-PackageSource -Name chocolatey -Location http://chocolatey.org/api/v2 -Provider PSModule -Verbose`

[NuGet package manager – Build a PowerShell package repository](https://4sysops.com/archives/nuget-package-manager-build-a-powershell-package-repository/)

[Build and install local Chocolatey packages with PowerShell](https://4sysops.com/archives/build-and-install-local-chocolatey-packages-with-powershell/)

[Understanding Chocolatey NuGet packages](https://4sysops.com/archives/understanding-chocolatey-nuget-packages/)

[Psake PowershellBuild](https://github.com/psake/PowerShellBuild)

[Build Automation in PowerShell](https://github.com/nightroman/Invoke-Build)

[Catesta is a PowerShell module project generator](https://github.com/techthoughts2/Catesta)

## $Path and $psmodulepath in Powershell V5 (Desktop) and V7 (Core)

[about_PSModulePath](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath?view=powershell-7.2)

[Differences between Windows PowerShell 5.1 and PowerShell 7.x](https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.2)

## Placeholder for code to compare extensions in two instances of Visualstudiocode

$a = ls C:\Dropbox\whertzing\ncat016-dotvscode\.vscode\extensions
$b = ls C:\Users\whertzing\.vscode\extensions
$a1 = $a -replace [regex]::escape('C:\Dropbox\whertzing\ncat016-dotvscode\.vscode\extensions\'), ''
$b1 = $b -replace [regex]::escape('C:\Users\whertzing\.vscode\extensions\'), ''
$c= $a2 | %{if ($b2.contains($_)) {$\_}}

## Setup IIS WebServer

### Enable IIS on Windows 10 or 11


From and elevated Powershell prompt:

The `DISM` module provides the `Enable-WindowsOptionalFeature`, so it must be installed. However, it is not available as a standalone download, it has to be finessed . See this for instructions: [Install DISM powershell module on Windows 7](https://superuser.com/questions/1270094/install-dism-powershell-module-on-windows-7)


[Use Command line to Enable IIS Web server on Windows 11](https://www.how2shout.com/how-to/use-command-line-to-enable-iis-web-server-on-windows-11.html)

`Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-ManagementConsole, IIS-HttpErrors, IIS-HttpRedirect, IIS-WindowsAuthentication, IIS-StaticContent, IIS-DefaultDocument, IIS-HttpCompressionStatic, IIS-DirectoryBrowsing`

To install IIS via the GUI, see
[How to enable IIS (Internet Information Services) on Windows 11](https://www.how2shout.com/how-to/how-to-enable-iis-internet-information-services-on-windows-11.html)

### Add SSLServer certificate to IIS

[Enable HTTPS on IIS](https://techexpert.tips/iis/enable-https-iis/)
### Add SSLServer certificate to Jenkins

[How can I set up Jenkins CI to use https on Windows?](https://stackoverflow.com/questions/5313703/how-can-i-set-up-jenkins-ci-to-use-https-on-windows)

