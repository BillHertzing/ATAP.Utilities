# Release notes

## 0.1.1

- Makes the frozen export-contract test robust when the legacy parent module is
  already loaded and owns overlapping compatibility command names.
- Makes the contract fixture honor the promoted-artifact manifest supplied by
  the standard tier verifier.
- Aligns the checked-in source manifest with released version 0.1.1 so
  BuildMaster can resolve the child before AllUsers installation.
- Moves the detailed ceiling-label and feature-slug tests to their owning child
  module.
- Supersedes 0.1.0, which stopped at the Development validation gate.

## 0.1.0

- Extracted 16 build commands from the compatibility parent.
- Added Common 0.1.7 and ProGet 0.1.1 dependency floors.
- Split `Parse-MSBuildFile` from the co-owned rules reader.
- Removed top-level executable export code and the legacy
  `Invoke-Expression` build path.
- Added direct module-contract and safe-invocation coverage.
