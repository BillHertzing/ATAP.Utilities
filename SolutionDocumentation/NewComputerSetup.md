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
   - ProGet using the `Production` SQL instance — full step-by-step procedure: see [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md)
   - BuildMaster using the `Production` SQL instance — full step-by-step procedure: see [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md)
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
`ATAP.Utilities.BuildTooling.PowerShell`. Use `-Scope AllUsers` (not
`CurrentUser`) so the BuildMaster service account (`SvcBuildmaster` on
`utat022`) and any other local service identity can resolve these modules.
A `CurrentUser` install only writes under the interactive developer profile
and is invisible to service accounts — BuildMaster packing will fail
validating the module manifest when it cannot resolve `powershell-yaml`.

This step must be run from an **elevated** PowerShell 7 session so the
machine-scoped `Program Files\PowerShell\Modules` write succeeds.

```powershell
$requiredModules = @('PSFramework', 'powershell-yaml')

foreach ($moduleName in $requiredModules) {
  if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Repository PSGallery -Scope AllUsers -Force
  }
}

Get-Module -ListAvailable PSFramework, powershell-yaml |
  Select-Object Name, Version, ModuleBase
```

The `ModuleBase` column should report a path under
`C:\Program Files\PowerShell\Modules\...`, not under
`$env:USERPROFILE\Documents\PowerShell\Modules`. If it reports a per-user
path, the install ran un-elevated or with the wrong scope — uninstall the
per-user copy and re-run elevated with `-Scope AllUsers`.

If `PSGallery` is not already trusted on the workstation, run this once first:

```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

### 4.4 Install NBGV (Nerdbank.GitVersioning) machine-wide

BuildMaster runs as a service account (`SvcBuildmaster` on `utat022`) and
shells out to the `nbgv` CLI through `Get-BuildContext` during the
Experimental stage. If `nbgv` is installed only as a per-user dotnet tool
(for example, at `C:\Users\<dev>\.dotnet\tools\nbgv.exe`), the service
account cannot see it — even when `pwsh` is launched without `-NoProfile` —
and BuildMaster fails with:

```text
The 'nbgv' CLI was not found on PATH
```

Install `nbgv` to a **machine-wide** dotnet tool location so every local
account (developer logins and service accounts) can resolve it. The
convention used by the ATAP profile is `C:\ProgramData\dotnet\tools`.

```powershell
# Elevated PowerShell 7
$machineToolPath = 'C:\ProgramData\dotnet\tools'
New-Item -ItemType Directory -Path $machineToolPath -Force | Out-Null

dotnet tool install --tool-path $machineToolPath nbgv

