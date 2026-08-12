# Release Notes — ATAP.Utilities.SystemParityMonitor.PowerShell

## 0.1.18

- Grant non-inheriting `ReadAttributes` plus `Execute` on validated user-profile
  ancestors. npm uses `lstat` while walking to its configured prefix, so execute-only
  traversal is insufficient even though no directory listing or inherited access is
  required.

## 0.1.17

- Grant non-inheriting traverse-only access on validated user-profile ancestors so the
  parity identity can reach configured package roots without gaining inherited access to
  sibling content.
- When the approved machine npm prefix is a symbolic link, grant the resolved target only
  when it remains beneath the approved developer user root; reject ambiguous, remote, or
  out-of-root targets.
- Treat missing SQL default-data/default-log registry values as path nonconformance rather
  than an audit exception. This preserves the complete Integration instance surface while
  reporting `FilesConform=False`.

## 0.1.16

- Fail audit and comparison coverage closed when any collector emits an explicit
  `AuditError` row, and preserve the precise category/item path in diagnostic snapshots
  and drift reports. A row count can no longer conceal an incomplete collection.
- Support SQL named instances that use a dynamic TCP port by preferring a valid static
  `TcpPort` and otherwise using `TcpDynamicPorts` for the connection.
- Collect SQL Agent job names through `msdb.dbo.sysjobs_view`, matching the deployed
  `SQLAgentReaderRole` least-privilege grant instead of requiring direct table access.
- Grant read-and-traverse, rather than read alone, on configured package-manager profile
  roots so npm, pip, and dotnet can descend through those inventories under the scheduled
  service identity.

## 0.1.15

- Service and SQL engine discovery move from `Get-Service` back to `Win32_Service`, the surface
  the least-privilege matrix names. A previous change had moved the other way on the belief that
  the approved `root\cimv2` ACE could not serve `Win32_Service`; measured on both hosts
  2026-08-11 that was wrong twice over. The namespace ACE (`Enable`+`RemoteEnable`, `0x21`) is
  fine — `Win32_OperatingSystem`, `Win32_ComputerSystem`, `Win32_Process`, and
  `Win32_LogicalDisk` all queried successfully — while BOTH `Win32_Service` and `Get-Service`
  were denied, because the `Win32_Service` provider calls Service Control Manager underneath.
  This was the cause of the long-standing `InvalidOperationException` that stopped the audit
  before it collected anything, on both hosts.
- Unblocking it required read-only SCM access plus per-service query rights (Task 14.72), not a
  code change; the move to CIM keeps collection on one documented permission surface.
- The audit now enumerates services once rather than querying per name, so a single denial
  cannot silently degrade one row to `<missing>` while others succeed.
- Recorded value shapes are deliberately unchanged, including the two `<not-collected>`
  placeholders on engine rows. `Win32_Service` could populate them with `StartName` and
  `StartMode`, but that would alter every engine row and perturb the Task 14.73 drift baseline.

## 0.1.13 release candidate (unreleased)

- Persist a scheduled-task failure's exception message and fully qualified error identifier in the task-result JSON, so S4U failures can be diagnosed without interactive logon.

## 0.1.12 release candidate (unreleased)

This candidate is not yet built, promoted, installed, or deployed. Permission-profile
ACL follow-up remains in flight, so the module is not yet release-ready. The candidate's
version must not be used to describe the installed host tasks.

- Add identity-explicit configured path collection for pip, npm, and NuGet global
  tools. Missing configuration is a status, not an implicit audit of the
  `SvcParityAudit` profile; package/conflict rows are scoped by identity.
- Add configurable audit and comparison minimum category counts. Missing and thin
  coverage are structurally distinct; audit writes its diagnostic snapshot before
  failing.
- Add source-level Windows Application event thresholds: event `12380`/`12381` on
  the second consecutive scheduled failure and event `12382` immediately for stale
  snapshots or missing/thin comparison coverage. Host event-source registration and
  SEQ forwarding are not verified or deployed.
- Add validated scheduler transport for package-manager profiles and coverage minima.
  Registration atomically materializes schema-versioned JSON, validates its read-back,
  and places only the quoted configuration path on scheduled command lines. Wrappers
  fail closed on missing, unreadable, malformed, or unsupported configuration while
  preserving second-consecutive-failure alerting.
