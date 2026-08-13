# Setup a new computer

> **Task 13.62 security cutover:** Legacy ProGet API-key environment setup and raw REST examples below are superseded. Pass only `ProGet.Admin.API.Key` or `ProGet.BuildMaster.API.Key` as a SecretName to the appropriate PowerShell boundary.

> **Status (2026-05-19):** This document is retained for its deeper
> BIOS / OS-install / Ansible-bootstrap notes that
> [NewComputerSetup.md](NewComputerSetup.md) deliberately omits. For any
> overlap (PowerShell profile install, SQL Server instance creation,
> ProGet/BuildMaster install, service accounts, NBGV, git
> `safe.directory`), prefer [NewComputerSetup.md](NewComputerSetup.md) —
> it is the maintained canonical source. In particular:
>
> - Git `safe.directory` bootstrap for `SvcBuildMaster` —
>   [NewComputerSetup.md § 9.4](NewComputerSetup.md).
> - Machine-wide NBGV install (so `SvcBuildMaster` can resolve `nbgv`) —
>   [NewComputerSetup.md § 4.4](NewComputerSetup.md).
> - PowerShell Gallery modules installed with `-Scope AllUsers` so
>   `SvcBuildMaster` can resolve `PSFramework` and `powershell-yaml` —
>   [NewComputerSetup.md § 4.3](NewComputerSetup.md).

## Parity journal requirement

Before a step in this runbook changes state on `utat022` or `utat01`, append a
secret-safe declaration with `Add-ParityChangeEntry` on the host being changed.
Include the category, item, old/new state, peer host, and a peer action; do not
include any secret value. After the peer applies its corresponding action,
acknowledge it from that peer with `Confirm-ParityChangeApplied`.

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

## Determine and record the computer name

In many custom Windows installation images, setup asks for the computer name during OOBE. If prompted, set it there and record it immediately.

Use this value consistently everywhere in this document where `<COMPUTERNAME>` appears.

To verify the current computer name after first login:

```powershell
$env:COMPUTERNAME
```

If this does not match the intended name, rename the computer before continuing with infrastructure configuration.

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

## Related Reference — WSL2 Setup

If this workstation will run Ansible, Docker, or related automation inside WSL2, use the
standalone reference [WSL2Setup.md](./WSL2Setup.md) for the Ubuntu 24.04 install pattern,
drive automount guidance, WSL2 networking notes, PowerShell-to-WSL trigger examples, and
Docker interoperability notes.
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

### Install SQL Server Community Edition

> **CRITICAL PREREQUISITE:** SQL Server Community Edition (latest version) **must** be installed and configured before installing ProGet or BuildMaster. Both Inedo products depend on SQL Server for their databases.

#### Pre-Installation: Create SvcSQLServer Service Account

Before installing SQL Server, create a dedicated Windows service account for running the SQL Server Engine service. This provides better auditability and password management.

> **Prerequisites:**
>
> 1. Ensure a Bitwarden secret named `SvcSQLServer.<lowercase-hostname>` exists in Bitwarden Secrets Manager with:
>    (Corrected 2026-08-12: the name has no `.Login.` middle field. None of the 66 live keys
>    contains `.Login.`, so `SvcSQLServer.Login.<lowercase-hostname>` does not resolve. The
>    existing keys are `SvcSQLServer.utat01` and `SvcSQLServer.utat022`.)
>    - Username: `SvcSQLServer`
>    - Password: the service account password
> 2. Ensure `ATAP.Utilities.PowerShell` module is loaded, which provides `New-LocalServiceAccount`:
>
> ```powershell
> Import-Module ATAP.Utilities.PowerShell
> ```
>
> If the module is not yet available, you can create this account manually via `lusrmgr.msc` and then grant `SeServiceLogonRight` with `ntrights.exe` or Active Directory Group Policy.

Create the SvcSQLServer account:

```powershell
New-LocalServiceAccount `
    -AccountName              SvcSQLServer `
    -FullName                 'SQL Server Service Identity' `
    -Description              'Dedicated Windows service account for SQL Server Database Engine' `
    -SecretNameServiceAccountLoginCredentials "SvcSQLServer.$($env:COMPUTERNAME.ToLowerInvariant())" `
    -GrantSeServiceLogonRight
