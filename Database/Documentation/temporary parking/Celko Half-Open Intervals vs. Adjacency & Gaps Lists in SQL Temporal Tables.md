# Celko Half-Open Intervals vs. Adjacency & Gaps Lists in SQL Temporal Tables

## Overview

Joe Celko's advocacy for half-open interval `

***

## The Three Competing Approaches

### 1. Adjacency / Gaps List (Start-Only Table)

The simplest pattern stores only the `task_start_date` per row and derives the end date via a self-join VIEW:[^1]

```sql
CREATE VIEW ContiguousTasks (task_id, task_score, task_start_date, task_end_date)
AS
SELECT T1.task_id, MAX(T1.task_score),
       T1.task_start_date,
       DATEADD(DD, -1, MIN(T2.task_start_date))
FROM Tasks AS T1
LEFT OUTER JOIN Tasks AS T2
  ON T1.task_id = T2.task_id
 AND T1.task_start_date < T2.task_start_date
GROUP BY T1.task_id, T1.task_start_date;
```

**Critical problems:**
- **Gaps are invisible.** If two rows are inserted with a gap between their start dates, the VIEW silently produces a false `task_end_date` that bridges the gap — no constraint fires.[^1]
- **Overlaps are also invisible.** Nothing in the schema prevents two rows for the same key from having logically overlapping periods.[^1]
- **Rows model half a fact.** Without the end date stored, a row does not model a complete temporal fact; every query must re-derive the missing half via a self-join.[^1]
- **Performance scales poorly.** The self-join grows expensive as the table grows. A clustered index on `(task_id, task_start_date)` helps but cannot eliminate the computation and grouping cost.[^1]

### 2. Simple History Table (start + end, no contiguity enforcement)

Adds `task_end_date` to the schema and a `CHECK (task_start_date <= task_end_date)` constraint:[^1]

```sql
CREATE TABLE Tasks (
    task_id          INTEGER NOT NULL,
    task_score       CHAR(1) NOT NULL,
    task_start_date  DATE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    task_end_date    DATE,   -- NULL means still active
    CONSTRAINT end_and_start_dates_in_sequence
        CHECK (task_start_date <= task_end_date),
    PRIMARY KEY (task_id, task_start_date)
);
```

This stores complete facts per row, but **nothing prevents gaps or overlaps**. There is also no safeguard against multiple rows per task having `task_end_date IS NULL` (multiple "current" open intervals), which requires either a `CREATE ASSERTION` (not supported in T-SQL) or a trigger. Standard SQL provides `CREATE ASSERTION` to force a maximum of one NULL per task, but SQL Server requires a trigger or a `WITH CHECK OPTION` view workaround instead.[^1]

### 3. Celko / Kuznetsov Contiguous Half-Open Interval Table

The fully contiguous design adds a `previous_end_date` column and a self-referencing FOREIGN KEY:[^2][^1]

```sql
CREATE TABLE Tasks (
    task_id             INTEGER NOT NULL,
    task_score          CHAR(1) NOT NULL,
    previous_end_date   DATE,           -- NULL = first task in chain
    current_start_date  DATE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    current_end_date    DATE,           -- NULL = task still in progress
    CONSTRAINT prev_end_before_start
        CHECK (previous_end_date <= current_start_date),
    CONSTRAINT start_before_end
        CHECK (current_start_date <= current_end_date),
    CONSTRAINT end_dates_differ
        CHECK (previous_end_date <> current_end_date),
    PRIMARY KEY (task_id, current_start_date),
    UNIQUE      (task_id, previous_end_date),   -- one NULL (first task)
    UNIQUE      (task_id, current_end_date),    -- one NULL (active task)
    FOREIGN KEY (task_id, previous_end_date)
        REFERENCES Tasks (task_id, current_end_date)
);
```

The FOREIGN KEY is the mechanism that enforces contiguity declaratively: a row can only exist if its `previous_end_date` equals the `current_end_date` of some already-existing row for the same task. This creates an induction chain — prove the first row is valid, then prove each subsequent row abuts its predecessor, and by induction the entire timeline has no gaps and no overlaps.[^2][^1]

***

## The Mathematical Foundation: Why Half-Open Wins

### Closure Property

