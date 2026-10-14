# RPRRSBSI-V4 Tags Traversal Contract

Status: normative, database-neutral design contract for Sprint 0015 Task 15.50.b.
This document defines traversal behavior and acceptance inputs only. It creates no SQL,
migration, seed identity, API implementation, package, feed, inventory, or live action.

## Authority and compatibility

This contract is subordinate to the ratified RPRRSBSI-V4/V4-2 Tags model and the
Sprint 0015 Decision Register. In particular:

- C-17: Tags classify and advise but never authorize.
- C-18: Tags have no intrinsic ordering; `Ordinal` is used only for genuinely ordered
  collections.
- C-19: Tag relations are typed, directed, and optionally weighted in authoring terms.
  The stored weight is always present, defaults to `1.0`, and is in `(0, 1]`.
- C-22: relation endpoints are durable Tag roots. A traversal resolves root state at one
  as-of instant and never substitutes a state-row endpoint.
- V4 D10: traversal order comes from stable values, never `Tag.Ordinal`, legacy
  `SortOrder`, insertion order, storage order, locale, or database collation.
- V4 D11: self-relations are prohibited and `(source, target, role)` is unique.

Where this contract and an older Tags document disagree, the ratified V4-2 contract and
this Task 15.50.b contract control traversal. This contract does not alter Tag identity,
temporal state, assignment, stewardship, provenance, or authorization rules.

## Normative vocabulary

- **Stored edge**: one authored `TagRelation` from a durable source root to a durable
  target root with one role and one mandatory normalized weight.
- **Logical edge**: a stored edge as exposed in its authored direction, or its
  query-time symmetric/inverse projection.
- **Path**: an ordered sequence of logical edges beginning at the resolved start Tag.
- **Frontier**: all retained paths of the same depth awaiting expansion.
- **Visible**: effective at the request's as-of instant and admitted by the host's
  consumer-owned authorization predicate.
- **Ordinal comparison**: invariant Unicode scalar-value comparison after the normal form
  required by the canonical-code contract. It is case-sensitive and culture-neutral.
- **GUID comparison**: RFC 4122/network byte order, unsigned byte by unsigned byte.

The key words SHALL, SHALL NOT, SHOULD, and MAY are normative.

## Request contract

One request traverses from exactly one start Tag and has these logical fields:

| Field | Required behavior |
| --- | --- |
| `start` | Exactly one of durable `TagId` or `(TagNamespaceCode, TagCodeOrAlias)`. Code lookup is namespace-local and as-of aware. |
| `asOfUtc` | Optional UTC instant. If omitted, the service captures its UTC clock once before any lookup. The effective value is echoed. A supplied value must be a valid UTC instant no later than that captured request time. |
| `maxDepth` | Optional maximum hop count. Default `3`; inclusive range `1..8`. Depth `0` is invalid, not a root-only query. |
| `maxWidth` | Optional per-path outgoing-neighbour limit. Default `25`; inclusive range `1..100`. It is applied independently to every expanded path. |
| `maxPaths` | Optional global returned-path limit. Default `500`; inclusive range `1..1000`. The start Tag is not a returned path and does not consume this limit. |
| `roleCodes` | Optional set of traversable role codes. Omission means every active traversable role. An explicitly empty set is invalid. Repeated codes are normalized to one set member. Mixing valid role families is allowed. |
| `includeDeprecated` | Optional boolean, default `false`. It affects active deprecated states only. Retracted or otherwise ineffective Tags are never returned. |
| `timeoutMs` | Optional end-to-end traversal budget. Default `2000`; inclusive range `100..10000`. It includes resolution, authorization filtering, traversal, ordering, and serialization. |

Implementations SHALL validate the entire request before reading graph data. They SHALL
not clamp an out-of-range value. A deployment with a lower operational limit SHALL reject
the request explicitly; it SHALL NOT silently substitute its local limit.

### As-of snapshot

All root, state, alias, relation-role, and relation reads SHALL use one logical snapshot
at `effectiveAsOfUtc`. A successful response is invalid if different hops observed
different committed graph states. The implementation may use snapshot isolation, a
version token, or an equivalent mechanism, but the observable contract is database
neutral.

