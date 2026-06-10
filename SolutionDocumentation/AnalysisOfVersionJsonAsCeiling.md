# Critical Analysis — `version.json`-as-Ceiling Implementation

**Created:** 2026-05-17
**Reviewer scope:** Files modified in commit `48d78f2e` ("Implement version.json promotion ceiling")
**Authority sources:**

- `_Planning-wt-14-Sprint-0007-work-items/Plan-VersionJsonAsCeiling.md`
- `SolutionDocumentation/Immutable-Build-Strategy.md`
- `SolutionDocumentation/VersionJsonAsCeiling.md`
- `SolutionDocumentation/BuildMaster-Pipeline-Topology.md`
- 3 OtterScript plans + 9 PowerShell cmdlets + 5 Pester test files

---

## 1. Scope of the Implementation Reviewed

The commit delivers three concept-pair changes:

1. **Tier-concept split.** `Get-BuildContext` now returns both `CurrentTier`
   (from BuildMaster stage context) and `CeilingTier` (from
   `version.json` prerelease label). The legacy `Tier` field is kept as a
   deprecated script-property alias for `CeilingTier`.
2. **Stage-gate guard.** Each `.otter` plan computes the per-stage
   allow/deny matrix once in a preamble (`$AllowExperimental` …
   `$AllowProduction`) by calling `Test-PromotionWithinCeiling -AsBoolean`,
   then guards every stage body with `if $Allow<Stage> == true`.
3. **Promotion-time guard.** `Promote-ProGetPackage` accepts an optional
   `-CeilingTier`; when supplied, it parses the destination tier from the
   `-ToFeed` name and rejects the call before any ProGet API invocation
   when the destination is above the ceiling.

Helpers (`Get-CeilingFromPrereleaseLabel`, `Get-CurrentTierFromStage`,
`Get-TierOrder`) and `Publish-*ToProGet` echo-only ceiling carriage round
out the surface. Pester coverage adds a unit test per pair-table cell
plus an integration test that drives the full stage matrix from each
prerelease label.

The intent and the high-level shape match the plan. The criticism that
follows is **about the gaps and unfinished edges**, not about the core
design — which is sound.

---

## 2. Gaps in the Documentation

### 2.1 Missing semantic edge cases

`VersionJsonAsCeiling.md` is a single-page summary that does not answer:

| Question                                                                                                                            | Doc status |
| ----------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| What happens when `version.json` is **malformed** or unreadable?                                                                    | Unspecified — `Get-BuildContext` throws but the failure mode for stage skipping isn't documented |
| What happens when the project tree contains **multiple** `version.json` files (e.g., monorepo with nested overrides)?              | Unspecified |
| What happens during a **feature branch** — does `<FeatureSlug>.N` always force `Experimental`?                                      | The cmdlet code says yes (`default → Experimental` in `Get-CeilingFromPrereleaseLabel`), but the docs only show `Sprint.N` / `<FeatureSlug>.N` in tables — they never call out that the unmatched-label default is `Experimental` |
| What happens when **prerelease label casing** varies (`alpha`, `ALPHA`, `Alpha`)?                                                   | Code is case-insensitive; doc never says so |
| Can the prerelease label be `Alpha.7.foo`? Does the suffix-after-height pass through?                                               | Pattern strips at first `.` then strips trailing digits — but never documented |
| What is the **observable difference** for a developer between "skipped due to ceiling" vs "genuinely no-op stage"?                  | Unspecified |

### 2.2 No migration guide for `.Tier` callers

- A deprecation warning fires when `.Tier` is accessed.
- The warning is suppressed after the first hit per session (`$script:GetBuildContextTierAliasWarningEmitted`).
- **There is no documented inventory of existing callers** (the plan's P6-T1
  task lists this as a TODO; nothing in the commit shows it was done).
- **There is no documented removal date.** The plan says "next sprint after
  P6-T3 smoke validation passes" but no follow-up issue or scope-creep item
  exists in TASKS.md.
- The deprecation warning text doesn't include a call-site hint. A user
  reading the warning has no idea which file in their codebase reads `.Tier`.

