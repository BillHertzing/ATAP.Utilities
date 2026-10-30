# RDB-310 — Non-RRSBS Reset-Scope Disposition

Status: Wave 4 source-only disposition decision (2026-08-04).

## Authority and boundary

This record implements the source-planning portion of `RDB-310` after the
RDB-300 allocation record.  It consumes the RDB-015 permanent-object inventory
and the RDB-160 source-disposition register.  It does not create SQL, a Flyway
migration, a seed, a package, or a database; it does not connect to a tier,
back up, reset, remove, or alter an object.

`RESET-01` establishes a fresh RRSBS V2 lineage (`0.0.1`, `V00010`, and
`rrsbs_flyway_schema_history`).  `RESET-SCOPE-01` puts Tags and Gmail in that
new-lineage scope, while all other deferred scopes are preservation scopes.
Consequently, a target is never an unspecified "whole database reset": it is
either the RRSBS V2 target described here or a preserved legacy/deferred scope.
RDB-850 remains the only authority that can name and approve an actual target.

## Decisions

| Disposition | Meaning | RDB-310 constraint |
| --- | --- | --- |
| Carry | The named source contract belongs in the RRSBS V2 package, recreated from the frozen source with equivalent required behavior. | RDB-470 owns the future SQL; RDB-480 is its sole baseline integrator. |
| Preserve | The named object remains outside the RRSBS V2 package.  Its legacy/deferred location is not dropped, moved, altered, or implicitly recreated by an RRSBS reset. | An exact-target approval and a separately owned consumer/cutover plan are required before any later change. |
| Retire | The legacy surface is not included in RRSBS V2 because a named successor owns the capability. | The legacy surface cannot be removed until its successor and consumer gate are complete. |
| Exclude | A transient or unproven source artifact is not a baseline object. | Live comparison is required before treating any surviving artifact as removable. |

## Object disposition register

| Source scope and objects | Count | Disposition | Reset/preservation path | Successor / gate |
| --- | ---: | --- | --- | --- |
| `Tags.Tags`, `Tags.TagAliases`, `Tags.RelationshipTypes`, `Tags.TagRelationships`; `vw_ActiveTags`, `vw_RootTags`, `vw_TagsWithChildCount`, `vw_TagRelationshipsExpanded`; `usp_GetTagTree`, `usp_GetTagAncestors`, `usp_GetTagDescendants` | 11 | Carry | RDB-470 recreates the frozen-source schema and behavior in the RRSBS V2 lineage.  The package contains no implicit drop or legacy-history manipulation. | RDB-470 SQL fixtures and RDB-480 integration; RDB-850 before execution. |
| `Gmail.gmailMessages` | 1 | Carry | RDB-470 recreates the frozen-source table contract in the RRSBS V2 lineage.  No mailbox contents, credentials, or live Gmail import are implied; only source-authorized seed inputs may be used later. | RDB-470 and seed/catalog approval; RDB-850 before execution. |
| `ATAPUtilities.User`, `ATAPUtilities.UserInformation`, `ATAPUtilities.UserSettings`; `ATAPUtilities.vw_UserFull`; `ATAPUtilities.usp_GetDecryptedUserInformation` | 5 | Preserve | These user/PII-adjacent legacy objects are excluded from RRSBS V2.  An RRSBS V2 reset never operates on their deferred scope, and no source data is copied by this task. | RDB-655 consumer disposition and a separately approved user-data migration/retention plan. |
| `AceCommander.Philote`, `PhiloteAdditionalId`, `PhiloteTimeBlock`, `PrimitiveLanguageKind`, `RulePrimitive`, `RulePrimitiveInput`, `Rule`, `RulePrimitiveComposition`, `RuleSet`, `RuleSetMember`, `RuleInstantiation`, `RuleInstantiationBinding`, `User`, `UserInformation`, `UserSettings`, `ScheduledTask`, `ScheduledTaskRun`; `AceCommander.vw_UserFull`, `AceCommander.vw_UserCrossSchema` | 19 | Preserve | The legacy AceCommander scope remains untouched and is absent from the ATAP.Utilities RRSBS V2 package.  In particular, `ScheduledTask` and `ScheduledTaskRun` are not recreated merely because a new RRSBS database exists. | Future AceCommander catalog plan and RDB-655 consumer map; any cutover is separately exact-target approved. |
| `ATAPUtilities.GetRuleByName` | 1 | Retired | It is excluded from the new baseline. The repository reference, query, PowerShell consumer, example, and unit fixture were retired on 2026-08-09 after the consumer scan found no callers outside that legacy family. The archived migration remains evidence only. | PTV-540 retirement decision. |
| `ATAPUtilities._stg_*` loader tables (45 source-declared transient tables) | 45 | Exclude | They are not baseline objects because each active loader drops its staging table.  A failed/interrupted legacy load might have left a live object, which this source-only decision cannot establish. | RDB-010B live catalog comparison; only a later exact-target decision may address a surviving object. |
| Unreferenced `Snippet_Philote_RuleSets.csv` and `Snippet_RuleSets.csv` inputs | 2 files | Exclude | They are not new-lineage seed authorization because RDB-015 found no active loader reference. | RDB-500 seed-catalog decision if a retained consumer requires them. |

