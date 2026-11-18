# ATAP.Utilities.ConfigRootKeys.PowerShell — Overview

Created 2026-07-07 (Sprint 0012 Task 12.46.f scaffold pass).

This module owns **Tier 1** of the two-tier configuration system: the
`$global:configRootKeys` hashtable of key-name string constants. Every
eponymous section function under `public/` adds the key names for one subsystem
(databases, package repositories, BuildMaster, RulesManagement, hosts, …);
`Set-GlobalConfigRootKeys` orchestrates loading them. Tier 2 (the values) is populated
per-workstation by ATAP.IAC `Windows\HostSettings.ps1` and its
`HostSettings.IAC.Fragments\`, which consume these key names.

Canonical documentation for the whole two-tier system:
`SolutionDocumentation\ConfigRootKeys-and-HostSettings.md` (§9 covers the ATAP.IAC
fragment files). Functional area: Environment / Workstation Setup — START HERE
`SolutionDocumentation\NewComputerSetup.md`.


The source candidate `Set-OrchestrationConfigRootKeys` is explicitly ordered
immediately after Core and exported by the manifest. It registers seventeen flat
orchestration name constants only. An initialized Hashtable is required; all
conflicts are checked before additions, equivalent repeat calls are idempotent,
and `-WhatIf` leaves keys unchanged. The candidate has not been deployed and
establishes no host settings, defaults, measurements or operational admission.

`Set-PackageOwnershipConfigRootKeys` runs after the SystemParityMonitor section
and before BuildMaster. It registers the package-manager ownership vocabulary:
`PackageOwnership` (section), `SchemaVersion` and `ManagerOwnership`. ATAP.IAC
publishes the values per host. SystemParityMonitor reads `ManagerOwnership`
(`WinGet` package ids and `ChocolateyExcluded` regex patterns) so that drift
remediation never hands a WinGet-owned package back to Chocolatey. Until the
release that contains these keys is installed, ATAP.IAC's `Hosts.ps1` defers the
PackageOwnership fragment rather than failing profile load.
