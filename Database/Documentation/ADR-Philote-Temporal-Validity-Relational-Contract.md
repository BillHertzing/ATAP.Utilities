# ADR: Philote temporal-validity relational contract

Status: **Proposed for joint HITL ratification at Gate PTV-G0**

Task: **14.21.e / PTV-020**

Date: **2026-08-08**

## Decision boundary

This ADR freezes the PTV-020 relational contract for review with the PTV-010 API
contract and PTV-030 seed registry. It is documentation, not implementation
authority. No active migration, archive SQL, seed, CSV, database, package, or
deployment surface is changed by PTV-020.

The requirements under **Ratified upstream decisions** are already adopted by the
temporal-validity plan. The requirements under **PTV-020 contract proposed for
PTV-G0** become ratified only if HITL approves all three Wave 0 contracts together.

## Evidence classes

### Verified current facts

Direct source inspection on 2026-08-08 verified the following current state:

- `V00010__Create_RPRRSBSI_V3_Core_Schema.sql` creates an
  `ATAPUtilities.TimeBlock` table with `TimeBlockId`, `PhiloteId`, `Ordinal`,
  `StartUtc`, `DurationTicks`, and `EndUtc`.
- `V00020__Load_RPRRSBSI_V3_Philote.sql` loads exactly 22 approved Philotes.
- `V00030__Load_RPRRSBSI_V3_TimeBlock.sql` requires a header-only
  `TimeBlock.csv` and an empty initial TimeBlock collection.
- `V00130__Assert_RPRRSBSI_V3_Initial_Graph.sql` asserts 22 Philotes and zero
  TimeBlocks in the current initial graph.
- The V3 physical data dictionary describes the same six-column TimeBlock
  contract. It is pre-adoption source evidence, not the target contract.
- The retained PowerShell, Path, and SQL compendiums document stable semantic
  identities. They do not authorize temporal seed facts or SQL mutation.
- PTV-000 found the active TimeBlock/Itenso surfaces that the temporal adoption
  program must replace. It did not build, run, or mutate a database.

The source hashes and exact inspection commands are recorded in the PTV-020
handoff. No runtime or deployed-state claim is made from these facts.

### Ratified upstream decisions

The adopted temporal-validity plan already requires:

- Philote periods describe **business-valid identity existence**.
- A period is half-open: `[ValidFromUtc, ValidToUtc)`.
- `ValidToUtc = NULL` means no known end.
- Gaps are valid; overlaps are invalid.
- At most one open-ended period exists for a Philote, and it is last.
- Boundaries are stored without redundant duration or ordinal state.
- The corrected predecessor-chain model enforces ordering and non-overlap.
- SQL Server system-versioned transaction time is separate and deferred.

### PTV-020 contract proposed for PTV-G0

The remaining sections freeze exact physical names, constraints, mutation
semantics, concurrency, and query predicates for joint human review.

## Valid time is not transaction time

`ValidFromUtc` and `ValidToUtc` answer, "When did this Philote represent a valid
business identity?" They do not answer when a row was inserted, corrected, or
observed by SQL Server.

This contract therefore defines no `PERIOD FOR SYSTEM_TIME`, `SYSTEM_VERSIONING`,
`GENERATED ALWAYS`, audit timestamp, rowversion, or history table. A correction
may replace an incorrect valid-time fact in place. Recovering when that correction
was made would require a separately approved transaction-time or audit design.

`datetime2(7)` has no time-zone offset. The `Utc` suffix is a caller and seed
contract: all values must already be normalized UTC instants. No table default or
procedure may substitute `GETDATE`, `GETUTCDATE`, `SYSDATETIME`,
`SYSUTCDATETIME`, or an execution-time value for a business fact.

## Physical table contract

The active initial lineage will replace `ATAPUtilities.TimeBlock` with exactly one
aggregate-owned table named `ATAPUtilities.PhiloteValidityPeriod`.

