# Orchestration configuration manifest v1

Status: SOURCE DESIGN PROPOSAL, pending distinct review and coordinator acceptance.
Task 17.19.a / C17.1a remains open. This document selects no measured values,
creates no configuration entries and proves no runtime consumption on either host.

## Authority and evidence boundary

The accepted [Coordination-v1 contract](Coordination-v1.md) is the semantic
authority, including S1-S4. Its internal proposal heading is historical: the
external [coordinator acceptance](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/GoverningPlan/Clerk-Contract-Coordinator-Acceptance-20261026.json)
accepts exactly SHA256
`5A3533409C94418D3E5E44331CA7E3511A1BD459BD3138DBA4E4FC7509CA7959`
(46,079 bytes). That acceptance does not accept this configuration design.

The adopted C17.1a requires keys, units/ranges, source entries on both hosts,
human-reviewed measured values, actual pilot profiled consumption and explicit
missing/invalid failure. Only the documentary design portion is supplied here.
The request schema is being authored separately; state/result schemas, concrete
storage representations and numeric implementation ceilings remain downstream.
Do not treat this document as approval of those representations. [P290; C580]

| Reference | Exact local source | Clauses used |
| --- | --- | --- |
| P | [Adopted detailed plan](../../../../_Planning-wt-44-Sprint-0017-work-items/InformationForTheFuture/Sprint0017/SprintStartPlanning/Codex-V3-Astra/plan/02-Sprint0017-Detailed-Plan.md) | Lines 104-116, 120-138 and 290; C17.1a and C17.5/12/13/14 |
| C | [Accepted contract](Coordination-v1.md) | Lines 75-85 identity retention; 117-143 canonical bytes; 219-236 bounded batches; 238-252 registered roots; 340-362 stop/recovery/retention; 364-432 state/custody; 491-512 exclusion/transfer; 576-581 downstream bindings |
| H | [ConfigRootKeys and Host Settings](../../../SolutionDocumentation/ConfigRootKeys-and-HostSettings.md) | Lines 26-36, 46-72, 85-116, 153-164, 174-219, 223-252, 316-336 and 348-354 |
| V | [Get-PVal source](../../ATAP.Utilities.PowerShell/public/Get-ParameterValueFromNeoConfigurationRoot.ps1) | Lines 4-15 and 28-60 resolution/coercion; 76-77 alias; 239-307 precedence/missing; 311-342 validation/coercion |
| K | [Key registration source](../../ATAP.Utilities.ConfigRootKeys.Powershell/public/Set-GlobalConfigRootKeys.ps1) | Lines 99-107 explicit section list; 110-137 loading/invocation |
| E | [Existing core key source](../../ATAP.Utilities.ConfigRootKeys.Powershell/public/Set-CoreConfigRootKeys.ps1) | Line 58 CloudBasePathConfigRootKey; line 259 SecretVaultNameConfigRootKey; vocabulary examples only |
| B | [Host settings builder](../../ATAP.Utilities.PowerShell/public/Get-HostSettings.ps1) | Lines 166-171 key precondition; 211-225 explicit IAC path; 348-363 inner builder/result validation |

Line citations bind the source bytes pinned in the generated author report.
These are source observations, not installed-version or host-value observations.
No HostSettings values, environment values, profiles or secrets were inspected.

## Verified mechanisms and proposed vocabulary

Verified existing mechanisms are the two-tier globals, `Get-PVal` alias and its
resolution implementation, explicit key-section registration and the host
settings builder. The source examples `CloudBasePathConfigRootKey` and
`SecretVaultNameConfigRootKey` exist; neither supplies clerk custody or a clerk
limit. No existing orchestration key is asserted by this document. [H; V; K; E]

Every setting name in the catalogue below is DESIGN-PROPOSED. Names were checked
against the current ConfigRootKeys public sources only; no registration or
installed vocabulary is claimed. For each Level 2 name `N` below, its proposed
Level 1 constant is exactly `NConfigRootKey`, mapping to the literal string `N`.
The suffix convention is explicit here, not a rule that consumers may infer:
future consumers must resolve the actual Level 1 mapping. For example, the
proposed mapping is `OrchestrationMaxRequestBytesConfigRootKey` to
`OrchestrationMaxRequestBytes`. Neither is authored into configuration by this
document. [H46-72, H153-164]

All proposed keys are required before the affected pilot operation can run.
`UNMEASURED`, `UNBOUND` and `NOT_VERIFIED` are documentary status labels, never
usable configuration values. Every catalogue row has the same source status:
UTAT022 `NOT_AUTHORED_BY_THIS_UNIT / NOT_VERIFIED`, and UTAT01
`NOT_AUTHORED_BY_THIS_UNIT / NOT_VERIFIED`. This does not claim that entries are
absent in either live host. The per-host register below retains the distinction.

