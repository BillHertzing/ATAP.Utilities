# Get-CoordResult

`Get-CoordResult` is a local, read-only projection of one retained request in an established coordination state file. The source manifest and loader declare this command as a public export. Packaging and installed-consumer verification of this source remain pending; this note describes the selected contract, not a deployed capability.

## Inputs

All three inputs are mandatory, nonempty strings:

- `StatePath`: an absolute path to an existing protected state file.
- `ResourceId`: the exact resource identity expected in that state.
- `RequestId`: the exact retained request identity. Identity comparisons are ordinal and case-sensitive.

For example, after loading the reviewed source in an appropriate development context, a caller can supply its own authorized path and identities:

```powershell
Get-CoordResult -StatePath $authorizedStatePath -ResourceId $resourceId -RequestId $requestId
```

This is a source-invocation example; it does not select or authorize a real state file.

## Returned projection

The local object has nine fields:

| Field | Meaning |
| --- | --- |
| `Outcome` | `Found` for an exact retained request, or `NotFound` for no exact request in a valid matching snapshot. |
| `ResourceId` | The requested resource identity. |
| `RequestId` | The requested request identity. |
| `RetainedStatus` | The stored status: `Pending`, `Prepared`, `Applied`, `Rejected`, or `NeedsRecovery`; null for `NotFound`. |
| `StateSha256` | SHA-256 of the exact state bytes read; it is not a receipt. |
| `RecordedHead` | The stored current generation, committed revision, and output manifest. |
| `Record` | An independent JSON element clone of the retained request record, or null. |
| `Operation` | An independent clone of the linked operation when present, or null. |
| `CommitReceipt` | An independent clone of the linked historical commit receipt when present, or null. |

`Applied` and `Rejected` describe retained historical outcomes. A later recorded head or admission hold does not turn that historical result into a new result. The recorded head is separate context, not proof that current publication outputs are healthy. Missing, unreadable, malformed, mismatched, or internally inconsistent state fails rather than becoming a fabricated result. `NotFound` does not authorize reuse of a request ID.

## Caller boundary

Before reading, the caller must establish current permission for the protected resource and all referenced data, trusted state lineage and custody, and physical containment. This function does not authenticate the caller, grant access, resolve external evidence, or validate current publication health. Treat returned records as protected data.

The projection is not a `result-v1` wire response and does not mint receipt references. Wire adaptation, packaging, and installed-consumer verification are separate work.
