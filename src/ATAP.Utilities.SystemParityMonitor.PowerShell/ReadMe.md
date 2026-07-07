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
  `Invoke-ParityScheduledCompareTask.ps1`) and `Register-ParityScheduledTasks.ps1`
  (dual-purpose, `&`-proof guarded)
- `tests\Unit\` — Pester suite
- `Documentation\` — module documentation (see `Documentation\Overview.md`); images in
  `Documentation\images\`

## Deployment notes

- State root: `C:\ProgramData\ATAP\ParityState` (journal, acks, audit snapshots,
  task results); peer state is read over an SMB share (default `\\utat01\ParityState`).
- Scheduled tasks resolve the invoking user's BWS access token from
  `C:\ProgramData\ATAP\BitwardenCredentials` — secrets by SecretName only.
- BuildMaster: consolidated application `ATAP.Utilities-PowerShell` (see the reviewed
  module map in the ATAP.IAC BuildMaster HostSettings fragment).

## Functional area

Environment / Workstation Setup - START HERE: SolutionDocumentation\NewComputerSetup.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