### 2.3 Tier-name aliasing is confusing

The codebase juggles **three vocabularies** for the top tier:

| Surface                          | Top-tier name                |
| -------------------------------- | ---------------------------- |
| BuildMaster stage                | `Production`                 |
| Tier-canonical name (in cmdlets) | `Production` (with `Stable` accepted as alias) |
| ProGet feed                      | `nuget-stable`, `powershellget-stable`, `releasebundle-production` |
| NBGV prerelease label            | (empty) ⇒ ceiling = `Production` |

The aliasing rules are scattered:

- `Get-CurrentTierFromStage` accepts `Stable` → `Production`
- `Test-PromotionWithinCeiling.ConvertTo-BuildPromotionTierName` does the same
- `Resolve-PromotionTierFromFeedName` accepts feed suffix `-stable` or `-production`
- But the C# Application's production feed is `nuget-stable`, and the Release Bundle Application's is `releasebundle-production`

There is **no single explicit mapping table** that says "wherever you see
X, it means Y." A new contributor must read four files to figure this out.

### 2.4 Observability gaps in the docs

`BuildMaster-Pipeline-Topology.md` §4 admits:

> ProGet package metadata is not mutated by this implementation; the
> documented ProGet Packages API ... exposes upload, promote, status, and
> metadata-read surfaces, but no general package-metadata write endpoint.

This means:

- **A user looking at ProGet cannot see CeilingTier.** They see only what
  the feed name implies.
- The doc says "CeilingTier is observable in the BuildMaster artifact
  pane and the Otter preamble evidence files." It does **not** show
  where in the artifact pane, what the file is named, or how a
  release engineer audits ceiling history.

### 2.5 Missing test-matrix documentation

The plan §5 calls for an integration test (P5-T4) producing "a clear
pass/fail matrix per ceiling label." The test file
(`VersionJsonAsCeiling.StageMatrix.Tests.ps1`) exists and is correct,
but **no doc surfaces the matrix as a reference table** for human
readers. A new release engineer must read the test file to learn:

| Ceiling label | Experimental | Development | Integration | QA  | Production |
| ------------- | ------------ | ----------- | ----------- | --- | ---------- |
| `Sprint.N`    | ✓            | ✗           | ✗           | ✗   | ✗          |
| `Alpha.N`     | ✓            | ✓           | ✗           | ✗   | ✗          |
| `Beta.N`      | ✓            | ✓           | ✓           | ✗   | ✗          |
| `QA.N`        | ✓            | ✓           | ✓           | ✓   | ✗          |
| (empty)       | ✓            | ✓           | ✓           | ✓   | ✓          |

This belongs at the top of `VersionJsonAsCeiling.md`, not buried in a
test file.

### 2.6 No upgrade/runbook for existing BuildMaster instances

- New Application Variable `$CeilingTier` is documented in the topology
  doc, but it is **preamble-set**, not config-set. A reader looking for
  "variables I must define in BuildMaster" might assume `$CeilingTier`
  belongs in the Application Variables UI — which would clobber the
  preamble value.
- There is no documented procedure to **roll out** the new `.otter` plan to
  an existing BuildMaster, including:
  - Order of operations (deploy plan → deploy module → re-run smoke)
  - Backup of the previous plan in case rollback is needed
  - Verification that `$ResolvedPackageVersion` evidence file works

### 2.7 Companion-doc inventory not refreshed

- `CSharp-Packages-Versioning.md` and `PowerShell-Modules-Versioning.md`
  were modified in the commit. The plan's P4-T6 task calls for a "Ceiling
  semantics of the prerelease label" subsection in both. Both files do now
  contain references, but they reference `VersionJsonAsCeiling.md` without
  reproducing the ceiling table — a reader cannot understand the new
  versioning rule without opening a second doc.

---

## 3. Gaps in the PowerShell Scripts

### 3.1 `Test-PromotionWithinCeiling` — parameter name overloading

The cmdlet's `-CurrentTier` parameter is used for **two different
concepts**:

