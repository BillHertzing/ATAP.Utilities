# INDEX — ATAP.Utilities.SystemParityMonitor.PowerShell

| Path | Description |
| --- | --- |
| `ReadMe.md` | Module purpose, public-function table, layout, deployment notes |
| `ATAP.Utilities.SystemParityMonitor.PowerShell.psd1` | Module manifest (exports the seven public functions) |
| `ATAP.Utilities.SystemParityMonitor.PowerShell.psm1` | Root module; dot-sources `public\` and `private\` |
| `version.json` | Nerdbank.GitVersioning version file (module packaging) |
| `ReleaseNotes.md` | Deployed 0.1.8 baseline, unreleased next-release behavior, and historical version notes |
| `public\` | Exported functions: Add-ParityChangeEntry, Get-ParityPrimaryRole, Set-ParityPrimaryRole, Get-PeerPendingChanges, Confirm-ParityChangeApplied, Invoke-ParityAudit, Compare-ParityAudits |
| `private\` | Internal helpers (journal/ack/snapshot paths, atomic JSON and JSONL IO, surface map, whitelist, SQL and package-manager collection, normalized-name conflict detection, native-command adapter, logging shim) |
| `scripts\ParityScheduledTask.Common.ps1` | Shared scheduled-task helper for event-log failure reporting |
| `scripts\Invoke-ParityScheduledAuditTask.ps1` | Token-free local scheduled audit wrapper; imports this module, writes a snapshot, and records metadata-only task-result JSON with `SecretAccessRequired = false` |
| `scripts\Invoke-ParityScheduledCompareTask.ps1` | Token-free primary-host scheduled compare wrapper; reads local + peer snapshots, writes a drift report, records metadata-only task-result JSON, and flags stale snapshots using the cadence threshold |
| `scripts\Invoke-ParityTaskAndWait.ps1` | Interactive first-run helper; starts one parity task, waits for a newly recorded run, and fails on timeout or a non-zero Task Scheduler result |
| `scripts\Register-ParityScheduledTasks.ps1` | Registers token-free audit-only or audit+compare scheduled tasks for `SvcParityAudit`, with daily or biweekly cadence and optional Windows registration/SMB credentials that are unrelated to vault access |
| `tests\Unit\Parity.Tests.ps1` | Pester suite (journal round-trip, audit snapshot, Chocolatey/pip/npm/NuGet collection, cross-manager conflicts, drift comparison, stale snapshots, token-free wrapper guards, scheduled-task registration contracts) |
| `tests\Unit\PrimaryRole.Tests.ps1` | Focused Pester coverage for canonical DPOM marker creation, validation, idempotence, exit, and WhatIf behavior |
| `Documentation\Overview.md` | Concept overview: parity journal, audit snapshots, coverage limits, identity-explicit package paths, drift classes, and D-6 alert state |
| `Documentation\InstallationAndTroubleshooting.md` | Windows 10/11 token-free deployment contract, proposed least-privilege matrix, profile-path semantics, cadence gate, alert thresholds, first-run proof, and troubleshooting |
| `Documentation\images\` | Images referenced by module documentation |
