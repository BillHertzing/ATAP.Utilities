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
| `Get-PeerPendingChanges` | List peer journal entries not yet acknowledged locally |
| `Confirm-ParityChangeApplied` | Acknowledge a peer change as applied locally |
| `Invoke-ParityAudit` | Capture an audit snapshot of the local configuration surfaces |
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

## Deployment notes

- State root: `C:\ProgramData\ATAP\ParityState` (journal, acks, audit snapshots,
  task results); peer state is read over an SMB share (default `\\utat01\ParityState`).
- Scheduled tasks run under the dedicated `SvcParityAudit` identity by default and
  resolve that identity's purpose-specific `CommonCIForBitwardenReadOnly` DPAPI token
  via `Get-BWSAccessToken -TokenPurpose ReadOnly`; the wrappers never use `bw`,
  `BW_SESSION`, or remoting.
- Register `AuditOnly` on peer hosts and `AuditAndCompare` on the primary host
  (`utat022`). Both roles use `-LogonType Password -Credential <PSCredential>` because
  the current wrappers decrypt a per-user DPAPI BWS token; the peer remains
  `RunLevel Limited`, while the primary uses `Highest` and its reusable credential to
  read the peer SMB share.
- When an administrator registers an S4U task for a different account, supply that
  account's credential at registration while retaining S4U in the saved principal.
  Version `0.1.3` uses Task Scheduler COM for this credential-backed registration;
  the task definition remains S4U/Limited and does not persist the registration
  password. This capability is for tasks that do not decrypt per-user DPAPI material;
  it is not the deployed parity-wrapper topology. Version `0.1.2` could incorrectly
  persist a Password principal on the peer and must not be used for new S4U
  registrations.
- Cadence is `Daily` during the first onboarding month; re-register with
  `-Cadence BiWeekly` after the first clean month. The compare wrapper passes the
  expected cadence into `Compare-ParityAudits`, which flags snapshots older than
  `1.5x` cadence as stale.
- BuildMaster: consolidated application `ATAP.Utilities-PowerShell` (see the reviewed
  module map in the ATAP.IAC BuildMaster HostSettings fragment).
- Packaging preserves the `scripts\` and `Documentation\` folders below the installed
  module root. A package missing either folder is not deployable for parity monitoring.
  Version `0.1.2` replaces the temporary manual `scripts\` copy used for 0.1.1.

## Functional area

Environment / Workstation Setup - START HERE: SolutionDocumentation\NewComputerSetup.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
