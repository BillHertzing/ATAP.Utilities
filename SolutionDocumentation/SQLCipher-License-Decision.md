# Decision Record: SQLitePCLRaw sqlite3mc vs Zetetic SQLCipher for .NET

> **Moved from `_Planning/Explainers/` on 2026-07-06** (Sprint 0012 Task 12.45.d,
> documentation reorganization per `PlanDocumentationReorganization.md`). This is the
> merge of the former `0001-sqlcipher-licensing.md` (Sprint 1, Task 1.6) and
> `SQLCipher-License-Decision.md` (DR-2026-03-16); both `_Planning` copies are deleted.
>
> **Eventual home: AceCommander SolutionDocumentation** — parked here because
> AceCommander has no sprint worktree in Sprint 0012 (user decision 2026-07-06);
> relocation is tracked as a scope-creep item.

- Decision ID: DR-2026-03-16-SQLCipher-License
- Date: 2026-03-16 (original explainer: Sprint 1, Task 1.6)
- Status: Accepted
- Related Task: Task 1.6 in TASKS.md

## Context

AceCommander needs encrypted local storage on all platforms (Windows, Android, iOS)
for offline-capable operation, with SQL Server on the server side. SQLCipher is the
standard for encrypted SQLite; a licensing and support decision is needed for the
SQLCipher-compatible .NET dependency. Two implementation paths exist for .NET:

1. `SQLitePCLRaw.bundle_e_sqlite3mc`
2. Zetetic SQLCipher for .NET

## High-Level Explainer: What a SQLCipher Database Is

SQLCipher is an encrypted variant of SQLite. It keeps the SQLite file format and SQL
behavior developers expect, but encrypts database pages at rest using strong
cryptography. At a high level, SQLCipher adds:

- Transparent encryption and decryption during read/write
- Key-based access control to open and use the database
- Compatibility with standard SQLite workflows (tables, indexes, transactions, migrations)

For this application, SQLCipher-style encrypted local storage matters because it
allows offline-first behavior while protecting sensitive data if a device is lost,
stolen, or inspected.

## Option Comparison

### Option A: SQLitePCLRaw.bundle_e_sqlite3mc (open-source)

- Package: `SQLitePCLRaw.bundle_e_sqlite3mc`
- Cost/License: Free, MIT
- Maintained by: community (Eric Sink's SQLitePCLRaw ecosystem)
- Compatibility claim: reads/writes standard SQLCipher databases (via the sqlite3mc bundle)
- .NET MAUI support: via standard SQLitePCLRaw integration

Pros:

- No recurring license cost; MIT license compatible with the project's open-source aspirations
- Fast to adopt in the current schedule
- Sufficient for planned development, test, and early production validation
- Maintains the SQLCipher-compatible encrypted local database strategy

Cons:

- No official commercial support SLA
- Compatibility confidence is practical/community-based, not vendor-guaranteed
- May require additional engineering time if edge cases appear on specific MAUI targets

### Option B: Zetetic SQLCipher for .NET (commercial)

- Cost/License: $499/year, commercial
- Maintained by: Zetetic (the SQLCipher creators); official vendor support
- Compatibility claim: guaranteed (official implementation)
- .NET MAUI support: official, but requires separate MAUI licensing verification

Pros:

- Official support channel and accountability
- Reduced uncertainty for production incidents
- Stronger assurance for long-term enterprise operations

Cons:

- Ongoing annual cost; procurement/licensing overhead
- Licensing terms may complicate open-source distribution
- Not required yet for immediate execution of current roadmap milestones

## Decision

**Adopt `SQLitePCLRaw.bundle_e_sqlite3mc` (Option A)** for initial development.

## Rationale

- Meets the technical requirement for SQLCipher-compatible encrypted local storage
- Zero cost; avoids near-term licensing spend and procurement friction
- Proven practical compatibility with the SQLCipher database format; sqlite3mc tracks
  upstream SQLite and SQLCipher releases closely, making the community-maintenance
  risk acceptable
- Keeps momentum on MAUI and offline-first milestones without blocking on a
  commercial purchase; paid support can be deferred until real production risk is
  observed instead of assumed

## Risk and Revisit Trigger

Risk: MAUI platform-specific issues (stability, compatibility, or operational
support gaps) may surface under production conditions — particularly iOS Keychain
interaction or Android Keystore edge cases.

Revisit gate:

- Re-evaluate Zetetic if MAUI integration surfaces platform-specific encryption
  issues (original gate: before Sprint 13, the MAUI scaffold phase)
- Reopen this decision if production MAUI issues arise that cannot be resolved
  quickly with community support; if triggered, evaluate upgrading to Zetetic
  SQLCipher for .NET as the default runtime package

## Consequences

Immediate: proceed with the sqlite3mc-based implementation; no licensing spend this cycle.
Future: keep a migration path to the Zetetic package if supportability requirements increase.

## Follow-up Actions

1. Track MAUI runtime behavior and encrypted-DB reliability in testing and pilot deployments.
2. Add a checkpoint before broader production rollout to confirm whether commercial support is required.
3. Document any platform-specific defects to inform a potential switch decision.

## References

- Modernization Plan: Guiding Constraints
- Conversation Bookmark: Key Architectural Decisions → Core Platform