| Column | SQL Server type | Null | Meaning |
| --- | --- | --- | --- |
| `PhiloteValidityPeriodId` | `uniqueidentifier` | No | Stable period-row identity supplied by the caller or approved seed registry. |
| `PhiloteId` | `uniqueidentifier` | No | Parent identity in `ATAPUtilities.Philote`. |
| `PreviousValidToUtc` | `datetime2(7)` | Yes | End of the immediate predecessor; null only on the first row. |
| `ValidFromUtc` | `datetime2(7)` | No | Included business-valid boundary. |
| `ValidToUtc` | `datetime2(7)` | Yes | Excluded boundary; null means open-ended. |

No other column is part of this contract. In particular, `Ordinal`, `StartUtc`,
`DurationTicks`, `EndUtc`, computed duration, execution timestamps, and audit
columns are prohibited without a later ADR.

### Named constraints and actions

| Name | Frozen definition |
| --- | --- |
| `PK_PhiloteValidityPeriod` | Primary key on `(PhiloteValidityPeriodId)`. |
| `FK_PhiloteValidityPeriod_Philote` | `(PhiloteId)` references `Philote(PhiloteId)` with `ON DELETE NO ACTION ON UPDATE NO ACTION`. |
| `CK_PhiloteValidityPeriod_NonEmpty` | `ValidToUtc IS NULL OR ValidFromUtc < ValidToUtc`. |
| `CK_PhiloteValidityPeriod_PredecessorNotAfterStart` | `PreviousValidToUtc IS NULL OR PreviousValidToUtc <= ValidFromUtc`. |
| `UQ_PhiloteValidityPeriod_Philote_ValidFromUtc` | Unique `(PhiloteId, ValidFromUtc)`. |
| `UQ_PhiloteValidityPeriod_Philote_ValidToUtc` | Unique `(PhiloteId, ValidToUtc)`. |
| `UQ_PhiloteValidityPeriod_Philote_PreviousValidToUtc` | Unique `(PhiloteId, PreviousValidToUtc)`. |
| `FK_PhiloteValidityPeriod_Predecessor` | `(PhiloteId, PreviousValidToUtc)` references `(PhiloteId, ValidToUtc)` with `ON DELETE NO ACTION ON UPDATE NO ACTION`. |

SQL Server unique constraints treat the composite key containing a null boundary
as one key for a given Philote. Consequently the two nullable unique keys permit
only one open end and only one first row per Philote. A null
`PreviousValidToUtc` bypasses the self-FK, as intended only for that first row.

The executable DDL shape to be implemented after PTV-G0 is:

```sql
CREATE TABLE [ATAPUtilities].[PhiloteValidityPeriod]
(
    [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
    [PhiloteId] uniqueidentifier NOT NULL,
    [PreviousValidToUtc] datetime2(7) NULL,
    [ValidFromUtc] datetime2(7) NOT NULL,
    [ValidToUtc] datetime2(7) NULL,
    CONSTRAINT [PK_PhiloteValidityPeriod]
        PRIMARY KEY ([PhiloteValidityPeriodId]),
    CONSTRAINT [FK_PhiloteValidityPeriod_Philote]
        FOREIGN KEY ([PhiloteId])
        REFERENCES [ATAPUtilities].[Philote] ([PhiloteId])
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT [CK_PhiloteValidityPeriod_NonEmpty]
        CHECK ([ValidToUtc] IS NULL OR [ValidFromUtc] < [ValidToUtc]),
    CONSTRAINT [CK_PhiloteValidityPeriod_PredecessorNotAfterStart]
        CHECK ([PreviousValidToUtc] IS NULL OR [PreviousValidToUtc] <= [ValidFromUtc]),
    CONSTRAINT [UQ_PhiloteValidityPeriod_Philote_ValidFromUtc]
        UNIQUE ([PhiloteId], [ValidFromUtc]),
    CONSTRAINT [UQ_PhiloteValidityPeriod_Philote_ValidToUtc]
        UNIQUE ([PhiloteId], [ValidToUtc]),
    CONSTRAINT [UQ_PhiloteValidityPeriod_Philote_PreviousValidToUtc]
        UNIQUE ([PhiloteId], [PreviousValidToUtc]),
    CONSTRAINT [FK_PhiloteValidityPeriod_Predecessor]
        FOREIGN KEY ([PhiloteId], [PreviousValidToUtc])
        REFERENCES [ATAPUtilities].[PhiloteValidityPeriod] ([PhiloteId], [ValidToUtc])
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);
```

