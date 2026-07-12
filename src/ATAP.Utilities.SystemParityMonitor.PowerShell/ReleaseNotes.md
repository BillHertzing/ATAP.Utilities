# Release Notes — ATAP.Utilities.SystemParityMonitor.PowerShell

## 0.1.3 (unreleased)

- Correct credential-backed S4U registration to use Task Scheduler COM
  `RegisterTaskDefinition` with `TASK_LOGON_S4U`; `Register-ScheduledTask -User`
  and `-Password` saved a Password principal on the live Windows host.

## 0.1.2 (published 2026-07-12)

- `Register-ParityScheduledTasks.ps1` now uses an optional supplied `PSCredential`
  when registering S4U tasks, retaining the S4U/Limited principal in the saved task
  while providing Task Scheduler the separate registration credential needed when the
  caller and run-as identities differ.
- The module builder stages optional `scripts\` and `Documentation\` folders before
  invoking `Publish-PSResource`; the promoted package therefore contains the scheduler
  actions and its deployment runbook.
- Added Pester coverage for credential-backed S4U registration and static-folder build
  staging.

## 0.1.1 (published 2026-07-11)

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
- Published to `powershellget-stable` and installed for AllUsers on `utat022` and
  `utat01`. The promoted package omitted `scripts\` and `Documentation\`; the operator
  manually copied `scripts\` to both PowerShell 7 module roots as a temporary recovery
  (SC-0264 tracks the packaging fix).
- `utat022` has Ready audit and compare tasks using Password logon. Windows 10
  `utat01` has a Ready audit task using S4U (`LogonType 2`) and Limited run level
  (`RunLevel 0`), registered through Task Scheduler COM after supplying the
  service-account credential at registration.
- Known limitation: `Register-ParityScheduledTasks.ps1` 0.1.1 supplies credentials
  only for Password logon. Its S4U branch returns `0x80070005` when an administrator
  registers for a different account; a new immutable version must implement that path.
