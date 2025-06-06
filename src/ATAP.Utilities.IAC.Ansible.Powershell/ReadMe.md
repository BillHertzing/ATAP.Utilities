# ReadMe for the ATAP.IAC.Ansible Concept Documentation

## Overview

Infrastructure as Code (IAC) using Ansible as the IAC tool.

TBD: This package converts an ATAP project database into an Ansible directory structure suitable for managing an organization's hosts.

Current: This package supplies scripts and placeholder files to create an Ansible directory structure suitable for managing an organization's hosts (servers and desktops) used in the development, testing, deployment, and production use of the organizations software products. Placeholder files must be populated with specific information for an organization.

This package does not document the steps to setup a new host to accept connections and commands from an AnsibleController host. For the instructions to setup a new computer / host so that it can accept connections and commands from Ansible, see [tbd]

Overview diagram of this package and how it interacts with the organizations hosts can be found [here; tbd]

The AnsibleController host must be configured before Ansible will run. The ATAP Utilities repository is primarily written around Windows hosts, so these instructions will start from a very low level to setup an AnsibleController on a Windows Subsystem for Linux (WSL) container running on a Windows 11 host.

The scripts use the populated placeholder files to create the entire Ansible directory structure, which is then deployed to an Infrastructure group's Ansible directory in WSL2. Administrators are assigned to the InfrastructureAdministrators group, which in turn allows them run Ansible and access the subdirectories and files that describe the infrastructure at the organization

Prerequisite:

- Windows Terminal
- Internet Access (OR)
- Local package repository with vetted versions of the following [tbd]

## enable Windows Features for WSL

Windows settings -> Option Features-> Additional Optional Features, Turn on 'Virtual Machine Platform' and 'Windows Subsystem for Linux', then reboot

(or the following untested command lines)

```Powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

reboot if prompted

Note that if you want to remove everything from WSL, run the following commands (this assumes there is only one installed distro)

```Powershell
wsl --shutdown
@(,$(wsl -l -v))
$distroToRemove = Read-Host -Prompt 'Distro to remove'
wsl --unregister $distroToRemove
```

## Setup WSL for Windows

Enter the following command from a terminal running elevated ("run as Administrator") [Linux distribution and version may change in the future]

```Powershell
$distroToInstall = Read-Host -Prompt 'Distro to install'
wsl --install $distroToInstall
wsl --set-default-version 2
```

You are now taken into a 'Ubuntu' terminal. Windows Terminal will also have an entry (profile) for Ubuntu
Enter a userid and password to be the first admministrative user
enter Linux userid (I use the same as my windows userid)
enter a Linux password

Instructions from here to TBD are should be executed in a 'ubuntu-22.04' terminal

```bash
# add the default user to the sudoers file
# TBD - seems to be difficulat to do....

