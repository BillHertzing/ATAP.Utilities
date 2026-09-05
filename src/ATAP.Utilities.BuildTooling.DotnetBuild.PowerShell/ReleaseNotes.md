# Release notes

## 0.1.6

- Adds deterministic, secret-free DAB configuration generation for the
  ContentSummary scalar stored-procedure custom tool.
- Rejects mismatched tier keys, catalog ports, identity metadata, duplicate
  reservations, and pre-existing configurations that would widen access.
- Disables REST, GraphQL, generic MCP DML, raw database entities, and secondary
  MCP tools for the dedicated ContentSummary configuration.

## 0.1.3

- Defers the DAB executable lookup until after `-WhatIf` has returned so dry-run
  configuration planning works on hosts without DAB installed.

## 0.1.2

- Adds secret-free Data API Builder provisioning, configuration validation, and
  read-only entity registration helpers.
- Adds the on-demand DAB MCP stdio launcher, which resolves the selected local
  SQL-tier connection string from Bitwarden Secrets Manager only at startup.
- Adds unit coverage for deterministic BWS SecretName resolution and WhatIf
  behavior.

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
