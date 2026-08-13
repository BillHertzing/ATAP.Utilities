# RRSBS ADR-147: SourceArtifact and Path Identity

Status: Proposed for Wave 1 review  
Date: 2026-08-02  
Owner: RDB-147 / Task 14.20.b.10

## Decision

A SourceArtifact is a durable identity for a source location within one logical
Repository. A SourceArtifactVersion records the observed or authored bytes and
metadata for that identity. A filesystem worktree is a discovery context, not
part of the identity: the stable and sprint worktrees for one Repository map to
the same Repository identity and SourceArtifact namespace.

The model uses a finite locator-type catalog. Repository-contained artifacts
use `RepositoryPath`; external resources use a controlled `ExternalUri` or
`OpaqueExternalReference` type with source-specific evidence. A locator type is
never inferred from a string and a filesystem path is never silently treated as
an external URI, or conversely.

This ADR reconciles the ContentSummary invariants as follows:

- **PCS INV-08:** `NormalizedContentSha256` is SHA-256 of bytes after CRLF is
  normalized to LF. A UTF-8 BOM is excluded from this normalized hash and its
  presence is recorded as metadata.
- **PCS INV-12:** a `RepositoryPath` is forward-slash, repository-relative,
  unrooted, and contains no backslash. It is the exact logical form emitted by
  `git ls-files`.
- Exact-byte reconstruction uses a separate `ByteSha256`, computed over the
  original bytes without newline or BOM normalization. It therefore preserves
  the CRLF/LF/None terminators, encoding, BOM policy, and final-newline state
  required by an executable or manifestation contract.

All SHA-256 values are stored and compared as 64-character lowercase hexadecimal
values. A hash is evidence of a version's bytes, not an identity, authorization,
or rename decision.

## Locator model and normalization

| Locator type | Canonical form | Identity and validation rule |
| --- | --- | --- |
| `RepositoryPath` | `RepoRelativePath` using forward slashes | Requires one Repository FK; must be the normalized, unrooted tracked-path form. It is not an absolute worktree path. |
| `ExternalUri` | Scheme-specific canonical URI | Requires an allow-listed scheme, normalized authority/path/query policy, and retrieval/version/hash evidence when available. |
| `OpaqueExternalReference` | Controlled opaque identifier plus authority namespace | Used only when no canonical URI exists. It cannot be used to disguise an internal repository path and must carry issuer/observation metadata. |

Repository path identity is binary/ordinal and case-sensitive at the logical
model boundary. The database uses a binary collation or equivalent comparison
for `(RepositoryId, RepoRelativePath)`, and rejects case or Unicode-normalization
collisions even when a Windows worktree would resolve both spellings to one
file. Separators are normalized to `/`; rooted paths, drive-qualified paths,
UNC/device paths, empty segments, `.`/`..`, and NUL/control characters are
rejected rather than repaired.

An external URI has a type-specific normalizer; it does not receive Windows
path normalization. Normalization must preserve security-significant URI
components and reject an unrecognized scheme or ambiguous canonicalization.

## Repository and worktree equivalence

Repository has one stable Philote/RepositoryId and may register multiple root
locations, including a stable worktree and any sprint worktree. Root matching is
case-insensitive and trailing-separator tolerant only for locating the local
repository context. After that match, the artifact key is the RepositoryId plus
the ordinal `RepoRelativePath`; an absolute root must not appear in a
SourceArtifact identity, SourceId, or content hash.

A scanner that cannot map its working directory to exactly one registered
Repository fails closed. It must not create a Repository, guess from a folder
name, or treat the same path under a new sprint worktree as a new artifact.

## Version, rename, and retirement lineage

`SourceArtifactVersion` is append-only and references one SourceArtifact. It
stores `NormalizedContentSha256`, optional `ByteSha256`, byte count, encoding,
BOM presence, line-ending metadata, observation time, and the extractor or
harvester version. Identical hashes do not collapse versions when observation or
provenance differs.

A rename or move creates a new SourceArtifact for the new repository-relative
path and records an immutable `SourceArtifactLineage` edge from predecessor to
successor with a controlled relation such as `RenamedFrom` or `MovedFrom`. The
old artifact is retired by `RetiredAt`; it is never deleted. A content-similarity
heuristic may propose a lineage edge but cannot create it without an explicit,
auditable acceptance rule. Copying a file creates a distinct artifact unless a
separate relationship records derivation.

