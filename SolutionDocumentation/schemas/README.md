# JSON Schemas

This directory contains the versioned JSON Schemas for immutable release
package contracts.

Each schema uses JSON Schema Draft 2020-12 and has a stable `$id` under
`https://atap.example.com/schemas/<name>/v<N>.json`. The schema files are
linked from the documentation sections that define their semantics:

- `manifest.schema.json` validates the Release Bundle `manifest.json`
  described in `../Release-Branch-and-Manifest.md`.
- `db-release-unit.schema.yaml` validates the per-release DB change-unit YAML
  described in `../Database-Change-Unit-and-Flyway-Promotion.md`. It is
  written as JSON-compatible YAML so PowerShell `Test-Json -SchemaFile` can
  consume it without an external YAML module.
- `db-manifest.schema.json` validates the generated `db/db-manifest.json`
  described in `../Database-Change-Unit-and-Flyway-Promotion.md`.

The Pester tests under `../../tests/Schemas/` validate the examples embedded
in those documents against the schemas, including negative coverage for the
top-level Release Bundle manifest.