### Why the chain rejects overlap

For every non-first row, the self-FK identifies exactly one predecessor end.
The predecessor check requires that end to be no later than the current start,
and the non-empty check requires the current start to be earlier than its end.
Therefore ends strictly increase along every link. The two unique link keys
prohibit branches and duplicate roots. A finite non-empty set has one root and
cannot contain a cycle, so it forms one ordered chain. Equality between a
predecessor end and the next start represents adjacency; strict inequality
represents a permitted gap.

## Invalid-row counterexamples

Assume all IDs are distinct valid GUIDs and all rows share one existing
`PhiloteId`. Times are UTC `datetime2(7)` values.

| Invalid shape | Concrete counterexample | Rejection contract |
| --- | --- | --- |
| Arbitrary overlap | `A=[01:00,04:00)` is first; `B.PreviousValidToUtc=04:00`, `B=[03:00,05:00)`. | `CK_PhiloteValidityPeriod_PredecessorNotAfterStart` rejects `04:00 <= 03:00`. A different predecessor cannot produce a second branch because both predecessor keys are unique. |
| Duplicate starts | `A.ValidFromUtc=B.ValidFromUtc=01:00`. | `UQ_PhiloteValidityPeriod_Philote_ValidFromUtc`. |
| Duplicate ends | `A.ValidToUtc=B.ValidToUtc=04:00`. | `UQ_PhiloteValidityPeriod_Philote_ValidToUtc`. |
| Two open ends | `A.ValidToUtc=NULL` and `B.ValidToUtc=NULL`. | The nullable composite `UQ_PhiloteValidityPeriod_Philote_ValidToUtc` permits one null end per Philote. |
| Open end followed by another row | `A=[01:00,NULL)` followed by `B=[05:00,06:00)`. | `B` cannot reference the null end; giving `B` a null predecessor creates a second root and violates `UQ_PhiloteValidityPeriod_Philote_PreviousValidToUtc`; linking it to an earlier end duplicates a consumed predecessor or disconnects a finite chain. |
| Cycle | `A.Previous=B.ValidToUtc` and `B.Previous=A.ValidToUtc`. | Each link requires predecessor end `<` current end. The pair would require both `B.End < A.End` and `A.End < B.End`; at least one predecessor check fails. |
| Zero duration | `A=[01:00,01:00)`. | `CK_PhiloteValidityPeriod_NonEmpty`. |
| Reversed endpoints | `A=[02:00,01:00)`. | `CK_PhiloteValidityPeriod_NonEmpty`. |
| Broken predecessor link | `B.PreviousValidToUtc=03:00` when no row for the Philote ends at `03:00`. | `FK_PhiloteValidityPeriod_Predecessor`. |

The future verification suite must execute each shape both as a direct row-set
attempt and through every applicable procedure. DDL reasoning alone is not
runtime evidence.

## Mutation boundary

Application principals receive procedure execution, not ad hoc table DML. Exact
role names and grants remain a separately reviewed security surface; this ADR
does not issue a grant. Migration ownership may perform DDL and seed DML only
inside the approved initial migration.

### Frozen procedure surface

All procedure names are in schema `ATAPUtilities`. Parameters occur in the exact
order below and have no defaults; the caller supplies every argument. SQL Server
procedure parameters do not support a `NOT NULL` declaration, so each procedure
must explicitly reject a null passed for a row marked **No** under **Allows null**
before changing state. A nullable expected value is still a required argument and
uses null-safe equality: two nulls match, while null and non-null do not.

