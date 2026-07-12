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
  `Invoke-ParityScheduledCompareTask.ps1`), shared scheduled-task helper
  `ParityScheduledTask.Common.ps1`, and `Register-ParityScheduledTasks.ps1`
  (dual-purpose, `&`-proof guarded)
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
  (`utat022`). The compare task reads the peer share, so live primary-host
  registration may need `-LogonType Password -Credential <PSCredential>` rather than
  `S4U` when SMB access requires reusable service-account credentials.
- When an administrator registers an S4U task for a different account, supply that
  account's credential at registration while retaining S4U in the saved principal.
  Version `0.1.1` does not yet implement this path; the live Windows 10 peer task was
  registered through Task Scheduler COM as S4U/Limited.
- Cadence is `Daily` during the first onboarding month; re-register with
  `-Cadence BiWeekly` after the first clean month. The compare wrapper passes the
  expected cadence into `Compare-ParityAudits`, which flags snapshots older than
  `1.5x` cadence as stale.
- BuildMaster: consolidated application `ATAP.Utilities-PowerShell` (see the reviewed
  module map in the ATAP.IAC BuildMaster HostSettings fragment).
- Packaging must preserve the `scripts\` and `Documentation\` folders below the
  installed module root. A package missing either folder is not deployable for parity
  monitoring. The live `0.1.1` hosts have a documented temporary manual `scripts\`
  copy; SC-0264 remains the required reproducible fix.

## Functional area

Environment / Workstation Setup - START HERE: SolutionDocumentation\NewComputerSetup.md (link-up added 2026-07-07, Sprint 0012 Task 12.46.f)
