# ATAP.Utilities.Security.Powershell Index

## Contents

- [ReadMe](ReadMe.md)
- [Documentation](Documentation/)

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
