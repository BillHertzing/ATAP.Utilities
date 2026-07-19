# ProGet administration SecretName boundary

The ProGet administration cmdlets accept the name of an API-key secret, never
an API-key value. The canonical parameter and default are:

```powershell
-ProGetApiKeySecretName 'ProGet.Admin.API.Key'
```

This contract applies to:

- `List-ProGetFeeds`
- `List-ProGetConnectors`
- `List-ProGetApiKeys`
- `New-ProGetFeedSet`
- `New-ProGetConnector`
- `New-ProGetApiKey`
- `Remove-ProGetFeeds`
- `Remove-ProGetApiKeys`
- `Rename-ProGetFeed`

When the parameter is omitted, a non-empty value from the canonical
`ProGetAdminApiKeySecretNameConfigRootKey` setting may override the default.
The setting stores only a SecretName. The cmdlet calls `Get-SecretATAP` directly
before an authenticated ProGet request and fails closed if the resolver is
unavailable or returns no value.

Raw `-ApiKey` parameters, API-key environment-variable fallbacks, and
BuildMaster-to-administrator fallback are unsupported. `New-ProGetApiKey`
allows ProGet to generate the new value, but does not return or persist that
value. Provisioning the generated value into the approved secret store is a
separate privileged workflow.

`-WhatIf` operations do not resolve a secret or contact ProGet when the cmdlet
can determine the planned operation without authentication.

## Verification

Run the focused contract tests with PowerShell profiles enabled:

```powershell
Invoke-Pester -Path @(
  'tests/Unit/ProGetAdminSecretNameBoundary.Tests.ps1',
  'tests/Unit/Rename-ProGetFeed.Tests.ps1',
  'tests/Unit/New-ProGetFeedSet.Tests.ps1'
) -Output Minimal
```
