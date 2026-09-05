# Release notes

## 0.1.7

- Rebuild the immutable package from the complete production-adapter source set so the
  flattened module contains every public and private function used at runtime.
- Bind the module-private conversion, procedure invocation, dependency, and acknowledgement
  commands into returned SQL adapter closures so they remain callable outside module scope.
- Add an isolated package-only regression that imports the expanded package and exercises
  repository inventory validation and its `WhatIf` path without source-tree dot-sourcing.

## 0.1.6

- Validate caller-authored repository inventories against an approved SHA-256, durable
  UUIDs, real canonical Git roots, and credential-free origin evidence.
- Add fail-closed Microsoft.Data.SqlClient adapters for V00120 repository provisioning,
  version-tag assignment, principal authorization, and the unchanged V00100 capture loader.
- Add a deterministic safe summary generator that derives a bounded Unicode-safe prefix
  only from locally classified and redacted input.
- Apply inventory provisioning with `WhatIf` support and secret-safe diagnostics.

## 0.1.5

- Validate the full AceOutpost response before exposing any ContentSummary item.
- Normalize real and authorized-empty success to the stable six-field public envelope.
- Preserve safe server error codes, correlation IDs, HTTP distinctions, and legacy
  NotImplemented blocker evidence without fabricating fallback content.
- Map cancellation and transport failures to stable safe errors and record true
  no-response attempts distinctly.
- Export `Invoke-ContentSummaryHarvest` with its deterministic hashing, normalization,
  redaction, provenance, and repository-envelope boundary.

## 0.1.4

- Use the current Windows identity for the ratified Negotiate authentication contract.
- Disable redirects and proxy detours; retain certificate validation and bounded timeouts.
- Preserve the request envelope, idempotency header, and mandatory gather-call recorder.

## 0.1.3

- Ship the REST02-compatible UUID `Idempotency-Key` client as the immutable stable
  replacement. Version 0.1.2 was the verified source candidate and was not published.

## 0.1.2

- Send a distinct UUID `Idempotency-Key` header for each logical `Get-ContentSummary`
  invocation while preserving the four-field JSON body and SQL-free PowerShell boundary.

## 0.1.1

- Correct the promoted-artifact test loader so it imports exactly the manifest selected by
  `ATAP_PROMOTED_MODULE_MANIFEST` instead of loading a second source module.

## 0.1.0

- Add `Get-ContentSummary`, a fail-closed PowerShell client for the AceOutpost
  `POST /api/v1/gather-content` REST resource.
- Accept only HTTPS loopback endpoints and record every attempted gather operation through
  `Write-GatherCallRecord` without persisting returned item content or secret values.
