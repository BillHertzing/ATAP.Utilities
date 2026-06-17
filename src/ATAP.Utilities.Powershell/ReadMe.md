# ATAP.Utilities.Powershell

## Overview

Miscellaneous Powershell scripts

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
runners via `pwsh -NoProfile -File` *by design*, so `$global:settings` is legitimately
absent there and the documented param → env → settings → `DefaultValue` chain must degrade
rather than throw. The runners declare that context by setting
`$env:ATAP_NOPROFILE_PIPELINE = '1'`; in the declared context the guard **yields** to an
explicit `-DefaultValue` / `-AllowMissing`. An interactive shell never sets the marker, so
the loud-failure guard above is fully intact for the case it was written for. A bare
`-NoProfile` on the command line is **not** the signal (Pester and CI harnesses also use
`-NoProfile`) — only the explicit `ATAP_NOPROFILE_PIPELINE` marker separates the pipeline
from an interactive fault. See
`SolutionDocumentation/PowerShellModule-Pipeline-NoProfile-Runbook.md`.

## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

