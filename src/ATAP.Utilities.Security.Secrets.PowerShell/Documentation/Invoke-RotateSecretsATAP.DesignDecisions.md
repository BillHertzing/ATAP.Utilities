# `Invoke-RotateSecretsATAP` — binding design decisions

**Status:** Design record. The function is **not yet implemented** (Sprint 0012 Task 12.55.c).
**Source of authority:** `_Planning/InformationForTheFuture/PlanPowerShellSecurityReorganization.md`
Task 5.1 and Task 5.3; `_Planning/TASKS.Sprint0012.md` Tasks 12.55.a–12.55.a4, 12.56.

These decisions are **load-bearing and already made**. Implement them as stated. Do not
re-litigate them at code time.

---

## D1 — No PKI dependency

`Invoke-RotateSecretsATAP` calls **no** function from `ATAP.Utilities.Security.PKI.PowerShell`.
This module declares **no** `RequiredModules` edge on the PKI child. The `New-Random*` /
`New-Encrypted*` generators that live in the PKI child are **not** on the rotation path.

## D2 — Rotation scope is closed at exactly two secrets

The function rotates **exactly** the two Bitwarden **machine-account access tokens**:

1. `CommonCIForBitwardenReadOnly`
2. `CommonCIForBitwardenReadWrite`

**Explicitly out of scope:** Bitwarden Password Manager items, general Secrets Manager secrets,
per-sprint `dbConnectionString-*` secrets, and all API keys.

Build the rotation set **data-driven and extensible**, but ship with only these two enabled.
Anything else attempted in the first iteration is rejected at review.

Future secret classes are captured as **SC-0250**: `ProGet.Admin.ApiKey`,
`BuildMaster.Admin.API.Key`, the `svcProGet` password, the `svcBuildMaster` password.

> The two deferred **service-account passwords** are a materially harder rotation class than the
> tokens. They are Windows service logon credentials, so rotating them requires updating the
> service's logon password on every host in the same transaction as the vault update, or the
> service fails on next restart. Do not assume the token rotation path generalizes to them.

## D3 — The function generates nothing; values arrive by interactive paste

The operator regenerates each machine-account access token **by hand in the Bitwarden UI**
(out-of-band), then pastes each value into a **separate, individually labeled interactive prompt**.

**Clipboard auto-read is rejected.** There are two distinct tokens; a blind clipboard read cannot
tell them apart and would silently write the `ReadOnly` value into the `ReadWrite` slot or vice
versa. A swapped value **authenticates successfully on first touch** and only surfaces later as a
confusing permissions error. One prompt per token, each naming its machine account.

## D4 — Consequences of D3 (all binding)

| # | Consequence |
| --- | --- |
| D4.1 | **The live path is an interactive-only cmdlet.** It cannot run from an agent shell, scheduled task, CI, or any `-NonInteractive` session. **An AI agent cannot execute Task 12.56 / plan Task 5.3.** A human operator runs it from a real interactive terminal, on each host. |
| D4.2 | Non-interactive invocation of the live path **fails loudly with one clear terminating error** naming the missing prompt. It never half-rotates and never falls through to an empty value. |
| D4.3 | Prompts use `Read-Host -AsSecureString`, matching `SolutionDocumentation/Runbook-BitwardenServiceAccounts.md`. Pasting works but echoes nothing, so emit a **non-revealing confirmation** after each paste — token length plus a short SHA-256 fingerprint prefix — so a mis-paste is caught before it is written. |
| D4.4 | **Never** echo, log, or transcript a token value. PSFramework messages carry SecretName / token label only. |
| D4.5 | Prompt **order is fixed**: `CommonCIForBitwardenReadOnly` first, `CommonCIForBitwardenReadWrite` **last**. This matches the self-eviction sequencing in D5. |
| D4.6 | `-WhatIf` completes its dry run **without prompting at all** — nothing to paste when nothing is written — so the dry-run transcript stays runnable from any shell. |
| D4.7 | The Pester suite **mocks `Read-Host`** and remains runnable non-interactively in CI. |

### D4.2 has a worked precedent — do not reproduce it

**SC-0251** (`ScopeCreepManagement/ScopeCreep-Inbox.md`) records the exact failure mode in
`Add-ScopeCreepIdea`: a `Read-Host` in a non-interactive shell threw **non-terminating**, then
`Set-StrictMode -Version Latest` produced a confusing secondary `InvalidOperation` on the unset
variable, and the function **wrote an incomplete record anyway** while looking like it had failed.

For a secret-rotation cmdlet that outcome is unacceptable. Fail terminating, before any write.

## D5 — Self-eviction hazard

`Invoke-RotateSecretsATAP` authenticates to Bitwarden using the `CommonCIForBitwardenReadWrite`
machine-account token — **one of the two tokens it rotates**. Rotate it naively and the running
session loses vault access before it can write the new DPAPI files to the second host.

Sequence the `ReadWrite` rotation **last**, and keep the running session's token valid until the
new DPAPI files are written and verified on **both** `utat01` and `utat022`. Record the current
tokens out-of-band before the window so a failed rotation is recoverable.

A partial-host state (one host rotated, the other not) is a **rollback trigger, not a pass**.

## D6 — Token routing (Sprint 0012 Stream I contract)

| Path | Token purpose |
| --- | --- |
| Read | `Get-BWSAccessToken -TokenPurpose ReadOnly` → `CommonCIForBitwardenReadOnly` |
| Mutate / rotate | `Get-BWSAccessToken -TokenPurpose ReadWrite` → `CommonCIForBitwardenReadWrite` |

`ReadWrite` has **no** legacy single-slot fallback. See Sprint 0012 Tasks 12.50–12.53.

## D7 — Downstream consumers to update after rotation

Per-host, per-account DPAPI token files written by `Initialize-BWSAccessToken`, for the
interactive developer identity **and every service account** in the
`SolutionDocumentation/NewComputerSetup.md` account matrix (`SvcBuildmaster`, `SvcProGet`, …).
Enumerate identities from that matrix, not from memory. DPAPI files are host- and user-bound and
can never be copied between identities or machines.

## Still open

- Idempotency and rollback semantics (plan Task 5.1 design-gate step 4).
- Whether Bitwarden **issues** the new token value on regeneration (expected) or whether any local
  generation is required. Verify against the `bws` CLI surface before coding. If Bitwarden issues
  it, there is no generator to choose and D3 is the whole story.

---

## Rule 11 debt carried into this module (not introduced by it)

`Get-BitWardenCredential` mutates state — `Copy-Item` backups (lines ~161-162), `New-Item -Force`
directory creation (~205), and `Export-Clixml` credential writes (~211, ~214) — but declares only
`[CmdletBinding()]`, **without** `SupportsShouldProcess`.

This was **not** patched during the Task 12.55.b extraction. Adding `SupportsShouldProcess`
without guarding each mutation with `$PSCmdlet.ShouldProcess(...)` would be worse than leaving it:
it would advertise a `-WhatIf` that silently does nothing while still writing credential files.
Doing it correctly is a real edit to a 246-line credential-handling function, and the smoke tests
that would catch a regression were authored in the same commit as the move.

**Fix it in Task 12.55.c**, with the test slice already green, guarding each of the five mutation
points above. Tracked against SC-0248.