| Procedure | # | Exact parameter | SQL type | Allows null | Contract |
| --- | ---: | --- | --- | --- | --- |
| `CreateFirstPhiloteValidityPeriod` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Existing parent Philote. |
| `CreateFirstPhiloteValidityPeriod` | 2 | `@PhiloteValidityPeriodId` | `uniqueidentifier` | No | New stable row ID. |
| `CreateFirstPhiloteValidityPeriod` | 3 | `@ValidFromUtc` | `datetime2(7)` | No | Included first boundary. |
| `CreateFirstPhiloteValidityPeriod` | 4 | `@ValidToUtc` | `datetime2(7)` | Yes | Excluded end; null creates the first open period. |
| `CloseCurrentPhiloteValidityPeriod` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `CloseCurrentPhiloteValidityPeriod` | 2 | `@ExpectedPhiloteValidityPeriodId` | `uniqueidentifier` | No | Exact open row expected by the caller. |
| `CloseCurrentPhiloteValidityPeriod` | 3 | `@ValidToUtc` | `datetime2(7)` | No | New excluded end, strictly after the row start. |
| `ReactivatePhiloteValidityPeriod` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `ReactivatePhiloteValidityPeriod` | 2 | `@PhiloteValidityPeriodId` | `uniqueidentifier` | No | New stable row ID. |
| `ReactivatePhiloteValidityPeriod` | 3 | `@ValidFromUtc` | `datetime2(7)` | No | New open row start, strictly after the last bounded end. |
| `CorrectPhiloteValidityPeriodBoundary` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `CorrectPhiloteValidityPeriodBoundary` | 2 | `@PhiloteValidityPeriodId` | `uniqueidentifier` | No | Row to correct. |
| `CorrectPhiloteValidityPeriodBoundary` | 3 | `@ExpectedValidFromUtc` | `datetime2(7)` | No | Stale-write guard for the old start. |
| `CorrectPhiloteValidityPeriodBoundary` | 4 | `@ExpectedValidToUtc` | `datetime2(7)` | Yes | Null-safe stale-write guard for the old end. |
| `CorrectPhiloteValidityPeriodBoundary` | 5 | `@NewValidFromUtc` | `datetime2(7)` | No | Replacement included start. |
| `CorrectPhiloteValidityPeriodBoundary` | 6 | `@NewValidToUtc` | `datetime2(7)` | Yes | Replacement excluded end; null makes the corrected row open. |
| `SplitPhiloteValidityPeriod` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `SplitPhiloteValidityPeriod` | 2 | `@PhiloteValidityPeriodId` | `uniqueidentifier` | No | Existing bounded row retained as the earlier segment. |
| `SplitPhiloteValidityPeriod` | 3 | `@ExpectedValidFromUtc` | `datetime2(7)` | No | Stale-write guard for the old start. |
| `SplitPhiloteValidityPeriod` | 4 | `@ExpectedValidToUtc` | `datetime2(7)` | No | Stale-write guard for the bounded old end. |
| `SplitPhiloteValidityPeriod` | 5 | `@SplitUtc` | `datetime2(7)` | No | Boundary strictly inside the expected bounded row. |
| `SplitPhiloteValidityPeriod` | 6 | `@NewLaterPhiloteValidityPeriodId` | `uniqueidentifier` | No | Stable ID for the new later segment. |
| `MergeAdjacentPhiloteValidityPeriods` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `MergeAdjacentPhiloteValidityPeriods` | 2 | `@EarlierPhiloteValidityPeriodId` | `uniqueidentifier` | No | Row ID preserved by the merge. |
| `MergeAdjacentPhiloteValidityPeriods` | 3 | `@LaterPhiloteValidityPeriodId` | `uniqueidentifier` | No | Row ID removed by the merge. |
| `MergeAdjacentPhiloteValidityPeriods` | 4 | `@ExpectedBoundaryUtc` | `datetime2(7)` | No | Must equal both the earlier end and later start. |
| `DeletePhiloteValidityPeriod` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `DeletePhiloteValidityPeriod` | 2 | `@PhiloteValidityPeriodId` | `uniqueidentifier` | No | Row to delete. |
| `DeletePhiloteValidityPeriod` | 3 | `@ExpectedValidFromUtc` | `datetime2(7)` | No | Stale-write guard for the old start. |
| `DeletePhiloteValidityPeriod` | 4 | `@ExpectedValidToUtc` | `datetime2(7)` | Yes | Null-safe stale-write guard for the old end. |
| `ReplacePhiloteValidityPeriodSet` | 1 | `@PhiloteId` | `uniqueidentifier` | No | Aggregate scope. |
| `ReplacePhiloteValidityPeriodSet` | 2 | `@Periods` | `ATAPUtilities.PhiloteValidityPeriodSetInput READONLY` | No | Complete desired set; an empty TVP removes every period. |

