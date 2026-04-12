# Setup a new computer

## Introduction

Setting up a new computer can be a daunting task when there are hundreds of customizations needed to make the computer a productive element of an organization's infrastructure. Infrastructure As Code (IAC) is the discipline that is concerned with formalizing how to codify the customizations, and executing on the configuration to make a computer conform to the customizations desired.

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

Ansible (for Windows) uses WinRM to communicate from the AnsibleController host to the remote hosts. WinRM must be setup durring the bootstrap process.

#### Enable WinRM

Setup the initial WinRM configuration. Run the command `winrm qc`

#### Allow Powershell script execution

During the bootstrapping process, we will use the version of the Powershell executable that came with the Windows OS install. During the bootstrapping process, Powershell will be configured to allow running scripts that are unsigned. After the initial configuration, the Powershell ExecutionPolicy will be changed so that only signed scripts will be allowed.

Run the command `Set-ExecutionPolicy Bypass`

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

```

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

ansible-playbook -l $newhostname playbooks/WindowsHostsPlaybook.yml -i ./nonproduction_inventory.yml --tags "Preamble" -e 'user=whertzing password=obfuscated'
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

Note: as of 7/2/2023 StableDiffusion will only work with Python 3.10, nothing later (pytorch is required)

`winget install Python.Python.3.10 --scope machine`

`winget install --name 'python 3.10' --version '3.10.11' --accept-package-agreements --accept-source-agreements --silent --location 'C:\Program Files\PythonInterpreters' --source 'winget' --verbose --scope machine --force``

## Add new host to the IAC configuration

At this point, the new host is ready to accept further configuration from the AnsibleController host. See [TBD] for the

### Driver updates

Use the Windows GUI to install driver updates, update all that are out of date
Windows Update -> Advanced Options -> Optional Updates

### Install Dropbox, and sync

### Map User Directories to dropbox

### Install SQL Server XCommunity edition

#### Create PRODUCTION instance

### Developer tools

#### Add aaronontheweb/mssql-mcp SQL MCP Server

As a development tool, this will have to be installed on a new machine after dotnet has been installed. The MCP server configuration file(s) are found in the SharedVSCode repo

The repo does not publish a NuGet tool package — it's build-from-source only.

Note: an alternative is Microsoft's DAB-based SQL MCP Server, which is officially maintained, integrates directly into VS Code, and uses Windows Integrated Auth without needing to manage credentials. However, since the DAB is spun up for every MCP query, and can take 3-5 seconds, as well as adding a translation layer over the SQL tablesss, the `aaronontheweb/mssql-mcp` MCP server isa better fit

##### Detailed instructions

Clone the repo from github.
ToDo: replace the path locations below with data from the global settings
<cloudSharedBaseFolder> = `Join-Path 'C:' 'Dropbox'`
<username> = `$env:USERNAME`
<GithubOSSForksFolder> = `Join-Path 'Github' 'OSSForks'`
<CloneRoot> = `Join-Path 'aaronontheweb' 'mssql-mcp'`

```powershell
$targetBaseFolderPath = Join-Path 'C:' 'Dropbox' $env:USERNAME 'Github' 'OSSForks' 'aaronontheweb'
# Ensure the entire tree exists
New-Item -ItemType Directory -Path $targetBaseFolderPath -Force
cd $targetBaseFolderPath
git clone https://github.com/Aaronontheweb/mssql-mcp.git
cd mssql-mcp
dotnet build -c Release
# ToDo: confirm build succeeded
# ToDo: get instructions on how to do a virus scan from $global:settings, and scan the cloned folder tree
# configure the server. Use the mcp.json file in the .vscode folder in the SharedVSCode repo


```

#### Install ProGet

> **Prerequisite:** SQL Server must already be installed with a `PRODUCTION` named instance
> running and accessible at `localhost\PRODUCTION`. Verify with:
>
> ```powershell
> sqlcmd -S 'localhost\PRODUCTION' -E -Q 'SELECT @@SERVERNAME, @@VERSION'
> ```
>
> Expected: returns `<hostname>\PRODUCTION` and the SQL Server version string.

##### Step 1 — Download and run Inedo Hub