# Upgrade ubuntu
sudo apt update && sudo apt upgrade
```

### Set Python to version 3.10

```bash
sudo apt remove python3-apt -y
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa
```

### Install Powershell Core for WSL

[Installation of pwsh via Package Repository](https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.3#installation-via-package-repository)

```bash
# Update the list of packages
sudo apt-get update
# Install pre-requisite packages.
sudo apt-get install -y wget apt-transport-https software-properties-common
# Download the Microsoft repository GPG keys
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
# Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb
# Update the list of packages after we added packages.microsoft.com
sudo apt-get update
# Install PowerShell
sudo apt-get install -y powershell
# Start PowerShell
pwsh
```

### Invoke pwsh on login

To add `pwsh` as the last line of ~/.profile run this command

```powershell
$lines = gc ~/.profile; $lines += 'pwsh'; Set-Content -path ~/.profile -Value $lines
```

### Create a new group for Infrastructure admins to control aceess to ansible

```powershell
$InfrastructureAdminsGroupName = 'InfrastructureAdmins'
sudo groupadd $InfrastructureAdminsGroupName
```

### Ensure that the new administrative user just created is a member of the InfrastructureAdmins group

```powershell
$userid = whoami
sudo usermod -aG $InfrastructureAdminsGroupName $userid
```

### Powershell paths for WSL container and WSL User

[PowerShell paths](https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.3#powershell-paths)

#### WSL Container Machine profile

at `$PSHOME/profile.ps1`, contents TBD

#### WSL Container User profile

at `~/.config/powershell/profile.ps1`, contents TBD

#### WSL Container Module locations

TBD See link above for details

#### WSL SSH Client setup

#### Create Public/Private Key Pair with Passphrase

Use ed25519 algorithm for secure keys, enter a passphrase when prompted
`ssh-keygen -t ed25519`

Confirm two files have been created in $HOME/.ssh with the names id_ed25519 and id_ed25519.pub

#### Configure ssh-agent service for automatic startup on WSL

TBD

#### Confirm ssh_agent is running

`eval "$(ssh-agent -s)"`

#### Register private key with the ssh-agent

`ssh-agent $HOME/.ssh/id_ed25519`

### SMB1 Client for Ubuntu

TBD: this may not be needed - no real reason to access SMB from WSL, yet
`sudo apt install smbclient`

## SSH Server for Windows

 [Configuring OpenSSH-Server (sshd) on Windows 11](https://erwin.co/configuring-openssh-server-sshd-on-windows-11/)

From an elevated Powershell prompt, run the following commands

```Powershell
Get-WindowsCapability -Online | Where-Object Name -like ‘OpenSSH.Server*’ | Add-WindowsCapability –Online
Set-Service -Name sshd -StartupType 'Automatic'
netsh advfirewall firewall add rule name="OpenSSH-Server-In-TCP" dir=in action=allow protocol=TCP localport=22
```

test using `ssh username@hostname` from the WSL contrainer to the SSH Server for Windows machine.

### Change the SSH Server for Windows's DefaultShell to Powershell Core

Find the location of Powershell Core interperter (pwsh.exe) on the machine and set a registry key property to that path

```Powershell
$pwshPath = (get-command 'pwsh.exe').path
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $pwshPath -PropertyType String –Force
```

### Create the administrators_authorized_keys file for storing authorized SSL keys for administrators, and protect it

```Powershell
$aakPath = $(Join-Path $Env:ProgramData 'ssh' 'administrators_authorized_keys')
New-Item -ItemType File -Force $aakPath
icacls.exe $aakPath /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
```

### Key-based authentication for OpenSSH

[Key-based authentication in OpenSSH for Windows](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement?source=recommendations)

#### create keys
Use ed25519 algorithm for secure keys, do not enter a passphrase
`ssh-keygen -t ed25519`

#### Configure ssh-agent service

ssh-agent is used to securely store the private ssh key's passphrase under a security context associated with the specific user

```Powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
```

#### Load key files and passphrase into the ssh-agent

`ssh-add $env:USERPROFILE\.ssh\id_ed25519`

### Add public key to ssh servers

The public key has to be added to the SSH Server on every machine to which a ssh connection will be made
We intend to use SSH with Ansible to allow Ansible to manage the IAC configuration of a machine, so this must be done on every computer listed in the Ansible inventory.
The configuration changes to be made on the target machine will usually require administrative access.

```Powershell
# This expects Powershell or Powershell-core to be the WSL command interpreter
# Get the public key file generated previously on the WSL client
$authorizedKey = Get-Content -Path $Home\.ssh\id_ed25519.pub

# This expects pwsh or Powershell to be available on the Windows container
# Powershell-core (pwsh) works, but Powershell Desktop has a problem. This means that Powershell core must be installed in the Windows Server before this command can set up the administrators_authorized_keys file
# Generate the PowerShell script to be run remote that will copy the public key file generated previously on the WSL client to the authorized_keys file on the Windows SSH server
$remotePowershell = 'Add-Content -Force -Path $(Join-Path $Env:ProgramData "ssh" "administrators_authorized_keys") -Value "' + $authorizedKey + '";icacls.exe "$(Join-Path $Env:ProgramData "ssh" "administrators_authorized_keys")" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"'
# Connect to the Windows SSH server and run the PowerShell using the $remotePowerShell variable
ssh <username>@<servername> $remotePowershell
```

For a different take on sharing SSH keys from a Windows container into the WSL 2 subsystem within, see also [Sharing SSH keys between Windows and WSL 2](https://devblogs.microsoft.com/commandline/sharing-ssh-keys-between-windows-and-wsl-2/)


### edit sshd_config

The file located at `$(Join-Path $Env:ProgramData "ssh" "sshd_config")` configures the Windows SSH server. Ensure that the line `PubkeyAuthentication yes` exists and is not commented out. If you have to edit/change this file the SSHD service must be stopped and restarted.

```Powershell
$SSHService =   (Get-Service | ?{$_.name -eq 'sshd'})[0]
Stop-Service $SSHService
Start-Service $SSHService
```

## Setup Python in WSL 2

`python3 --version`

### Setup pip in WSL2

`sudo apt install python3-pip`

## Setup Ansible Control Node in WSL 2

Run the following in the 'Ubuntu' terminal

```Powershell
sudo apt-add-repository ppa:ansible/ansible -y
sudo apt-get update
sudo pip3 install pywinrm -y
sudo pip3 install pyvmomi -y
sudo apt-get install ansible -y

