# AI Docs → Reviewed Docs: Merge Task List

Purpose: migrate durable technical insights from the `AI on ...` / `AI Generated ...` /
`AI Conversations.md` / `AI prompt ...` documents into the non-AI docs that were
reviewed in the INDEX.md audit. Each task names the **source** (AI doc + approximate
line range or section) and the **target** (doc to update) with a specific insert/update.

No target-doc edits have been made yet. This list is the work queue.

Legend: **P1** = correctness/security (do first), **P2** = completeness, **P3** = nice-to-have polish.

---

## 1. Rules Compendium.Powershell.md

### Task 1.1 — Add canonical logging rules (P1) ✅ COMPLETE

- **Source:** `AI prompt to create Copilot instruction files.md` lines 1-305 (esp. the
  `Write-PSFMessage` template with `-FunctionName $fn -ModuleName $mn -Level <Debug|Verbose|Important|Error>`
  and tag conventions `RestCall` / `WebRequestCall` / `InvokeExpressionCall` / `InvokeCommandCall`).
- **Target:** add a **Logging** rule set under Rules Compendium.Powershell.md.
- **What to write:** explicit rules — never `Write-Host`/`Write-Output` for logging;
  never `Level Info`; always set `-FunctionName`/`-ModuleName`; tag every external call
  with one of the four call-type tags; place `-ErrorAction Stop` on any call whose
  failure should abort the enclosing try.

### Task 1.2 — Try/Catch/Finally template (P1) ✅ COMPLETE

- **Source:** same AI prompt doc — the validation + try/catch/finally exemplar.
- **Target:** Rules Compendium.Powershell.md, new **Error Handling** primitive.
- **What to write:** mandatory pattern — validate inputs with `[Validate*]` attributes
  or `[string]::IsNullOrWhiteSpace`, wrap external calls in try, `catch { Write-PSFMessage -Level Error ...; throw }`,
  `finally { <cleanup> }`. Cross-reference the logging rule.

### Task 1.3 — GELF/SEQ provider with named instances (P2) ✅ COMPLETE

- **Source:** `AI Conversations.md` (section on `Set-PSFLoggingProvider -Name gelf -InstanceName SendToSEQ ...`).
- **Target:** Rules Compendium.Powershell.md **Logging** rule set (sub-section) and/or `TestingMethodology.md`.
- **What to write:** one instance per sink; naming convention `SendTo<Sink>`; filters
  at the provider level, not in code; warning that sinks with the same name collide.

### Task 1.4 — `[string]::IsNullOrEmpty` / `IsNullOrWhiteSpace` / `ValidateScript` primitive (P2) ✅ COMPLETE

- **Source:** `AI On Proget and Publish.md` lines 1-89.
- **Target:** Rules Compendium.Powershell.md, **Input Validation** primitive.
- **What to write:** prefer the static .NET methods over `-eq $null -or -eq ''`;
  `ValidateScript` with explicit `throw` message for complex invariants.
- **Result:** `### Input Validation Rule Set` appended at line 1886; Philote `b57a4b16-293e-4938-ba7e-b809aff30066`; Rules IV-1 through IV-4; file now 1,976 lines.

### Task 1.5 — Debugger hooks (P3) ✅ COMPLETE

- **Source:** `AI on VSC and Powershell and Repository Feeds.md` lines 1-410 (debugger section).
- **Target:** Rules Compendium.Powershell.md appendix **Debugging Tools**.
- **What to write:** `Wait-Debugger`, `[System.Diagnostics.Debugger]::Break()`, dynamic
  `Set-PSBreakpoint -Command <name>` — when each is appropriate.
- **Result:** `### Debugging Tools Appendix` appended at line 1978; Philote `b70ddc13-9453-4b76-9689-24460a3fc41f`; Rules DBG-1 through DBG-3 + summary table; file now 2,063 lines.

---

## 2. Security Shift-Left.md

### Task 2.1 — BW_SESSION acquisition pattern (P1) ✅ COMPLETE