```

Expected result: `Status = Success`, `UserCreated = True`, `SeServiceLogonRight = True`.

**Bitwarden record requirement:** Ensure `SvcSQLServer.<lowercase-hostname>` remains available in Bitwarden Secrets Manager for SQL Server service maintenance.

---

#### Step 1 — Download and Install SQL Server Community Edition

1. Navigate to [SQL Server Community Edition Downloads](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) in a web browser
2. Select **Express** edition (note: Community Edition is now called SQL Server Express Community Edition)
3. Run the installer (`SQLEXPR_*.exe`)
4. Choose **Custom** installation type
5. During feature selection, ensure the following are checked:
   - **Database Engine Services** ✓ (required)
   - **SQL Server Agent** ✓ (required for backup jobs and scheduled maintenance)
   - SQL Server Replication (recommended)
   - Machine Learning Services and Language Extensions (optional, for advanced scenarios)
6. When prompted for **Service Accounts** configuration:
   - For **SQL Server Database Engine**, select **Use the following user account** (instead of the default virtual account)
   - Enter the account name: `<COMPUTERNAME>\SvcSQLServer` (replace `<COMPUTERNAME>` with your actual machine name, or use `.\SvcSQLServer` for local account)
   - Enter the password you created in the pre-installation step
   - For **SQL Server Agent**, also specify `<COMPUTERNAME>\SvcSQLServer` with the same password
7. Accept the default paths or customize as needed
8. Complete the installation
9. **Verify and Configure SQL Server Agent:**
   - After installation completes, open **SQL Server Configuration Manager**
   - Navigate to **SQL Server Services**
   - Verify **SQL Server (PRODUCTION)** shows **Log On As: COMPUTERNAME\SvcSQLServer**
   - Verify **SQL Server Agent (PRODUCTION)** shows **Log On As: COMPUTERNAME\SvcSQLServer**
   - Ensure both services have **Startup Type** set to **Automatic**
   - Start both services if they are not already running:
     ```powershell
     Start-Service -Name 'MSSQL$PRODUCTION'
     Start-Service -Name 'SQLAGENT$PRODUCTION'
     Get-Service -Name 'MSSQL$PRODUCTION', 'SQLAGENT$PRODUCTION' | Select-Object Name, Status
     # Expected output: Both services show Status = Running
     ```
   - SQL Server Engine and Agent are now running under the SvcSQLServer dedicated account

#### Step 2 — Create and Configure the PRODUCTION Named Instance

> **Why a named instance?** Using a named instance (e.g., `localhost\PRODUCTION`) separates this instance from any default SQL Server instance, improves security, and allows multiple instances to coexist on the same machine.

During SQL Server installation, when prompted for **Instance Configuration**:

1. Select **Named Instance** (not Default Instance)
2. Enter instance name: `PRODUCTION`
3. Instance ID will auto-populate as `PRODUCTION`
4. Choose appropriate installation path (default is fine)

#### Step 3 — Configure SQL Server to Listen on TCP

SQL Server must be configured to accept TCP/IP connections. Use **SQL Server Configuration Manager**:

```powershell
# Open SQL Server Configuration Manager
# (Search for "SQL Server Configuration Manager" in Windows Start menu)
# OR run via PowerShell:
Start-Process 'C:\Program Files\Microsoft SQL Server\170\Tools\Binn\SQLMANAGER.MSC' -Wait
```

In SQL Server Configuration Manager:

1. Navigate to **SQL Server Network Configuration** → **Protocols for PRODUCTION**
2. Right-click **TCP/IP** → **Enable**
3. Right-click **TCP/IP** → **Properties**
4. On the **Protocol** tab, ensure **Enabled** is set to `Yes`
5. On the **IP Addresses** tab:
   - Scroll to **IPAll** section at the bottom
   - Verify **TCP Port** is set to a non-default port (e.g., `1433` for default, or `50001` for custom)
   - **Important:** Do NOT use the default port `1433` if other SQL Server instances may exist; use a port like `50001`–`59999`
6. Click **OK** to save
7. Restart the **SQL Server (PRODUCTION)** service:
   ```powershell
   Restart-Service -Name 'MSSQL$PRODUCTION' -Force
   ```

#### Step 4 — Configure SQL Server Memory Limits

For **development or "all-in-one" hosts**, SQL Server memory should be limited to a safe percentage of total system RAM:

```powershell
# Example: on a system with 32 GB RAM, set max to ~3.2 GB (10%)
# Connect to SQL Server and run:

$sqlInstance = 'localhost\PRODUCTION'
$maxMemoryMB = [int]([System.Environment]::ProcessorCount * 256 * 0.10)  # 10% of total available

