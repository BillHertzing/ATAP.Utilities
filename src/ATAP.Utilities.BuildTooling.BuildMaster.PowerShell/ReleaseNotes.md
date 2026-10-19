# Release notes

## 0.1.3

- Treat the optional `private/` function directory as empty when it is absent,
  so importing the child module remains valid when a strict caller promotes
  `$ErrorActionPreference` to `Stop`.

## Unreleased

- SC-0360 (Task 16.92.a): `Start-BuildMasterPackagePipeline` and
  `Start-BuildMasterModulePipelineBatch` now also return `ComposedReleaseNumber`
  (the unbounded `<version>-<module>` value) and `ReleaseNumberWasBounded`.
  `ReleaseNumber` is unchanged: it is still the value sent to BuildMaster, at
  most 50 characters, bounded by `ConvertTo-BuildMasterBoundedReleaseNumber`.
- `New-BuildMasterRelease`, `Start-BuildMasterDeployment` and
  `Approve-BuildMasterStage` now add a note to a failure message when the call
  used a release number longer than the 50-character workspace bound. The note
  is context only; it does not assert the cause of the failure. The
  non-exported helper `Get-BuildMasterReleaseNumberLengthHint` builds that text.
- Unit tests for those three commands use `Should -Invoke` in place of the
  `Assert-MockCalled` command that Pester 6 removed.
- Document the BuildMaster child as a member of the BuildTooling family. The
  compatibility parent continues to re-export its legacy commands while installed
  consumers are inventoried for a later parent-mode decision (Task 13.73).

## 0.1.0

- Initial BuildMaster child-module scaffold and extracted command surface.
# 0.1.2

- Omit the local `ArtifactUsage=Default` sentinel from BuildMaster application
  create/update requests.
- Validate AssetDirectory pairing, omit unused optional fields, compare API
  property names case-insensitively for idempotency, and preserve bounded
  validation response details.
