# Release Notes — ATAP.Utilities.Security.Secrets.PowerShell

## 0.1.0 (unreleased)

Initial extraction. Pilot child of the `ATAP.Utilities.Security.*` family
(Sprint 0012 Task 12.55.b).

- Moved the six Bitwarden functions out of `ATAP.Utilities.Security.Powershell`:
  `Get-BitWardenCredential`, `List-BitwardenSecrets`, `Load-BitwardenBackup`,
  `New-BitwardenBackup`, `Set-BitWardenSecret`, `Sync-BitWardenDedicatedSecrets`.
- Moved the three aliases with them: `New-BWSecret`, `Add-BitWardenLogin`,
  `Sync-DedicatedSecrets`. These are now **exported** (they were module-internal in the
  umbrella, whose `AliasesToExport` was `@()`).
- **`Load-BitwardenBackup` is now exported.** It was defined in the umbrella's `public/` but
  omitted from the umbrella's `FunctionsToExport`, so it was unreachable as a cmdlet.
- Manifest born correctly cased, `PowerShellVersion = '7.0'`, `CompatiblePSEditions = 'Core'`,
  explicit `CmdletsToExport`/`VariablesToExport` (no wildcards).
- Added the module's first Pester tests (the umbrella had none).

The umbrella re-exports all six functions and three aliases, so existing consumers that
`Import-Module ATAP.Utilities.Security.Powershell` see an unchanged command surface.

### Added `Invoke-RotateSecretsATAP` (Sprint 0012 Tasks 12.55.c–12.55.e)

New public function. Rotates **exactly two** secrets — the Bitwarden machine-account access tokens
`CommonCIForBitwardenReadOnly` and `CommonCIForBitwardenReadWrite` — on the current host for the
current Windows identity. It **generates nothing**: the operator regenerates each token in the
Bitwarden UI and pastes it into a separate labeled `Read-Host -AsSecureString` prompt.

- **Interactive-only live path.** A session with redirected stdin (agent shell, scheduled task, CI)
  is rejected in `BEGIN`, before any write, with one terminating error. It never half-rotates.
- **`-WhatIf` prompts for nothing and writes nothing,** so a dry run works from any shell.
- Every paste is confirmed by length + a 12-character SHA-256 prefix, then verified by reading the
  DPAPI file back and matching that fingerprint. No token value is ever echoed, logged, or thrown.
- `ReadOnly` rotates first, `ReadWrite` last — the function authenticates with the `ReadWrite` token
  it rotates, so rotating it last keeps the running session recoverable.
- Deliberately **not** re-exported by the umbrella: it is a new function whose home is this child,
  not a moved name needing compatibility.

Three private helpers accompany it: `Get-SecureStringFingerprint`, `Test-BWSAccessTokenFormat`, and
`Test-RotationSessionIsInteractive`.

Live rotation on `utat01` and `utat022` is Sprint 0012 Task 12.56 — a **human-only** task.

### Fixed

- **`Get-BitWardenCredential` now declares `SupportsShouldProcess`.** Its five mutation points
  (two `.bak` copies, `New-Item -Force`, two `Export-Clixml` writes) sit behind a single
  `ShouldProcess` gate, so `-WhatIf` is honest instead of advertised-and-ignored. The backup copies
  also moved *after* the required-parameter validation, so a call destined to fail validation no
  longer leaves `.bak` files behind. (SC-0248)
- All six moved functions attributed their PSFramework messages to
  `ATAP.Utilities.Security.Powershell`. They now name this module.

### Known remaining debt (tracked, not fixed in this iteration)

- `Get-BitWardenCredential` accepts passwords as `[string]`. PSScriptAnalyzer reports
  `PSAvoidUsingConvertToSecureStringWithPlainText` and `PSAvoidUsingUsernameAndPasswordParams`
  against it. Fixing it changes the public signature, which is a consumer-facing break. (SC-0248)
- `List-BitwardenSecrets` and `Load-BitwardenBackup` use non-approved verbs. Rename deferred by
  Sprint 0012 Task 12.55.a; when renamed, the old names ship as exported aliases.
- No `RequiredModules` minimum on `ATAP.Utilities.BuildTooling.PowerShell` yet. The `-TokenPurpose`
  parameter that `Invoke-RotateSecretsATAP` consumes is newer than the installed 0.1.20, so the pin
  waits for Task 12.54.d to publish it and Task 12.55.f to apply it. Until then the function
  dot-sources the sibling source tree.