1. **Stage gating:** "If the current BuildMaster stage is X, may it run?"
   (otter preamble — `Test-PromotionWithinCeiling -CurrentTier 'Development' -CeilingTier $$context.CeilingTier`)
2. **Destination guarding:** "If we're about to promote to feed Y, may we?"
   (in `Promote-ProGetPackage` — parses destination from `-ToFeed`, then
   passes as `-CurrentTier $destinationTier`)

Both call sites pass the same parameter for genuinely different semantic
roles. This works because the check is the same comparison, but the API
is misleading. A maintainer reading the otter file sees
`-CurrentTier 'Development'` and reasonably wonders "current — what
about the actual current stage?"

**Better:** rename to `-CandidateTier` (or split into two cmdlets:
`Test-StageWithinCeiling` and `Test-PromotionDestinationWithinCeiling`).

### 3.2 Ceiling is **observed-but-not-enforced** by `Publish-*ToProGet`

All three publish cmdlets accept `-CeilingTier` and echo it on the
output, but **none of them call `Test-PromotionWithinCeiling`**:

- `Publish-NuGetPackageToProGet` accepts arbitrary `-Feed` values (default
  `nuget-experimental`). Nothing prevents a caller passing
  `-Feed nuget-qa -CeilingTier Experimental`.
- `Publish-PSModuleToProGet` is hard-coded to the Experimental feed
  (defensible), but still accepts `-CeilingTier` only for output.
- `Publish-UniversalPackageToProGet` accepts arbitrary `-Feed` values
  (default `releasebundle-experimental`).

If a future cmdlet or script bypasses `Promote-ProGetPackage` and goes
directly to a publish cmdlet (e.g., for a hotfix), the ceiling will not
stop them. This is an **enforcement gap masquerading as a parameter**.

### 3.3 `Promote-ProGetPackage` ceiling-guard is opt-in

`-CeilingTier` is optional. If a caller forgets to pass it, the promotion
runs unguarded. Today every otter plan does pass it — but the cmdlet
itself doesn't fail-closed.

**Better:** make `-CeilingTier` mandatory, with an explicit
`-NoCeilingCheck` switch for the rare ad-hoc promotion case. That makes
the safe path the default and the unsafe path explicit.

### 3.4 File-based inter-stage communication has no concurrency story

The otter preamble writes:

```text
_generated\buildmaster\_current_tier.tmp
_generated\buildmaster\_ceiling_tier.tmp
_generated\buildmaster\_resolved_version.tmp
... 5 more _allow_*.tmp files
```

Per-module variant uses `_generated\buildmaster\$ModuleName.*.tmp`.

Problems:

1. **No locking.** If two BuildMaster pipeline runs share a build agent
   worktree (rare but possible during retry storms), the temp files will
   race. Last-writer-wins; the later stage reads whichever value was
   written most recently.
2. **No staleness check.** If the preamble fails part-way (e.g., nbgv
   crashes), some files exist and some don't. The first stage block to
   reference `$AllowDevelopment` (via `$FileContents`) will throw an
   un-prefixed "file not found" error.
3. **No cleanup contract.** The temp files persist across builds.
   `_generated/` is committed to .gitignore but not cleared at the start
   of each run. A failed-then-restarted pipeline could read stale state.

### 3.5 The "skipped due to ceiling" signal is invisible to BuildMaster

When `$AllowDevelopment == false`, the entire `if` body is skipped, but
the **stage itself reports success to BuildMaster**. There is no:

- Log line specifically tagged "ceiling-skip"
- Artifact created documenting the skip
- BuildMaster build variable set to "yes/no this stage ran"

Audit story for "did this pipeline actually try to promote?" requires
correlating the preamble's `Log-Debug` with the absence of subsequent
promote calls in the BuildMaster execution log. That is not a great
audit experience.

### 3.6 `Get-TierFromNBGVLabel` is now legacy but still exported

The new model uses `Get-BuildContext.CeilingTier`. The old cmdlet
`Get-TierFromNBGVLabel` still exists, is still exported, and its
docstring says "This cmdlet is retained for existing callers. New
pipeline code should use Get-BuildContext.CeilingTier." There is:

