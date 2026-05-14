# Setup a New Development Computer

## Purpose

This document bootstraps a new Windows 11 developer workstation so it can participate in
ATAP development, sprint worktrees, local SQL Server work, ProGet package hosting,
BuildMaster promotion workflows, and offline development.

The end state is:

1. The machine has the expected stable and sprint worktrees under `C:\Dropbox\whertzing\GitHub`.
2. PowerShell 7 profiles and login automation are installed from `ATAP.Utilities.PowerShell`.
3. Third-party software is installed and configured:
   - SQL Server with the base instances `Production`, `QA`, and `Integration`
   - ProGet using the `Production` SQL instance
   - BuildMaster using the `Production` SQL instance
4. The local service accounts and Bitwarden secrets required by SQL Server, ProGet, and
   BuildMaster exist and are wired up.
5. Backup jobs exist for the ProGet and BuildMaster databases.
6. Stable-branch builds and tests complete successfully.

## Important Conventions

- Use PowerShell 7 (`pwsh`) for all commands in this document.
- The historical phrase `SQL Server Community Edition` appears in older notes, but for a
  developer workstation that needs SQL Server Agent you should install SQL Server 2022
  Developer media. SQL Server Express does not include SQL Server Agent.
- Keep SQL Server instance names under 16 characters. The base instances are
  `Production`, `QA`, and `Integration`. Sprint and feature-branch instances use a short
  tier prefix such as `Dev` or `Exp` plus a shortened branch or user token.
- Prefer the newest `Overview.code-workspace` and `OverviewSprintNNNN.code-workspace`
  files at `C:\Dropbox\whertzing\GitHub` as the current branch/worktree matrix when
  they are present.

## Phase 1: Windows and Developer Baseline

## Step 1: Install Windows and Record Machine Identity

1. Install Windows 11.
2. Assign and record the final computer name.
3. Set the timezone.
4. Join the network as a private network and enable discovery and file sharing.

Verify the final machine name:

```powershell
$env:COMPUTERNAME
```

## Step 2: Install Core Tools

Install and verify these tools before continuing:

1. PowerShell 7
2. Git
3. Visual Studio Code
4. Dropbox
5. Bitwarden desktop and `bw`
6. .NET SDKs required by the repos
7. Python if the workstation will run Manim or Copilot code execution

Useful checks:

```powershell
pwsh --version
git --version
code --version
dotnet --list-sdks
bw --version
```

## Step 3: Sync the Repository Tree

Wait for Dropbox to report `Up to date`, then verify the stable repos exist:

```powershell
$gitHubRoot = 'C:\Dropbox\whertzing\GitHub'
$stableRepos = @('_Planning', 'Ace', 'AceCommander', 'ATAP.Utilities', 'ATAP.IAC', 'SharedVSCode')

foreach ($repo in $stableRepos) {
  $path = Join-Path $gitHubRoot $repo
  if (-not (Test-Path $path)) {
    throw "Missing repository: $path"
  }
}

'Stable repositories are present.'
```

If the current sprint already exists, verify the sprint worktrees are present as well:

```powershell
Get-ChildItem $gitHubRoot -Directory -Filter '*-wt-*-Sprint-*-work-items' |
  Select-Object FullName
```

## Step 4: Install PowerShell Profiles and the Login Script

The machine-level and user-level PowerShell 7 profiles come from
`ATAP.Utilities.PowerShell`. Install them either by copying the files or, during active
development, by linking them back to the source worktree.

### 4.1 Link the machine-wide PowerShell 7 profile

```powershell
$gitHubRoot = 'C:\Dropbox\whertzing\GitHub'
$atapRoot = Join-Path $gitHubRoot 'ATAP.Utilities'
$profileSource = Join-Path $atapRoot 'src\ATAP.Utilities.PowerShell\Profiles'

New-Item -ItemType Directory -Path (Join-Path $env:ProgramFiles 'PowerShell\7') -Force | Out-Null
Remove-Item (Join-Path $env:ProgramFiles 'PowerShell\7\profile.ps1') -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink `
  -Path (Join-Path $env:ProgramFiles 'PowerShell\7\profile.ps1') `
  -Target (Join-Path $profileSource 'AllUsersAllHostsV7CoreProfile.ps1') | Out-Null
```

### 4.2 Link the current-user all-hosts and current-host profiles