## Limits catalogue

The numeric type proposal is a strictly validated positive signed 64-bit integer
after resolution. No fraction, exponent, negative, zero, null, empty string,
overflow, Boolean, silent conversion failure or sentinel meaning unlimited is
valid. A positive lower bound expresses a useful finite limit, not a selected
default. An actual finite operational upper bound must be measured, reviewed
and intersected with the accepted schema/parser/storage ceilings. Those ceilings
are UNBOUND here; a positive value alone is insufficient for admission. [P290;
C580; V321-342]

| Proposed Level 2 key | Purpose and unit | Valid bound / unresolved requirement | UTAT022 / UTAT01 values | Failure before affected work | Basis |
| --- | --- | --- | --- | --- | --- |
| OrchestrationMaxRequestBytes | Bound one submitted request; bytes | Positive finite integer. Bind raw wire/envelope and canonical-content accounting to accepted schema/parser before use; measure representative largest valid inputs and reject over limit before durable acceptance. | UNMEASURED / UNMEASURED | No durable request acceptance on unresolved/invalid limit or over-limit input; preserve prior same-ID evidence. | P124; C117-143; C580 |
| OrchestrationMaxBatchRequests | Bound membership of one prepared batch; requests | Positive finite integer no greater than drain request capacity. Measure cost of selected independent requests. | UNMEASURED / UNMEASURED | No new preparation with invalid configuration; never truncate an existing Prepared batch. | C219-236; P131; P290 |
| OrchestrationMaxBatchBytes | Bound aggregate batch input budget; bytes | Positive finite integer. Bind accounting to request limits and retained prepared images; measure peak working set/output sizes separately. A valid largest admitted request must fit an empty eligible batch or be refused explicitly before preparation. | UNMEASURED / UNMEASURED | No partial selection/publication to fit a guessed budget; preserve queue and prepared recovery. | C219-236; C350-356; P290 |
| OrchestrationMaxDrainRequests | Bound newly considered requests in one explicit invocation; requests | Positive finite integer at least batch request capacity. Bind whether rejected candidates count; proposed accounting counts each newly considered request once, including rejected candidates. Review accounting before implementation. | UNMEASURED / UNMEASURED | Do not start a new drain with invalid limit. Reaching a valid bound returns explicit remaining work, not completed drain. | C340-341; P130-138; P290 |
| OrchestrationMaxDrainBatches | Bound new batch preparations per invocation; batches | Positive finite integer. Measure representative bounded workload; distinguish preparation from completion of a previously prepared batch. | UNMEASURED / UNMEASURED | No fresh batch after budget exhausted; retain pending/prepared state and committed head. | C219-236; C340-356; P290 |
| OrchestrationMaxDrainMilliseconds | Bound elapsed work admission for an explicit invocation; milliseconds | Positive finite integer and measured operational ceiling. Specify monotonic measurement and safe-boundary checks; not a promise to kill a process or interrupt publication at an arbitrary deadline. | UNMEASURED / UNMEASURED | Invalid budget prevents drain. Exhaustion stops new work at safe boundaries; incomplete work remains explicit NeedsRecovery/Prepared, never falsely Applied. | C207-217; C330-341; P131-138; P290 |
| OrchestrationMaxRetryAttempts | Bound delivery/recovery attempts within a single authorized invocation; attempts | Positive finite integer; bind exact counted transient failure classes and attempt boundary before implementation. Does not expire retained same-ID results or grant automatic re-admission. | UNMEASURED / UNMEASURED | Invalid limit prevents affected attempt. Exhaustion reports retained pending/recovery result and evidence; no changed ID, payload or duplicate effect. | C149-164; C282-341; P290 |
| OrchestrationRetryBudgetMilliseconds | Bound elapsed attempt budget within that invocation; milliseconds | Positive finite integer; measure supported persistence/recovery workload and reconcile with drain budget. No polling interval/backoff/service schedule chosen. | UNMEASURED / UNMEASURED | Stop scheduling further attempts at safe boundary, retain original identity/state; no cancellation or implicit success. | C149-164; C330-362; P136-138; P290 |
| OrchestrationClosedSprintRetentionDays | Minimum retention of full closed-sprint recovery/export records; whole days | Positive finite integer; exact protected record classes and period require reviewed closed-sprint retention contract and measured storage demand. No time-based identity reuse. | UNMEASURED / UNMEASURED | No retention cleanup when policy is unresolved/invalid; preserve evidence and hold affected new mutation if safe storage cannot be assured. | C75-82; C358-362; C579-580 |
| OrchestrationMigrationRetentionDays | Minimum retention of migration/restore evidence; whole days | Positive finite integer; bind period and start event to approved compatibility/restore contract. Records needed for outstanding recovery, reservations or retries outlive this minimum. | UNMEASURED / UNMEASURED | No migration/cleanup authorized by this key. Missing policy preserves records and holds affected operation. | C358-386; C427-432; C579-580 |

