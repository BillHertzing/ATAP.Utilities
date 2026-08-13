# RRSBS ADR-110: Temporal and Versioning Contract

Status: Proposed for Wave 1 review

Date: 2026-08-02

Owner: RDB-110 / Task 14.20.b.03

## Decision

RRSBS separates durable identity, immutable version, publication time, and
business-effective validity. A durable subject retains its table-specific
Philote across revisions. Each published definition or snapshot is an
append-only version of exactly one durable subject and has its own immutable
version identity. A revision inserts a successor; it never updates or deletes
the published predecessor. A fork is a new durable subject with recorded
derivation, not a new version of its source.

Every immutable version records an immutable publication timestamp and an
ordered, identity-local revision sequence. The exact atomic publication
operation, sequence allocation, singleton-current enforcement, and isolation
behavior are owned by RDB-115. This ADR requires that any such mechanism
selects a published version only; it does not prescribe a mutable `IsCurrent`
column or an implementation-specific current-row index.

`ValidFromDTS` and `ValidToDTS` represent a separately declared
business-effective interval, in UTC and with half-open semantics
`[ValidFromDTS, ValidToDTS)`. They are present only for concepts whose domain
meaning requires business-effective time. They do not represent publication
time, audit retention, row liveness, or a universal current-version selector.
Where a version has no business-effective validity, these columns are absent;
where the concept has open-ended validity, `ValidToDTS` is null. An as-of
query uses the explicit business-effective interval and a declared instant;
it does not infer a result from the latest row, a version label, or a nullable
legacy `EffectiveTo` field.

This is an authored normative authority for the new baseline. It does not
authorize DDL, migration, seed, package, live-tier, reset, or consumer work.

## Scope and authority

This ADR implements TM-01 and ID-01 for RDB-110. It governs version lineage,
publication state, business-effective temporal fields, immutability, and
as-of semantics. It uses the terms defined by
[ADR-100](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md).

The current effective-dated schema is evidence and migration input, not the
new-baseline authority. In particular, its `EffectiveFrom` / `EffectiveTo`
fields and current-row pattern are not adopted merely because they exist.
RDB-115 owns publication/concurrency mechanics, and RDB-105 owns physical
Entity/Philote FK patterns.

## Normative contract

1. A version belongs to one durable identity. Its durable-parent Philote and
   its own version Philote are immutable and cannot be reassigned.
2. A published version is insert-only. Content, lineage, publication timestamp,
   revision sequence, and composition/membership snapshot cannot be updated or
   deleted. Correction is represented by a successor version or a separately
   modeled revocation state, never by rewriting history.
3. Revision sequence is unique and monotonic within its durable identity. It is
   an ordering aid, not a global key and not a substitute for the version
   identity. The predecessor relationship, when present, must remain within
   the same durable identity and be acyclic.
4. Publication time records when the immutable version became published. It is
   system time, stored in UTC, and is distinct from business-effective time.
5. `ValidFromDTS` / `ValidToDTS` are allowed only when a specification names
   the business-effective fact and its temporal consumer. A non-null interval
   satisfies `ValidFromDTS < ValidToDTS`; boundary instants belong to the
   successor interval, never both intervals.
6. An as-of request must name both the durable identity and an instant. It
   returns the uniquely applicable published version for that identity and
   business-effective interval, or no result. It must not silently fall back
   to a current or nearest version.
7. A snapshot selection records exact version identities. Later revisions,
   later publications, and later business-effective intervals cannot change
   the historical selection.
8. A versioned projection or cache may be regenerated, but it cannot be the
   sole authority for version identity, lineage, or as-of results.

## Future-dated business-fact admissibility

A future business-effective fact is admissible only for a concept that has a
declared business-effective meaning and temporal consumer. Admission requires an exact
durable identity, an immutable candidate version, a UTC `ValidFromDTS`, and either a
valid later `ValidToDTS` or an explicitly open-ended interval. The submitting contract
must state that the interval describes a future business fact, rather than using a
future timestamp as a proxy for publication, scheduling, retention, or currentness.

Validation is performed against the declared temporal policy before publication. The
candidate must satisfy the interval rules in this ADR, be attributable to its durable
identity and predecessor as applicable, and be unambiguous for the declared as-of
consumer. A candidate that lacks the required business meaning, has an invalid or
ambiguous interval, conflicts with an interval where a single result is required, or
cannot be associated with its declared durable identity must be rejected. Rejection
does not create a published version or alter a prior published version.