The operation semantics are also normative:

| Procedure | Success precondition and transformation |
| --- | --- |
| `CreateFirstPhiloteValidityPeriod` | Requires no existing row and creates the first bounded or open period. |
| `CloseCurrentPhiloteValidityPeriod` | Requires the exact expected open row and closes it. |
| `ReactivatePhiloteValidityPeriod` | Requires no open row and a strict gap after the last bounded end, then creates an open row linked to that end. |
| `CorrectPhiloteValidityPeriodBoundary` | Requires the exact null-safe expected boundaries, applies the new boundaries, and repairs predecessor and successor links atomically. |
| `SplitPhiloteValidityPeriod` | Requires the exact expected bounded row and an interior split, preserves the earlier ID, and assigns the new ID to the later segment. |
| `MergeAdjacentPhiloteValidityPeriods` | Requires the two IDs to be consecutive and exactly adjacent at the expected boundary, preserves the earlier ID, removes the later ID, and repairs the successor link. |
| `DeletePhiloteValidityPeriod` | Requires the exact null-safe expected row; supports first, middle, last, or open-current deletion and repairs the remaining chain. Deleting the final row leaves an empty set. |
| `ReplacePhiloteValidityPeriodSet` | Validates and atomically replaces the complete set. An explicitly empty TVP removes the set. |

The replace input type is frozen as:

```sql
CREATE TYPE [ATAPUtilities].[PhiloteValidityPeriodSetInput] AS TABLE
(
    [PhiloteValidityPeriodId] uniqueidentifier NOT NULL,
    [PreviousValidToUtc] datetime2(7) NULL,
    [ValidFromUtc] datetime2(7) NOT NULL,
    [ValidToUtc] datetime2(7) NULL,
    PRIMARY KEY ([PhiloteValidityPeriodId]),
    UNIQUE ([ValidFromUtc]),
    UNIQUE ([ValidToUtc]),
    UNIQUE ([PreviousValidToUtc])
);
```

`PhiloteId` is deliberately absent from the TVP because the procedure parameter
owns the aggregate scope.

### Frozen result contract

On success, every procedure returns exactly one rowset containing the complete
resulting set. An empty resulting set returns the same five-column schema with
zero rows. Column order, names, types, and nullability are:

| # | Result column | SQL type | Allows null |
| ---: | --- | --- | --- |
| 1 | `PhiloteValidityPeriodId` | `uniqueidentifier` | No |
| 2 | `PhiloteId` | `uniqueidentifier` | No |
| 3 | `PreviousValidToUtc` | `datetime2(7)` | Yes |
| 4 | `ValidFromUtc` | `datetime2(7)` | No |
| 5 | `ValidToUtc` | `datetime2(7)` | Yes |

