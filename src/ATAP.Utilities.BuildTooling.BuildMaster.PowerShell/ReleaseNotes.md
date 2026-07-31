# Release notes

## 0.1.3

- Treat the optional `private/` function directory as empty when it is absent,
  so importing the child module remains valid when a strict caller promotes
  `$ErrorActionPreference` to `Stop`.

## Unreleased

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
