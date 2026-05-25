# JSON Schemas

This directory contains the versioned JSON Schemas for immutable release
package contracts.

Each schema uses JSON Schema Draft 2020-12 and has a stable `$id` under
`https://atap.example.com/schemas/<name>/v<N>.json`. The schema files are
linked from the documentation sections that define their semantics:

- `manifest.schema.json` validates the Release Bundle `manifest.json`
  described in `../Release-Branch-and-Manifest.md`.
- `db-release-unit.schema.json` validates the per-release DB change-unit
  manifest described in `../Database-Change-Unit-and-Flyway-Promotion.md`.
- `db-manifest.schema.json` validates the generated `db/db-manifest.json`
  described in `../Database-Change-Unit-and-Flyway-Promotion.md`.
- `database-package-ceiling.schema.json` validates
  `database-package-ceiling.json`, the consumer-side ceiling file described in
  `../Database-Package-Ceiling-File.md`.

The Pester tests under `../../tests/Schemas/` validate the examples embedded
in those documents against the schemas, including negative coverage for the
top-level Release Bundle manifest.
