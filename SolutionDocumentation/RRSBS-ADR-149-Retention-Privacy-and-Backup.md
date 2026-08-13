# RRSBS ADR-149: Retention, Privacy, and Backup Contract

Status: Proposed for Wave 1 review

Date: 2026-08-02

Owner: RDB-149 / Task 14.20.b.12

## Decision

Every RRSBS destructive target operation requires a protected, restorable
backup or equivalent approved recovery point before the operation begins. The
backup is retained for the target-specific **approved rollback window**. That
window begins when the backup is successfully created and integrity-verified;
it ends only after all of the following: the target's RDB-845 restore rehearsal
has passed, RDB-870 deployed-state verification has passed, any incident or
rollback investigation is closed, no legal hold applies, and an explicit
deletion approval names the exact backup set. The RDB-850 exact-target approval
must record the window's minimum calendar duration and the recovery-point
identity. No implicit or global retention duration is accepted.

Backup storage is classified at least as highly restricted operational data.
Access is least-privilege, role-based, and limited to authorized backup,
restore, incident-response, and audit roles. Backup creation, copying,
transport, storage, restoration, and deletion use approved encrypted storage
and authenticated transport. A backup must not be placed in a general shared
folder, copied to unmanaged media, or exposed through routine build logs.

Each backup and restore test produces non-secret audit metadata: backup-set
identity; target identity; source state/version; creation, verification, and
expiry timestamps; retention basis; storage location class; encryption/key
policy identifier; checksum or immutable storage version; approver identity;
restore-test identity/outcome; legal-hold state; and deletion-approval identity
when applicable. The metadata stores no connection string, credential, secret,
backup contents, personally identifying payload, or encryption key material.

Restore proof is mandatory before a destructive target operation: a designated
recovery owner must restore or otherwise validate the approved recovery point
in a separately authorized non-production/rehearsal scope, verify identity,
integrity, and expected recoverability, and record the result. A `VerifyOnly`
check alone is useful evidence but is not a complete restore rehearsal when the
approved recovery plan requires a usable restored database.

A legal hold, incident hold, security investigation, or preservation request
overrides ordinary expiry. It is an immutable hold record linked to the backup
set and blocks deletion until an authorized release is recorded. Deletion is a
separate destructive action: it needs an exact backup-set inventory, expiry and
hold checks, confirmation of the required restore proof, retention of the
non-secret audit record, and an explicit approval. Automation may identify
eligible candidates but may not delete them solely because a timer expired.

The Sprint 0013 “delete-after-verify” practice recorded in Task 13.83 is
historical evidence only. It is not permitted for RDB destructive work. A
successful deployment or verification never by itself permits removal of the
only recovery copy.

This ADR is an authored normative authority. It authorizes no backup, restore,
copy, access, deletion, SQL, package/feed, live-system, or secret action.

## Scope and authority

This ADR governs RRSBS rollback backups and associated audit/retention policy.
It complements exact-target approval in
[ADR-146](RRSBS-ADR-146-Plan-Approval.md) and the broader promotion/recovery
evidence in
[Database change-unit and Flyway promotion guidance](Database-Change-Unit-and-Flyway-Promotion.md).

It does not replace enterprise legal, privacy, incident-response, encryption,
or key-management policy. It also does not select storage products, configure
access controls, or grant a deletion approval. Those require their respective
authorized operators and gates.

## Normative contract

1. An RDB-850 approval names exact host, instance, database, backup/recovery
   identity, package/hash, restore plan, minimum rollback-window duration, and
   authorized recovery owner before a destructive operation may start.
2. A recovery point is accepted only after capture integrity verification and a
   separately authorized restore rehearsal prove the recovery procedure named
   in the target approval. Production restoration is not used merely to test a
   backup.
3. The protected backup remains readable and restorable through the entire
   approved rollback window. Replication, compression, or format conversion may
   create a new backup representation only when it preserves verified recovery
   and linked audit identity.
4. Access is granted only to named roles with least privilege. Every privileged
   read, copy, restore, hold, and deletion action is audit-recorded with actor,
   time, purpose, target/backup identity, and result.
5. Backup content and audit evidence are privacy-minimized. Secrets, keys, and
   connection values are never placed in audit metadata or generated evidence;
   any personal data in backup content remains subject to its source data's
   classification and access restrictions.
6. A legal/incident/security hold is append-only, overrides normal expiry, and
   cannot be bypassed by retention automation or a rollout completion signal.
7. Deletion requires a distinct approval that lists every backup representation
   to remove, proves expiry/no active hold/restore evidence, and preserves an
   immutable non-secret deletion audit record. Deleting one replica does not
   authorize deletion of another representation.
8. Failed backup capture, checksum mismatch, inaccessible storage, failed
   restore rehearsal, missing audit metadata, or missing deletion approval
   blocks the associated destructive operation or deletion.

## Attribution correction and dispute lineage

An attribution is an immutable claim that connects an attributed actor or entity to a subject entity. A discovered error does not authorize an update, deletion, or re-keying of that claim. A correction creates a new immutable attribution assertion with exactly one `SupersedesAttributionId` reference to the prior assertion; the original remains available for audit, and the successor relationship determines the current effective assertion. Correction chains must be acyclic and must not leave two ambiguous current successors for the same corrected claim.

