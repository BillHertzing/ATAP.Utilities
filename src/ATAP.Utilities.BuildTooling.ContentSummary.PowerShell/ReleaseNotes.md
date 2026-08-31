# Release notes

## 0.1.1

- Correct the promoted-artifact test loader so it imports exactly the manifest selected by
  `ATAP_PROMOTED_MODULE_MANIFEST` instead of loading a second source module.

## 0.1.0

- Add `Get-ContentSummary`, a fail-closed PowerShell client for the AceOutpost
  `POST /api/v1/gather-content` REST resource.
- Accept only HTTPS loopback endpoints and record every attempted gather operation through
  `Write-GatherCallRecord` without persisting returned item content or secret values.
