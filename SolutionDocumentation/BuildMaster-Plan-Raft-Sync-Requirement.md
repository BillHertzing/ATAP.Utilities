# BuildMaster Plan Raft Sync Requirement

**Rule of record:** A committed change to an OtterScript plan or its stage-runner script is
**not live**. BuildMaster executes the plan stored in its **raft**, not the `.otter` file in
the worktree. Every change to a plan's argument list — and every change to a stage-runner
parameter block — must be followed by `Sync-BuildMasterPlans` before any pipeline run.

Skipping the sync produces a **silent indefinite hang**, not an error. This document exists
because that failure mode cost a full release cycle to diagnose on 2026-08-03.

## The two halves that must move together

A pipeline stage is defined in two files that are committed together but deployed
differently:

| File | Where it lives at run time | How it gets there |
| --- | --- | --- |
| `Plans/<Pipeline>.otter` | BuildMaster **raft** (database) | `Sync-BuildMasterPlans` — an explicit, separate step |
| `Plans/Invoke-*BuildMasterStage.ps1` | Read from the **worktree** on disk | Immediately, as soon as the file is saved |

This asymmetry is the whole problem. The stage script is picked up the instant it is
committed; the plan that *invokes* it is not. A commit that changes both leaves the raft
holding the **old** argument list while the worktree already has the **new** parameter
block.

## The failure mode: a missing mandatory parameter blocks forever

When the stale raft plan omits an argument that the new stage script declares as
`[Parameter(Mandatory)]`, PowerShell does exactly what it is designed to do: it prompts the
console for the missing value. The stage runs under BuildMaster's LocalAgent, non-interactive,
with no stdin. The prompt can never be answered.

The result is a process that hangs indefinitely and produces **no error at any layer**:

- The build sits at `status: active`, `furthestStage: <first stage>`, forever.
- The execution log's last line is `INFO : Executing pwsh...` and nothing after.
- The `pwsh` process is alive but accumulates almost no CPU (~0.3 seconds over 10 minutes).
- A `conhost.exe` child exists — the allocated console for the prompt nobody can see.
- The stage's `_generated/buildmaster/<BuildMasterBuildId>/` run-state directory is
  **never created**, because the hang happens during parameter binding, before the script
  body runs.
- Nothing is published, so every tier feed still shows only the previous version.

## Worked example: the 2026-08-03 incident

Commit `dfa333ecc` (*feat(security): implement Stream E PKI and signing*) added Authenticode
signing to the PowerShell-module pipeline. It correctly changed both halves:

- `Invoke-PowerShellModuleBuildMasterStage.ps1` gained two **mandatory** parameters:
  `-CodeSigningCertificateThumbprint` and `-TimestampServerUri`.
- `PowerShellModule-5Stage.otter` gained the matching arguments on its `Arguments:` line.

`Sync-BuildMasterPlans` was never run. BuildMaster kept executing the pre-signing plan.

Releasing `ATAP.Utilities.BuildTooling.PlanningSession.PowerShell` 0.1.4 then queued build
`21240` / execution `21641`, which spawned child execution `21642`. Its log ended at:

```text
DEBUG: Arguments: -NoProfile -File "...\Invoke-PowerShellModuleBuildMasterStage.ps1" ...
       -Stage "Experimental " -ProGetUrl "https://utat022:50000"
       -ProGetApiKeySecretName "ProGet.BuildMaster.API.Key.utat022"
INFO : Executing pwsh...
```

The two signing arguments are simply absent — the signature of a stale raft plan. The
process blocked on the hidden prompt for both mandatory values. The BuildMaster application
variables `$CodeSigningCertificateThumbprint` and `$TimestampServerUri` were correctly
defined the whole time; the plan that would have passed them was the stale one.

Fix: `Sync-BuildMasterPlans -Path Plans\PowerShellModule-5Stage.otter`, then re-queue.

## Required procedure when changing build steps

