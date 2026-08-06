# Setup a New Development Computer

> **Canonical.** The companion [NewComputerSetupUsingAnsible.md](NewComputerSetupUsingAnsible.md)
> is retained only for its deeper BIOS / OS-install / Ansible-bootstrap notes; where the two
> overlap, THIS document wins (cross-link added 2026-07-06, Task 12.45.e).

## Purpose

This document bootstraps a new Windows 11 developer workstation so it can participate in
ATAP development, sprint worktrees, local SQL Server work, ProGet package hosting,
BuildMaster promotion workflows, and offline development.

The end state is:

1. The machine has the expected stable and sprint worktrees under `C:\Dropbox\whertzing\GitHub`,
   and the active overview assigns each developer to every approved host rather than
   deduplicating by username.
2. PowerShell 7 profiles are rendered from the canonical ATAP.IAC templates into the
   profile paths PowerShell actually loads; profiled remoting passes a bounded identity probe.
3. Third-party software is installed and configured:
   - SQL Server with the base instances `Production`, `QA`, and `Integration`
   - ProGet using the `Production` SQL instance — full step-by-step procedure: see [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md)
   - BuildMaster using the `Production` SQL instance — full step-by-step procedure: see [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md)
4. Service accounts have managed profiles, while only the explicitly approved identities
   receive Bitwarden Secrets Manager (`bws`) access. Interactive Password Manager
   (`bw`/`BW_SESSION`) use remains a separate user-only path.
5. Classified, verified SQL backups exist outside Git and Dropbox; independent Inedo
   databases are never copied or merged between hosts.
6. Stable-branch builds and tests complete successfully, and Class A/off-LAN plus bounded
   return certification is recorded with metadata-only evidence.

## Important Conventions

- **Parity journal required:** Before a step in this runbook changes state on
  `utat022` or `utat01`, append a secret-safe declaration with
  `Add-ParityChangeEntry` on the host being changed. Include the category,
  item, old/new state, peer host, and a peer action; do not include any secret
  value. After the peer applies its corresponding action, acknowledge it from
  that peer with `Confirm-ParityChangeApplied`.
- Use PowerShell 7 (`pwsh`) for all commands in this document.
- The historical phrase `SQL Server Community Edition` appears in older notes, but for a
  developer workstation that needs SQL Server Agent you should install SQL Server 2022
  Developer media. SQL Server Express does not include SQL Server Agent.
- Keep SQL Server instance names under 16 characters. The base instances are
  `Production`, `QA`, and `Integration`. Sprint and feature-branch instances use a short
  tier prefix such as `Dev` or `Exp` plus a shortened branch or user token.
- Prefer the newest `Overview.code-workspace` and `Overview.Sprint.NNNN.code-workspace`
  files at `C:\Dropbox\whertzing\GitHub` as the current branch/worktree matrix when
  they are present.

### Current architecture and deferred gates

Apply the guide in this dependency order. A later gate does not excuse a failed earlier one.

1. Settle Dropbox, inventory mutable application state, and prove exact repository integrity
   before changing Git or worktree state. Never grant Git trust to the whole GitHub parent.
2. Join an existing sprint with the machine-local boundary retarget procedure, not a second
   SprintStart. Only `.vscode` is a designed junction; AI adapter surfaces are concrete renders.
3. Resolve the active `(developer, host)` assignment and the profile paths PowerShell actually
   loads. Profile templates come from ATAP.IAC, not a retired ATAP.Utilities profile target.
4. Keep personal `bw`/`BW_SESSION` use distinct from project-scoped `bws` automation.
   Provision no new BWS identity until the Tasks 13.40–13.43 senior decision and release gates.
5. Declare one package manager as owner for every executable. The Java vendor/version/update
   decision remains deferred to `SC-0286`; measured Java 21/Flyway success is not that decision.
6. Verify the five SQL roles, classified backup boundaries, ProGet on port `50000`, and
   BuildMaster on port `50017` before package or application readiness claims.
7. Finish with mobile-host security, Class A off-LAN proof, and a bounded return drill.

The profiled-remoting source/runtime-state fix (Task 13.20.e), the BWS identity
decision (Tasks 13.40–13.43), the Java decision (`SC-0286`), the production-data policy
(Task 13.60), and the BuildMaster helper release (Task 13.20.j) remain explicit gates. Do not
turn a successful operator workaround into a claim that these product changes are deployed.

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

## Step 0: Validate Memory Before Building (MemTest86)

Run this before installing Windows on a new machine, and on any existing host that
shows unexplained bugchecks. Memory faults corrupt builds, databases, and Dropbox
state silently; validating first avoids attributing hardware failures to software.

> **Why this is Step 0.** MemTest86 boots from USB and does not need an OS. On a new
> build it costs one overnight run before any time is invested in the image. On an
> existing host it is the cheapest way to separate a hardware fault from a driver fault.

### 0.1 When to run

- Every new workstation, before Step 1.
- After any RAM change (added, replaced, or reseated DIMMs).
- After enabling or changing an EXPO/XMP memory profile.
- Whenever a host records more than one bugcheck in a week, **especially with
  differing bugcheck codes**. A single repeated code usually indicates a driver; a
  spread of unrelated codes (`0x1A`, `0x3B`, `0x50`, `0xBE`, `0x124`) indicates
  memory or another hardware fault.

Check a host's bugcheck history before deciding:

```powershell
# Bugcheck codes recorded in the last 30 days
Get-WinEvent -FilterHashtable @{
  LogName      = 'System'
  ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'
  Id           = 1001
  StartTime    = (Get-Date).AddDays(-30)
} -ErrorAction SilentlyContinue |
  Sort-Object TimeCreated |
  ForEach-Object {
    $code = if ($_.Message -match 'bugcheck was:\s*(0x[0-9a-fA-F]+)') { $Matches[1] } else { '?' }
    '{0}  {1}' -f $_.TimeCreated.ToString('MM-dd HH:mm:ss'), $code
  }

# WHEA entries are hardware-reported and cannot be caused by software
Get-WinEvent -FilterHashtable @{
  LogName      = 'System'
  ProviderName = 'Microsoft-Windows-WHEA-Logger'
  StartTime    = (Get-Date).AddDays(-30)
} -ErrorAction SilentlyContinue |
  Select-Object TimeCreated, Id, LevelDisplayName
```

### 0.2 Build the bootable USB

MemTest86 (PassMark) Free Edition is sufficient; the paid editions add reporting
features this runbook does not require. Do **not** substitute the built-in Windows
Memory Diagnostic — it is far weaker and misses marginal faults.

1. Download the **MemTest86 Free Edition — Image for creating bootable USB Drive**
   from `https://www.memtest86.com/download.htm` on a *known-good* machine.
2. Extract the ZIP. It contains `imageUSB.exe` and the `memtest86-usb.img` image.
3. Insert a USB stick of 1 GB or larger. **Its contents are destroyed.**
4. Run `imageUSB.exe` elevated, select the USB drive, choose
   **Write image to USB drive**, and confirm.

```powershell
# Identify the USB stick before writing, so the correct disk is selected in imageUSB
Get-Disk | Where-Object BusType -eq 'USB' |
  Select-Object Number, FriendlyName, @{ n = 'GB'; e = { [math]::Round($_.Size / 1GB, 1) } }
```

> **Keep the stick.** Label it and store it with the build media. It is reused for
> every host, so this step is only performed once per site.

### 0.3 Boot the target machine from the USB

1. Insert the stick and power on, opening the firmware boot menu (commonly `F12`,
   `F11`, `F8`, or `Esc` — vendor-specific).
2. Select the USB device, preferring the **UEFI** entry when both are listed.
3. If the stick will not boot, disable **Secure Boot** in firmware, run the test,
   then re-enable it afterward.

### 0.4 Run the test

Accept the default test suite and let it complete **at least four full passes**.
Expect roughly 30–60 minutes per pass for 32 GB, so schedule an overnight run.

- MemTest86 starts automatically after a short countdown.
- Errors are reported in red and counted per test; the run need not be stopped, but
  any error at all is a failure.
- At the end, choose to save the report. It is written to the USB stick as
  `MemTest86.log` and an HTML report.

**Pass criteria: zero errors across four or more consecutive passes.** One error is
a failure. Memory faults are frequently intermittent, so a single clean pass proves
nothing.

### 0.5 Test at the memory profile you intend to run

An enabled EXPO/XMP profile is a factory overclock, not a JEDEC-guaranteed speed. It
is a common source of exactly the mixed-bugcheck pattern described in 0.1. Test in
the order below and record which configuration passed:

| Order | Firmware setting | Interpretation of a failure |
| --- | --- | --- |
| 1 | EXPO/XMP **enabled** (rated speed) | The profile is unstable on this silicon; continue to test 2. |
| 2 | EXPO/XMP **disabled** (JEDEC, e.g. DDR5-4800) | The DIMMs themselves are faulty; RMA them. |

If the host passes at JEDEC but fails at the rated profile, either run it at JEDEC
permanently or step the profile down (for example 6000 → 5600) and re-validate with a
full four-pass run before trusting the machine.

Record the memory configuration under test:

