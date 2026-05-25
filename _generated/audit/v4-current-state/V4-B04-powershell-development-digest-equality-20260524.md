# V4-B04 PowerShell Development Digest Equality

Date: 2026-05-24

Package: `ATAP.Utilities.BuildTooling.PowerShell`

Version: `0.1.0-Alpha025`

Feeds compared:

- `powershellget-experimental`
- `powershellget-development`

## Result

The package bytes are identical in Experimental and Development.

| Feed | Published | Size | API SHA256 | Download SHA256 |
| --- | --- | ---: | --- | --- |
| `powershellget-experimental` | `2026-05-21T13:18:59.433Z` | `295067` | `ada9c327297514d6eb16545a5f5859d05a4db2a0e28ed090b5b5bd82a2bdcc05` | `ada9c327297514d6eb16545a5f5859d05a4db2a0e28ed090b5b5bd82a2bdcc05` |
| `powershellget-development` | `2026-05-21T13:19:34.717Z` | `295067` | `ada9c327297514d6eb16545a5f5859d05a4db2a0e28ed090b5b5bd82a2bdcc05` | `ada9c327297514d6eb16545a5f5859d05a4db2a0e28ed090b5b5bd82a2bdcc05` |

Equality flags from the captured JSON proof:

```json
{
  "Sha256Equal": true,
  "SizeEqual": true
}
```

Raw proof JSON:

```text
_generated/audit/v4-current-state/V4-B04-powershell-digest-equality-20260524/digest-proof.json
```

## Commands

The proof queried the ProGet package API for both feeds:

```text
http://localhost:50000/api/packages/powershellget-experimental/versions?name=ATAP.Utilities.BuildTooling.PowerShell&version=0.1.0-Alpha025
http://localhost:50000/api/packages/powershellget-development/versions?name=ATAP.Utilities.BuildTooling.PowerShell&version=0.1.0-Alpha025
```

Then it directly downloaded both packages and hashed the downloaded `.nupkg` files:

```text
http://localhost:50000/nuget/powershellget-experimental/package/ATAP.Utilities.BuildTooling.PowerShell/0.1.0-Alpha025
http://localhost:50000/nuget/powershellget-development/package/ATAP.Utilities.BuildTooling.PowerShell/0.1.0-Alpha025
```

## Issues

None for digest equality. The direct package hashes and ProGet API hashes match across both feeds.
