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
| `scripts\` | Scheduled-task wrappers and `Register-ParityScheduledTasks.ps1` |
| `tests\Unit\Parity.Tests.ps1` | Pester suite (journal round-trip, audit snapshot, drift comparison) |
| `Documentation\Overview.md` | Concept overview: parity journal, audit snapshots, drift classes |
| `Documentation\images\` | Images referenced by module documentation |