```powershell
Get-CimInstance Win32_PhysicalMemory |
  Select-Object DeviceLocator, Manufacturer, PartNumber,
                @{ n = 'GB';    e = { [math]::Round($_.Capacity / 1GB) } },
                @{ n = 'Speed'; e = { $_.Speed } }
```

### 0.6 If the test fails

1. Re-run with a **single DIMM installed**, repeating for each DIMM, to identify the
   failing module. Use the same slot each time so a faulty slot is not mistaken for a
   faulty DIMM.
2. If every DIMM fails individually in the same slot, test a known-good DIMM in a
   different slot to implicate the slot or the memory controller.
3. RMA the failing module. Do not continue with the build; a host that fails
   MemTest86 must not be used for ATAP development, database, or Dropbox work.

### 0.7 Record the result in the parity journal

Per the parity-journal convention in **Important Conventions**, declare the outcome
on the host that was tested so the peer host can be scheduled for the same
validation:

```powershell
Import-Module ATAP.Utilities.SystemParityMonitor.PowerShell

Add-ParityChangeEntry `
  -Category      OS `
  -Item          'MemTest86 memory validation' `
  -OldValue      'not validated' `
  -NewValue      'PASS - 4 passes, EXPO disabled (JEDEC DDR5-4800)' `
  -PeerHostName  'utat01' `
  -PeerActionKind Document `
  -PeerAction    'Run MemTest86 per NewComputerSetup.md Step 0; record pass/fail and the memory profile tested.' `
  -Reason        'Baseline hardware validation gate for all ATAP hosts.'
```

Adjust `-NewValue` to the configuration actually tested. After the peer host runs its
own validation, acknowledge the entry there with `Confirm-ParityChangeApplied`.

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
8. Sysinternals Suite at `C:\Program Files\SysinternalsSuite`

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

### 2.3 Install Sysinternals Suite

Install the pinned Sysinternals Suite release with WinGet. The suite is part of the
UTAT workstation parity baseline: it was installed on `utat01` on 2026-07-28 and must
be installed to the same location on `utat022` during the return procedure.

Run from an elevated PowerShell session:

```powershell
winget install -e --id Microsoft.Sysinternals.Suite --version 2026-07-09
```

Record the installed version and resolved executable path in the parity journal. On
`utat01`, the existing direct-download installation is at
`C:\Program Files\SysinternalsSuite`; verify the WinGet installation on `utat022`
resolves to the same path before closing the return action.

### 2.3.1 Configure Avast HTTPS inspection for browsers only

Avast Web Guard (formerly Web Shield) installs a local trusted root and transparently
intercepts TLS through its network-filter drivers. This is not a WinHTTP, WinINet, or
environment-variable proxy: those proxy surfaces can all report direct access while a
non-browser process still receives an Avast-issued certificate instead of the certificate
presented by the destination service. That breaks PKI evidence and can disrupt PowerShell,
`bws`, NuGet, ProGet, BuildMaster, and other development automation.

Keep HTTPS inspection enabled for browsers, but restrict Web Guard to browser processes on
developer and infrastructure hosts:

1. Open Avast and select **Menu > Settings**.
2. Select **Search**, enter `geek:area`, and open **Avast Geek**.
3. Search for `well-known browser`.
4. Enable **Scan traffic from well-known browser processes only**.
5. Leave **Enable HTTPS scanning** enabled.

