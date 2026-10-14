# Runbook: Elevated Install Broker on a Peer Host (utat022)

## Purpose

Bring a peer host to parity with utat01 for the elevated install broker: the code, the
scheduled task, the start-rights grant, and the calling code in the build tooling.

utat01 was provisioned on 2026-07-28. This runbook is the replication procedure, and is
referenced from the parity journal entries so the peer host records declared changes rather
than undeclared drift.

## Why the broker exists

Agents and build tooling run unelevated. An AllUsers module install writes under
`Program Files` and needs administrator rights, so without a broker an agent either fails or
falls into a blind `Start-Process -Verb RunAs` retry loop with no transcript. The broker
performs the install as a service account under a scheduled task with highest privileges,
validates every request against an admin-owned config, and always leaves a transcript.

`build-deploy-module` cannot complete its final install step on a host where the broker is
absent.

## Prerequisites on the peer host

- `SvcAnsibleAdmin` local account exists.
- Bitwarden secret `SvcAnsibleAdmin.<hostname>` resolves through `Get-SecretATAP` — for
  example `SvcAnsibleAdmin.utat01`, `SvcAnsibleAdmin.utat022`, `SvcAnsibleAdmin.ncat040`.
  This document previously named `SvcAnsibleAdmin.Login.<hostname>`, which does not exist;
  resolving it fails with "No Bitwarden Secrets Manager secret found with key ... in the
  BWS token's granted projects." Corrected 2026-08-12 by enumerating the live vault: **none
  of the 66 keys contains `.Login.`**, so the service-account form is
  `<ServiceAccount>.<hostname>` everywhere, not just for `SvcAnsibleAdmin`.
- ProGet feeds reachable, including `powershellget-stable`.
- A synced clone of `ATAP.Utilities`.
- PowerShell 7 with profiles loading (`$global:settings` populated). Do not use
  `-NoProfile`.

### Provisioning a BWS token for the broker account

Only needed when the broker must resolve secrets itself, as the constrained parity-task
installer does for a Password-logon task's run-as credential.

**DPAPI is profile-bound as well as user-bound, so this cannot be done over remoting.**
Running `Initialize-BWSAccessToken` inside an explicit-credential PowerShell session fails
with "Error occurred during a cryptographic operation", because a network logon loads no
user profile and therefore no DPAPI master key. It must run as the owning account **in a
process that has a profile** — a Password-logon batch process. A temporary one-shot
scheduled task registered as `SvcAnsibleAdmin` with `LogonType` `Password`, run once and
then deleted, is the working pattern.

`Initialize-BWSCredentialDirectory` must run first: `Initialize-BWSAccessToken` does not
create the per-account credential directory and fails if it is absent.

Verify by reading the token back and resolving one real SecretName **as that account**, not
from an administrator session.

## Step 1: Code

The broker code ships inside `ATAP.Utilities.BuildTooling.ProGet.PowerShell`. Nothing needs
to be copied by hand.

| Artifact | Path in the module |
| -------- | ------------------ |
| Client (called by build tooling) | `public\Request-ElevatedInstall.ps1` |
| Provisioning | `public\Register-ElevationBrokerTask.ps1` |
| Start-rights grant | `public\Grant-ElevationBrokerStartRights.ps1` |
| Broker payload, task XML, config template | `Resources\ElevationBroker\` |

Import from the **clone**, not from an installed module. The broker is what installs modules
AllUsers, so on a fresh host it must be provisioned before the install machinery works.

```powershell
# ELEVATED pwsh
$proGetModule = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.ProGet.PowerShell'
Import-Module "$proGetModule\ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1" -Force -DisableNameChecking
```

## Step 2: Scheduled task and folder structure

```powershell
Register-ElevationBrokerTask -Verbose
```

This creates `C:\ProgramData\ATAP\ElevationBroker` with its subfolders, deploys the payload
and config template, applies a restrictive non-inherited ACL to `requests\`, and registers
`\ATAP\ATAP-ElevatedInstallBroker` to run as `SvcAnsibleAdmin` with highest privileges.

Two properties of the registration are load-bearing and must not be "tidied up":

- **No repeating time trigger.** On utat01 a one-minute timer fired roughly 4,644 times to
  service 4 real requests and measurably contributed to CPU saturation. The task is started
  on demand instead. `BootTrigger` is the catch-up drain for requests staged while the broker
  could not run.
- **`MultipleInstancesPolicy` is `Queue`, not `IgnoreNew`.** Under `-Once` the broker
  enumerates the requests folder exactly once and exits, so `IgnoreNew` would silently strand
  a request staged while another instance was running. The old timer masked that race; with
  on-demand start it would surface as an intermittent silent hang.

An existing `config.json` is never overwritten unless `-ForcePayload` is passed, because that
file is the broker's trust anchor.

## Step 3: Start rights

```powershell
Grant-ElevationBrokerStartRights -Principal '<HOSTNAME>\<developer-account>' -Verbose
```

Required, not optional: with no repeating timer, a caller that cannot start the task gets
`broker-unreachable` on every request. The grant confers read + execute only — the grantee
can ask the broker to drain, but cannot change what the task runs.

Do not grant this to `Everyone`, `Authenticated Users`, or `Users`; the function refuses
those identities, matching the broker's own ACL check.

For corpus capture on UTAT022, the requester is the service identity rather than an
interactive developer. Re-registration replaces the task DACL, so always apply this exact
grant after `Register-ElevationBrokerTask`:

```powershell
Grant-ElevationBrokerStartRights `
  -Principal 'UTAT022\SvcAceOutpost' `
  -TaskPath '\ATAP-Broker\' `
  -Confirm:$false
