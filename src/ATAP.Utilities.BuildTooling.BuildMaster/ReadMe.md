# ReadMe for ATAP.Utilities.BuildTooling.BuildMaster

## ProGet authentication

Active plans pass `ProGet.BuildMaster.API.Key` only as a SecretName to their
PowerShell runners. Publishing and promotion leaves resolve that name with
`Get-SecretATAP` immediately before authentication. Raw API-key parameters and
ProGet API-key environment-variable fallbacks are rejected; there is no fallback
from the BuildMaster key to the administrator key.

## Deterministic C# pack prerequisite

The Experimental C# stage builds with `dotnet build` and packs with stable
Visual Studio Build Tools 2026 MSBuild. Production agents require:

- Visual Studio Build Tools 2026 and MSBuild 18.8 or later;
- `Microsoft.VisualStudio.Workload.MSBuildTools`;
- `Microsoft.VisualStudio.Component.NuGet.BuildTools` with NuGet 7.8+;
- `Microsoft.NetCore.Component.SDK`, the SDK resolver used by full MSBuild; and
- the stable SDK pinned by `global.json` (currently 10.0.400, selecting NuGet
  Pack 7.9).

`Invoke-CSharpPackageBuildMasterStage.ps1` discovers the stable installation
with `vswhere`, rejects absent or old components, validates the SDK-selected
`NuGet.Build.Tasks.Pack.dll`, and invokes `/t:Pack` with deterministic build
properties. `DeterministicTimestamp` is the Git `HEAD` commit epoch. The release
gate packs twice into isolated roots and compares complete `.nupkg` SHA-256
hashes before Experimental publication; later tiers promote those same bytes.

Provisioning, verification, and parity-journal instructions are in
[NewComputerSetup.md](../../SolutionDocumentation/NewComputerSetup.md#232-install-the-deterministic-c-package-build-toolchain).
