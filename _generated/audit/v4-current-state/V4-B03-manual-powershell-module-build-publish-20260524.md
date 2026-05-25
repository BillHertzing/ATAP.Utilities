# V4-B03 Manual PowerShell Module Build/Publish Evidence

Date: 2026-05-24

Module: `ATAP.Utilities.PowerShell`

Source commit: `b3b43d59`

## Version

`src/ATAP.Utilities.PowerShell/version.json`:

```json
"version": "0.1.1-Beta.{height}"
```

NBGV resolved package version:

```text
0.1.1-Beta.1
```

PowerShell module package version:

```text
ATAP.Utilities.Powershell.0.1.1-Beta001.nupkg
```

The version string differs because NuGet/NBGV allows `Beta.1`, while the PowerShell module manifest `Prerelease` field requires an alphanumeric value. The build tooling converted `Beta.1` to `Beta001`.

## Manual Build/Pack

Command shape:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force

Invoke-ModuleBuildWithRetry `
  -ProjectPath .\src\ATAP.Utilities.PowerShell `
  -Tier Sprint `
  -Task CI `
  -SkipPublish `
  -MaxRetries 1 `
  -OutputRoot .\_generated\audit\v4-current-state\V4-B03-manual-psmodule-20260524-211640
```

Result:

```text
Invoke-Build CI succeeded: ATAP.Utilities.PowerShell [Tier=Sprint]
BuildSummary: Version=0.1.1-Beta.1; Tier=Sprint; Passed=0; Failed=0; Acknowledged=0; CoveragePct=null
Package: _generated/audit/v4-current-state/V4-B03-manual-psmodule-20260524-211640/packages/ATAP.Utilities.Powershell.0.1.1-Beta001.nupkg
Package size: 73355 bytes
```

## Manual Publish

The publish step used `Publish-PSModuleToProGet`, which always targets the Experimental PowerShellGet feed. Because the wrapper resolves feed metadata through `$global:Settings`, the clean `-NoProfile` invocation bootstrapped only the required feed metadata:

```powershell
$global:configRootKeys = @{ ProGetFeedCollectionConfigRootKey = 'ProGetFeedCollection' }
$global:Settings = @{
  ProGetFeedCollection = @{
    PowerShellGetExperimental = @{
      FeedType   = 'powershellget'
      Tier       = 'experimental'
      FeedName   = 'powershellget-experimental'
      Uri        = 'http://localhost:50000/nuget/powershellget-experimental/'
      NuGetV3Uri = ''
      ApiKeyName = 'PROGET_ADMIN_API_KEY'
    }
  }
}
```

Result:

```json
{
  "FeedName": "powershellget-experimental",
  "FeedUri": "http://localhost:50000/nuget/powershellget-experimental/",
  "Published": true,
  "CeilingTier": "Integration",
  "ResponseSummary": "Published '.../ATAP.Utilities.Powershell.0.1.1-Beta001.nupkg' to 'powershellget-experimental'."
}
```

## Discoverability

ProGet package API query:

```text
GET http://localhost:50000/api/packages/powershellget-experimental/versions?name=ATAP.Utilities.Powershell&version=0.1.1-Beta001
```

Result:

```text
name: ATAP.Utilities.Powershell
version: 0.1.1-Beta001
published: 2026-05-25T03:18:23.447Z
size: 73355
sha256: ce9d234c3c763ae2894c9ed612d83d734b40a444aefa5286d62e390d6fda9014
```

## Clean Shell Restore Proof

`Save-PSResource` from a clean `pwsh -NoProfile` shell failed against ProGet's V2 OData query endpoint:

```text
500 Internal Server Error
Request: http://localhost:50000/nuget/powershellget-experimental//FindPackagesById()?...
```

As a direct restore proof, a clean `pwsh -NoProfile` shell downloaded the same package from the ProGet package endpoint and expanded it:

```text
GET http://localhost:50000/nuget/powershellget-experimental/package/ATAP.Utilities.Powershell/0.1.1-Beta001
Status: 200
Content-Type: application/zip
Downloaded SHA256: CE9D234C3C763AE2894C9ED612D83D734B40A444AEFA5286D62E390D6FDA9014
Local SHA256:      CE9D234C3C763AE2894C9ED612D83D734B40A444AEFA5286D62E390D6FDA9014
Expanded manifest: _generated/audit/v4-current-state/V4-B03-manual-psmodule-20260524-211640/restore-proof/expanded/ATAP.Utilities.Powershell.psd1
```

`Test-ModuleManifest` on the expanded package:

```json
{
  "Name": "ATAP.Utilities.Powershell",
  "Version": "0.1.1",
  "Prerelease": "Beta001",
  "RootModule": "ATAP.Utilities.Powershell.psm1",
  "ExportedFunctionCount": 51
}
```

## Issues

- `Publish-PSModuleToProGet` still needs profile-independent feed metadata bootstrap for normal no-profile use. This was worked around manually for V4-B03 and should be folded into the V4-B02 / V4-G05 no-profile settings cleanup.
- `Save-PSResource` hit a ProGet V2 OData `FindPackagesById` 500 for this prerelease package. Direct package download and expansion from ProGet succeeded, with SHA256 equality against the locally built `.nupkg`.
- The package identity uses the existing module/file casing `ATAP.Utilities.Powershell`, while the task text spells the product name `ATAP.Utilities.PowerShell`.