The defining algebraic advantage is **closure under abutment**:[^3][^4]

- Abutting two half-open intervals `[A, B)` and `[B, C)` yields the half-open interval `[A, C)`.
- Removing `[B, C)` from `[A, C)` yields `[A, B)`.
- These results are themselves half-open intervals — the set is *closed* under these operations.[^4][^3]

Closed intervals `[A, B]` and `[B+ε, C]` do not have this property: there is always an infinitesimally thin gap or overlap at the boundary, making arithmetic on them fragile.[^4][^2]

### Each Point in Time Belongs to Exactly One Interval

With half-open intervals, **each moment in time belongs to one and only one interval**. The ISO OVERLAPS() predicate, defined in the ANSI SQL Standard, is built on this principle: a period includes its starting point but excludes its endpoint. This means adjacent half-open intervals — e.g., a day shift ending at 17:00 and an evening shift starting at 17:00 — are non-overlapping; the boundary instant belongs unambiguously to the second interval.[^2]

With closed intervals, the boundary point (17:00:00) is included in *both* intervals, forcing you to handle the collision in application code or queries.[^5][^2]

### Avoiding the "Last Moment" Problem

Temporal data types represent time with finite precision. A closed interval that should end "at the end of the day" faces an ambiguous last moment: is it `23:59:59`, `23:59:59.999`, `23:59:59.9999999`? The answer depends on which data type and precision is in use. Half-open intervals eliminate this entirely: the end point is the *start* of the excluded next interval, so `end = '2026-01-02'` means "everything up to but not including January 2nd" regardless of fractional-second precision.[^6][^5]

***

## Comparison Table

| Criterion | Adjacency / Gaps List | Simple History Table | Celko Contiguous Half-Open |
|---|---|---|---|
| Gaps detectable via DDL | ❌ No | ❌ No | ✅ Yes — FK enforces abutment[^1] |
| Overlaps prevented by DDL | ❌ No | ❌ No | ✅ Yes — UNIQUE on start + end[^1] |
| Each point in one interval | ❌ Implied only | ⚠️ By convention | ✅ Guaranteed by constraints[^2] |
| Multiple NULLs (open tasks) | N/A | ❌ Requires trigger | ✅ UNIQUE allows one NULL per task[^1] |
| Self-join for end date | ❌ Required for every query | ✅ Stored | ✅ Stored[^1] |
| Duration arithmetic correct | ❌ Error-prone | ⚠️ BETWEEN trap with DATETIME | ✅ end - start is exact[^1][^5] |
| Closure under abutment | ❌ No | ❌ Not enforced | ✅ Mathematically closed[^3][^4] |
| Boundary ambiguity | ❌ High | ⚠️ Medium | ✅ None[^6] |
| DDL complexity | ✅ Simple | ✅ Simple | ⚠️ Complex but declarative[^1] |

***

## Why Declarative Beats Procedural Enforcement

### Triggers Are Brittle

The procedural alternative for enforcing contiguity is a set of INSERT/UPDATE/DELETE triggers that validate the timeline before each change. These:
- Fire row-by-row in many engines, causing N+1 query patterns under bulk loads.
- Are easy to disable accidentally during migrations.
- Cannot prevent gaps that arise from multi-statement transactions that temporarily violate invariants mid-transaction without deferred constraints.
- Require re-implementing the same logic in every application path that touches the table.[^7][^1]

### The Induction Guarantee

Celko explicitly frames the FK chain as mathematical **induction**: prove the first row is correct (the NULL `previous_end_date` anchor), then prove that any row in the chain forces its successor to abut it via the FK. By induction, the entire chain for any `task_id` is guaranteed gap-free and overlap-free — not as a result of running a validation scan, but as a structural consequence of the DDL.[^1]

### Comparison with SQL Server Temporal Tables

SQL Server's built-in system-versioned temporal tables (`FOR SYSTEM_TIME`) also use half-open intervals internally (`ValidFrom` / `ValidTo` with `DATETIME2`), adopting the same ISO model. However, they enforce system time automatically for audit history, not business-time contiguity for application logic. Furthermore, the history table in SQL Server temporal tables cannot have primary keys, foreign key constraints, or most indexes, limiting their use for business-rule enforcement. For application-managed business timelines — like task assignment history, pricing periods, or SLA tracking — the Celko/Kuznetsov DDL pattern is necessary because the built-in temporal feature does not enforce user-defined period contiguity.[^8][^9][^7]

