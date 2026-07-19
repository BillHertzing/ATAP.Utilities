# Package-Pinning Ownership Decision

**Task:** V4-D06 — _Decide package pinning ownership._
**Scope:** Decision note / docs.
**Status:** Decided 2026-06-05. Engine implemented and exported; consumer-wrapper
thinning is a tracked follow-up (see §6).
**Decision record type:** Architecture Decision Record (ADR).

> **Acceptance criterion (from the V4 board):** "Either generic pinning moves
> into BuildTooling _or_ AceCommander-specific ownership is documented with
> rationale." This record selects the first option and documents the rationale.

---

## 1. Context

[CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md) §6.1
establishes the pinning **policy**: floating version ranges (`0.*-*`) are
permitted only at the Experimental and Development tiers; at Integration, QA,
and Stable/Production every internal `ATAP.*` entry in a consumer's
`Directory.Packages.props` must be pinned to a concrete version before
`dotnet restore`/`build` runs. The CI agent rewrites its workspace copy; the
working-copy file in git keeps its floating patterns.

The policy needed an **implementation owner**. Two artifacts existed that both
implemented the pin-the-floating-versions mechanic:

| Artifact | Location | Shape |
| -------- | -------- | ----- |
| `Set-AceCommanderPackagePins.ps1` | `AceCommander/powershell/public/` | Full ~220-line implementation, hard-coded to the `ATAP.` prefix, module name `AceCommander.BuildTooling`, legacy `T1`–`T5` tier vocabulary in its help. Invoked by the AceCommander `CSharpPackage-5Stage.otter` QA stage by script path. |
| `Set-FloatingPackagePins.ps1` | `ATAP.Utilities.BuildTooling.PowerShell/public/` | Generic, repository-agnostic cmdlet with a `-PackageIdPrefix` parameter (default `ATAP.`). Exported from the module manifest; covered by Pester tests. |

Leaving both in place is the problem this decision closes: two engines that can
**diverge** (the AceCommander copy already uses retired `T1`–`T5` tier names and
a subtly different version-comparison code path), with no documented statement
of which one owns the behavior.

---

## 2. Decision

**The generic pinning engine is owned by `ATAP.Utilities.BuildTooling.PowerShell`.**

- `Set-FloatingPackagePins` is the single source of truth for the pin-floating
  -versions mechanic. It is repository-agnostic: callers pass the props path,
  ProGet URL, target feed, and package-id prefix.
- **Consumers keep a thin, repo-specific wrapper that supplies their own
  defaults and delegates to the engine.** A consumer wrapper exists only to (a)
  pin the consumer's package-id prefix and default feed, and (b) give the
  consumer's build plan a stable local call site. It must contain **no**
  version-resolution or XML-rewriting logic of its own.

This is the "generic pinning moves into BuildTooling" option, refined with a
thin-wrapper pattern so each consumer keeps an ergonomic, repo-local entry point
without re-implementing the engine.

---

## 3. The engine contract

`Set-FloatingPackagePins` (in `ATAP.Utilities.BuildTooling.PowerShell`,
`FunctionsToExport`):

| Parameter | Default | Notes |
| --------- | ------- | ----- |
| `-PackagePropsPath` | `Directory.Packages.props` | Path to the central props file to rewrite. |
| `-ProGetUrl` | _(mandatory)_ | ProGet base URL; a trailing slash is normalized. |
| `-FeedName` | `nuget-qa` | Tier feed queried for the highest concrete version. |
| `-PackageIdPrefix` | `ATAP.` | Only `<PackageVersion Include>` entries with this prefix **and** a wildcard `Version` are pinned; everything else (third-party, already-pinned) is left untouched. |
| `-ProGetApiKeySecretName` | `ProGet.BuildMaster.API.Key` | Non-secret SecretName; the authenticated leaf resolves it immediately before the request. |

- Supports `-WhatIf` (no file write under `-WhatIf`).
- Returns `[pscustomobject]` with `PackagePropsPath`, `PackagesPinned`
  (ordered `{ packageId → pinnedVersion }`), and `PackagesSkipped` (ids absent
  from the feed).
- Version ordering: stable outranks any prerelease; prerelease labels compare
  lexicographically (sufficient for the `Sprint`/`Alpha`/`Beta`/`QA` scheme).
- Tests: `src/ATAP.Utilities.BuildTooling.PowerShell/tests/Unit/Set-FloatingPackagePins.Tests.ps1`
  (pins floating `ATAP.*`, leaves pinned entries untouched, ignores non-prefix
  third-party entries, honors a custom `-PackageIdPrefix`, `-WhatIf` is a no-op,
  records feed-missing packages in `PackagesSkipped`, throws on a missing props
  file, tolerates a trailing slash on `-ProGetUrl`).