A Tag is eligible only when its Philote validity and sanctioned Tag state are both
effective at `effectiveAsOfUtc`. A code input may resolve through an effective alias;
aliases never become graph vertices and therefore cannot be “encountered” mid-traversal.
An alias resolves to its durable owning root before the first hop.

## Role-direction contract

Inverse and symmetric logical edges are **derived at query time and are not stored as
mirror rows**. Authoring SHALL reject a stored mirror of a symmetric claim and a stored
inverse duplicate. Derived edges retain the stored edge's weight and relation identity;
their `projection` is `symmetric` or `inverse` rather than `stored`.

The initial reviewed role behavior is exact:

| Role code | Direction exposed | Inverse role | Family | Cycle policy |
| --- | --- | --- | --- | --- |
| `REL_RELATED_TO` | symmetric | itself | associative | allowed |
| `REL_SEE_ALSO` | symmetric | itself | associative | allowed |
| `REL_OPPOSITE_OF` | symmetric | itself | semantic-opposition | allowed |
| `REL_BROADER_THAN` | authored plus derived inverse | `REL_NARROWER_THAN` | hierarchy-breadth | prohibited within family |
| `REL_NARROWER_THAN` | authored plus derived inverse | `REL_BROADER_THAN` | hierarchy-breadth | prohibited within family |
| `REL_REPLACES` | authored plus derived inverse | `REL_REPLACED_BY` | replacement | prohibited within family |
| `REL_REPLACED_BY` | authored plus derived inverse | `REL_REPLACES` | replacement | prohibited within family |
| `REL_PART_OF` | authored plus derived inverse | `REL_HAS_PART` | hierarchy-composition | prohibited within family |
| `REL_HAS_PART` | authored plus derived inverse | `REL_PART_OF` | hierarchy-composition | prohibited within family |

`REL_SYNONYM_OF` is not an initial relation role. V4 aliases represent alternate names
without creating a second Tag root. New role codes require a reviewed catalog addition
that declares symmetry/inverse, family, cycle policy, and traversability before use.

For a prohibited-cycle family, authoring SHALL reject an edge when adding its normalized
family direction would make any directed cycle in that family. The paired role names are
two views of the same family graph; changing role spelling does not evade the check.
Cross-family cycles can still arise in mixed traversal and are handled by the path rule
below. Self-reference remains prohibited for every role.

## Weight and path score

Every logical edge has the stored `decimal(5,4)` weight in `(0, 1]`; an author that omits
weight receives `1.0`. “Unweighted” therefore means all applicable edges have `1.0`, not
null or zero.

The path score is the exact decimal product of its edge weights:

```text
pathWeight(path) = product(edge.weight for edge in path)
```

With at most eight scale-four factors, the product has at most 32 fractional digits and
SHALL be computed without intermediate rounding. JSON renders it as a decimal string in
plain notation, removes trailing fractional zeroes, and retains at least one fractional
digit (`1.0`, not `1` or scientific notation). Symmetric and inverse projections do not
change weight. Weight ranks traversal; it never grants authority and is not a probability.

## Deterministic traversal algorithm

The result is path-preserving breadth-first traversal. The start Tag is response context,
not a result item.

1. Resolve and authorize the start root at `effectiveAsOfUtc`.
2. Initialize the frontier with the zero-edge start path and the returned-path set empty.
3. For depths `1` through `maxDepth`, expand each retained path from the preceding
   frontier.
4. Form that path's candidate logical edges by applying, in this order: the role filter;
   as-of effectiveness of the target; `includeDeprecated`; the host authorization
   predicate; and path-local cycle rejection.
5. Sort that path's candidates by the neighbour key below and retain its first
   `maxWidth`. Count the remainder as width-pruned.
6. Extend the path once per retained candidate. Sort the complete new depth frontier by
   the result key below.
7. Append paths from that ordered frontier until `maxPaths` is reached. If the frontier
   exceeds the remaining capacity, retain the prefix, count the discarded suffix as
   max-paths-pruned, and stop without exploring descendants.
