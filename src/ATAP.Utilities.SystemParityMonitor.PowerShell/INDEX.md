# INDEX — ATAP.Utilities.SystemParityMonitor.PowerShell

| Path | Description |
| --- | --- |
| `ReadMe.md` | Module purpose, public-function table, layout, deployment notes |
| `ATAP.Utilities.SystemParityMonitor.PowerShell.psd1` | Module manifest (exports the five public functions) |
| `ATAP.Utilities.SystemParityMonitor.PowerShell.psm1` | Root module; dot-sources `public\` and `private\` |
| `version.json` | Nerdbank.GitVersioning version file (module packaging) |
| `ReleaseNotes.md` | Per-version release notes |
| `public\` | Exported functions: Add-ParityChangeEntry, Get-PeerPendingChanges, Confirm-ParityChangeApplied, Invoke-ParityAudit, Compare-ParityAudits |
| `private\` | Internal helpers (journal/ack/snapshot paths, JSONL IO, surface map, whitelist, logging shim) |
| `scripts\ParityScheduledTask.Common.ps1` | Shared scheduled-task helper for purpose-specific ReadOnly BWS token probing and event-log failure reporting |
| `scripts\Invoke-ParityScheduledAuditTask.ps1` | Local scheduled audit wrapper; imports this module, probes `CommonCIForBitwardenReadOnly`, writes snapshot and task-result JSON |
| `scripts\Invoke-ParityScheduledCompareTask.ps1` | Primary-host scheduled compare wrapper; reads local + peer snapshots, writes drift report, and flags stale snapshots using the cadence threshold |
| `scripts\Register-ParityScheduledTasks.ps1` | Registers audit-only or audit+compare scheduled tasks for `SvcParityAudit`, with daily or biweekly cadence |
| `tests\Unit\Parity.Tests.ps1` | Pester suite (journal round-trip, audit snapshot, drift comparison, stale snapshots, scheduled-task registration contracts) |
| `Documentation\Overview.md` | Concept overview: parity journal, audit snapshots, drift classes |
| `Documentation\InstallationAndTroubleshooting.md` | Windows 10/11 deployment contract, prerequisites, task registration, first-run proof, and live troubleshooting record |
| `Documentation\images\` | Images referenced by module documentation |
