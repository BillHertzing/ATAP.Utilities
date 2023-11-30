# Setup a new computer

## Introduction

Setting up a new computer can be a daunting task when there are hundreds of customizations needed to make the computer a productive element of an organization's infrastructure.  Infrastructure As Code (IAC) is the discipline that is concerned with formalizing how to codify the customizations, and executing on the configuration to make a computer conform to the customizations desired.

The ATAP utilities repository uses the automation software Ansible to control the setup and upgrade of the hosts in our organization. The sub-repository ATAP.IAC.Ansible contains IAC code that defines the organization's hosts, their roles, and the specific software and configuration needed on the hosts for them to fulfill their roles. See the ATAP.IAC.Ansible [readme] for further information on this

However, a new computer / host requires some setup steps before it can communicate with an IAC Controller host. The purpose of this document is to detail the bootstrapping steps to setup a Window's host so it can communicate with Ansible for the remainder of the setup process. Bootstrapping is the process of initial machine configuration.

Eventually, some of these steps will be incorporated into a Powershell module ad functions that can be loaded and executed

This document starts with the assumption that a new computer is operational, has a monitor and keyboard connected, and can vbe booted into the BIOS.

## Presetup steps

- Create bootable USB stick using rufus, and setup the first user (<firstlocalusername>terminal) on that rufus-built SUB stick image (details TBD)
- Print out Windows activation key

## BIOS modifications

BIOS changes can be made before an operating system is installed. These will be unique to a given machine configuration. These must be done manually when a machine is first powered up.

### utat022 host BIOS modifications

- Change PCIE slot 4 configuration from "M2 extension card" to "dual M2 SSD"
- write down disk number for M2.2 main SSD stick
- Ensure SATA controllers are On
- X.M.P is enabled
- Intel Rapid Storage technology is OFF
- change hotswap notification to "enabled"
- select a single boot option,the USB drive (UEFI)
- save and reboot

## Install the Operating system

Operating systems can be installed from ISO images, or from other image sources. This will describe how to manually install the OS from an ISO image on a USB stick. These instructions are for the Windows OS.

These instructions are for adding a machine to a non-domain workgroup, and creating local users and groups on the machine.

Bootable USB stick is created from an ISO download and Rufus program. Rufus allows you to create a local user and bypass the microsoft account login.

### Windows OS instructions

plug USB stick into bootable usb port
Power up the machine, boot through the USB stick

- follow prompts to install windows, to the M2.2 SSD drive (2TB or bigger)
- when reboot/restart occurs, go into Bios, change boot order to be the M2.2 disk, remove the USB drive
- save and exit
- Follow prompts after rebooting, including setting password for first user

The following steps are run via the Windows UI,

## set Timezone

- via the Windows UI, change timezone as appropriate

## change machine name

- Settings -> system->System Product Name - enter <newcomputerName>

## Network Sharing

using Windows Explorer, navigate to the `network` folder.You will see a prompt indicating network access is turned off. it will offer to turn it on. Select `make this network private and enable discovery and file sharing`

## Boostrap a new host for accepting communications from the IAC controller

Before any IAC controller can configure a new host, the IAC controller software must be able to connect to the host.

### Bootstrap a new host accepting communications from Ansible

Ansible (for Windows) uses WinRM to communicate from the AnsibleController host to the remote hosts.  WinRM must be setup durring the bootstrap process.

#### Enable WinRM

Setup the initial WinRM configuration. Run the command `winrm qc`

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

#### Enable insecure communications

```Powershell
set-item wsman:\localhost\Service\Auth\Certificate true
set-item wsman:\localhost\Service\Auth\Basic true
```

#### Enable WinRM for remote management

Run the following command

```Powershell
Enable-PSRemoting
```

#### Validate the WinRM initial listener configuration

From an administrative terminal on Windows,
Run the command `winrm get winrm/config/Service`. Expected response should be

