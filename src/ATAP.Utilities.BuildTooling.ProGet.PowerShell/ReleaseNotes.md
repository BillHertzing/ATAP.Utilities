# Release notes

## 0.1.23

- Package the module's `Resources` directory through the shared module build pipeline.
  ProGet 0.1.22 contained the corpus-sealing broker contract in source but omitted the
  broker payload, task XML, and trust-anchor config template from its immutable nupkg,
  preventing a trusted installed module from activating the action.
- Strengthen the shared package-staging contract test to pin every supported static payload
  directory and recursive copy behavior.

## 0.1.22

- Add the tightly allowlisted `seal-gather-call-record-segment` elevation-broker action.
  It loads `Complete-GatherCallRecordSegment` only from
  `ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell` 0.1.37 or later beneath the
  administrator-writable `C:\Program Files\PowerShell\Modules` root.
- Restrict sealing requests to seven required scalar strings: canonical C: or D: corpus
  paths, a four-digit sprint, bounded SAM identities, and an exact SHA-256 pin. The
  SprintLifecycle command remains responsible for semantic canonicalization, reparse,
  ancestry, identity, JSONL, destination, volume, and hash checks.
- Fail a broker request when a module command returns Boolean `Ok = false`, with bounded
  `Failure.Code` and `Failure.Message` detail. Preserve the existing `ExitStatus` result
  contract and reject non-Boolean `Ok` values.

## 0.1.21

- Carry the fixed shared .NET tool policy path into every approved parity audit
  and comparison dispatcher, and fail closed when the materialized policy is
  missing before a live scheduled-task action is repointed.

## 0.1.19

- **Breaking for callers that relied on the old default.** The broker task's default folder is
  now `\ATAP-Broker\` rather than `\ATAP\`, in `Request-ElevatedInstall -BrokerTaskPath`,
  `Register-ElevationBrokerTask -TaskPath`, `Grant-ElevationBrokerStartRights -TaskPath`, and the
  task template's `<URI>`. The broker task was relocated on 2026-08-11 so that granting it
  folder-level create/update on `\ATAP` — which `ITaskFolder.RegisterTaskDefinition` requires to
  manage the parity tasks — cannot also let it rewrite its own definition.
- Until this shipped, every caller using the default got
  `broker-unreachable ... The system cannot find the file specified (0x80070002)`.
- A contract test now pins all three defaults and the template URI together, so they cannot drift
  apart again.
- Hosts whose broker task still sits in `\ATAP` must either be re-registered with
  `Register-ElevationBrokerTask` or have `-BrokerTaskPath '\ATAP\'` passed explicitly.

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