- **Source:** `AI on You are an expert on the BitWarden password manag.md` lines 1-562.
- **Target:** Security Shift-Left.md, new section **Bitwarden Session Bootstrap**.
- **What to write:** Windows login does NOT set `BW_SESSION`; the user's pwsh profile
  must run `$env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw` once per
  session; VSC inherits `BW_SESSION` only if launched from a shell where it is set.
- **Result:** `## Bitwarden Session Bootstrap` appended at line 779; Philote `e1304e80-8720-4212-b842-b7c17d3f100d`; Rules BSB-1 through BSB-4; file now 827 lines.

### Task 2.2 — `match`-property iteration bug in SecretManagement.BitWarden / Warden (P1) ✅ COMPLETE

- **Source:** same BitWarden AI doc — `login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })`
  fails on items where `match` is `$null`.
- **Target:** Security Shift-Left.md **Known Issues** + cross-ref from
  `SecretsPluginArchitecture.md` and `Module Catalog.md` §3.3.9.
- **What to write:** null-guard required before cast; prefer shelling to `bw` directly
  until the upstream modules are patched.
- **Result:** `## Known Issues: Bitwarden SecretManagement Extension` appended at line 828; Philote `8e7bb62c-099e-47ae-aabf-82e2a6fe8b6f`; file now 879 lines.

### Task 2.3 — Headless service-account pattern (P1) ✅ COMPLETE

- **Source:** same BitWarden AI doc — API-key login with `BW_CLIENTID` / `BW_CLIENTSECRET`.
- **Target:** Security Shift-Left.md, new section **Service Accounts / CI**,
  cross-ref from `NewComputerSetup.md` (Jenkins bootstrap).
- **What to write:** never use interactive `bw login` on CI; provision API keys in
  Bitwarden UI, store the two envs as machine-scope, use `bw login --apikey` then
  `bw unlock --passwordenv`.
- **Result:** `## Service Accounts / CI` appended at line 880; Philote `5ed118cb-1711-4ea2-b32f-1cb9184baa05`; file now 944 lines.

### Task 2.4 — `Register-PSResourceRepository` with `-CredentialInfo` (P2) ✅ COMPLETE

- **Source:** `AI On Proget and Publish.md` + `AI on VSC and Powershell and Repository Feeds.md`.
- **Target:** Security Shift-Left.md credential-at-rest section; cross-ref `NewComputerSetup.md`.
- **What to write:** PSResourceGet v3 `-CredentialInfo` retrieves credentials from a
  named SecretManagement vault at call time — avoids plaintext creds in profile or
  `PSRepositories.xml`.
- **Result:** `## PSResourceGet Credential-at-Rest: Register-PSResourceRepository -CredentialInfo` appended at line 945; Philote `dda5026c-aefd-481f-9927-fb2b16618339`; Rules CIR-1 through CIR-4 + summary table; file now 1,005 lines.

---

## 3. NewComputerSetup.md

### Task 3.1 — ProGet `Web.BaseUrl` / custom-port 302 gotcha (P1) ✅ COMPLETE

- **Source:** `AI on Feeds and Secrets.md` lines 1-916 (the "invalid Web Uri" investigation).
- **Target:** NewComputerSetup.md, ProGet install step.
- **What to write:** `Web.BaseUrl` MUST include the custom port (e.g. `http://server:8624/`);
  otherwise `Register-PSRepository` follows the 302 and fails with "invalid Web Uri".
  Verify with `ProGet.Service.exe` config dump.
- **Done:** Appended as "Step 9" to the ## Install ProGet section. Philote: `7a5d02d4-895c-41ba-9b57-9862328281d7`. NewComputerSetup.md: 723 → 794 lines.

### Task 3.2 — ProGet.Service.exe CLI verbs (P2) ✅ COMPLETE

- **Source:** `AI on VSC and Powershell and Repository Feeds.md` ProGet CLI section.
- **Target:** NewComputerSetup.md ProGet section (replace ad-hoc install prose).
- **What to write:** document `run` / `install` / `installweb` / `uninstall` and when
  to use each; note that `install` creates a Windows service, `run` is for debugging.
- **Done:** Appended as "Step 10" to the ## Install ProGet section. Philote: `50c1d535-5b55-4388-af2c-4d473627bfdb`. NewComputerSetup.md: 794 → 850 lines.