```powershell
$documentsPowerShell = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
New-Item -ItemType Directory -Path $documentsPowerShell -Force | Out-Null

Remove-Item (Join-Path $documentsPowerShell 'Profile.ps1') -ErrorAction SilentlyContinue
Copy-Item (Join-Path $profileSource 'CurrentUserAllHostsV7CoreProfile.ps1') (Join-Path $documentsPowerShell 'Profile.ps1') -Force

Remove-Item (Join-Path $documentsPowerShell 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink `
  -Path (Join-Path $documentsPowerShell 'Microsoft.PowerShell_profile.ps1') `
  -Target (Join-Path $profileSource 'CurrentUserAllHostsV7CoreProfile.ps1') | Out-Null

Remove-Item (Join-Path $documentsPowerShell 'Microsoft.VSCode_profile.ps1') -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink `
  -Path (Join-Path $documentsPowerShell 'Microsoft.VSCode_profile.ps1') `
  -Target (Join-Path $profileSource 'CurrentUserAllHostsV7CoreProfile.ps1') | Out-Null
```

### 4.3 Install required PowerShell Gallery modules

Install the PowerShell Gallery dependencies before later steps import
`ATAP.Utilities.BuildTooling.PowerShell`.

```powershell
$requiredModules = @('PSFramework', 'powershell-yaml')

foreach ($moduleName in $requiredModules) {
  if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -Force
  }
}

Get-Module -ListAvailable PSFramework, powershell-yaml |
  Select-Object Name, Version, ModuleBase
```

If `PSGallery` is not already trusted on the workstation, run this once first:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

### 4.4 Register the Bitwarden login script at startup

```powershell
Import-Module ATAP.Utilities.PowerShell

$loginScript = Join-Path $profileSource 'LoginScript.ps1'
$credential = Get-BitWardenCredential

Register-StartupScheduledTask `
  -TaskName 'ATAPLoginScript' `
  -ScriptPath $loginScript `
  -Description 'Unlock Bitwarden and populate user-scope environment variables at sign-in' `
  -Credential $credential
```

Open a fresh PowerShell 7 console and verify that the profile and login script are active:

```powershell
$PROFILE | Format-List *
[System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
```

## Phase 2: Third-Party Software

## Step 5: Create the Bitwarden Secrets and Local Service Accounts

Create these Bitwarden items in the `ComputerLogins` collection before installing any
third-party service. Each item must contain a username and password field.

| Bitwarden item name                            | Local Windows account | Used by                                         |
| ---------------------------------------------- | --------------------- | ----------------------------------------------- |
| `<COMPUTERNAME>-SQLServerSrvAcct-Production`   | `SQLServerSrvAcct`    | SQL Server Database Engine and SQL Server Agent |
| `<COMPUTERNAME>-ProGetSrvAcct-Production`      | `ProGetSrvAcct`       | ProGet service                                  |
| `<COMPUTERNAME>-BuildMasterSrvAcct-Production` | `BuildMasterSrvAcct`  | BuildMaster service                             |

Then provision the local accounts:

```powershell
Import-Module ATAP.Utilities.PowerShell

$serviceAccounts = @(
  @{
    SecretName  = "$env:COMPUTERNAME-SQLServerSrvAcct-Production"
    AccountName = 'SQLServerSrvAcct'
    FullName    = 'SQL Server Service Identity'
    Description = 'Local service account for SQL Server Database Engine and Agent'
  },
  @{
    SecretName  = "$env:COMPUTERNAME-ProGetSrvAcct-Production"
    AccountName = 'ProGetSrvAcct'
    FullName    = 'ProGet Service Identity'
    Description = 'Local service account for the Inedo ProGet service'
  },
  @{
    SecretName  = "$env:COMPUTERNAME-BuildMasterSrvAcct-Production"
    AccountName = 'BuildMasterSrvAcct'
    FullName    = 'BuildMaster Service Identity'
    Description = 'Local service account for the Inedo BuildMaster service'
  }
)

foreach ($entry in $serviceAccounts) {
  $secret = Get-BitWardenSecret -Name $entry.SecretName -FolderName 'ComputerLogins'
  if (-not $secret.password) {
    throw "Bitwarden item '$($entry.SecretName)' is missing a password field."
  }

  $securePassword = ConvertTo-SecureString $secret.password -AsPlainText -Force

  New-LocalServiceAccount `
    -AccountName $entry.AccountName `
    -FullName $entry.FullName `
    -Description $entry.Description `
    -Password $securePassword `
    -GrantSeServiceLogonRight
}
```

## Step 6: Install SQL Server and Record the Setup Media Path

### 6.1 Preserve the setup media location

Keep the extracted SQL Server media on disk because `setup.exe` is required to add or
remove named instances later.

Recommended location:

```powershell
$sqlSetupRoot = 'D:\Temp\SQLExpr\extracted'
$sqlSetupExe = Join-Path $sqlSetupRoot 'Setup.exe'
```

If you do not remember where the media was extracted, try the helper that looks in the
registry and the standard staging folders:

```powershell
Import-Module ATAP.Utilities.BuildTooling.PowerShell
Find-SqlServerSetupExe
```

Record the returned path in the workstation notes or in the relevant `Overview` workspace
file for that sprint.

### 6.2 Install the base instances

Install or verify these permanent instances:

1. `Production`
2. `QA`
3. `Integration`

Use the database-management helper:

```powershell
Import-Module ATAP.Utilities.DatabaseManagement.Powershell