1. Open a browser and navigate to **[https://inedo.com/hub](https://inedo.com/hub)**
2. Click **Download Inedo Hub** (~1 MB bootstrapper)
3. Run `InedoHub.exe` — it self-updates and opens the Inedo Hub UI
4. Sign in or continue (Free tier — request a free license key if prompted and enter it)

##### Step 2 — Install ProGet via Inedo Hub

1. In the Inedo Hub, find **ProGet** → **Install**
2. On the **Database** screen → click **Advanced**
3. Select **Legacy: Specify SQL Server Connection String**
4. Enter: `Data Source=localhost\PRODUCTION; Integrated Security=True;`
5. Press **OK** → **Install**

The installer will:

- Create the `ProGet` database on `localhost\PRODUCTION`
- Run database schema migrations
- Install the `INEDOPROGETSVC` Windows service
- Start the service

Installation typically takes 2–5 minutes.

##### Step 3 — Set up ProGet.config

The `ProGet.config` file is stored under Git version control in the `ATAP.IAC` repository
and symlinked to the ProGet shared config location. Create the symlink:

```powershell
cd C:\ProgramData\Inedo\SharedConfig
New-Item -ItemType SymbolicLink -Path './ProGet.config' `
    -Target 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Windows\AnsibleHostInventory\utat022\ProGet.config'
```

The `ProGet.config` in the IAC repo uses Integrated Security (no username/password in the
connection string) and a Bitwarden-sourced encryption key placeholder:

```xml
<?xml version="1.0" encoding="utf-8"?>
<InedoAppConfig>
  <ConnectionString>Data Source=UTAT022\PRODUCTION;Initial Catalog=ProGet;
        Integrated Security=True;TrustServerCertificate=True;Encrypt=Optional</ConnectionString>
  <EncryptionKey>__SET_FROM_BITWARDEN_AT_STARTUP__</EncryptionKey>
  <WebServer Enabled="true" Urls="http://*:50000/"
    UseHttpsRedirection="False" IntegratedAuthenticationEnabled="False" />
</InedoAppConfig>
```

> If the Inedo Hub installer wrote a `ProGet.config` with a username/password connection
> string (e.g. `User Id=ProGetUser;Password=...`), remove those credentials now and replace
> the `ConnectionString` value with the Integrated Security form shown above. See
> **Step 5** below for the remove-credentials procedure.

##### Step 4 — Bootstrap the SQL service login (one-time)

Run this once after ProGet is installed and the service account `NT SERVICE\INEDOPROGETSVC`
exists. Call it from the `ATAP.Utilities.BuildTooling.PowerShell` module:

```powershell
Initialize-ProGetSqlServiceLogin -Encrypt Optional -TrustServerCertificate
```

Expected output (timestamps will differ):

```text
[21:32:40][Initialize-ProGetSqlServiceLogin] Applying SQL principal grants on localhost\PRODUCTION for database ProGet and account NT SERVICE\INEDOPROGETSVC
[21:32:40][Initialize-ProGetSqlServiceLogin] SQL principal grants applied successfully

SqlInstance          DatabaseName ServiceAccount            Status
-----------          ------------ --------------            ------
localhost\PRODUCTION ProGet       NT SERVICE\INEDOPROGETSVC Success
```

This creates the Windows login (if needed), creates the database user in `[ProGet]`, and
grants `db_owner` to `NT SERVICE\INEDOPROGETSVC`.

##### Step 5 — Remove username/password from ProGet.config connection string

If the Inedo Hub installer added SQL authentication credentials to `ProGet.config`
(e.g., `User Id=ProGetUser;Password=...`), they must be removed now that Integrated
Security and the service-account `db_owner` grant are in place.

Open `C:\ProgramData\Inedo\SharedConfig\ProGet.config` (which is the symlink created in
Step 3, so editing it edits the IAC repo file directly) and ensure the `ConnectionString`
contains **only** Integrated Security attributes — no `User Id`, `Password`, or `UID`/`PWD`
keys:

```xml
<ConnectionString>Data Source=UTAT022\PRODUCTION;Initial Catalog=ProGet;
    Integrated Security=True;TrustServerCertificate=True;Encrypt=Optional</ConnectionString>
```

After saving, restart the ProGet service to pick up the change:

```powershell
Restart-Service INEDOPROGETSVC
```

Verify the service came back up:

```powershell
Get-Service INEDOPROGETSVC | Select-Object Name, Status
```

Expected: `Status = Running`

##### Step 6 — Populate the encryption key from Bitwarden

The `EncryptionKey` placeholder in `ProGet.config` must be replaced at machine startup by
`LoginScript.ps1`, which reads the key from Bitwarden and writes it to the file under
controlled ACLs.

TBD: document the exact `LoginScript.ps1` entry and file-ACL hardening steps.

##### Step 7 — Verify the installation

1. Open a browser to **http://localhost:50000**
2. You should see the ProGet login page
3. Default admin credentials (first run): Username `Admin`, Password `Admin`
4. **Immediately change the admin password** via Admin → My Profile → Change Password

Verify the database was created:

```powershell
sqlcmd -S 'localhost\PRODUCTION' -E -Q "SELECT name FROM sys.databases WHERE name = 'ProGet'"
```

Expected output: `ProGet`

##### Step 8 — Create the Admin API key and register feeds

See `_Planning/Explainers/0002-ProGet-Setup.md` Steps 4–8 for:

- Creating the `PROGET_ADMIN_API_TOKEN` API key in the ProGet UI
- Registering NuGet feeds in `NuGet.config`
- Registering PowerShell feeds with `Register-PSResourceRepository`
- Setting up inter-tier connectors