```Markdown
Service
    RootSDDL = O:NSG:BAD:P(A;;GA;;;BA)(A;;GR;;;IU)S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)
    MaxConcurrentOperations = 4294967295
    MaxConcurrentOperationsPerUser = 1500
    EnumerationTimeoutMS = 240000
    MaxConnections = 300
    MaxPacketRetrievalTimeSeconds = 120
    AllowUnencrypted = false
    Auth
        Basic = true
        Kerberos = true
        Negotiate = true
        Certificate = true
        CredSSP = true
        CbtHardeningLevel = Relaxed
    DefaultPorts
        HTTP = 5985
        HTTPS = 5986
    IPv4Filter = *
    IPv6Filter = *
    EnableCompatibilityHttpListener = false
    EnableCompatibilityHttpsListener = false
    CertificateThumbprint
    AllowRemoteAccess = true

Notes:

- The IP address that start with `169.254.x.x` are unexpected, and according to this article [WinRM Strange ListeningOn Addresses](https://social.technet.microsoft.com/Forums/windows/en-US/3082d5ab-b018-4d99-8697-81cefc4b3543/winrm-strange-listeningon-addresses), come from the "Microsoft Failover Cluster Virtual Adapter", which is hidden.
- Later steps will remove the Failover Clustering feature
- Later steps will disable the HTTP listener, and install a WSMan certificate generated by the organizations internal PKI infrastructure.
- Later steps will setup the TrustedHosts list for the WSman service
- The hostname shown will be the initial host name generated when the OS is installed. Later steps will change the hostname, and modify the hostname entries in the WinRM Listener

```

#### Enable Wake-on-LAN (WoL)

Wake-on-LAN (WoL) is enabled to automatically turn on systems when doing maintenance. Most systems are configured this way automatically, however in some cases they need specific changes to make them work.

Detailed instructions are TBD and are per-host

### Test Ansible connectivity

The default ansible temporary directory is 'C:\temp\ansible`, Run the command

```powershell

# ToDo: get the actual ansible temp directory from the settings for the new host
$null = New-Item -ItemType Directory -Force C:\temp\ansible

````

Ensure the organization's `hosts` file includes the new Windows host.
Ensure the Ansible inventory files include the new host
Ensure the organization's IAC data files include the new host
Generate a new Ansible directory structure, and transfer that to an active Ansible controller

Invoke the ansible WindowsHosts.yml playbook, specify the new Windows host's name, the appropriate inventory file (nonproduction, during new computer setup), execute only tasks tagged with 'Preamble', and provide the extra arguments for user and password.

Run this in an `Ubuntu` terminal on the active Ansible Controller's host

 ```Powershell
$newhostname = 'utat022'
$defaultUser = 'whertzing'
ansible-playbook -l $newhostname playbooks/WindowsHostsPlaybook.yml -i ./nonproduction_inventory.yml  --tags "Preamble"  -e "user=$defaultUser password=  "
```

### Accept the configuration from Ansible

#### WindowsHosts

TBD - update the list of packages by referencing an organization's confidential IAC data

Run This

ansible-playbook -l $newhostname playbooks/WindowsHostsPlaybook.yml -i ./nonproduction_inventory.yml  --tags "Preamble"  -e 'user=whertzing password=obfuscated'
Chocolatey packages

### Document the Operating System baseline (optional)

run the program 'Everything' from a USB stick, get list to a file "01 Clean Windows 11 install, Step 01 Files.efu"

## Install Python for Windows for bootstrapping

TBD - install python310 from an organization's internal repository
TBD - install python311 from a USB stick [TBD]
Current - install Python from the internet

The easiest way to get python is from the microsoft store using winget

### Ensure Winget is present

[Use the winget tool to install and manage applications](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
[Install winget by the command line (powershell)](https://stackoverflow.com/questions/74166150/install-winget-by-the-command-line-powershell)

After a clean new install of Windows, winget won't be present for awhile. To ensure Winget is present, enter the command `winget`. If this is the first time winget has been run for the logged in user, there will be a message asking the user to acknowledge the license terms. If winget is not installed, then try the following commands

```powershell
# get latest download url
$URL = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
$URL = (Invoke-WebRequest -Uri $URL).Content | ConvertFrom-Json |
        Select-Object -ExpandProperty "assets" |
        Where-Object "browser_download_url" -Match '.msixbundle' |
        Select-Object -ExpandProperty "browser_download_url"

# download
Invoke-WebRequest -Uri $URL -OutFile "Setup.msix" -UseBasicParsing

# install
Add-AppxPackage -Path "Setup.msix"

# delete file
Remove-Item "Setup.msix"
```

### Install Python

 Note: as of 7/2/2023 StableDiffusion  will only work with Python 3.10, nothing later (pytorch is required)

`winget install Python.Python.3.10 --scope machine`

`winget install --name 'python 3.10' --version '3.10.11' --accept-package-agreements --accept-source-agreements --silent --location 'C:\Program Files\PythonInterpreters' --source 'winget' --verbose --scope machine --force``

## Add new host to the IAC configuration

At this point, the new host is ready to accept further configuration from the AnsibleController host. See [TBD] for the

### Driver updates

Use the Windows GUI to install driver updates, update all that are out of date
Windows Update -> Advanced Options -> Optional Updates

### Install Dropbox, and sync

### Map User Directories to dropbox
