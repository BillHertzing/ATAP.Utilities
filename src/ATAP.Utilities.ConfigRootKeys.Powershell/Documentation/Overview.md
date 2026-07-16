# ATAP.Utilities.ConfigRootKeys.PowerShell — Overview

Created 2026-07-07 (Sprint 0012 Task 12.46.f scaffold pass).

This module owns **Tier 1** of the two-tier configuration system: the
`$global:configRootKeys` hashtable of key-name string constants. Every
`*.ConfigRootKeys.ps1` file under `public\` adds the key names for one subsystem
(databases, package repositories, BuildMaster, RulesManagement, hosts, …);
`Set-GlobalConfigRootKeys` orchestrates loading them. Tier 2 (the values) is populated
per-workstation by ATAP.IAC `Windows\HostSettings.ps1` and its
`HostSettings.IAC.Fragments\`, which consume these key names.

Canonical documentation for the whole two-tier system:
`SolutionDocumentation\ConfigRootKeys-and-HostSettings.md` (§9 covers the ATAP.IAC
fragment files). Functional area: Environment / Workstation Setup — START HERE
`SolutionDocumentation\NewComputerSetup.md`.
