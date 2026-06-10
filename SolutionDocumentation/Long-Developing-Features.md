# Long-Developing Features

**Scope:** Policy and mechanics for feature branches that span more than
one sprint, carry their own DB-change cadence, and must eventually merge
to stable/trunk.
**Audience:** Feature owners, release engineers, junior devs working on
a feature team.
**Status:** Authoritative for sprint-0007. Design decisions recorded
2026-05-08.
**See also:** `Immutable-Build-Strategy.md`, `Database-Change-Unit-and-Flyway-Promotion.md`.

---

## 1. What makes a feature "long-developing"?

A feature branch becomes "long-developing" when it cannot be merged within
the sprint it was created in — typically because it touches DB schema,
requires multi-sprint architectural change, or has more than one
contributor. This document applies to any such branch. If a feature can
be completed and merged inside a single sprint, the ordinary trunk-only
sprint flow applies and this document is not needed.

---

## 2. Version shape on the feature branch

The prerelease suffix on a feature-branch artifact is **derived from the
branch name as a short slug**, injected by BuildMaster (not set manually
in `version.json`).

Rules:

- The full version string (SemVer core + prerelease label) must not exceed
  **64 characters**.
- Any single component of the prerelease label must not exceed **16
  characters**.
- The slug is derived by taking the feature branch name after the
  `feature/` prefix, converting to PascalCase, and truncating to 16
  characters.
- `NNN` (the integer that follows the slug) is the feature branch's own
  NBGV height, independent of trunk height.
- BuildMaster reads the branch name from the pipeline trigger context and
  computes the slug at pipeline start. It is stored as the BuildMaster
  build variable **`$FeatureSlug`** for use throughout the pipeline.

### 2.1 Examples

| Branch name                             | Slug (≤16 chars)  | Example version string         |
| --------------------------------------- | ----------------- | ------------------------------ |
| `feature/payment-refactor`              | `PaymentRefactor` | `0.1.0-PaymentRefactor.42`     |
| `feature/long-running-auth-overhaul`    | `LongRunningAuth` | `0.1.0-LongRunningAuth.7`      |
| `feature/db-schema-v2`                  | `DbSchemaV2`      | `0.1.0-DbSchemaV2.13`          |

> ⚠ **Collision note (record for future action):** Once the project workforce
> grows to the point where multiple developers are working simultaneously on
> sprint slices of the same feature, their local builds will share the same
> `NNN` height space. At that point, this policy must be revisited. Candidate
> solutions include: (a) a per-developer height offset encoded in a local
> `version.json` override, or (b) a `-Dev<initials>` sub-suffix injected by
> BuildMaster for local-trigger builds only. A follow-up design task should
> be created when the team reaches 3+ developers on a single feature.

---

## 3. Sprint slices off the feature branch

A sprint slice is a sprint-length unit of work cut from a feature branch.
Sprint slices **inherit the feature suffix** — they do **not** receive an
additional `-S07` (or any other sprint-numbered) component. A sprint
slice that is built from `feature/payment-refactor` during sprint-0007
still produces artifacts versioned `0.1.0-PaymentRefactor.NNN`.

The rationale: the prerelease suffix identifies the *artifact's lineage*
(which feature branch it came from), not the calendar sprint in which it
was produced. Sprint identity is a project-management concern; artifact
identity is determined by branch lineage and NBGV height.

> ⚠ **Collision note (record for future action):** Once the project workforce
> grows to the point where multiple developers are working simultaneously on
> sprint slices of the same feature, their local builds will share the same
> `NNN` height space. At that point, this policy must be revisited. Candidate
> solutions include: (a) a per-developer height offset encoded in a local
> `version.json` override, or (b) a `-Dev<initials>` sub-suffix injected by
> BuildMaster for local-trigger builds only. A follow-up design task should
> be created when the team reaches 3+ developers on a single feature.

---

## 4. Feed targets and promotion

Feature builds are promoted through **all five tiers** (Experimental →
Development → Integration → QA → Production-equivalent), with one
exception: **feature builds are never merged to stable/trunk until they
have passed the QA gate.** The five-tier promotion ladder applies in full
to feature-branch artifacts; only the merge-to-stable step is gated.

The ProGet feeds used are the **same feeds as trunk** — the prerelease
suffix (e.g., `-PaymentRefactor.NNN`) keeps feature artifacts isolated
from trunk artifacts within the same feed. **No separate per-feature feed
is created.** This avoids feed sprawl and keeps tooling, retention
policy, and feed permissions uniform across trunk and feature builds.