$setupExe = Find-SqlServerSetupExe
$setupRoot = Split-Path $setupExe -Parent

$instances = @(
  @{ Name = 'Production'; Port = 1433 },
  @{ Name = 'QA';         Port = 1435 },
  @{ Name = 'Integration'; Port = 1434 }
)

foreach ($instance in $instances) {
  Install-SqlServerInstance `
    -DatabaseHost 'localhost' `
    -SqlInstance $instance.Name `
    -ConnectionMethod 'tcp' `
    -Port $instance.Port `
    -AuthenticationMode 'Windows' `
    -IntegratedSecurity `
    -Version '2022' `
    -SqlServerSetupPath $setupRoot
}
```

### 6.3 During the SQL Server setup UI

When the SQL installer prompts for service accounts:

1. Configure the Database Engine to run as `SQLServerSrvAcct`.
2. Configure SQL Server Agent to run as `SQLServerSrvAcct`.
3. Set both services to automatic startup.
4. Keep Windows authentication enabled.

### 6.4 Verify the instances and SQL Server Agent

```powershell
@('Production', 'QA', 'Integration') | ForEach-Object {
  Get-Service -Name "MSSQL`$$_", "SQLAgent`$$_" -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType
}
```

### 6.5 Enable TCP/IP and set backup paths

For each named instance:

1. Open SQL Server Configuration Manager.
2. Enable TCP/IP for the instance.
3. Assign the intended static port.
4. Restart the instance.
5. Set the default backup directory to the Dropbox-backed location.

The current convention for `Production` is:

- Data: `C:\LocalDBs\Production`
- Logs: `C:\LocalDBs\Production`
- Backups: `C:\Dropbox\DatabaseBackups\Production`

Verify TCP connectivity:

```powershell
sqlcmd -S 'localhost\Production' -E -Q 'SELECT @@SERVERNAME, @@VERSION' -C
sqlcmd -S 'localhost\QA' -E -Q 'SELECT @@SERVERNAME' -C
sqlcmd -S 'localhost\Integration' -E -Q 'SELECT @@SERVERNAME' -C
```

## Step 7: Create Sprint and Feature-Branch Developer Instances

The permanent instances are `Production`, `QA`, and `Integration`. Developer and
experimental instances are per-user or per-feature and are created separately.

For the active developer:

```powershell
Import-Module ATAP.Utilities.BuildTooling.PowerShell

New-SprintSqlServerInstances `
  -InstanceNames @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)") `
  -Databases @('ATAPUtilities', 'AceCommander') `
  -DatabaseHost 'localhost' `
  -ConnectionMethod 'tcp'
```

Notes:

1. `New-SprintSqlServerInstances` creates only the `Dev...` and `Exp...` instances. It
   does not create `Production`, `QA`, or `Integration`.
2. For long-lived multi-sprint feature branches, combine a short feature token with the
   tier prefix and keep the full instance name under 16 characters.
3. Use the current `Overview.code-workspace` and `OverviewSprintNNNN.code-workspace`
   files as the branch matrix when deciding which extra instances are still required.

## Step 8: Build the Databases on All Instances

Run the database rebuild script after the instances exist:

```powershell
Push-Location 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
.\Database\Powershell\public\Rebuild-All-AllInstances.ps1
Pop-Location
```

This script should be treated as a temporary bootstrap script until it is converted into a
module cmdlet. For now, it is still the documented way to build and seed the databases on
the permanent instances.

## Step 9: Install and Configure ProGet and BuildMaster

Group all tooling setup under this section. ProGet and BuildMaster both use the local
`Production` SQL Server instance and Windows integrated security.

### 9.1 Install ProGet and BuildMaster from Inedo Hub

1. Download and run Inedo Hub.
2. Install ProGet first.
3. Install BuildMaster second.
4. For both products, use a connection string targeting `localhost\Production` with
   integrated security.

### 9.2 Grant the service accounts database rights

```powershell
Import-Module ATAP.Utilities.PowerShell

Initialize-SqlServiceLogin `
  -SqlInstance 'localhost\Production' `
  -DatabaseName 'ProGet' `
  -ServiceAccount "$env:COMPUTERNAME\ProGetSrvAcct" `
  -Encrypt Optional `
  -TrustServerCertificate

Initialize-SqlServiceLogin `
  -SqlInstance 'localhost\Production' `
  -DatabaseName 'BuildMaster' `
  -ServiceAccount "$env:COMPUTERNAME\BuildMasterSrvAcct" `
  -Encrypt Optional `
  -TrustServerCertificate
