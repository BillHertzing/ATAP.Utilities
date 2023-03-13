# ReadMe for the ATAP.IAC.Ansible Concept Documentation

## Overview

Infrastructure as Code (IAC) using Ansible as the IAC tool

TBD: This package converts an ATAP project database into an Ansible directory structure suitable for managing an organization's hosts.

Current: This package supplies scripts and placeholder files to create an Ansible directory structure suitable for managing an organization's hosts (servers and desktops) used in the development, testing, deployment, and production use of the organizations software products. Placeholder files must be populated with specific information for an organization.

This package also documenbts the steps to setup a new host to accept connections nad commands from an AnsibleController host

Overview diagram can be found [here; tbd]

## Testing

TBD

## Packaging and Distribution

These resources are deployed to an Ansible directory in WSL2, and to an Infrastructure group's directory (administrators are assigned to the InfrastructureAdministrators group, which in turn allows them access to the files and subdirectories

## Public Functions and Cmdlets



## Data files

Setting up a new host to accept connections from Ansible

## Python for Windows

`choco install python311`


## WSL for Windows

administrator mode
`wsl --install`
`wsl --set-default-version 2`
reboot
Windows terminal now has a 'ubuntu' terminal
Open `ubuntu` in windows termina
enter Linux userid (I use the same as my windows userid)
enter a Linux password

Upgrade ubuntu
`sudo apt update && sudo apt upgrade`

Create a new group to control access to Ansible playbooks and other infrastructure files. I used the group name InfrastructureAdmins
`sudo groupadd InfrastructureAdmins`

Ensure that the new user just created is a member of the InfrastructureAdmins group
`sudo usermod -G InfrastructureAdmins <YourUserID>`

### Powershell Core for WSL

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

add `pwsh` a s last line of $Home/.profile
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

'sudo apt install smbclient'

## SSH Server for Windows

 [Configuring OpenSSH-Server (sshd) on Windows 11](https://erwin.co/configuring-openssh-server-sshd-on-windows-11/)


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

Windows server does not accept public key transfers using

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

# This expect pwsh or Powershell to be available on the Windows container
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

python3 --version

### Setup pip in WSL2

curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py

get-pip.py or python3 get-pip.py --user
 python3 -m pip -V

## Setup Ansible Control Node in WSL 2

python3 -m pip install --upgrade --user ansible
python3 -m pip show ansible

sudo apt --only-upgrade install ansible

### Edit Ansible configuration file

Can be done with notepad++ from Windows hosts, at the Windows path "\\wsl.localhost\Ubuntu\etc\ansible\ansible.cfg". Remember to ensure the file has Linux line-endings (LF), not Windows line-endings (CR-LF)
[Ansible Configuration Settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html)\

Create a configuration file with all options, commented out, and all extensions, also commented out Run on the WSL2 container
`ansible-config init --disabled -t all > ansible.cfg`

Ensure the following line in the config file is not commented
`enable_plugins=host_list, script, auto, yaml, ini, toml`

To enable Ansible running on ubuntu in WSL 2 to connect to target machins running Windows, make the following changes to the `/etc/ansible/ansible.cfg`, under the `[defaults]` section
`executable=pwsh`

### Edit Ansible inventory file

Can be done with notepad++ from Windows hosts, at the Windows path "\\wsl.localhost\Ubuntu\etc\ansible\hosts.yml". Remember to ensure the file has Linux line-endings (LF), not Windows line-endings (CR-LF)

Here is an example with three simple Windows hosts. Note that these host names are related to their IP address by entries in the Windows hosts file at `C:\Windows\System32\drivers\etc\hosts`

```yaml
---
all:

windows:
  hosts:
    ncat016:
    utat022:
    utat01:
    ncat-ltb1:
    ncat040:
  vars:
    ansible_remote_tmp: D:\Temp\Ansible
    ansible_shell_type: cmd
    ansible_shell_executable: pwsh
    ansible_pwsh_interpreter: pwsh
    ansible_Powershell_interpreter: Powershell
    become_method: runas
```

### Test Ansible connection to the Windows hosts

 in the WSL2 container
 `ansible all  -i /etc/ansible/hosts.yml -m ping`

### Ansible for Windows collection

on WSL2 run `ansible-galaxy collection list`

### Edit Ansible Playbook file file

The location and the ownership of the Ansible Playbook files are at directory TBD, and the group owning the file is TBD. Ensure that all