$query = @"
EXEC sp_configure 'max server memory (MB)', $maxMemoryMB;
RECONFIGURE;
"@

Invoke-Sqlcmd -ServerInstance $sqlInstance -Query $query -Encrypt Optional
```

> **Rationale:** Allowing SQL Server to consume all available RAM can starve the OS and other applications, especially on shared dev machines. 10% is a conservative limit suitable for development and all-in-one deployments.

#### Step 5 — Verify SQL Server PRODUCTION Instance is Running

```powershell
# Verify the service is running
Get-Service -Name 'MSSQL$PRODUCTION' | Select-Object Name, Status

# Expected output: Status = Running

# Verify TCP connectivity
sqlcmd -S 'localhost\PRODUCTION' -E -Q 'SELECT @@SERVERNAME, @@VERSION'

# Expected output: Shows <COMPUTERNAME>\PRODUCTION and SQL Server version
```

#### Step 6 — Create Service User Accounts (Before Installing ProGet/BuildMaster)

Creating dedicated Windows service accounts provides better auditability and password management than default virtual service accounts.

> **Prerequisite:** Ensure `ATAP.Utilities.PowerShell` module is loaded, which provides `New-LocalServiceAccount`:
>
> ```powershell
> Import-Module ATAP.Utilities.PowerShell
> ```
>
> If the module is not yet available, you can create these accounts manually via `lusrmgr.msc` and then grant `SeServiceLogonRight` with `ntrights.exe` or Active Directory Group Policy.

##### Create SvcProGet Account

Create this account **before** installing ProGet:

```powershell
New-LocalServiceAccount `
    -AccountName              SvcProGet `
    -FullName                 'ProGet Service Identity' `
    -Description              'Dedicated Windows service account for Inedo ProGet' `
    -SecretNameServiceAccountLoginCredentials "SvcProGet.$($env:COMPUTERNAME.ToLowerInvariant())" `
    -GrantSeServiceLogonRight
```

Expected result: `Status = Success`, `UserCreated = True`, `SeServiceLogonRight = True`.

**Store the password in Bitwarden:** Use `Get-SecretATAP` in your `LoginScript.ps1` to retrieve this at system startup, or record it in Bitwarden for safekeeping.

##### Create SvcBuildMaster Account

Create this account **before** installing BuildMaster:

```powershell
New-LocalServiceAccount `
    -AccountName              SvcBuildMaster `
    -FullName                 'BuildMaster Service Identity' `
    -Description              'Dedicated Windows service account for Inedo BuildMaster' `
    -SecretNameServiceAccountLoginCredentials "SvcBuildMaster.$($env:COMPUTERNAME.ToLowerInvariant())" `
    -GrantSeServiceLogonRight
```

Expected result: `Status = Success`, `UserCreated = True`, `SeServiceLogonRight = True`.

---

## Create Additional SQL Server Named Instances

After SQL Server is installed and the `PRODUCTION` instance is verified running, create the
`Integration` and `QA` named instances. These are required for the sprint-based development
workflow and must exist before ProGet or BuildMaster attempt to use them.

Load the current host's authoritative instance rows before provisioning:

```powershell
$hostName = $env:COMPUTERNAME.ToLowerInvariant()
$topology = $global:settings[$global:configRootKeys['SqlInstanceTopologyConfigRootKey']]
$hosts = $topology[$global:configRootKeys['SqlInstanceTopologyHostsConfigRootKey']]
$instances = $hosts[$hostName][$global:configRootKeys['SqlInstanceTopologyInstancesConfigRootKey']]
$instanceNameKey = $global:configRootKeys['SqlInstanceTopologyInstanceNameConfigRootKey']
$tcpPortKey = $global:configRootKeys['SqlInstanceTopologyTcpPortConfigRootKey']
```

Each row supplies `DataPath`, `LogPath`, and `BackupPath` under
`C:\LocalDBs\<INSTANCE_NAME>\`. `Install-SqlServerInstance` passes those settings
to dbatools; Ansible or setup scripts must not maintain separate path literals.

> **Why separate instances?** Each instance (`Integration`, `QA`, `PRODUCTION`) maps to a
> promotion tier in the BuildMaster pipeline. Flyway migrations and package deployments
> target the appropriate instance at each stage. Running them on separate named instances
> prevents a broken migration on one tier from affecting others.

### Create the Integration Instance

```powershell
Install-SqlServerInstance `
    -DatabaseHost        'localhost' `
    -SqlInstance         $instances['INTEGRATION'][$instanceNameKey] `
    -Port                $instances['INTEGRATION'][$tcpPortKey] `
    -Version             '2022' `
    -AuthenticationMode  Windows `
    -SqlServerSetupPath  'D:\Temp\SQLExpr\extracted'
