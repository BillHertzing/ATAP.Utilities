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

## Parity journal requirement

Before a step in this runbook changes machine-local service-account, token-file,
ACL, or `bws` installation state on `utat022` or `utat01`, append a secret-safe
declaration with `Add-ParityChangeEntry` on the host being changed. Record
SecretNames and token purposes only—never token values or credentials. After the
peer applies its corresponding action, acknowledge it from that peer with
`Confirm-ParityChangeApplied`.

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
  "username": "SvcBuildMaster",
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

3. Start a profile-loaded PowerShell session as each owning local identity. Run this
   from an interactive administrator session, substitute the account name, and enter
   that account's Windows password only at the credential prompt:

```powershell
$serviceAccountName = 'SvcBuildMaster'
$credential = Get-Credential -UserName "$env:COMPUTERNAME\$serviceAccountName"
Start-Process -FilePath (Get-Command pwsh).Source -Credential $credential -LoadUserProfile -UseNewEnvironment -ArgumentList '-NoExit'
```

In the new session, confirm the identity with `whoami`, then write the `ReadOnly`
access token. Supply the token only through a `SecureString`; never put it in a
source file, a persistent environment variable, transcript, or log.

```powershell
$accessToken = (Get-Clipboard -Raw).Trim()| ConvertTo-SecureString -AsPlainText -Force
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

| Host      | Interactive user | Service accounts with protected folder and ReadOnly DPAPI file            |
| --------- | ---------------- | ------------------------------------------------------------------------- |
| `utat01`  | `whertzing`      | `SvcBuildMaster`, `SvcProGet`, `SvcSeq`, `SvcSQLServer`, `SvcParityAudit` |
| `utat022` | `whertzing`      | `SvcBuildMaster`, `SvcProGet`, `SvcSeq`, `SvcSQLServer`, `SvcParityAudit` |

This removes the DPAPI-file prerequisite for the Sprint 0012 BWS read-path tasks on
both hosts. It does not by itself prove that each identity can invoke `bws`, decrypt
the token, or access every required project; perform the no-secret validation in
SA-04 before declaring live access healthy.

### Rotation implementation deferred

The provisioning baseline above is complete and validated. Sprint 0012 does not authorize a
live rotation of either BWS access token, any service password, or any other secret. The
remaining idempotent bootstrap automation, release work, human-only live rotation, and stream
exit review are deferred to the next sprint. Start from the durable carry-forward entry in
`_Planning\InformationForTheFuture\PlanPasswordRotationSystemCritique.md` before scheduling
that work.

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

## Appendix A — Changing a local service-account password

This procedure rotates the password of a local Windows service account. It is a
human-authorized production change: complete the impact inventory first and do not
place a password in source, a command line, a transcript, an environment variable, or
this runbook.

1. Identify every consumer of the account on the target host: Windows services,
   scheduled tasks, saved credentials, SMB shares, and interactive/provisioning
   sessions. Record the planned change through the applicable parity-change journal
   before changing either host.

2. Generate the replacement password once in Bitwarden Password Manager and update the
   account's host-specific item. For the parity monitor, the items are
   `SvcParityAudit.utat01` and `SvcParityAudit.utat022`. Do not create two different
   passwords when the account must authenticate across the two hosts.

3. On each affected host, open an elevated PowerShell session and set the local-account
   password. Enter or paste it only into the secure prompt:

   ```powershell
   $accountName = 'SvcParityAudit'
   $newPassword = Read-Host -Prompt "New password for $accountName" -AsSecureString
   Set-LocalUser -Name $accountName -Password $newPassword
   ```

   Repeat for every host that uses the account. For the `SvcParityAudit` parity
   monitor, `utat01` and `utat022` must use the same password while the primary task
   on `utat022` reads `\\utat01\ParityState`; otherwise Windows cannot authenticate the
   identically named local account over SMB.

4. Reapply every password-backed consumer with the updated credential. For a scheduled
   task, re-register it using the account's new `PSCredential`; for a Windows service,
   update its logon credential through its approved configuration procedure and restart
   it. A task configured for S4U does not retain a password, but it also cannot reliably
   unlock per-user DPAPI material after a cold start. Re-provision a stale token as the
   owning identity; never copy a DPAPI file between identities or hosts.

### `SvcParityAudit` scheduled-task procedure

The parity monitor uses Password logon on both hosts because every wrapper decrypts the
owning account's per-user DPAPI token. The primary `utat022` tasks run Highest because
the compare task reads `\\utat01\ParityState` over SMB; the peer `utat01` audit remains
Limited and non-administrative. Consult the SystemParityMonitor
`InstallationAndTroubleshooting.md` runbook before changing the task definitions.

#### Primary host — `utat022`

Run the following from an elevated PowerShell session on `utat022` after changing the
local account password. The credential prompt is the only place the new password is
entered. It is retained only in the process memory needed for task registration.

```powershell
$moduleRoot = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell\0.1.2'
$registrationScript = Join-Path $moduleRoot 'scripts\Register-ParityScheduledTasks.ps1'

