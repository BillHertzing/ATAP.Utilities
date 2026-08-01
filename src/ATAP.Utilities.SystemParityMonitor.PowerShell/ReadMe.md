# ATAP.Utilities.SystemParityMonitor.PowerShell

System parity journal and audit tooling for host-pair operations. A pair of
workstations (for example `utat022` and `utat01`) each record intentional
configuration changes in a parity journal, take periodic audit snapshots of their
configuration surfaces, and compare snapshots to detect undeclared drift between the
two machines.

Moved from ATAP.IAC `Windows\Parity` (module `ATAP.IAC.Parity.PowerShell`) in
Sprint 0012 Task 12.46; public function names are unchanged.

## Public functions

| Function | Purpose |
| --- | --- |
| `Add-ParityChangeEntry` | Append an intentional-change entry to the local parity journal |
| `Get-ParityPrimaryRole` | Read and validate the local Task 12.59 `PrimaryRole.json` marker |
| `Set-ParityPrimaryRole` | Atomically write the human-authorized local DPOM entry or exit marker |
| `Get-PeerPendingChanges` | List peer journal entries not yet acknowledged locally |
| `Confirm-ParityChangeApplied` | Acknowledge a peer change as applied locally |
| `Invoke-ParityAudit` | Capture local configuration surfaces, including Chocolatey, pip, npm, and NuGet-managed package versions and cross-manager ownership conflicts |
| `Compare-ParityAudits` | Compare two hosts' snapshots and classify drift (declared / whitelisted / undeclared / stale) |

## Layout

- `public\`, `private\` — one function per file; no top-level executable code
- `scripts\` — scheduled-task wrappers (`Invoke-ParityScheduledAuditTask.ps1`,
  `Invoke-ParityScheduledCompareTask.ps1`), interactive first-run helper
  `Invoke-ParityTaskAndWait.ps1`, shared scheduled-task helper
  `ParityScheduledTask.Common.ps1`, and `Register-ParityScheduledTasks.ps1` (the
  executable scripts are dual-purpose and `&`-proof guarded)
- `tests\Unit\` — Pester suite
- `Documentation\` — module documentation (see `Documentation\Overview.md`); images in
  `Documentation\images\`

Start with `Documentation\InstallationAndTroubleshooting.md` for the deployed-layout
contract, Windows 10/11 prerequisites, registration commands, first-run proof, and
known live-registration failure modes.

## DPOM role marker

`Set-ParityPrimaryRole` implements the Task 12.59 schema without remoting. It writes
one canonical record at
`C:\Dropbox\whertzing\ATAP\ParityState\PrimaryRole.json`. Run it once on either
host only after a human authorizes the entry or exit and `Add-ParityChangeEntry`
returns the journal ID referenced by the marker. Wait for Dropbox to report
`Up to date` before shutting down or disconnecting the other host. Never run
simultaneous marker writes on both hosts.

```powershell
$entry = Add-ParityChangeEntry `
  -Category Runbook `
  -Item 'DPOM primary role' `
  -OldValue 'utat022' `
  -NewValue 'utat01' `
  -PeerHostName 'utat022' `
  -PeerActionKind Manual `
  -PeerAction 'Write the matching authorized PrimaryRole.json marker.' `
  -Reason 'first Class A test'

Set-ParityPrimaryRole `
  -PrimaryRole 'utat01' `
  -PlannedAbsenceHostName 'utat022' `
  -Reason 'first Class A test' `
  -AuthorizedBy 'Bill Hertzing' `
  -JournalEntryId $entry.Id
```

The sprint-boundary workflow validates this stable operational path. It can
migrate a lone legacy marker from `C:\ProgramData\ATAP\ParityState` when no
shared marker exists, but it refuses to choose between differing local and
shared markers.

An exit marker restores the normal primary and has no planned absence:

```powershell
Set-ParityPrimaryRole `
  -PrimaryRole 'utat022' `
  -Reason 'DPOM exit' `
  -AuthorizedBy 'Bill Hertzing' `
  -JournalEntryId $exitEntry.Id
```

## Deployment notes

- State root: `C:\ProgramData\ATAP\ParityState` (journal, acks, audit snapshots,
  task results); peer state is read over an SMB share (default `\\utat01\ParityState`).
- Scheduled tasks run under the dedicated `SvcParityAudit` identity by default and
  require no Bitwarden/BWS token, `BW_SESSION`, credential directory, or vault probe.
  Successful task-result JSON records `SecretAccessRequired = false`; the wrappers
  also avoid remoting.
- Register `AuditOnly` on peer hosts and `AuditAndCompare` on the primary host
  (`utat022`). The peer uses `-LogonType S4U` with `RunLevel Limited`. The primary may
  use `-LogonType Password -Credential <PSCredential>` when its compare action needs
  authenticated access to the peer SMB share; that Windows credential is unrelated
  to secret-vault access.
- When an administrator registers an S4U task for a different account, supply that
  account's credential at registration while retaining S4U in the saved principal.
  Version `0.1.3` uses Task Scheduler COM for this credential-backed registration;
  the task definition remains S4U/Limited and does not persist the registration
  password. This is the deployed peer audit topology now that the wrapper has no
  per-user DPAPI or vault dependency. Version `0.1.2` could incorrectly persist a
  Password principal on the peer and must not be used for new S4U registrations.
- Cadence is `Daily` during the first onboarding month; re-register with
  `-Cadence BiWeekly` after the first clean month. The compare wrapper passes the
  expected cadence into `Compare-ParityAudits`, which flags snapshots older than
  `1.5x` cadence as stale.
- Package collection covers Chocolatey local packages, pip packages for the active
  `python` interpreter, npm global packages, and NuGet-managed global .NET tools.
  Package/version rows compare normally between hosts. A normalized package name
  found under multiple managers produces a host-qualified `PackageManagerConflict`
  row whose value begins `ACTION REQUIRED`; this keeps the conflict visible in the
  drift report even when both hosts have made the same conflicting manager choices.
  Operators must choose one owning manager and remove the duplicate installation.
- BuildMaster: consolidated application `ATAP.Utilities-PowerShell` (see the reviewed
  module map in the ATAP.IAC BuildMaster HostSettings fragment).
- Packaging preserves the `scripts\` and `Documentation\` folders below the installed
  module root. A package missing either folder is not deployable for parity monitoring.
  Version `0.1.2` replaces the temporary manual `scripts\` copy used for 0.1.1.

## Functional area

Environment / Workstation Setup - START HERE: SolutionDocumentation\NewComputerSetup.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