8. The retained frontier becomes the next frontier. Stop when it is empty or the maximum
   depth is complete.

### Path-local cycle rule

A candidate is cycle-forming when its target durable `TagId` already occurs anywhere in
the current path, including the start. Such an edge is omitted and increments
`cyclePrunedEdgeCount`. Cycle pruning is defined semantics, not truncation. The visited
set is path-local, not global: reaching the same Tag by two distinct acyclic paths is
allowed and both paths are returned.

### Neighbour key

Candidate logical edges for one path sort by this exact ascending tuple, with the first
element expressed as descending:

1. edge weight descending;
2. exposed role code by ordinal comparison;
3. target canonical Tag code by ordinal comparison;
4. target Tag Philote by GUID comparison;
5. stored relation Philote by GUID comparison;
6. projection rank: `stored`, `symmetric`, `inverse`.

No `Ordinal`, `SortOrder`, label, localized text, insertion sequence, physical key,
database collation, or locale may participate.

### Result key

The returned path array sorts by:

1. depth ascending;
2. path weight descending;
3. terminal canonical Tag code by ordinal comparison;
4. terminal Tag Philote by GUID comparison;
5. exposed role-code sequence lexicographically by ordinal comparison;
6. stored relation-Philote sequence lexicographically by GUID comparison;
7. projection-rank sequence lexicographically.

These final sequence keys make distinct paths total-order comparable even when they end
at the same Tag with the same score. A conforming implementation produces byte-identical
semantic JSON arrays for the same request, snapshot, graph, and authorization predicate.
Transport correlation identifiers and elapsed-time diagnostics are outside that semantic
comparison.

## Duplicate-path behavior

Results are paths, not distinct Tags. A diamond therefore returns the shared terminal
Tag once for each distinct acyclic path. Consumers that want a distinct-Tag view MAY
group after receiving the response, but the query layer SHALL NOT discard provenance.

Two paths are identical only when their ordered triples of `(storedRelationPhilote,
projection, exposedRoleCode)` are identical. For each step, the canonical hash input is
the relation Philote as 32 lowercase RFC 4122/network-order hexadecimal digits, U+001F,
the lowercase projection token, U+001F, the exact role code, and U+001E. Concatenate the
step inputs without a prefix or suffix and hash their UTF-8 bytes. The service SHALL
expose `pathId` as that SHA-256 in 64 lowercase hexadecimal digits. This identifier is
for response correlation and deduplication, not authorization.

## Truncation contract

Every successful response contains:

```json
{
  "isTruncated": false,
  "reasons": [],
  "widthPrunedEdgeCount": 0,
  "depthPrunedPathExtensionCount": 0,
  "maxPathsPrunedPathCount": 0,
  "cyclePrunedEdgeCount": 0
}
```

The rules are exact:

- `WIDTH` appears when `widthPrunedEdgeCount > 0`. This count is the sum of visible,
  role-matching, cycle-free candidate edges discarded by per-path width at depths that
  were actually expanded.
- `DEPTH` appears when traversal completes `maxDepth` without a max-paths cut and at least one returned boundary
  path has a visible, role-matching, cycle-free outgoing logical edge. The count is the
  number of those potential one-hop extensions before applying width. No descendants are
  inspected.
- `MAX_PATHS` appears when an ordered generated frontier exceeds remaining response
  capacity. Its count is the exact number discarded from that frontier. Descendants of
  discarded paths are intentionally neither generated nor counted.
- Reasons sort exactly `WIDTH`, `DEPTH`, `MAX_PATHS`, with absent reasons omitted.
- `isTruncated` is true if and only if at least one of those three counts is nonzero.
- Cycle pruning never sets `isTruncated`; its separate count remains observable.
- Unauthorized or as-of-ineligible nodes/edges are removed before candidate formation.
  They do not affect any count and cannot be inferred from truncation metadata.

