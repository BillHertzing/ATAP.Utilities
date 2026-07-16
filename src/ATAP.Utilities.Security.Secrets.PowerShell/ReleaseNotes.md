# Release Notes — ATAP.Utilities.Security.Secrets.PowerShell

## 0.1.1 — 2026-07-09

### Fixed

- **The three exported aliases were missing from the published 0.1.0 package.** They were declared
  with `Set-Alias` in the source `.psm1`. `Build-PSModulePsm1` **regenerates** the shipped `.psm1` by
  concatenating `public\` and `private\` and **discards the source `.psm1`**, so the `Set-Alias`
  calls never reached the package. `AliasesToExport` named three aliases that nothing defined:
  `New-BWSecret`, `Add-BitWardenLogin`, and `Sync-DedicatedSecrets` all resolved to *nothing* when
  the module was installed, and the umbrella's re-export of them silently exported zero aliases.

  Everything looked correct from source, which is exactly why it shipped. Aliases are now declared
  with function-level `[Alias()]` attributes on `Set-BitWardenSecret` and
  `Sync-BitWardenDedicatedSecrets` — the pattern `ATAP.Utilities.PowerShell` already uses for
  `Get-PVal`, and the only one that survives the module build.

### Added

- Three contract tests that would have caught it before publishing: every alias in `AliasesToExport`
  must be defined by the loaded module; each alias must be backed by a function-level `[Alias()]`
  attribute (asserted by AST); and the source `.psm1` must contain no `Set-Alias`.

> ⚠ **0.1.0 is defective and immutable.** It is present in `powershellget-stable` with three broken
> alias exports. Do not install it. Consider removing it from the feed.

## 0.1.0 — 2026-07-09 (superseded by 0.1.1; do not use)

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
### Deployment

Published to `powershellget-stable` and installed `-Scope AllUsers` on **`utat022`** and **`utat01`**
(Sprint 0012 Task 12.55.f). On both hosts a fresh shell resolves `Invoke-RotateSecretsATAP` from the
installed module, and `Install-Module` pulls `ATAP.Utilities.BuildTooling.PowerShell` 0.1.29
automatically through the `RequiredModules` pin.

The umbrella `ATAP.Utilities.Security.Powershell` now declares this module in its own
`RequiredModules` at a `0.1.1` minimum.

### Dependencies

`RequiredModules` now pins `ATAP.Utilities.BuildTooling.PowerShell` at a **0.1.29 minimum** — the
version that first ships `-TokenPurpose` on `Get-BWSAccessToken` / `Initialize-BWSAccessToken`.
Pinning it means an older BuildTooling fails at import rather than at rotation time. Two contract
tests guard it: one on the declared minimum, one asserting the resolved version really exposes the
parameter.