### Task 3.3 — ProGet DELETE feed API (P3) ✅ COMPLETE

- **Source:** `AI on Feeds and Secrets.md` — `DELETE /api/management/feeds/delete/{feed-name}` with `X-ApiKey`.
- **Target:** NewComputerSetup.md troubleshooting appendix.
- **What to write:** admin cleanup recipe; needed because the web UI occasionally
  leaves orphaned feeds after migration.
- **Done:** Appended new `## Troubleshooting — ProGet Feed Management` section with list-first/delete/pgutil/recovery pattern. Philote: `90ab74a9-31fe-488a-b56a-828f5b305071`. NewComputerSetup.md: 850 → 941 lines.

---

## 4. BuildMaster-ProGet-CSharp-Package-Pipeline.md

### Task 4.1 — `allowInsecureConnections="true"` placement (P1)

- **Source:** `AI Conversations.md` NuGet.config section.
- **Target:** BuildMaster-ProGet-CSharp-Package-Pipeline.md NuGet.config examples +
  `plan-fixDotnetBuild.prompt.md` + `Building.md`.
- **What to write:** the attribute belongs in `<packageSourceSettings>`, NOT `<config>`;
  verify effective config with `nuget config -list`.
- ✅ **DONE** — Philote `3bf42c43-15a3-4d8b-9ada-83365d37c450`
  BuildMaster doc: 746 → 848 lines (new §13 NuGet.config Reference).
  plan-fixDotnetBuild.prompt.md: 227 → 248 lines. Building.md: 230 → 242 lines.

### Task 4.2 — Republish semantics / duplicate-rejection (P2)

- **Source:** `AI Conversations.md` Republish-NuGet section.
- **Target:** BuildMaster-ProGet-CSharp-Package-Pipeline.md promotion stages.
- **What to write:** `nuget add` rejects duplicates; `Republish-NuGet.ps1` re-pushes
  only when the source feed's package differs; call out the SHA-embedding circularity
  that prevents true byte-for-byte republish.
- ✅ **DONE** — Philote `19ec4ccb-7769-46f3-9cc6-c4300efcfac5`
  BuildMaster doc: 848 → 909 lines (new §4.3 Package immutability and republish semantics).

### Task 4.3 — BaGet as local alternative (P2)

- **Source:** `AI Conversations.md` BaGet Docker recipe.
- **Target:** BuildMaster-ProGet-CSharp-Package-Pipeline.md new appendix
  **Lightweight Local Alternative: BaGet**, OR a new section in `Building.md`.
- **What to write:** NuGet v3 server in a single Docker container; useful for
  offline / developer-machine use; note feature gap vs ProGet (no promotion pipelines).

### Task 4.4 — Publish URL pattern (P3)

- **Source:** `AI on Feeds and Secrets.md` — `https://server/nuget/feed/` (trailing slash matters).
- **Target:** BuildMaster-ProGet-CSharp-Package-Pipeline.md feed-URL table.
- **What to write:** document exact URL shape; link to troubleshooting entry for
  "invalid Web Uri".

---

## 5. ~~Versioning.md — inconsistency resolution (P1)~~ COMPLETED

### ~~Task 5.1 — Reconcile tier-label conflict~~

**DONE.** `Versioning.md` has been deleted. Its non-obsolete content (SemVer
validity note, feed connector topology table, key source files list) was merged
into `BuildMaster-ProGet-CSharp-Package-Pipeline.md`. INDEX.md updated.

---

## 6. SecretsPluginArchitecture.md

### Task 6.1 — Concrete secrets backends (P2)

- **Source:** `AI on Feeds and Secrets.md` Bitwarden CLI / Secrets Manager / Public API /
  KeePass comparison.
- **Target:** SecretsPluginArchitecture.md, new section **Concrete Shims**.
- **What to write:** table comparing `bw` vs `bws` vs Public API vs KeePass
  (`keepassxc-cli`, `kpcli`); which `ISecretsAbstract` implementations map to which;
  session-lifecycle differences.