# Verify
& (Join-Path $machineToolPath 'nbgv.exe') --version
```

`AllUsersAllHostsV7CoreProfile.ps1` (installed at
`$PSHome\profile.ps1` in step 4.1) prepends `C:\ProgramData\dotnet\tools`
to the process-scope `PATH` for every PowerShell 7 session — including the
non-interactive session BuildMaster spawns under `SvcBuildmaster`. After
opening a new `pwsh` window, both of these must succeed:

```powershell
pwsh -NoProfile -Command "Get-Command nbgv -ErrorAction SilentlyContinue"   # machine PATH only
pwsh -Command            "Get-Command nbgv -ErrorAction SilentlyContinue"   # machine PATH + profile
```

Upgrade later with:

```powershell
dotnet tool update --tool-path 'C:\ProgramData\dotnet\tools' nbgv
```

### 4.5 Register the Bitwarden login script at startup

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

### 9.4 Bootstrap git `safe.directory` for the BuildMaster service account

When a BuildMaster build agent runs as the BuildMaster service account
(`SvcBuildmaster` on `utat022`) against a worktree under
`C:\Dropbox\whertzing\GitHub\`, git refuses to operate on the directory
because it was created by a different user (the interactive developer
account that owns the Dropbox sync). Symptom:

```text
fatal: detected dubious ownership in repository at 'C:/Dropbox/whertzing/GitHub/...'
```

This breaks NBGV height computation, sourcelink commit-id resolution, and
every `Get-BuildContext` call that shells out to `git`. It typically
surfaces first during `dotnet restore` because of the
`<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>` block at
`Directory.Build.props:36`, which triggers an NBGV evaluation that needs
git.

Run **once**, as `SvcBuildmaster` itself (not as your interactive login),
in an elevated `pwsh` session opened with that account's credentials:

```powershell
# Elevated pwsh, running as SvcBuildmaster
git config --global --add safe.directory C:/Dropbox/whertzing/GitHub
```

Verify:

```powershell
git config --global --get-all safe.directory
```

Critical notes:

1. **Run as `SvcBuildmaster`, not as your interactive login.** This entry
   lives in the running user's `~/.gitconfig`. Running it from your
   developer account writes to the wrong user's gitconfig and the dubious
   ownership error persists.
2. **The trailing path is the parent** that contains every repo worktree
   (`ATAP.Utilities`, `AceCommander`, `ATAP.IAC`, `SharedVSCode`,
   `_Planning`, and all `*-wt-*-Sprint-*-work-items` siblings). Using the
   parent path lets one entry cover every current and future worktree
   under that root.
3. **Wildcards are not supported.** If a future repo root moves outside
   `C:\Dropbox\whertzing\GitHub\`, add a second `safe.directory` entry.

A common way to obtain a `SvcBuildmaster` shell from an admin login:

```powershell
$bmSecret = Get-BitWardenSecret -Name "$env:COMPUTERNAME-BuildMasterSrvAcct-Production" -FolderName 'ComputerLogins'
$bmCred = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcBuildmaster",
  (ConvertTo-SecureString $bmSecret.password -AsPlainText -Force)
)
Start-Process pwsh -Credential $bmCred -ArgumentList '-NoExit', '-Command',
  'git config --global --add safe.directory C:/Dropbox/whertzing/GitHub; git config --global --get-all safe.directory'
```

Acceptance: a fresh BuildMaster build under `SvcBuildmaster` against any
worktree under `C:\Dropbox\whertzing\GitHub\` completes `dotnet restore`
and `Get-BuildContext` without a `dubious ownership` error.

### 9.5 Keep the config files under source control

Use the IAC repo copies of `ProGet.config` and `BuildMaster.config` and link them into
`C:\ProgramData\Inedo\SharedConfig` when that machine is the authoritative host.

### 9.6 Assign the Git raft to each BuildMaster application

When configuring each BuildMaster application to read plans/monitors/scripts from Git,
the raft is assigned in this UI location:

- **Application → Settings → Advanced → Artifact & Component Hosting**

In that dialog, choose the intended raft in the **Raft** dropdown and save the
application settings.

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
Invoke-WebRequest 'http://localhost:50017/' -UseBasicParsing | Select-Object StatusCode
```

### 11.4 GitHub MCP access validation

Configure and test the GitHub MCP token before using Copilot or MCP-driven GitHub
automation from the new workstation.

```powershell
$toolRoot = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\tools'

& (Join-Path $toolRoot 'Setup-GitHubMCP.ps1') -Token '<GitHub PAT>' -Scope User
& (Join-Path $toolRoot 'Test-GitHubMCP.ps1')
```

`Setup-GitHubMCP.ps1` validates the token shape, stores it as `GITHUB_TOKEN`, and
checks that `mcp-server-github` is available on `PATH`. Use `-Scope Process` when
testing a token without persisting it.

`Test-GitHubMCP.ps1` verifies that `GITHUB_TOKEN` is visible, confirms the MCP
server command is installed, checks the repository `.vscode\settings.json` MCP
server entry, and performs a GitHub API identity/rate-limit check with the token.
Restart VS Code after setting the token at user scope.

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
9. GitHub MCP token, server, VS Code settings, and API access validation pass.

At that point the workstation can serve as a fully functional developer machine.

## Google Antigravity setup on a new Windows 11 computer

Use the steps in this section to install Google Antigravity on a new workstation and connect it to the current sprint's local repositories.

### Install prerequisites

