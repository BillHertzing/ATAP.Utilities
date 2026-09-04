# ATAP.Utilities.BuildTooling.ContentSummary.PowerShell

This module supplies `Get-ContentSummary`, the narrow compatibility client used by the
`gather-content-summary` agent. It sends only `tags`, `depth`, `width`, and `instance` to
AceOutpost. It uses ambient Windows Integrated Authentication with the current identity;
SQL access and explicit credential or secret resolution are outside this module.

The endpoint is resolved through ATAP configuration keys
`AceOutpost:Ingestion:Scheme`, `AceOutpost:Ingestion:Host`,
`AceOutpost:Ingestion:Port`, and `AceOutpost:Ingestion:Path`. Explicit cmdlet parameters have
highest priority. Scheme defaults to `https`, host to `localhost`, and path to
`/api/v1/gather-content`. No port is embedded as a fallback; use the active deployed binding through ATAP configuration or the explicit parameter (currently `50010` on UTAT022).

Only `https` and the loopback names/addresses `localhost`, `127.0.0.1`, and `::1` are accepted.
Certificate validation is never bypassed. Redirects and proxies are disabled. Connection
timeouts are 30 seconds; PowerShell versions exposing a separate operation timeout also
use 30 seconds for that timeout. Every actual invocation is recorded through
`Write-GatherCallRecord`; the full returned `items` collection is not written to that record.
Each logical invocation sends a fresh UUID in the `Idempotency-Key` HTTP header. The key is
not added to the JSON body, persisted by this module, or reused for a separate invocation.

```powershell
Get-ContentSummary -Tags @('schema', 'migration') -Port 50010
```
