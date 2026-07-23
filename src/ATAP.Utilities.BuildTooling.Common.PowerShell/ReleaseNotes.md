# Release notes — ATAP.Utilities.BuildTooling.Common.PowerShell

## 0.1.6

- Moves `Resolve-BuildToolingSettingValue` from the parent module's ProGet settings source into
  an eponymous Common public file and exports it for all BuildTooling child consumers.
- Adds focused direct-key, mapped-key, value-type, uninitialized-state, and missing-value tests.
- Replaces immutable 0.1.5 so the extracted shared setting resolver can be promoted independently.

## 0.1.5

- Binds the promoted-module export contract to the `ModuleInfo` returned by the explicit manifest
  import, rather than the ambiguous process-wide `Get-Command -Module <name>` lookup.
- Replaces immutable 0.1.4 after the BuildMaster service account selected a stale same-name module
  during that process-wide lookup despite the restored package containing all five commands.

## 0.1.4

- Adds the explicit promoted-manifest test-process contract so all selected Common fixtures
  re-import the immutable promoted package instead of source code during a tier gate.
- Replaces immutable 0.1.3 after its Development gate exposed remaining source-fixture imports.

## 0.1.3

- Corrects the Common contract and `Get-RepositoryRoot` test fixtures so a promotion gate keeps
  the restored immutable package as the system under test. Standalone source test runs still
  import the source manifest.
- Replaces immutable 0.1.2 after its Development gate failed solely because the test fixtures
  re-imported source code and therefore invalidated the promoted-package contract.

## 0.1.2

- Adds `Get-RepositoryRoot` as a Common public command for the approved PesterScaffolding
  pilot prerequisite. The parent copy remains until the serialized parent rewire.

## 0.1.1

- Promoted through UTAT01 Experimental, Development, Integration, QA, and Stable. BuildMaster
  release 11/build 11 passed the Development, Integration, QA, and Production gates (12/12 each).
- Installed the immutable Stable package AllUsers at
  `C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.Common.PowerShell\0.1.1`.
  The package SHA-256 is `C902582372279E483696CEBF5131788277A231E6909E4BABA49A574FC6BED573`;
  a fresh profile-loaded import exposes all four module commands.
- Classifies the two mock-only `Assert-GitAvailable` Unit tests as
  `PromotedModuleHostSensitive`. They remain in the normal Unit suite but are excluded from the
  BuildMaster service-account promoted-module gate, where they re-import source code and fail
  without diagnostic detail rather than validating the restored package.
- Bumps the immutable package version after the failed 0.1.0 Development gate.

## 0.1.0

- Created the empty, PowerShell 7/Core-only Common module scaffold for Sprint 0013 Task 13.70.c.
- Copied the first approved public helper batch under Task 13.70.d: `Assert-GitAvailable`,
  `Get-WorkspaceJson`, `Initialize-ATAPConfigurationGlobals`, and `Resolve-WorkspaceFiles`.
- Parent implementations remain temporarily to preserve the unrewired parent contract.
- Added the Common-owned Pester slice for each exported helper under Task 13.70.e.
- Recorded the Task 13.70.f no-type/no-assembly disposition: this function-only batch has no
  Common-owned duplicate DLL and no applicable type-loading mechanism.