1. Install Google Antigravity using the vendor-supported installer or package source used by the team.
2. Sign in with the account used for development work.
3. Verify Git is installed and available on `PATH`.
4. Verify Visual Studio Code is installed and available on `PATH`.
5. Verify PowerShell 7 is installed and available on `PATH`.

### Repo discovery model

Antigravity should not be configured with a hard-coded list of repository paths because the workspace file changes every sprint.

Instead, the local configuration should be generated from the current sprint's `.code-workspace` file, for example:

```text
C:\Dropbox\whertzing\GitHub\OverviewSprint0007.code-workspace
```

Each new sprint creates a new workspace file, so the authoritative source for the repo list is the active sprint workspace file, not a static Antigravity configuration checked in once.

### Recommended configuration approach

Configure Antigravity so its list of connected repositories is rebuilt from the current workspace file whenever `SprintStartAgent` creates a new sprint workspace and whenever `SprintEndAgent` closes out a sprint.

Recommended pattern:

1. Keep a small generated Antigravity config file outside the repo or in a machine-local ignored path.
2. Have `SprintStartAgent` determine the active workspace file for the new sprint.
3. Parse the `folders` collection in that `.code-workspace` file.
4. Resolve each folder path to an absolute local path.
5. Rewrite the Antigravity repo connection file or invoke the Antigravity CLI/API to register those repos.
6. Optionally remove repos no longer present in the active sprint workspace.
7. Have `SprintEndAgent` either clear the repo list or switch Antigravity to the next active workspace, depending on the sprint workflow.

### PowerShell implementation guidance

Add or maintain a PowerShell helper that accepts the current workspace path and emits the repo list in the format expected by Antigravity.

Suggested contract:

```powershell
Set-AntigravityWorkspaceRepos `
  -WorkspacePath 'C:\Dropbox\whertzing\GitHub\OverviewSprint0007.code-workspace' `
  -AntigravityConfigPath "$env:LOCALAPPDATA\Google\Antigravity\repos.json"
```

Suggested behavior:

- Read the workspace file as JSON.
- Expand every entry under `folders`.
- Normalize relative paths against the workspace file directory.
- Preserve only paths that currently exist.
- Write the resolved repo list to the Antigravity configuration store.
- Make the script idempotent so `SprintStartAgent` and `SprintEndAgent` can run it repeatedly without duplicating entries.

### Example PowerShell sketch

```powershell
function Set-AntigravityWorkspaceRepos {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $WorkspacePath,

    [Parameter(Mandatory)]
    [string] $AntigravityConfigPath
  )

  $workspace = Get-Content -Raw -Path $WorkspacePath | ConvertFrom-Json
  $workspaceDirectory = Split-Path -Parent $WorkspacePath

  $repoPaths = foreach ($folder in $workspace.folders) {
    $candidate = if ($folder.path -match '^[A-Za-z]:\\') {
      $folder.path
    }
    else {
      [System.IO.Path]::GetFullPath((Join-Path $workspaceDirectory $folder.path))
    }

    if (Test-Path -LiteralPath $candidate) {
      $candidate
    }
  }

  $repoPaths = $repoPaths | Sort-Object -Unique

  $payload = [ordered]@{
    generatedFromWorkspace = $WorkspacePath
    generatedOn = (Get-Date).ToString('s')
    repositories = @($repoPaths | ForEach-Object {
      [ordered]@{ path = $_ }
    })
  }

  $parent = Split-Path -Parent $AntigravityConfigPath
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $AntigravityConfigPath -Encoding utf8
}
```

### Agent integration points

`SprintStartAgent` should:

- Create the new sprint workspace file.
- Call `Set-AntigravityWorkspaceRepos` with that workspace file.
- Launch or refresh Antigravity if needed so it reloads the updated repo list.

`SprintEndAgent` should:

- Determine whether the sprint is being archived, replaced, or rolled forward.
- Either clear Antigravity's repo list, or repoint it to the next workspace file.
- Call the same helper so there is only one code path for repo synchronization.

### Maintenance note

Document the Antigravity integration in terms of an active workspace file and a generated local config, rather than naming a specific sprint file such as `OverviewSprint0007.code-workspace`, because that filename changes every sprint.