Avast documents this control in
[Using the Avast Geek settings area](https://support.avast.com/en-us/article/Use-Antivirus-Geek-settings).
Do not replace this configuration with broad URL exceptions: an exception for an internal
host also bypasses inspection when a browser visits that host. Do not treat `-NoProxy` as a
permanent fix; it does not configure Avast and only happened to avoid one intercepted client
path during diagnosis.

Record the change with `Add-ParityChangeEntry` before applying it. The peer action is to
enable the same browser-process-only setting on the other UTAT host and then acknowledge the
journal entry.

After applying the setting, verify all of the following:

```powershell
# Conventional proxy surfaces remain disabled.
netsh winhttp show proxy
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
  Select-Object ProxyEnable, ProxyServer, AutoConfigURL
Get-ChildItem Env: | Where-Object Name -Match '^(HTTP|HTTPS|ALL|NO)_PROXY$'

# Development traffic succeeds without a bypass switch.
(Invoke-WebRequest 'https://utat022:50000/' -UseBasicParsing -TimeoutSec 20).StatusCode
(Invoke-WebRequest 'https://utat022:50017/' -UseBasicParsing -TimeoutSec 20).StatusCode

# Resolve a known metadata-safe test secret without printing its value.
$null = Get-SecretATAP -SecretName '<approved-test-SecretName>' -ErrorAction Stop
```

In a browser, confirm Avast inspection remains active. From PowerShell, confirm the TLS leaf
subject, issuer, and thumbprint are the direct ATAP Foundation values recorded in
`ATAP.IAC\Windows\AnsibleHostInventory\All\PKI-TLS-ATAP-Foundation.example.yml`, not an
`Avast Web/Mail Shield` certificate. A successful HTTP status alone is insufficient PKI
evidence because an intercepting certificate can still produce HTTP 200.

### 2.4 Install Python (for Manim or Copilot code execution)

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

Before allowing Dropbox to synchronize application state, inventory host-local mutable
directories such as databases, package stores, logs, caches, sessions, histories, captures,
and credential stores. Keep them out of Dropbox/Git unless a reviewed procedure explicitly
classifies a safe declarative subset. Wait for Dropbox to report `Up to date`, scan for
`*conflicted copy*` files and unexpected reparse points, then verify the stable repos exist:

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

Do not run SprintStart a second time merely because this host is joining an active sprint.
Run the current machine-local boundary retarget, then verify clean Git state and exact-path
ownership/trust for each repository and worktree. Trusting `C:\Dropbox\whertzing\GitHub` as a
single parent path is prohibited. Confirm `.vscode` is the intended junction and that `.agents`,
`.claude`, `.codex`, and `.gemini` are concrete rendered surfaces.

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

The canonical developer and service-account templates come from ATAP.IAC. Deploy managed
copies through BuildTooling and HostSettings; do not create a profile symlink or revive the
retired ATAP.Utilities profile target. Discover the paths PowerShell actually loads from
`$PROFILE` in a fresh shell, including redirected known folders.

### 4.1 Verify the machine-wide PowerShell 7 profile source

Use the current ATAP.IAC profile template selected through HostSettings. In both a direct
fresh shell and `ATAP.PS7.Profiled`, record the loaded `$PROFILE` paths, source/target
existence, parser/import results, and current identity. The verified bounded workaround is
to register the endpoint with an explicit `WithProfiles.pssc` path. Default deployed-module
resolution and machine-state placement remain deferred to Task 13.20.e; do not present the
workaround as the installed fix.

### 4.2 Provision managed current-user profiles

Use `Set-UserScopeProfile` instead of copying or linking an individual profile.
The developer template dot-sources the canonical core profile; service-account
templates are deliberately minimal and never start Bitwarden/browser
authentication or resolve secrets. The command refuses to replace a profile
without the managed-header marker unless `-Force` is supplied. Each live change
adds an `Add-ParityChangeEntry` record for the peer machine.

```powershell
Import-Module ATAP.Utilities.BuildTooling.PowerShell

$iacRoot = Join-Path $gitHubRoot 'ATAP.IAC'
Set-UserScopeProfile -AccountName 'whertzing' -AccountClass Developer `
  -ATAPIACRoot $iacRoot -ATAPUtilitiesRoot $atapRoot -Confirm:$false

# Run this only after the local service account exists. Use an elevated shell
# because a different user's profile directory is being written.
Set-UserScopeProfile -AccountName 'SvcBuildMaster' -AccountClass ServiceAccount `
  -ATAPIACRoot $iacRoot -ATAPUtilitiesRoot $atapRoot -Confirm:$false
```

For the complete service-account and BWS-machine-token procedure, see
[Runbook-BitwardenServiceAccounts.md](Runbook-BitwardenServiceAccounts.md).

### 4.3 Install required PowerShell Gallery modules

Install the PowerShell Gallery dependencies before later steps import
`ATAP.Utilities.BuildTooling.PowerShell`. Use `-Scope AllUsers` (not
`CurrentUser`) so the BuildMaster service account (`SvcBuildMaster` on
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

BuildMaster runs as a service account (`SvcBuildMaster` on `utat022`) and
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
non-interactive session BuildMaster spawns under `SvcBuildMaster`. After
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
CLI to read runtime secrets (Step 9.4.10). The Inedo products run as `SvcBuildMaster`
and `SvcProGet`, and those service / scheduled-task processes start with `-NoProfile`,
so `bws` must resolve from the **machine** `PATH` — not from a per-user `winget` install
under one developer's AppData, and not only from the ATAP profile's injected PATH (which
`-NoProfile` sessions and Windows services never load).

This is the same machine-wide-resolution requirement Step 4.4 documents for `nbgv`.
Install `bws.exe` into a shared `Program Files` location and add that folder to the
system `PATH` so every local account — `SvcBuildMaster`, `SvcProGet`, and every
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
including `SvcBuildMaster` and `SvcProGet` once their services are restarted. The
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
$svc = 'SvcBuildMaster'   # repeat with 'SvcProGet'
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

### 4.7 Gate Java, Flyway, and package-manager ownership

Inventory Java from every package manager and every resolved path before installing or
removing a runtime. A successful UTAT01 repair removed Oracle Java 8 and proved Java 21 with
Flyway, but the canonical vendor, architecture, version, update owner, rollback, `JAVA_HOME`,
and PATH-order decision remains deferred to `SC-0286`. Do not generalize that measured repair
into an organization-wide Java selection.

Apply the same ownership gate to Chocolatey, pip, npm, NuGet/.NET tools, and manually
installed binaries. Every overlap needs one declared owner even when versions match. Record
only version, path, architecture, package owner, and test outcome. Flyway validation must run
with the exact Java executable selected by the gate.

## Phase 2: Third-Party Software

## Step 5: Create the Bitwarden Secrets and Local Service Accounts

Create these Bitwarden items in the `ComputerLogins` collection before installing any
third-party service. Each item must contain a username and password field.

| Bitwarden item name                          | Local Windows account | Used by                                         |
| -------------------------------------------- | --------------------- | ----------------------------------------------- |
| `SvcSQLServer.Login.<COMPUTERNAME>`   | `SvcSQLServer`   | SQL Server Database Engine and SQL Server Agent |
| `SvcProGet.Login.<COMPUTERNAME>`      | `SvcProGet`      | ProGet service                                  |
| `SvcBuildMaster.Login.<COMPUTERNAME>` | `SvcBuildMaster` | BuildMaster service                             |

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
    SecretName  = "SvcSQLServer.Login.$($env:COMPUTERNAME.ToLowerInvariant())"
    AccountName = 'SvcSQLServer'
    FullName    = 'SQL Server Service Identity'
    Description = 'Local service account for SQL Server Database Engine and Agent'
  },
  @{
    SecretName  = "SvcProGet.Login.$($env:COMPUTERNAME.ToLowerInvariant())"
    AccountName = 'SvcProGet'
    FullName    = 'ProGet Service Identity'
    Description = 'Local service account for the Inedo ProGet service'
  },
  @{
    SecretName  = "SvcBuildMaster.Login.$($env:COMPUTERNAME.ToLowerInvariant())"
    AccountName = 'SvcBuildMaster'
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

All SQL Server named instances use TCP with fixed, high-range ports; do not use
dynamic ports. This is the intended configuration on every host:

| Instance | TCP port |
| --- | ---: |
| `Production` | 50020 |
| `QA` | 50025 |
| `Integration` | 50030 |
| `DevWhertzing` | 50035 |
| `ExpWhertzing` | 50040 |

Use the database-management helper:

```powershell
Import-Module ATAP.Utilities.DatabaseManagement.Powershell

$setupExe = Find-SqlServerSetupExe
$setupRoot = Split-Path $setupExe -Parent

$hostName = $env:COMPUTERNAME.ToLowerInvariant()
$topology = $global:settings[$global:configRootKeys['SqlInstanceTopologyConfigRootKey']]
$hosts = $topology[$global:configRootKeys['SqlInstanceTopologyHostsConfigRootKey']]
$instances = $hosts[$hostName][$global:configRootKeys['SqlInstanceTopologyInstancesConfigRootKey']]
$instanceNameKey = $global:configRootKeys['SqlInstanceTopologyInstanceNameConfigRootKey']
$tcpPortKey = $global:configRootKeys['SqlInstanceTopologyTcpPortConfigRootKey']

foreach ($role in @('PRODUCTION', 'QA', 'INTEGRATION')) {
  $instance = $instances[$role]
  Install-SqlServerInstance `
    -DatabaseHost 'localhost' `
    -SqlInstance $instance[$instanceNameKey] `
    -ConnectionMethod 'tcp' `
    -Port $instance[$tcpPortKey] `
    -AuthenticationMode 'Windows' `
    -IntegratedSecurity `
    -Version '2022' `
    -SqlServerSetupPath $setupRoot
}
```

### 6.3 During the SQL Server setup UI

When the SQL installer prompts for service accounts:

1. Configure the Database Engine to run as `SvcSQLServer`.
2. Configure SQL Server Agent to run as `SvcSQLServer`.
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

For each named instance, configure TCP/IP with the fixed port in the preceding
table and clear its dynamic-port setting:

1. Open SQL Server Configuration Manager.
2. Enable TCP/IP for the instance.
3. Assign the intended static port.
4. Restart the instance.
5. Verify that the data, log, and backup directories match the current host's
   SQL topology row in `$global:settings`.

Display the authoritative values for the current host:

```powershell
$hostName = $env:COMPUTERNAME.ToLowerInvariant()
$topology = $global:settings[$global:configRootKeys['SqlInstanceTopologyConfigRootKey']]
$hosts = $topology[$global:configRootKeys['SqlInstanceTopologyHostsConfigRootKey']]
$instances = $hosts[$hostName][$global:configRootKeys['SqlInstanceTopologyInstancesConfigRootKey']]

$instances.Values | Select-Object InstanceName, DataPath, LogPath, BackupPath, TcpPort
```

Every instance follows this settings-backed convention:

- Data: `C:\LocalDBs\<INSTANCE_NAME>\Data\`
- Logs: `C:\LocalDBs\<INSTANCE_NAME>\Log\`
- Backups: `C:\LocalDBs\<INSTANCE_NAME>\Backup\`

`Install-SqlServerInstance` resolves these values from `$global:settings` and passes
them to dbatools. Do not reproduce the paths as independent literals in setup scripts.

Verify TCP connectivity:

```powershell
sqlcmd -S 'localhost\Production' -E -Q 'SELECT @@SERVERNAME, @@VERSION' -C
sqlcmd -S 'localhost\QA' -E -Q 'SELECT @@SERVERNAME' -C
sqlcmd -S 'localhost\Integration' -E -Q 'SELECT @@SERVERNAME' -C
```

### 6.6 Cap `max server memory` on every instance

SQL Server ships with `max server memory (MB)` set to `2147483647`, which means
unlimited. A workstation runs several instances alongside builds, AI agent
processes, and Dropbox, so uncapped instances compete with each other and with the
OS until every instance raises error 701 at once. **Cap every instance immediately
after creating it.**

The standing allocation for a 32 GB host:

| Instance | Cap (MB) | Rationale |
| --- | --- | --- |
| `Production` | 7936 | Hosts the ProGet and BuildMaster databases; the only instance under sustained real load. |
| `QA` | 1792 | Promotion target; intermittent load. |
| `Integration` | 1024 | Integration runs only. |
| `Dev<user>` | 768 | Per-developer scratch. |
| `Exp<user>` | 768 | Per-developer experimental. |
| **Total** | **12288** | 12 GB of 32 GB, leaving headroom for the OS, builds, and agent processes. |

Scale proportionally on hosts with different physical memory, keeping the total at
roughly one third of RAM and leaving `Production` the clear majority.

Apply the caps:

```powershell
$caps = [ordered]@{
  Production  = 7936
  QA          = 1792
  Integration = 1024
  "Dev$($env:USERNAME)" =  768
  "Exp$($env:USERNAME)" =  768
}

foreach ($instance in $caps.Keys) {
  $mb = $caps[$instance]
  $tsql = @"
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', $mb; RECONFIGURE;
"@
  sqlcmd -S "localhost\$instance" -E -C -Q $tsql
  Write-Output "  $instance capped at $mb MB"
}
```

> **No restart required.** `max server memory` is a dynamic setting
> (`sys.configurations.is_dynamic = 1`); it takes effect immediately.

Verify the applied values and the host-wide total:

```powershell
$rows = foreach ($instance in @('Production','QA','Integration',"Dev$($env:USERNAME)","Exp$($env:USERNAME)")) {
  $c = New-Object System.Data.SqlClient.SqlConnection "Server=localhost\$instance;Integrated Security=True;Connect Timeout=10;TrustServerCertificate=True"
  $c.Open()
  $cmd = $c.CreateCommand()
  $cmd.CommandText = @'
SELECT MaxMB  = (SELECT CONVERT(bigint, value_in_use) FROM sys.configurations WHERE name = 'max server memory (MB)'),
       UsedMB = (SELECT physical_memory_in_use_kb / 1024 FROM sys.dm_os_process_memory)
'@
  $r = $cmd.ExecuteReader()
  while ($r.Read()) { [pscustomobject] @{ Instance = $instance; MaxMB = $r['MaxMB']; UsedMB = $r['UsedMB'] } }
  $c.Close()
}
$rows | Format-Table -AutoSize
'TOTAL capped: {0} MB' -f ($rows.MaxMB | Measure-Object -Sum).Sum
```

A value of `2147483647` in the `MaxMB` column means that instance was missed.

If `Production` later shows sustained memory pressure — error 701, or a page life
expectancy trending toward single digits — raise its cap before any other
instance's:

```powershell
$c = New-Object System.Data.SqlClient.SqlConnection 'Server=localhost\Production;Integrated Security=True;TrustServerCertificate=True'
$c.Open()
$cmd = $c.CreateCommand()
$cmd.CommandText = @'
SELECT counter_name, cntr_value FROM sys.dm_os_performance_counters
WHERE counter_name IN ('Page life expectancy', 'Total Server Memory (KB)', 'Target Server Memory (KB)')
'@
$r = $cmd.ExecuteReader()
while ($r.Read()) { '{0,-28} {1}' -f $r[0].Trim(), $r[1] }
$c.Close()
```

Declare the caps in the parity journal so the peer host receives the same
allocation:

```powershell
Import-Module ATAP.Utilities.SystemParityMonitor.PowerShell

Add-ParityChangeEntry `
  -Category      SQL `
  -Item          'max server memory (MB) - all local instances' `
  -OldValue      'uncapped (2147483647 MB default)' `
  -NewValue      'capped, 12288 MB total: Production 7936, QA 1792, Integration 1024, Dev 768, Exp 768' `
  -PeerHostName  'utat01' `
  -PeerActionKind ConfigureService `
  -PeerAction    'Apply the same max server memory caps to the corresponding local SQL instances. Setting is dynamic; no restart required.' `
  -Reason        'Uncapped instances compete for RAM and raise error 701 together under memory pressure.'
```

## Step 7: Create Sprint and Feature-Branch Developer Instances

The permanent instances are `Production`, `QA`, and `Integration`. Developer and
experimental instances are per-user or per-feature and are created separately.

> **Every new instance must be capped.** Instances created here arrive at the SQL
> default of unlimited. A single uncapped sprint instance can consume the headroom
> reserved for all the others. Apply the **1024 MB default cap** in 7.1 as part of
> creating the instance, not as a later cleanup step.

For the active developer:

```powershell
Import-Module ATAP.Utilities.BuildTooling.PowerShell

New-SprintSqlServerInstances `
  -InstanceNames @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)") `
  -Databases @('ATAPUtilities', 'AceCommander') `
  -DatabaseHost 'localhost' `
  -ConnectionMethod 'tcp'
```

### 7.1 Apply the default memory cap to every new instance

**Default cap for any instance created in this step: `1024` MB.** Run this
immediately after `New-SprintSqlServerInstances` returns, and after creating any
ad-hoc sprint or feature-branch instance.

```powershell
# Default cap for newly created sprint / feature-branch instances
$DefaultInstanceCapMB = 1024

$newInstances = @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)")   # add feature-branch instances here

foreach ($instance in $newInstances) {
  $tsql = @"
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', $DefaultInstanceCapMB; RECONFIGURE;
"@
  sqlcmd -S "localhost\$instance" -E -C -Q $tsql
  Write-Output "  $instance capped at $DefaultInstanceCapMB MB"
}
```

Sweep for any instance still at the unlimited default — this catches instances
created outside this runbook:

```powershell
Get-Service -Name 'MSSQL$*' |
  Where-Object Status -eq 'Running' |
  ForEach-Object {
    $instance = $_.Name -replace '^MSSQL\$', ''
    try {
      $c = New-Object System.Data.SqlClient.SqlConnection "Server=localhost\$instance;Integrated Security=True;Connect Timeout=10;TrustServerCertificate=True"
      $c.Open()
      $cmd = $c.CreateCommand()
      $cmd.CommandText = "SELECT CONVERT(bigint, value_in_use) FROM sys.configurations WHERE name = 'max server memory (MB)'"
      $maxMb = $cmd.ExecuteScalar()
      $c.Close()
      [pscustomobject] @{
        Instance = $instance
        MaxMB    = $maxMb
        Status   = if ($maxMb -eq 2147483647) { 'UNCAPPED - fix' } else { 'ok' }
      }
    } catch {
      [pscustomobject] @{ Instance = $instance; MaxMB = 'unreachable'; Status = $_.Exception.Message }
    }
  } | Format-Table -AutoSize
```

Raise a sprint instance above `1024` MB only when a specific workload requires it,
and subtract the increase from the host's remaining headroom rather than letting the
total climb past the budget in 6.6.

Notes:

1. `New-SprintSqlServerInstances` creates only the `Dev...` and `Exp...` instances. It
   does not create `Production`, `QA`, or `Integration`.
2. For long-lived multi-sprint feature branches, combine a short feature token with the
   tier prefix and keep the full instance name under 16 characters.
3. Use the current `Overview.code-workspace` and `Overview.Sprint.NNNN.code-workspace`
   files as the branch matrix when deciding which extra instances are still required.
4. Sprint instances are torn down at sprint end. Removing them returns their capped
   memory to the host budget; no cap adjustment is needed elsewhere when they go away.

## Step 8: Build the Databases on All Instances

Classify the five roles before running any database command:

- `Devwhertzing` and `Expwhertzing` are permanent developer instances managed by the sprint
  lifecycle and may be rebuilt from Flyway under that contract.
- `Integration` and `QA` are ecosystem tiers with their own verification and reset policy.
- `Production` is protected data. Do not rebuild, seed, copy, restore, or reset it merely
  because a developer instance was created. Task 13.60 owns the protection/seed policy.

Run the database rebuild script only for roles whose current policy explicitly authorizes a
rebuild:

```powershell
Push-Location 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
.\Database\Powershell\public\Rebuild-All-AllInstances.ps1
Pop-Location
```

This script should be treated as a temporary bootstrap script until it is converted into a
module cmdlet. Review its resolved target list before execution. It is not authorization to
build or seed Production, and it must not collapse the five roles into "two instances total."

## Step 9: Install and Configure ProGet and BuildMaster

Group all tooling setup under this section. ProGet and BuildMaster both use the local
`Production` SQL Server instance and Windows integrated security.

The two Inedo products are independent per host. ProGet is canonical on port `50000` and
BuildMaster on port `50017`; port `8600` is obsolete. Never copy or merge an Inedo database
between `utat01` and `utat022`. All service placement and derived URLs come from the single
`ServicePlacementMap`; do not edit derived endpoint keys individually.

ProGet readiness includes the per-host license state, `Storage.PackagesRootPath` readback as
`C:\ProgramData\ProGet\Packages`, `SvcProGet` ACLs, the canonical 15-feed inventory, explicit
connector-free mapping, and a harmless publish/download/restore proof. The approved local HTTP
NuGet source may set `allowInsecureConnections=true`; public sources remain HTTPS. Resolve the
host-specific administrative SecretName only at the authenticated-operation boundary and never
record the value.

BuildMaster readiness includes the host-specific administrative SecretName, the approved
`ATAP.Utilities-CSharp` and `ATAP.Utilities-PowerShell` application definitions, required
non-secret variables, default raft, and full `Assert-BuildMasterReady` outcome. The supported
server `ArtifactUsage` values are `FileSystem`, `AssetDirectory`, and `None`; do not send
`Default`. The direct API fallback is a verified workaround only. Optional/null-field handling,
response detail, idempotent create/update tests, release, and installation remain Task 13.20.j.

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
  -ServiceAccount "$env:COMPUTERNAME\SvcBuildMaster" `
  -Encrypt Optional `
  -TrustServerCertificate
```

### 9.2.1 Grant SvcBuildMaster database-package deployment rights

The preceding BuildMaster product-database grant is not sufficient for database
package deployment. The BuildMaster service identity also performs tier rehearsal,
pre-migration backup, and Flyway DDL/DML apply operations. Grant the local
`SvcBuildMaster` identity `db_owner` on the `ATAPUtilities` database in every
authorized tier instance.

The logical Experimental tier targets `Exp<DeveloperName>`. Never create or grant
against a generic permanent `Experimental` instance.

Run this idempotent procedure in an elevated, profile-loaded PowerShell session
after the five databases exist:

```powershell
Import-Module ATAP.Utilities.PowerShell

$developerName = $env:USERNAME
$serviceAccount = "$env:COMPUTERNAME\SvcBuildMaster"
$databaseTierInstances = @(
  "Exp$developerName"
  "Dev$developerName"
  'Integration'
  'QA'
  'Production'
)

foreach ($instanceName in $databaseTierInstances) {
  Initialize-SqlServiceLogin `
    -SqlInstance "localhost\$instanceName" `
    -DatabaseName 'ATAPUtilities' `
    -ServiceAccount $serviceAccount `
    -Encrypt Optional `
    -TrustServerCertificate
}
```

Verify the server login, database user, and `db_owner` membership independently:

```powershell
$principalLiteral = $serviceAccount.Replace("'", "''")
$verificationQuery = @"
DECLARE @principal sysname = N'$principalLiteral';
SELECT
  CAST(SERVERPROPERTY('MachineName') AS nvarchar(128)) AS MachineName,
  CAST(SERVERPROPERTY('InstanceName') AS nvarchar(128)) AS InstanceName,
  DB_NAME() AS DatabaseName,
  @principal AS AccountName,
  IIF(SUSER_ID(@principal) IS NULL, 0, 1) AS ServerLoginExists,
  IIF(USER_ID(@principal) IS NULL, 0, 1) AS DatabaseUserExists,
  ISNULL(IS_ROLEMEMBER(N'db_owner', @principal), 0) AS IsDbOwner;
