# Starting an organization infrastructure

Initial draft 2024-09-17,original author W.Hertzing

## Architecture for the initialization of a new computer in the organization's infrastructure

TBD: details here. We start build ing a new computer using an existing Ansible controller. eventually, we get to the point of using Ansible to create an Ansible controller running in ubuntu in a WSL2 container on a WindowsHost computer.

TBD: Explain how the organization's IAC (the data) and the ATAP.IAC.Ansible Powershell module (the algorithms) interact to create the -generated Ansible image

## Creating the Ansible directory structure in ubuntu on WSL

```Powershell
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.IAC.Ansible\public\Create-AnsibleDirectoryStructure.ps1'
```

## Testing communications from Ansible



## Boot Setup Image

### Windows Source ISO

### ISO modifications

#### Debloat the source image

Remove everything not absolutly necessary

#### Add custom autoUnattend.xml

Details on the autoUnattend creation

#### using NTLite to make ISO modifications

### Create the bootable USB stick

using Rufus

## WindowsHost is the base group

### The Preamble establishes the baseline capabilities

#### Validation of boot setup image

The ansibleAdminFirstLogon.ps1 script leaves a log file in C:\Windows\Temp\ansibleAdminFirstLogon.log
The ansibleAdminFirstLogon.ps1 script creates a directory at C:\Temp\Ansible

#### Latest Windows and drivers updates

#### Reinstall package management

#### Install dotnet runtime

#### Reinstall Powershell core

#### Install PKI certificates

##### Install Root CA certificate

##### Install Server Authentication (SSL) certificate

#### Reconfigure of WinRM listener

#### Validate WinRM configuration

#### Switch to using HTTPS and Authenticated Server SSL

#### Install ATAP.Utilities.Powershell and its dependent packages

#### Install Powershell AllUsersAllHosts profile

global_ConfigRootKeys.ps1
HostSettings.ps1
global_EnvironmentVariables.ps1
AllUsersAllHostsV7CoreProfile.ps1

#### Install Powershell CurrentUsersAllHosts profile

### Validate WindowsHost Preamble

The chocolatey cache is placed at C:\Temp\ChocolateyCache
PKI certificates for RootCA and Server Authentication (SSL) are installed into Cert:\LocalMachine\Root and cert:\LocalMachine\My
The Powershell package ATAP.Utilities.Powershell and its requiredModules are installed into the new computer's Powershell Desktop (V5) $PSHOME/Modules
The Powershell package ATAP.Utilities.Powershell and its requiredModules are installed into the new computer's Powershell Core (V7) $PSHOME/Modules
The Everything application has been isntalled globally, the shortcut is on everyone's desktop, and it is running as a service
The files
  global_ConfigRootKeys.ps1
  HostSettings.ps1
  global_EnvironmentVariables.ps1
  AllUsersAllHostsV7CoreProfile.ps1
 are found in the $PSHome/Modules/ATAP.Utilities.Powershell/latest/Resources subdirecotry.
These same files are linked into the $PSHome/7 subdirectory
The Directory C:/Users/ansibleAdmin/AppData/Roaming/Powershell/PSFramework exists.
There is at least one file (ending in .log) in the directory C:/Users/ansibleAdmin/AppData/Roaming/Powershell/PSFramework



Powershell scripts should have let the following log messages in 'C:\Users\ansibleAdmin\AppData\Roaming'
The



Update 10-27-2024
Using the ansible playbook for utat022, to build the whole machine from scratch:
under ansibleAdmin:

1) chocolatey package ngrok halts installation; windows defender claims there is a malware payload in the package

2) Chocolatey package xxx reports an error

3) Powershell modules that fail to install:

assert
chocolateyget
computermanagementdsc
microsoft.powershell.secretmanagement
microsoft.powershell.secretstore
nuget
platyps
powershell-yaml
psdepend
psdscresources
psscriptanalyzersqlserver
secretmanagement.hashicorp.vault.kv
secretmanagement.keepass
sqlserver
threadjob

Ditto - needs 'start on system startup' in global registryu setting

per-user:
profile links
Ditto - needs friends setup to copy clips between computers / per user
chrome extensions / settings:
  Add VoiceIn Chrome extension; login as Google account bill.hertzing; allow microphone access while using the extension; pin extension to Chrome's address bar
Turn on "Show recommended files in Start, recent files in FileExlorer, and item in Jump Lists", under Personalization->Start
Setup VSCode per-User Settings to the SharedxCode

per-serviceuser
profile links

VSC is not spell checking code files .ps1, .psm1, .psd1
turn on Chrome memory Saver feature (TBD global or per-user)
Download OpenAI ChatGPT application for Windows (beta as of 10/27/2024, cannot install, maybe related to Microsoft Appstore)
Add VoiceIn Chrome extension; login as Google account bill.hertzing; allow microphone access while using the extension;; pin extension to Chrome's address bar
SQL Server executable configuration
SQL Server Management Server executable configuration
Setup SQL Server,