### Canonical consumer-wrapper pattern

```powershell
# AceCommander/powershell/public/Set-AceCommanderPackagePins.ps1  (target shape)
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$PackagePropsPath = 'Directory.Packages.props',
  [Parameter(Mandatory)][string]$ProGetUrl,
  [string]$FeedName = 'nuget-qa',
  [string]$ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key'
)
Import-Module 'ATAP.Utilities.BuildTooling.PowerShell' -Force
Set-FloatingPackagePins `
  -PackagePropsPath $PackagePropsPath `
  -ProGetUrl        $ProGetUrl `
  -FeedName         $FeedName `
  -PackageIdPrefix  'ATAP.' `
  -ProGetApiKeySecretName $ProGetApiKeySecretName `
  @PSBoundParametersWhatIfPassthrough
```

The wrapper's only repo-specific knowledge is `-PackageIdPrefix 'ATAP.'`. The
AceCommander `CSharpPackage-5Stage.otter` plan already imports
`ATAP.Utilities.BuildTooling.PowerShell` for its Failure-Acknowledged gate, so
the engine is on the agent's module path and **no OtterScript change is
required** — the plan keeps calling the local wrapper by path with the same
arguments.

---

## 4. Rationale

1. **Single source of truth.** Version-resolution and props-rewriting logic
   lives once. A change (e.g. switching the prerelease comparison to true SemVer
   ordering) is made and tested in one place instead of drifting across repos.
2. **Reuse.** Any future consumer (a second app, a database-package consumer)
   pins by calling the engine with its own prefix/feed — no copy-paste.
3. **Testability.** The engine already has unit coverage in BuildTooling; a thin
   wrapper needs only a "delegates with the right defaults" test, not a re-test
   of the mechanic.
4. **Consistency with existing ownership.** BuildTooling already owns the
   adjacent CI mechanics the consumer plans import (`Assert-LockFilesClean`,
   `Invoke-FailureAcknowledgedGate`, `Test-ProGetFeedSet`). Pinning belongs in
   the same toolbox.
5. **Tier-vocabulary hygiene.** The retired `T1`–`T5` naming (swept by V4-G09)
   survives only in the AceCommander duplicate; centralizing the engine removes
   the last functional carrier of the legacy vocabulary.

---

## 5. Alternatives considered

- **AceCommander-specific ownership (status quo, rejected).** Keep the full
  implementation in AceCommander and document it as the owner. Rejected: it
  blocks reuse by any second consumer, doubles the test surface, and is the
  source of the existing `T1`–`T5` drift. The acceptance criterion permits this
  path only "with rationale"; the rationale instead favors centralization.
- **Engine in `ATAP.Utilities.PowerShell` (not BuildTooling).** Rejected:
  pinning is a build/CI concern, and the consumer plans already import
  BuildTooling, not the core utilities module, at the pin step.
- **No wrapper — call `Set-FloatingPackagePins` directly from OtterScript.**
  Viable, but a repo-local wrapper gives each consumer a stable call site and a
  natural home for repo-specific defaults; it also keeps the OtterScript call
  identical to today's, minimizing pipeline churn.

---

## 6. Consequences and follow-ups

**Done (this decision):**

- Engine `Set-FloatingPackagePins` implemented, exported from
  `ATAP.Utilities.BuildTooling.PowerShell.psd1`, and unit-tested.
- This record + [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md)
  §6.1 reconciled to name the engine as the owner.

**Tracked follow-up (AceCommander repo — cross-repo, not done here):**

- Convert `AceCommander/powershell/public/Set-AceCommanderPackagePins.ps1` from a
  full duplicate into the thin wrapper shown in §3 (delegates to
  `Set-FloatingPackagePins -PackageIdPrefix 'ATAP.'`) and update its help to the
  canonical Experimental/Development/Integration/QA/Production vocabulary. The
  AceCommander `CSharpPackage-5Stage.otter` call site is unchanged. This edit is
  in the AceCommander sprint worktree; per the repo boundary-enforcement rule it
  is left as a documented follow-up for explicit action rather than performed as
  part of this ATAP.Utilities decision note.

Until that follow-up lands, the AceCommander wrapper is the **deprecated**
duplicate: the policy and engine of record are defined here and in CPM §6.1, and
the AceCommander copy must not be treated as an independent source of truth.

---

## Related documents

- [CSharp-Central-Package-Management.md](CSharp-Central-Package-Management.md)
  §6.1 — the pinning **policy** (which tiers require pinning).
- [Immutable-Build-Strategy.md](Immutable-Build-Strategy.md) — why
  Integration-and-above must be reproducible.
- `Set-FloatingPackagePins` — the engine
  (`src/ATAP.Utilities.BuildTooling.PowerShell/public/Set-FloatingPackagePins.ps1`).
