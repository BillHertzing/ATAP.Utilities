# V4-D01 Demo / Scaffold Separation Evidence

Date: 2026-05-25
Repository: `ATAP.Utilities-wt-100-Sprint-0007-work-items`
Baseline: `df6ad8eb feat(test): wire UsePackageReferenceForSUT in StronglyTypedIDs.Tests (V4-C05)`

## Result

V4-D01 is accepted with documented exceptions. No source move was required for this pass.

## Checks

- `dotnet sln ATAP.Utilities.sln list` exited 0 and returned valid project paths.
- The sample inventory found 17 `.csproj` files under `samples/`.
- All 17 sample projects define `<IsPackable>false</IsPackable>`.
- All 17 sample projects define `<IsPublishable>false</IsPublishable>`.
- `ATAP.Utilities.Production.slnf` contains 0 `samples/` project references.
- `ATAP.Utilities.Production.slnf` does not include `OpenHardwareMonitorLib/OpenHardwareMonitorLib.csproj`.
- `ATAP.Utilities.Production.slnf` does not include `src/ATAP.Utilities.ZSandbox/ATAP.Utilities.ZSandbox.csproj`.

## Documented Exceptions

- `samples/ATAP.Console.PluginDemo/ATAP.Console.PluginDemo.csproj`, `samples/ATAP.Console.PluginDemo/Model/ATAP.Console.PluginDemo.Model.csproj`, and `samples/ATAP.Console.PluginDemo/StringConstants/ATAP.Console.PluginDemo.StringConstants.csproj` are under `samples/` and are non-packable/non-publishable, but they are not in `ATAP.Utilities.sln`. Their internal sample-to-sample references resolve, but their references back to `src/ATAP.Utilities.*` still resolve as if the demo lived under `src/`; adding them to the solution before fixing those relative references would make the solution list less healthy.
- `OpenHardwareMonitorLib/` remains at the repository root as an embedded third-party hardware sensor library, not a demo/scaffold project. It is already documented in `SolutionDocumentation/architecture-overview.md`.
- `src/ATAP.Utilities.ZSandbox/ATAP.Utilities.ZSandbox.csproj` remains source-scoped and is not currently treated as demo/scaffold for D01. It is present in the full solution but excluded from the production solution filter; moving it under `samples/` should be a separate owner decision if desired.

## Issues

- PluginDemo needs a follow-up reference repair before it can safely be added to `ATAP.Utilities.sln`.
- The repository still contains source-level sandbox naming (`ATAP.Utilities.ZSandbox`), but it is outside the production filter and documented here as a deliberate D01 exception rather than moved during this task.