```

After creation, configure TCP and set memory limits as for PRODUCTION (Steps 3–4 above),
using the port reserved for Integration in `HostSettings.ps1`
(`SqlServerIntegrationPortConfigRootKey`).

### Create the QA Instance

```powershell
Install-SqlServerInstance `
    -DatabaseHost        'localhost' `
    -SqlInstance         $instances['QA'][$instanceNameKey] `
    -Port                $instances['QA'][$tcpPortKey] `
    -Version             '2022' `
    -AuthenticationMode  Windows `
    -SqlServerSetupPath  'D:\Temp\SQLExpr\extracted'
```

After creation, configure TCP and set memory limits, using the port reserved for QA
(`SqlServerQaPortConfigRootKey`).

### Verify All Three Instances

```powershell
@('PRODUCTION', 'Integration', 'QA') | ForEach-Object {
    sqlcmd -S "localhost\$_" -E -Q 'SELECT @@SERVERNAME' -l 5
}
```

Expected: each command returns `<COMPUTERNAME>\<InstanceName>` with no errors.

> **Sprint start reminder:** At the beginning of each sprint, run `Install-SqlServerInstance`
> for any sprint-specific instances (e.g., `Integration`, `QA`) that do not yet exist on
> the target machine. The `PRODUCTION` instance is permanent and only created once.

### Build ATAPUtilities Database on All Instances

After all three instances exist and are accessible, build the `ATAPUtilities` database on
each one in sequence using the convenience script:

```powershell
# From the ATAP.Utilities repository root:
.\Database\Powershell\public\Rebuild-All-AllInstances.ps1
```

This script builds `ATAPUtilities` on `QA` (Testing environment), `Integration`
(Development environment), and `Production` (Production environment) in order,
applying all Flyway migrations with `-Force` (drop + recreate). It continues to the
next instance if one fails, then throws at the end if any failed.

See `Database\Powershell\public\Rebuild-All-AllInstances.ps1` for the full script.

---

## Install ProGet and BuildMaster (After SQL Server Setup)

> **Prerequisites completed:**
>
> - ✅ SQL Server Community Edition installed with PRODUCTION named instance
>   ✅ TCP enabled on the PRODUCTION instance
>   ✅ Memory limits configured (10% of total RAM for dev hosts)
>   ✅ Service accounts SvcProGet and SvcBuildMaster created
>
> Now proceed with ProGet and BuildMaster installation.

#### Create PRODUCTION instance

##### Step 7 — Verify Service Account Permissions on Databases (After ProGet and BuildMaster Install)

After both ProGet and BuildMaster are installed, you must grant the service accounts `db_owner` rights on their respective databases.

##### Grant SvcProGet db_owner on ProGet Database

After ProGet is installed (see below), run:

```powershell
Initialize-SqlServiceLogin `
    -SqlInstance              'localhost\PRODUCTION' `
    -DatabaseName             'ProGet' `
    -ServiceAccount           "$env:COMPUTERNAME\SvcProGet" `
    -Encrypt                  Optional `
    -TrustServerCertificate
```

Then reconfigure the ProGet Windows service to log on as `SvcProGet`:

```powershell
sc.exe config INEDOPROGETSVC obj= "$env:COMPUTERNAME\SvcProGet" password= '<password>'
```

##### Grant SvcBuildMaster db_owner on BuildMaster Database

After BuildMaster is installed (see below), run:

```powershell
Initialize-SqlServiceLogin `
    -SqlInstance              'localhost\PRODUCTION' `
    -DatabaseName             'BuildMaster' `
    -ServiceAccount           "$env:COMPUTERNAME\SvcBuildMaster" `
    -Encrypt                  Optional `
    -TrustServerCertificate
