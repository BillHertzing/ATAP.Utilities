# Setup a New Development Computer

> **Canonical.** The companion [NewComputerSetupUsingAnsible.md](NewComputerSetupUsingAnsible.md)
> is retained only for its deeper BIOS / OS-install / Ansible-bootstrap notes; where the two
> overlap, THIS document wins (cross-link added 2026-07-06, Task 12.45.e).

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

## OS Image Sources

Before beginning, decide which OS image you are starting from:

**Option A — Direct from Microsoft (OEM image)**
The PC ships with a manufacturer-specific Windows image that includes OEM additions
(drivers, utilities, bloatware). This is the most common starting point for a new machine.
OOBE runs from this image. Bloatware should be removed during or after setup.

**Option B — Custom organization image**
A pre-configured Windows image built and maintained in the `ATAP.IAC` repository. It skips
or automates much of the manual setup described in this document.

> **See:** `ATAP.IAC` for details on the custom image pipeline. A dedicated explainer —
> _Creating a Custom Windows 11 Organization Image_ — is **not yet written**. When
> available it will be linked here.

The steps below assume **Option A** (OEM image). Where a custom image eliminates a step, a
note says so.

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

### 1.1 First login — create a local user account

This setup uses a **local account** rather than a Microsoft account because:

- These machines are domain-less workstations on a private LAN.
- Services (SQL Server, ProGet, BuildMaster, Cobian) run under local service accounts.
- A Microsoft account ties the local profile to cloud sync in ways that can interfere with
  predictable configuration management.

> **TBD:** Whether to document a Microsoft Live account as the primary user (for Windows
> Hello, OneDrive, or AAD/Intune policy) is still under consideration. This document covers
> the local-account path only until that decision is made.

**Windows 11 Pro path (local account during OOBE):**

1. Power on the PC and complete the **Language**, **Region**, and **Keyboard layout** screens.
2. On the **"Let's connect you to a network"** screen, click **"I don't have internet"**
   (bottom-left) → **"Continue with limited setup"**. If that option is not visible, use the
   workaround below.

**Fallback workaround (Home, or if the option is not visible on Pro):**

1. On the network screen, press **Shift + F10** to open a command prompt.
2. Run:

   ```cmd
   oobe\bypassnro
   ```

3. The PC reboots and re-enters OOBE. **"I don't have internet"** now appears — click it →
   **"Continue with limited setup"**.

> **Note:** `oobe\bypassnro` is an official Microsoft-supported bypass. It sets a registry
> flag that skips the network requirement for the current OOBE session.

After choosing limited/offline setup, enter the account details:

1. **Who's going to use this PC?** — Enter the local username. Use the same username as on
   other machines in the environment (e.g., `whertzing`) to keep paths, profile directories,
   and scripts consistent.
2. **Create a super memorable password** — Enter a strong password. Store it in Bitwarden
   under the entry for this machine (Bitwarden is installed in Step 2 / Step 5). Until then,
   record it securely offline.
3. **Security questions** — Windows 11 requires three for local accounts. Use memorably
   wrong answers and store them in Bitwarden alongside the password.

> Turn off all optional telemetry and advertising features on the privacy/diagnostics
> consent screens.

### 1.2 Verify the account is an Administrator

When OOBE creates the **first** local account, Windows automatically adds it to the local
**Administrators** group. Verify after the desktop appears:

```powershell
# Confirm current user's group membership
whoami /groups | Select-String Administrators

# Or list the Administrators group members explicitly
net localgroup Administrators
```

If the account lacks Administrator privileges — or you are adding a second admin account —
run (as Administrator):

```powershell
# Replace 'whertzing' with the actual username
Add-LocalGroupMember -Group 'Administrators' -Member 'whertzing'
Get-LocalGroupMember -Group 'Administrators'
```

### 1.3 (Optional) Enable the built-in Administrator account

The built-in `Administrator` account is **disabled** by default. For emergency console
access (recovery when the main account is locked out) it can be enabled:

```powershell
Enable-LocalUser -Name 'Administrator'
# Leave blank for console-only access (the default when the account has no password)
Set-LocalUser -Name 'Administrator' -Password ([System.Security.SecureString]::new())
```

> **Security note:** If this machine is reachable from a network, set a strong password on
> the built-in `Administrator` account and store it in Bitwarden.

### 1.4 Windows Update

Run Windows Update immediately after first login to reach the current patch level **before**
installing any software. This may require several reboot cycles. Ensure the machine reaches
Windows 11 24H2 build 26200 or later before proceeding to Step 2.

## Step 2: Install Core Tools

Install and verify these tools before continuing:

1. PowerShell 7
2. Git
3. Visual Studio Code
4. Dropbox
5. Bitwarden desktop and the `bw` Password-Manager CLI (the Secrets Manager CLI `bws`
   is installed machine-wide separately in Step 4.6)
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

