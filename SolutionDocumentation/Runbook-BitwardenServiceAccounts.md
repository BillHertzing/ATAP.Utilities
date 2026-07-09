# Runbook: Bitwarden Secrets Manager Access Tokens

**Status:** Sprint-0012 operational runbook
**Related decision record:** [ServiceAccountsAndBitwarden.md](ServiceAccountsAndBitwarden.md)
**Primary Sprint tasks:** SA-02, SA-03, SA-04, 12.53

## Scope

This runbook covers Bitwarden Secrets Manager access for Windows service accounts and
interactive users. The supported runtime pattern is:

1. Grant a Bitwarden Secrets Manager access token to the required projects.
2. Install the `bws` CLI on the host and make it visible in the target account's PATH.
3. Create and ACL `C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>` with `Initialize-BWSCredentialDirectory`.
4. Store the required BWS access token slots as DPAPI-protected CLIXML files by running `Initialize-BWSAccessToken` as the owning Windows account: `ReadOnly` for every account that reads secrets, plus optional `ReadWrite` only for trusted maintainer or provisioning accounts that create, update, delete, or rotate secrets.
5. Read secrets at runtime through `Get-SecretATAP` with the `BitwardenSecretsManager` provider.

Do not persist `BWS_ACCESS_TOKEN` as a long-lived Machine/User environment variable. It may exist only in Process scope while `bws` is being called. DPAPI-protected token files are bound to both the Windows identity and the host, so they cannot be copied to another user profile or another machine and still decrypt.

## Token-purpose baseline

| Token purpose | Token label | Who needs it |
| --- | --- | --- |
| `ReadOnly` | `CommonCIForBitwardenReadOnly` | Every developer or service account that reads BWS secrets |
| `ReadWrite` | `CommonCIForBitwardenReadWrite` | Only explicitly authorized maintainer or provisioning identities that create, update, delete, or rotate BWS secrets |

Provision `ReadOnly` first. Add `ReadWrite` only where the host and identity are trusted for secret-maintenance work.

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

Run the folder-ACL step from an elevated administrative shell, then run the DPAPI write
step from a shell started as the target Windows account. For `SvcBuildmaster`, use an
elevated local-admin provisioning session that launches PowerShell under that identity.
For the current interactive user, the DPAPI write can run in the user's own shell.

1. Confirm `bws` is available:

```powershell
Get-Command bws -ErrorAction Stop
bws --version
```

2. Create and ACL the BWS credential directory.

For the current interactive user:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
Initialize-BWSCredentialDirectory
```

For a service account:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
Initialize-BWSCredentialDirectory -AccountName '.\SvcBuildmaster'
```

3. For a service account, open a PowerShell session as that account with the user profile loaded:

```powershell
$serviceCredential = Get-Credential '.\SvcBuildmaster'
Start-Process pwsh -Credential $serviceCredential -ArgumentList '-NoExit', '-Command', 'Set-Location "C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-120-Sprint-0012-work-items"' -LoadUserProfile
```

4. Store the required BWS access token slot(s) while running as the owning account.

Required `ReadOnly` slot for every reader:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
$token = Read-Host 'BWS access token for CommonCIForBitwardenReadOnly' -AsSecureString
Initialize-BWSAccessToken -TokenPurpose ReadOnly -AccessToken $token
```

Optional `ReadWrite` provisioning for trusted maintainer or provisioning identities only:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
$token = Read-Host 'BWS access token for CommonCIForBitwardenReadWrite' -AsSecureString
Initialize-BWSAccessToken -TokenPurpose ReadWrite -AccessToken $token
```

Expected `ReadOnly` file:

```text
C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster\<HOST>_SvcBuildmaster_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml
```

Optional `ReadWrite` file:

```text
C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster\<HOST>_SvcBuildmaster_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml
```

For the current interactive user, the expected `ReadOnly` file is:

```text
C:\ProgramData\ATAP\BitwardenCredentials\<USERNAME>\<HOST>_<USERNAME>_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml
```

Only trusted maintainer workstations should also carry:

```text
C:\ProgramData\ATAP\BitwardenCredentials\<USERNAME>\<HOST>_<USERNAME>_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml
```