```

This grants only task read/execute. It does not grant task modification, administrator
membership, corpus ACL authority, or any permanent privilege to `SvcAceOutpost`.

## Step 4: Calling code

The build tooling calls the broker from the `build-deploy-module` skill, section 10, instead
of `Install-Module -Scope AllUsers`. The canonical skill source lives in SharedVSCode at
`.ai/skills/build-deploy-module/SKILL.md`; the per-repo copies are generated wrappers. Ensure
the peer host has re-rendered adapters (`Render-AIAdapters`) so its copies carry the broker
call.

Both `FeedUrl` and `ExpectedSha256` are mandatory on `Install-ATAPModuleAllUsers`, and the
broker config rejects a request that omits either.

```powershell
$r = Request-ElevatedInstall -InstallerId 'install-atap-module-allusers' -Parameters @{
  ModuleName      = '<ModuleName>'
  RequiredVersion = '<Version>'
  Repository      = 'powershellget-stable'
  FeedUrl         = (Get-PSRepository -Name powershellget-stable).SourceLocation
  ExpectedSha256  = '<sha256 of the .nupkg tested in the promotion step>'
}
if ($r.status -ne 'succeeded') {
  throw "Elevated install failed [$($r.status)]: $($r.error). Transcript: $($r.transcriptPath)"
}
```

### Activate the corpus-sealing action

Activation order is security-significant. Complete it through an explicitly authorized,
non-interactive administrative channel; never use `Start-Process -Verb RunAs`, UAC, a
certificate-store dialog, or any other console prompt. A PowerShell remoting channel must
select `-ConfigurationName 'PowerShell.7'`. Use the already-installed broker action or a
separately approved administrative automation path to establish the two trusted module
versions before replacing the broker trust anchor:

1. Promote and install ProGet module 0.1.22 and SprintLifecycle module 0.1.37 at AllUsers
   scope, then verify both resolve from `C:\Program Files\PowerShell\Modules` at those exact
   versions.
2. Import ProGet 0.1.22 by its absolute manifest path and re-register with `-ForcePayload`
   so `config.json` gains `seal-gather-call-record-segment`.
3. Reapply the `UTAT022\SvcAceOutpost` start-rights grant after registration.
4. From the service identity's normal, non-elevated context, submit a hash-pinned sealing
   request and require a `succeeded` result plus its transcript before enabling capture.

The administrative activation commands are intentionally non-interactive:

```powershell
$proGetManifest = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.ProGet.PowerShell\0.1.22\ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1'
$sprintLifecycleManifest = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\0.1.37\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psd1'

foreach ($manifest in $proGetManifest, $sprintLifecycleManifest) {
  if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "Required trusted module manifest is missing: $manifest"
  }
}

Import-Module -FullyQualifiedName $proGetManifest -Force -ErrorAction Stop
Register-ElevationBrokerTask `
  -RequesterPrincipal 'UTAT022\SvcAceOutpost' `
  -TaskPath '\ATAP-Broker\' `
  -ForcePayload `
  -Confirm:$false
Grant-ElevationBrokerStartRights `
  -Principal 'UTAT022\SvcAceOutpost' `
  -TaskPath '\ATAP-Broker\' `
  -Confirm:$false
```

The request carries only `StagingFilePath`, `CorpusGatherRecordsStagingPath`,
`CorpusGatherRecordsPath`, `SprintNumber`, `CaptureIdentity`, `ExpiryIdentity`, and
`ExpectedSha256`. It cannot choose the module, command, module path, trusted root, or a
privileged bypass. Broker regexes reject malformed values before dispatch; the trusted
SprintLifecycle command independently revalidates canonical paths, matching root and
volume, reparse points, resolved identities, JSONL content, destination, and exact bytes.

## Step 5: Verify

Run from a **normal, non-elevated** shell. An elevated shell succeeds through the
`Administrators` ACE and proves nothing about the grant.

```powershell
$s = New-Object -ComObject Schedule.Service
$s.Connect()
$t = $s.GetFolder('\ATAP').GetTask('ATAP-ElevatedInstallBroker')
$t.Run($null)
Start-Sleep -Seconds 5
"result=$($t.LastTaskResult) lastrun=$($t.LastRunTime)"
```

Expect `result=0` and a current timestamp. Access denied means Step 3 targeted the wrong
account.

## Known gotchas

- The client starts the task through the `Schedule.Service` COM API, not
  `Start-ScheduledTask`. The `ScheduledTasks` module is a Windows PowerShell CDXML module and
  is **not present at all** under PowerShell 7 on these hosts; `-SkipEditionCheck` does not
  help.
- Windows canonicalises task SDDL. An ACE submitted as `(A;;GRGX;;;<sid>)` is stored as
  `(A;;0x1200a9;;;<sid>)` in a re-ordered DACL. Verify a grant by locating the ACE by SID and
  testing the `TASK_EXECUTE` bit, never by string-matching the submitted ACE.
- An unelevated `schtasks /query` reports "cannot find the path specified" for a task that
  exists. Never conclude "the task is missing" from an unelevated shell.
- `Register-ElevationBrokerTask` deletes and recreates the registration, which discards the
  ACL. Always run `Grant-ElevationBrokerStartRights` **after** registering, never before.

## Confirming parity

After completing the steps, close out the journal entries on the peer host:

```powershell
Get-PeerPendingChanges -PeerHostName utat01
Confirm-ParityChangeApplied -ChangeId <id>
```
