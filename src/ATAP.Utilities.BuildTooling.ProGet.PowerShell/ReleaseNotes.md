# Release notes

## 0.1.18

- `utat01`'s `ATAP-ParityAudit` policy is now Password logon, matching `utat022`. S4U task
  registration is refused on that host for every caller including SYSTEM with `SeTcbPrivilege`,
  and for a brand-new S4U task in an empty folder, so an S4U task there could never be updated.
  Run level stays `Limited`; only `utat022` runs `HighestAvailable`, for its peer SMB read.
- The credential-free S4U update path is retained for any future task that needs it; no current
  host policy uses it.

## 0.1.17

- Replaced `schtasks /Change` with Task Scheduler COM for the one-time dispatcher migration.
  `schtasks` prompts for the run-as password **even on an S4U task**, which has no password:
  with stdin inherited it hung the broker, and with stdin closed it failed with
  "Please enter the run as password for SvcParityAudit:". COM updates only the Exec action,
  using a null password with `TASK_LOGON_S4U` for `utat01` and the re-supplied credential with
  `TASK_LOGON_PASSWORD` for `utat022`.
- There is now exactly one task-mutation path, so the S4U and Password cases cannot drift apart.
- COM failures report the HRESULT alongside the message.

## 0.1.16

- Moved parity version selection out of the scheduled task definition and into a fixed,
  version-independent dispatcher under `C:\Program Files\ATAP\ParityDispatchers`. Repointing a
  parity version now rewrites that dispatcher instead of mutating a registered task, so it needs
  no run-as password and no Task Scheduler permission. The privileged task mutation is a one-time
  migration per host.
- The dispatcher root is deliberately outside this module's versioned directory; the previous
  location would have forced a fresh privileged task mutation on every broker release.
- Restored the two-host policy: `utat01` audit (S4U/Limited/AuditOnly) and `utat022`
  audit + compare (Password/Highest/AuditAndCompare). A host or task outside that table is refused.
- The Password-logon one-time migration re-supplies the run-as credential through
  `RegisterTaskDefinition`, resolved in-broker by canonical SecretName `SvcParityAudit.<host>`.
  It is never accepted from a request and never reaches the result record or transcript. Requires
  a BWS ReadOnly token for the broker service account (operator decision, 2026-08-11).
- `schtasks` invocations now close stdin before waiting. An open stdin let a Password-logon
  credential prompt hang the broker indefinitely.
- Dispatcher ACL guard now also rejects `AppendData`, `TakeOwnership`, and `ChangePermissions`.
- Contract, validation matrix, and threat model recorded in
  `_Planning/InformationForTheFuture/Parity/ParityTaskInstaller-Contract.md`.

## 0.1.8

- Add the narrowly typed `register-atap-parity-tasks` elevation-broker installer. It accepts only an exact installed SystemParityMonitor version and may repoint only the approved local parity tasks.

## 0.1.1

- Corrected the ProGet administration boundary test to use Pester mocks when
  the packaged module and its Secrets dependency are already imported.
- Version 0.1.0 was burned after its Development promoted-package gate exposed
  the test-isolation defect.

## 0.1.0

- Extracted the ProGet feed-administration, publication, promotion, and
  package-retrieval implementation from the aggregate BuildTooling module.
- Added explicit 36-command exports and 320 focused unit/integration tests.
- Retained the aggregate module as the compatibility surface.