- No `Obsolete` attribute
- No deprecation warning
- No documented timeline for removal
- No grep-output inventory of remaining callers

This is the same problem as `.Tier` field deprecation, repeated at the
cmdlet level.

### 3.7 `Get-BuildContext` requires `version.json` per project

A reasonable design choice, but the failure mode is brittle:

```powershell
throw "ProjectPath '$resolvedProjectPath' does not contain a project-adjacent 'version.json'..."
```

This means the preamble explodes hard for any consumer that doesn't yet
have a per-project `version.json`. There is no soft-fail or default-to-
solution-root fallback. The plan documents this is intentional (to
prevent nbgv from walking up the tree silently), but there is no
**migration tool** to bulk-add `version.json` to all projects.

### 3.8 The deprecation warning is per-session, not per-call-site

```powershell
if (-not $script:GetBuildContextTierAliasWarningEmitted) {
    $script:GetBuildContextTierAliasWarningEmitted = $true
    Write-PSFMessage -Level Warning -Message "Get-BuildContext.Tier is deprecated..."
}
```

`$script:` scope is module-scope. Once any caller hits `.Tier`, the
warning is suppressed for **every** caller for the rest of the session.
A long-running pipeline that has 10 callers all reading `.Tier` will
get the warning once and miss 9 opportunities to identify the offenders.

### 3.9 `Promote-ProGetPackage`'s `-Reason` is mandatory but every otter call passes a constant template

Every promote call in the three otter plans passes
`-Reason 'XXX-PASS for $ApplicationName $PackageVersion'`. The cmdlet
treats this as mandatory and validates it's non-empty. There's no
contract about format, no validation that the reason mentions tier,
and no enforcement that it includes the build ID.

Audit problem: if a release engineer searches ProGet promotion history
for "ceiling Beta" they will find nothing — the reason field doesn't
mention the ceiling at all.

### 3.10 Verbose pwsh one-liners in otter plans

Lines like:

```text
Arguments: `-NoProfile -Command "$$ErrorActionPreference = 'Stop'; Import-Module '$BuildToolingModulePath' -Force; New-Item -ItemType Directory -Path '$BuildContextDir' -Force | Out-Null; $$context = Get-BuildContext -Application '$ApplicationName' ... [continues 1500 chars]"`,
```

are unmaintainable. They:

- Lose syntax highlighting in any editor
- Are impossible to diff cleanly
- Have hidden quoting bugs (the `$$` escape sequence is BuildMaster
  Otter-specific and trips up reviewers)
- Force a maintainer changing one logical step to re-quote the whole
  call

**Better:** factor each preamble into a single PowerShell **script
file** (e.g., `Invoke-BuildMasterPreamble.ps1`), invoke it as
`pwsh -File`, and pass parameters with `-ArgumentList`.

### 3.11 OtterScript variable-quoting inconsistency

- `CSharpPackage-5Stage.otter` uses backtick-quoted strings:
  `` Arguments: `-NoProfile -Command "..."` ``
- `ReleaseBundle-6Stage.otter` uses `>>...>>` heredoc style:
  `Arguments: >>-NoProfile -Command "...">>`

Both work. Both are legal OtterScript. Mixing them in the same module
makes review harder. **Pick one and apply it consistently.**

### 3.12 Distribution stage half-removed

The bottom of `ReleaseBundle-6Stage.otter` retains a comment

> The Distribution stage block at the bottom of this file is preserved
> for the future sprint that takes Chocolatey/WinGet off hold.

but the block itself is at the very end of the file. A reviewer skimming
the plan can easily think the pipeline includes Distribution and miss
the D-06 hold. **Better:** move the dormant block to a sibling file
(`ReleaseBundle-Distribution-OnHold.otter.txt`) and reference it from a
comment, or wrap in `#region Dormant` with a strong banner.

### 3.13 No structured ceiling-violation logging

When `Test-PromotionWithinCeiling` throws, the error message is:

