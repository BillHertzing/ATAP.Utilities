# ATAP.Utilities.Security.Powershell Index

module: ATAP.Utilities.Security.Powershell
functional-area: Secrets & Security
family-role: umbrella (re-export mode)
family-child: ATAP.Utilities.Security.Secrets.PowerShell
family-child: ATAP.Utilities.Security.PKI.PowerShell

## Contents

- [ReadMe](ReadMe.md)
- [Documentation](Documentation/)

## Module family

| Module | Role | Status |
| --- | --- | --- |
| `ATAP.Utilities.Security.Powershell` | Umbrella; residual functions + re-exports the Secrets and PKI children | This module |
| [`ATAP.Utilities.Security.Secrets.PowerShell`](../ATAP.Utilities.Security.Secrets.PowerShell/INDEX.md) | Bitwarden functions | Extracted, Sprint 0012 Task 12.55.b |
| [`ATAP.Utilities.Security.PKI.PowerShell`](../ATAP.Utilities.Security.PKI.PowerShell/INDEX.md) | Certificate / PKI functions | Extracted, Sprint 0014 Stream E |

## Moved out of `public/` (Sprint 0012 Tasks 12.55.b, 12.55.c)

| File | New location | Reason |
| --- | --- | --- |
| `SecretVaultTesting.ps1` | `Documentation/SecretVaultTesting.ps1.txt` | Executed destructive top-level code at import |
| `Test-SecretVault.ps1` | `Documentation/Test-SecretVault.ps1.txt` | No function; dot-sourced stable-worktree absolute paths, including itself |
| `PKIForNewOrg.ps1` | PKI child `Documentation/PKIForNewOrg.md` | Converted to an opt-in runbook; no import-time execution |

All three were phantom entries in `FunctionsToExport` and have been removed from it. Each `.ps1.txt`
for SecretVault remains preserved as a future runbook input. The PKI source was converted and removed.

## Assessments

- [Task 9.15 — Shortcomings assessment + revise/complete plan](../../_generated/Security/Task-9.15-SecurityPowershell-GapAssessment.md)
  (Sprint 9, Stream SEC). Read-only gap report: import-safety/manifest defects, the
  non-canonical `version.json`, the broken/stub install cmdlets, and how the module ties
  into the remote-git-over-SSL fix (Tasks 9.16/9.17).
- Task 9.16 — Remote Git over SSL restored (Sprint 9, Stream SEC). The durable
  workstation fix is user/global `http.sslBackend=schannel`, overriding the system
  Git for Windows `openssl` backend so HTTPS remotes use Windows-native trust.
  Verified from a fresh PowerShell process with `git ls-remote origin HEAD`,
  `git fetch origin`, and non-mutating `git push --dry-run origin HEAD`.