The sequence:

1. The feature pipeline produces a `<FeatureSlug>.NNN` artifact at
   Experimental and pushes it to the same Experimental feed used by
   trunk builds.
2. `Promote-ProGetPackage` advances the artifact through Development,
   Integration, and QA tiers using the same feed names as trunk
   promotion.
3. Promotion to QA exercises the QA gate — the artifact must pass the
   QA test suite before promotion succeeds.
4. The merge of the feature branch to stable is a separate step from
   tier promotion. The PR merge gate enforces that the artifact at
   `0.1.0-<FeatureSlug>.NNN` has a passing QA promotion record before
   the merge is permitted.

Artifacts are not promoted to Production under their feature suffix.
Production-tier artifacts are produced after merge from the trunk
pipeline under the `Sprint.NNN` suffix.

---

## 5. DB-change compatibility rule

Feature branches with DB changes must follow an **additive-only rule**
until merge:

- No `ALTER COLUMN`.
- No `DROP COLUMN`.
- No `DROP TABLE` against existing trunk-schema objects.

The rationale: feature branches share the Production DB shape with
trunk. Additive migrations (new tables, new columns, new indexes) are
safe to apply independently because they do not break trunk's current
production schema. Destructive migrations are unsafe to apply out of
order and are deferred until the feature is merged and the trunk
release process can sequence them appropriately.

**This rule is policy, not yet enforced by tooling.** It is documented
here and in `Database-Change-Unit-and-Flyway-Promotion.md` and is the
responsibility of feature owners and PR reviewers to uphold.

A future IMPL ticket should add a Flyway dry-run check to the feature
branch Experimental stage that validates each candidate migration
against the trunk Integration DB snapshot. The check would detect
attempted `ALTER`/`DROP` operations and fail the Experimental build
before the artifact reaches the Development tier.

---

## 6. Merge mechanics

When a feature branch is ready to merge to stable/trunk, the feature
owner (with release engineer support as needed) follows this sequence:

1. **Confirm QA gate passed** for the feature's latest artifact at
   version `0.1.0-<FeatureSlug>.NNN`. The PR merge gate enforces this:
   the merge will be blocked unless a passing QA promotion record
   exists for the artifact.
2. **Squash the feature branch's DB migrations** into a single ordered
   set. The squash is performed by the feature owner manually — there
   is no automated tooling for this in sprint-0007.
3. **Re-sequence migration version numbers** to follow trunk's highest
   existing migration number. The result must have no gaps and no
   collisions with existing trunk migrations.
4. **Update `version.json` on trunk:** set the prerelease label to
   `Sprint` (if it is not already). This is a manual step owned by the
   release engineer or the feature owner, and it must happen *before*
   the next trunk pipeline run — not after.
5. **Merge the feature branch to trunk** via the normal PR review
   process.
6. **Trigger (or wait for) the first trunk Experimental pipeline run.**
   The resulting trunk artifact will be `Sprint.NNN`, where `NNN`
   resets and is the NBGV height from trunk's HEAD.
7. **Feature artifacts remain in feeds under their suffix.** The
   `<FeatureSlug>.NNN` artifacts are not deleted, but they receive no
   further promotion. Retention policy on the feeds will eventually
   age them out under normal feed cleanup rules.

---

## 7. BuildMaster Release scoping for feature branches

Each feature branch gets its **own BuildMaster Release**, scoped to the
feature slug (`Release.<FeatureSlug>`), distinct from the trunk Release.
This keeps the promotion history of feature artifacts separate from
trunk promotion history and prevents feature-tier transitions from
appearing in the trunk Release timeline.

After the feature is merged to trunk, the feature BuildMaster Release
is **closed/archived**. The feature artifacts remain accessible through
the feeds under their suffix, but the Release record itself is no
longer active and accepts no further promotion actions.

> **Note:** This is a policy decision recorded 2026-05-08. If the team
> discovers that separate Releases cause operational friction (e.g.,
> duplicate approval workflows, redundant pipeline configuration, or
> excessive Release-record proliferation when many short-lived features
> are in flight), revisit and update this section.

---

_This doc is linked from `Immutable-Build-Strategy.md §8` and
`BuildMaster-Pipeline-Topology.md §8`. The DB-instance implications of
long-developing features are in
`Database-Change-Unit-and-Flyway-Promotion.md §5`._
