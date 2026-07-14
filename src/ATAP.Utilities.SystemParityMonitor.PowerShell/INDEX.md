# INDEX — ATAP.Utilities.SystemParityMonitor.PowerShell

| Path | Description |
| --- | --- |
| `ReadMe.md` | Module purpose, public-function table, layout, deployment notes |
| `ATAP.Utilities.SystemParityMonitor.PowerShell.psd1` | Module manifest (exports the seven public functions) |
| `ATAP.Utilities.SystemParityMonitor.PowerShell.psm1` | Root module; dot-sources `public\` and `private\` |
| `version.json` | Nerdbank.GitVersioning version file (module packaging) |
| `ReleaseNotes.md` | Per-version release notes |
| `public\` | Exported functions: Add-ParityChangeEntry, Get-ParityPrimaryRole, Set-ParityPrimaryRole, Get-PeerPendingChanges, Confirm-ParityChangeApplied, Invoke-ParityAudit, Compare-ParityAudits |
| `private\` | Internal helpers (journal/ack/snapshot paths, atomic JSON and JSONL IO, surface map, whitelist, SQL and package-manager collection, normalized-name conflict detection, native-command adapter, logging shim) |
| `scripts\ParityScheduledTask.Common.ps1` | Shared scheduled-task helper for purpose-specific ReadOnly BWS token probing and event-log failure reporting |
| `scripts\Invoke-ParityScheduledAuditTask.ps1` | Local scheduled audit wrapper; imports this module, probes `CommonCIForBitwardenReadOnly`, writes snapshot and task-result JSON |
| `scripts\Invoke-ParityScheduledCompareTask.ps1` | Primary-host scheduled compare wrapper; reads local + peer snapshots, writes drift report, and flags stale snapshots using the cadence threshold |
| `scripts\Invoke-ParityTaskAndWait.ps1` | Interactive first-run helper; starts one parity task, waits for a newly recorded run, and fails on timeout or a non-zero Task Scheduler result |
| `scripts\Register-ParityScheduledTasks.ps1` | Registers audit-only or audit+compare scheduled tasks for `SvcParityAudit`, with daily or biweekly cadence, including credential-backed S4U registration when caller and run-as identities differ |
| `tests\Unit\Parity.Tests.ps1` | Pester suite (journal round-trip, audit snapshot, Chocolatey/pip/npm/NuGet collection, cross-manager conflicts, drift comparison, stale snapshots, scheduled-task registration contracts) |
| `tests\Unit\PrimaryRole.Tests.ps1` | Focused Pester coverage for canonical DPOM marker creation, validation, idempotence, exit, and WhatIf behavior |
| `Documentation\Overview.md` | Concept overview: parity journal, audit snapshots, drift classes |
| `Documentation\InstallationAndTroubleshooting.md` | Windows 10/11 deployment contract, DPAPI-compatible Password principals, credential-backed S4U capability, package-content verification, WinRM compatibility, first-run proof, and live troubleshooting record |
| `Documentation\images\` | Images referenced by module documentation |
