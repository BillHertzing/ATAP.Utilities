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
    ListeningOn = 127.0.0.1, 169.254.57.70, 169.254.70.187, 169.254.112.251, 169.254.190.156, 169.254.216.213, 169.254.226.151, 169.254.243.235, 192.168.1.01, ::1, fe80::1d36:2a1:1009:ba9f%8, fe80::3771:cebf:b9b8:bfab%22, fe80::38a8:8571:2350:4160%15, fe80::9479:9073:1303:6f08%12, fe80::d9b2:fccb:bdc:d011%11, fe80::dd23:2447:54ef:973b%14, fe80::e8ba:3244:9cf0:32ec%10, fe80::eca8:c27b:1692:6f95%7

Listener
    Address = *
    Transport = HTTPS
    Port = 5986
    Hostname = <NewHost_HostName>
    Enabled = true
    URLPrefix = wsman
    CertificateThumbprint = 02CCB8C348080EC5C75AE2C0EB844D3EA12A2B16
    ListeningOn = 127.0.0.1, 169.254.57.70, 169.254.70.187, 169.254.112.251, 169.254.190.156, 169.254.216.213, 169.254.226.151, 169.254.243.235, 192.168.1.01, ::1, fe80::1d36:2a1:1009:ba9f%8, fe80::3771:cebf:b9b8:bfab%22, fe80::38a8:8571:2350:4160%15, fe80::9479:9073:1303:6f08%12, fe80::d9b2:fccb:bdc:d011%11, fe80::dd23:2447:54ef:973b%14, fe80::e8ba:3244:9cf0:32ec%10, fe80::eca8:c27b:1692:6f95%7```

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


## Install Chocolatey for bootstrapping

Ansible requires python to be installed on a remote host. Chocolatey is the easiest way to install python.

TBD - install chocolatey from an organization's internal repository
Current - install chocolatey from a USB stick [TBD]

## Install Python for Windows for bootstrapping

TBD - install python311 from an organization's internal repository
TBD - install python311 from a USB stick [TBD]
Current - install Python from the internet

`choco install python311`

## Add new host to the IAC configuration

At this point, the new host is ready to accept further configuration from the AnsibleController host. See [TBD] for the