The attempt and accounting names above are design proposals required to make
limits reviewable, not claims that the accepted contract already specifies
their exact counters. Counter definitions, byte-accounting and safe-boundary
enforcement must be resolved with later implementation review. A conflict with
accepted retry precedence or immutable batch membership holds the producer;
it cannot be fixed by choosing a large value. [C219-236; C282-341]

## Custody and resource catalogue

Each value below is a nonempty string reference/path, not executable content or
an access grant. Actual paths, protected provenance and approved contents are
UNBOUND on both hosts. Runtime validation must resolve actual filesystem
identity and containment; lexical prefixes or an absolute spelling alone are
insufficient. Missing/unreadable/ambiguous/escaping references fail closed.
No root is created by a drain, no path is guessed from the current worktree,
and no Dropbox/ephemeral fallback is permitted for protected state. [C238-252;
C364-425]

| Proposed Level 2 key | Purpose and type/unit | Valid bound / required binding | UTAT022 / UTAT01 values | Missing/invalid behavior | Basis |
| --- | --- | --- | --- | --- | --- |
| OrchestrationStateRootPath | Existing protected ProgramData clerk state root; absolute local path string | Bind canonical root, resource/lineage, protection and separate setup receipt. Must exist; ProgramData text alone proves no protection. | UNBOUND / UNBOUND | Hold admission/recovery; never initialize replacement state or auto-create root. | P132; C364-386; C424-425 |
| OrchestrationCustodyRecordPath | Reference to protected external first-use/established witness; absolute path string | Outside replaceable state root, synced board and ephemeral worktree; bind custodian approval, baseline, lineage, epoch, coordinator, imports and compatibility. Actual trust mechanism remains unbound. | UNBOUND / UNBOUND | Hold MissingCustodyEvidence/CustodyConflict/StateLoss as applicable; absence never proves first use. | C396-425 |
| OrchestrationProtectedBackupRootPath | Protected backup/export destination reference; absolute path string | Bind durable automated protected backups and clean restore evidence; destination independent enough to survive the declared state-loss case. Topology/protection must be reviewed, not inferred from this path. | UNBOUND / UNBOUND | No pilot admission or backup-success assertion; retain current evidence without silent fallback. | P132-136; C373-386 |
| OrchestrationBackupPolicyReference | Protected, approved backup policy reference; nonempty string | Bind automated backup ownership/trigger, protected retention, restore tuple and verification evidence. No cadence/interval chosen here; unsupported reference holds admission. | UNBOUND / UNBOUND | No pilot while backup/clean restore prerequisites are unproved; never treat the reference as execution authority. | P136; C373-386 |
| OrchestrationResourceRegistryPath | Approved registered board/resource/root manifest reference; absolute path string | Bind immutable resource identity, canonical roots, exact quartet, allowed sprint/scope and current custody/owner references. Validate exact/ancestor conflicts and real aliases. Content schema remains downstream. | UNBOUND / UNBOUND | Reject unregistered/out-of-scope requests; hold mutation if registry integrity or containment cannot be proven. | C75-85; C238-264; C396-405 |
| OrchestrationCompatibilityMatrixPath | Approved package/schema/restore compatibility record reference; absolute path string | Bind exact package/digest/schema/export/restore tuple and approval provenance. A shared label or version string alone is insufficient. Matrix representation remains downstream. | UNBOUND / UNBOUND | Hold IncompatibleState/invalid restore; do not migrate, reset or treat unknown state as healthy. | C381-386; C427-487; C579 |

Resource identity, lineage, epoch, committed revision, FIRST_USE consumption,
coordinator authorization, prepared plans, reservations and result tombstones
are durable protocol evidence, not configurable reset knobs. Registry/custody
references must agree with that evidence; changing a setting cannot refresh an
old request, grant a new owner or establish a new lineage. No lock-expiry takeover,
automatic failover, bootstrap switch or retention switch permitting identity
reuse is proposed. Bill remains accountable custodian. [C75-85; C182-217;
C255-264; C396-432; C491-512]

## Resolution and failure contract for later consumers

This is a design requirement, not an implementation or runnable setup recipe.
Register key names through an explicitly invoked ConfigRootKeys section, update
its exported/ordered registration using the existing workflow, and provide
per-host/user Level 2 values in the admitted ATAP.IAC HostSettings source.
The section and IAC fragment write scopes must be separately bound; this unit
chooses neither an existing section to mutate nor a new fragment to discover.
The documentation's older five-section list is not the current inventory:
current source K lines 99-107 also names SQL topology and parity sections.
The explicit-registration convention is what is reused. [H85-116; H316-336; K]

