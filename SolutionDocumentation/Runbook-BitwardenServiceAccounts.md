# Runbook: Bitwarden Service Account Secrets

**Status:** Sprint-0007 operational runbook
**Related decision record:** [ServiceAccountsAndBitwarden.md](ServiceAccountsAndBitwarden.md)
**Primary Sprint tasks:** SA-02, SA-03, SA-04

## Scope

This runbook covers non-interactive Bitwarden Secrets Manager access for Windows service accounts, starting with `SvcBuildmaster`. The supported runtime pattern is:

1. Grant a Bitwarden Secrets Manager machine account access to the required projects.
2. Install the `bws` CLI on the BuildMaster host and make it visible in the service account PATH.
3. Store the machine-account access token as a DPAPI-protected CLIXML file by running `Initialize-ServiceAccountBWSAccessToken` as the service account.
4. Read secrets at runtime through `Get-SecretATAP` with the `BitwardenSecretsManager` provider.

Do not persist `BWS_ACCESS_TOKEN` as a long-lived Machine/User environment variable. It may exist only in Process scope while `bws` is being called.

## SA-02 Secret Inventory

Confirm these BWS projects and key names exist before live BuildMaster validation. Record names only; never record values.

| Project | Required keys |
| --- | --- |
| `BuildMaster-Core` | `BuildMaster.Admin.API.Key` |
| `BuildMaster-Core` | ProGet feed read/write/promote keys used by BuildMaster pipeline runners |
| `CI-Shared` | PowerShellGet feed keys for Experimental, Development, Integration, QA, and Production |
| `CI-Shared` | Database rehearsal connection-string secrets used by database package validation |
| `CI-Shared` | Bootstrap credential items required to bring a fresh service account online |

Structured secrets that need field extraction must store a JSON object as the BWS secret value. `Get-SecretATAP -SecretField <field>` expects fields such as `username`, `password`, `token`, or `connectionString`.

Example value shape:

```json
{
  "username": "SvcBuildmaster",
  "password": "<redacted>",
  "token": "<redacted>",
  "connectionString": "<redacted>"
}
```

## SA-03 Provisioning

Run these commands from a shell started as the target service account. For `SvcBuildmaster`, use an elevated local-admin provisioning session that launches PowerShell under that identity.

1. Confirm `bws` is available:

```powershell
Get-Command bws -ErrorAction Stop
bws --version
```

2. Import the BuildTooling module:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
```

3. Store the BWS machine-account token as a DPAPI file:

```powershell
$token = Read-Host 'BWS machine-account access token' -AsSecureString
Initialize-ServiceAccountBWSAccessToken -AccessToken $token
```

Expected file:

```text
C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster\<HOST>_SvcBuildmaster_BWS_AccessToken.xml
```

4. Validate token decryption and project access without leaving plaintext behind:

```powershell
$cred = Get-ServiceAccountBWSAccessToken
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
try {
  bws secret list --output json | ConvertFrom-Json | Select-Object key, projectId
}
finally {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

5. Validate the runtime provider:

```powershell
Get-SecretATAP -SecretName 'BuildMaster.Admin.API.Key' -SecretField 'token'
```

The command should return the secret value and emit no plaintext to logs. Record only the secret key name, project, service-account identity, host name, and timestamp.

## Current Finding

## SA-04 validation attempt

As of the 2026-06-05 SA-04 pass:

- Current automation identity was `UTAT022\whertzing`, not `UTAT022\SvcBuildmaster`.
- `Get-Command bws -ErrorAction SilentlyContinue` returned no command in the current automation shell.
- The expected `SvcBuildmaster` DPAPI token file exists at `C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster\utat022_SvcBuildmaster_BWS_AccessToken.xml`; contents were not read or logged.
- Focused mocked-provider Pester coverage passed: `Get-SecretATAP.Tests.ps1` and `Get-SecretATAPBitwardenSecretsManager.Tests.ps1` passed 8/8 tests.

The repo-side helpers and unit-tested BWS provider exist, and a service-account DPAPI token file is present, but SA-04 live validation remains blocked until the commands above are run from a no-profile shell as `SvcBuildmaster` with `bws` visible on PATH. Record only secret key names, project IDs/names, host, identity, timestamps, and value lengths/presence; do not record secret values.

## Rotation

1. Create or rotate the BWS machine-account access token in Bitwarden Secrets Manager.
2. Run `Initialize-ServiceAccountBWSAccessToken -AccessToken <secure token>` as the service account.
3. Confirm the previous CLIXML file was backed up and the new file decrypts under the same identity.
4. Run the validation commands above.
5. Delete obsolete backup files after the new token is proven and any retention requirement is satisfied.

## Troubleshooting

| Symptom | Likely cause | Check |
| --- | --- | --- |
| `bws` not found | CLI not installed or not visible to service-account PATH | `Get-Command bws` from the service-account shell |
| DPAPI file missing | Token was never provisioned for this identity/host | Confirm the path under `C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>` |
| DPAPI decrypt fails | File was created by a different identity or copied from another host | Re-run `Initialize-ServiceAccountBWSAccessToken` as the target service account |
| Secret key not found | Machine account lacks project access or the key name differs | Compare BWS project assignments and the SA-02 inventory |
| `-SecretField` returns raw JSON | Field name is absent or value is not JSON | Confirm the BWS secret value shape |
