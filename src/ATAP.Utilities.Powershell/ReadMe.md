# ATAP.Utilities.Powershell

## Overview

Miscellaneous Powershell scripts

## Get-FilesWithContent

ToDo: write content

## Get-GoogleChromeBookmarks

ToDo: write content
## Get-PVal Loud-Failure Guard (Task 8.16, SC-prop-0007-1)

`Get-ParameterValueFromNeoConfigurationRoot` (alias `Get-PVal`) throws with `-NoProfile`
remediation text when value resolution reaches the settings stage and no settings source
exists at all — no `-Settings` argument, no `$script:Settings`, no `$global:settings` —
even when a `DefaultValue` or `-AllowMissing` is supplied. An entirely absent
`$global:settings` means the ATAP AllUsersAllHosts profile did not run (typically a
`pwsh -NoProfile` session), which is an environment fault, not a missing key. Never pass
`-NoProfile` for ATAP work.

## 5-Tier Module Flow

Use the module-level getting started guide for the lifecycle workflow:

- [Documentation/GettingStarted.md](Documentation/GettingStarted.md)

