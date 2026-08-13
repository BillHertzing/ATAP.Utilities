# ATAP.Utilities.GELFLogging.Powershell — Index

| Path | Purpose |
| --- | --- |
| `ATAP.Utilities.GELFLogging.Powershell.psd1` | Module manifest. Exports the enable/disable/query trio. |
| `ATAP.Utilities.GELFLogging.Powershell.psm1` | Dot-sources `private\` then `public\`; declares the export list. |
| `version.json` | Nerdbank.GitVersioning source of the package version (0.1.1). |
| `ReadMe.md` | What the module is for and why it exists. |
| `ReleaseNotes.md` | Per-version change history. |
| `Documentation/Overview.md` | Design decisions and operational behaviour. |
| `public/Enable-SeqGelfLogging.ps1` | Enable a named `gelfudp` instance; optional delivery verification. |
| `public/Disable-SeqGelfLogging.ps1` | Flush and disable a named instance. |
| `public/Get-SeqGelfLoggingStatus.ps1` | Read-only state and endpoint query. |
| `private/Register-SeqGelfUdpProvider.ps1` | Idempotent registration of the UDP GELF provider. |
| `private/Assert-PSGelfAvailable.ps1` | On-demand PSGELF import; only `Enable` calls it. |
| `tests/Unit/GELFLoggingModule.Tests.ps1` | Manifest, export, dependency, and documentation contract. |
| `tests/Unit/Disable-SeqGelfLogging.Tests.ps1` | Flush ordering, idempotence, `-WhatIf`, failure reporting. |
| `tests/Unit/Get-SeqGelfLoggingStatus.Tests.ps1` | Read-only guarantees and endpoint reporting. |