Rows are ordered by `ValidFromUtc ASC`, then
`PhiloteValidityPeriodId ASC`. Procedures use `SET NOCOUNT ON`, return integer
code `0` after successful rowset production, and emit no other rowset. Domain or
concurrency rejection uses `THROW`, returns no success rowset, and rolls back; it
does not silently normalize, truncate, invent a timestamp, or partially apply.

### Atomic rewrite rule

SQL Server constraints are immediate rather than deferrable. Updating a boundary
that participates in both a unique key and the self-FK can otherwise create an
invalid transient state even when the final set is valid. Each procedure must:

1. acquire the Philote-scoped writer lock described below;
2. materialize the current set and verify all expected old values;
3. construct and validate the complete desired set in memory;
4. remove existing rows from last to first, so no surviving row references a
   deleted predecessor;
5. insert desired rows from first to last; and
6. re-read and validate the persisted set before commit.

The period table is aggregate-owned. A new external FK to a period ID is
prohibited until another ADR replaces this rewrite rule. Failures roll back the
entire transaction; there is no partial repair mode.

## Concurrency strategy

Every mutation uses `SET XACT_ABORT ON`, an explicit transaction, and an exclusive
transaction-owned `sys.sp_getapplock` on the canonical resource
`ATAPUtilities.PhiloteValidityPeriod:<lowercase-hyphenated-PhiloteId>`. A negative
lock result is an error. After acquiring it, the procedure reads the Philote's
set with `UPDLOCK, HOLDLOCK` before validating or changing rows.

This serializes all cooperating writers for one Philote while permitting writers
for different Philotes to proceed. Procedure inputs containing expected old IDs
or boundaries reject stale targeted mutations. Whole-set replacement is an
explicit authoritative overwrite after lock acquisition.

The conceptual lock template parses as T-SQL but is not an implementation:

```sql
SET XACT_ABORT ON;

DECLARE @PhiloteId uniqueidentifier = '00000000-0000-0000-0000-000000000001';
DECLARE @LockResult int;
DECLARE @LockResource nvarchar(255) =
    N'ATAPUtilities.PhiloteValidityPeriod:'
    + LOWER(CONVERT(nvarchar(36), @PhiloteId));

BEGIN TRANSACTION;

EXEC @LockResult = sys.sp_getapplock
    @Resource = @LockResource,
    @LockMode = 'Exclusive',
    @LockOwner = 'Transaction',
    @LockTimeout = 15000,
    @DbPrincipal = 'public';

IF @LockResult < 0
BEGIN
    ROLLBACK TRANSACTION;
    THROW 55100, 'Unable to acquire the Philote temporal-validity writer lock.', 1;
END;

SELECT
    [PhiloteValidityPeriodId],
    [PreviousValidToUtc],
    [ValidFromUtc],
    [ValidToUtc]
FROM [ATAPUtilities].[PhiloteValidityPeriod] WITH (UPDLOCK, HOLDLOCK)
WHERE [PhiloteId] = @PhiloteId
ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];

ROLLBACK TRANSACTION;
```

The concurrency acceptance test starts two sessions that call
`ReactivatePhiloteValidityPeriod` for the same Philote while it has no open row.
Exactly one call may commit. The other acquires the lock afterward, observes the
new open row, throws, and leaves the single committed row unchanged. Tests must
also prove different-Philote writers are not serialized by the same resource.

## Query contract

All parameters are `datetime2(7)` UTC business instants. Results order by
`ValidFromUtc`, then `PhiloteValidityPeriodId` whenever more than one row can
return. `BETWEEN` is prohibited because its upper bound is inclusive.

### Point-in-time containment

```sql
DECLARE @PhiloteId uniqueidentifier = '00000000-0000-0000-0000-000000000001';
DECLARE @AsOfUtc datetime2(7) = '2026-01-01T00:00:00.0000000';

SELECT [PhiloteValidityPeriodId], [ValidFromUtc], [ValidToUtc]
FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE [PhiloteId] = @PhiloteId
  AND [ValidFromUtc] <= @AsOfUtc
  AND ([ValidToUtc] IS NULL OR @AsOfUtc < [ValidToUtc])
ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];
```

