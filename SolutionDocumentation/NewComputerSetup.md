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

| Bitwarden item name                          | Local Windows account | Used by                                         |
| -------------------------------------------- | --------------------- | ----------------------------------------------- |
| `<COMPUTERNAME>-SQLServerSrvAcct-Production` | `SQLServerSrvAcct`    | SQL Server Database Engine and SQL Server Agent |
| `<COMPUTERNAME>-SvcProGet-Production`        | `SvcProGet`           | ProGet service                                  |
| `<COMPUTERNAME>-SvcBuildmaster-Production`   | `SvcBuildmaster`      | BuildMaster service                             |

If this workstation must be brought online **before** an Ansible controller exists,
use the manual bootstrap procedure in
[ServiceAccountsAndBitwarden.md](ServiceAccountsAndBitwarden.md) under
`Setting Up Credentials for Services without Ansible` after the local service accounts
are created and before installing services that need Bitwarden access.

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
    SecretName  = "$env:COMPUTERNAME-SvcProGet-Production"
    AccountName = 'SvcProGet'
    FullName    = 'ProGet Service Identity'
    Description = 'Local service account for the Inedo ProGet service'
  },
  @{
    SecretName  = "$env:COMPUTERNAME-SvcBuildmaster-Production"
    AccountName = 'SvcBuildmaster'
    FullName    = 'BuildMaster Service Identity'
    Description = 'Local service account for the Inedo BuildMaster service'
  }
)

