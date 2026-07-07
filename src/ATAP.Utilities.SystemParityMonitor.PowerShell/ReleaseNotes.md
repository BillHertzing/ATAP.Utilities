# Release Notes — ATAP.Utilities.SystemParityMonitor.PowerShell

## 0.1.0 (unreleased)

- Module relocated from ATAP.IAC `Windows\Parity` (`ATAP.IAC.Parity.PowerShell`) in
  Sprint 0012 Task 12.46. Public function names unchanged; module identity, manifest
  GUID, and internal `$mn` module-name strings updated.
- `Register-ParityScheduledTasks.ps1` reconstructed (the ATAP.IAC copy was never
  committed and the on-disk file was corrupted to null bytes).
- Not yet published to the ProGet PowerShell feed; scheduled tasks are not yet
  registered on any host from this location.