Retirement means the locator is no longer active for new discovery, while its
identity, versions, lineage, historical ContentSummary links, and provenance
remain queryable. Reusing a retired path for new content requires an explicit
new artifact/lineage decision; it must not silently revive or overwrite the
retired identity.

## Hash and newline policy

The normalized hash supports cross-worktree content drift and ContentSummary:
CRLF and LF equivalents produce the same `NormalizedContentSha256`; a changed
trailing newline remains a content change; lone CR is not silently rewritten;
and BOM presence is recorded independently. Hashing is byte-based, not a text
reader/re-join operation.

The byte hash supports exact reproduction. It is required for a SourceArtifact
Version that feeds an exact-byte RuleInstantiationVersion or ManifestationPlan.
The executor additionally records the selected environment contract under
RDB-140. No consumer may substitute the normalized hash where exact byte
comparison is required, or use a byte hash to suppress the cross-platform
newline drift detection required by PCS.

## Consequences

RDB-260 models Repository root registrations, SourceArtifact,
SourceArtifactVersion, and SourceArtifactLineage. RDB-190 ContentSummary uses
the normalized path and hash contract without changing its `ContentKind`
taxonomy. RDB-630/RDB-140 use `ByteSha256` and exact byte metadata for
manifestation safety. RDB-160 assigns retained, renamed, and retired legacy
source rows a deterministic disposition before the new baseline is seeded.

The current scanner and renderer provide useful evidence for ordinal
case-sensitive comparison, relative paths, and exact-byte output, but they are
not sufficient proof of the new locator, lineage, retirement, or worktree
identity contract. See [Task 13.80 execution evidence](Task-13.80-Instantiation-Execution.md),
[Task 13.79 exact-byte evidence](Task-13.79-Instantiation-V1.md), and
[RRSBS ADR-140 executor safety](RRSBS-ADR-140-Manifestation-Executor-Safety.md).

## Negative controls

The eventual model and tests must reject these scenarios:

1. A rooted, backslash-containing, drive, UNC/device, traversal, empty-segment,
   control-character, or noncanonical `RepositoryPath` is stored.
2. Two paths under one Repository differ only by ordinal case or Unicode
   normalization and are treated as distinct active logical artifacts.
3. A stable and sprint worktree for the same Repository create different
   Repository identities or SourceArtifact namespaces.
4. An unmatched working directory causes an implicit Repository registration or
   a guessed repository identity.
5. A Windows path receives URI normalization, an unknown URI scheme is accepted,
   or an internal repository file is hidden behind `OpaqueExternalReference`.
6. CRLF/LF-equivalent content produces different normalized hashes; a changed
   trailing newline, lone CR, or content byte is silently ignored; or BOM state
   is discarded without metadata.
7. An exact-byte consumer uses `NormalizedContentSha256` instead of ByteSha256,
   or a byte consumer accepts changed encoding/BOM/newline metadata.
8. A hash equality result merges two provenance-distinct versions or decides a
   rename without a lineage record.
9. A rename overwrites/rekeys the old SourceArtifact, a copied file is treated
   as the original, or a retired artifact is deleted/revived implicitly.
10. A source link or ContentSummary reference points to a retired artifact
    without an explicit historical/as-of interpretation.

## Acceptance checks

- RDB-260 defines binary-collated RepositoryPath uniqueness, finite locator
  types, root registrations, version metadata, lineage edges, and retirement.
- RDB-280 includes every negative control above as invalid row or normalization
  scenario.
- RDB-460/RDB-470 fixtures prove CRLF/LF normalized-hash equality, byte-hash
  distinction, worktree equivalence, rename lineage, and no-delete retirement.
- RDB-640/RDB-650 consumers prove ContentSummary and AgentText projections
  retain the required version/hash provenance.

## Related authorities

- [RRSBS ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [RRSBS ADR-140: Manifestation, Executor Safety, and UnRollIt Traversal](RRSBS-ADR-140-Manifestation-Executor-Safety.md)
- [Task 13.79: Instantiation Version 1](Task-13.79-Instantiation-V1.md)
- [Task 13.80: Instantiation Query, Ingestion, and Execution](Task-13.80-Instantiation-Execution.md)