If `MAX_PATHS` stops traversal at any depth, including `maxDepth`, `DEPTH` is not
asserted because the full boundary was not evaluated. Width counts accumulated before
the stop remain valid.

## Response contract

A successful response contains the normalized request, `effectiveAsOfUtc`, resolved start
root identity and canonical code, an ordered `paths` array, and truncation metadata. Each
path contains:

- `pathId`, `depth`, and exact string `pathWeight`;
- terminal durable `TagId`, Tag Philote, canonical code, active display state, and
  deprecation state at the common as-of instant;
- ordered steps containing source and target durable identities, exposed role code,
  stored relation Philote, projection, and edge weight.

The response SHALL NOT label a Tag or relation as permitted, denied, trusted, privileged,
approved, or authorized. It SHALL NOT expose hidden-node counts, unauthorized identifiers,
or authorization-rejection reasons.

## Authorization boundary

Traversal is classification and explanation only. The host consumer owns authentication,
authorization, tenant scope, and any subject/content access decision. Its authorization
predicate SHALL be applied to the start before existence is disclosed and to every
candidate before ranking, width, truncation, or output.

An absent, ineffective, and unauthorized start all return the same public `NOT_FOUND`
shape. A hidden neighbour behaves as though it does not exist. A relation role, weight,
path score, reachability, Tag assignment, namespace stewardship row, or returned result
SHALL NOT be treated as authorization evidence. Task 15.50.c shall supply negative
database fixtures and Task 15.50.e shall supply negative API/consumer tests for this
invariant.

## Invalid input and failure contract

Errors contain a stable code, field when applicable, and non-secret message. No failure returns partial paths.

| Code | Public status | Condition |
| --- | --- | --- |
| `TAG_TRAVERSAL_INVALID_START` | 400 | Neither/both start forms supplied, malformed GUID, empty namespace/code, or alias form not normalized. |
| `TAG_TRAVERSAL_INVALID_AS_OF` | 400 | Not UTC, malformed, or later than captured request time. |
| `TAG_TRAVERSAL_INVALID_DEPTH` | 400 | Missing after normalization or outside `1..8`, including zero. |
| `TAG_TRAVERSAL_INVALID_WIDTH` | 400 | Outside `1..100`, including zero. |
| `TAG_TRAVERSAL_INVALID_MAX_PATHS` | 400 | Outside `1..1000`. |
| `TAG_TRAVERSAL_INVALID_TIMEOUT` | 400 | Outside `100..10000` milliseconds. |
| `TAG_TRAVERSAL_INVALID_ROLE_FILTER` | 400 | Explicitly empty, malformed, unknown, inactive, or non-traversable role. Valid mixed families are accepted. |
| `TAG_TRAVERSAL_NOT_FOUND` | 404 | Start is absent, ineffective, deprecated while excluded, or unauthorized. These cases are intentionally indistinguishable. |
| `TAG_TRAVERSAL_TIMEOUT` | 503 | The declared budget expires. Paths and truncation are omitted; retry guidance may be returned. |
| `TAG_TRAVERSAL_INVARIANT_VIOLATION` | 500 | Ambiguous alias, invalid stored weight, forbidden mirror/inverse duplicate, missing inverse metadata, or inconsistent snapshot. Internal identifiers are not disclosed. |

Unknown JSON fields follow the owning API versioning policy; this contract neither
requires permissive nor strict parsing. All defined scalar type mismatches are invalid.

## Timeout and performance assumptions

The semantic work bound is at most `maxPaths` returned paths, at most `maxWidth`
extensions retained per expanded path, depth at most eight, and one bounded candidate
sort per expanded path. Authorization and as-of filtering happen before width. Task
15.50.c SHOULD provide access paths for source endpoint, role, weight, and target; this is
an implementation consequence, not a physical-index mandate here.

The default two-second budget is a service protection default, not an SLA. A timeout is a
deterministic all-or-error boundary: an implementation SHALL cancel database work where
supported, discard accumulated paths, and return `TAG_TRAVERSAL_TIMEOUT`. It SHALL NOT
return a timing-dependent prefix marked truncated. Load tests shall cover hard caps and a
high-degree node, but absolute throughput targets require measured deployment data and
are not invented by this contract.