Install **Dropbox first and manually** (download from
[dropbox.com/install](https://www.dropbox.com/install)). Chocolatey is not yet available at
this stage, and organization scripts, PowerShell modules, and the Chocolatey package
manifest all live under `C:\Dropbox\whertzing\` once Dropbox syncs (Step 3). The remaining
tools are installed with Chocolatey below.

### 2.1 Install Chocolatey

Chocolatey is the organization's standard Windows package manager and a prerequisite for
installing most tools in the approved package list.

> **Custom image note:** If the machine was provisioned from the `ATAP.IAC` custom image,
> Chocolatey may already be installed. Run `choco --version` to check before proceeding.

Open PowerShell 7 (or Windows PowerShell) **as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Verify
choco --version            # Expected: 2.x or later

# Enable confirmation bypass for non-interactive installs and list sources
choco feature enable -n allowGlobalConfirmation
choco source list
```

> If the organization runs a local Chocolatey feed through ProGet (Step 9), add it as a
> source once ProGet is up:
>
> ```powershell
> choco source add --name='proget-choco' --source='http://<proget-host>/nuget/chocolatey/'
> ```

### 2.2 Approved Chocolatey packages

The authoritative list of approved packages is maintained in the `ATAP.IAC` repository under
the Infrastructure-as-Code data for this machine class.

> **See:** `ATAP.IAC` → organization IAC data → Chocolatey package manifest for
> `utat022`-class workstations. _(Exact file path TBD — link here once the IAC data is
> formalized.)_

The following categories are expected; exact package names and versions are in `ATAP.IAC`:

| Category            | Key Packages                                                            |
| ------------------- | ----------------------------------------------------------------------- |
| Shell & terminal    | `pwsh` (PowerShell 7), `git`, `git-credential-manager`                  |
| Editor & IDE        | `vscode`                                                                |
| Compression         | `7zip`                                                                  |
| File sync           | `dropbox` (installed manually above; Chocolatey manages future updates) |
| Password management | `bitwarden`                                                             |
| Package management  | `nuget.commandline`                                                     |
| Diff / merge        | `winmerge` or similar                                                   |
| Database tools      | `ssms` (SQL Server Management Studio)                                   |
| Runtimes            | `dotnet-sdk` (.NET 8+), `nodejs` (if needed)                            |

Once the approved list exists as a `packages.config` file in `ATAP.IAC`:

```powershell
choco install .\packages.config --yes
```

Or install individually as needed during setup. After installing VS Code, open a new
terminal so the `code` command is on `PATH`, then verify with `code --version`. (The `nbgv`
.NET global tool is installed machine-wide separately in Step 4.4.)

### 2.3 Install Python (for Manim or Copilot code execution)

Install Python only if the workstation will run Manim (see the optional Manim section near
the end of this document) or Copilot code execution.

> **⚠ Python version constraint — use 3.11, not 3.14 (as of 2026-04-04)**
>
> Python 3.14 is too new for several Manim Community dependencies. Pre-built binary wheels
> for `pycairo`, `manimpango`, and `scipy` are not yet published for `cp314` on Windows, so
> `pip` falls back to building from source (requires a full C/C++ toolchain and often
> fails). This was observed during setup of `utat022`. Use **Python 3.11** until the Manim
> dependency ecosystem catches up.

```powershell
# Install Python 3.11 explicitly — adds python.exe and pip to PATH automatically
choco install python311 --yes
```

Chocolatey installs Python to `C:\Python311\` and adds both the install root and its
`Scripts\` subfolder to the **system** `PATH`. Verify:

```powershell
# Reload PATH in the current shell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

python --version     # Expected: Python 3.11.x
pip --version        # Expected: pip 24.x from C:\Python311\...
```

> If multiple versions are installed, the `py.exe` launcher (`C:\Windows\py.exe`) lets you
> target one explicitly: `py -3.11`, `py -3.14`. Confirm which version the bare `python`
> command resolves to after the PATH reload and adjust if needed.

**Disable the Windows Store Python stub.** Windows 11 ships a `python.exe` stub in
`%LOCALAPPDATA%\Microsoft\WindowsApps\` that redirects to the Microsoft Store and can
silently shadow the real installation. Disable it via **Settings → Apps → Advanced app
settings → App execution aliases** (toggle off `python.exe` and `python3.exe`), or:

```powershell
$aliasPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
Remove-Item "$aliasPath\python.exe"  -ErrorAction SilentlyContinue
Remove-Item "$aliasPath\python3.exe" -ErrorAction SilentlyContinue
```

**VS Code Python extensions:**

```powershell
choco install vscode-python --yes
choco install vscode-pylance --yes
```

| Chocolatey Package | Extension ID        | Purpose                                                        |
| ------------------ | ------------------- | -------------------------------------------------------------- |
| `vscode-python`    | `ms-python.python`  | Core Python language support: IntelliSense, linting, debugging |
| `vscode-pylance`   | `ms-python.pylance` | Fast type-checking language server                             |

After installing, choose `C:\Python311\python.exe` when VS Code prompts to select an
interpreter.

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

Also confirm the shell-folder mapping script is present on disk before running it below:

```text
C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.IAC.Ansible.Powershell\public\MapUserShellFoldersToDropBox.ps1
```

### 3.1 Map user shell folders to Dropbox

Once sync is complete, redirect the Windows shell folders (Documents, Downloads, Favorites,
Music, Photos, Videos) to Dropbox-backed locations so all user data is backed up and
consistent across machines. Run **as Administrator**:

```powershell
& 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.IAC.Ansible.Powershell\public\MapUserShellFoldersToDropBox.ps1'
```

The script sets the following registry paths under
`HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`:

| Shell Folder | Registry Key                             | Target Path                      |
| ------------ | ---------------------------------------- | -------------------------------- |
| Documents    | `Personal`                               | `C:\Dropbox\whertzing\`          |
| Favorites    | `Favorites`                              | `C:\Dropbox\whertzing Favorites` |
| Music        | `My Music`                               | `C:\Dropbox\Music`               |
| Photos       | `My Pictures`                            | `C:\Dropbox\Photos`              |
| Videos       | `My Video`                               | `C:\Dropbox\Videos`              |
| Downloads    | `{374DE290-123F-4565-9164-39C4925E467B}` | `C:\Dropbox\Downloads`           |

The script first displays the current vs. desired value for each folder and only applies
changes where a difference is detected. After running it, **sign out and sign back in** (or
reboot) so Windows Explorer picks up the changed shell-folder locations.

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

### 4.6 Install the Bitwarden Secrets Manager CLI (`bws`) machine-wide

`Get-SecretATAP` with the `BitwardenSecretsManager` provider shells out to the `bws`
CLI to read runtime secrets (Step 9.4.10). The Inedo products run as `SvcBuildmaster`
and `SvcProGet`, and those service / scheduled-task processes start with `-NoProfile`,
so `bws` must resolve from the **machine** `PATH` — not from a per-user `winget` install
under one developer's AppData, and not only from the ATAP profile's injected PATH (which
`-NoProfile` sessions and Windows services never load).

This is the same machine-wide-resolution requirement Step 4.4 documents for `nbgv`.
Install `bws.exe` into a shared `Program Files` location and add that folder to the
system `PATH` so every local account — `SvcBuildmaster`, `SvcProGet`, and every
interactive developer — resolves the same binary.

The `bws` CLI ships from the `bitwarden/sdk-sm` repository (it is **not** the same
package as the `bw` Password-Manager CLI, and there is no reliable machine-scope winget
package for it). Releases are tagged `bws-v<version>`.

Run from an **elevated** PowerShell 7 session.

```powershell
# Pin the bws release. Bump these lines to upgrade.
$bwsVersion = '2.1.0'
$bwsAsset   = "bws-x86_64-pc-windows-msvc-$bwsVersion.zip"
$bwsUrl     = "https://github.com/bitwarden/sdk-sm/releases/download/bws-v$bwsVersion/$bwsAsset"

$installDir = 'C:\Program Files\Bitwarden\bws'
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

$zipPath = Join-Path $env:TEMP $bwsAsset
Invoke-WebRequest -Uri $bwsUrl -OutFile $zipPath

# The zip contains bws.exe at its root; extract it into the machine-wide install dir.
Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath -ErrorAction SilentlyContinue

# Confirm the binary landed.
& (Join-Path $installDir 'bws.exe') --version
```

Add the install dir to the **Machine** `PATH` (idempotent — only appends if missing). A
machine-scope `PATH` entry is inherited by Windows services and by scheduled tasks
launched with `-NoProfile`, which is why it is used here instead of the profile PATH
injection used for `nbgv`:

```powershell
$installDir = 'C:\Program Files\Bitwarden\bws'
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$entries = $machinePath -split ';' | Where-Object { $_ }
if ($entries -notcontains $installDir) {
  $newPath = ($entries + $installDir) -join ';'
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
  Write-Host "Added $installDir to Machine PATH."
} else {
  Write-Host "$installDir already on Machine PATH."
}
```

A Machine `PATH` change is composed into a process's environment only at process
creation, and a child process inherits its **parent's** in-memory environment block —
not a freshly rebuilt one. The elevated session you just ran the install in still holds
the old `PATH`, and any `pwsh` you launch _from it_ (including the verification lines
below) inherits that stale block and will report `bws` as missing. **Open a brand-new
`pwsh` window from the Start menu / Explorer** (not from the install session), then
verify that `bws` resolves both with and without a profile:

```powershell
pwsh -NoProfile -Command "(Get-Command bws -ErrorAction SilentlyContinue).Source"   # machine PATH only
pwsh -Command            "(Get-Command bws -ErrorAction SilentlyContinue).Source"   # machine PATH + profile
bws --version
```

If you must verify without opening a new window, refresh the current session's `PATH`
from the registry first (this is what a fresh window does automatically):

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User')
(Get-Command bws).Source
```

Windows **services** and scheduled tasks likewise inherit the new `PATH` only after a
service restart (or a reboot).

Both must print a path under `C:\Program Files\Bitwarden\bws` and the version. The
`-NoProfile` line is the important one: it proves the binary is visible to the
`-NoProfile` service-account contexts described in Step 9.4.10, independent of any
PowerShell profile.

A **Machine** `PATH` entry is account-independent, so the `-NoProfile` check above
already proves the binary is resolvable for every account that starts after the change —
including `SvcBuildmaster` and `SvcProGet` once their services are restarted. The
following is an **optional** belt-and-suspenders confirmation that opens a one-shot
`-NoProfile` shell _as_ the service account and prints the resolved path.

This check is only possible after the service accounts exist (Step 5); if you are
running Step 4.6 in document order, the accounts do not exist yet — skip this and rely
on the `-NoProfile` check above, or return here after Step 5.

Prompt for the service account's Windows password with `Get-Credential` rather than
fetching it through `Get-SecretATAP`. The verification's only goal is to prove `bws` is
on the service account's `PATH`; routing it through the Password-Manager `bw` CLI would
couple this check to an unrelated dependency (a live `BW_SESSION` and `bw`'s network/TLS
state) that can fail for reasons having nothing to do with `bws`.

```powershell
$svc = 'SvcBuildmaster'   # repeat with 'SvcProGet'
$cred = Get-Credential -UserName "$env:COMPUTERNAME\$svc" `
  -Message "Windows password for $svc (PATH check only)"

# Write the captured output somewhere the service account can also reach. Do NOT use
# your own $env:TEMP (under your profile) — the spawned service-account process cannot
# use another user's profile Temp as its working directory and emits a harmless
# "drive root ... does not exist" warning. C:\Windows\Temp is readable by all accounts.
$out = "C:\Windows\Temp\bws-pathcheck-$svc.txt"

# Keep the Start-Process call on one physical line. A backtick continuation here breaks
# when the block is pasted into an interactive console line-by-line (the -ArgumentList
# arguments end up on a separate, separately-evaluated line). -WorkingDirectory points the
# child at a path the service account can access.
$argList = @('-NoProfile', '-Command', '(Get-Command bws -ErrorAction SilentlyContinue).Source; bws --version')
Start-Process pwsh -Credential $cred -Wait -WorkingDirectory 'C:\Windows\Temp' -RedirectStandardOutput $out -ArgumentList $argList

Get-Content $out
Remove-Item $out -ErrorAction SilentlyContinue
```

Expected — the resolved path under `C:\Program Files\Bitwarden\bws` and the `bws`
version, printed from the service account's own `-NoProfile` context.

> **Upgrading.** Bump `$bwsVersion` and re-run the download/extract block; the PATH and
> verification steps are idempotent and do not need to change. Overwriting `bws.exe` in
> place is safe because every account shares the one binary by path rather than copying
> it per profile.

> **Why not `winget install Bitwarden.SecretsManager`?** A `winget` per-user install
> places `bws` under the installing developer's profile, where service accounts cannot
> see it. If a verified machine-scope package becomes available you may use it, but you
> must still pass the `-NoProfile` and service-account resolution checks above.

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
    SecretName  = "SQLServerSrvAcct.$($env:COMPUTERNAME.ToLowerInvariant())"
    AccountName = 'SQLServerSrvAcct'
    FullName    = 'SQL Server Service Identity'
    Description = 'Local service account for SQL Server Database Engine and Agent'
  },
  @{
    SecretName  = "SvcProGet.$($env:COMPUTERNAME.ToLowerInvariant())"
    AccountName = 'SvcProGet'
    FullName    = 'ProGet Service Identity'
    Description = 'Local service account for the Inedo ProGet service'
  },
  @{
    SecretName  = "SvcBuildmaster.$($env:COMPUTERNAME.ToLowerInvariant())"
    AccountName = 'SvcBuildmaster'
    FullName    = 'BuildMaster Service Identity'
    Description = 'Local service account for Inedo BuildMaster service'
  }
)

foreach ($entry in $serviceAccounts) {
  New-LocalServiceAccount `
    -AccountName $entry.AccountName `
    -FullName $entry.FullName `
    -Description $entry.Description `
    -SecretNameServiceAccountLoginCredentials $entry.SecretName `
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

### 9.3.1 Grant SvcProGet full control over the ProGet package store

When ProGet runs as the custom local service account `SvcProGet` (rather than the default
`NetworkService` identity), the Inedo Hub installer does **not** automatically grant that
account write access to `C:\ProgramData\ProGet\Packages\`. ProGet UI operations that delete
or write package files (e.g., bulk feed delete) then return HTTP 500 with:

```text
Access to the path 'C:\ProgramData\ProGet\Packages\...' is denied.
```

Grant `SvcProGet` Full Control (object-inherit + container-inherit) over the package
directory. **Run in an elevated shell:**

```powershell
icacls "C:\ProgramData\ProGet\Packages" /grant "SvcProGet:(OI)(CI)F" /T
```

> **Automation:** `Invoke-ProvisionInedoServiceAccounts.ps1` performs this step
> automatically after creating the `SvcProGet` account. Run it instead of the manual
> command when provisioning a new machine.

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
> | Identity                                | Bitwarden identity           | Provisioning path                           |
> | --------------------------------------- | ---------------------------- | ------------------------------------------- |
> | Windows interactive user `DeveloperTwo` | PM User 2                    | `bw` login/unlock — **9.4.1–9.4.9 pattern** |
> | `SvcBuildmaster` (service)              | BWS machine `SvcBuildMaster` | `bws` access token — **§9.4.10**            |
> | `SvcProGet` (service)                   | BWS machine `SvcInfraShared` | `bws` access token — **§9.4.10**            |
> | AceCommander service / IIS              | BWS machine `AceCommander`   | `bws` access token — **§9.4.10**            |

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

#### 9.4.10 Provision Secrets Manager (`bws`) access tokens for Windows accounts

Under the current architecture, runtime/project secrets live in **Bitwarden Secrets
Manager** and are read with a BWS **access token** - there is no `bw login`, no `unlock`,
no `BW_SESSION`, and no startup/refresh task. The DPAPI-protected access token is the
entire runtime credential.

This applies to both service accounts and interactive users. Service accounts such as
`SvcBuildmaster` use project-scoped machine-account tokens. Interactive users can be
given their own project-scoped BWS token so they can call the same `Get-SecretATAP`
Secrets Manager path without duplicating project secrets into Password Manager. User-only
secrets remain in Password Manager and continue to use the login-time `BW_SESSION`
pattern.

Preconditions:

1. The Bitwarden org, projects, machine accounts, and **access tokens** exist
   ([NewOrganizationSetup.md](NewOrganizationSetup.md) Phase 2).
2. Any service accounts being provisioned exist on this host.
3. You are elevated for the credential-folder ACL step.
4. You have the approved BWS access token authority for the intended project; do not record or persist its value.

Host mapping:

| Windows identity | ReadOnly access-token authority | Intended project | Required DPAPI token file | ReadWrite status |
| ---------------- | ------------------------------- | ---------------- | ------------------------- | ---------------- |
| `SvcBuildMaster` | `CommonCIForBitwardenReadOnly` | `CI-Shared` | `…\SvcBuildMaster\<HOST>_SvcBuildMaster_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` | Not approved by default |
| `SvcProGet` | `CommonCIForBitwardenReadOnly` | `CI-Shared` | `…\SvcProGet\<HOST>_SvcProGet_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` | Not approved by default |
| `SvcSeq` | `CommonCIForBitwardenReadOnly` | `CI-Shared` | `…\SvcSeq\<HOST>_SvcSeq_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` | Not approved by default |
| `SvcSQLServer` | `CommonCIForBitwardenReadOnly` | `CI-Shared` | `…\SvcSQLServer\<HOST>_SvcSQLServer_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` | Not approved by default |
| `SvcParityAudit` | `CommonCIForBitwardenReadOnly` | `CI-Shared` | `…\SvcParityAudit\<HOST>_SvcParityAudit_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` | Not approved by default |

Interactive-user mapping:

| Windows interactive user | BWS access-token scope | Required DPAPI token file | Optional DPAPI token file |
| ------------------------ | ---------------------- | ------------------------- | ------------------------- |
| `whertzing` | `CommonCIForBitwardenReadOnly` for `CI-Shared` | `…\whertzing\<HOST>_whertzing_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml` | Not approved by default |

##### 9.4.10.1 Confirm the `bws` CLI is installed machine-wide

`bws` is installed machine-wide in **Step 4.6**, so `SvcBuildmaster`, `SvcProGet`, and
every interactive account resolve the same binary from the system `PATH`. Confirm it is
visible from a `-NoProfile` shell (the context the service accounts actually run in) and
continue:

```powershell
pwsh -NoProfile -Command "(Get-Command bws -ErrorAction SilentlyContinue).Source"
bws --version
```

If `bws` does not resolve, complete Step 4.6 (machine-wide `bws` install) before
continuing.

##### 9.4.10.2 Create and ACL the BWS credential directory

Create the protected directory before writing the DPAPI token file. This can be run from
an elevated administrative shell. For the current interactive user:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
Initialize-BWSCredentialDirectory
```

For a service account, pass the account name:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
Initialize-BWSCredentialDirectory -AccountName '.\SvcBuildmaster'
```

The helper creates `C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>` and grants
FullControl only to the owning account, `SYSTEM`, and local `Administrators`.

##### 9.4.10.3 DPAPI-store each access token (run AS the owning account)

DPAPI binds to the running user, so the token file must be written by a process running as
the account that will later read it. For an interactive user, run the command from that
user's own shell. For a service account, open a shell as that account and store its token.
The helper cmdlet `Initialize-BWSAccessToken` encapsulates the DPAPI write:

```powershell
$token = Read-Host 'BWS access token for CommonCIForBitwardenReadOnly' -AsSecureString
Initialize-BWSAccessToken -TokenPurpose ReadOnly -AccessToken $token
```

Only trusted maintainer or provisioning identities should also store:

```powershell
$token = Read-Host 'BWS access token for CommonCIForBitwardenReadWrite' -AsSecureString
Initialize-BWSAccessToken -TokenPurpose ReadWrite -AccessToken $token
```

The token is stored in a PSCredential whose UserName is the literal
`BWS_ACCESS_TOKEN`; the password is the BWS access token. The canonical helper names are
`Initialize-BWSAccessToken` and `Get-BWSAccessToken`. The older service-account names
remain module aliases for compatibility. DPAPI binds these files to the current Windows
identity and host, so they cannot be copied between users or hosts and still decrypt.

##### 9.4.10.4 Validate (as the owning account)

Decrypt the token in memory and confirm the BWS token can read only its intended projects:

```powershell
$cred = Get-BWSAccessToken
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
try {
  bws secret list --output json | ConvertFrom-Json | Select-Object key, projectId
} finally {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

Expected — the listed secret `key`s match the projects granted to that BWS token.
Runtime secret reads go through `Get-SecretATAP` with the
`BitwardenSecretsManager` provider (set `SecretStoreType='BitwardenSecretsManager'` in
`$global:settings`), which resolves the token from this DPAPI file.

> **Rotation:** regenerating the BWS access token in the web vault invalidates the
> old one; re-run 9.4.10.3 on every host/account that uses that token.

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

### 9.8 Register the ProGet `powershellget-stable` feed and install ATAP modules

ProGet is now running with the `powershellget-stable` NuGetV2 feed provisioned. This
step registers that feed as a trusted PSRepository **before** PSGallery in the
repository priority list, then installs `ATAP.Utilities.PowerShell` and
`ATAP.Utilities.BuildTooling.PowerShell` globally (`-Scope AllUsers`).

> **Why ordering matters.** `Get-PSRepository` returns repositories in registration
> order and `Find-Module` (without `-Repository`) searches them in that order. If
> `PSGallery` appears before `powershellget-stable`, PowerShell will resolve the public
> registry first and may pick up a stale or wrong version. The step below ensures the
> internal feed is consulted first by re-registering PSGallery after `powershellget-stable`
> when necessary, or by always passing `-Repository powershellget-stable` explicitly.

Run from an **elevated** PowerShell 7 session. The script is already in the sprint
worktree.

```powershell
# Dot-source the function and invoke it
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items\src\_AdminRequiresHoldingPen\ATAP.Utilities.PowerShell\public\Install-ATAPModulesFromProGet.ps1'

Install-ATAPModulesFromProGet
```

Expected output (module base paths confirm `-Scope AllUsers`):

```text
[HH:mm:ss][Install-ATAPModulesFromProGet] Feed URI: http://localhost:50000/nuget/powershellget-stable/
[HH:mm:ss][Install-ATAPModulesFromProGet] Feed 'powershellget-stable' is reachable at http://localhost:50000/nuget/powershellget-stable/
[HH:mm:ss][Install-ATAPModulesFromProGet] Installed 'ATAP.Utilities.PowerShell' v0.1.0 to 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.Powershell\0.1.0'
[HH:mm:ss][Install-ATAPModulesFromProGet] Installed 'ATAP.Utilities.BuildTooling.PowerShell' v0.1.0 to 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.PowerShell\0.1.0'

ModuleName                             VersionInstalled InstallResult
----------                             ---------------- -------------
ATAP.Utilities.PowerShell              0.1.0            Installed
ATAP.Utilities.BuildTooling.PowerShell 0.1.0            Installed
```

Verify the `ModuleBase` column shows `C:\Program Files\PowerShell\Modules\...`, not a
per-user path. If it shows a per-user path, the shell was not elevated — uninstall the
per-user copy and re-run elevated.

If `powershellget-stable` appears after `PSGallery` in the repository list, the script
logs a warning but still succeeds because it passes `-Repository powershellget-stable`
explicitly. To fix the ordering permanently, unregister and re-register the repositories
so the internal feed is first:

```powershell
# Fix repository ordering: internal feed first, PSGallery second.
# Run elevated.
Unregister-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
Unregister-PSRepository -Name powershellget-stable -ErrorAction SilentlyContinue

Register-PSRepository `
  -Name              'powershellget-stable' `
  -SourceLocation    'http://localhost:50000/nuget/powershellget-stable/' `
  -PublishLocation   'http://localhost:50000/nuget/powershellget-stable/' `
  -InstallationPolicy Trusted

Register-PSRepository `
  -Default `
  -InstallationPolicy Trusted

Get-PSRepository | Select-Object Name, SourceLocation, InstallationPolicy
```

After re-ordering, `Get-PSRepository` should list `powershellget-stable` first.

### 9.9 Register all ProGet PowerShell feeds for the current user

Step 9.8 registers only the `powershellget-stable` feed needed to install the ATAP modules.
Registering the **full** set of tiered feeds is a **one-time per Windows user profile per
machine** consumer setup step. Re-run it only when:

- setting up a new workstation or a new Windows user profile;
- changing the ProGet host, port, or feed names;
- repairing a profile where PowerShellGet/PSResourceGet repository state was reset.

.NET/NuGet feed sources are normally checked into repo-level `NuGet.Config` files, but
PowerShell module installation keeps repository registrations in the current user's
package-provider state. Register both PowerShell repository stores so either
`Install-Module` (PowerShellGet v2) or `Install-PSResource`
(Microsoft.PowerShell.PSResourceGet) can consume the same ProGet feeds.

Run in a normal PowerShell 7 session for the user who will install modules:

```powershell
$feeds = @(
  @{ Name = 'powershellget-experimental'; Uri = 'http://localhost:50000/nuget/powershellget-experimental/' },
  @{ Name = 'powershellget-development';  Uri = 'http://localhost:50000/nuget/powershellget-development/' },
  @{ Name = 'powershellget-integration';  Uri = 'http://localhost:50000/nuget/powershellget-integration/' },
  @{ Name = 'powershellget-qa';           Uri = 'http://localhost:50000/nuget/powershellget-qa/' },
  @{ Name = 'powershellget-stable';       Uri = 'http://localhost:50000/nuget/powershellget-stable/' }
)

foreach ($feed in $feeds) {
  $repo = Get-PSRepository -Name $feed.Name -ErrorAction SilentlyContinue
  if ($null -eq $repo) {
    Register-PSRepository `
      -Name $feed.Name `
      -SourceLocation $feed.Uri `
      -PublishLocation $feed.Uri `
      -InstallationPolicy Trusted
  }
  else {
    Set-PSRepository `
      -Name $feed.Name `
      -SourceLocation $feed.Uri `
      -PublishLocation $feed.Uri `
      -InstallationPolicy Trusted
  }

  $resourceUri = "$($feed.Uri.TrimEnd('/'))/v2"
  $resourceRepo = Get-PSResourceRepository -Name $feed.Name -ErrorAction SilentlyContinue
  if ($null -eq $resourceRepo) {
    Register-PSResourceRepository -Name $feed.Name -Uri $resourceUri -Trusted
  }
  else {
    Set-PSResourceRepository -Name $feed.Name -Uri $resourceUri -Trusted
  }
}
```

Verify:

```powershell
Get-PSRepository |
  Where-Object Name -like 'powershellget-*' |
  Sort-Object Name |
  Select-Object Name, SourceLocation, InstallationPolicy

Get-PSResourceRepository |
  Where-Object Name -like 'powershellget-*' |
  Sort-Object Name |
  Select-Object Name, Uri, Trusted
```

Expected PowerShell feeds: `powershellget-experimental`, `powershellget-development`,
`powershellget-integration`, `powershellget-qa`, `powershellget-stable`.

The matching NuGet package feeds for .NET restore (`nuget-experimental`,
`nuget-development`, `nuget-integration`, `nuget-qa`, `nuget-stable`) should already appear
in the repo `NuGet.Config` files. Confirm from a repo root with:

```powershell
dotnet nuget list source
```

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
3. `BW_SESSION`, .ADMIN.API.KEY`, and `BUILDMASTER.ADMIN.API.KEY` are populated
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

## (Optional) Manim Community Animation Tooling

Manim Community is a Python animation engine used to create precise mathematical and
technical animations programmatically. Install it only on workstations that render Manim
scenes. It depends on Python (Step 2.3), ffmpeg, and optionally MiKTeX for LaTeX-rendered
equations.

### Install ffmpeg

```powershell
choco install ffmpeg --yes
ffmpeg -version            # Expected: ffmpeg version N-xxxxx ...
```

### Install MiKTeX (optional — for LaTeX equations)

MiKTeX provides the LaTeX distribution Manim uses for `MathTex`/`Tex` objects. Skip if you
do not need equation rendering.

```powershell
choco install miktex --yes
```

After installation, open the **MiKTeX Console** and run **Check for updates → Update now**.
Manim downloads additional LaTeX packages on first use.

### Create the project folder and virtual environment

The Manim work lives **inside the ATAP.Utilities repository** rather than in a separate repo,
keeping Python scene scripts, C# host code, and shared ATAP.Utilities libraries under one
version-control root.

```text
ATAP.Utilities/
├── ManimVideoGenerator/          ← Python project root (its own .gitignore)
│   ├── .gitignore                  ← excludes .venv/, __pycache__/ (NOT media/)
│   ├── .venv/                      ← Python virtual environment (gitignored)
│   ├── scenes/                     ← Manim scene .py scripts
│   ├── media/                      ← rendered MP4/GIF output (tracked in git)
│   └── requirements.txt            ← pinned Python dependencies
└── src/
    └── ATAP.Utilities.ManimVideoGenerator/         ← C# facade (.csproj)
        ├── ATAP.Utilities.ManimVideoGenerator.Interfaces/
        ├── ATAP.Utilities.ManimVideoGenerator.StringConstants/
        ├── ATAP.Utilities.ManimVideoGenerator.DefaultSettings/
        └── ATAP.Utilities.ManimVideoGenerator.Models/
```

Rendered output under `media/` is **tracked in git** so it merges into main when the sprint
PR lands and can be consumed by other projects over time.

```powershell
Set-Location C:\Dropbox\whertzing\GitHub\ATAP.Utilities
New-Item -ItemType Directory -Path ManimVideoGenerator
Set-Location ManimVideoGenerator
python -m venv .venv
.\.venv\Scripts\Activate
```

The shell prompt shows `(.venv)` when the environment is active. Create
`ManimVideoGenerator\.gitignore` with at minimum:

```gitignore
# Python virtual environment
.venv/

# Python caches
__pycache__/
*.pyc
*.pyo

# NOTE: media/ is intentionally NOT ignored — rendered output is tracked in git
#       so it can be merged into main and reused by other projects.
```

> **Virtual environment path for C# `Process.Start()`:**
> `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ManimVideoGenerator\.venv\Scripts\manim.exe`
> — passed as `ProcessStartInfo.FileName`, or read from a configuration value bound to
> `IOptions<ManimVideoGeneratorOptions>`.

You must **activate the virtual environment** each time you open a new terminal to work on
Manim scripts directly. VS Code activates it automatically (see the Manim Sideview
subsection below).

### Sprint worktree and venv lifecycle

Git worktrees give every sprint branch its own directory. There are two sprint types:

| Sprint type       | Examples                                                                 | Venv action needed?                         | `MANIM_EXE_PATH` changes?                        |
| ----------------- | ------------------------------------------------------------------------ | ------------------------------------------- | ------------------------------------------------ |
| **Scene-only**    | Write or edit `.py` scene files, add rendering output to `media/`        | None — reuse the main worktree venv         | **No** — keep pointing at the main worktree venv |
| **Manim-upgrade** | Install a new Manim version, change `requirements.txt`, modify C# facade | Create a new `.venv` in the sprint worktree | **Yes** — point at the sprint worktree venv      |

For the common scene-only case, the `.venv` in the main worktree is fully reusable; only the
sprint worktree's `scenes/` folder changes, tracked normally by git. Because `.venv/` is
gitignored, a newly-created sprint worktree contains no virtual environment — irrelevant for
scene-only sprints. Only Manim-upgrade sprints require a fresh venv in the sprint worktree.

| Context         | Root path                                                                  |
| --------------- | -------------------------------------------------------------------------- |
| Main worktree   | `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\`                              |
| Sprint worktree | `C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-{N}-Sprint-NNN-work-items\` |

**Items holding an absolute path to `manim.exe`/`python.exe`** that must track the active
worktree (updated when a Manim-affecting sprint starts, reverted when it ends):

| Item                                                       | Storage location                                               | Scene-only sprint                             | Manim-upgrade sprint                |
| ---------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------- | ----------------------------------- |
| `manim.exe` path in `IOptions<ManimVideoGeneratorOptions>` | `DefaultSettings` config override or `MANIM_EXE_PATH` env var  | **No change** — reuse main worktree venv path | Update to sprint worktree venv path |
| VS Code **Manim Sideview: Default Manim Path**             | VS Code user settings (or workspace override)                  | **No change**                                 | Update to sprint worktree venv path |
| VS Code **Python: Select Interpreter**                     | Workspace settings or command palette selection                | **No change**                                 | Update to sprint worktree venv      |
| `scenes/` content (`.py` files)                            | Tracked in git on the sprint branch                            | Normal git workflow                           | Normal git workflow                 |
| `requirements.txt`                                         | Tracked in git on the sprint branch                            | Normal git workflow                           | Update, then `pip install -r requirements.txt` |
| `media/` rendered output                                   | **Tracked in git** on the sprint branch                        | Committed and merged into main with the PR    | Committed and merged into main with the PR |

**Recommended pattern — `MANIM_EXE_PATH` environment variable.** For scene-only sprints this
variable never changes. For Manim-upgrade sprints, storing the path in a **User-scope**
environment variable means only that one variable needs updating — no source files are
touched. The C# binding reads it at startup:

```csharp
options.ManimExecutablePath =
    configuration["ManimVideoGenerator:ManimExecutablePath"]
    ?? Environment.GetEnvironmentVariable("MANIM_EXE_PATH")
    ?? @"C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ManimVideoGenerator\.venv\Scripts\manim.exe";
```

**Sprint-start agent steps (Manim-affecting sprints only):**

```powershell
$sprintWorktreeRoot = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-{N}-Sprint-NNN-work-items'
$venvManimExe = "$sprintWorktreeRoot\ManimVideoGenerator\.venv\Scripts\manim.exe"

New-Item -ItemType Directory -Path "$sprintWorktreeRoot\ManimVideoGenerator" -Force
Set-Location "$sprintWorktreeRoot\ManimVideoGenerator"
python -m venv .venv
.\.venv\Scripts\Activate
pip install manim

# Point MANIM_EXE_PATH at the sprint worktree venv (User scope — survives shell restart)
[System.Environment]::SetEnvironmentVariable('MANIM_EXE_PATH', $venvManimExe, 'User')

# Update the VS Code workspace Python interpreter as well (see UserSettings.jsonc below).
```

> **Symlink alternative:** the sprint-start agent can instead create an NTFS junction
> `ManimVideoGenerator-active` in a fixed location that always points to the active
> worktree's `ManimVideoGenerator\` folder; configuration then references the fixed junction
> path and only the junction target changes.

**Sprint-end agent steps (after PR merge):**

- **Scene-only sprint:** No venv action. Ensure `media/` rendered output is staged and
  committed before the PR merges — it then lands in main automatically.
- **Manim-upgrade sprint only:** revert `MANIM_EXE_PATH` to the main-branch venv; the sprint
  worktree's gitignored `.venv\` is deleted with the worktree (no git cleanup).

```powershell
[System.Environment]::SetEnvironmentVariable(
    'MANIM_EXE_PATH',
    'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ManimVideoGenerator\.venv\Scripts\manim.exe',
    'User')
```

### Install Manim

With the virtual environment active:

```powershell
pip install manim                  # 2–5 minutes on first install
manim --version                    # Expected: Manim Community v0.19.x
manim checkhealth                  # cairo / ffmpeg / latex / manimpango should PASS
```

If LaTeX reports FAIL and you did not install MiKTeX, that is expected and acceptable as
long as you do not use `MathTex` or `Tex` objects.

### VS Code extension — Manim Sideview

> **Note:** `Rickaym.manim-sideview` is not available as a Chocolatey package (confirmed
> 2026-04-04). Prefer installing from the Extensions panel (`Ctrl+Shift+X`) → search
> `Manim Sideview` → Install, because running `code --install-extension` while VS Code is
> open launches additional GUI windows. The CLI command is preserved for automation:

```powershell
code --install-extension Rickaym.manim-sideview
```

Then configure the extension and interpreter:

1. **Settings** (`Ctrl+,`) → search `manim sideview` → set **Manim Sideview: Default Manim
   Path** to
   `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ManimVideoGenerator\.venv\Scripts\manim.exe`.
2. Command Palette (`Ctrl+Shift+P`) → **Python: Select Interpreter** → **Enter interpreter
   path** →
   `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ManimVideoGenerator\.venv\Scripts\python.exe`.

**Sprint-branch adjustments for `UserSettings.jsonc`.** On a Manim-affecting sprint branch,
both keys must point to the **sprint worktree venv**. These settings live in
`SharedVSCode/UserSettings.jsonc` (the canonical source — there is no per-repo
`.vscode/settings.json`).

| Setting key                       | Purpose                                                |
| --------------------------------- | ------------------------------------------------------ |
| `manim-sideview.defaultManimPath` | Path to the `manim.exe` the Sideview extension invokes |
| `python.defaultInterpreterPath`   | Python interpreter VS Code uses for the workspace      |

Sprint-start — set to the sprint worktree venv (example sprint `94-sprint-0004-work-items`):

```jsonc
// In SharedVSCode/UserSettings.jsonc
"manim-sideview.defaultManimPath": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities-wt-94-sprint-0004-work-items\\ManimVideoGenerator\\.venv\\Scripts\\manim.exe",
"python.defaultInterpreterPath": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities-wt-94-sprint-0004-work-items\\ManimVideoGenerator\\.venv\\Scripts\\python.exe",
```

Sprint-end — revert to the main-branch venv after the PR merges and the worktree is removed:

```jsonc
// In SharedVSCode/UserSettings.jsonc
"manim-sideview.defaultManimPath": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities\\ManimVideoGenerator\\.venv\\Scripts\\manim.exe",
"python.defaultInterpreterPath": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities\\ManimVideoGenerator\\.venv\\Scripts\\python.exe",
```

> **Agent reminder:** these two keys must be in the sprint-start and sprint-end checklists
> for any sprint that creates or upgrades a Manim venv. Scene-only sprints that reuse the
> main-branch venv do **not** need these changes.

### Render a verification scene

```python
# test_manim.py
from manim import *

class HelloManim(Scene):
    def construct(self):
        text = Text("Hello, Manim!")
        self.play(Write(text))
        self.wait(1)
```

```powershell
manim -pql test_manim.py HelloManim
```

`-p` opens the video after rendering; `-q l` renders at low quality (fast). Output is saved
to `media\videos\test_manim\480p15\HelloManim.mp4` relative to the project folder. If MiKTeX
was installed, optionally verify equation rendering with a `MathTex(r"e^{i\pi} + 1 = 0")`
scene — MiKTeX downloads required LaTeX packages automatically on first run.

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

## (Optional) Headroom — AI Agent Context Compression

Headroom (`headroom-ai`, Apache-2.0, [chopratejas/headroom](https://github.com/chopratejas/headroom))
is a context-optimization layer for LLM agents. It compresses large tool outputs, logs,
search results, and traces so coding agents (Claude Code, Codex, Copilot) consume fewer
context tokens. It is delivered three ways, all of which this section installs/enables:

1. **MCP server** — exposes on-demand tools `headroom_compress`, `headroom_retrieve`,
   `headroom_stats` to Claude Code and Codex. **This is the primary, recommended mode.**
2. **Proxy** — a local server on port `8787` that transparently compresses provider
   traffic when an agent is launched through it (`headroom wrap claude|codex`).
3. **Library** — the Python compress API the MCP server calls internally.

Install Headroom only on workstations doing heavy agentic development. It is independent of
the SQL/ProGet/BuildMaster pipeline and can be skipped without affecting builds.

> **Compression engine note.** Headroom's semantic compression loads two ML models on first
> use — an `answerdotai/ModernBERT-base` embedding model (via `torch` / `sentence-transformers`)
> and a quantized `kompress-int8.onnx` model (via `onnxruntime`). **On CPU the first
> compression incurs a multi-minute cold model-load**, and steady-state compress latency is
> CPU-bound. A machine with an NVIDIA GPU should follow **Path B** below to run these models
> on the GPU. Choose exactly one path in §H.3.

### H.0 Decision: which path?

| | **Path A — CPU-only** | **Path B — GPU-accelerated** |
| --- | --- | --- |
| **Requires** | Any x64 CPU | NVIDIA GPU (e.g. RTX 3080) + recent driver (CUDA 12.x class) |
| **Packages** | `torch` (cpu build), `onnxruntime` | CUDA `torch` (`+cuXXX`), `onnxruntime-gpu` |
| **First compress** | Multi-minute cold model load | Seconds (after one-time model download) |
| **Steady-state compress** | CPU-bound (slow on large payloads) | GPU-accelerated |
| **Proxy wrap overhead** | ~550ms+/request (observed on CPU) | Lower |
| **Use when** | No NVIDIA GPU present | NVIDIA GPU present — **preferred** |

Verify GPU presence before choosing:

```powershell
# Path B is available only if this prints a GPU. Otherwise use Path A.
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
```

### H.1 Prerequisites (both paths)

These were required to build `headroom-ai[all]` from source on Windows + Python 3.11 (the
package builds native wheels for itself and `hnswlib`):

1. **Python 3.11** — already installed in Step 2.3 at `C:\Python311\` (do **not** use 3.14).
2. **Rust toolchain** — Headroom's native extension bootstraps Rust if absent; install it
   explicitly first to avoid a mid-install cert failure:

   ```powershell
   winget install Rustlang.Rustup --source winget
   # New shell, then verify:
   rustup --version; rustc --version; cargo --version
   ```

3. **Visual Studio Build Tools 2022 with the C++ workload** — provides `link.exe` / `cl.exe`
   needed to compile native wheels:

   ```powershell
   winget install Microsoft.VisualStudio.2022.BuildTools `
     --override "--quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
   ```

### H.2 Create the dedicated virtual environment (both paths)

Headroom is cross-workflow tooling, so it gets its **own reusable venv** — not `pipx`, and
not a project-scoped venv (e.g. the ManimVideoGenerator venv is intentionally left alone).

```powershell
& 'C:\Python311\python.exe' -m venv 'C:\Users\whertzing\.venvs\headroom'
$venvPy = 'C:\Users\whertzing\.venvs\headroom\Scripts\python.exe'

# truststore lets pip use the Windows certificate store (required on this network)
& $venvPy -m pip install --upgrade --use-feature=truststore pip setuptools wheel
```

### H.3 Install Headroom — choose ONE path

The native build needs the Visual C++ environment loaded and two network workarounds. This
helper loads `VsDevCmd.bat`, puts Cargo on `PATH`, and sets the cert workarounds for the
current shell — run it **before** the pip install in either path:

```powershell
$vsdev = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat'
cmd.exe /d /s /c "call `"$vsdev`" -arch=x64 -host_arch=x64 && set" | ForEach-Object {
  if ($_ -match '^(.*?)=(.*)$') { Set-Item -Path ('Env:' + $matches[1]) -Value $matches[2] }
}
$env:PATH = 'C:\Users\whertzing\.cargo\bin;' + $env:PATH
$env:CARGO_HTTP_CHECK_REVOKE = 'false'   # Cargo hits CRYPT_E_NO_REVOCATION_CHECK against crates.io without this
$venvPy = 'C:\Users\whertzing\.venvs\headroom\Scripts\python.exe'
```

#### Path A — CPU-only

```powershell
& $venvPy -m pip install --use-feature=truststore 'headroom-ai[all]'

# Verify
& 'C:\Users\whertzing\.venvs\headroom\Scripts\headroom.exe' --help
& $venvPy -c "import headroom; print('headroom', headroom.__version__)"
```

This installs CPU builds (`torch ...+cpu`, CPU `onnxruntime`). Compression works but is
CPU-bound — expect a multi-minute first-compress while models load.

#### Path B — GPU-accelerated (NVIDIA)

Install Headroom the same way, then **replace** the two CPU ML packages with CUDA builds.
The default `headroom-ai[all]` pulls `torch ...+cpu` and CPU-only `onnxruntime`; neither
touches the GPU until swapped.

```powershell
# 1. Base install (same as Path A)
& $venvPy -m pip install --use-feature=truststore 'headroom-ai[all]'

# 2. Replace CPU torch with a CUDA build (cu124 shown — match your driver's CUDA level).
#    This is a large (~2.5 GB) download.
& $venvPy -m pip uninstall -y torch
& $venvPy -m pip install --use-feature=truststore torch --index-url https://download.pytorch.org/whl/cu124

# 3. Replace CPU onnxruntime with the GPU build so the kompress ONNX model can use CUDA.
& $venvPy -m pip uninstall -y onnxruntime
& $venvPy -m pip install --use-feature=truststore onnxruntime-gpu

# 4. Verify both ML stacks see the GPU
& $venvPy -c "import torch; print('torch', torch.__version__, 'cuda_available', torch.cuda.is_available(), 'device', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"
& $venvPy -c "import onnxruntime as ort; print('ORT', ort.__version__, 'providers', ort.get_available_providers())"
```

Path B is correct when:
- `torch.cuda.is_available()` prints **`True`** and names your GPU, **and**
- `onnxruntime.get_available_providers()` includes **`CUDAExecutionProvider`**.

If either still reports CPU-only, the CUDA `torch` wheel or `onnxruntime-gpu` did not match
the installed CUDA runtime — re-check the driver's CUDA level (`nvidia-smi`) and pick the
matching `cuXXX` wheel index. There is **no Headroom CLI switch for the GPU**; GPU use is
entirely determined by which `torch` / `onnxruntime` packages are installed.

### H.3.1 ⚠ REQUIRED: pin the onnxruntime DLL (both paths) — prevents a fatal hang

**Symptom if skipped:** any Headroom compression hangs indefinitely (observed: a single
compression ran **24.8 minutes without completing**). It looks like a CPU/GPU/model
problem but is not.

**Root cause:** Headroom's Rust extension `headroom._core.detect_content_type` (the magika
content-type detector that the compression pipeline calls *first*, before any model) uses
the Rust `ort` crate, which by default tries to **locate/download its own onnxruntime**.
On this environment that probe blocks forever — the process sits at 0% CPU, 1 thread, no
completed network connection. It hangs on **every** input, even an 11-character string.
(Diagnosed with Python `faulthandler`, which pinpointed `content_router.py` →
`_detect_content` → the Rust call.)

**Fix:** point the `ort` crate at the onnxruntime DLL already installed in the venv via the
`ORT_DYLIB_PATH` environment variable. Set it **User-scope** so every Headroom process
inherits it — the logon proxy task, the MCP servers Claude Code / Codex spawn, and
interactive shells:

```powershell
$ortDll = 'C:\Users\whertzing\.venvs\headroom\Lib\site-packages\onnxruntime\capi\onnxruntime.dll'
[Environment]::SetEnvironmentVariable('ORT_DYLIB_PATH', $ortDll, 'User')
$env:ORT_DYLIB_PATH = $ortDll   # current shell too

# Verify the Rust detector now returns instantly instead of hanging
& 'C:\Users\whertzing\.venvs\headroom\Scripts\python.exe' -c "import time; from headroom._core import detect_content_type as d; t=time.time(); r=d('hello world'); print(f'{time.time()-t:.2f}s', r.content_type)"
# Expected: ~0.1s text   (NOT a hang)
```

After this fix, a 4,162-token build log compresses in **~0.5s cold / ~0s warm** (≈86% token
reduction) with all critical evidence preserved — versus the 24.8-minute hang without it.

> The §H.5 proxy task and §H.6 profile also set `ORT_DYLIB_PATH` explicitly as
> belt-and-suspenders for `-NoProfile` / service contexts. Setting it User-scope here is
> what makes it apply everywhere.

### H.3.2 Disable Headroom telemetry at user scope

Disable Headroom telemetry once at **User** scope so the setting is inherited by normal
PowerShell sessions, `headroom wrap ...` launches, MCP server processes, Claude Code,
Codex, and VS Code sessions started after the setting is applied:

```powershell
[Environment]::SetEnvironmentVariable('HEADROOM_TELEMETRY', 'off', 'User')
$env:HEADROOM_TELEMETRY = 'off'   # current shell too
```

`headroom proxy --no-telemetry` still appears in the scheduled task below as a
belt-and-suspenders guard. The user-scope environment variable is the setting that prevents
`headroom wrap codex` / `headroom wrap claude` from reporting telemetry as enabled when the
wrapper is launched from a fresh shell.

### H.4 Configure the Headroom MCP server (both paths) — primary mode

Register the **absolute venv path** (not a bare `headroom`, which is PATH-dependent and
fails to connect) as a user-scope stdio MCP server in both agents:

```powershell
$hrExe = 'C:\Users\whertzing\.venvs\headroom\Scripts\headroom.exe'

# Claude Code (user scope = all projects)
claude mcp add headroom -s user -- $hrExe mcp serve
claude mcp get headroom      # expect: Status: Connected

# Codex (global config: C:\Users\whertzing\.codex\config.toml)
& 'C:\Users\whertzing\AppData\Local\OpenAI\Codex\bin\<build-id>\codex.exe' mcp add headroom -- $hrExe mcp serve
```

Restart any running Claude Code / Codex session so the new server is picked up, then run
`/mcp` in each to confirm `headroom_compress`, `headroom_retrieve`, `headroom_stats` appear.

### H.5 Proxy autostart at logon (both paths) — optional wrap mode

The proxy backs `headroom wrap claude|codex|copilot` and any editor/app that can be pointed
at an OpenAI-compatible or Anthropic-compatible base URL. Run it as a **hidden,
telemetry-disabled** logon scheduled task that logs to
`C:\Users\whertzing\.headroom\proxy.log`.

Headroom writes nothing to a log file on its own — a bare Scheduled Task would silently
discard its stdout/stderr — so the task must redirect output explicitly. A `cscript`/VBScript
wrapper launches it with **no visible console window** (a plain `cmd`/`pwsh` action flashes
and steals foreground focus). The VBScript writes a one-line batch that sets
`HEADROOM_TELEMETRY=off` and passes `--no-telemetry`:

```powershell
$headroomDir = 'C:\Users\whertzing\.headroom'
New-Item -ItemType Directory -Path $headroomDir -Force | Out-Null
$vbs = Join-Path $headroomDir 'Start-HeadroomProxy.vbs'

@'
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
batchPath = "C:\Users\whertzing\.headroom\headroom_proxy_run.bat"
Set objFile = objFSO.CreateTextFile(batchPath, True)
objFile.WriteLine("@echo off")
objFile.WriteLine("set HEADROOM_TELEMETRY=off")
objFile.WriteLine("C:\Users\whertzing\.venvs\headroom\Scripts\headroom.exe proxy --port 8787 --no-telemetry >> ""C:\Users\whertzing\.headroom\proxy.log"" 2>&1")
objFile.Close()
objShell.Run batchPath, 0, False   ' 0 = hidden window
'@ | Set-Content -LiteralPath $vbs -Encoding ASCII

$action  = New-ScheduledTaskAction -Execute 'cscript.exe' -Argument "`"$vbs`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
  -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -DontStopOnIdleEnd

# Replace any old task with the current hidden/telemetry-off definition.
Unregister-ScheduledTask -TaskName 'Headroom Proxy' -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName 'Headroom Proxy' -Action $action -Trigger $trigger `
  -Settings $settings -RunLevel Highest `
  -Description 'Headroom context compression proxy on port 8787 (hidden, telemetry off)'

# Start now and confirm
Start-ScheduledTask -TaskName 'Headroom Proxy'
Start-Sleep -Seconds 5
if (netstat -ano | Select-String ':8787.*LISTENING') { 'Proxy listening on 8787' }

# Confirm telemetry is disabled
(curl http://127.0.0.1:8787/stats | ConvertFrom-Json).telemetry.enabled   # expect: False
```

> **Why not a direct `headroom.exe proxy` task action?** The proxy runs in the foreground
> until killed; a Scheduled Task whose action is the proxy never reports "completed" and can
> trip the execution-time limit. The VBScript launches it detached and exits immediately, so
> the task completes while the proxy keeps running.
>
> **Scope-creep (SC-0171):** the inline VBScript + task registration above should be
> replaced by a reusable `Register-HeadroomProxyTask.ps1` function in
> `ATAP.Utilities.BuildTooling.PowerShell/public/`; this doc will then call that function.

### H.6 PowerShell profile additions (both paths)

`CurrentUserAllHostsV7CoreProfile.ps1` adds a `headroom` function (so the venv CLI resolves
from any shell) and a startup warning when the proxy is not listening:

```powershell
function headroom { & "C:\Users\whertzing\.venvs\headroom\Scripts\headroom.exe" @args }

if (-not (netstat -ano 2>$null | Select-String ":8787.*LISTENING")) {
  Write-Warning "Headroom proxy is NOT running on port 8787. Start with: headroom proxy --port 8787"
}
```

### H.7 Automatically use Headroom with agent CLIs, apps, and VS Code extensions

Headroom can fully auto-wrap **CLI processes** because the wrapper controls their launch
environment. Desktop apps and VS Code extensions are different: they usually run in their
own host process and often ignore `OPENAI_BASE_URL` / `ANTHROPIC_BASE_URL`. For those,
Headroom works only when the app/extension exposes a custom base URL, BYOK provider, or
compatible local-proxy setting.

Recommended baseline:

```powershell
# Run once per user profile.
$codexBin = "$env:LOCALAPPDATA\OpenAI\Codex\bin"
$headroomBin = "$env:USERPROFILE\.venvs\headroom\Scripts"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$wanted = @($headroomBin, $codexBin)
$entries = @($userPath -split ';' | Where-Object { $_ })
foreach ($entry in $wanted) {
  if ($entries -notcontains $entry) { $userPath = "$entry;$userPath" }
}
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')

[Environment]::SetEnvironmentVariable('HEADROOM_TELEMETRY', 'off', 'User')
[Environment]::SetEnvironmentVariable('OPENAI_BASE_URL', 'http://127.0.0.1:8787/v1', 'User')
[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', 'http://127.0.0.1:8787', 'User')
```

Open a new PowerShell after setting PATH/environment variables, then verify:

```powershell
Get-Command headroom
Get-Command codex
curl http://127.0.0.1:8787/stats
```

CLI launch commands:

```powershell
# Claude Code CLI
headroom wrap claude --no-serena --no-mcp --no-proxy

# Codex CLI
headroom wrap codex --no-serena --no-mcp --no-proxy

# GitHub Copilot CLI
headroom wrap copilot --no-proxy -- --model claude-sonnet-4-20250514
```

Use `--no-proxy` only when the `Headroom Proxy` scheduled task is already listening on
`127.0.0.1:8787`. Use `--no-mcp` for Claude Code / Codex after §H.4 has registered MCP with
the absolute venv path. Use `--no-serena` unless `uvx` has been installed and Serena MCP is
intentionally enabled.

Desktop app / VS Code extension handling:

| Client surface | Headroom approach |
| --- | --- |
| Claude Code CLI | Fully auto-wrap with `headroom wrap claude ...`. |
| Codex CLI | Fully auto-wrap with `headroom wrap codex ...`; ensure `C:\Users\whertzing\AppData\Local\OpenAI\Codex\bin` is on `PATH`. |
| GitHub Copilot CLI | Fully auto-wrap with `headroom wrap copilot ...`; requires the `copilot` CLI on `PATH` and a model/provider supported by Copilot CLI BYOK mode. |
| Codex desktop app | Prefer MCP tools only. Do **not** keep a global Headroom provider/base URL override in `C:\Users\whertzing\.codex\config.toml`; it can make the app show only conversations created under `model_provider = headroom`. Use the wrapped Codex CLI for guaranteed proxy routing. |
| Claude desktop app | Only route through Headroom if the app exposes a custom Anthropic base URL or inherits `ANTHROPIC_BASE_URL`; otherwise use Claude Code CLI for guaranteed routing. |
| VS Code launched from shell | Launch from a shell that has `OPENAI_BASE_URL`, `ANTHROPIC_BASE_URL`, and `HEADROOM_TELEMETRY=off`: `code <workspace>`. This only helps extensions that actually inherit and honor those variables. |
| GitHub Copilot VS Code extension | Do **not** assume it is wrapped. The first-party extension may use GitHub-hosted Copilot endpoints and may ignore OpenAI/Anthropic base URL variables. Use Copilot CLI through `headroom wrap copilot` for guaranteed Headroom routing, or configure BYOK/custom-model base URL only if the installed extension version exposes that setting. |
| Cline VS Code extension | Run `headroom wrap cline --no-proxy`, then configure Cline's API Base URL in VS Code settings to `http://127.0.0.1:8787/v1` for OpenAI-compatible mode or the matching Anthropic-compatible URL if using Anthropic mode. |
| Continue VS Code / JetBrains extension | Run `headroom wrap continue --no-proxy`, then set each model's `apiBase` in `.continue/config.json` / `.continue/config.yaml` to the Headroom proxy URL. |
| Cursor app | Run `headroom wrap cursor --no-proxy`, then set Cursor's OpenAI override base URL to `http://127.0.0.1:8787/v1`. |

For app/extension surfaces, the acceptance test is not "the app launched" - it is "the proxy
saw traffic":

```powershell
curl http://127.0.0.1:8787/stats
headroom perf --hours 1
```

If the request counters do not change while using a surface, that surface is not routed
through Headroom yet. Prefer the wrapped CLI for guaranteed savings.

#### H.7.1 Codex desktop conversation visibility incident

On 2026-06-03, after `headroom wrap codex` was made to work for the Codex CLI, the Codex
desktop app showed `No Chats` for projects that still had conversation history. The
conversations were not deleted. They were still present in
`C:\Users\whertzing\.codex\state_5.sqlite` under the normal `openai` provider. The new
desktop sessions were being created under `model_provider = headroom`, so the app sidebar
was effectively showing the wrong provider slice.

The risky config injected by the wrapper was at the top of
`C:\Users\whertzing\.codex\config.toml`:

```toml
# --- Headroom proxy (auto-injected by headroom wrap codex) ---
model_provider = "headroom"
openai_base_url = "http://127.0.0.1:8787/v1"
# --- end Headroom ---
```

The repair was:

1. Confirm the old conversations existed in `state_5.sqlite`, grouped mostly under
   `model_provider = openai`.
2. Back up `C:\Users\whertzing\.codex\config.toml`.
3. Remove only the global Headroom provider/base URL override shown above.
4. Keep `[mcp_servers.headroom]` intact so the MCP tools still load.
5. Fully quit and restart the Codex desktop app.

Do not use the Codex desktop app as the primary Headroom proxy surface until Codex exposes a
provider override that does not partition or hide existing conversation history. Use
`headroom wrap codex` for the CLI and MCP tools for the desktop app.

### H.8 Daily usage and verification

- **MCP (default):** in Claude Code / Codex, run `/mcp`, then ask the agent to compress a
  large log or search result; retrieve the original with `headroom_retrieve <hash>` when
  exact line-level evidence is needed. Compress for triage/summary; **retrieve originals
  before exact edits or claims** — do not compress source files you are about to edit.
- **Wrap (optional):** `headroom wrap claude` / `headroom wrap codex` /
  `headroom wrap copilot` routes supported CLI provider traffic through the proxy for
  automatic compression.
- **Metrics:** `headroom perf --hours 1`, or the proxy endpoints `GET /stats` and
  `GET /stats-history` on `http://127.0.0.1:8787`.

### H.9 Troubleshooting

| Symptom | Cause / Fix |
| --- | --- |
| MCP server shows "failed to connect" | Registered as bare `headroom` (PATH-dependent). Re-add with the absolute `...\.venvs\headroom\Scripts\headroom.exe` path. |
| Codex desktop shows `No Chats` after `headroom wrap codex` | Check `C:\Users\whertzing\.codex\config.toml` for a global `model_provider = "headroom"` / `openai_base_url = "http://127.0.0.1:8787/v1"` override. Back up the file, remove only that override, keep `[mcp_servers.headroom]`, then fully restart Codex. Confirm history still exists with Python's built-in `sqlite3` module by querying `C:\Users\whertzing\.codex\state_5.sqlite` and grouping `threads` by `model_provider` and `cwd`. |
| `headroom wrap codex` reports telemetry enabled | Set `[Environment]::SetEnvironmentVariable('HEADROOM_TELEMETRY', 'off', 'User')`, open a fresh shell, and relaunch. |
| `headroom wrap codex` says `codex` not found | Add `C:\Users\whertzing\AppData\Local\OpenAI\Codex\bin` to user `PATH`, open a fresh shell, and verify `Get-Command codex`. |
| App or VS Code extension shows no proxy traffic | It is not inheriting or honoring the proxy base URL. Configure the extension's custom base URL/BYOK setting if available; otherwise use the wrapped CLI. |
| First compression hangs for minutes | CPU model cold-load (Path A). Expected once per process; switch to **Path B** for GPU. |
| `headroom_retrieve` returns nothing | Local/proxy retention window expired — reacquire the original content. |
| `pip` cert errors during install | Add `--use-feature=truststore` (Windows cert store). |
| Cargo `CRYPT_E_NO_REVOCATION_CHECK` | Set `CARGO_HTTP_CHECK_REVOKE=false` before the install (see §H.3). |
| `link.exe` / `cl.exe` not found | Load `VsDevCmd.bat` (§H.3) so the MSVC toolchain is on PATH. |
| Path B still CPU-only | CUDA `torch` / `onnxruntime-gpu` mismatch with driver CUDA level; reinstall the matching `cuXXX` wheel. |
| Proxy window flashes / steals focus | Use the `cscript` VBScript wrapper (§H.5), not a `cmd`/`pwsh` task action. |
