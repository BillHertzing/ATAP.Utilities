# Sync-ProGetPowerShellModules

`Sync-ProGetPowerShellModules` compares the newest module versions on a ProGet PowerShell feed
with the newest versions installed locally. It emits one structured result per discovered module
and installs only missing modules or upgrades.

## Feed selection

Omit `Repository` to resolve the requested `Tier` through `Resolve-ProGetFeedFromSettings`:

```powershell
Sync-ProGetPowerShellModules -Tier Stable -Filter 'ATAP.*' -WhatIf
```

To run from any host against any registered ProGet PowerShell feed, specify the repository name
and optionally its feed URI:

```powershell
Sync-ProGetPowerShellModules `
  -Repository 'customer-powershell' `
  -FeedUrl 'https://proget.example.test/nuget/customer-powershell/' `
  -Scope CurrentUser
```

When `FeedUrl` is omitted, the command uses the registered repository's `SourceLocation`.

## Safety contract

- The selected PSRepository must already be registered. The command never registers a repository
  and never changes its trust policy.
- `SupportsShouldProcess` provides `-WhatIf` and `-Confirm` behavior for every install.
- The default `Install-Module` path supports `AllUsers` and `CurrentUser` scope.
- `UseValidatedInstaller` is restricted to `AllUsers`, requires HTTPS, and requires a
  64-character SHA-256 pin for every changed module.
- The validated path delegates hashing, signature checks, dependency-floor checks, staging,
  fresh import, and rollback to `Install-ATAPModuleAllUsers`.
- A failed install is returned as `ActionTaken = 'Failed'` with `ErrorText`. Feed resolution,
  repository discovery, and feed-query failures terminate the run.

## Hash-pinned AllUsers synchronization

```powershell
$pins = @{
  'ATAP.Utilities.BuildTooling.Common.PowerShell' =
    '6795AD76AC3DD5CC35AAA2CDCEFC734B8043F498A8C9F2103F19EC8169BD9F7F'
}

Sync-ProGetPowerShellModules `
  -Repository 'powershellget-stable' `
  -FeedUrl 'https://proget.example.test/nuget/powershellget-stable/' `
  -UseValidatedInstaller `
  -ExpectedSha256ByModule $pins
```

Obtain each pin from separately verified release evidence. Do not calculate a pin from an
untrusted download and then treat the same value as validation evidence.

## Result properties

| Property | Meaning |
| --- | --- |
| `ModuleName` | ProGet package/module identifier. |
| `InstalledVersion` | Newest locally installed semantic version, or null. |
| `ProGetVersion` | Newest semantic version found on the selected feed. |
| `Status` | `Missing`, `UpgradeAvailable`, or `UpToDate`. |
| `ActionTaken` | `Installed`, `Skipped`, `WhatIf`, or `Failed`. |
| `Repository` | Registered PowerShell repository used for discovery and install. |
| `Tier` | Canonical configured tier, or `Explicit`. |
| `FeedUrl` | Feed URI used by the validated installer. |
| `ErrorText` | Per-module installation failure, otherwise null. |

## Configuration follow-up

SC-0432 tracks the separate cross-repository work to review which parameters should be backed by
`Get-PVal`, add canonical ConfigRootKeys, and add guarded per-host ATAP.IAC HostSettings values.
Explicit parameter values must continue to take precedence. SHA-256 package pins and secrets must
not be placed in HostSettings without a separately approved trust design.

## Verification boundary

Task 15.195 validates parsing, module-loading shape, semantic-version comparison, failure behavior,
`WhatIf`, generic host/feed selection, installer selection, and export behavior without contacting
ProGet or changing installed modules. Package release and deployed-host acceptance remain separate.