```

Then reconfigure the BuildMaster Windows service to log on as `SvcBuildMaster`:

```powershell
sc.exe config INEDOBUILDMASTERSVC obj= "$env:COMPUTERNAME\SvcBuildMaster" password= '<password>'
```

---

## Developer tools

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
> Expected: returns `<COMPUTERNAME>\PRODUCTION` and the SQL Server version string.

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

Run this once after ProGet is installed. Use one of these two approaches:

**Option A — default virtual service account** (`NT SERVICE\INEDOPROGETSVC`, from
`ATAP.Utilities.BuildTooling.PowerShell`):

```powershell
Initialize-ProGetSqlServiceLogin -Encrypt Optional -TrustServerCertificate
```

**Option B — dedicated local account** (`SvcProGet`, created in the pre-install section above):

```powershell
Initialize-SqlServiceLogin `
    -SqlInstance    'localhost\PRODUCTION' `
    -DatabaseName   'ProGet' `
    -ServiceAccount "$env:COMPUTERNAME\SvcProGet" `
    -Encrypt        Optional `
    -TrustServerCertificate
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

- Securely registering the value associated with `ProGet.Admin.API.Key` in the ProGet UI
- Registering NuGet feeds in `NuGet.config`
- Registering PowerShell feeds with `Register-PSResourceRepository`
- Setting up inter-tier connectors

---

##### Step 9 — Set `Web.BaseUrl` to include the custom port (CRITICAL)

<!-- Philote: 7a5d02d4-895c-41ba-9b57-9862328281d7 -->

**Symptom:** `Register-PSRepository` or `Register-PSResourceRepository` fails with:

```
... is an invalid Web Uri
```

**Root cause:** When ProGet is listening on a non-default port, it constructs all absolute
links using its `Web.BaseUrl` setting (Administration → Advanced Settings). If `Web.BaseUrl`
is left at the factory default (e.g. `http://localhost/` with no port), ProGet returns a
**302 redirect** that points to the wrong port. `Register-PSRepository` follows the redirect
and then fails because the resulting URL is unreachable.

This is a **guaranteed blocker** on every new machine: the feed registers successfully in
the ProGet UI, but every PowerShell `Register-*` call fails silently with this error.

**Fix — set `Web.BaseUrl` in the ProGet Administration panel:**

1. Log in to ProGet → **Administration** → **Advanced Settings**
2. Search for `Web.BaseUrl`
3. Set the value to `http://<hostname>:<port>` — scheme + hostname + port only, no trailing
   path. Example: `http://utat022:50000`
4. Click **Save**

The port to use is stored in the global settings:

```powershell
$port    = $global:settings[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']]
$baseUrl = $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]
# $baseUrl is a [UriBuilder] built from scheme + hostname + $port in HostSettings.ps1
```

**Diagnostic — verify before registering feeds:**

```powershell
$baseUrl = $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]
$probe   = Invoke-WebRequest "$baseUrl/nuget/<feed-name>/" -UseBasicParsing -ErrorAction SilentlyContinue
$probe.StatusCode
# 200  → ProGet is reachable; proceed to register feeds
# 302  → Web.BaseUrl is wrong (missing port or wrong hostname) — fix it first
# 401/403 → URL is reachable but credentials are needed — check API key / anonymous access
```

**Post-fix feed registration (PSResourceGet v3):**

```powershell
Register-PSResourceRepository `
    -Name    'IntPrePSRProdPullFeed' `
    -Uri     "$baseUrl/nuget/IntPrePSRProdPullFeed/" `
    -Trusted
```

**Legacy PowerShellGet (v2):**

```powershell
Register-PSRepository `
    -Name              'IntPrePSRProdPullFeed' `
    -SourceLocation    "$baseUrl/nuget/IntPrePSRProdPullFeed/" `
    -PublishLocation   "$baseUrl/nuget/IntPrePSRProdPullFeed/" `
    -InstallationPolicy Trusted
```

> **Note:** HostSettings.ps1 in the `ATAP.IAC` repository builds `$baseUrl` via
> `[UriBuilder]::new(scheme, hostname, port)` and stores it under `ProGetBaseUrlConfigRootKey`.
> Always use that value — never hard-code the port.

---

##### Step 10 — ProGet.Service.exe CLI verbs reference

<!-- Philote: 50c1d535-5b55-4388-af2c-4d473627bfdb -->

`ProGet.Service.exe` (found in the ProGet install directory, typically
`C:\Program Files\ProGet\`) accepts the following verbs. Use `run` during troubleshooting
to see live log output; use `install` / `installweb` for production.

| Verb                         | What it does                                                                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `run`                        | Launches ProGet in the current console window — streams all log output to stdout. Use for debugging a service that refuses to start under Windows SCM. |
| `install`                    | Registers the **background-tasks** Windows service (`INEDOPROGETSVC`). Accepts `--user`/`--password` for a dedicated service account.                  |
| `installweb`                 | Registers the **self-hosted web server** Windows service (`INEDOPROGETWEBSRV`). Accepts `--url` for the HTTP.SYS reservation.                          |
| `uninstall` / `uninstallweb` | Removes the respective Windows service(s).                                                                                                             |
| `resetadminpassword`         | Resets the built-in directory and sets `Admin` / `Admin` credentials. Run locally or in a container only.                                              |

**Common `run` recipes:**

```powershell
# Background tasks only (no HTTP listener) — good for quick config verification:
.\ProGet.Service.exe run --mode=serviceonly

