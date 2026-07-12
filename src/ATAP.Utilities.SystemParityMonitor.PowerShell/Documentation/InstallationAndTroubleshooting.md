# SystemParityMonitor Installation and Troubleshooting

This runbook installs and validates `ATAP.Utilities.SystemParityMonitor.PowerShell`
on a Windows host pair. It records the operational lessons from the first live
Sprint 0012 Task 12.38.e registration attempt on Windows 11 `utat022` and Windows 10
`utat01`.

The architecture overview is in [Overview.md](Overview.md). The workstation-level
entry point is `SolutionDocumentation\NewComputerSetup.md`.

## Intended topology

| Host role | Example host | Scheduled tasks | Task logon |
| --- | --- | --- | --- |
| Primary | `utat022` | `ATAP-ParityAudit`, `ATAP-ParityCompare` | `Password` when the compare task needs reusable SMB credentials |
| Peer | `utat01` | `ATAP-ParityAudit` only | `S4U` for the local-only audit |

The scheduled runtime performs no PowerShell remoting. Each host writes its own
snapshot to `C:\ProgramData\ATAP\ParityState`; the primary compare task reads the
peer's `ParityState` SMB share.

## Security invariants

- Run tasks under the dedicated local `SvcParityAudit` account.
- Do not add `SvcParityAudit` to the local Administrators group to work around task
  registration or runtime failures.
- Give the account `SeBatchLogonRight` (Log on as a batch job), and ensure it is not
  covered by `SeDenyBatchLogonRight`.
- Provision only the purpose-specific `CommonCIForBitwardenReadOnly` token unless a
  separate, approved secret-maintenance workflow needs ReadWrite access.
- Create the DPAPI token on the target host while running as the target account. A
  token file copied from another host or account cannot be decrypted.
- Never put passwords, access tokens, secret values, or `BW_SESSION` in commands,
  task arguments, journals, evidence, or documentation.
- Record each machine-state change with `Add-ParityChangeEntry` before applying it.

## Deployment contract

Set `$moduleRoot` to the exact installed module version that will own the scheduled
task actions. Do not register tasks against a sprint-worktree path: the path is
ephemeral and disappears at sprint end.

```powershell
$moduleParent = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell'
$moduleRoot = Get-ChildItem -LiteralPath $moduleParent -Directory |
  Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'scripts\Register-ParityScheduledTasks.ps1')
  } |
  Sort-Object { [version]$_.Name } -Descending |
  Select-Object -First 1

if (-not $moduleRoot) {
  throw "No installed SystemParityMonitor package with scheduler scripts was found under '$moduleParent'."
}

$moduleRoot = $moduleRoot.FullName
```

The deployed module root must contain all of these files:

```text
$moduleRoot\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1
$moduleRoot\ATAP.Utilities.SystemParityMonitor.PowerShell.psm1
$moduleRoot\scripts\ParityScheduledTask.Common.ps1
$moduleRoot\scripts\Invoke-ParityScheduledAuditTask.ps1
$moduleRoot\scripts\Invoke-ParityScheduledCompareTask.ps1
$moduleRoot\scripts\Register-ParityScheduledTasks.ps1
$moduleRoot\Documentation\Overview.md
$moduleRoot\Documentation\InstallationAndTroubleshooting.md
```

If `scripts` or `Documentation` is missing from a promoted package, the package is not
deployment-complete. Correct the module build and packaging contract, publish a new
immutable version, install that exact version, and verify it from a fresh shell. The
missing-static-folder packaging capability is tracked as SC-0264.

Live exception recorded 2026-07-11: version `0.1.1` was promoted and installed for
AllUsers on `utat022` and `utat01`, but the package omitted both static folders. The
operator manually copied `scripts\` into the PowerShell 7 module roots on both hosts to
unblock Task 12.38.e. Treat those hosts as manually repaired, not reproducibly deployed;
do not use that exception as the normal installation procedure. `Documentation\` remains
available from source until SC-0264 is implemented and a new immutable version is
published.

## Prerequisites on every host

1. Install PowerShell 7 and ensure `pwsh.exe` is visible through machine-scope
   `PATH`; scheduled tasks do not inherit a newly changed process-only path.
2. Install the exact promoted SystemParityMonitor package for AllUsers.
3. Create and enable the local `SvcParityAudit` account.
4. Create `C:\ProgramData\ATAP\ParityState`, its journal/ack/snapshot structure, and
   the host-owned SMB share/ACL configuration described in Task 12.38.c.
5. Create the Task Scheduler folder `\ATAP`.
6. Grant `SvcParityAudit` `SeBatchLogonRight` without replacing existing right
   holders. Use the guarded procedure in `SolutionDocumentation\NewComputerSetup.md`.
7. Provision the ReadOnly BWS DPAPI token as `SvcParityAudit` on that host.
8. Verify `bws.exe` is machine-visible and the token resolves without using `bw`,
   `BW_SESSION`, an interactive login, browser authentication, or email verification.

The expected token file is:

```text
C:\ProgramData\ATAP\BitwardenCredentials\SvcParityAudit\<HOST>_SvcParityAudit_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml
```

Verify presence without reading or printing its contents:

```powershell
$tokenPath = Join-Path `
  'C:\ProgramData\ATAP\BitwardenCredentials\SvcParityAudit' `
  "$($env:COMPUTERNAME)_SvcParityAudit_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml"