if (-not (Test-Path -LiteralPath $registrationScript -PathType Leaf)) {
  throw "Registration script was not found at '$registrationScript'."
}

. $registrationScript
$svcCredential = Get-Credential -UserName 'UTAT022\SvcParityAudit'

$parameters = @{
  TaskSet             = 'AuditAndCompare'
  HostName            = 'utat022'
  RightHostName       = 'utat01'
  RightStatePath      = '\\utat01\ParityState'
  Cadence             = 'Daily'
  AuditTime           = '03:00'
  CompareTime         = '03:30'
  ExpectedCadenceDays = 1
  StaleMultiplier     = 1.5
  RunAsAccountName    = 'SvcParityAudit'
  LogonType           = 'Password'
  Credential          = $svcCredential
}

Register-ParityScheduledTasks @parameters -WhatIf
Register-ParityScheduledTasks @parameters
```

`-WhatIf` must complete without an error before the second command is allowed to
replace the task definitions. The resulting `ATAP-ParityAudit` and
`ATAP-ParityCompare` tasks must both show `Password` logon. Do not use an S4U task for
the primary compare workload: S4U has no reusable network credential for the peer SMB
share.

#### Peer host — `utat01`

Changing the local `SvcParityAudit` password requires re-registering the peer task with
the current credential. First inspect it:

```powershell
Get-ScheduledTask -TaskPath '\ATAP\' -TaskName 'ATAP-ParityAudit' |
  Select-Object TaskName, State,
    @{ Name = 'RunAs'; Expression = { $_.Principal.UserId } },
    @{ Name = 'LogonType'; Expression = { $_.Principal.LogonType } },
    @{ Name = 'RunLevel'; Expression = { $_.Principal.RunLevel } }
```

It must use `Password` with `Limited` run level. Version `0.1.3` retains corrected S4U
registration as a capability for non-DPAPI tasks, but S4U is not valid for this wrapper
because its BWS probe decrypts per-user DPAPI material. Use this explicit configuration
with a newly prompted credential:

```powershell
$svcCredential = Get-Credential -UserName 'UTAT01\SvcParityAudit'

$parameters = @{
  TaskSet          = 'AuditOnly'
  HostName         = 'utat01'
  Cadence          = 'Daily'
  AuditTime        = '03:00'
  RunAsAccountName = 'SvcParityAudit'
  LogonType        = 'Password'
  Credential       = $svcCredential
  RunLevel         = 'Limited'
}

Register-ParityScheduledTasks @parameters -WhatIf
Register-ParityScheduledTasks @parameters
```

5. Validate without exposing the password. Confirm the account exists, start the
   affected scheduled task or service, and inspect its resulting state and exit code:

   ```powershell
   Get-LocalUser -Name 'SvcParityAudit' |
     Select-Object Name, Enabled, LastLogon

   Get-ScheduledTask -TaskPath '\ATAP\' |
     Where-Object TaskName -like 'ATAP-Parity*' |
     Select-Object TaskName, State

   Get-ScheduledTaskInfo -TaskPath '\ATAP\' -TaskName 'ATAP-ParityAudit' |
     Select-Object LastRunTime, LastTaskResult
   ```

   For the parity monitor, run a fresh audit on `utat01`, wait for completion and a
   zero task result, then run the audit and finally the compare task on `utat022`.
   `LastTaskResult` must be `0x00000000` for each task, and the primary compare task
   must be able to read the peer snapshot.

   The installed helper starts a task, waits for a new Task Scheduler run, and throws
   on timeout or a non-zero result. Invoke it through `powershell.exe -File`; this
   uses the inbox `ScheduledTasks` module on both Windows 10 and Windows 11. Its
   dual-purpose guard intentionally does not execute it through the call operator.

   ```powershell
   $waitScript = Join-Path $moduleRoot 'scripts\Invoke-ParityTaskAndWait.ps1'

   # Run on utat01 and wait for the peer snapshot before continuing.
   powershell.exe -NoProfile -File $waitScript -TaskName 'ATAP-ParityAudit'

   # Run on utat022 only after the peer audit succeeds.
   powershell.exe -NoProfile -File $waitScript -TaskName 'ATAP-ParityAudit'
   powershell.exe -NoProfile -File $waitScript -TaskName 'ATAP-ParityCompare'
   ```

6. Record the applied change and validation evidence in the parity-change journal only
   after the peer has applied its change. Record the account name, hosts, consumers,
   timestamps, and redacted result—never the password or BWS token.