```

### Create and Edit Ansible configuration file

[Ansible Configuration Settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html)

Create the default ansible.cfg file, edit it, then place it into a location where Ansible wil find it

#### Create default Ansible configuration file

Create a configuration file with all options, commented out, and all extensions, also commented out.

Run on the Ubuntu terminal

```powershell
$ansibleVersionString = $($(ansible --version) -split [Environment]::NewLine)[0] -replace 'ansible\s+\[core\s+(.*?)]','$1'
$ansibleDisabledConfigFileName = "AnsibleConfigAllDisabled-$ansibleVersionString.cfg"
ansible-config init --disabled -t all > $ansibleDisabledConfigFileName
'$ansibleDisabledConfigFileName = ''' + $ansibleDisabledConfigFileName + '''' # for use in the next steps
'$ansibleDisabledConfigFileLinuxFullName = ''' + $(gci $ansibleDisabledConfigFileName).fullname + '''' # for use in the next steps
```

#### Copy to Repository

copy the last two lines displayed in the Ubuntu terminal
Run the following commands on the Windows Powershell terminal

```powershell
# paste in the last two lines generated on the Ubuntu terminal setting the values of
#  $ansibleDisabledConfigFileName $ansibleDisabledConfigFileLinuxFullName

$sourcePath = "\\wsl.localhost\Ubuntu-22.04\$ansibleDisabledConfigFileLinuxFullName"
$destinationPathOnWindowsForOriginal = "C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\etc\ansible\$ansibleDisabledConfigFileName"
cp $sourcePath $destinationPathOnWindowsForOriginal
```

#### Modify the configuration file in the repository

Run the following commands on the Windows Powershell terminal, after changing into organizations' IAC repository's `Wsl2Ubuntu\etc\ansible` directory.

```powershell
$ansibleDraftAnsibleConfigFilename = 'DraftModifiedAnsibleConfig.cfg'

cp $ansibleDisabledConfigFileName $ansibleDraftAnsibleConfigFilename
```

Edit the file `$ansibleDraftAnsibleConfigFilename`

Remember to ensure the file has Linux line-endings (LF), not Windows line-endings (CR-LF)
[Ansible Configuration Settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html)\

Ensure the following line in the config file is not commented
`enable_plugins=host_list, script, auto, yaml, ini, toml`

To enable Ansible running on ubuntu in WSL 2 to connect to target machines running Windows and use Powershell Core on the hosts, under the `[defaults]` section
`executable=pwsh`

save the file then rename it.

```powershell
$ansibleDraftAnsibleConfigFilename = 'DraftModifiedAnsibleConfig.cfg'
$ansibleLatestAnsibleConfigFilename = 'LatestModifiedAnsibleConfig.cfg'
mv $ansibleDraftAnsibleConfigFilename $ansibleLatestAnsibleConfigFilename
```

#### Copy the modified Ansible configuration file to Ubuntu

Run this in the Ubuntu window

```Powershell
$ansibleLatestAnsibleConfigFilename = 'LatestModifiedAnsibleConfig.cfg'
$ansibleFinalConfigFilename = 'ansible.cfg'
$destinationDirOnLinuxForModified = "/etc/ansible/"
sudo mkdir $destinationDirOnLinuxForModified
$destinationPathOnLinuxForLatest = "$($destinationDirOnLinuxForModified)$($ansibleFinalConfigFilename)"
$destinationPathOnWindowsForLatest = "/mnt/c/Dropbox/whertzing/GitHub/ATAP.IAC/Wsl2Ubuntu/etc/ansible/$($ansibleLatestAnsibleConfigFilename)"
sudo cp $destinationPathOnWindowsForLatest $destinationPathOnLinuxForLatest
```

## Testing the AnsibleController hosts

The core `win_ping` ansible module verifies the connection from the AnsibleController to a remote host. The AnsbileController needs a minimal inventory file.

### Create minimal Ansible inventory file

Run the following Powershell commands. Replace the hostname shown with the host name of the machine hosting the WSL container

```Powershell
$defaultPassword = 'obfuscated'
$defaultUser = 'whertzing'
$defaultPythonInterpreter = 'python3'
# ensure the directory exists, or the ansible connection to the host will fail
$defaultAnsibleRemoteTmp =  'C:\Temp\Ansible'

$hostnames = @{
'ncat016' =  @{user=$defaultUser;'password' = $defaultPassword;  RemoteTmp = $defaultAnsibleRemoteTmp }
'ncat-ltb1' = @{user='whertzing56';'password' = $defaultPassword; PythonInterpreter = 'C:\ProgramData\chocolatey\bin\python3.10.exe'; RemoteTmp = 'D:\Temp\Ansible' }
'utat01' =  @{user=$defaultUser;'password' = $defaultPassword; PythonInterpreter = $defaultPythonInterpreter; RemoteTmp = $defaultAnsibleRemoteTmp }
'utat022' =  @{user=$defaultUser;'password' = $defaultPassword; PythonInterpreter = $defaultPythonInterpreter; RemoteTmp = $defaultAnsibleRemoteTmp }
}
$minimalInventoryPath = '~/Ansible/minimalInventory.yml'

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
[void]$sb.Append(@"
---
all:
windows:
  hosts:
"@)
$keys =  @($($hostnames.keys))
for ($index = 0; $index -lt $keys.count; $index++) {
  $key = $keys[$index]
  [void]$sb.Append(@"

    $key :
      ansible_user: $($($hostnames[$key]).user)
      ansible_password: $($($hostnames[$key]).password)
      # ansible_python_interpreter: $($($hostnames[$key]).PythonInterpreter)
      # ansible_remote_tmp: $($($hostnames[$key]).RemoteTmp)
"@)
}
[void]$sb.Append(@"

  vars:
    ansible_connection: winrm
    ansible_winrm_transport: ntlm
    # allow the use of a self-signed cert on the remote windows host
    ansible_winrm_server_cert_validation: ignore
    become_method: runas
    # ansible_shell_type: cmd   # TBD - confirm what works best; powershell or pwsh
    # ansible_shell_executable: pwsh
    # ansible_pwsh_interpreter: pwsh
    # ansible_Powershell_interpreter: Powershell

"@)
Set-Content -Path $minimalInventoryPath -Value $sb.ToString()
gc  $minimalInventoryPath

```

Note that Ansible does not use the Python interpreter on the Windows host, it only uses powershel. So there is no need to specify a specific Python interpreter.


### Test Ansible connection to the Windows hosts

 in the WSL2 container

 ```Powershell
ansible all  -i $minimalInventoryPath -m win_ping
```

Do not use te core module `ping`, as it will try to use a python interpreter on the Windows hosts, which is not supported.

The correct response from Ansible,  after some status responses, ends with the string response 'pong'

### Ansible for Windows collection

Ansible has a large collection of contributed modules and code, organized into the ansible-galaxy. There are two collections aimed at Windows hosts, the ansible.windows collection and the community.windows collection. Our organization makes
The AnsibleController needs access to both Windows ansible module. Install both.

Note: to see the collections currently installed on the WSL2 instance, run `ls ~/.ansible/collections`

Future TBD : download from a vetted protected internal repository
Current: Fetch and load from internet
On the Ubuntu WSL2 terminal run these two commands to install the collections to `~/.ansible/collections`

```Powershell
ls ~/.ansible/collections/ansible_collections # if the following two collections are not present, run the remainder of the commands herehave been added
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install community.windows
ls ~/.ansible/collections/ansible_collections # note that the collections have been added
```

### Hardening the remote host's WinRM connection

see also [Understanding and troubleshooting WinRM connection and authentication: a thrill seeker's guide to adventure ](https://www.hurryupandwait.io/blog/understanding-and-troubleshooting-winrm-connection-and-authentication-a-thrill-seekers-guide-to-adventure)

Future: TBD: Connect to the remote host using basic auth without CredSSP, and let ansible run the following commands
Current: On any remote host that will be controlled by Ansible, run the following command
`Enable-WSManCredSSP -Role Server -Force`

## Creating the organization's infrastructure code

Now that the AnsibleController has been setup, the next step is to define and document an organization's infrastructure. Defining the infrastructure is done in code, but documenting it, outside of the code itself, is difficult and very prone to becoming quickly outdated. This Powershell subrepository is dedicated to the automatic creation of the infrastructure code. The next sections describe how the powershell scripts and placeholder files interact.

### Create the Ansible directory structure and files

TBD: generate the complete Ansible directory structure and files from the project database
current: The main Powershell script is called `Create-AnsibleDirectoryStructure.ps1`. This script, and the scripts it calls will create a generated complete Ansible directory structure and files.


### Edit Ansible Playbook file

The location and the ownership of the Ansible Playbook files are at directory TBD, and the group owning the file is TBD. Ensure that all

Current: The IAC configuration is stored in the subrepository `ATAP.IAC.Ansible`. The script `Create-AnsibleDirectoryStructure.ps1` from that repository can be run to output a complete Ansible directory structure and its contents.
Documentation can be found [here; TBD]

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


## Hardware Level setup for a new computer

### Windows Operating System Prerequisites setup

Create latest Windows 11 bootable USB stick. Use Rufus, select local account use 'FirstAdmin' as name of administrator user
Print latest Windows 11 Pro license Key, have it ready to type into the windows setup screens

### BIOS modifications

### specific per-computer, these are for utat022

ToDo: review BIOS pages and ensure these are complete and correct

- Change PCIE slot 4 configuration from "M2 extension card" to "dual M2 SSD"
- Ensure SATA controllers are On
- X.M.P is enabled
- Intel Rapid Storage technology is OFF
- change hotswap notification to "enabled"
- multiple GPUs enabled (

## install the Operating system

unplug SATA drives, leave just PCIE drive in
disconnect from internet
Install Windows 11 Pro to (unformatted) drive 0

run Everything from USB stick, get list to a file "01 Clean Windows 11 install, Step 01 Files.efu"
reconnect SATA drives

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
Obsolete, use Ansible instead Copy InstChoco and packagesconfig to Filesharecopy from fileshare to \\mydocuments\ChocolateyPackageListBackup

Install hosts to new computer
copy hosts to \\utat022\fileshare and then to new computer
Start Powershell (old), run Instchoco.exe as admin

Install Dropbox to c:\

create the primary user on the computer
use settings account adduser and on screen prompts, or try

If the primary user on the computer is 'AUserName',
make AUserName a member of  the local administrators group
`Add-LocalGroupMember -Group "Administrators" -Member 'AUserName' `
reboot

 Give the primary user acccess to the C:\Dropbox directory created by FirstAdmin
Download the Powershell NTFS moduleterm
S
 local admins run `Add-NTFSAccess -Path "C:\dropbox" -Account "utat022\whertzing" -AccessRights FullControl
and that user has been added to the administrators group

see also C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\MapUserShellFoldersToDropBox.ps1

Set Locations for MyDocuments, Pictures, Videos, Downloads to c:\Dropbox


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
powershell Invoke-Build module

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

### Git Setup

The Git configuration file `.gitconfig` is stored in the mapped cloud filesystem drive, under the user's 'Documents folder'/Git  An environment variable called $env:GIT_CONFIG_GLOBAL points to this file. That works for the pwsh terminal and for the Powershell Integrated Terminal in VSC, but it does NOT work for the VSC Git Extensions. Instead, the GIT VSC extension seems like it only reads whatever is in `"C:\Program Files\Git\etc\gitconfig"`. So you can either merge that file with what is below, or, you can modify that file to

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
  - New-LocalUser -Name "HashicorpVaultSrv
  Acct" -Description "Runs Vault Server task" -NoPassword # ToDo - if password where will it get the credential from?
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
   ToDO: Keepass secret vault  is for an alternate secrets vault
   ToDO: `DISM` is for enabling Windows Features, but it is not available for direct download. See
  `@('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore', 'SecretManagement.Keepass', 'PSFramework', 'DISM') | ForEach-Object { if (-not (Get-Module -ListAvailable -Name  $_)) { Install-Module -Name $_ -Scope AllUsers}}`

- 32-Bit powershel Desktop Modules will not import automatically, run the foillowing lines
  - for installing any certificates via powershell
  `Import-Module -Name C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PKI\pki.psd1`

  - For NetTCPIP functions like `test-port`
  `Import-Module -Name "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\NetTCPIP\NetTCPIP.psd1"`

- Install the following ATAP.Utilities packages machine-wide

  - ATAP.Utilities.Powershell
    - Before Package Management
      - install the PSFramework requiredPackage
      - Install the machine profile files. Install them into $env:ProgramFiles\Powershell\Modules\ATAP.Utilities.Powershell\Resources\Profiles
      - Install the package descriptor file. Install them into $env:ProgramFiles\Powershell\Modules\ATAP.Utilities.Powershell
      - Install the package library file. Install them into $env:ProgramFiles\Powershell\Modules\ATAP.Utilities.Powershell
      - Symlink the AllUsersAllHosts machine profile from Resources\Profiles\ to

        ``` Powershell

             Remove-Item -path $(join-path $env:ProgramFiles 'PowerShell' 'Modules' 'global_ConfigRootKeys.ps1') -ErrorAction SilentlyContinue
             New-SymbolicLink -symbolicLinkPath $(join-path $env:ProgramFiles 'PowerShell' 'Modules' 'global_ConfigRootKeys.ps1')

        ```

      - Symlink the settings files global_ConfigRootKeys.ps1, HostSettings.ps1, global_EnvironmentVariables.ps1 from the powershell module to the global profile location
      -
    - After Package Management
       - WinGet ATAP.Utilities.Powershell

  Before Package Management

  Symlink the profile files for the machine as follows:

```Powershell
Remove-Item -path $(join-path $env:ProgramFiles 'PowerShell' '7' 'global_ConfigRootKeys.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path $(join-path $env:ProgramFiles 'PowerShell' '7' 'global_ConfigRootKeys.ps1') -Target $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'global_ConfigRootKeys.ps1')

Remove-Item -path $(join-path $env:ProgramFiles 'PowerShell' '7' 'HostSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path $(join-path $env:ProgramFiles 'PowerShell' '7' 'HostSettings.ps1') -Target $(join-path -path $([Environment]::GetFolderPath("MyDocuments")) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.IAC','Windows','HostSettings.ps1'))

Remove-Item -path $(join-path ($env:ProgramFiles) 'PowerShell' '7' 'global_EnvironmentVariables.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path $(join-path $env:ProgramFiles 'PowerShell' '7' 'global_EnvironmentVariables.ps1') -Target $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'global_EnvironmentVariables.ps1')
```

  Symlink the profile file for the first admin user on this machine It must be linked to both the standard terminal per user profile, and also to the VSCode special powershell terminal profile

```Powershell

Remove-Item -path $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.PowerShell_profile.ps1') -Target $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'CurrentUserAllHostsV7CoreProfile.ps1')

Remove-Item -path $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.VSCode_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'PowerShell' 'Microsoft.VSCode_profile.ps1') -Target $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.Utilities.PowerShell' 'profiles' 'CurrentUserAllHostsV7CoreProfile.ps1')
```

Symlink the .gitconfig file for the first admin user on this machine.

```Powershell

Remove-Item -path $(join-path $([Environment]::GetFolderPath("MyDocuments")) '.gitconfig') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path $(join-path $([Environment]::GetFolderPath("MyDocuments")) '.gitconfig' ) -Target $(join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' '.gitconfig')

```

  Note: For development computer: Manually Symlink the Atap.Utilities.Building.Powershell module. TBD -install it as a package

## Per machine configuration

- NOTE: Powertoys superseededs this as of 8/30/2023 setup the registry to support "preview as perceived type text" for additional file types

  - Set-PerceivedTypeInRegistryForPreviewPane from module
  - C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Set-PerceivedTypeInRegistryForPreviewPane.ps1

- Disable Windows Search Service Indexing background task
  Change list of drives indexed to only "start programs"
  Delete and rebuild index
  Disable windows indexing service "Windows Search" manually using services applet

  It turns out that Avast has a problem with Powershell when Powershell starts with -EncodedCommand. Avast refuses to allow any mitigation or exception to stop Avast from halting Powershell. Windows Defender does not have this problem. So we will NOT replace Windows Defender with Avast.

- Replace Windows Defender with AVAST # obsolete 2023-03-02
  stop Windows Defender Firewall
  stop windows defender service
  stop MsSense service
  disable MsSense service

- setup Windows Defender

- Ensure that any service that starts  with 'wd' and include 'Windows Defender' in the description is set to Autostart WindowsDefender and WindowsDefenderFirewall is running
- [Disable Windows Defender in Windows 10](https://superuser.com/questions/947873/disable-windows-defender-in-windows-10) has a deep dive into security settings and permissions for any service,
    browse the registry to `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services`,
a partial list of serices includes wdboot, wdfilter, wdnisdrv, wdnissvc, windefend. another that needs starting is `mpssvc` Windows Defender Firewall
This script will show the Start property for all services with 'Defend' in their description
`Get-ItemProperty -Name 'Start' -path $($((gci HKLM:\SYSTEM\CurrentControlSet\Services).name | ?{$(Get-ItemProperty -Path $($_-replace 'HKEY_LOCAL_MACHINE','HKLM:') -Name 'Description' -ErrorAction SilentlyContinue) -match 'defend'}) -replace 'HKEY_LOCAL_MACHINE','HKLM:')`
Run this command while Avast is installed and it shows all Start key values = 3. Run the command after uninstalling AVASt, and the Start key values are 0 and 2

- Windows Defender will complain that the hosts file has been modified. Manually allow that. TBD: figure out how to make it  happen with Ansible, so no manual step is required

After uninstalling the Avast

- remove the default version of Pester that comes with windows

  ```Powershell  $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
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

# ToDo: Install-ChocolateyFileAssociation is no longer part of chocolatey setup - fix this or fix the following

```Powershell
$suffixs = @('.txt','.log',  '.inf', )
Install-ChocolateyFileAssociation  $suffixs "$($env:ProgramFiles)\Notepad++\notepad++.exe"
```

### Set global file associations for VSC

```Powershell
$suffixs = @( '.ini','.props', '.java', '.cs', '.inc', 'html', '.asp', '.aspx', '.css', '.js', '.jsp', '.xml', '.sh', '.bash', '.bat', '.cmd', '.py', '.sql', '.ps1','.psm1','.psd1')
Install-ChocolateyFileAssociation  $suffixs "$($env:ProgramFiles)\Microsoft VS Code\Code.exe"
```

### Service Accounts on the machine (as per Role)

#### Everything Client Service Account

Everything.exe -install-client-service

#### Jenkins Controller Service account

create the subdirectory `Powershell` in the Jenkins Controller Service Account User's home directory. In the newly created Powershell subdirectory, run the following command
`Remove-Item -path (join-path 'C:' 'Users' 'JenkinsServiceAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path 'C:' 'Users' 'JenkinsServiceAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -Target (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','ProfileForServiceAccountUsers.ps1')`

ToDo: figure out how to do this with a published package instead of a symbolic link
ToDo: Figure out how to handle drive/path differences for source

#### Jenkins Agent Service account

create the subdirectory `Powershell` in the Jenkins Agent Service Account User's home directory
In the newly created Powershell subdirectory, run the following command
`Remove-Item -path (join-path 'C:' 'Users' 'JenkinsAgentSrvAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path 'C:' 'Users' 'JenkinsAgentSrvAcct','PowerShell','Microsoft.PowerShell_profile.ps1') -Target (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities','src','ATAP.Utilities.PowerShell','profiles','ProfileForServiceAccountUsers.ps1')`

#### MSSQL Service Account

#### IIS Controller Service Account



### Setup Role-wide Autoruns and startups

#### Role:Developer

To ensure that nuget has a recognized endpoint for the public nuget servers, update the user's NuGetConfig file (C:\Users\{username}\AppData\Roaming\NuGet\nuget.config)
run this command (per user)

```Powershell
dotnet nuget add source --name nuget.org https://api.nuget.org/v3/index.json
```

Install the Powershell build tools. Run the following command:

```Powershell
install-module PSScriptAnalyzer -Repository PSGallery -Scope CurrentUser
```

Install the Powershell script analysis tools. Run the following command:

```Powershell
install-module PSScriptAnalyzer -Repository PSGallery -Scope CurrentUser
```

#### Role:QualityAssurance

Install the Powershell script analysis tools. Run the following command:

```Powershell
install-module PSScriptAnalyzer -Repository PSGallery -Scope CurrentUser
```

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

Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'utat022,utat01,ncat-ltjo,ncat-ltb1,ncat016,ncat016-vs,ncat041' # ToDo - add wireless hostname and add default virtual switch for each host

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

Java setup is accomplished using the Ansible Role  `JavaInterpreter`. This is a foundational role, and is run against all of the hosts in the WindowsHost group. The Powershell script `RoleJavaInterpreter.ps1` generates the task, vars, and configuration file(s) for each version of Java installed. It also uses registry settings which sets the machine-level PATH environment variable, the JAVA_HOME and JAVA_EXE environment variable, and the JARPATH environment variable.

Many of the development and CI tools need Java. Jenkins, PlantUML, diagram generator TBD and TBD all use Java. Managing multiple versions of the Java engine is required because not all of these tools will work with just one version.

### Java 17

The Jenkins CI tool uses the Java interpreter. Currently (July 2023), the Jenkins project recommends Java 17. The ATAP organization uses the Eclipse Adoptium Java interperter. The Ansible Role `JavaInterpreter` uses chocolatey to install a specific version of Java, as specified in the ChocolateyPackageProductionInformation file. The version number from this file is also used to setup the environment variables at the machine level in the remote Windows host.

The installation mechanism for Eclipse Adoptium places the executable and configuration files in the path `$global:settings[$global:configRootKeys['JavaEclipseAdoptiumFolderPathPattern'] -replace 'jre-.*?-hotspot', jre-$global:settings[$global:configRootKeys['JavaEclipseAdoptiumVersion']-hotspot"`

Environment Variables
The code is installed to "C:\Program Files\Eclipse Adoptium\jre-17.0.2.8-hotspot\bin\java.exe", and the PATH variable (Machine scope)  is modified to include `"C:\Program Files\Eclipse Adoptium\jre-17.0.2.8-hotspot\bin\"`

## Setup Jenkins Controller

Everything necessary  to run jenkins is found in the `$ENV:JENKINS_HOME` subdirectory. For any machine having the role of the Jenkins Controller, the value of `$ENV:JENKINS_HOME`is set to the machine' settings' path `$global:configRootKeys['CloudBasePathConfigRootKey']` and`JenkinsHome`. This is assigned at the machine level, so when the Jenkins Controller Service starts, it uses the data in this directory. Note that only one machine in the organization should be designated the active Jenkins Controller. (ToDo: add section on High-availability and scaling for the Jenkins Controller, also how to have a second or third machine act as a disconnected Jenkins Controller)

The resolvable machine name of the Jenkins Controller will be referred to in this document as `JenkinsControllerHostName`

ToDo: how to change the jenkins agents to communicate with the new master

### Change Powershell from V5 to V7 on Controller and Agents

`http://JenkinsControllerHostName:4040/configureTools/`
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

```Powershell
$a = ls C:\Dropbox\whertzing\ncat016-dotvscode\.vscode\extensions
$b = ls C:\Users\whertzing\.vscode\extensions
$a1 = $a -replace [regex]::escape('C:\Dropbox\whertzing\ncat016-dotvscode\.vscode\extensions\'), ''
$b1 = $b -replace [regex]::escape('C:\Users\whertzing\.vscode\extensions\'), ''
$c= $a2 | %{if ($b2.contains($_)) {$\_}}
```

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