The 25 archived non-RRSBS permanent tables in RDB-160 are covered exactly by
the first four rows: Tags (4), Gmail (1), ATAPUtilities user scope (3), and
AceCommander (17).  The seven views and five procedures from RDB-015 are also
explicitly covered above.  No function, permission, or active grant/revoke
statement was declared in the frozen source, so none is silently carried.

## Preservation and negative controls

- A V2 package that drops, truncates, alters, or imports the preserved
  ATAPUtilities user or AceCommander scope is rejected.
- A V2 package that omits the carried Tags/Gmail contract, or substitutes
  undocumented data/import behavior, is rejected.
- `ScheduledTask` verification does not prove a V2 recreation: it is a
  preserved AceCommander concern until its separately owned cutover is accepted.
- A surviving legacy staging table is not treated as evidence that a V2 baseline
  should create or drop it.
- No task may use `Flyway clean`, history edits, or a mixed legacy/V2 migration
  family to effect any of these dispositions.

## Acceptance and deferred execution

This is an approved source disposition, not deployment state.  RDB-470 owns
physical realization of the two carried domains; RDB-480 owns integration; and
RDB-800 through RDB-870 own rehearsal, per-target authorization, execution,
and proof that preserved scopes stayed unchanged.  The close variant rejected
by this decision is an unqualified fresh-database reset that silently destroys
user, AceCommander, or scheduled-task state while claiming to reset RRSBS.

## Experimental UserLogin amendment — 2026-10-29 (America/Denver)

This subordinate amendment applies only to **UTAT022\Expwhertzing / ATAPUtilities,
Experimental**, within the existing design05/decisions09 UserLogin model. The
original register and all other-tier/object dispositions above remain unchanged.

### Operator approval and exact scope

Bill explicitly approved the Experimental amendment with no drops, preserving
shared Philote and non-user objects. This is **typed operator approval**, recorded
by the coordinator in root chat `01a18563-f33a-79f1-a863-5da8876a946d`; the
[approval receipt](D:/ATAPArtifacts/Sprint0017/Task17.68.a/Approval40/Operator-Approval.json)
was recorded at `2026-10-29T23:42:35.8486336Z`.

| Approval record | SHA256 |
| --- | --- |
| [Explicit typed approval receipt](D:/ATAPArtifacts/Sprint0017/Task17.68.a/Approval40/Operator-Approval.json) | `C0E7C003DB91D6762A5632DC5DCF994A6FEB13BF27A5384A374ADDAACC9F6E8D` |
| [Approved amendment snapshot](D:/ATAPArtifacts/Sprint0017/Task17.68.a/Approval40/Approved-Amendment.json) | `4449ED0C5BB0FBA82A98F1694CD79F90957A8A3C5204213D9EE3FD56DB0F148F` |
| [Exact presented Draft03](D:/ATAPArtifacts/Sprint0017/Task17.68.a/Decision38/Decision-Packet.json) | `BE89AB10ACF896ADF050AB74C3D9CFB2B07980EE926AA13592D534F99A7088F0` |

The **approved exact drop list is `[]`**. All 12 historical candidates were absent
in the accepted snapshot. No wildcard or `IF EXISTS` expansion is approved; a
later present object needs refreshed exact disposition and operator-approved
amended scope under the existing workflow.

Retain the existing AceCommander creation model and its conditional Philote
authority. Do not recreate the retired ATAPUtilities user mirror. Within this
Experimental UserLogin action, preserve `ATAPUtilities.Philote` and its incoming
FKs, `ScheduledTask`/`ScheduledTaskRun`, all 22 classified modules, RRSBS/V2,
Tags/Gmail, ContentSummary and every non-user object. Original Carry, Preserve,
Retired and Exclude dispositions remain as recorded above.

### Bounded evidence and uncovered entries

The [consumer decision report](D:/ATAPArtifacts/Sprint0017/Task17.68.a/Decision38/Report.json)
and its [accepted documentation receipt](D:/ATAPArtifacts/Sprint0017/Task17.68.a/Decision38/Acceptance.json)
record a verdict or explicit uncovered entry for each exact candidate and the
archived seed/loader scope. The accepted evidence includes 14 corrected checksum
matches and 22 bounded definition matches, with two explicit transformed-source
candidates. These counts do not establish global consumer absence or applied
release provenance. The original T12 stop and recorded coverage limits remain.

- DAB effective host/configuration/entity mapping and remote consumers remain unknown.
- External, dynamic and cross-database callers remain uncovered. SQL Agent evidence
  covers three step rows in one job with zero broad candidate-token flags.
- Three CSVs and six exact loader references were found in the archive within the
  bounded search; runtime, packaging, dynamic and other-scope consumption remain unknown.
- Observed `dbo.flyway_schema_history` is distinct from configured release authority;
  the V2 contract expects `rrsbs_flyway_schema_history`. Package/configuration,
  producer, applied-byte lineage and migration-number binding remain unverified.

### Execution boundary

This records approval of amendment scope and the empty drop list. It grants no
reset, drop, grant, clean, repair, `Rebuild-All` or migration execution permission.
Existing RDB-850/RDB-655 and exact-target/release responsibilities continue; this
amendment adds no new gate. Existing R-10/R-11 waivers remain Experimental-only,
and promotion beyond Experimental requires separate operator approval.
Independent nondestructive source work remains distinct from database execution.
