# Task 13.70.d batch 1 disposition

## Scope

The reviewed batch contains four public Common commands:

- `Assert-GitAvailable`
- `Get-WorkspaceJson`
- `Initialize-ATAPConfigurationGlobals`
- `Resolve-WorkspaceFiles`

## SC-0248 disposition

Each source file contains only its eponymous function declaration; none has top-level executable
code or `Write-Host` usage. Therefore no SC-0248 remediation was necessary in this batch.

The parent copies remain intentionally during this increment. Task 13.70.d authorizes copying
without parent rewiring; removing or forwarding parent implementations is deferred to the later
parent-rewire iteration. The Common copies are public because they are shared family contracts.

`Initialize-ATAPConfigurationGlobals` keeps its existing source-first resolution of the
ConfigRootKeys and ATAP.Utilities.PowerShell commands. Its use of `$global:configRootKeys` and
`$global:settings` is deliberate and covered by its existing suppression attributes.

## Test disposition

Task 13.70.e adds Common-owned functional coverage for every exported helper:

| Command | Common test |
| --- | --- |
| `Assert-GitAvailable` | `tests/Unit/Assert-GitAvailable.Tests.ps1` |
| `Get-WorkspaceJson` | `tests/Unit/Get-WorkspaceJson.Tests.ps1` |
| `Initialize-ATAPConfigurationGlobals` | `tests/Unit/Initialize-ATAPConfigurationGlobals.Tests.ps1` |
| `Resolve-WorkspaceFiles` | `tests/Unit/Resolve-WorkspaceFiles.Tests.ps1` |

The parent copies and their tests remain while the parent is unrewired. The Common test files
import Common's manifest directly, so they validate Common ownership and command scope without
depending on the parent module.

## Task 13.70.f type and assembly disposition

The approved first batch exposes only PowerShell functions. The Common module contains no
shared type definition, `Add-Type` use, DLL, `lib/*.types.ps1` file, or manifest
`RequiredAssemblies` entry. Therefore neither proposed type-loading mechanism applies to this
batch, and no guarded loader is added speculatively.

No duplicate DLL is owned by Common, so there is no Common DLL copy to remove. Any assembly that
remains with the unrewired parent stays parent-owned until a later extraction explicitly moves the
type and names the duplicate-copy disposition. `CommonModule.Contract.Tests.ps1` makes this
absence an intentional contract so a future type introduction must update the manifest/loader,
the test, and this disposition together.
