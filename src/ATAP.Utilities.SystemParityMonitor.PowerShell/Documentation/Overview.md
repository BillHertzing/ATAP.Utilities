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
- **SQL topology surfaces** — snapshots include named engine instances, service state
  and identity, version, logins, server roles and permissions, Agent jobs, endpoints,
  fixed TCP configuration, default directories, and physical-file conformance to
  `C:\LocalDBs\<INSTANCE_NAME>\{Data,Log,Backup}\`.
- **Drift comparison** — `Compare-ParityAudits` compares the two hosts' latest
  snapshots and classifies every difference as **declared** (journaled), **whitelisted**
  (expected per-host differences), or **undeclared drift** (the actionable class), and
  flags **stale** snapshots older than the expected cadence.

## Scheduled operation

`scripts\Register-ParityScheduledTasks.ps1` registers local Task Scheduler entries
for the host role:

1. `ATAP-ParityAudit` -> `Invoke-ParityScheduledAuditTask.ps1` — local snapshot plus a
   `CommonCIForBitwardenReadOnly` BWS credential probe; result JSON under
   `<StateRoot>\TaskResults`.
2. `ATAP-ParityCompare` -> `Invoke-ParityScheduledCompareTask.ps1` — primary-host
   comparison against the peer's state share (default `\\utat01\ParityState`). Register
   this only on the primary host (`TaskSet AuditAndCompare`).

Both wrappers import the module from this folder's parent by relative path and use the
shared `ParityScheduledTask.Common.ps1` helper. The scheduled path performs no
PowerShell remoting: each host writes its own snapshots locally, and `utat022` reads the
peer snapshot share during compare. Tasks default to `SvcParityAudit` with `S4U`; use
`-LogonType Password -Credential <PSCredential>` for the primary compare task when SMB
peer-share access requires reusable service-account credentials. When an administrator
registers an S4U task for a different identity, Task Scheduler also requires that
identity's credential during registration even though the saved principal remains S4U
and does not store the password. Version `0.1.2` supplies that registration credential
while retaining the S4U/Limited saved principal. Re-register tasks when the module's
on-disk location changes.

The `0.1.1` package installed on both live hosts omitted `scripts\` and
`Documentation\`; `scripts\` was copied manually as a temporary Task 12.38.e recovery.
Version `0.1.2` stages both folders into the package. SC-0266 owns the incomplete
Windows 10 WinRM `PSModulePath` plus a PowerShell 7 endpoint.

Version `0.1.4` adds source-level resilience for the associated Windows 10 surface:
when `Get-SmbShare` is unavailable, audit collection falls back to `Win32_Share`.
Comparison also treats an absent whitelist or journal as empty and preserves the UTC
instant of deserialized snapshots during freshness calculation. The change is not live
until version 0.1.4 is promoted and installed.

Cadence starts as `Daily` for the first onboarding month and then relaxes to
`BiWeekly` after a clean month. The compare wrapper passes the expected cadence and
`1.5` stale multiplier into `Compare-ParityAudits`, so stale snapshots are reported as
their own drift-report line.

## Related documentation

- Installation, platform prerequisites, live-registration procedure, and the
  troubleshooting record: `Documentation\InstallationAndTroubleshooting.md`.
- Functional area: Environment / Workstation Setup — START HERE
  `SolutionDocumentation\NewComputerSetup.md`; see also
  `SolutionDocumentation\ConfigRootKeys-and-HostSettings.md` and
  `SolutionDocumentation\IAC-Windows-Scripts-Migration.md`.