Test-Path -LiteralPath $tokenPath -PathType Leaf
```

## Windows 10 ScheduledTasks compatibility

PowerShell 7 on Windows 10 may not discover `New-ScheduledTaskAction`,
`New-ScheduledTaskPrincipal`, or the other inbox `ScheduledTasks` cmdlets. The
module can still be present at the Windows PowerShell 5.1 system-module path.

Use the Windows PowerShell 5.1 WinRM endpoint for registration and import the
manifest by its full path:

```powershell
$scheduledTasksManifest = Join-Path `
  $env:WINDIR `
  'System32\WindowsPowerShell\v1.0\Modules\ScheduledTasks\ScheduledTasks.psd1'

Import-Module -Name $scheduledTasksManifest -ErrorAction Stop
```

If the manifest is absent, repair the Windows component; do not install a similarly
named gallery module or copy the Windows 11 module onto Windows 10. If the manifest
exists but `Get-Module -ListAvailable` does not list it, full-path import is the
supported local workaround.

On the observed `utat01` Windows 10 WinRM endpoint, `PSModulePath` omitted
`C:\Windows\System32\WindowsPowerShell\v1.0\Modules`. This also prevented normal
autoload of `Microsoft.PowerShell.Utility` and therefore `PowerShellGet`. Import inbox
manifests by absolute path for the current recovery procedure. SC-0266 tracks correcting
the machine/profile `PSModulePath` and registering a PowerShell 7 (`pwsh`) WinRM
endpoint. Whether profiles should run in WinRM sessions is separate work.

An administrator can use WinRM from the primary host to perform registration on the
peer. Force the `Microsoft.PowerShell` endpoint so the remote runspace is Windows
PowerShell 5.1:

```powershell
Invoke-Command `
  -ComputerName 'utat01' `
  -Credential $remotingCredential `
  -ConfigurationName 'Microsoft.PowerShell' `
  -ScriptBlock {
    $PSVersionTable.PSVersion
  }
```

Source-host elevation does not guarantee remote elevation. Verify the remote token
before changing state:

```powershell
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

## Create the Task Scheduler folder

`Register-ScheduledTask -TaskPath '\ATAP\'` requires the folder to exist and be
writable. Create it once from an elevated Windows PowerShell session:

```powershell
$scheduler = New-Object -ComObject 'Schedule.Service'
$scheduler.Connect()

try {
  $folder = $scheduler.GetFolder('\ATAP')
}
catch {
  $root = $scheduler.GetFolder('\')
  $folder = $root.CreateFolder('ATAP', $null)
}

$folder.Path
```

Expected output is `\ATAP`.

## Register tasks

`Register-ParityScheduledTasks.ps1` is a dual-purpose script. It intentionally does
not execute its registration function when invoked through the call operator (`&`).
Dot-source it and invoke `Register-ParityScheduledTasks`, or run the script through
`pwsh -File`. A call such as `& $registrationScript ...` returns silently and creates
no tasks.

```powershell
$registrationScript = Join-Path $moduleRoot 'scripts\Register-ParityScheduledTasks.ps1'
. $registrationScript
Get-Command Register-ParityScheduledTasks -ErrorAction Stop
```

### Primary host

The compare task reads `\\utat01\ParityState`, so it normally needs a Password-logon
principal whose password is supplied only through a `PSCredential` variable.