"@

$grantAudit = foreach ($instanceName in $databaseTierInstances) {
  Invoke-Sqlcmd `
    -ServerInstance "localhost\$instanceName" `
    -Database 'ATAPUtilities' `
    -Query $verificationQuery `
    -TrustServerCertificate
}

$grantAudit |
  Select-Object MachineName, InstanceName, DatabaseName, AccountName,
    ServerLoginExists, DatabaseUserExists, IsDbOwner

if ($grantAudit.Where({
      $_.ServerLoginExists -ne 1 -or
      $_.DatabaseUserExists -ne 1 -or
      $_.IsDbOwner -ne 1
    }).Count -gt 0) {
  throw 'SvcBuildMaster ATAPUtilities database permission verification failed.'
}
```

Record this machine-state grant with `Add-ParityChangeEntry`. The peer action must
repeat the same idempotent procedure using the peer-local
`<PeerHost>\SvcBuildMaster` identity, then acknowledge the entry only after the
independent query passes on all five authorized tier databases. Do not copy or
restore an application or Inedo database to establish parity.

### 9.3 Reconfigure the Windows services to use the dedicated accounts

```powershell
Import-Module ATAP.Utilities.PowerShell

$proGetPassword = Get-SecretATAP -SecretName "SvcProGet.Login.$($env:COMPUTERNAME.ToLowerInvariant())" -SecretField 'password'
$bmPassword = Get-SecretATAP -SecretName "SvcBuildMaster.Login.$($env:COMPUTERNAME.ToLowerInvariant())" -SecretField 'password'