***

## Practical T-SQL Implications

### Point-in-Time Lookup

With half-open intervals, the canonical point-in-time query uses `>=` and `<` rather than `BETWEEN`:

```sql
SELECT task_score
FROM Tasks
WHERE task_id = @id
  AND current_start_date <= @my_time
  AND (@my_time < current_end_date OR current_end_date IS NULL);
```

This is safer than `BETWEEN` because `BETWEEN` in SQL is always inclusive on both ends (`[A, B]`), which would incorrectly include the boundary row from the prior period.[^10][^6]

### Duration Calculation

Because the end date is excluded, duration is simply `end - start` with no fencepost correction needed. A closed `[2026-01-01, 2026-01-31]` interval requires adding 1 day to get the true duration of January; `[^8]

### Inserting the First Row

The only procedural step required is bootstrapping the chain, since the FK references a row that doesn't yet exist for a new `task_id`. In T-SQL, this requires temporarily disabling the FK with `ALTER TABLE Tasks NOCHECK CONSTRAINT ALL`, inserting the first row with `previous_end_date = NULL`, then re-enabling the constraint. After that, all subsequent inserts are enforced declaratively.[^1]

***

## Conclusion

The Celko half-open contiguous interval design wins across every integrity dimension that matters in temporal tables. The adjacency-list approach trades correctness for simplicity, silently allowing gaps and hiding overlaps. The simple history table adds an end date but remains unable to enforce abutment without procedural code. Only the half-open model with the self-referencing FK chain provides mathematical closure, eliminates boundary ambiguity, and enforces gap-free, overlap-free timelines purely through DDL constraints — no triggers, no application-layer enforcement, no periodic validation scans required.[^3][^4][^2][^1]

---

## References

1. [Contiguous Time Periods | Simple Talk](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/contiguous-time-periods/) - Nov 22, 2010  —  We are going to create a  table  of some kind of vague Tasks that are done one righ...

2. [Modeling Time - Simple Talk - Redgate Software](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/modeling-time/) - The advantage of the half open interval model is that two time periods can be abutted to each other....

3. [[PDF] Making Time Using Temporal Data - Embarcadero](https://www.embarcadero.com/resources/white-papers?download=684) - Joe Celko serves as Member of Technical Advisory Board of Cogito, Inc. Mr. Celko joined the ANSI X3H...

4. [Discrete and Continuous data in SQL | Simple Talk - Redgate Software](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/discrete-and-continuous-data-in-sql/) - The advantage is that you can abut two half-open intervals together and get a third half-open interv...

5. [Time intervals and other ranges should be half-open - Bill Schneider](http://wrschneider.github.io/2014/01/07/time-intervals-and-other-ranges-should.html) - Time intervals and other ranges should be half-open. It is a good practice to treat time intervals a...

6. [java - Is there a standard for inclusive/exclusive ends of time intervals?](https://stackoverflow.com/questions/9795391/is-there-a-standard-for-inclusive-exclusive-ends-of-time-intervals) - By the way, note that Half-Open [) means avoiding the SQL BETWEEN conjunction as that is always full...

7. [Enforcing and Validating Temporal Referential Constraints](https://docs.teradata.com/r/Enterprise_IntelliFlex_VMware/Temporal-Table-Support/Enforcing-and-Validating-Temporal-Referential-Constraints) - Learn to guarantee referential integrity using procedural constraints like triggers instead of using...

8. [Temporal Tables - SQL Server | Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables?view=sql-server-ver17) - A system-versioned temporal table is a type of user table designed to keep a full history of data ch...

9. [Temporal table considerations and limitations - SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-table-considerations-and-limitations?view=sql-server-ver17) - There are some considerations and limitations to be aware of when working with temporal tables, due ...

10. [Temporal validity and open/closed intervals - KiBeHa](https://www.kibeha.dk/2017/01/temporal-validity-and-openclosed.html) - Temporal validity is simply an easier way to deal with these things than doing it yourself with pred...

