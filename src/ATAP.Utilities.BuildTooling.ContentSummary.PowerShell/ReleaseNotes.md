# Release notes

## 0.1.0

- Add `Get-ContentSummary`, a fail-closed PowerShell client for the AceOutpost
  `POST /api/v1/gather-content` REST resource.
- Accept only HTTPS loopback endpoints and record every attempted gather operation through
  `Write-GatherCallRecord` without persisting returned item content or secret values.