foreach ($entry in $serviceAccounts) {
  $password = Get-SecretATAP -SecretName $entry.SecretName -SecretField 'password'
  if ([string]::IsNullOrWhiteSpace($password)) {
    throw "Secret store item '$($entry.SecretName)' is missing a password field."
  }

  $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

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
  -ServiceAccount "$env:COMPUTERNAME\SvcProGet" `
  -Encrypt Optional `
  -TrustServerCertificate

Initialize-SqlServiceLogin `
  -SqlInstance 'localhost\Production' `
  -DatabaseName 'BuildMaster' `
  -ServiceAccount "$env:COMPUTERNAME\SvcBuildmaster" `
  -Encrypt Optional `
  -TrustServerCertificate
```

### 9.3 Reconfigure the Windows services to use the dedicated accounts

```powershell
Import-Module ATAP.Utilities.PowerShell

$proGetPassword = Get-SecretATAP -SecretName "$env:COMPUTERNAME-SvcProGet-Production" -SecretField 'password'
$bmPassword = Get-SecretATAP -SecretName "$env:COMPUTERNAME-SvcBuildmaster-Production" -SecretField 'password'

$proGetCredential = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcProGet",
  (ConvertTo-SecureString $proGetPassword -AsPlainText -Force)
)

$buildMasterCredential = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcBuildmaster",
  (ConvertTo-SecureString $bmPassword -AsPlainText -Force)
)

Set-ServiceLogonAccount -ServiceName 'INEDOPROGETSVC' -Credential $proGetCredential
Set-ServiceLogonAccount -ServiceName 'INEDOBMSVC' -Credential $buildMasterCredential
Set-InedoServicesDependency

Restart-Service INEDOPROGETSVC, INEDOBMSVC
Get-Service INEDOPROGETSVC, INEDOBMSVC | Select-Object Name, Status, StartType
```

Both services must depend on `MSSQL$PRODUCTION` so SQL Server is fully available before
either Inedo product starts.

### 9.4 Manually provision DPAPI Bitwarden credentials for the service accounts

> **⚠ Architecture update (Sprint 0007 — Bitwarden Secrets Manager).** Subsections
> 9.4.1–9.4.9 below provision the **Password Manager** (`bw`) login/unlock DPAPI files and
> were originally written for `SvcBuildmaster` / `SvcProGet`. They are **retained** as the
> reference pattern, which now applies to the **interactive Password Manager user
> `DeveloperTwo`** (the 2nd Bitwarden org user — see
> [NewOrganizationSetup.md](NewOrganizationSetup.md)). The **service accounts** obtain
> runtime secrets from **Bitwarden Secrets Manager** (`bws`) using machine-account access
> tokens instead — see **§9.4.10** below. Identity map for this host:
>
> | Identity | Bitwarden identity | Provisioning path |
> | --- | --- | --- |
> | Windows interactive user `DeveloperTwo` | PM User 2 | `bw` login/unlock — **9.4.1–9.4.9 pattern** |
> | `SvcBuildmaster` (service) | BWS machine `SvcBuildMaster` | `bws` access token — **§9.4.10** |
> | `SvcProGet` (service) | BWS machine `SvcInfraShared` | `bws` access token — **§9.4.10** |
> | AceCommander service / IIS | BWS machine `AceCommander` | `bws` access token — **§9.4.10** |

This section is the manual (no-Ansible) provisioning runbook for the per-service-account
DPAPI credential files described in
[ServiceAccountsAndBitwarden.md](ServiceAccountsAndBitwarden.md). Use it after the local
service accounts exist (Step 5) and after the Inedo services are installed (Step 9.1)
but before you reconfigure those services to run as the dedicated accounts (Step 9.3).
The output of this section is two pairs of DPAPI-encrypted `.xml` credential files
(login + unlock) under
`C:\ProgramData\ATAP\BitwardenCredentials\<ServiceAccount>\`, each readable only by the
owning service account on this host.

Preconditions:

1. `SvcProGet` and `SvcBuildmaster` exist on this host (Step 5).
2. You are logged in interactively as a member of the local Administrators group.
3. You know the Windows password for each of those two service accounts.
4. You know the Bitwarden email plus the Bitwarden login password and the master/unlock
   password that should be bound to each service account. In the simplest single-tenant
   model these are the same for both service accounts; if each service account has its
   own dedicated Bitwarden identity, you will need both sets of passwords.
5. The Bitwarden CLI (`bw`) is installed and on `PATH`.
6. You are running PowerShell 7 elevated.

#### 9.4.0 Checklist

Work through these steps in order. Tick each box as you complete it.

- [ ] **9.4.1** Create and ACL `C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster\`
- [ ] **9.4.2** Launch a PowerShell session as `SvcBuildmaster` and create its
      `BW_Login_Credential.xml` and `BW_Unlock_Credential.xml`
- [ ] **9.4.3** Validate the BuildMaster credential files were created
- [ ] **9.4.4** Create and ACL `C:\ProgramData\ATAP\BitwardenCredentials\SvcProGet\`
- [ ] **9.4.5** Launch a PowerShell session as `SvcProGet` and create its
      `BW_Login_Credential.xml` and `BW_Unlock_Credential.xml`
- [ ] **9.4.6** Validate the ProGet credential files were created
- [ ] **9.4.6.5** Grant `SeBatchLogonRight` ("Log on as a batch job") to
      `SvcBuildmaster` and `SvcProGet` — required before Task Scheduler will
      launch the tasks registered in 9.4.7 / 9.4.8
- [ ] **9.4.6.6** Install `ProfileForServiceAccountUsers.ps1` as the
      `CurrentUserAllHosts` profile for each service account (creates the
      `Documents\PowerShell` folder under each home directory and links the
      worktree script as `profile.ps1`)
- [ ] **9.4.7** Register the per-service-account startup task that establishes
      `BW_SESSION` (`Initialize-ServiceAccountBitwardenSession.ps1`)
- [ ] **9.4.8** Register the per-service-account periodic refresh task
      (`Refresh-BWSession.ps1`)
- [ ] **9.4.9** Smoke-test that each service account can establish a `BW_SESSION` and
      retrieve at least one known Bitwarden item via `Get-SecretATAP`

#### 9.4.1 Create and ACL the BuildMaster credentials folder

Run this from the elevated administrative session. It does not need to run as the
service account.

```powershell
$serviceAccount = 'SvcBuildmaster'
$credentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$serviceAccount"

New-Item -ItemType Directory -Path $credentialDirectory -Force | Out-Null

$acl = Get-Acl $credentialDirectory
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { [void]$acl.RemoveAccessRule($_) }

$inheritFlags = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
$propFlags    = [System.Security.AccessControl.PropagationFlags]::None
$allowType    = [System.Security.AccessControl.AccessControlType]::Allow
$fullCtl      = [System.Security.AccessControl.FileSystemRights]::FullControl

$rules = @(
  [System.Security.AccessControl.FileSystemAccessRule]::new($serviceAccount,  $fullCtl, $inheritFlags, $propFlags, $allowType),
  [System.Security.AccessControl.FileSystemAccessRule]::new('SYSTEM',         $fullCtl, $inheritFlags, $propFlags, $allowType),
  [System.Security.AccessControl.FileSystemAccessRule]::new('Administrators', $fullCtl, $inheritFlags, $propFlags, $allowType)
)

foreach ($rule in $rules) {
  $acl.AddAccessRule($rule)
}

Set-Acl -LiteralPath $credentialDirectory -AclObject $acl
```

#### 9.4.2 Create the BuildMaster DPAPI credential files

DPAPI binds the encryption key to the running user, so the `Export-Clixml` files must
be produced by a process running as `SvcBuildmaster` itself. The standard pattern is
`Start-Process -Credential` to obtain a shell in that account's security context, then
run [`Update-ServiceAccountBWCredentialFile.ps1`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Update-ServiceAccountBWCredentialFile.ps1)
inside that shell. The helper function takes the new Bitwarden passwords as
`SecureString` parameters (so they never appear on the command line), runs the security
guard that verifies the current user equals `-ServiceAccount`, and wraps
`Get-BitWardenCredential -Replace` with a single call.

Run **from the elevated administrative session**:

```powershell
$serviceAccount = 'SvcBuildmaster'
$credentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$serviceAccount"

# Auto-detect the source tree containing the new helpers. Prefer the active sprint
# worktree during sprint development; fall back to the stable repo after merge.
$candidateRoots = @(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items',
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
)
$repoRoot = $candidateRoots | Where-Object {
  Test-Path -LiteralPath (Join-Path $_ 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Update-ServiceAccountBWCredentialFile.ps1')
} | Select-Object -First 1
if (-not $repoRoot) {
  throw 'Update-ServiceAccountBWCredentialFile.ps1 not found in any known repository root.'
}
$updateScript = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Update-ServiceAccountBWCredentialFile.ps1'

$serviceCredential = Get-Credential -UserName ".\$serviceAccount" `
  -Message "Enter the Windows password for $serviceAccount"

# Build a small provisioning script and write it to the (ACL-protected) credential
# directory. Driving the spawned pwsh with -File <path> instead of -Command "<here-string>"
# avoids the Windows command-line argument escaping that was mangling SecureString
# variables across line continuations. The script self-deletes at the end so the
# credential directory stays clean.
$provScript = Join-Path $credentialDirectory ".provision-$serviceAccount-$(Get-Random).ps1"

# Single-quoted here-string keeps every $ literal; explicit Replace() substitutes the
# three placeholders so there is exactly one substitution mechanism (no nested escaping).
$scriptBody = @'
$env:TEMP = '__CREDDIR__'
$env:TMP  = '__CREDDIR__'

Write-Host '---- Spawned-window security context ----'
Write-Host ('Windows identity : ' + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
Write-Host ('whoami output    : ' + (whoami))
Write-Host ('Expected         : *\__SERVICE__')
Write-Host '-----------------------------------------'

. '__UPDATE__'

$bwUser   = Read-Host 'Bitwarden username/email bound to __SERVICE__'
$bwLogin  = Read-Host 'Bitwarden login password' -AsSecureString
$bwUnlock = Read-Host 'Bitwarden unlock/master password' -AsSecureString

# Splat the arguments so PowerShell binds them by name from a hashtable. This avoids the
# multi-line command-line parameter binding issue that was converting $bwLogin to String.
$params = @{
    ServiceAccount          = '__SERVICE__'
    CredentialDirectory     = '__CREDDIR__'
    BitwardenUserName       = $bwUser
    BitWardenLoginPassword  = $bwLogin
    BitWardenUnlockPassword = $bwUnlock
    NoRefresh               = $true
}
Update-ServiceAccountBWCredentialFile @params

Write-Host ''
Write-Host 'Provisioning complete. Type "exit" to close this window.'

# Self-delete this provisioning script.
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
'@

$scriptBody = $scriptBody.Replace('__CREDDIR__', $credentialDirectory)
$scriptBody = $scriptBody.Replace('__UPDATE__',  $updateScript)
$scriptBody = $scriptBody.Replace('__SERVICE__', $serviceAccount)

Set-Content -LiteralPath $provScript -Value $scriptBody -Encoding utf8

# -NoProfile bypasses the user profile of the service account. Service accounts that
# have never interactively logged in have no MyDocuments folder, so the standard ATAP
# AllUsersAllHostsV7CoreProfile.ps1 throws inside Get-HostSettings.ps1 when it tries to
# Join-Path against an empty MyDocuments. (Note: -NoProfile is disallowed for Pester per
# the repo rules, but is appropriate here.)
Start-Process pwsh `
  -Credential $serviceCredential `
  -WorkingDirectory $credentialDirectory `
  -ArgumentList '-NoProfile', '-NoExit', '-File', $provScript
```

When the spawned window opens, the first lines printed must include
`Windows identity : UTAT022\SvcBuildmaster`. If they instead show your interactive
user (for example `UTAT022\whertzing`), `Start-Process -Credential` did not actually
elevate. That happens on hardened workstations where the launching session lacks the
`SeAssignPrimaryToken` privilege; in that case fall back to one of:

- **PsExec** (Sysinternals): `psexec -u .\SvcBuildmaster -p <pwd> -h pwsh.exe -NoProfile -NoExit -File <provScript>`
- **Task Scheduler one-shot**: register a task with `-Principal SvcBuildmaster -LogonType Password`, trigger once, then `Unregister-ScheduledTask` after the credential files appear.

A new PowerShell window appears running as `SvcBuildmaster`. The window prompts for
the three Bitwarden values, calls `Update-ServiceAccountBWCredentialFile`, and prints
a `PSCustomObject` summarizing the rotation. After reviewing the output, close the
window with `exit`.

> **Why `-NoRefresh`?** `Update-ServiceAccountBWCredentialFile` normally triggers
> `Refresh-BWSession -ForceReunlock` at the end so a running service picks up the new
> credentials immediately. During first-time provisioning the live `BW_SESSION` does
> not exist yet, so the refresh is suppressed; step 9.4.7 registers the startup task
> that will perform the unlock at next boot, and step 9.4.8 registers the recurring
> refresh that maintains it thereafter.

#### 9.4.3 Validate the BuildMaster credential files

Back in the elevated administrative session:

```powershell
$credentialDirectory = 'C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster'
Get-ChildItem -LiteralPath $credentialDirectory -Filter '*.xml' |
  Select-Object Name, Length, LastWriteTime
```

You should see at least these two files:

```text
<COMPUTERNAME>_SvcBuildmaster_BW_Login_Credential.xml
<COMPUTERNAME>_SvcBuildmaster_BW_Unlock_Credential.xml
```

Confirm via ACL that only `SvcBuildmaster`, `SYSTEM`, and `Administrators` are
granted access:

```powershell
(Get-Acl $credentialDirectory).Access |
  Select-Object IdentityReference, FileSystemRights, AccessControlType
```

#### 9.4.4 Create and ACL the ProGet credentials folder

Repeat Step 9.4.1 substituting `SvcProGet`:

```powershell
$serviceAccount = 'SvcProGet'
$credentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$serviceAccount"

New-Item -ItemType Directory -Path $credentialDirectory -Force | Out-Null

$acl = Get-Acl $credentialDirectory
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { [void]$acl.RemoveAccessRule($_) }

$inheritFlags = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
$propFlags    = [System.Security.AccessControl.PropagationFlags]::None
$allowType    = [System.Security.AccessControl.AccessControlType]::Allow
$fullCtl      = [System.Security.AccessControl.FileSystemRights]::FullControl

$rules = @(
  [System.Security.AccessControl.FileSystemAccessRule]::new($serviceAccount,  $fullCtl, $inheritFlags, $propFlags, $allowType),
  [System.Security.AccessControl.FileSystemAccessRule]::new('SYSTEM',         $fullCtl, $inheritFlags, $propFlags, $allowType),
  [System.Security.AccessControl.FileSystemAccessRule]::new('Administrators', $fullCtl, $inheritFlags, $propFlags, $allowType)
)

foreach ($rule in $rules) {
  $acl.AddAccessRule($rule)
}

Set-Acl -LiteralPath $credentialDirectory -AclObject $acl
```

#### 9.4.5 Create the ProGet DPAPI credential files

Same pattern as 9.4.2 — launch a `pwsh` window as `SvcProGet` and invoke
[`Update-ServiceAccountBWCredentialFile.ps1`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Update-ServiceAccountBWCredentialFile.ps1)
inside that shell.

Run **from the elevated administrative session**:

```powershell
$serviceAccount = 'SvcProGet'
$credentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$serviceAccount"

$candidateRoots = @(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items',
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
)
$repoRoot = $candidateRoots | Where-Object {
  Test-Path -LiteralPath (Join-Path $_ 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Update-ServiceAccountBWCredentialFile.ps1')
} | Select-Object -First 1
if (-not $repoRoot) {
  throw 'Update-ServiceAccountBWCredentialFile.ps1 not found in any known repository root.'
}
$updateScript = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Update-ServiceAccountBWCredentialFile.ps1'

$serviceCredential = Get-Credential -UserName ".\$serviceAccount" `
  -Message "Enter the Windows password for $serviceAccount"

# Same temp-script + splat pattern as 9.4.2.
$provScript = Join-Path $credentialDirectory ".provision-$serviceAccount-$(Get-Random).ps1"

$scriptBody = @'
$env:TEMP = '__CREDDIR__'
$env:TMP  = '__CREDDIR__'

Write-Host '---- Spawned-window security context ----'
Write-Host ('Windows identity : ' + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
Write-Host ('whoami output    : ' + (whoami))
Write-Host ('Expected         : *\__SERVICE__')
Write-Host '-----------------------------------------'

. '__UPDATE__'

$bwUser   = Read-Host 'Bitwarden username/email bound to __SERVICE__'
$bwLogin  = Read-Host 'Bitwarden login password' -AsSecureString
$bwUnlock = Read-Host 'Bitwarden unlock/master password' -AsSecureString

$params = @{
    ServiceAccount          = '__SERVICE__'
    CredentialDirectory     = '__CREDDIR__'
    BitwardenUserName       = $bwUser
    BitWardenLoginPassword  = $bwLogin
    BitWardenUnlockPassword = $bwUnlock
    NoRefresh               = $true
}
Update-ServiceAccountBWCredentialFile @params

Write-Host ''
Write-Host 'Provisioning complete. Type "exit" to close this window.'

Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
'@

$scriptBody = $scriptBody.Replace('__CREDDIR__', $credentialDirectory)
$scriptBody = $scriptBody.Replace('__UPDATE__',  $updateScript)
$scriptBody = $scriptBody.Replace('__SERVICE__', $serviceAccount)

Set-Content -LiteralPath $provScript -Value $scriptBody -Encoding utf8

Start-Process pwsh `
  -Credential $serviceCredential `
  -WorkingDirectory $credentialDirectory `
  -ArgumentList '-NoProfile', '-NoExit', '-File', $provScript
```

The header in the spawned window must show `Windows identity : UTAT022\SvcProGet`.
If it shows your interactive user, fall back to PsExec or a one-shot scheduled task
as described under 9.4.2.

Answer the three prompts in the new window, review the rotation summary, then close
the window with `exit`. The `-NoRefresh`, `-NoProfile`, and TEMP-reset rationales from
9.4.2 apply here as well.

#### 9.4.6 Validate the ProGet credential files

```powershell
$credentialDirectory = 'C:\ProgramData\ATAP\BitwardenCredentials\SvcProGet'
Get-ChildItem -LiteralPath $credentialDirectory -Filter '*.xml' |
  Select-Object Name, Length, LastWriteTime
```

#### 9.4.6.5 Grant `SeBatchLogonRight` to the service accounts

The scheduled tasks registered in 9.4.7 and 9.4.8 run with `LogonType=Password`,
which under the hood uses `LOGON32_LOGON_BATCH`. Windows requires the target
account to hold the "Log on as a batch job" user right (`SeBatchLogonRight`),
otherwise Task Scheduler accepts `Register-ScheduledTask` silently but refuses
to launch the task: `LastTaskResult` stays at `267011` (`SCHED_S_TASK_HAS_NOT_RUN`)
and no event is written to the script's event source or PSFramework log file.

Unlike `schtasks.exe`, the PowerShell `Register-ScheduledTask` cmdlet does **not**
grant `SeBatchLogonRight` automatically when `-Password` is supplied. Grant it
explicitly via `secedit` from the elevated administrative session, once per
host, before running 9.4.7:

```powershell
$sids = @(
  (Get-LocalUser -Name 'SvcBuildmaster').SID.Value,
  (Get-LocalUser -Name 'SvcProGet').SID.Value
)

# Read the current entry so we append rather than replace
$tmp = "$env:TEMP\userrights-export-$(Get-Random).inf"
secedit /export /areas USER_RIGHTS /cfg $tmp | Out-Null
$currentLine = (Select-String -Path $tmp -Pattern '^SeBatchLogonRight\s*=').Line
Remove-Item $tmp -ErrorAction SilentlyContinue

# Parse the existing entries, add ours (deduplicated), rebuild the entry
$existing = ($currentLine -replace '^SeBatchLogonRight\s*=\s*', '') -split ','
$combined = ($existing + ($sids | ForEach-Object { "*$_" })) |
  ForEach-Object { $_.Trim() } |
  Where-Object { $_ } |
  Select-Object -Unique
$newLine = "SeBatchLogonRight = " + ($combined -join ',')

# Write a minimal INF and apply it (USER_RIGHTS area only)
$applyInf = "$env:TEMP\grant-batch-$(Get-Random).inf"
$applyDb  = "$env:TEMP\grant-batch-$(Get-Random).sdb"
@"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
$newLine
"@ | Set-Content -LiteralPath $applyInf -Encoding Unicode

secedit /configure /db $applyDb /cfg $applyInf /areas USER_RIGHTS /quiet

Remove-Item $applyInf, $applyDb -ErrorAction SilentlyContinue
```

Verify the right landed. `secedit` resolves the SIDs of local accounts back to
their SAM names on import, so the entry shows the accounts by name rather than
SID — both forms are equivalent:

```powershell
$tmp = "$env:TEMP\userrights-verify-$(Get-Random).inf"
secedit /export /areas USER_RIGHTS /cfg $tmp | Out-Null
$line = (Select-String -Path $tmp -Pattern '^SeBatchLogonRight\s*=').Line
Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host $line
foreach ($svc in @('SvcBuildmaster', 'SvcProGet')) {
  $sid = (Get-LocalUser -Name $svc).SID.Value
  $has = ($line -match [regex]::Escape($svc)) -or ($line -match [regex]::Escape($sid))
  Write-Host "$svc has SeBatchLogonRight: $has"
}
```

Expected — the printed line contains `SvcBuildmaster` and `SvcProGet` (or their
SIDs), and both verification lines say `True`.

> **Why this is not handled by `Register-ScheduledTask`:** the PowerShell
> ScheduledTasks module uses the Task Scheduler 2.0 COM API, which does not
> touch LSA user-rights policy. Only `schtasks.exe` (and its legacy
> `at.exe` predecessor) grants `SeBatchLogonRight` as a side effect. For a
> reproducible runbook we grant the right explicitly with `secedit` so the
> step does not depend on which registration tool happens to be in use.

#### 9.4.6.6 Install the service-account PowerShell profile

`ProfileForServiceAccountUsers.ps1` is the PowerShell `CurrentUserAllHosts`
profile that interactive service-account sessions load. It dot-sources the
machine-wide `global_EnvironmentVariables.ps1` and then calls
`Set-EnvironmentVariablesProcess`, with a service-account-specific exclusion
list that removes `OPENSSL_CONF`, `OPENSSL_HOME`, and `RANDFILE` from the
`$global:EnvVars` hash before any environment variable is written. These three
keys resolve to paths under the operator's personal Dropbox folder; service
accounts have no read access there, and leaving `OPENSSL_CONF` set causes the
Bitwarden CLI (`bw.exe`) to abort during TLS init.

> **Scheduled tasks vs interactive sessions.** The 9.4.7 / 9.4.8 tasks run
> `pwsh.exe -NoProfile -File …`, so the profile installed here is **not**
> evaluated when the task fires. The two Bitwarden helper scripts also clear
> these OpenSSL vars defensively at the top of `PROCESS{}` as a belt-and-
> suspenders measure. The profile is still required because (a) any
> interactive `Start-Process pwsh -Credential` window opened as a service
> account during diagnostics, smoke-testing, or future maintenance gets a
> clean environment, and (b) it documents the contract that service-account
> sessions must not inherit operator-Dropbox paths.

Run this from the elevated administrative session. The script creates the
`Documents\PowerShell` folder under each service account's home directory
(needed only the first time) and creates an NTFS symbolic link from each
account's `profile.ps1` to the worktree copy of
`ProfileForServiceAccountUsers.ps1`:

```powershell
$candidateRoots = @(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items',
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
)
$profileRelative = 'src\ATAP.Utilities.PowerShell\Profiles\ProfileForServiceAccountUsers.ps1'
$repoRoot = $candidateRoots | Where-Object {
  Test-Path -LiteralPath (Join-Path $_ $profileRelative)
} | Select-Object -First 1
if (-not $repoRoot) {
  throw "ProfileForServiceAccountUsers.ps1 not found in any known repository root."
}
$profileSource = Join-Path $repoRoot $profileRelative

foreach ($svcAccount in @('SvcBuildmaster', 'SvcProGet')) {
  $svcHome = "C:\Users\$svcAccount"
  $psDir   = Join-Path $svcHome 'Documents\PowerShell'
  $linkPs1 = Join-Path $psDir 'profile.ps1'

  if (-not (Test-Path -LiteralPath $svcHome -PathType Container)) {
    throw "Home folder '$svcHome' does not exist. Log in as $svcAccount once (or run a process as that account) to create the profile, then retry."
  }
  if (-not (Test-Path -LiteralPath $psDir -PathType Container)) {
    New-Item -ItemType Directory -Path $psDir -Force | Out-Null
    Write-Host "Created $psDir"
  }

  # If a real file or stale link already exists, replace it.
  if (Test-Path -LiteralPath $linkPs1) {
    $existing = Get-Item -LiteralPath $linkPs1 -Force
    if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -contains $profileSource) {
      Write-Host "Link already correct: $linkPs1 -> $profileSource"
      continue
    }
    Write-Host "Replacing existing $linkPs1"
    Remove-Item -LiteralPath $linkPs1 -Force
  }

  New-Item -ItemType SymbolicLink -Path $linkPs1 -Target $profileSource -Force | Out-Null
  Write-Host "Linked $linkPs1 -> $profileSource"
}
```

Verification — both links resolve to the worktree source file:

```powershell
foreach ($svcAccount in @('SvcBuildmaster', 'SvcProGet')) {
  $linkPs1 = "C:\Users\$svcAccount\Documents\PowerShell\profile.ps1"
  if (Test-Path -LiteralPath $linkPs1) {
    $info = Get-Item -LiteralPath $linkPs1 -Force
    "{0,-25} {1,-12} -> {2}" -f $svcAccount, $info.LinkType, ($info.Target -join ';')
  } else {
    "{0,-25} MISSING" -f $svcAccount
  }
}
```

Expected — two `SymbolicLink` lines pointing at the same worktree path.

> **Sprint vs stable retarget.** This link is created from the sprint
> worktree path. When the sprint merges into stable, retarget each link to
> `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\Profiles\ProfileForServiceAccountUsers.ps1`
> as part of SprintEndAgent. Re-running the script above against the stable
> worktree (after removing the sprint-pointing links) is sufficient.

#### 9.4.7 Register the per-service-account startup task

The startup task runs once at host boot under each service account, decrypts the DPAPI
credential files, and writes `BW_SESSION` into that account's User-scope environment so
the service inherits it on next start.

```powershell
# Resolve the init script using the same candidate-roots fallback as 9.4.2 / 9.4.5
# so this works both during a sprint (script lives only in the sprint worktree)
# and after the sprint merges into stable. The registered task invokes the script
# by absolute path with -NoProfile, so no module import is needed here.
$candidateRoots = @(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items',
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
)
$initRelative = 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Initialize-ServiceAccountBitwardenSession.ps1'
$repoRoot = $candidateRoots | Where-Object {
  Test-Path -LiteralPath (Join-Path $_ $initRelative)
} | Select-Object -First 1
if (-not $repoRoot) {
  throw "Initialize-ServiceAccountBitwardenSession.ps1 not found in any known repository root."
}
$initScript = Join-Path $repoRoot $initRelative

foreach ($svcAccount in @('SvcBuildmaster', 'SvcProGet')) {
  # Use the fully qualified COMPUTER\account form. Register-ScheduledTask's
  # LookupAccountName call does not reliably resolve the '.\' prefix for local
  # accounts; passing $env:COMPUTERNAME\<account> works on all Windows versions.
  $accountUpn = "$env:COMPUTERNAME\$svcAccount"
  $credentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$svcAccount"

  $svcPassword = Read-Host "Windows password for $svcAccount" -AsSecureString

  $action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
    -Argument "-NoProfile -File `"$initScript`" -CredentialDirectory `"$credentialDirectory`""
  $trigger = New-ScheduledTaskTrigger -AtStartup
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

  # -User + -Password belongs to a different parameter set than -Principal in
  # Register-ScheduledTask. Supplying -Password makes LogonType=Password and
  # the default RunLevel=Limited is what we want for these service tasks.
  Register-ScheduledTask `
    -TaskName "ATAP-BWSession-Init-$svcAccount" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $accountUpn `
    -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto(
      [Runtime.InteropServices.Marshal]::SecureStringToBSTR($svcPassword)
    )) `
    -Force | Out-Null
}
```

#### 9.4.8 Register the per-service-account refresh task

The refresh task runs on a recurring trigger and re-unlocks the vault before the session
expires.

```powershell
# Resolve the refresh script using the same candidate-roots fallback as 9.4.7.
# The registered task invokes the script by absolute path with -NoProfile, so
# no module import is needed here.
$candidateRoots = @(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items',
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
)
$refreshRelative = 'src\ATAP.Utilities.BuildTooling.PowerShell\public\Refresh-BWSession.ps1'
$repoRoot = $candidateRoots | Where-Object {
  Test-Path -LiteralPath (Join-Path $_ $refreshRelative)
} | Select-Object -First 1
if (-not $repoRoot) {
  throw "Refresh-BWSession.ps1 not found in any known repository root."
}
$refreshScript = Join-Path $repoRoot $refreshRelative

foreach ($svcAccount in @('SvcBuildmaster', 'SvcProGet')) {
  # See 9.4.7 for the rationale on using $env:COMPUTERNAME\<account> instead of .\<account>.
  $accountUpn = "$env:COMPUTERNAME\$svcAccount"
  $credentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$svcAccount"

  $svcPassword = Read-Host "Windows password for $svcAccount" -AsSecureString

  $action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
    -Argument "-NoProfile -File `"$refreshScript`" -CredentialDirectory `"$credentialDirectory`""
  $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5)) `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration ([TimeSpan]::FromDays(365))
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 3)

  # See 9.4.7 for the rationale on -User/-Password vs -Principal.
  Register-ScheduledTask `
    -TaskName "ATAP-BWSession-Refresh-$svcAccount" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $accountUpn `
    -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto(
      [Runtime.InteropServices.Marshal]::SecureStringToBSTR($svcPassword)
    )) `
    -Force | Out-Null
}
```

#### 9.4.9 Smoke-test secret retrieval as each service account

For each service account, launch a `Start-Process pwsh -Credential` window and verify:

```powershell
[System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User') |
  ForEach-Object { "BW_SESSION length: $($_.Length)" }
Get-SecretATAP -SecretName "$env:COMPUTERNAME-SvcBuildmaster-Production" -SecretField 'username'
```

If the second call returns the expected username string, the manual provisioning for
that service account is complete.

> **Cross-reference:** Re-keying these credential files later (Bitwarden master password
> change, Windows password rotation, host migration) is handled by
> `Update-ServiceAccountBWCredentialFile`. See
> [ServiceAccountsAndBitwarden.md](ServiceAccountsAndBitwarden.md#rotation-and-refresh-strategy)
> for the rotation runbook.

#### 9.4.10 Provision Secrets Manager (`bws`) access tokens for the service accounts

Under the current architecture the **service accounts** read runtime secrets from
**Bitwarden Secrets Manager** with a machine-account **access token** — there is no
`bw login`, no `unlock`, no `BW_SESSION`, and no startup/refresh task. The DPAPI-protected
access token is the entire credential. (The `bw`/Password-Manager steps 9.4.1–9.4.9 are
the separate path for the interactive user `DeveloperTwo`; see the banner at the top of
§9.4.)

Preconditions:

1. The Bitwarden org, projects, machine accounts, and **access tokens** exist
   ([NewOrganizationSetup.md](NewOrganizationSetup.md) Phase 2).
2. `SvcBuildmaster` / `SvcProGet` exist on this host and their credential folders are
   ACL'd (9.4.1 / 9.4.4).
3. You are elevated and have each machine account's access token to hand.

Host mapping:

| Windows service account | BWS machine account | Projects | DPAPI token file |
| --- | --- | --- | --- |
| `SvcBuildmaster` | `SvcBuildMaster` | `BuildMaster-Core`, `CI-Shared` | `…\SvcBuildmaster\<HOST>_SvcBuildmaster_BWS_AccessToken.xml` |
| `SvcProGet` | `SvcInfraShared` | `ProGet-Core`, `CI-Shared` | `…\SvcProGet\<HOST>_SvcProGet_BWS_AccessToken.xml` |

##### 9.4.10.1 Install the `bws` CLI (once per host)

Install the Bitwarden Secrets Manager CLI (`bws`) and confirm it is on `PATH`:

```powershell
winget install Bitwarden.SecretsManager   # or download the bws release and add to PATH
bws --version
```

##### 9.4.10.2 DPAPI-store each access token (run AS the service account)

DPAPI binds to the running user, so the token file must be written by a process running as
the owning service account. From the elevated admin session, for each service account,
open a shell as that account and store its token. The helper cmdlet
`Initialize-ServiceAccountBWSAccessToken` (added in `ATAP.Utilities.BuildTooling.PowerShell`)
encapsulates the write; the equivalent inline form is:

```powershell
# Runs AS the service account (Start-Process pwsh -Credential), elevated.
$credDir = "C:\ProgramData\ATAP\BitwardenCredentials\$env:USERNAME"
$sam     = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
$tokPath = Join-Path $credDir "$env:COMPUTERNAME`_${sam}_BWS_AccessToken.xml"
$token   = Read-Host 'BWS machine-account access token' -AsSecureString
(New-Object System.Management.Automation.PSCredential('BWS_ACCESS_TOKEN', $token)) |
  Export-Clixml -LiteralPath $tokPath
```

##### 9.4.10.3 Validate (as the service account)

Decrypt the token in memory and confirm the machine account can read its projects:

```powershell
$tokPath = "C:\ProgramData\ATAP\BitwardenCredentials\$env:USERNAME\$env:COMPUTERNAME`_$($env:USERNAME)_BWS_AccessToken.xml"
$cred    = Import-Clixml -LiteralPath $tokPath
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
try {
  bws secret list --output json | ConvertFrom-Json | Select-Object key, projectId
} finally {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

Expected — the listed secret `key`s match the projects granted to that machine account.
Runtime secret reads go through `Get-SecretATAP` with the
`BitwardenSecretsManager` provider (set `SecretStoreType='BitwardenSecretsManager'` in
`$global:settings`), which resolves the token from this DPAPI file.

> **Rotation:** regenerating the machine-account token in the web vault invalidates the
> old one; re-run 9.4.10.2 on every host that uses that machine account.

### 9.5 Bootstrap git `safe.directory` for the BuildMaster service account

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
$bmPassword = Get-SecretATAP -SecretName "$env:COMPUTERNAME-SvcBuildmaster-Production" -SecretField 'password'
$bmCred = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcBuildmaster",
  (ConvertTo-SecureString $bmPassword -AsPlainText -Force)
)
Start-Process pwsh -Credential $bmCred -ArgumentList '-NoExit', '-Command',
  'git config --global --add safe.directory C:/Dropbox/whertzing/GitHub; git config --global --get-all safe.directory'
```

Acceptance: a fresh BuildMaster build under `SvcBuildmaster` against any
worktree under `C:\Dropbox\whertzing\GitHub\` completes `dotnet restore`
and `Get-BuildContext` without a `dubious ownership` error.

### 9.6 Keep the config files under source control

Use the IAC repo copies of `ProGet.config` and `BuildMaster.config` and link them into
`C:\ProgramData\Inedo\SharedConfig` when that machine is the authoritative host.

### 9.7 Assign the Git raft to each BuildMaster application

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