```powershell
$parameters = @{
  TaskSet             = 'AuditAndCompare'
  HostName            = 'utat022'
  RightHostName       = 'utat01'
  RightStatePath      = '\\utat01\ParityState'
  Cadence             = 'Daily'
  AuditTime           = '03:00'
  CompareTime         = '03:30'
  ExpectedCadenceDays = 1
  StaleMultiplier     = 1.5
  RunAsAccountName    = 'SvcParityAudit'
  LogonType           = 'Password'
  Credential          = $svcCredential
}

Register-ParityScheduledTasks @parameters -WhatIf
Register-ParityScheduledTasks @parameters
```

### Peer host

The peer registers only its local audit task. The intended least-privilege principal
is S4U with `RunLevel Limited`.

```powershell
$parameters = @{
  TaskSet          = 'AuditOnly'
  HostName         = 'utat01'
  Cadence          = 'Daily'
  AuditTime        = '03:00'
  RunAsAccountName = 'SvcParityAudit'
  LogonType        = 'S4U'
  Credential       = $svcCredential
  RunLevel         = 'Limited'
}
```

The credential is required at registration because the elevated administrator is
registering an S4U task for a different account. The resulting task remains S4U and
does not store the password. A direct `LOGON32_LOGON_BATCH` test on `utat01` proved
that `SvcParityAudit` can perform a batch logon; `TaskFolder.RegisterTaskDefinition`
without the credential still returned `0x80070005`, and the same call succeeded once
the credential was supplied. See Microsoft's
[Security Contexts for Tasks](https://learn.microsoft.com/en-us/windows/win32/taskschd/security-contexts-for-running-tasks)
for the distinct registration-credential and saved-principal rules.

### Version 0.1.1 S4U limitation and live recovery

Version `0.1.1` corrected the earlier `RunLevel Highest` defect by selecting
`Limited` for `AuditOnly` + `S4U` and made registration errors terminating. It still
passes `-Credential` only for `LogonType Password`; therefore its S4U branch cannot
supply the credential required when an administrator registers for the different
`SvcParityAudit` identity. Both `Register-ScheduledTask` and direct Task Scheduler COM
registration without that credential return `0x80070005` on `utat01`.

For the live recovery, the administrator built the normal audit task definition and
called `TaskFolder.RegisterTaskDefinition` with the service-account username and
password while keeping logon type `2` (`TASK_LOGON_S4U`) and run level `0`
(`TASK_RUNLEVEL_LUA`). Registration succeeded with this verified result:

```text
TaskName  : ATAP-ParityAudit
TaskPath  : \ATAP\ATAP-ParityAudit
RunAs     : SvcParityAudit
LogonType : 2
RunLevel  : 0
NextRun   : 7/12/2026 3:00:00 AM
```

The durable correction is to make the script use credential-backed registration for
S4U when the caller and task identities differ, retain the S4U principal in the saved
definition, add a focused Pester contract, and publish a new immutable version. Task
12.38.e remains open until first-run snapshots and the primary drift report are proven.

## Verify registration

Logging is not proof of registration. Historical version `0.1.0` can emit a
`Registered scheduled task` PSFramework message after a non-terminating
`Register-ScheduledTask` error. Version `0.1.1` corrected this with
`-ErrorAction Stop`, but direct Task Scheduler state remains authoritative:

```powershell
Get-ScheduledTask -TaskPath '\ATAP\' |
  Where-Object TaskName -like 'ATAP-Parity*' |
  Select-Object TaskName, State,
    @{ Name = 'RunAs'; Expression = { $_.Principal.UserId } },
    @{ Name = 'LogonType'; Expression = { $_.Principal.LogonType } },
    Actions, Triggers |
  Format-List
```

Expected topology:

- `utat022`: audit and compare, both Ready, Password logon.
- `utat01`: audit only, Ready, S4U logon, limited run level.
- Every action path is below the installed `$moduleRoot`, never a sprint worktree.

## First-run proof

Run tasks in this order so both snapshots exist before comparison:

1. Start `ATAP-ParityAudit` on the peer.
2. Wait for it to finish and verify `LastTaskResult` is zero.
3. Start `ATAP-ParityAudit` on the primary.
4. Wait for it to finish and verify `LastTaskResult` is zero.
5. Start `ATAP-ParityCompare` on the primary.

```powershell
Start-ScheduledTask -TaskPath '\ATAP\' -TaskName 'ATAP-ParityAudit'
Get-ScheduledTaskInfo -TaskPath '\ATAP\' -TaskName 'ATAP-ParityAudit'
```

Audit and compare results are written below:

```text
C:\ProgramData\ATAP\ParityState\TaskResults
```

Require all of the following before closing Task 12.38.e:

- task result JSON has `Success = true`;
- `IdentityName` is the intended `SvcParityAudit` account;
- the BWS probe succeeds using `CommonCIForBitwardenReadOnly`;
- both fresh audit snapshots exist;
- compare result JSON identifies its report path;
- immediate first-run `StaleSnapshotCount` is zero;
- undeclared drift is zero or is explicitly investigated and dispositioned;
- no secret values appear in the evidence.

Use Daily cadence during the first clean month. Re-register with `BiWeekly` afterward;
the default 14-day expected cadence and `1.5` multiplier make the stale threshold 21
days.

## Troubleshooting matrix

| Symptom | Cause or diagnostic | Corrective action |
| --- | --- | --- |
| `& $registrationScript` returns with no tasks | The script's `&`-proof guard intentionally skips call-operator execution | Dot-source the script, then invoke `Register-ParityScheduledTasks` |
| `New-ScheduledTaskPrincipal` or related commands are not found on Windows 10 | PowerShell 7 did not discover the Windows PowerShell inbox module | Use the `Microsoft.PowerShell` WinRM endpoint and import `ScheduledTasks.psd1` by full path |
| `Join-Path` says `Path` is null | Windows PowerShell 5.1 did not enumerate the PowerShell 7-only module manifest | Resolve `$moduleRoot` from `C:\Program Files\PowerShell\Modules` and verify the registration script exists |
| `TaskPath '\ATAP\'` finds nothing | The scheduler folder does not exist | Create `\ATAP` through `Schedule.Service` before registration |
| Registration or runtime reports batch-logon failure | `SvcParityAudit` lacks effective `SeBatchLogonRight`, or a deny right applies | Preserve existing rights and verify with a `LOGON32_LOGON_BATCH` test; `secedit` may export a local account by name, so absence of a literal SID is not proof that the right is absent |
| Version 0.1.0 peer registration returns `Access is denied` | It requests Highest run level for a non-admin account | Upgrade; do not add the service account to Administrators |
| Version 0.1.1 peer S4U registration returns `0x80070005` although batch logon succeeds | An administrator is registering for a different account without supplying that account's registration credential | Supply the `SvcParityAudit` credential while preserving S4U/Limited in the task definition; publish the durable script fix in a new immutable version |
| Windows 10 WinRM cannot autoload inbox modules | The endpoint's `PSModulePath` omits the Windows PowerShell system-module root | Import manifests by absolute path for recovery; fix `PSModulePath` and add a `pwsh` endpoint under SC-0266 |
| `Find-Module` succeeds but promoted testing gets `Save-PSResource` HTTP 404 | The registered stable feed works through PowerShellGet/NuGet v2, while the PSResourceGet request shape is rejected | Do not claim promoted tests passed; record the exact URL/error, use `Find-Module`/`Install-Module` only when explicitly authorized, and fix the promoted-test runner or feed protocol separately |
| Error followed by `Registered scheduled task` | Registration error was non-terminating and the logger ran anyway | Treat the error and `Get-ScheduledTask` as authoritative; update code to use `-ErrorAction Stop` and log only after success |
| Headroom proxy warning appears during a nested `pwsh` call | The child PowerShell process loaded the user's profile | Treat the warning as unrelated unless the child command fails; capture the complete error record |
| `Add-ParityChangeEntry` asks for mandatory parameters from a nested command string | Backtick continuations were consumed while building a double-quoted here-string | Use a parameter hashtable and splatting inside the child command string |
| BWS token file exists but decryption fails | The DPAPI file was created under another identity or host | Re-provision it as `SvcParityAudit` on the same host; never copy it |
| Task result JSON is absent | Wrapper failed before or while creating the result directory, or the task never started | Inspect `LastTaskResult`, Task Scheduler history, Application event IDs 12380/12381, action path, and account rights |
| Compare cannot read the peer share | S4U has no reusable network credential, share/NTFS ACL is wrong, or peer state is absent | Use Password logon on the primary compare task and verify read-only SMB access without printing credentials |

## Evidence and rollback

Store sprint verification evidence in the repository-root `_generated` folder. Record
host, task, installed version/path, principal, logon type, trigger, task result,
snapshot/report paths, BWS probe status, stale count, and drift classification.

Rollback unregisters only the affected task definitions; it does not delete parity
journals, snapshots, acknowledgements, task-result JSON, BWS DPAPI files, or the
`ParityState` share. Journal the rollback before applying it.

```powershell
Unregister-ScheduledTask `
  -TaskPath '\ATAP\' `
  -TaskName 'ATAP-ParityAudit' `
  -Confirm:$false
```