```text
Promotion ceiling exceeded: current tier 'Development' is above ceiling tier 'Experimental'.
```

The FullyQualifiedErrorId is `PromotionCeilingExceededException`. Good.
But `TargetObject` is a small PSCustomObject with only `CurrentTier` and
`CeilingTier`. A release engineer debugging a real ceiling violation
needs:

- Package name and version
- Source feed and destination feed
- Pipeline run / build ID
- Branch and commit SHA

None of those are attached to the structured error. They live in the
caller's parameter set but are dropped before the throw.

### 3.14 Test coverage of inter-stage state is missing

The Pester suites cover **pure unit logic** (ceiling mapping, tier
ordering, `Test-PromotionWithinCeiling`). The integration test
`VersionJsonAsCeiling.StageMatrix.Tests.ps1` covers the matrix but
**does not exercise the temp-file communication** or the otter preamble
syntax. There is no test that:

- Simulates the preamble writing all 5 `_allow_*.tmp` files and
  verifies the otter `$Trim($FileContents(...))` reads them correctly.
- Verifies behavior when one `_allow_*.tmp` file is missing.
- Verifies stale-file behavior across runs.

### 3.15 Module manifest is not at 0.3.0

Per plan P6-T2 ("minor bump — additive change with deprecated alias"),
the module version should have moved to `0.3.0`. The current `.psd1`
shows `ModuleVersion = '0.2.0'` with `Prerelease = 'Sprint003'`. The
prerelease label tells you a sprint built it but the SemVer didn't tick.
Auto-discovery of "do I have the ceiling cmdlets?" will be wrong for any
consumer doing range-based dependency resolution.

---

## 4. Cross-cutting Concerns

1. **No end-to-end smoke run recorded.** Plan task P6-T3 says: cut a
   smoke pipeline run for one PowerShell module and one C# package at
   ceiling=`Alpha` to confirm pipeline really does build-once + promote-
   once + stop at Development; record digests and assert byte-equality.
   Commit message is `Implement version.json promotion ceiling` — nothing
   says the smoke was actually run, and the plan's Status Tracker has all
   tasks marked `todo`.

2. **`Tier` deprecation removal has no follow-up issue.** Plan P6-T4
   says: open a follow-up ticket / scope-creep item with the removal
   date. Sprint 0007 TASKS.md does not contain such an entry.

3. **Caller-side migration is undone.** Plan P6-T1 says: grep the
   `ATAP.Utilities` and `AceCommander` sprint worktrees for callers of
   `Get-BuildContext` that read `.Tier` directly. Patch each to use
   `.CeilingTier` (the semantic-preserving rename) unless the caller
   actually wants CurrentTier. No commit shows that the grep was run or
   that any caller was migrated.

4. **The plan's Status Tracker is stale.** All 25 tasks in Plan-
   VersionJsonAsCeiling.md §7 are marked `todo`, yet the implementation
   is committed. Someone (human or agent) needs to:
   - Reconcile which tasks were actually done.
   - Reclassify what remains as deferred / in-progress / blocked.

---

## 5. Summary

The implementation captures the intent of BD-13 Choice B. It is correct
in the happy path and well tested for pure functions. The **gaps cluster
around five themes**:

| Theme                              | Severity | Primary fix surface         |
| ---------------------------------- | -------- | --------------------------- |
| Caller migration off `.Tier`       | High     | Grep + patch + remove alias |
| Enforcement of ceiling at publish  | High     | Add guard to publish cmdlets, or document `-CeilingTier` as advisory-only |
| OtterScript readability            | Medium   | Factor preambles into `.ps1` |
| Observability of ceiling-skips     | Medium   | Add structured log + artifact |
| Documentation depth                | Medium   | Add edge-cases, matrix table, runbook |

A V2 plan with junior-dev-sized tasks follows in
[`_Planning-wt-14-Sprint-0007-work-items/Plan-VersionJsonAsCeiling_V2.md`](../../_Planning-wt-14-Sprint-0007-work-items/Plan-VersionJsonAsCeiling_V2.md).