## Acceptance fixtures for Tasks 15.50.c and 15.50.e

The machine-readable companion is
`_generated/Sprint0015/Task15.50/b/stream-b-traversal-contract/acceptance-fixtures.json`.
Its fixed symbolic identities SHALL be replaced by stable implementation identities only
through a reviewed fixture mapping; expected semantics must not change.

| Fixture | Required assertion |
| --- | --- |
| `T01-width-order` | Three equal/unequal outgoing candidates prove weight-descending, code, Philote, width `2`, and exact `WIDTH` count `1`; insertion order is deliberately reversed. |
| `T02-diamond-duplicates` | Two depth-two paths reach the same Tag; both remain, scores are exact products, and the higher score sorts first. |
| `T03-path-cycle` | A permitted associative cycle is stored, but a path never repeats a root; cycle pruning is counted and is not truncation. |
| `T04-inverse-projection` | One stored broader-than edge exposes a narrower-than reverse edge with the same weight and relation identity; no mirror row exists. |
| `T05-prohibited-family-cycle` | Schema/authoring acceptance rejects a cycle across either spelling of one prohibited inverse family. |
| `T06-as-of-before-width` | A higher-weight ineffective target is removed before width, does not consume width, and does not affect truncation counts. |
| `T07-deprecated` | An active deprecated target is absent by default and present only with `includeDeprecated=true`; a retracted target is always absent. |
| `T08-authorization-before-width` | A hidden higher-weight target neither consumes width nor changes counts; absent and unauthorized starts have identical public responses. |
| `T09-mixed-role-filter` | Valid mixed role families are accepted, only named exposed roles participate, and duplicate filter codes do not duplicate edges. |
| `T10-depth-boundary` | Depth `1` returns only first-hop paths and reports exact eligible next-hop extensions as `DEPTH`. |
| `T11-max-paths` | An ordered frontier overflows `maxPaths`; only its stable prefix returns and the discarded suffix count is exact. |
| `T12-alias-start` | Effective alias and canonical code resolve the same root and semantic path array; aliases never appear as vertices. |
| `T13-invalid-matrix` | Every range, shape, time, and role-filter error maps to its exact stable code; depth/width zero are explicit cases. |
| `T14-timeout-no-partial` | Forced timeout returns the timeout error with no `paths` or truncation object and cancels downstream work. |
| `T15-repeatability` | Repeated execution over the same snapshot and authorization predicate produces byte-identical semantic output despite reversed physical/insertion order. |
| `T16-authorization-negative` | No output field or downstream decision interprets Tags, roles, reachability, or weight as authorization. |

Task 15.50.c owns schema/authoring enforcement fixtures (role metadata, mirror/inverse
duplicates, prohibited cycles, constraints, and query access). Task 15.50.e owns request,
response, authorization, parameterization, timeout/cancellation, and transport fixtures.
Both tasks share traversal-order, as-of, duplicate-path, and truncation expectations.

## Adversarial close variants

The following variants commonly reintroduce nondeterminism or information leakage and
must fail review:

- sorting equal weights by a database-generated integer, label, current collation, or
  physical row order;
- using a global visited set and thereby deleting the second arm of a diamond;
- applying width before authorization/as-of filtering, which leaks hidden candidates and
  starves visible results;
- treating a derived inverse as a second stored claim or multiplying its weight twice;
- returning a timeout-dependent partial prefix;
- reporting depth truncation after an earlier max-path stop when the boundary was never
  inspected;
- folding results to distinct Tags without retaining path provenance;
- permitting `0`, null, or negative weight as “do not traverse”;
- allowing role metadata, reachability, or weight to authorize content;
- evaluating each hop at a new clock instant.

## Close recommendation

Task 15.50.b should close when the contract and fixture manifest pass structural review.
Tasks 15.50.c and 15.50.e may proceed from this behavior contract, but neither is
implemented or authorized by this document. Before any live work, C-25 still requires a
separately authorized and recorded metadata inventory.
