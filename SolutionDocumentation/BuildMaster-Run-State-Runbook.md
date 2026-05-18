# BuildMaster Run-State Runbook

**Scope:** Operational notes for the Sprint 0007 Option A inter-stage state
channel used by the BuildMaster Otter plans.

## State location

Each BuildMaster build writes generated state under:

```text
_generated/buildmaster/<BuildMasterBuildId>/
```

`<BuildMasterBuildId>` is the value returned in OtterScript by
`$BuildMasterId(build)`. The plans also log `$BuildNumber`, `$ExecutionId`, and
the resolved context directory for correlation with BuildMaster UI records.

## Files to inspect

- `build-context.json` — build id, build number, execution id, application,
  branch, source path, current tier, ceiling tier, resolved version,
  prerelease label, allow/skip decisions, and relevant state-file paths.
- C# package state — `_current_tier.tmp`, `_ceiling_tier.tmp`,
  `_resolved_version.tmp`, `_prerelease_label.tmp`, `_allow_*.tmp`.
- PowerShell module state — `<ModuleName>.current-tier.tmp`,
  `<ModuleName>.ceiling-tier.tmp`, `<ModuleName>.resolved-version.tmp`,
  `<ModuleName>.nupkg-path.tmp`, `<ModuleName>.allow-*.tmp`.
- ReleaseBundle state — `releasebundle_context.json`,
  `releasebundle_name.tmp`, `releasebundle_bundle_version.tmp`,
  `releasebundle_path.tmp`, `releasebundle_manifest_path.tmp`, and
  `releasebundle_allow_*.tmp`.

## Diagnosing skipped stages

1. Open `build-context.json` for the BuildMaster build id.
2. Check `CeilingTier` and `AllowDecisions`.
3. Confirm the skipped stage is above the ceiling. For example, a `Beta` label
   maps to `Integration`; QA and Production should be false.
4. Compare the BuildMaster log entry with the same build id and context path.

## Stale or cross-run state

Two concurrent builds must have different `<BuildMasterBuildId>` folders. If a
later stage reads the wrong folder, check the plan log for `$BuildMasterId(build)`
and verify `$BuildContextDir` includes that id. No plan should read flat
`_generated/buildmaster/*.tmp` files.

Retries of the same BuildMaster build id may refresh recomputable state. The
helper fails if an existing `build-context.json` captured a different resolved
version, because that means the workspace no longer matches the artifact that
started the run.

## Cleanup

The helper scripts remove old build-id folders after 14 days. The active
BuildMaster build id folder is never deleted by cleanup. The folder is generated
diagnostic state and is not source-controlled.

## Shared workspace requirement

Option A assumes every stage in the same BuildMaster run can see the same
`_generated/buildmaster/<BuildMasterBuildId>/` folder. If stages run on different
agents or clean workspaces, configure artifact transfer or shared storage for
that folder before enabling multi-agent execution.
