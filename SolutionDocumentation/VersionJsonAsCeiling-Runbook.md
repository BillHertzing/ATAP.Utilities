# version.json Ceiling Mechanism — Operational Runbook

**Audience:** Build engineers, senior developers, and on-call engineers who
need to change a promotion ceiling, diagnose a blocked pipeline, or roll back
a bad label change.

**Related docs:**

- [version.json as Promotion Ceiling](VersionJsonAsCeiling.md) — concepts and vocabulary
- [C# Packages — Versioning](CSharp-Packages-Versioning.md) §5.0
- [PowerShell Modules — Versioning](PowerShell-Modules-Versioning.md) §7
- [Immutable Build Strategy](Immutable-Build-Strategy.md)

---

## 1. Rollout Order — Raising a Ceiling

When you want a package to reach a higher tier (e.g. promote from
Development-ceiling to Integration-ceiling), follow this order:

1. **Finish and merge the sprint-worktree branch.** Ensure all work-in-progress
   is committed and all CI checks pass on the current branch.

2. **Edit `version.json` in every affected project / module.**
   Change the prerelease label from the current label to the new one:

   | Current label | New label | Ceiling raised to |
   | ------------- | --------- | ----------------- |
   | `Sprint`      | `Alpha`   | Development       |
   | `Alpha`       | `Beta`    | Integration       |
   | `Beta`        | `QA`      | QA                |
   | `QA`          | _(empty)_ | Production        |

   Bulk-update helper (C#, all `version.json` under a sprint worktree):

   ```powershell
   $root = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-{NNNN}-sprint-{M}-work-items'
   $from = 'Sprint'; $to = 'Alpha'
   Get-ChildItem $root -Filter 'version.json' -Recurse | ForEach-Object {
       $c = Get-Content $_.FullName -Raw
       $n = $c -replace "\"version\"\s*:\s*\"([\d.]+)-$from\.\{height\}\"",
                        "`"version`": `"`$1-$to.{height}`""
       if ($n -ne $c) { Set-Content $_.FullName -Value $n -NoNewline }
   }
   ```

3. **Commit the `version.json` change.**

   ```powershell
   git add '**/version.json'
   git commit -m "chore(version): raise ceiling Sprint → Alpha"
   ```

4. **Trigger the BuildMaster run.**
   The new build produces a fresh artifact with the updated prerelease label
   (e.g. `0.1.0-Alpha.1`). It is **not** the same artifact as before; height
   resets because `version.json` itself matches `pathFilters`.

5. **Verify** using the checks in §3 below.

---

## 2. Rollback Procedure

### 2.1 Rollback a label change (before BuildMaster run)

If you edited `version.json` but have not yet triggered a build:

```powershell
git revert HEAD --no-edit        # reverts the version.json commit
git push origin <your-branch>
```

### 2.2 Rollback a label change (after a broken BuildMaster run)

If the new artifact was published and you need to revert:

1. **Do not delete the published package.** ProGet immutable-feed packages
   cannot be deleted without breaking cached pipeline references. Instead,
   treat the broken artifact as superseded.

2. **Revert the `version.json` change and push.**

   ```powershell
   git revert HEAD --no-edit
   git push origin <your-branch>
   ```

3. **Trigger a new BuildMaster run.** The reverted label produces a new
   artifact with the original ceiling. This new artifact supersedes the
   broken one.

4. **Deprecate the broken artifact in ProGet** (optional but recommended):
   use the ProGet UI → Feed → Package → Deprecate to mark it so it is
   excluded from restore and install operations without deleting it.

### 2.3 Rollback a promotion (Promote-ProGetPackage)

Promotions copy packages between feeds. If you need to undo a promotion:

1. If the feed is not append-only, remove the package from the destination
   feed via the ProGet UI → Feed → Package → Delete from Feed. The source
   feed copy is unaffected.
2. If the feed is append-only (any Production or QA feed), file a change
   request; automated rollback of a production promotion is not supported.

---

## 3. Per-Stage Verification

Run these checks after any label change or after a pipeline run that
produced unexpected skip markers.

### 3.1 Experimental stage

```powershell
# Confirm the resolved version matches the new label
nbgv get-version --project <project-path>
# Expected: 0.1.0-Alpha.1+<hash>  (label = Alpha means Development ceiling)

# Confirm the artifact was published to the correct sprint feed
Get-ProGetPackage -FeedName 'nuget-Sprint{N}-experimental' `
    -PackageName 'ATAP.Utilities.<Module>' `
    -Version     '0.1.0-Alpha.1'
```

### 3.2 Development stage

```powershell
# Confirm the package was promoted
Get-ProGetPackage -FeedName 'nuget-Sprint{N}-development' `
    -PackageName 'ATAP.Utilities.<Module>' `
    -Version     '0.1.0-Alpha.1'
```

### 3.3 Integration stage

```powershell
# A Beta-ceiling artifact should appear here; an Alpha-ceiling should NOT
Get-ProGetPackage -FeedName 'nuget-integration' `
    -PackageName 'ATAP.Utilities.<Module>' `
    -Version     '0.1.0-Beta.1'
```

### 3.4 QA and Production stages

```powershell
# Confirm the QA feed received the QA-ceiling artifact
Get-ProGetPackage -FeedName 'nuget-qa' -PackageName 'ATAP.Utilities.<Module>' `
    -Version '0.1.0-QA.1'

# Confirm the stable feed received the Production-ceiling artifact
Get-ProGetPackage -FeedName 'nuget-stable' -PackageName 'ATAP.Utilities.<Module>' `
    -Version '0.1.0'
```

---

## 4. Where to Inspect BuildMaster Evidence

Each BuildMaster run writes diagnostics under:

```text
_generated/buildmaster/<BuildMasterBuildId>/
```

`<BuildMasterBuildId>` is the value of `$BuildMasterId(build)` at the time
the Experimental preamble ran.

| File                                | Contents                                                                                                                                             |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `build-context.json`                | `CeilingTier`, `CurrentTier`, `IsAtCeiling`, `AllowDevelopment`, …, `PrereleaseLabel`, `ResolvedVersion` — the full context captured in Experimental |
| `_resolved_version.tmp`             | NuGet package version string (e.g. `0.1.0-Alpha.3`)                                                                                                  |
| `ceiling_tier.tmp`                  | Ceiling tier string (e.g. `Development`)                                                                                                             |
| `allow_development.tmp`             | `true` or `false`                                                                                                                                    |
| `ceiling_skip_markers/<Stage>.skip` | One file per skipped stage; contains the reason and the ceiling tier that caused the skip                                                            |

**Reading `build-context.json`:**

```powershell
Get-Content '_generated/buildmaster/<BuildMasterBuildId>/build-context.json' |
    ConvertFrom-Json | Format-List
```

**Listing skip markers:**

```powershell
Get-ChildItem '_generated/buildmaster/<BuildMasterBuildId>/ceiling_skip_markers'
```

In BuildMaster, the `CeilingSkipMarkers` artifact (created at the end of the
run when at least one skip marker exists) is visible in the **Artifacts** tab
of the build page. Download it to inspect the `.skip` files.

---

## 5. How to Interpret Skip Markers

A skip marker file is created in `ceiling_skip_markers/` when an above-ceiling
stage records its skip decision. The file name is `<Stage>.skip` where
`<Stage>` is the BuildMaster stage name (e.g. `Development.skip`, `QA.skip`).

**File contents example (`Integration.skip`):**

```
Stage=Integration
CurrentTier=Integration
CeilingTier=Development
Reason=Stage Integration exceeds ceiling Development; artifact 0.1.0-Alpha.3 will not be promoted beyond Development.
Timestamp=2025-06-10T14:37:22Z
```

**Interpreting the output:**

| Observation                                                | Meaning                                                                                                                                                       |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CeilingTier=Development`, `Stage=Integration.skip` exists | Normal: Alpha-labeled artifact stopped at Development.                                                                                                        |
| `CeilingTier=Production`, `<Stage>.skip` files exist       | Unexpected: a Production-ceiling artifact skipped some stages. Check `$AllowQA`, `$AllowProduction` variables in the BuildMaster plan for explicit overrides. |
| No skip markers at all, all stages ran                     | Normal for a Production-ceiling (`version.json` has no prerelease label).                                                                                     |
| Skip marker exists but feed promotion also occurred        | Configuration error: `Test-PromotionWithinCeiling` was bypassed. Review the OtterScript plan and the `$Allow*` override flags.                                |

**Collecting skip markers for a historical run:**

```powershell
# Replace <id> with the BuildMaster build ID
$markers = Get-ChildItem '_generated/buildmaster/<id>/ceiling_skip_markers' -Filter '*.skip'
$markers | ForEach-Object {
    Write-PSFMessage -Level Important -Message "Skip marker: $($_.Name)"
    Get-Content $_.FullName | Write-PSFMessage -Level Debug -Message { "  $_" }
}
```
