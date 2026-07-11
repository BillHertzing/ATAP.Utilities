# Release Notes — ATAP.Utilities.SystemParityMonitor.PowerShell

## 0.1.1 (unreleased)

- Module relocated from ATAP.IAC `Windows\Parity` (`ATAP.IAC.Parity.PowerShell`) in
  Sprint 0012 Task 12.46. Public function names unchanged; module identity, manifest
  GUID, and internal `$mn` module-name strings updated.
- `Register-ParityScheduledTasks.ps1` reconstructed (the ATAP.IAC copy was never
  committed and the on-disk file was corrupted to null bytes).
- Task 12.38.e scheduler hardening: audit-only vs audit+compare registration, default
  `SvcParityAudit` run-as, optional password-logon registration for peer-share access,
  daily or biweekly cadence, and compare stale-snapshot thresholding at `1.5x` cadence.
- Scheduled wrappers now use `Get-BWSAccessToken -TokenPurpose ReadOnly` through a
  shared helper, require the purpose-specific `CommonCIForBitwardenReadOnly` DPAPI
  token file, avoid remoting in the scheduled path, and write event-log failure attempts
  plus task-result JSON.
- Unit coverage expanded to 9 Pester tests, including scheduled-task registration
  contracts and legacy `BW_SESSION` / `bw` / single-slot BWS filename guards.
- Not yet published to the ProGet PowerShell feed; scheduled tasks are not yet
  registered on any host from this location.