### Task 6.2 — Bitwarden Secrets Manager pricing / licensing path (P3)

- **Source:** `AI on Feeds and Secrets.md` pricing section (Free 2u/3p/3ma; Teams $6; Enterprise $12).
- **Target:** `DeveloperMusings.md` (SecSub design discussion) or a new appendix in SecretsPluginArchitecture.md.
- **What to write:** two-person free-org upgrade path to Secrets Manager;
  token/machine-account limits; decision criteria for when to migrate from CLI to SM.

---

## 7. Module Catalog.md (§3.3)

### Task 7.1 — Secrets sub-catalog expansion (P2)

- **Source:** BitWarden AI doc + `AI on Feeds and Secrets.md`.
- **Target:** Module Catalog.md §3.3.9 (Secrets).
- **What to write:** enumerate `BitwardenSecretsShim`, `BitwardenConfigurationSource/Provider`,
  `SecretsRouter`, `SecretMapping`; reference the `match`-property bug from
  Security Shift-Left.md; list planned KeePass shim.

---

## 8. New/consolidated document: DevEnvironment.md (P2)

Many of the dev-tool insights don't fit any existing doc. Propose a **new** doc
`SolutionDocumentation/DevEnvironment.md` that gathers them. If a new doc is
undesired, merge into `VisualStudioExtensions.md`.

### Task 8.1 — cspell custom dictionary

- **Source:** `AI on many Dev Tools.md` cspell section.
- **Content:** user-dictionary file location on Windows, `ignoreRegExpList` recipes
  for GUIDs / base64 / hex.

### Task 8.2 — PSReadLine shared history

- **Source:** `AI on many Dev Tools.md` PSReadLine section.
- **Content:** timestamp + hostname merge; commands to exclude from history to avoid
  recording secrets.

### Task 8.3 — PSScriptAnalyzer formatting + inline disable

- **Source:** `AI on many Dev Tools.md`.
- **Content:** `PSScriptAnalyzerDisableFormatting` inline directive; prettier `-&&`
  autoformat bug workaround.

### Task 8.4 — PSModulePath on Windows

- **Source:** `AI on many Dev Tools.md` PSModulePath section.
- **Content:** distinction between `C:\Program Files\PowerShell\Modules` (all versions)
  and `C:\Program Files\PowerShell\7\Modules` (pwsh 7 only); install-target guidance.

### Task 8.5 — npm global bin + junctions

- **Source:** `AI on many Dev Tools.md` npm section.
- **Content:** global bin path; when to junction vs symlink; UAC requirements.

### Task 8.6 — VSC integrated-terminal vs external-terminal profile differences

- **Source:** `AI on many Dev Tools.md`.
- **Content:** why `$env:BW_SESSION` and other interactively set vars leak into VSC
  but not into detached agent shells.

---

## 9. AI Generated Summary.md (P2)

### Task 9.1 — Mark stale or update

