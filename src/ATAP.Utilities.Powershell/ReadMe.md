# ATAP.Utilities.Powershell

## Overview

Miscellaneous Powershell scripts

## Write-\*Indented Diagnostic Display Helpers (SC-0183, Task 11.20)

Four diagnostic display functions were moved from the inline `AllUsersAllHosts` profile
into this module's `public/` folder so the profile loads them via module autoloading
rather than redefining them on every session start (reduces profile load time):

- `Write-ArrayIndented` — formats an array as a multi-line indented string
- `Write-HashIndented` — formats a hashtable alphabetically as indented key=value pairs
- `Write-KVPIndented` — formats a single key-value pair as an indented string
- `Write-EnvironmentVariablesIndented` — formats all environment variables (Machine, User, Process scopes)

These are still called in the profile via the `Write-EnvironmentVariablesIndented` call
that appears in the startup diagnostics block; they now resolve from the installed module
(stable worktree) or dot-sourced sprint files (sprint worktree).

## Get-FilesWithContent

ToDo: write content

## Get-GoogleChromeBookmarks

ToDo: write content

## Get-PVal Loud-Failure Guard (Task 8.16, SC-prop-0007-1; host-context exception Task 9.1, V4-B02)

`Get-ParameterValueFromNeoConfigurationRoot` (alias `Get-PVal`) throws with `-NoProfile`
remediation text when value resolution reaches the settings stage and no settings source
exists at all — no `-Settings` argument, no `$script:Settings`, no `$global:settings` —
even when a `DefaultValue` or `-AllowMissing` is supplied. An entirely absent
`$global:settings` means the ATAP AllUsersAllHosts profile did not run (typically a
`pwsh -NoProfile` session), which is an environment fault, not a missing key. Never pass
`-NoProfile` for ATAP work.

**Host-context exception (Task 9.1, V4-B02).** The BuildMaster 5-tier pipeline runs its
runners via `pwsh -NoProfile -File` _by design_, so `$global:settings` is legitimately
absent there and the documented param → env → settings → `DefaultValue` chain must degrade
rather than throw. The runners declare that context by setting
`$env:ATAP_NOPROFILE_PIPELINE = '1'`; in the declared context the guard **yields** to an
explicit `-DefaultValue` / `-AllowMissing`. An interactive shell never sets the marker, so
the loud-failure guard above is fully intact for the case it was written for. A bare
`-NoProfile` on the command line is **not** the signal (Pester and CI harnesses also use
`-NoProfile`) — only the explicit `ATAP_NOPROFILE_PIPELINE` marker separates the pipeline
from an interactive fault. See
`SolutionDocumentation/PowerShellModule-Pipeline-NoProfile-Runbook.md`.

## Set-GroupEnvironmentVariables (eliminate the global_EnvironmentVariables.ps1 profile symlink)

`Set-GroupEnvironmentVariables` projects a caller-supplied group of ConfigRootKeys into
**process-scope** environment variables. For each `ConfigRootKey` it resolves the variable
**name** from `$global:configRootKeys[<ConfigRootKey>]` and the variable **value** from
`$global:settings[$global:configRootKeys[<ConfigRootKey>]]`, then sets the process
environment variable.

It is the programmatic replacement for symlinking
`Profiles/global_EnvironmentVariables.ps1` into the machine PowerShell profile directory
(`C:\Program Files\PowerShell\7\`). Rather than maintaining a per-worktree symlink that must
be retargeted at every sprint boundary (H09 / SC-0188), a profile, agent bootstrap, or
pipeline calls this function with just the group of ConfigRootKeys it needs, reading
authoritative values from the already-bootstrapped `$global:settings`. Like `Get-PVal`, it is
StrictMode-safe and **fails loud** when `$global:configRootKeys` / `$global:settings` are
absent and no `-ConfigRootKeyMap` / `-Settings` override is supplied. Secrets and API keys are
intentionally **not** projected — resolve those by canonical name through `Get-PVal` /
`Get-SecretATAP`.

```powershell
Set-GroupEnvironmentVariables -ConfigRootKeys 'FastTempBasePathConfigRootKey','DropBoxBasePathConfigRootKey'
```

## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

- Version bumped to 0.1.8 in Sprint 11