5. Validate `ReadOnly` token decryption and project access without leaving plaintext behind:

```powershell
$cred = Get-BWSAccessToken -TokenPurpose ReadOnly
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
try {
  bws secret list --output json | ConvertFrom-Json | Select-Object key, projectId
}
finally {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

Optional `ReadWrite` validation for identities that are explicitly allowed to maintain secrets:

```powershell
$cred = Get-BWSAccessToken -TokenPurpose ReadWrite
$env:BWS_ACCESS_TOKEN = $cred.GetNetworkCredential().Password
try {
  bws secret list --output json | ConvertFrom-Json | Select-Object key, projectId
}
finally {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

6. Validate the runtime provider:

```powershell
Get-SecretATAP -SecretName 'BuildMaster.Admin.API.Key' -SecretField 'token'
```

The command should return the secret value and emit no plaintext to logs. Record only the
secret key name, project, Windows account identity, host name, timestamp, and any redacted
value-presence/length check that does not reveal the value itself.

The canonical cmdlets are `Initialize-BWSCredentialDirectory`,
`Initialize-BWSAccessToken`, and `Get-BWSAccessToken`. The old
`Initialize-ServiceAccountBWSAccessToken` and `Get-ServiceAccountBWSAccessToken` names
remain exported aliases for existing automation.

## Current Finding

## SA-04 validation attempt

As of the 2026-06-05 SA-04 pass (before the Task 12.50+ two-slot update):

- Current automation identity was `UTAT022\whertzing`, not `UTAT022\SvcBuildmaster`.
- `Get-Command bws -ErrorAction SilentlyContinue` returned no command in the current automation shell.
- The expected `SvcBuildmaster` DPAPI token file existed at `C:\ProgramData\ATAP\BitwardenCredentials\SvcBuildmaster\utat022_SvcBuildmaster_BWS_AccessToken.xml`; contents were not read or logged. Current runs should expect the purpose-specific `CommonCIForBitwardenReadOnly` filename instead, with optional `CommonCIForBitwardenReadWrite` for authorized writers.
- Focused mocked-provider Pester coverage passed: `Get-SecretATAP.Tests.ps1` and `Get-SecretATAPBitwardenSecretsManager.Tests.ps1` passed 8/8 tests.

The repo-side helpers and unit-tested BWS provider exist, and a service-account DPAPI token file is present, but SA-04 live validation remains blocked until the commands above are run from a no-profile shell as `SvcBuildmaster` with `bws` visible on PATH. Record only secret key names, project IDs/names, host, identity, timestamps, and value lengths/presence; do not record secret values.

## Rotation

1. Create or rotate the BWS machine-account access token in Bitwarden Secrets Manager.
2. Run `Initialize-BWSAccessToken -TokenPurpose ReadOnly -AccessToken <secure token>` as the owning Windows account for the baseline read path.
3. If the identity is authorized for secret maintenance, rotate `Initialize-BWSAccessToken -TokenPurpose ReadWrite -AccessToken <secure token>` separately.
4. Confirm only the matching CLIXML file was backed up and the new file decrypts under the same identity on the same host.
5. Run the validation commands above.
6. Delete obsolete backup files after the new token is proven and any retention requirement is satisfied.

## Troubleshooting

| Symptom | Likely cause | Check |
| --- | --- | --- |
| `bws` not found | CLI not installed or not visible to service-account PATH | `Get-Command bws` from the service-account shell |
| ReadOnly DPAPI file missing | The baseline read token was never provisioned for this identity/host | Confirm the `CommonCIForBitwardenReadOnly` path under `C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>` |
| ReadWrite DPAPI file missing | Secret-maintenance work was attempted without the optional writer token | Provision `CommonCIForBitwardenReadWrite` only on an explicitly authorized maintainer/provisioning account |
| DPAPI decrypt fails | File was created by a different identity or copied from another host | Re-run `Initialize-BWSAccessToken` as the target account on the target host |
| Secret key not found | Machine account lacks project access or the key name differs | Compare BWS project assignments and the SA-02 inventory |
| `-SecretField` returns raw JSON | Field name is absent or value is not JSON | Confirm the BWS secret value shape |