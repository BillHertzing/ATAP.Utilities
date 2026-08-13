# ADR: ZSandbox Ownership and Disposition

## Status

Accepted for current retention. Review is required when the exit criteria below are met.

## Context

`ATAP.Utilities.ZSandbox` contains experimental code that is useful for exploration but is not a production library. It was retained under `src/` and in `ATAP.Utilities.sln` without an explicit owner or complete package and publish boundaries. Its test project also lacked a valid active reference to the sandbox project.

The recovered V4-D01 work requires an explicit, non-destructive disposition. Moving or deleting the experimental source is outside Task 14.90, and the current evidence does not justify either action.

## Decision

The responsible owner is the **ATAP.Utilities repository maintainer responsible for experimental and sandbox code**. This is a role, not a named person.

`ATAP.Utilities.ZSandbox` is classified as retained experimental, non-production code:

- Preserve `src/ATAP.Utilities.ZSandbox` and `tests/ATAP.Utilities.ZSandbox.Tests` in their current locations.
- Preserve both projects in `ATAP.Utilities.sln` so reference drift and compile regressions remain visible.
- Exclude both projects from `ATAP.Utilities.Production.slnf`.
- Set `GeneratePackageOnBuild=false`, `IsPackable=false`, and `IsPublishable=false` on the sandbox project.
- Do not publish, promote, deploy, or consume the sandbox as a package.
- Permit sandbox and sandbox-test dependencies to point toward production libraries.
- Prohibit production-filter projects from depending on the sandbox, its tests, or projects under `samples/`.
- Keep PluginDemo projects under `samples/`, in the main solution for validation, and out of the production filter.

The solution is an engineering validation surface. Solution membership does not grant production status; the production filter and dependency direction provide that boundary.

## Retention rationale

The experimental C# source and tests retain exploratory value, and main-solution membership makes stale project paths detectable. Deletion or relocation would discard context without an approved replacement and would broaden this task beyond the recovered demo/scaffold-separation defect.

## Consequences

The repository maintainer must treat ZSandbox failures separately from production-filter failures. A focused ZSandbox build can expose existing experimental-code debt without changing production acceptance. Production code cannot gain a dependency on ZSandbox merely to make a broad build green.

## Exit and review criteria

Review this decision when any of the following occurs:

1. Experimental behavior is promoted into a supported production component with an explicit API owner, tests, and migration plan.
2. The sandbox has no remaining unique experiments and deletion is separately approved after repository-history review.
3. The sandbox cannot remain buildable without obsolete or vulnerable dependencies; the repository maintainer must then choose migration, archival relocation, or deletion in a separately scoped task.
4. Production-filter dependency analysis finds an edge to ZSandbox, its tests, or PluginDemo; block that change and review the boundary before merge.
5. A future repository layout standard requires experimental projects outside `src/`; perform any move only in a separately approved task that repairs references atomically.

## Verification contract

Task 14.90 verifies this decision with these exact checks:

1. Parse every project entry in `ATAP.Utilities.sln` and confirm its path exists.
2. Parse every non-variable `ProjectReference` in repository project files and confirm its resolved path exists.
3. Run `dotnet sln .\ATAP.Utilities.sln list` and confirm each of the three PluginDemo projects and both ZSandbox projects appears exactly once.
4. Restore and build `samples/ATAP.Console.PluginDemo/ATAP.Console.PluginDemo.csproj` with `RestorePackagesWithLockFile=false` and outputs redirected under `_generated/Sprint0014/StreamJ/Task-14.90/artifacts/`.
5. Restore and build ZSandbox and its test project with the same redirected-artifact and lock-file protections when safe; classify experimental compile failures rather than changing excluded C# source.
6. Parse `ATAP.Utilities.Production.slnf` and confirm it contains no sample or ZSandbox projects.
7. Evaluate the production-filter project graph and confirm it has no dependency edge to PluginDemo or ZSandbox.
8. Evaluate project metadata and confirm `GeneratePackageOnBuild=false`, `IsPackable=false`, and `IsPublishable=false` for PluginDemo and ZSandbox projects.
9. Confirm no source-adjacent lock, `bin`, or `obj` artifact was created by the focused builds.
10. Run `git diff --check` and an owned-scope status audit.

## Task 14.90 implementation record

The first focused PluginDemo build that reached Fody generated untracked `FodyWeavers.xml` and `FodyWeavers.xsd` files under the PluginDemo StringConstants directory. That directory was outside the worker's exact file-level write scope, so the worker stopped immediately without deleting the files. The user subsequently authorized cleanup, and the coordinator deleted only those two task-created files after revalidation. No tracked, project, or source file was removed.

The resumed build added direct PluginDemo Model references to FileIO, Loader Interfaces, and Loader Model. Subsequent builds set `DisableFody=true` and `FodyGenerateXsd=false`; the installed Fody targets confirm that `DisableFody=true` prevents the weaving target from running. The PluginDemo facade then restored and built successfully for `net8.0`, `net9.0`, and `net10.0` with redirected outputs, no warnings or errors, and neither Fody file recreated.

Current boundary evidence records:

- 200 main-solution project paths with zero missing.
- Each of the three PluginDemo projects and both ZSandbox projects exactly once in the main solution.
- 18 non-variable project references across the five task-owned projects with zero missing.
- 177 production-filter projects with zero sample or ZSandbox membership, zero dependency edges into PluginDemo or ZSandbox, and zero missing production-filter project references.
- `IsPackable=false`, `IsPublishable=false`, and `GeneratePackageOnBuild=false` after MSBuild evaluation for all three PluginDemo projects and the ZSandbox source project.
- No change from the pre-build source-adjacent artifact inventory and neither task-created Fody path present.

The broad repository-wide project-reference scan found 112 pre-existing missing references outside the task-owned projects. This residual is not hidden by the focused green result and was not repaired because Task 14.90 did not own those project files. The focused ZSandbox source build also remains non-green in a transitive production dependency: `ATAP.Utilities.ConcurrentObservableCollections` reports six `SYSLIB0011` BinaryFormatter errors across `net8.0`, `net9.0`, and `net10.0`. That residual does not originate in ZSandbox metadata or its repaired test reference and requires a separately owned production-library task.

## Content coverage finding

The mandatory content-summary request returned `NotImplemented` with marker `CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED`; it was blocked by RDB-190, RDB-260, Stream D, and Task 14.113. Task 14.90 therefore used the approved direct-source fallback: the recovered V4-D01 record, current project files, solution membership, and production filter were inspected directly.