$proGetCredential = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcProGet",
  (ConvertTo-SecureString $proGetPassword -AsPlainText -Force)
)

$buildMasterCredential = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcBuildMaster",
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

### 9.4 Provision approved Bitwarden Secrets Manager ReadOnly identities

This is the only supported non-interactive secret bootstrap. Password Manager
`bw`/`BW_SESSION` is interactive-user-only and must never be provisioned to or inherited by
a Windows service. The retired service-account Password Manager procedure is available in
Git history only and is non-executable.

The approved automation allowlist is exact: `SvcBuildMaster`, `SvcProGet`, and
`SvcSQLServer`, each scoped to project `CI-Shared` with purpose `ReadOnly`. `SvcSeq`,
`SvcParityAudit`, and `ansibleAdmin` receive no BWS token. ReadWrite is approved only for
`utat022\whertzing` and is not a fallback for any service account. Creating accounts,
certificates, Bitwarden grants, tokens, logon rights, or scheduled tasks is a separate HITL
operation under Tasks 13.40–13.43.

#### 9.4.1 Preconditions and dry run

1. Install BuildTooling 0.1.44 or later from `powershellget-stable` at AllUsers scope and
   verify a fresh shell imports that exact version from `C:\Program Files\PowerShell\Modules`.
2. Confirm the service account, its Password logon credential, its document-encryption
   certificate/private key, and its `CI-Shared` ReadOnly machine-account grant were created
   under explicit operator authority.
3. Resolve the current repository root and host at run time. Do not paste a sprint worktree
   path or a suffixless infrastructure SecretName into this procedure.
4. Run both cmdlets with `-WhatIf`. Require `ProjectName=CI-Shared`,
   `TokenPurpose=ReadOnly`, the intended account, and no state change.

```powershell
$repositoryRoot = git rev-parse --show-toplevel
Import-Module (Join-Path $repositoryRoot 'src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1') -Force

$accountName = '.\SvcProGet' # repeat separately for each approved account
$token = Read-Host 'CI-Shared ReadOnly BWS token' -AsSecureString
$envelope = Join-Path $env:TEMP 'ATAP-BWS-ReadOnly-bootstrap.cms'
$certificatePath = Join-Path $env:TEMP 'SvcProGet.cer'

New-BWSReadOnlyBootstrapEnvelope `
  -AccountName $accountName `
  -AccessToken $token `
  -RecipientCertificatePath $certificatePath `
  -OutputPath $envelope `
  -WhatIf
```

The public `.cer` must have document-encryption EKU and a simple name exactly matching the
approved account. The envelope contains no plaintext token and is bound to that account's
certificate. Never put a token in an argument, environment variable, transcript, log, or
evidence artifact.

#### 9.4.2 Execute the bounded bootstrap

After reviewing the dry run, create the CMS envelope and invoke the bounded one-shot
Password-logon scheduled task. The service logon credential identity must exactly match
`-AccountName`.

```powershell
$serviceLogonCredential = Get-Credential -UserName $accountName
$envelopeResult = New-BWSReadOnlyBootstrapEnvelope `
  -AccountName $accountName `
  -AccessToken $token `
  -RecipientCertificatePath $certificatePath `
  -OutputPath $envelope

$bootstrap = Invoke-BWSReadOnlyTokenBootstrap `
  -AccountName $accountName `
  -ServiceLogonCredential $serviceLogonCredential `
  -EnvelopePath $envelopeResult.EnvelopePath `
  -CertificateThumbprint $envelopeResult.CertificateThumbprint

Remove-Item -LiteralPath $envelopeResult.EnvelopePath -Force
$serviceLogonCredential = $null
$token = $null
```

The automation uses the fixed `\ATAP\` task path, waits for bounded completion, verifies the
canonical account-bound DPAPI ReadOnly file, and removes the temporary task. Re-running
without `-Force` returns the existing-state result without overwriting it; use `-Force` only
for an operator-reviewed repair. A failure stops and verifies task removal before deleting
the envelope; a cleanup failure is an operator gate, not permission to continue.

#### 9.4.3 Validate without exposing secret material

Run validation as the owning account in a fresh profile-enabled shell:

```powershell
$credential = Get-BWSAccessToken -TokenPurpose ReadOnly
if ($credential.UserName -ne 'BWS_ACCESS_TOKEN') {
  throw 'The canonical ReadOnly DPAPI slot did not return the expected credential shape.'
}
Get-SecretATAP -SecretName '<approved-CI-Shared-secret-name>' | Out-Null
```

Record only account, host, project, purpose, module version/path, operation ID, redacted
status, and the DPAPI file path/hash. Do not record the credential value, BWS output, CMS
contents, task XML, runtime environment, transcript, cache, or history. Repeat independently
for all three approved accounts and both hosts; DPAPI files and envelopes are never copied
between accounts or hosts.

### 9.5 Bootstrap exact Git trust for the BuildMaster service account

When a BuildMaster build agent runs as the BuildMaster service account
(`SvcBuildMaster` on `utat022`) against a worktree under
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

Run as `SvcBuildMaster` itself, not as the interactive developer. Add only the resolved
repository and worktree paths that this identity is authorized to build. Task 13.5 owns the
idempotent ownership/trust automation; until that automation is deployed, review each exact
path before adding it.

```powershell
# Elevated pwsh running as SvcBuildMaster; repeat for each reviewed exact path.
$authorizedWorktree = 'C:/Dropbox/whertzing/GitHub/ATAP.Utilities'
git config --global --add safe.directory $authorizedWorktree
```

Verify:

```powershell
git config --global --get-all safe.directory
```

Critical notes:

1. **Run as `SvcBuildMaster`, not as your interactive login.** This entry
   lives in the running user's `~/.gitconfig`. Running it from your
   developer account writes to the wrong user's gitconfig and the dubious
   ownership error persists.
2. **Never trust the parent GitHub directory.** Parent-wide trust silently authorizes
   current and future repositories that were not reviewed.
3. **Wildcards are not supported or acceptable here.** Add each authorized repository or
   worktree as an exact canonical path, and remove obsolete entries during return cleanup.

A common way to obtain a `SvcBuildMaster` shell from an admin login:

```powershell
$bmPassword = Get-SecretATAP -SecretName "SvcBuildMaster.Login.$($env:COMPUTERNAME.ToLowerInvariant())" -SecretField 'password'
$bmCred = New-Object System.Management.Automation.PSCredential(
  "$env:COMPUTERNAME\SvcBuildMaster",
  (ConvertTo-SecureString $bmPassword -AsPlainText -Force)
)
Start-Process pwsh -Credential $bmCred -ArgumentList '-NoExit', '-Command',
  'git config --global --add safe.directory C:/Dropbox/whertzing/GitHub/ATAP.Utilities; git config --global --get-all safe.directory'
```

Acceptance: the exact authorized paths appear in `safe.directory`, no parent-wide entry is
present, and a fresh BuildMaster build under `SvcBuildMaster` completes `dotnet restore` and
`Get-BuildContext` without a `dubious ownership` error.

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
. 'C:\Dropbox\whertzing\GitHub\<active-ATAP.Utilities-worktree>\src\_AdminRequiresHoldingPen\ATAP.Utilities.PowerShell\public\Install-ATAPModulesFromProGet.ps1'

Install-ATAPModulesFromProGet
```

Expected output (module base paths confirm `-Scope AllUsers`):

```text
[HH:mm:ss][Install-ATAPModulesFromProGet] Feed URI: https://utat022:50000/nuget/powershellget-stable/
[HH:mm:ss][Install-ATAPModulesFromProGet] Feed 'powershellget-stable' is reachable at https://utat022:50000/nuget/powershellget-stable/
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
  -SourceLocation    'https://utat022:50000/nuget/powershellget-stable/' `
  -PublishLocation   'https://utat022:50000/nuget/powershellget-stable/' `
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

> **Protocol note.** ProGet serves **HTTPS only** on `utat022:50000`; a plain `http://`
> request fails rather than redirecting. The certificate's SAN covers only `utat022`, so
> `localhost` is not a usable host name over TLS. Prefer driving these URIs from host
> settings (`$settings['ProGetFeedPowerShellStableUri']` and siblings) rather than the
> literals below. See
> [Feed-Protocol-HTTP-to-HTTPS-Migration.md](Feed-Protocol-HTTP-to-HTTPS-Migration.md).

