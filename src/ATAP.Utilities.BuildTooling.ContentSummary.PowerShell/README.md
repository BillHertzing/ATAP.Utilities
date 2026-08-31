# ATAP.Utilities.BuildTooling.ContentSummary.PowerShell

This module supplies `Get-ContentSummary`, the narrow compatibility client used by the
`gather-content-summary` agent. It sends only `tags`, `depth`, `width`, and `instance` to
AceOutpost. SQL access, credentials, and secret values are intentionally outside this module.

The endpoint is resolved through ATAP configuration keys
`AceOutpost:Ingestion:Scheme`, `AceOutpost:Ingestion:Host`,
`AceOutpost:Ingestion:Port`, and `AceOutpost:Ingestion:Path`. Explicit cmdlet parameters have
highest priority. Scheme defaults to `https`, host to `localhost`, and path to
`/api/v1/gather-content`; no port default exists because a live port has not been ratified.

Only `https` and the loopback names/addresses `localhost`, `127.0.0.1`, and `::1` are accepted.
Certificate validation is never bypassed. Every actual invocation is recorded through
`Write-GatherCallRecord`; the full returned `items` collection is not written to that record.

```powershell
Get-ContentSummary -Tags @('schema', 'migration') -Port 50041
```