- **Source:** AI Generated Summary.md itself (says C# 11 / .NET 8).
- **Target:** AI Generated Summary.md — either delete and replace with a pointer to
  `architecture-overview.md` + `Module Catalog.md`, OR add a dated banner
  **"Snapshot 2025-05-16 — superseded; current stack is C# 14 / .NET 10"** and keep
  as a historical artifact.

---

## 10. INDEX.md follow-ups (P3)

### Task 10.1 — Reference the new docs

- After 8.x lands, add `DevEnvironment.md` to INDEX.md under a new **Developer Environment** section.
- After 9.1 lands, update INDEX.md entry for AI Generated Summary.md with the stale-banner note.

### Task 10.2 — Cross-reference the Rules Compendium additions

- After 1.x lands, INDEX.md entry for `Rules Compendium.Powershell.md` should mention
  the new Logging / Error Handling / Input Validation rule sets.

---

## 11. NewComputerSetup.md / Security Shift-Left.md — WSL2-specific Bitwarden (P3)

> **Note:** `Module Catalog New Material.md` was renamed to
> `AI on WSL2 Ansible Docker and Bitwarden.md` — content is a 7-exchange
> Perplexity.ai Q&A on WSL2 + Ansible + Docker + Bitwarden. Tasks below
> extract additional insights not yet in §2 or §3.

### Task 11.1 — BW_SESSION auto-unlock inside WSL pwsh profile

- **Source:** `AI on WSL2 Ansible Docker and Bitwarden.md` exchanges 6–8.
- **Target:** Security Shift-Left.md §Bitwarden Session Bootstrap (from task 2.1),
  add a sub-section **WSL-specific pattern**.
- **What to write:** pwsh profile at `~/.config/powershell/Microsoft.PowerShell_profile.ps1`;
  guard with `if ($env:WSL_DISTRO_NAME)`; use `bw unlock --raw --passwordenv BW_PASSWORD`
  or prompt once with `Read-Host -AsSecureString`; why CLIXML from Windows DPAPI is
  unsuitable inside WSL.

### Task 11.2 — Docker container secret injection patterns

- **Source:** `AI on WSL2 Ansible Docker and Bitwarden.md` exchange 5.
- **Target:** Security Shift-Left.md, new sub-section **Secrets in Docker containers (WSL2)**.
- **What to write:** Pattern A (Secrets Manager CLI `bws` + `BWS_ACCESS_TOKEN` in container);
  Pattern B (pre-deploy `bw` step generating `.env` file mounted at `--env-file`);
  why WSL PowerShell SecretManagement is not directly accessible from containers.

### Task 11.3 — WSL2 drives / networking / Ansible setup condensed reference

- **Source:** `AI on WSL2 Ansible Docker and Bitwarden.md` exchanges 1–3.
- **Target:** NewComputerSetup.md — new appendix **WSL2 Ansible/Docker Quick Reference**,
  or a standalone `WSL2Setup.md` in SolutionDocumentation.
- **What to write:** `wsl --install Ubuntu-24.04`; `/etc/wsl.conf` automount; WSL IP
  via `ip route show`; `netsh interface portproxy` for older NAT; PowerShell
  `wsl -d <Distro> -- ansible-playbook ...` trigger pattern; `\\wsl$\<Distro>` Windows
  path alias.

---

## Source coverage map

| AI doc                                                     | Insights extracted                                                                          |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| AI Generated Summary.md                                    | stale-stack flag (§9)                                                                       |
| AI On Proget and Publish.md                                | PSResourceGet v3 + validators (§1.4, §2.4)                                                  |
| AI prompt to create Copilot instruction files.md           | PowerShell logging + error-handling canon (§1.1, §1.2)                                      |
| AI on VSC and Powershell and Repository Feeds.md           | ProGet CLI verbs, debugger hooks (§1.5, §3.2)                                               |
| AI on Feeds and Secrets.md                                 | Web.BaseUrl gotcha, DELETE API, BW vs BWS vs API, pricing (§3.1, §3.3, §4.4, §6.1, §6.2)    |
| AI on You are an expert on the BitWarden password manag.md | BW_SESSION, `match` bug, headless service-accts (§2.1, §2.2, §2.3, §3.4)                    |
| AI Conversations.md                                        | NuGet.config placement, BaGet, GELF instances, Republish semantics (§1.3, §4.1, §4.2, §4.3) |
| AI on many Dev Tools.md                                    | cspell, PSReadLine, PSScriptAnalyzer, PSModulePath, npm, VSC terminal (§8.1–§8.6)           |
| AI on WSL2 Ansible Docker and Bitwarden.md                 | WSL pwsh profile BW_SESSION, Docker secret injection, WSL2 setup reference (§11.1–§11.3)    |

---

## Recommended execution order

1. §5.1 (tier-label reconciliation — unblocks everything referencing pipeline stages)
2. §2.1 – §2.3 (Bitwarden correctness/security)
3. §3.1 (ProGet Web.BaseUrl — blocks anyone trying to register the feed)
4. §4.1 (NuGet.config correctness)
5. §1.1 – §1.2 (logging + error-handling canon; many other docs will cross-ref these)
6. §9.1 (retire or banner the stale AI summary)
7. Remaining P2 tasks
8. §8.x (new DevEnvironment.md) and P3 polish
9. §11.x (WSL2-specific Bitwarden and Docker patterns)