```powershell
$feeds = @(
  @{ Name = 'powershellget-experimental'; Uri = 'https://utat022:50000/nuget/powershellget-experimental/' },
  @{ Name = 'powershellget-development';  Uri = 'https://utat022:50000/nuget/powershellget-development/' },
  @{ Name = 'powershellget-integration';  Uri = 'https://utat022:50000/nuget/powershellget-integration/' },
  @{ Name = 'powershellget-qa';           Uri = 'https://utat022:50000/nuget/powershellget-qa/' },
  @{ Name = 'powershellget-stable';       Uri = 'https://utat022:50000/nuget/powershellget-stable/' }
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

Two further families are registered as dotnet sources: the universal `releasebundle-*`
feeds (top tier is `production`, not `stable`) and the `database-*` feeds used by the
database-package pipeline. All must be `https://utat022:50000`. Confirm nothing remains on
plain HTTP across all four registration surfaces:

```powershell
Get-PSRepository         | Where-Object SourceLocation -like 'http://*'
Get-PSResourceRepository | Where-Object Uri            -like 'http://*'
dotnet nuget list source | Select-String 'http://'
```

All three must return nothing. Note that `Get-PSRepository` (PowerShellGet v2) and
`Get-PSResourceRepository` (PSResourceGet) are **separate stores** — migrating one leaves
the other broken.

### 9.10 Configure SystemParityMonitor on Windows 10 and Windows 11

Parity monitoring is a host-pair service, not merely a module import. The complete
installation, registration, first-run, rollback, and troubleshooting procedure is
intended to ship with the module at:

```text
$moduleRoot\Documentation\InstallationAndTroubleshooting.md
```

Version `0.1.1` omitted `Documentation\`; until SC-0264 is implemented, use the
canonical source copy under
`src\ATAP.Utilities.SystemParityMonitor.PowerShell\Documentation`.

An administrator must complete this checklist on each participating host:

1. Install the exact promoted `ATAP.Utilities.SystemParityMonitor.PowerShell` version
   for AllUsers. Resolve `$moduleRoot` below
   `C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell`.
2. Verify the installed package contains its `scripts\` and `Documentation\` folders.
   A package missing either folder is not deployment-complete. The live `0.1.1`
   installation required a temporary manual `scripts\` copy on both hosts; SC-0264
   owns the reproducible package fix, and source documentation remains authoritative
   until a corrected immutable version ships.
3. Create and enable the non-administrative `SvcParityAudit` account. Do not grant
   local Administrator membership to work around scheduled-task failures.
4. Create and ACL `C:\ProgramData\ATAP\ParityState`, its SMB share, journals,
   acknowledgements, snapshots, whitelist, and task-results folders as specified by
   the parity runbook.
5. Create the `\ATAP` Task Scheduler folder.
6. Grant `SvcParityAudit` `SeBatchLogonRight` while preserving every existing right
   holder. Confirm neither the account nor one of its governing policies assigns
   `SeDenyBatchLogonRight`. The guarded `secedit` pattern in §9.4.6.5 applies; add
   `SvcParityAudit` to the SID list.
7. As `SvcParityAudit` on that same host, provision and validate the
   `CommonCIForBitwardenReadOnly` DPAPI token. Never copy the token from another host
   or account, and never use `bw`/`BW_SESSION` in the scheduled path.
8. Register `AuditAndCompare` on the primary host with Password logon when peer SMB
   access needs reusable credentials. Register `AuditOnly` on the peer with S4U and a
   limited run level. When the elevated administrator and S4U run-as identities differ,
   supply the run-as credential during registration; Task Scheduler uses it to
   authorize registration while preserving S4U/no stored password in the task.
9. Run the peer audit, primary audit, and primary comparison in that order; require
   successful task-result JSON, fresh snapshots, a drift report, and no secret values
   in evidence.
10. Keep Daily cadence for the first clean month, then re-register as BiWeekly.

Windows 10 can require the inbox `ScheduledTasks` manifest to be imported by full path
from Windows PowerShell 5.1. The observed `utat01` endpoint omitted
`C:\Windows\System32\WindowsPowerShell\v1.0\Modules` from `PSModulePath`, which also
prevented normal autoload of `Microsoft.PowerShell.Utility` and `PowerShellGet`. Use
WinRM with `-ConfigurationName Microsoft.PowerShell` and absolute manifest paths for
the current recovery. SC-0266 tracks restoring a complete `PSModulePath` and adding a
PowerShell 7 (`pwsh`) endpoint; WinRM profile loading is separate work. Windows 11
normally exposes the cmdlets directly. The module runbook records the exact
compatibility checks and these live findings:

- the registration script must be dot-sourced before calling
  `Register-ParityScheduledTasks`; invoking the file with `&` intentionally performs no
  registration;
- `Get-Module -ListAvailable` in Windows PowerShell 5.1 may not enumerate a module
  whose manifest requires PowerShell 7, so discover `$moduleRoot` from the installed
  filesystem path;
- a PSFramework success message after `Register-ScheduledTask` reports an error is not
  proof; verify with `Get-ScheduledTask` and force registration errors to stop;
- version `0.1.1` fixed the historical Highest-run-level and false-success-log defects,
  but its S4U branch still omits the different run-as account's registration
  credential. `LOGON32_LOGON_BATCH` proved the account right is effective; COM and
  cmdlet registration without a credential returned `0x80070005`, while credential-
  backed COM registration succeeded and saved S4U (`2`) with Limited run level (`0`);
- do not infer that a batch right is absent merely because `secedit` exports the local
  account by name rather than literal SID; use an actual batch-logon test;
- `Find-Module` and `Install-Module` can resolve the stable NuGet v2 feed even when
  `Save-PSResource` returns 404 against its `FindPackagesById` request. Treat that as a
  promoted-test-runner/feed-protocol defect, not proof that the package is absent.

### 9.10a Verify Inedo service reachability by hostname (IPv4 and IPv6)

Run this on every host that runs or calls BuildMaster/ProGet, including `utat022`.

BuildMaster and ProGet already bind **all** IPv4 and IPv6 addresses — their
`Urls="http://*:PORT/"` configuration is correct and must not be changed. The failure this
step catches is a *host networking* problem: if the machine advertises global IPv6
addresses that are not actually routable, clients resolving the hostname try those first
and hang, producing 30-second timeouts that look like a broken service.

```powershell
# 1. Confirm BOTH families are listening. -p tcp prints ONLY the IPv4 table, so a service
#    can look "IPv4-only" when it is not. Always check tcpv6 as well.
netstat -ano -p tcp   | Select-String ':50017|:50000'
netstat -ano -p tcpv6 | Select-String ':50017|:50000'   # expect [::]:50017 and [::]:50000

# 2. Connect to every address the hostname resolves to. Any TIMEOUT row is the defect.
$addrs = [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME)
foreach ($a in $addrs) {
  $ip = $a.IPAddressToString
  $c  = [System.Net.Sockets.TcpClient]::new()
  try {
    $ok = $c.ConnectAsync($ip, 50017).Wait(4000)
    '{0,-46} {1}' -f $ip, $(if ($ok) { 'CONNECT' } else { 'TIMEOUT' })
  } catch { '{0,-46} FAILED' -f $ip } finally { $c.Dispose() }
}

# 3. If a global IPv6 address timed out, test whether it works at all:
ping -6 -n 2 <that-address>        # "General failure" => the address is dead, not the port
```

If global IPv6 addresses are dead, fix the host networking — do **not** edit
`BuildMaster.config`, `ProGet.config`, or `ServicePlacementMap`:

- Preferred: fix router/ISP DHCPv6 so the advertised prefix is routable, then re-test.
- If IPv6 is not used on this network, disable IPv6 on the adapter, or prefer IPv4 in
  address selection (elevated):

  ```powershell
  netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 60 4
  ```

- Interim: use `localhost` / `127.0.0.1` for host-local calls, and pass
  `-BuildMasterBaseUrl 'http://localhost:50017/'` to the release cmdlets.

> **Do not change `ServicePlacementMap['BuildMaster']` to `localhost`.** The BuildMaster
> base URL is derived from it, and so is the host-suffixed admin SecretName
> (`BuildMaster.Admin.API.Key.<service-host>`). Repointing the map silently rewrites the
> SecretName to one that does not exist in Bitwarden, turning a slow timeout into a hard
> credential failure.

Record the outcome with `Add-ParityChangeEntry` so the peer host shows a declared change
rather than undeclared drift.

### 9.10b Deploy the organization hosts file (name resolution)

Every managed host resolves the organization's static host names (`utat022`, `utat01`,
`ncat040`, printers, IoT devices, and so on) from a shared `hosts` file rather than from
DNS. The canonical source is a single template that is deployed to each computer.

**Canonical sources — do not hand-invent host names or IPs:**

- **Host names and IP assignments** come from the organization's canonical compute
  inventory (the `ansibleInventory` compute-inventory model). The concept is documented in
  [NewOrganizationSetup.md](NewOrganizationSetup.md) Appendix A ("The organization's hosts
  file (IP connectivity) is part of the package"); the machine-readable data lives in
  `ATAP.IAC` (`ansible/inventory` and the host-settings fragments). Router DHCP reservations
  must agree with these assignments before a name is added.
- **The hosts-file contents** are the ATAP.IAC template
  `Windows/NetworkResources/Hosts IP addresess.txt`. Per `ATAP.IAC/ReadMe.md` and
  `IAC-Windows-Scripts-Migration.md`, this is the static hosts-file template for Ansible
  deployment. Edit host entries **there**, never directly in a workstation's live file as
  the primary change — the live file is a deployment target, not the source of truth.

**Deploy the template to this workstation** (elevated; the target is a protected system
file):

```powershell
# Source: the canonical ATAP.IAC template (adjust the repo root to the active worktree).
$src = Join-Path $env:USERPROFILE 'Dropbox\whertzing\GitHub\ATAP.IAC\Windows\NetworkResources\Hosts IP addresess.txt'
$dst = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