### Bounded overlap

```sql
DECLARE @PhiloteId uniqueidentifier = '00000000-0000-0000-0000-000000000001';
DECLARE @SearchFromUtc datetime2(7) = '2026-01-01T00:00:00.0000000';
DECLARE @SearchToUtc datetime2(7) = '2026-02-01T00:00:00.0000000';

IF @SearchFromUtc >= @SearchToUtc
    THROW 55101, 'The search interval must be non-empty and forward.', 1;

SELECT [PhiloteValidityPeriodId], [ValidFromUtc], [ValidToUtc]
FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE [PhiloteId] = @PhiloteId
  AND [ValidFromUtc] < @SearchToUtc
  AND ([ValidToUtc] IS NULL OR @SearchFromUtc < [ValidToUtc])
ORDER BY [ValidFromUtc], [PhiloteValidityPeriodId];
```

### Current valid period

Future activations are permitted by the physical model, so an open-ended row is
not necessarily current yet. Current containment must apply both boundaries:

```sql
DECLARE @PhiloteId uniqueidentifier = '00000000-0000-0000-0000-000000000001';
DECLARE @NowUtc datetime2(7) = '2026-01-01T00:00:00.0000000';

SELECT [PhiloteValidityPeriodId], [ValidFromUtc], [ValidToUtc]
FROM [ATAPUtilities].[PhiloteValidityPeriod]
WHERE [PhiloteId] = @PhiloteId
  AND [ValidFromUtc] <= @NowUtc
  AND ([ValidToUtc] IS NULL OR @NowUtc < [ValidToUtc]);
```

The unique `(PhiloteId, ValidFromUtc)` key supports Philote-scoped start-order
access. Implementers must capture actual plans before adding a redundant index;
this ADR does not ratify speculative indexes.

## Consequences and close variants

- The predecessor chain gives declarative rejection of overlap without a trigger.
- Gaps and adjacency remain distinct valid shapes.
- Immediate constraints require atomic ordered rewrites for complex repairs.
- An empty period set means no known business-valid existence; it is not an
  anytime sentinel.
- A row that begins in the future is not current merely because its end is null.
- Changing `<=` to `<` in the point query would incorrectly exclude the included
  start; changing `<` to `<=` at an end would violate half-open semantics.
- Replacing either overlap `<` comparison with `<=` would make touching periods
  overlap incorrectly.
- Omitting `PhiloteId` from any unique or predecessor key would couple unrelated
  Philotes and is prohibited.
- Allowing cascade delete would erase validity facts implicitly and is prohibited.
- Adding a second null root, an unlinked subchain, or a successor to an open row
  is not a benign disconnected component; it violates the single-chain contract.

## Deferred and excluded

- Active or archive SQL edits, Flyway lineage changes, CSV or seed changes.
- PTV-030 deterministic period IDs and exact seed-validity instants.
- C# API types, serialization, adapters, and consumer migrations.
- Transaction-time history, audit history, soft delete, and external references
  to validity-period row IDs.
- Security-role names and grants, package/feed work, BuildMaster, database access,
  rehearsal, deployment, backup, restore, or deletion.

## PTV-G0 review checklist

- [ ] Accept the five exact columns, types, nullability, and prohibited columns.
- [ ] Accept all eight named constraints and both `NO ACTION` relationships.
- [ ] Accept the predecessor-chain proof and every invalid-row counterexample.
- [ ] Accept the eight-procedure application boundary and atomic rewrite rule.
- [ ] Accept Philote-scoped application locking and concurrent-activation test.
- [ ] Accept the half-open point, overlap, and current predicates.
- [ ] Confirm valid time remains separate from transaction time.
- [ ] Confirm PTV-030 supplies deterministic seed facts before implementation.
