# Get-CoordClaims

`Get-CoordClaims` is a local, read-only projection of recorded claims and reservations in an established coordination state file. The source manifest and loader declare this command as a public export. Packaging and installed-consumer verification of this source remain pending.

## Inputs

Both inputs are mandatory, nonempty strings:

- `StatePath`: an absolute path to an existing protected state file.
- `ResourceId`: the exact resource identity expected in that state.

Resource, claim, and reservation IDs are compared ordinally and case-sensitively. For example, after loading reviewed source in an appropriate development context:

```powershell
Get-CoordClaims -StatePath $authorizedStatePath -ResourceId $resourceId
```

The example does not select or authorize a real state file.

## Returned snapshot

The local object has seven fields:

| Field | Meaning |
| --- | --- |
| `ResourceId` | The requested resource identity. |
| `StateSha256` | SHA-256 of the exact state bytes read. |
| `RecordedHead` | Stored generation, committed revision, and output manifest. |
| `ClaimCount` | Number of recorded claims. |
| `ReservationCount` | Number of recorded reservations. |
| `Claims` | An independent JSON array element clone, preserving recorded order and raw values. |
| `Reservations` | An independent JSON array element clone, preserving recorded order and raw values. |

Empty arrays are valid and have zero counts. Missing, unreadable, malformed, mismatched, or inconsistent state fails rather than producing an initialized empty snapshot.

## Caller boundary

The caller must establish current permission for the protected resource and returned data, trusted state lineage and custody, physical containment, and an appropriate input-size bound before calling. The function does not establish those prerequisites.

A recorded claim or reservation is not proof of current authority, expiry, takeover eligibility, or publication health. The function does not filter by time or generation and does not grant access. This local object is not a wire response; packaging and installed-consumer verification are separate work.