# Back up the current file first, then deploy the template verbatim.
Copy-Item -LiteralPath $dst -Destination "$dst.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
Copy-Item -LiteralPath $src -Destination $dst -Force

# Flush the resolver cache so new entries take effect immediately.
Clear-DnsClientCache
```

Under the Ansible deployment model this copy is performed by the provisioning play rather
than by hand; the manual copy above is the fallback for a host not yet (or not currently)
driven by Ansible. Either way the template is the source, so a manual edit to a live
`hosts` file must be mirrored back into `Hosts IP addresess.txt` (and, ultimately, the
compute inventory) or it will be overwritten on the next deployment.

### 9.11 Junction AI agent memory to the Dropbox store

AI agent memory for the ATAP repositories is stored under Dropbox, outside every git
repository, so it survives sprint end and is available on every host:

```text
C:\Dropbox\whertzing\ATAP\AIAgentMemory\<RepoName>\
```

Claude Code does not read that path directly. It resolves memory under
`%USERPROFILE%\.claude\projects\<slug>\memory`, where `<slug>` is the repository path with
the drive letter lowercased and `:` `\` `_` `.` replaced by `-`. Each host therefore needs
**NTFS junctions** from the expected slug paths to the Dropbox store. Junctions are
host-local and do not sync, so this step is required on every new computer even though the
memory content arrives via Dropbox.

Two junctions are needed per repository, because Claude Code and the checkpoint tooling
resolve different slugs:

- **Main-repo slug** — Claude Code derives it from `git rev-parse --git-common-dir`, so for
  a worktree it resolves to the *main* repository. This is where Claude Code reads and
  writes memory, which is why memory is shared across all worktrees of a repo.
- **Sprint-worktree slug** — `Save-SprintWorkSession` derives its path from the transcript
  slug, which *is* the worktree. This is where `/checkpoint` looks for memory to archive.

```powershell
# Directory junctions do NOT require elevation.
$projects = Join-Path $env:USERPROFILE '.claude\projects'
$target   = 'C:\Dropbox\whertzing\ATAP\AIAgentMemory\ATAP.Utilities'
New-Item -ItemType Directory -Path $target -Force | Out-Null

# Repeat for each repo and active sprint worktree. Replace the symbolic
# worktree path with the current sprint path; never pin a sprint number here.
$repositoryPaths = @(
  'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
  'C:\Dropbox\whertzing\GitHub\<active-ATAP.Utilities-worktree>'
)
$slugs = $repositoryPaths | ForEach-Object {
  $_ -replace '[:\\_.]', '-'
}

foreach ($slug in $slugs) {
  $projDir = Join-Path $projects $slug
  New-Item -ItemType Directory -Path $projDir -Force | Out-Null
  $mem = Join-Path $projDir 'memory'
  if (Test-Path $mem) {
    if ((Get-Item $mem).LinkType) { Remove-Item -LiteralPath $mem -Force }
    else { throw "Refusing to clobber real directory: $mem" }
  }
  New-Item -ItemType Junction -Path $mem -Target $target | Out-Null
}

# Verify: both must report LinkType 'Junction' and the same target.
foreach ($slug in $slugs) {
  Get-Item (Join-Path $projects "$slug\memory") | Select-Object FullName, LinkType, Target
}
```

Verify end to end by running `/checkpoint` and confirming the roster entry reports
`MemorySnapshotCreated: true` with a non-zero `MemoryFileCount`.

Two things to know:

- **The worktree-slug junction is sprint-scoped**, but from SprintLifecycle `0.1.10`
  onward it is created automatically: `Set-SprintBoundaryContext -Boundary Start`
  provisions it for every worktree, and both `New-SprintStage1` and `New-SprintStage2`
  delegate to that function, so `_Planning` and every downstream repo are covered. The
  manual commands above are for **first-time host setup** and for repairing a worktree
  created before that version. If `DropboxBasePathConfigRootKey` is unresolvable the
  automatic step skips rather than guessing a path, and records the reason in the
  per-worktree result as `MemoryJunctionError`; a memory-junction failure never aborts
  sprint provisioning. Check `MemoryJunctionCreated` and `MemoryStorePath` on the
  `Set-SprintBoundaryContext` result to confirm.
- A missing junction fails silently — `Save-SprintWorkSession` reports
  `MemorySnapshotCreated: false` with reason "Memory directory not found" and still exits
  successfully, so checkpoints look healthy while archiving zero memory files.
- **Dropbox sync can produce conflicted copies** if two hosts write memory concurrently.
  An agent would read a `... (conflicted copy).md` file as an additional memory. This is
  accepted deliberately because the files are small and rarely written, but it is worth
  checking when memory content looks duplicated. Memory also propagates only as fast as
  Dropbox syncs, so a memory written on one host is not instantly visible on another.

These junctions are host-local configuration in scope for SystemParityMonitor; journal
their creation with `Add-ParityChangeEntry` so the peer host records a declared change
rather than undeclared drift.

## Step 9a: Provision the Elevated Install Broker

Agents and build tooling run unelevated, but an AllUsers module install writes under
`Program Files` and needs administrator rights. The elevated install broker performs those
installs on their behalf with no UAC interaction, so agents never issue a blind
`Start-Process -Verb RunAs` retry loop. Without it, `build-deploy-module` cannot complete
its final install step.

Prerequisites: the `SvcAnsibleAdmin` account and its Bitwarden secret from Step 5, and the
ProGet feeds from Step 9.

**Bootstrap order matters.** The broker is what installs modules AllUsers, so it must be
provisioned *before* the module-install machinery works. Run the provisioning function from
the **git clone**, not from an installed module:

```powershell
# ELEVATED pwsh. Adjust the clone path to the worktree you synced in Step 3.
$proGetModule = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.ProGet.PowerShell'
Import-Module "$proGetModule\ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1" -Force -DisableNameChecking

Register-ElevationBrokerTask -Verbose
```

`Register-ElevationBrokerTask` is idempotent and does all of the following:

- creates `C:\ProgramData\ATAP\ElevationBroker` with its `bin`, `requests`, `results`,
  `transcripts`, and `work` subfolders;
- copies the broker payload and the config template out of the module's
  `Resources\ElevationBroker`, never overwriting an existing `config.json` unless
  `-ForcePayload` is passed, because that file is the broker's trust anchor;
- applies a restrictive, non-inherited ACL to `requests\`. The broker **refuses to run**
  when `Everyone`, `Authenticated Users`, or `Users` can write there, since that would let
  any local account reach an administrator context;
- exports any existing task registration before replacing it;
- registers the `\ATAP\ATAP-ElevatedInstallBroker` scheduled task to run as
  `SvcAnsibleAdmin` with highest privileges, reading the password through `Get-SecretATAP`.

Then grant the developer account the right to start the task on demand:

```powershell
Grant-ElevationBrokerStartRights -Verbose
```

This step is **required**, not optional. The task has no repeating timer: it is started on
demand the moment a request is staged. Without start rights every request returns
`broker-unreachable`. The grant confers read + execute only, so the grantee can ask the
broker to drain its queue but cannot alter what the task runs.

Verify the whole path end to end from a **normal, non-elevated** shell — an elevated shell
would succeed through the `Administrators` ACE and prove nothing:

```powershell
$s = New-Object -ComObject Schedule.Service
$s.Connect()
$t = $s.GetFolder('\ATAP').GetTask('ATAP-ElevatedInstallBroker')
$t.Run($null)
Start-Sleep -Seconds 5
"result=$($t.LastTaskResult) lastrun=$($t.LastRunTime)"
```

Expect `result=0` and a current timestamp. Access denied means the grant did not target the
account that actually runs the build tooling.

Notes and gotchas:

- The task deliberately has **no repeating time trigger**. An earlier one-minute timer fired
  roughly 4,644 times to service 4 real requests and measurably contributed to CPU
  saturation. `BootTrigger` remains as the catch-up drain for requests staged while the
  broker could not run.
- `MultipleInstancesPolicy` must stay `Queue`. Under `-Once` the broker enumerates the
  requests folder exactly once, so `IgnoreNew` would silently strand a request staged while
  another instance was running.
- The client starts the task through the `Schedule.Service` COM API rather than
  `Start-ScheduledTask`, because the `ScheduledTasks` module is not present under
  PowerShell 7 on these hosts.

The broker is host-local configuration in scope for SystemParityMonitor; journal its
provisioning with `Add-ParityChangeEntry` so the peer host records a declared change rather
than undeclared drift. See `Runbook-ElevationBroker-PeerHost.md` for the peer-host steps.

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
3. Before extended DPOM, write classified `COPY_ONLY` backups with `CHECKSUM` under
   `C:\LocalDBs\PRODUCTION\Backup` and run `RESTORE VERIFYONLY`.
4. Keep backup contents outside Git and Dropbox. Evidence contains metadata such as path
   identity, size, hash, timestamp, and verification outcome, never database contents.
5. Never merge or restore ProGet/BuildMaster databases across hosts as workstation state;
   reconstruct outcomes from Git, packages, and reviewed configuration.
6. Retention, recovery objectives, monitoring, and rehearsal remain gated by Task 13.60.

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

On a Sprint branch, pass `-p:PackageLifeCycleStage=Sprint` consistently to split and
combined restore/build/test flows. Preserve the `ATAP5TIER001` guard. Omit the override on
`main`, where the stable/empty lifecycle label is valid.

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

### 11.5 Data API Builder SQL MCP servers

Install Data API Builder (DAB) as a user-global .NET tool and initialize separate
secret-free read-only (RO) and read-write (RW) configurations. The canonical AI adapter
starts DAB on demand in MCP stdio mode; it does not create a long-lived HTTP listener.

```powershell
Import-Module ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell

Initialize-DabMcpServer -Version '2.0.9'
Initialize-DabMcpConfiguration -ConfigPath "$env:APPDATA\ATAP\DataApiBuilder\ATAPUtilities\dab-ro-config.json" -ExposureMode AllEntitiesReadOnly
Initialize-DabMcpConfiguration -ConfigPath "$env:APPDATA\ATAP\DataApiBuilder\ATAPUtilities\dab-rw-config.json" -ExposureMode AllEntitiesReadWrite
Test-DabInstallation
```

The DAB configurations are stored at
`$env:APPDATA\ATAP\DataApiBuilder\ATAPUtilities\dab-ro-config.json` and
`$env:APPDATA\ATAP\DataApiBuilder\ATAPUtilities\dab-rw-config.json`. They contain
only the `@env('DAB_ATAPUTILITIES_CONNECTION_STRING')` reference; they never contain a
connection string or a `.env` file. Both autoentity configurations include every
supported object in every schema of their database, with names formed as
`{schema}_{object}`. For multiple Exp databases, provision one RO/RW configuration and
one Bitwarden connection-string secret per database; DAB requires a separate data source
configuration for each database.

Codex and Claude Code receive six canonical, user-scope MCP registrations:
`dab-ataputilities-production`, `dab-ataputilities-qa`,
`dab-ataputilities-integration`, `dab-ataputilities-dev`,
`dab-RO-ataputilities-exp`, and `dab-RW-ataputilities-exp`. Each registration launches
an explicit tier and role, so a request cannot silently fall through to a different SQL
instance or privilege level.
The registrations invoke the dedicated `Mcp/Start-DabMcpServer.ps1` launcher rather
than importing the full DotnetBuild module: an MCP stdio process must reserve stdout
for JSON-RPC, while unrelated module-import warnings corrupt the protocol. DAB starts
Kestrel even in stdio mode, so the registrations also use separate loopback endpoints:
Dev `5101`, Exp RO `5102`, Integration `5103`, Production `5104`, QA `5105`, and Exp
RW `5106`. These ports must not be used by the normal DAB host or another MCP
registration.

At startup, the dedicated MCP launcher derives the local host's BWS SecretName with
`Get-DbConnectionStringSecretDescriptor`, resolves it through
`Get-SecretATAP -SecretStoreType BitwardenSecretsManager`, and assigns the result only
to the DAB child-process environment. The resolved value must not be displayed,
persisted, added to agent settings, or written to `.env`. The secret names follow this
shape:

```text
dbConnectionString.ATAPUtilities.<current-host>.Production
dbConnectionString.ATAPUtilities.<current-host>.QA
dbConnectionString.ATAPUtilities.<current-host>.Integration
dbConnectionString.ATAPUtilities.<current-host>.Dev.<current-user>
dbConnectionString.ATAPUtilities.<current-host>.Exp.<current-user>
```

After the shared MCP catalog is rendered and the agent application is restarted, open
the MCP status surface and confirm that all six DAB servers appear. Start with the RO
Exp server. Its autoentity configuration grants `mcp-reader:read` only. The RW Exp
configuration grants `mcp-writer:create,read,update,delete` and enables the corresponding
MCP DML tools. DAB 2.0.9 rejects `execute` in autoentity permissions, so stored-procedure
execution is deliberately not exposed by this server; it needs a separately designed,
allow-listed MCP capability. Both roles are DAB exposure controls, not SQL permissions:
until SC-0312 is delivered, the RW connection string uses Windows authentication with
full database access. DAB's stdio mode requires `runtime.mcp.enabled` and keeps protocol
messages on stdout; use `--LogLevel Error` as the canonical launcher does. See [DAB stdio transport](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/stdio-transport)
and [DAB environment substitution](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/config/env-function).

### 11.6 Mobile-host and Class A certification

Before a mobile workstation is considered ready for extended DPOM, record metadata-only
proof for:

1. BitLocker fully encrypted with protection on; anti-malware current; time synchronized.
2. Sleep/hibernate, battery-sensitive scheduled tasks, Windows support/EOS, and public-network
   behavior reviewed.
3. NordVPN Internet Kill Switch and the trusted-network rule tested before cloud access.
4. Local SQL and Inedo health, one value-discarding SecretName resolution, representative
   restore/build/test, GitHub authentication, and Dropbox continuity.
5. A live off-LAN gate where peer services are unreachable and local Class A work still passes.
6. A bounded return drill that reconciles parity journals and path/hash-only AI intent,
   transfers immutable packages by hash, and reconstructs BuildMaster outcomes without copying
   Inedo databases.

Class B/full-offline secret use is separately limited and is not implied by a Class A pass.
If a parity-share read encounters Windows double hop, use the documented temporary
credentialed-PSDrive workaround with a credential resolved by SecretName. Do not weaken
remoting globally; hardened transport remains deferred to `SC-0242`.

## Ready State

The new computer is ready for a developer when all of the following are true:

1. Dropbox is settled; conflict/reparse and tracked-file integrity checks pass; every Git
   trust entry is an exact authorized path.
2. The multi-host overview, machine-local sprint retarget, `.vscode` junction, and concrete AI
   adapter renders match the current host assignment.
3. Developer and service-account profiles load from canonical ATAP.IAC templates in the paths
   PowerShell actually uses; direct and profiled-remoting identity probes pass or carry an
   explicit deferred exception.
4. The `SecretName/Get-SecretATAP/bws` automation boundary and separate personal `bw`/`BW_SESSION` boundary are respected. Host settings and
   callers contain SecretNames only; no raw API-key environment-variable readiness claim is
   permitted.
5. The declared Java/package owners and Flyway resolution pass, or the deferred Java decision
   is recorded without claiming canonicalization.
6. SQL Server `Devwhertzing`, `Expwhertzing`, `Integration`, `QA`, and `Production` are verified
   under their distinct data classifications. Required local backups pass checksum and restore
   verification outside Git/Dropbox.
7. ProGet answers on `50000` with its package-root, license, feed inventory, ACL, and package
   proof complete. BuildMaster answers on `50017` with supported application definitions and a
   full readiness assertion.
8. Stable-branch builds/tests pass; Sprint-branch flows pass with the lifecycle override.
9. Mobile security, Class A off-LAN, GitHub/Dropbox continuity, and bounded return evidence pass.
10. Every acceptance record distinguishes source, deploy, service, and operator state and
    contains metadata only. Unresolved HITL/deferred gates remain named rather than silently
    treated as complete.

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

Sprint-start — set to the sprint worktree venv (example sprint `<active-sprint-branch>`):

```jsonc
// In SharedVSCode/UserSettings.jsonc
"manim-sideview.defaultManimPath": "C:\\Dropbox\\whertzing\\GitHub\\<active-ATAP.Utilities-worktree>\\ManimVideoGenerator\\.venv\\Scripts\\manim.exe",
"python.defaultInterpreterPath": "C:\\Dropbox\\whertzing\\GitHub\\<active-ATAP.Utilities-worktree>\\ManimVideoGenerator\\.venv\\Scripts\\python.exe",
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
C:\Dropbox\whertzing\GitHub\Overview.Sprint.0007.code-workspace
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
  -WorkspacePath 'C:\Dropbox\whertzing\GitHub\Overview.Sprint.0007.code-workspace' `
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

Document the Antigravity integration in terms of an active workspace file and a generated local config, rather than naming a specific sprint file such as `Overview.Sprint.0007.code-workspace`, because that filename changes every sprint.

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