1. Edit the stage-runner script and the `.otter` plan in the same commit.
2. **Sync the plan to the raft**, from the sprint worktree:

   ```powershell
   Set-GlobalConfigRootKeys | Out-Null
   $global:settings = Get-HostSettings -hostName $env:COMPUTERNAME
   Import-Module ATAP.Utilities.BuildTooling.PowerShell

   $plans = Join-Path $repoRoot 'src\ATAP.Utilities.BuildTooling.BuildMaster\Plans'

   # Preview first — confirms which raft items would be replaced.
   Sync-BuildMasterPlans -Path (Join-Path $plans '<Pipeline>.otter') -WhatIf

   Sync-BuildMasterPlans -Path (Join-Path $plans '<Pipeline>.otter')
   ```

   Use `-Path $plans -Recurse` to sync every plan when several changed.

3. If the new arguments read BuildMaster variables, confirm those variables exist **before**
   re-queuing:

   ```powershell
   $apiKey = Get-SecretATAP -SecretName $global:settings['BuildMasterAdminApiKeySecretName']
   Invoke-RestMethod -Uri 'https://utat022:50017/api/variables/application/<ApplicationName>' `
     -Headers @{ 'X-ApiKey' = $apiKey }
   ```

4. Re-queue the pipeline and verify the executed command line in the child execution log
   contains the new arguments.

## Design guidance: fail fast instead of hanging

The hang is a consequence of `[Parameter(Mandatory)]` in a non-interactive context. Two
defenses, in order of preference:

1. **Never let a stage runner prompt.** BuildMaster stage scripts should treat a missing
   required value as a hard error rather than relying on mandatory-parameter binding. Give
   the parameter no `Mandatory` attribute and validate explicitly in `begin`:

   ```powershell
   if ([string]::IsNullOrWhiteSpace($CodeSigningCertificateThumbprint)) {
     throw "CodeSigningCertificateThumbprint was not supplied. The BuildMaster raft plan is " +
           "probably stale — run Sync-BuildMasterPlans after changing plan arguments."
   }
   ```

   This converts a silent forever-hang into a one-line diagnosis in the execution log.

2. **Make the prompt impossible.** Invoking the runner with `-NonInteractive` in the plan's
   `Arguments:` causes PowerShell to throw on a missing mandatory parameter instead of
   prompting. This is a defence in depth, not a substitute for defence 1.

## Triage checklist for a stalled stage

Work down this list; it distinguishes a stale-raft hang from an ordinary failure in about a
minute.

1. Build stuck `active` at the first stage with no error → suspect a hang, not a failure.
2. Read the child execution log. Last line `Executing pwsh...` with nothing after → hang
   confirmed. Note the child execution id from the parent's
   `Waiting for execution #NNNNN to complete...`.
3. Compare the logged `Arguments:` line against the worktree `.otter` `Arguments:` line.
   **Any argument present in the file but missing from the log means the raft is stale.**
4. Confirm the process is blocked rather than working:

   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" |
     Where-Object CommandLine -like '*BuildMasterStage*' |
     Select-Object ProcessId, CreationDate
   Get-Process pwsh | Select-Object Id, StartTime, CPU   # near-zero CPU over minutes
   ```

5. Confirm `_generated/buildmaster/<BuildMasterBuildId>/` was never created — that places
   the hang in parameter binding, before the script body.
6. Stop the orphan (`Stop-Process -Id <pid> -Force`), sync the plan, re-queue.

## Related documentation

- [Runbook-BuildMasterConfiguration.md](Runbook-BuildMasterConfiguration.md)
- [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md)
- [BuildMaster-Pipeline-Topology.md](BuildMaster-Pipeline-Topology.md)
- [BuildMaster-Run-State-Runbook.md](BuildMaster-Run-State-Runbook.md)
- [PowerShellModule-Pipeline-NoProfile-Runbook.md](PowerShellModule-Pipeline-NoProfile-Runbook.md)
- [Feed-Protocol-HTTP-to-HTTPS-Migration.md](Feed-Protocol-HTTP-to-HTTPS-Migration.md)
