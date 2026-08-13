# RRSBS ADR-148: Database Package and Compatibility Contract

Status: Proposed for Wave 1 review
Date: 2026-08-02
Owner: RDB-148 / Task 14.20.b.11

## Decision

The rebaseline ships immutable `ATAPUtilities.Database` content packages through
the `database-*` feed family. The new lineage begins at Flyway `00010` and
package `0.0.1`. Its manifest records package identity/version, manifest schema
version, Flyway lineage identifier/head, input hashes, and
`compatibleAppPackageRanges`.

Consumers resolve only the feed permitted by tier and ceiling, then validate the
exact app/database pair. A ReleaseBundle pins package ID/version/hash/feed and
app version; it never floats to latest. Old immutable 0.1.x packages remain
resolvable for their supported releases but never mix with the new lineage.

This ADR authorizes no package/feed/BuildMaster/ProGet/live action. PACKAGE-01,
COMPAT-01, PKG-AUTH-01, RDB-550--576, RDB-815, RDB-835, and RDB-838 own that work.

## Rules

1. Build once, hash, then promote unchanged one tier at a time.
2. `database-package-ceiling.json` is a maximum; higher feeds fail closed.
3. Missing, malformed, or nonmatching compatibility ranges fail closed.
4. Every bundle pair must satisfy the pinned database manifest range.
5. A lineage identifier binds history-table metadata, baseline version, package,
   and manifest. One package contains exactly one lineage.
6. Preflight compares installed/applied lineage with package lineage before any
   Flyway action. A mismatch rejects the operation.
7. Cutover/reset is an approved operation, never a compatibility fallback.

## Mixed-lineage rejection

New packages cannot include retired-chain migrations/seeds, consult an old
history table, or append to an old history. Old packages cannot include the new
baseline/history metadata. Validation rejects both lineage IDs, both migration
roots, inconsistent head metadata, or mismatched target history before Flyway.
It does not authorize repair, clean, baseline, history edits, deletion, or feed
mutation.

## Negative controls

1. Both lineages occur in one package, manifest, migration root, or seed set.
2. New package uses old history metadata, or old package uses new metadata.
3. Consumer selects a feed above tier or ceiling.
4. Missing, malformed, or nonmatching compatibility range passes.
5. Bundle floats to latest, omits hash/lineage, or pins an incompatible pair.
6. Old-app/new-DB or new-app/old-DB proceeds without COMPAT-01 disposition.
7. Mismatched target history reaches migrate, repair, clean, or baseline.
8. Hash mismatch or unlisted manifest input is accepted.
9. Promotion rebuilds or repackages an already promoted version.
10. Cleanup/deletion/package mutation is represented as compatibility validation.

## Consequences and acceptance checks

- RDB-550 defines manifest/lineage/hash fields and proves 0.1.1/0.1.2 resolve.
- RDB-555 checks ceiling/resolution; RDB-560/565 implement promotion/bundle pinning.
- RDB-570/RDB-815 prove mixed-lineage rejection; RDB-835 proves COMPAT-01 outcomes.
- RDB-576 inventories old-lineage metadata before any separately reviewed cleanup.

## Related authorities

- [Database Package Artifact and Feed Decision](Database-Package-Artifact-And-Feed-Decision.md)
- [Database Package Compatibility](Database-Package-Compatibility.md)
- [Database Package Ceiling File](Database-Package-Ceiling-File.md)
- [Database Package Consumer Resolution](Database-Package-Consumer-Resolution.md)
- [ReleaseBundle vs Database Package Architecture](ReleaseBundle-vs-DatabasePackage-Architecture.md)
- [Database Change Unit and Flyway Promotion](Database-Change-Unit-and-Flyway-Promotion.md)