```

### 9.3 Reconfigure the Windows services to use the dedicated accounts

```powershell
Import-Module ATAP.Utilities.PowerShell

$proGetSecret = Get-BitWardenSecret -Name "$env:COMPUTERNAME-ProGetSrvAcct-Production" -FolderName 'ComputerLogins'
$bmSecret = Get-BitWardenSecret -Name "$env:COMPUTERNAME-BuildMasterSrvAcct-Production" -FolderName 'ComputerLogins'

$proGetCredential = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\ProGetSrvAcct",
  (ConvertTo-SecureString $proGetSecret.password -AsPlainText -Force)
)

$buildMasterCredential = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\BuildMasterSrvAcct",
  (ConvertTo-SecureString $bmSecret.password -AsPlainText -Force)
)

Set-ServiceLogonAccount -ServiceName 'INEDOPROGETSVC' -Credential $proGetCredential
Set-ServiceLogonAccount -ServiceName 'INEDOBMSVC' -Credential $buildMasterCredential
Set-InedoServicesDependency

Restart-Service INEDOPROGETSVC, INEDOBMSVC
Get-Service INEDOPROGETSVC, INEDOBMSVC | Select-Object Name, Status, StartType
```

Both services must depend on `MSSQL$PRODUCTION` so SQL Server is fully available before
either Inedo product starts.

### 9.4 Keep the config files under source control

Use the IAC repo copies of `ProGet.config` and `BuildMaster.config` and link them into
`C:\ProgramData\Inedo\SharedConfig` when that machine is the authoritative host.

## Step 10: Create Cobian Backup Jobs for the Tooling Databases

Create separate Cobian jobs for `ProGet` and `BuildMaster`. Each Cobian job should call
the SQL backup cmdlet from `ATAP.Utilities.DatabaseManagement.Powershell` rather than
copying MDF or LDF files directly.

Recommended commands:

```powershell
pwsh -Command "& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1' -DatabaseName 'ProGet' -BackupType Full"

pwsh -Command "& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\Invoke-SqlServerBackup.ps1' -DatabaseName 'BuildMaster' -BackupType Full"
```

Operational guidance:

1. Schedule a weekly full backup for each database.
2. Add nightly differential backups after the first full backup exists.
3. Point Cobian at the Dropbox-backed backup root so the resulting `.bak` or `.bak.7z`
   files replicate off-machine.
4. Verify restore instructions for both databases before the workstation is considered
   production-ready.

## Phase 3: Validate the Development Environment

## Step 11: Validate Stable-Branch Builds and Tests

Before calling the computer ready, run the stable branches through the same basic build
and test flow expected by the manual CI process.

### 11.1 ATAP.Utilities stable branch

```powershell
Push-Location 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
dotnet restore .\ATAP.Utilities.sln
dotnet build .\ATAP.Utilities.sln -c Debug
dotnet test .\ATAP.Utilities.sln -c Debug --no-build
Pop-Location
```

Run the PowerShell module tests as well:

```powershell
pwsh -Command "Invoke-Pester -Path 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\tests' -Output Detailed"
pwsh -Command "Invoke-Pester -Path 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\tests' -Output Detailed"
```

### 11.2 AceCommander stable branch

```powershell
Push-Location 'C:\Dropbox\whertzing\GitHub\AceCommander'
dotnet restore .\AceCommander.sln
dotnet build .\AceCommander.sln -c Debug
dotnet test .\AceCommander.sln -c Debug --no-build
Pop-Location
```

### 11.3 Packaging and feed validation

Validate that the stable machine can build packages and modules for the manual promotion
flow documented elsewhere in the repository.

Minimum checks:

1. NuGet package builds succeed.
2. PowerShell module builds succeed.
3. ProGet is reachable.
4. BuildMaster is reachable.

Example reachability checks:

```powershell
Invoke-WebRequest 'http://localhost:50000/' -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest 'http://localhost:8622/' -UseBasicParsing | Select-Object StatusCode
```

## Ready State

The new computer is ready for a developer when all of the following are true:

1. The expected stable and sprint worktrees exist and are synchronized.
2. PowerShell 7 profiles load without manual fixes.
3. `BW_SESSION`, `PROGET_ADMIN_API_KEY`, and `BUILDMASTER_ADMIN_API_KEY` are populated
   at user scope after sign-in.
4. SQL Server `Production`, `QA`, and `Integration` are running.
5. The required `Dev...` and `Exp...` instances exist for the active sprint or feature
   branches.
6. ProGet and BuildMaster start under their dedicated service accounts and depend on
   `MSSQL$PRODUCTION`.
7. Cobian backup jobs exist for both tooling databases.
8. Stable-branch builds and tests pass.

At that point the workstation can serve as a fully functional developer machine.