Publication time and business-effective time remain independent. A version may be
published before its `ValidFromDTS`; that makes it an immutable published future fact,
not the current business-effective result. Conversely, publishing a version after its
declared `ValidFromDTS` does not rewrite the past: consumers must apply the declared
as-of policy and publication eligibility rather than silently backdating an earlier
selection. RDB-115 owns the atomic publication and visibility mechanics needed to make
that policy observable.

A superseding future fact is a new immutable successor with its own publication time,
revision sequence, and business-effective interval. A correction to a published future
fact must publish a successor or use an explicitly modeled revocation state; it must
not update, delete, shorten, or move the already published fact in place. If a
supersession changes applicability, the new version's interval and the prior version's
documented disposition must still leave the declared as-of consumer with the required
unambiguous result.

## Consequences

Wave 3 logical models must give first-class durable and versioned subjects a
stable identity/version split, append-only version rows, and an explicit
predecessor/sequence contract. They must add business-effective time only to
the approved concepts that need it. Wave 5 SQL must enforce the immutable and
interval constraints with trusted database controls. Wave 8 contracts must
accept and return stable identities plus exact version identities rather than
physical keys or ambiguous “current” flags.

The legacy `EffectiveFrom` / `EffectiveTo` implementation remains relevant
evidence for migration disposition, including historic as-of reconstruction.
It does not dictate the field names, scope, or selector of the replacement
baseline.

## Negative controls

The eventual model, contracts, and tests must reject each of the following:

1. A Rule revision changes its durable Philote or reuses a version Philote.
2. An update, delete, or in-place content correction changes a published
   version, composition, membership, binding snapshot, or lineage field.
3. A successor points to a predecessor owned by another durable identity, or a
   predecessor cycle is accepted.
4. Two versions of one identity receive the same revision sequence, or a
   lower sequence is inserted after a higher published sequence.
5. `ValidToDTS IS NULL`, `VersionLabel`, or physical row order is used as the
   sole current-version selector without the RDB-115 publication contract.
6. A business-effective interval has an inverted or zero-width range, overlaps
   another interval where the concept requires one result, or returns both
   adjacent versions at their shared boundary.
7. An as-of query omits its instant or silently substitutes the latest,
   nearest, draft, or unpublished version.
8. `ValidFromDTS` / `ValidToDTS` are added mechanically to every RRSBS row,
   including rows with no declared business-effective meaning.
9. A published InstantiationVersion changes its selected InputBlockVersion or
   BuildSetVersion after publication.
10. A concept with no declared business-effective meaning accepts a future timestamp
    merely to schedule publication, indicate currentness, or retain an audit record.
11. A future-dated candidate is published without a durable identity, valid UTC
    interval, declared temporal consumer, and the required unambiguous applicability.
12. A published future-dated version is returned as business-effective before its
    `ValidFromDTS` solely because it is the latest or current published version.
13. A late publication silently changes a consumer's historical as-of result without
    the declared publication-eligibility policy.
14. A correction edits, deletes, shortens, or moves a published future fact in place
    instead of using a successor or an explicitly modeled revocation state.
15. A superseding future fact leaves an overlapping or gap-producing interval where
    the concept's declared policy requires exactly one applicable result.

## Acceptance checks

- RDB-115 defines an atomic publication operation consistent with this ADR and
  provides its concurrency and singleton-current proof.
- RDB-200 through RDB-260 identify every temporal concept, durable parent,
  version identity, lineage field, publication state, and permitted as-of
  query; a concept without a business-effective use does not receive validity
  columns by default.
- RDB-400 through RDB-470 include positive and negative fixtures for all fifteen
  negative controls, including an adjacent half-open interval boundary, a published
  future fact that is not yet business-effective, rejection of an invalid future fact,
  and an immutable snapshot selection after later publication.
- RDB-160 reconciles legacy effective-dated history without treating the
  legacy schema as the new-baseline authority.

## Related authorities

- [ADR-100 glossary and Entity-Philote authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [Instantiation tables current-state evidence](ATAPUtilities-Instantiation-Tables.md)
- [RRSBS database documentation](../Database/Documentation/README.RRSBS.md)
- [Durable versioned snapshots migration](../Database/Flyway/SQL/V00.02.000070__Add_RRSBS_Durable_Versioned_Snapshots.sql)
- [Legacy effective-dating migration](../Database/Flyway/SQL/V00.02.000100__Add_RRSBS_Effective_Dating.sql)
