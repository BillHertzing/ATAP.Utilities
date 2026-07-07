# SystemParityMonitor — Overview

The SystemParityMonitor module keeps a pair of hosts in declared parity. It was built
in Sprint 0012 (Task 12.38, as ATAP.IAC `Windows\Parity`) and relocated to
ATAP.Utilities in Task 12.46.

## Concepts

- **Parity journal** — an append-only JSONL journal per host under the state root
  (`C:\ProgramData\ATAP\ParityState`). `Add-ParityChangeEntry` records each intentional
  configuration change (the "declared" changes).
- **Acknowledgements** — `Get-PeerPendingChanges` lists peer journal entries the local
  host has not yet applied; `Confirm-ParityChangeApplied` records an ack once the change
  is mirrored locally.
- **Audit snapshots** — `Invoke-ParityAudit` captures a snapshot of the host's
  configuration surfaces (per the internal surface map) into the state root.
- **Drift comparison** — `Compare-ParityAudits` compares the two hosts' latest
  snapshots and classifies every difference as **declared** (journaled), **whitelisted**
  (expected per-host differences), or **undeclared drift** (the actionable class), and
  flags **stale** snapshots older than the expected cadence.

## Scheduled operation

`scripts\Register-ParityScheduledTasks.ps1` registers two daily tasks:

1. `ATAP-ParityAudit` → `Invoke-ParityScheduledAuditTask.ps1` — local snapshot plus a
   BWS credential probe; result JSON under `<StateRoot>\TaskResults`.
2. `ATAP-ParityCompare` → `Invoke-ParityScheduledCompareTask.ps1` — cross-host
   comparison against the peer's state share (default `\\utat01\ParityState`).

Both wrappers import the module from this folder's parent by relative path, so
registered tasks must be re-registered when the module's on-disk location changes
(deploy-state note: after this relocation, any tasks registered from the old ATAP.IAC
path must be re-registered — none were found registered on utat022 as of 2026-07-07).

## Related documentation

- Functional area: Environment / Workstation Setup — START HERE
  `SolutionDocumentation\NewComputerSetup.md`; see also
  `SolutionDocumentation\ConfigRootKeys-and-HostSettings.md` and
  `SolutionDocumentation\IAC-Windows-Scripts-Migration.md`.
