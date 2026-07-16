# Task 12.10 / 12.11 / 12.13 Verification

Date: 2026-07-08

## Source Changes

- Task 12.10: `Invoke-SprintEndGitHubClose.ps1` marks draft pull requests ready before squash merge and refreshes PR state before check/merge evaluation.
- Task 12.11: `Assert-MainBranchTemplateRef.ps1` supports `-WhatIf` as a structured violation preview while preserving normal fail-fast throws.
- Task 12.13: `Test-SprintEndBoundaryState.ps1` accepts `-ServiceAccountCredential` and `-RequireServiceAccountFreshShell`; `Invoke-SprintEndServiceAccountFreshShell.ps1` performs alternate-credential fresh-shell validation when credentials are supplied.

## Verification

- `SprintEndTask12Fixes.Tests.ps1`: focused tests for all three tasks.
- `Assert-MainBranchTemplateRef.Tests.ps1`: existing templateRef validation compatibility.
- `SprintEndLifecycle.Tests.ps1`: surrounding SprintEnd lifecycle compatibility.

Transcript: `_generated/Task-12.10-12.11-12.13-focused-pester.txt`.

## Deployment Caveat

Source is implemented and verified. BuildTooling was not version-bumped, promoted through BuildMaster, or installed AllUsers in this pass; per the Build Deploy Module workflow, that requires a separate module release sequence.
