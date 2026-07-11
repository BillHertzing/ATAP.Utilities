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

| Token purpose | Token label                     | Who needs it                                                                                                        |
| ------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `ReadOnly`    | `CommonCIForBitwardenReadOnly`  | Every developer or service account that reads BWS secrets                                                           |
| `ReadWrite`   | `CommonCIForBitwardenReadWrite` | Only explicitly authorized maintainer or provisioning identities that create, update, delete, or rotate BWS secrets |

Provision `ReadOnly` first. Add `ReadWrite` only where the host and identity are trusted for secret-maintenance work.

## SA-02 Secret Inventory

Confirm these BWS projects and key names exist before live BuildMaster validation. Record names only; never record values.

| Project            | Required keys                                                                          |
| ------------------ | -------------------------------------------------------------------------------------- |
| `BuildMaster-Core` | `BuildMaster.Admin.API.Key`                                                            |
| `BuildMaster-Core` | ProGet feed read/write/promote keys used by BuildMaster pipeline runners               |
| `CI-Shared`        | PowerShellGet feed keys for Experimental, Development, Integration, QA, and Production |
| `CI-Shared`        | Database rehearsal connection-string secrets used by database package validation       |
| `CI-Shared`        | Bootstrap credential items required to bring a fresh service account online            |

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

Run the folder-ACL step from an elevated administrative shell. Run the DPAPI token
write as the owning Windows account: DPAPI protection binds the file to both that
identity and the host. Do not copy the file between accounts or hosts.

1. Confirm `bws` is available to the target identity:

```powershell
Get-Command bws -ErrorAction Stop
bws --version
```

2. Create the protected directory for the interactive user and each already-created
   local service account. This step is idempotent.

```powershell
$serviceAccountNames = @(
  'SvcBuildMaster',
  'SvcProGet',
  'SvcSeq',
  'SvcSQLServer',
  'SvcParityAudit'
)

Initialize-BWSCredentialDirectory
foreach ($serviceAccountName in $serviceAccountNames) {
  Initialize-BWSCredentialDirectory -AccountName $serviceAccountName
}
```

3. In a PowerShell session running as each owning identity, write the `ReadOnly`
   access token. Supply the token only through a `SecureString`; never put it in a
   source file, a persistent environment variable, transcript, or log.

```powershell
$accessToken = Read-Host 'BWS ReadOnly access token' -AsSecureString
Initialize-BWSAccessToken -TokenPurpose ReadOnly -AccessToken $accessToken
```

4. Validate decryption and project access without printing the token:

```powershell
$credential = Get-BWSAccessToken -TokenPurpose ReadOnly
$env:BWS_ACCESS_TOKEN = $credential.GetNetworkCredential().Password
try {
  bws secret list --output json | ConvertFrom-Json | Select-Object key, projectId
}
finally {
  Remove-Item Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
```

The expected `ReadOnly` DPAPI file is:

```text
C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>\<HOST>_<SamAccountName>_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml
```

`ReadWrite` remains optional and is limited to explicitly authorized maintainer or
provisioning identities. Use a separate `Initialize-BWSAccessToken -TokenPurpose
ReadWrite` operation only when such authority is required.
## Current Finding

### Completed ReadOnly DPAPI baseline — 2026-07-10

The operator completed the folder-ACL and `CommonCIForBitwardenReadOnly` DPAPI token
file provisioning on both hosts for every identity below. This records file presence
and ACL provisioning only; it records no token value, no password, and no secret
content.

| Host | Interactive user | Service accounts with protected folder and ReadOnly DPAPI file |
| --- | --- | --- |
| `utat01` | `whertzing` | `SvcBuildMaster`, `SvcProGet`, `SvcSeq`, `SvcSQLServer`, `SvcParityAudit` |
| `utat022` | `whertzing` | `SvcBuildMaster`, `SvcProGet`, `SvcSeq`, `SvcSQLServer`, `SvcParityAudit` |

This removes the DPAPI-file prerequisite for the Sprint 0012 BWS read-path tasks on
both hosts. It does not by itself prove that each identity can invoke `bws`, decrypt
the token, or access every required project; perform the no-secret validation in
SA-04 before declaring live access healthy.

## SA-04 validation

For each identity that consumes BWS secrets, run the SA-03 validation commands in a
session owned by that identity. Record only host, identity, timestamp, project/key
names, and redacted presence or length checks. Do not record token values or secret
values.
## Rotation

1. Create or rotate the BWS machine-account access token in Bitwarden Secrets Manager.
2. Run `Initialize-BWSAccessToken -TokenPurpose ReadOnly -AccessToken <secure token>` as the owning Windows account for the baseline read path.
3. If the identity is authorized for secret maintenance, rotate `Initialize-BWSAccessToken -TokenPurpose ReadWrite -AccessToken <secure token>` separately.
4. Confirm only the matching CLIXML file was backed up and the new file decrypts under the same identity on the same host.
5. Run the validation commands above.
6. Delete obsolete backup files after the new token is proven and any retention requirement is satisfied.

## Troubleshooting

| Symptom                         | Likely cause                                                            | Check                                                                                                             |
| ------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `bws` not found                 | CLI not installed or not visible to service-account PATH                | `Get-Command bws` from the service-account shell                                                                  |
| ReadOnly DPAPI file missing     | The baseline read token was never provisioned for this identity/host    | Confirm the `CommonCIForBitwardenReadOnly` path under `C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>` |
| ReadWrite DPAPI file missing    | Secret-maintenance work was attempted without the optional writer token | Provision `CommonCIForBitwardenReadWrite` only on an explicitly authorized maintainer/provisioning account        |
| DPAPI decrypt fails             | File was created by a different identity or copied from another host    | Re-run `Initialize-BWSAccessToken` as the target account on the target host                                       |
| Secret key not found            | Machine account lacks project access or the key name differs            | Compare BWS project assignments and the SA-02 inventory                                                           |
| `-SecretField` returns raw JSON | Field name is absent or value is not JSON                               | Confirm the BWS secret value shape                                                                                |