# Full stack on a temp port — live log + web UI:
.\ProGet.Service.exe run --mode=both --urls=http://*:8080/
```

**Production install with dedicated service account:**

```powershell
# Create Windows service (background tasks):
.\ProGet.Service.exe install --user "$env:COMPUTERNAME\SvcProGet" --password '<password>'

# Register self-hosted web server on the configured port:
$port = $global:settings[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']]
.\ProGet.Service.exe installweb --url="http://+:$port/"
```

**Why use `run` before `install`?**
If `Start-Service INEDOPROGETSVC` fails silently, run the exe interactively — the full
.NET exception stack trace is printed to the console, which is far more useful than the
generic "service did not respond in a timely fashion" Windows error.

**Logging:**

- **Console** — `run` streams everything at Info level or above to stdout.
- **Windows Event Log** — always active for the installed service; see
  **Windows Logs → Application**, source `InedoProGet`.
- **Rolling log files** — configure via `ProGet.config`:
  ```xml
  <Logging Level="Debug" Path="D:\ProGetLogs" RetentionDays="14" />
  ```
- Fine-grained knobs (e.g. `Diagnostics.FeedErrorLogging`) are in
  **Administration → Advanced Settings**.

---

## Troubleshooting — ProGet Feed Management

### Delete an orphaned feed via the Management API

<!-- Philote: 90ab74a9-31fe-488a-b56a-828f5b305071 -->

The ProGet web UI occasionally leaves orphaned feeds after a migration, bulk rename, or
partial install. The only reliable way to remove them is the Management REST API.

> ⚠️ **This operation is irreversible.** The call permanently deletes the feed record and
> every package stored inside it. Deactivate the feed first (Administration → Feeds →
> Deactivate) and verify the contents via `GET /api/management/feeds/list` before
> proceeding. Recovery requires restoring from a SQL Server backup.

#### Prerequisites

| Requirement     | Detail                                                                                               |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| SecretName      | `ProGet.Admin.API.Key`, with **Use/Manage Feeds** permission                                         |
| Boundary        | `List-ProGetFeeds` / `Remove-ProGetFeeds`; never call the authenticated REST endpoint directly       |
| ProGet base URL | `$global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']]`                             |

#### Step 1 — List feeds to confirm the exact name

```powershell
List-ProGetFeeds -ProGetApiKeySecretName 'ProGet.Admin.API.Key'
```

Returns a JSON array of feed objects. Locate the exact `name` value before deleting.

#### Step 2 — Delete the feed

```powershell
$feedName = 'IntPreNugetDevPushFeed'   # replace with the name confirmed in Step 1
Remove-ProGetFeeds `
  -Name $feedName `
  -ProGetApiKeySecretName 'ProGet.Admin.API.Key'
```

HTTP 200 with no body = success. Common errors:

| Status | Meaning                                                      |
| ------ | ------------------------------------------------------------ |
| 403    | API key missing, wrong, or lacks Use/Manage Feeds permission |
| 404    | Feed name not found — verify with `feeds/list` first         |

#### Direct CLI calls are not an approved alternative

Do not call `pgutil` directly for authenticated administration because its
command-line contract requires a raw credential handoff. Use
`Remove-ProGetFeeds -ProGetApiKeySecretName 'ProGet.Admin.API.Key'`; it resolves
the secret only inside the authenticated leaf.

#### After deletion

- The feed disappears from the ProGet UI immediately.
- Any `NuGet.config` entries or `Register-PSResourceRepository` registrations pointing at
  the deleted feed will return 404. Remove those references:
  ```powershell
  Unregister-PSResourceRepository -Name $feedName -ErrorAction SilentlyContinue
  ```
- If the deletion was accidental, restore from the most recent SQL Server backup of the
  `ProGet` database on `localhost\PRODUCTION`.