- Add the local-only, additive `Set-ParityAuditReadAccess` permission tool for the
  approved filesystem, SQL metadata, SQL Agent metadata, and separately gated WMI
  read surfaces. It validates exact hosts, accounts, paths, and SQL instances, supports
  `ShouldProcess`, verifies applied access, and does not accept credentials. Its
  permission-profile ACL follow-up is not yet settled.
- Collect SQL engine discovery through the Service Control Manager (`Get-Service`) rather
  than `Win32_Service`. The approved non-inheriting WMI ACE remains unchanged: it is too
  narrow for the deployed service identity's WMI query and must not be widened to method
  execution. SCM status queries preserve least privilege and restore instance discovery.
- Do not resolve the Windows PowerShell `ScheduledTasks` cmdlets when performing the
  credential-backed S4U Task Scheduler COM registration path. This keeps UTAT01's
  PowerShell 7 endpoint able to re-register its S4U/Limited audit task.

## 0.1.10 (published and deployed 2026-08-10)

- Deployed to both hosts from the immutable package with SHA-256
  `70449CD9636D8D3880CF6ED26E69AF7296213AC27B239427E0B3AEF1C37E6BB1`.
- Repaired the scheduled audit and compare actions to the installed `0.1.10` module
  root and supplied the validated package-manager profile configuration path.
- Live evidence confirms successful fresh audit and compare task results, token-free
  task metadata, and no stale or missing/thin coverage in that run. It also records
  123 undeclared drift rows, so it is not the two-consecutive-clean-compare acceptance
  required by Task 14.74.
- This deployment does not verify least-privilege grants, event-source registration,
  SEQ forwarding, notification, or paging.

## 0.1.8 (published and deployed 2026-08-09)

- Remove the scheduled audit and compare wrappers' Bitwarden/BWS credential probe,
  token-purpose parameters, and credential-directory dependency.
- Record metadata-only task results with `SecretAccessRequired = false`; deployed
  tasks require no BWS token, `bws`, or `BW_SESSION`.

## Historical source changes recorded before 0.1.8

The following changes were previously grouped under a stale `0.1.4 (unreleased)`
heading. This file does not reconstruct or invent the exact intervening immutable
version in which each item shipped.

- Add canonical Task 12.59 `PrimaryRole.json` read/write cmdlets with atomic,
  idempotent writes and schema validation for DPOM entry and exit. The single
  marker lives under the Dropbox-synchronized ATAP operational state path so a
  human runs the writer once on either host.
- Add Chocolatey, pip, npm, and NuGet global-tool package/version surfaces plus
  action-required cross-manager ownership conflict rows that remain visible when
  both hosts share the same conflict.
- Add SQL Server parity collection for engine/service identity, build, logins,
  roles, permissions, Agent jobs, endpoints, TCP settings, default directories,
  and canonical physical-file path conformance.
- Preserve the UTC instant of deserialized `CapturedAtUtc` values when calculating
  snapshot freshness, preventing a local-time conversion from reporting a negative age.
- Treat absent or empty `ParityWhitelist.json` and empty journals as valid first-run
  inputs; unmatched differences are classified as undeclared drift.
- Fall back to `Win32_Share` when `Get-SmbShare` is unavailable, including on the
  affected Windows 10 module-discovery surface.
- Restore S4U/Limited as the peer audit topology; a supplied Windows credential is
  used only for cross-account task registration or primary-host peer SMB access, not
  for vault access.
- Add focused Pester regression coverage for the parity collection paths and
  adversarial guards against reintroducing `Get-BWSAccessToken`, `bws`, or credential
  directories into scheduled execution.

## 0.1.3 (published 2026-07-12)

- Correct credential-backed S4U registration to use Task Scheduler COM
  `RegisterTaskDefinition` with `TASK_LOGON_S4U`; `Register-ScheduledTask -User`
  and `-Password` saved a Password principal on the live Windows host.
- Add `Invoke-ParityTaskAndWait.ps1` for deterministic interactive first-run proof of
  audit and compare tasks, including timeout and non-zero-result enforcement.
- Live cold-start validation established that the deployed wrappers must use Password
  logon when decrypting their owning account's DPAPI BWS token. The peer remains
  Limited; S4U registration is retained only as a capability for non-DPAPI tasks.

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
