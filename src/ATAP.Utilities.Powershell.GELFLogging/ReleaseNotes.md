# ATAP.Utilities.Powershell.GELFLogging — Release Notes

## 0.1.1 — 2026-08-02 (Sprint 0014, Task 14.62)

Initial release. Extracted from `ATAP.Utilities.PowerShell` into a dedicated child module.

### Added

- **`Disable-SeqGelfLogging`** — the counterpart `Enable-SeqGelfLogging` never had. Flushes
  queued messages before disabling (PSFramework's logging runspace is asynchronous, so
  anything still queued when an instance stops is dropped without a diagnostic), and is a
  safe no-op when the instance or provider does not exist.
- **`Get-SeqGelfLoggingStatus`** — read-only query of registration, instance state, and the
  endpoint being shipped to. Never registers the provider and never imports PSGELF.

### Changed

- `Enable-SeqGelfLogging` moved here unchanged in behaviour. Provider registration was
  extracted into the private `Register-SeqGelfUdpProvider` so enable, disable, and query all
  share one provider definition, and the PSGELF availability check into the private
  `Assert-PSGelfAvailable` so only *enabling* pays for the transport module.
- PSFramework messages now report `ATAP.Utilities.Powershell.GELFLogging` rather than the
  parent module name, so SEQ attributes this module's telemetry correctly.

### Dependency notes

- `PSFramework` is a `RequiredModule`.
- `PSGELF` is deliberately **not** required — it is the UDP transport, used only by
  `Enable-SeqGelfLogging`, and is imported on demand. Requiring it would force any host that
  merely wants to disable or query the sink to install the transport first. It is declared in
  `PSData.ExternalModuleDependencies`.

### Known follow-ups

- `ATAP.Utilities.PowerShell` still carries the original `Enable-SeqGelfLogging`. Retiring
  that copy and repointing the machine profile at this module is gated on this package
  reaching `powershellget-stable`.
