# ATAP.Utilities.BuildTooling.ContentSummary.PowerShell

Version 0.1.7 packages the module as a self-contained flattened `.psm1`. All public and
private function definitions used by inventory validation, capture acknowledgement, SQL
adapters, and deterministic generation are embedded in that file; an installed package
does not dot-source the repository's `public` or `private` directories. Returned SQL adapter closures bind their private module commands before leaving
the module session, so callers can invoke those closures from an installed package.

This module supplies production retrieval and harvesting commands:

- `Get-ContentSummary`, the narrow compatibility client used by the
  `gather-content-summary` agent.
- `Invoke-ContentSummaryHarvest`, the deterministic ingestion boundary that observes,
  normalizes, classifies, redacts, summarizes, and submits one source artifact through
  injected generator and repository operations.
- `New-ContentSummarySqlAdapterSet`, which binds harvesting only to controlled
  V00100/V00120 procedures through an already-open Microsoft.Data.SqlClient connection.
- `Read-ContentSummaryRepositoryInventory` and `Invoke-ContentSummaryRepositoryInventory`,
  which hash-verify caller-authored identities and provision them with `WhatIf` support.
- `New-ContentSummaryDeterministicSafeSummaryGenerator`, which derives a bounded prefix
  only from safe input and never invents identifiers or fallback content.

`Get-ContentSummary` sends only `tags`, `depth`, `width`, and `instance` to AceOutpost.
It uses ambient Windows Integrated Authentication with the current identity. SQL access
and explicit credential or secret resolution are outside the client.

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

The client returns exactly `agent`, `status`, `query`, `items`, `truncated`, and
`error`. AceOutpost `Success` is normalized to `status=ok` only after the echoed query
and every item pass structural and type validation. An authorized empty response remains
`ok` with no items, no truncation, and no error. Malformed, mismatched, or
secret-canary-bearing responses return no items and a stable safe error. Server error
codes, correlation IDs, and observed HTTP status are retained when their envelope is valid.
A legacy `NotImplemented` response remains distinguishable through marker and blocker data
inside `error` and the mandatory gather-call record; no fallback content is fabricated.

`Invoke-ContentSummaryHarvest` performs no source discovery, model invocation, or durable
write implicitly. Callers inject each operation. Source text is classified and redacted
locally before generator egress, and the repository operation receives only the canonical
safe envelope.

Production inventory JSON is byte-bound by a required lowercase SHA-256. It carries
lowercase D-format durable UUIDs, an existing canonical Git worktree root, a
credential-free HTTPS origin URI with matching observation evidence, and any
database-principal authorizations. The module never creates UUIDs, tags, principals, or
repository content. Tags are assigned after capture through
`AssignContentSummaryVersionTag`, using an existing effective `TagId`, caller-supplied
`TagAssignmentId`, and the captured `ContentSummaryVersionId`.

```powershell
Get-ContentSummary -Tags @('schema', 'migration') -Port 50010
```