An `AttributionDispute` is a durable record linked to the exact attribution assertion or correction under review. Its append-only `AttributionDisputeEvent` lineage records the controlled status transitions `Raised`, `UnderReview`, `Resolved`, and `Withdrawn`; a resolved dispute also records one controlled outcome: `Upheld`, `Corrected`, or `Rejected`. A `Corrected` outcome must identify the resulting correction assertion. Reopening or withdrawing a dispute adds a new event; it does not rewrite an earlier status or outcome.

Each attribution correction and dispute event preserves provenance and audit metadata: the relevant typed entity identifiers, the source artifact and version when evidence was sourced from an artifact, the governing authority or policy, a reason or evidence reference, the acting entity, and UTC occurred, observed, and recorded times where each is known. Display names, secrets, and unnecessary personal data are not audit identifiers; typed entity references follow the [ADR-105 entity reference contract](RRSBS-ADR-105-Entity-Reference-Contract.md).

Retention policy and any legal, privacy, security, or incident hold apply to the attribution assertion, its correction lineage, the dispute timeline, and associated evidence references as one auditable history. An active hold blocks destructive expiry or purge of that history. If a lawful erasure or redaction obligation applies, record an immutable redaction or tombstone event with its authority and actor/time metadata; never silently remove or alter the attribution or dispute lineage. This rule defines data semantics only and does not initiate a backup, restore, deletion, or record mutation.

## Attribution dispute negative controls

1. Do not update, delete, or re-key an attribution assertion to correct it.
2. Do not create a correction without exactly one predecessor reference, create a cyclic correction chain, or leave ambiguous effective successors.
3. Do not replace a disputed attribution with dispute text or omit the exact assertion or correction being disputed.
4. Do not record a resolved outcome without an immutable status event, outcome, acting entity, UTC time, authority, and reason or evidence reference.
5. Do not record `Corrected` without identifying the successor correction assertion, or reopen or withdraw a dispute by rewriting an earlier event.
6. Do not allow a retention timer, backup-retention process, or hold release to remove or alter attribution or dispute history while an applicable hold remains active.
7. Do not treat erasure, redaction, or source unavailability as permission for silent deletion; preserve the authorized tombstone or redaction lineage.
8. Do not emit personal data, credentials, or secret-bearing artifact content as attribution or dispute audit metadata.

## Consequences

RDB-300 and RDB-780 must document target-specific recovery and retention
procedures. RDB-845 must execute the approved restore rehearsal and preserve
its evidence. RDB-850 approvals must bind each destructive target to a named
recovery point, rollback window, and restore plan. RDB-860 must stop if that
evidence is missing or invalid. RDB-870 must not advance deletion eligibility
without the separately recorded checks in this ADR.

The existing backup explainer provides operational background, but its legacy
retention settings and manual-pruning advice are not by themselves an approved
RRSBS destructive-action deletion policy.

## Negative controls

The eventual procedures, automation, and tests must reject each of the
following:

1. A destructive reset or migration begins without a named, integrity-verified,
   and restore-rehearsed recovery point.
2. A generic environment label, latest-backup alias, or unverified copy is used
   instead of the exact recovery identity approved for the target.
3. A backup is deleted immediately after deployment, hash verification, or
   successful restore test while its approved rollback window remains open.
4. A retention timer deletes a backup without an exact deletion approval,
   restore-proof reference, expiry check, and no-active-hold proof.
5. A legal, incident, privacy, or security hold is ignored, overwritten, or
   removed without a separately authorized release.
6. Backup data, connection strings, credentials, keys, or personal data are
   copied into logs, generated evidence, manifests, ticket text, or audit
   metadata beyond the permitted non-secret identifiers.
7. A general shared location or unauthorized role can read, copy, restore, or
   delete protected backup material.
8. A `VerifyOnly` result is treated as a complete recovery rehearsal when the
   approved plan requires a usable restored database.
9. A failed checksum, storage-access failure, or restore failure is recorded as
   success or does not block the associated destructive operation.
10. Deleting one compressed, replicated, or exported representation is treated
    as approval to remove every other retained representation.

## Acceptance checks

- RDB-300 and RDB-780 publish a recovery runbook that names the retention
  record, recovery identity, restore-test evidence, storage/access policy, hold
  procedure, and deletion-approval template.
- RDB-845 proves the exact retained recovery point restores in its approved
  rehearsal scope before RDB-850 destructive approval is used.
- RDB-850 rejects a target approval without a minimum rollback-window duration,
  recovery owner, storage classification, and restore plan.
- RDB-860/RDB-870 fixtures reject all ten negative controls and preserve
  non-secret audit evidence for every allowed operation.

## Related authorities

- [ADR-146 plan-approval contract](RRSBS-ADR-146-Plan-Approval.md)
- [Database change-unit and Flyway promotion guidance](Database-Change-Unit-and-Flyway-Promotion.md)
- [Backup operational explainer](Backup-SqlServer-ProGet-BuildMaster.md)
- [Historical Task 13.83 deployment record](Task-13.83-Instantiation-Deployment-and-Manifestation.md)
