# Release notes

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