Before any affected mutation, require populated globals, verify each Level 1
mapping is present and nonempty, resolve the actual Level 2 path through that
mapping, and validate the effective value and reviewed bounds. `Get-PVal`
accepts `originalPSBoundParameters`, `Settings` and `dottedPath`. Its actual
precedence is bound parameter, same-named environment variable, settings, then
explicit default. Use application-specific parameter names; never `Path`,
`Host` or another common environment name. No default, `AllowMissing`,
unlimited sentinel or invented host value is approved here. [H; V239-307]

Resolution is not validation. A higher-precedence value must still pass the
same type/unit/range, provenance and custody checks; do not retry lower-priority
sources after an invalid override. `AsType` conversion and `ValidValues` do not
prove protocol identity or measured numeric bounds: V311-318 compares allowed
strings without case sensitivity, and V337 can yield null through `-as`.
Do not use those conveniences to case-fold resource IDs, approve paths or
silently accept null. Require explicit post-resolution validation. [V311-342;
C75-143]

Both-host source-entry acceptance must still demonstrate the authored setting
through ConfigRootKeys and HostSettings even if a parameter/environment source
wins resolution. Capture the effective source, source revision, host/principal,
units, reviewed measurement reference and override authorization in a later
sanitized receipt. Do not assume an environment variable exists or dump its
value. No new environment integration is selected by this document. [H174-219;
P290]

Invalid configuration denies new affected admission/preparation without erasing
already durable requests/results or touching boards. Do not convert a malformed
request into an accepted queue record, retry with a new identity, truncate a
Prepared batch, release a reservation or delete recovery records to fit a
limit. Valid budget exhaustion reports remaining work; stop/drain is not
completion. Recovery ordering, safe stopping and retained retry semantics take
priority over attempts to finish within an arbitrary deadline. [C149-164;
C219-236; C330-362]

## Per-host source-entry and measurement register

This register applies individually to all sixteen proposed keys above. The
author report enumerates each row with separate UTAT022 and UTAT01 fields.

| Host | Measurement / approved reference values | Tier 1 registration | Tier 2 source entry | Effective profiled consumption |
| --- | --- | --- | --- | --- |
| UTAT022 | Ten limits UNMEASURED; six references UNBOUND | Proposed only; not authored | NOT_VERIFIED; not read or authored in this unit | NOT_RUN |
| UTAT01 | Ten limits UNMEASURED; six references UNBOUND | Proposed only; not authored | NOT_VERIFIED; not read or authored in this unit | NOT_RUN |

For each key on each host, future source work must bind the exact admitted IAC
sprint source file/host branch/principal, Level 1 mapping, Level 2 entry and
units/type validation. The documented convention is ATAP.IAC
`Windows/HostSettings.ps1` with its host fragments, selected by the wrapper;
this is a convention citation, not verification of current IAC values or a
permission to edit them. Unknown hosts fail closed pending an explicit source
mapping; neither host inherits another host's paths or measured limits. [H174-197;
H348-354; B166-171, B211-225, B348-363]

Measurement receipts must state workload, observations, approved finite bounds,
reviewer and margin rationale for request size, aggregate bytes, batch/drain
counts, attempt/drain duration and storage/retention. Structural bounds alone
are not measurements. Reference values additionally require protected custody,
resource registration and compatible clean restore evidence. No sample numeric
values or executable HostSettings snippets are provided to prevent accidental
promotion of placeholders. [P290; C373-386; C576-581]

## Review and remaining acceptance

Distinct review and coordinator acceptance of this design must precede any
consumer treating these names/accounting choices as approved. The following
remain unmet for 17.19.a and the parent outcome:

1. Accept exact key names, counter/byte accounting and relation to accepted
   request/state/result schemas without changing S1-S4 semantics.
2. Bind and review measured finite operational bounds and all protected reference
   values independently for UTAT022 and UTAT01; preserve UNMEASURED/UNBOUND until
   those receipts exist.
3. Separately authorize and implement exact ConfigRootKeys and HostSettings
   source entries; verify resulting source identities for both hosts/users.
4. Prove missing/invalid/override/overflow/near-bound cases fail before effects,
   including zero/unlimited, unit confusion, escaping aliases, absent established
   state, copied witness and invalid conversion yielding null.
5. Prove actual profiled pilot consumption on each required host with effective
   source attribution and exact installed package/consumer identity; remote
   runtime remains unverified until separately admitted and tested.
6. Bind backup/restore, custody and sole-writer evidence, real round trip and
   applicable ordinary/G2/release/pilot gates. A source document closes none of
   those gates. [P104-110, P132-138, P290; C554-581]

No schema/runtime test, import, remoting, configuration probe, settings write,
package action, polling loop, service or engine decision is performed by this
document. Generated checks and source-byte pins live in the assigned
`_generated/Sprint0017/17.19/ConfigurationManifest01/` evidence directory; the
source design itself stays in this durable module documentation path.
