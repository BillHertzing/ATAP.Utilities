# SolutionDocumentation Index

## Functional Area Map (START HERE per area)

Added 2026-07-06 (Sprint 0012 Task 12.45.e, `PlanDocumentationReorganization.md` 4.a;
area list approved by the user 2026-07-06). Each functional area of the ecosystem has
exactly one START-HERE (highest-level) document; the annotated sections further below
carry the per-file detail.

| Functional area                       | START HERE                                     | Also in this area (selection)                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| C# Build & Packaging                  | `CSharp-Packages-Build-Process.md`             | CSharp-Packages-{Versioning,Test-Process,Pack-and-Push}, CSharp-Central-Package-Management, BuildTooling-MSBuild-Internals, CS0246-Errors-TypeNotFound                                                                                                                                                                                                                                                                   |
| PowerShell Build & Packaging          | `PowerShell-Modules-Build-Process.md`          | PowerShell-Modules-{Versioning,Test-Process,Pack-and-Publish}, PowerShell-Script-Consolidation, PowerShellModule-Pipeline-NoProfile-Runbook; BuildTooling child-module family under `src\ATAP.Utilities.BuildTooling.*.PowerShell` with `ATAP.Utilities.BuildTooling.PowerShell` retained as the compatibility parent                                                                                                                                                        |
| Versioning & Immutable Build Strategy | `Immutable-Build-Strategy.md`                  | VersionJsonAsCeiling(+Runbook), Package-Pinning-Ownership-Decision, BranchModel-Future-Work, Long-Developing-Features                                                                                                                                                                                                                                                                                                    |
| BuildMaster / ProGet Infrastructure   | `Production-and-Tooling-Overview.md`           | BuildMaster-Pipeline-Topology, BuildMaster-Install-Runbook, Runbook-BuildMasterConfiguration, BuildMaster-Run-State-Runbook, ProGet-Install-Runbook                                                                                                                                                                                                                                                                      |
| Database & Flyway                     | `Database-Change-Unit-and-Flyway-Promotion.md` | `ATAPUtilities-Database-0.1.3-Release-Record.md` (BuildMaster/ProGet live release, checksum-repair backup, final tier proof), Database-Package-\* decisions, Database-MultiDB-Future-Requirements, Developer-SqlServerInstances-Runbook, ATAPUtilities-Instantiation-Tables; machine provisioning, settings-backed `C:\LocalDBs\<INSTANCE>\{Data,Log,Backup}\` topology, and the five-tier `SvcBuildMaster` deployment-database grant: `NewComputerSetup.md` / `NewComputerSetupUsingAnsible.md`; module: `src\ATAP.Utilities.DatabaseManagement.Powershell` |
| RRSBS & Rules Compendiums             | `Rules Compendium.md`                          | Rules Compendium.{CSharp,SQL,PowerShell,MSBuild,Snippet,Manim,Path,OtterScript,AgentText,Markdown}, Rules-Compendium-Template, Example.RuleInstantiation.HelloWorld; module: `src\ATAP.Utilities.RulesManagement.PowerShell`                                                                                                                                                                                             |
| Secrets & Security                    | `Security Shift-Left.md`                       | Security-PowerShell-Module-Architecture, ServiceAccountsAndBitwarden(+AlternativesConsidered), Runbook-BitwardenServiceAccounts, SecretName-HostSuffix-Convention, SecretsPluginArchitecture, GenericPluginArchitecture; modules: `src\ATAP.Utilities.Security.Powershell` (umbrella), `src\ATAP.Utilities.Security.Secrets.PowerShell` (Secrets compatibility), `src\ATAP.Utilities.Security.PKI.PowerShell` (PKI child; 0.1.2 source adds PKCS#12 creation, multi-host trust, and Windows signing issuance)                                                                                           |
| Environment / Workstation Setup       | `NewComputerSetup.md`                          | NewComputerSetupUsingAnsible, NewOrganizationSetup, DevEnvironment, WSL2Setup, VisualStudioExtensions, ConfigRootKeys-and-HostSettings, IAC-Windows-Scripts-Migration, `src\ATAP.Utilities.SystemParityMonitor.PowerShell\Documentation\Overview.md` and `InstallationAndTroubleshooting.md` (host-pair parity architecture plus Windows 10/11 install, credential-backed S4U registration, WinRM/PSModulePath recovery, and static-payload packaging limitations; journal every `utat022`/`utat01` machine-state change before execution, Task 12.38.f; moved from ATAP.IAC 2026-07-07); modules: `src\ATAP.Utilities.ConfigRootKeys.Powershell`, `src\ATAP.Utilities.IAC.Ansible.Powershell`, `src\ATAP.Utilities.SystemParityMonitor.PowerShell` |
| Sprint & Worktree Infrastructure      | `Sprint-Boundary-Retargeting.md`               | Worktree-Source-of-Truth-Inventory, SprintInfrastructure-Naming, Sprint-Planning references                                                                                                                                                                                                                                                                                                                              |
| Testing                               | `TestingMethodology.md`                        | CSharp-Packages-Test-Process, PowerShell-Modules-Test-Process                                                                                                                                                                                                                                                                                                                                                            |
| Disaster Preparedness                 | `Disaster Preparedness.md`                     | Backup-SqlServer-ProGet-BuildMaster, Backup-ProGet-BuildMaster-ApplicationData, Cobian-Reflector-Backup-Automation                                                                                                                                                                                                                                                                                                       |
| Core PowerShell Utilities             | `src\ATAP.Utilities.PowerShell\ReadMe.md`      | Added 2026-07-07 (Task 12.46.g, user-approved): the base cross-cutting utilities/profile-helpers module plus `src\ATAP.Utilities.FileIO.PowerShell` (file/path/Dropbox/drive-mapping helpers)                                                                                                                                                                                                                            |
| Domain & Personal Utilities           | `Domain-and-Personal-Utilities.md`             | Added 2026-07-07 (Task 12.46.g, user-approved): FinancialAPI, Hydrus, Neo4j, Speech, VennDiagramGenerator, VoiceRecognition modules (see the START-HERE page's module table)                                                                                                                                                                                                                                             |
| AI Agents & Adapters (pointer area)   | SharedVSCode `SolutionDocumentation/INDEX.md`  | Sprint-Lifecycle-Agent-Workflow, Agent-Permission-Model, CLAUDE-md-Across-Repositories, Junction-vs-File-Sync-Alternatives, Using-Agent-Swarms (all in SharedVSCode)                                                                                                                                                                                                                                                     |
| AceCommander (parked)                 | `AceCommander-architecture-overview.md`        | AceCommander-Modernization-Plan, SQLCipher-License-Decision — eventual home AceCommander SolutionDocumentation (SC-0245)                                                                                                                                                                                                                                                                                                 |

Files indexed into areas 2026-07-06 (previously missing from this INDEX):
`AceCommander-Modernization-Plan.md`, `AceCommander-architecture-overview.md`,
`Backup-ProGet-BuildMaster-ApplicationData.md`, `Backup-SqlServer-ProGet-BuildMaster.md`,
`BranchModel-Future-Work.md`, `BuildTooling-MSBuild-Internals.md`,
`Cobian-Reflector-Backup-Automation.md`, `IAC-Windows-Scripts-Migration.md`,
`NewOrganizationSetup.md`, `Package-Pinning-Ownership-Decision.md`,
`ProGet-Install-Runbook.md`, `Runbook-BuildMasterConfiguration.md`,
`SQLCipher-License-Decision.md`, `TraceETW-Configuration.md` (C# Build & Packaging area),
`VersionJsonAsCeiling-Runbook.md`.

---

This index catalogs the non-AI documents under `SolutionDocumentation/`. Documents
are grouped by purpose. A top-level distinction separates material that **teaches
or tells how to create software** (methodology, build, rules, setup) from material
that **describes how the target application — Ace Commander — will work**
(architecture, modules, feature intent).

- **Teach / Tell how to create software:** Setup, Security, Producing Software,
  Rules Compendium, Testing Methodology, and most build/versioning guides.
- **Describe how Ace Commander works:** Module Catalog, Generic Plugin
  Architecture, Secrets Plugin Architecture, Developer Musings (SecSub design),
  architecture-overview, and the various `.drawio` diagrams.

> **Stub / placeholder files:** `ContributingGuidelines.md` is a single-line
> stub. `ReadMe.md` is only partially populated; most of its subsections
> (Overview, Publishing, Debugging, Packaging, Using, Disaster Preparedness)
> still contain TBD/ToDo placeholders. `toc.yml` is a minimal 12-line DocFX
> stub that lists only six documents and is badly out of date.

> **Known inconsistencies across documents**
>
> - **Tier-label vocabulary conflict — RESOLVED.** `Versioning.md` (stale 4-tier
>   labels) has been deleted; its non-obsolete content was merged into
>   [BuildMaster Pipeline Topology](BuildMaster-Pipeline-Topology.md),
>   which is the single source of truth for all pipeline, feed, and tier-label
>   definitions as of Sprint 0007.
> - **"Module Catalog New Material.md"** was mis-titled (Perplexity.ai WSL2 content,
>   not catalog additions). The file now lives under
>   **`ReviewedAndArchived/AI on WSL2 Ansible Docker and Bitwarden.md`**.

---

## Setup — Computer and Organization

_Teach / Tell how to create software._

- [New Computer Setup](NewComputerSetup.md) — **Far more than a bootstrap page.**
  Sprint 0013 reconciliation records Dropbox/Git integrity, host-qualified
  multi-host sprint assignment, canonical ATAP.IAC profile sources, BWS versus
  personal-vault boundaries, five-role SQL protection, canonical Inedo ports,
  the parity-journaled `SvcBuildMaster` `db_owner` grant on all five authorized
  `ATAPUtilities` tier databases, mobile/Class A certification, and explicit deferred/HITL gates. Linked runbook and
  documentation-contract reconciliation is complete; clean-host rehearsal remains open.
  Run the read-only,
  idempotent `Test-NewComputerSetupDocumentation.ps1` contract validator after changing
  this guide or its active linked BuildMaster runbooks.
  The first half covers Rufus USB preparation, BIOS configuration, Windows
  install, and WinRM/Ansible enablement via `ConfigureRemotingForAnsible.ps1`.
  The second half (the bulk of the 700+-line document) is an end-to-end
  **build-server provisioning runbook**: SQL Server Express install with a
  PRODUCTION named instance on port 50001; creation of `SvcSQLServer`,
  `SvcProGet`, and `SvcBuildMaster` service accounts via
  `New-LocalServiceAccount`; Inedo Hub installation; eight-step ProGet install
  including `Initialize-ProGetSqlServiceLogin`, `Initialize-SqlServiceLogin`,
  ProGet.config symlinking, EncryptionKey retrieval from Bitwarden, API-key
  registration; and a build of the `aaronontheweb/mssql-mcp` MCP server.
- [New Computer Setup Using Ansible](NewComputerSetupUsingAnsible.md) —
  Alternate draft of workstation and build-host bootstrap guidance.
- [New Computer Provisioning Runbook](Runbook-NewComputerProvisioning.md) —
  Execution plan for `NewComputerSetup.md`, expressed as parallelizable streams with
  declared owners: organizational work (O1–O5), human-manual/console-bound work (H1–H5),
  and agent-automated work (A1–A8), joined by four gates (Authorized to build, Clean
  baseline, Tooling operational, Ready State). Records what may run concurrently and what
  must not (profiles before repo integrity, broker before module install, SQL before
  service accounts). Appendix A carries the `ncat040` instance plan: Mission 1 clean-host
  validation stopping at Gate 1 with a one-task-per-restore-cycle image discipline, then
  Mission 2 as a DPOM and testing host. Does not restate procedure — `NewComputerSetup.md`
  remains canonical for every step.
- [Sprint-Boundary Retargeting](Sprint-Boundary-Retargeting.md) — V4-H03 source of
  truth for the `Set-SprintBoundaryContext` orchestrator: which concern (machine
  links, SharedVSCode settings, downstream contexts, registry-backed AI adapters)
  retargets at sprint start/end via which worker, the sole adapter render/drift
  APIs and caller order, boundary-time `settings.overlay.json` refresh, why
  adapter drift blocks teardown, and how machine, developer, plus service-account
  PowerShell profiles now follow the sprint/stable boundary while ConfigRootKeys
  remain the only stable-by-design no-op.
- [WSL2 Setup](WSL2Setup.md) — WSL2 provisioning notes for development and
  automation workflows.
- [ReadMe](ReadMe.md) — Repository overview, prerequisites, and pointers to the
  Building, Publishing, Packaging, and Disaster Preparedness sections. **Many
  sections are still TBD/ToDo placeholders** rather than prose.
- [Contributing Guidelines](ContributingGuidelines.md) — **Stub (1 line)**
  reserved for future contributor guidance (branching, PR flow, code review).
- [Setup for Visual Studio Code Extension](Setup%20for%20Visual%20Studio%20Code%20Extension.md)
  — Installing Node.js, Yeoman, and `generator-code`; scaffolding the
  ATAP.AIAssist VS Code extension project. Also lists runtime npm packages
  (`js-yaml`, `events`), dev packages (`mocha`, `chai`, `sinon`, `ts-node`,
  `webpack`, `tsconfig-paths`), and LLM-client modules (`axios`, `openai`,
  `prettier`, `kdbxweb`, `diff`).
- [Visual Studio Extensions](VisualStudioExtensions.md) — Tooling notes for
  GhostDoc, DocFx, the AutoDoc project, and custom MSBuild **Targets**
  (lockfile create/remove, invalid-outputs detection) and **Tasks**
  (`GetVersion`, `SetVersion`, `UpdateVersion`), the MSBuild Community Tasks
  package, and MSBuild Structured Log Viewer install via Chocolatey. Still
  contains several "TBD" sections (GhostDoc config paths, VS settings).
- [Disaster Preparedness](Disaster%20Preparedness.md) — **Largely a skeleton.**
  Section headers for cloud sync (Dropbox / OneDrive / GoogleDrive),
  on-premise and off-premise backup, and validation via `Confirm-GitFSCK`
  are present, but most content is placeholder. Preserves tool configs for
  VS Code, Git, and SpellCheck.
- [Attribution](Attribution.md) — **566 lines — much broader than a bibliography.**
  Covers Flyway (§3.3.3), GitHub issue/branch workflow (§3.3.4),
  Jenkins/ProGet integration (§3.3.5), dbatools / SqlClient (§3.3.6), VS Code
  C# build (§3.3.7), multi-project NuGet packaging (§3.3.8), Bitwarden CLI
  (§3.3.9), and WSL2 source list (§3.3.10). Additional sections on Copilot
  token usage, the Copilot coding agent, Claude Code Windows install, and
  Google AI plans (§2.4.4–2.4.7).

---

## Developer Environment

_Teach / Tell how to create software — per-developer tooling and shell setup._

- [Developer Environment](DevEnvironment.md) — Consolidated guide for the tools
  and behaviors that affect day-to-day development. Covers: **CSpell** custom
  dictionary location (`%USERPROFILE%\.cspell\cspell-dict.txt`) and
  `ignoreRegExpList` recipes for GUIDs / base64 / hex; **PSReadLine** shared
  history with timestamp+hostname merging and commands to exclude to avoid
  recording secrets; **PSScriptAnalyzer** `PSScriptAnalyzerDisableFormatting`
  inline directive and the prettier `&&` autoformat workaround;
  **PSModulePath** — distinction between
  `C:\Program Files\PowerShell\Modules` (all versions) and
  `C:\Program Files\PowerShell\7\Modules` (pwsh 7 only) with install-target
  guidance; **npm global bin** path and when to prefer junctions vs symlinks
  with UAC considerations; **VS Code integrated vs external terminal** — why
  `$env:BW_SESSION` and other interactively set variables are visible inside
  VS Code but not in detached agent shells.
  (Philote `f0da7925-1a2d-454d-bf95-f8ae8d0f3e12`.)
- [ConfigRootKeys and Host Settings](ConfigRootKeys-and-HostSettings.md) —
  How the PowerShell two-tier global-settings pattern works:
  `$global:configRootKeys` (the host-invariant vocabulary of settings-key name
  constants, built by the `ATAP.Utilities.ConfigRootKeys.PowerShell` module via
  `Set-GlobalConfigRootKeys`) and `$global:settings` (the host/user-specific
  values, built by `Get-HostSettings` from the ATAP.IAC `HostSettings.ps1`).
  Covers the three-level value chain, the profile bootstrap order, the canonical
  `$global:settings[$global:configRootKeys[...]]` access expression, defensive
  loading in non-interactive agent shells, the explicit-loading (no fragment
  discovery) section-function design, the in-module sibling-resolution guard that
  keeps a sprint-worktree function from being shadowed by an installed module, and
  the checklist for adding a new setting.
- [Developer SQL Server Instances Runbook](Developer-SqlServerInstances-Runbook.md) —
  Onboarding/offboarding runbook for the permanent per-developer SQL Server
  instances (`Dev<username>` / `Exp<username>`). Documents the Sprint-0008
  lifecycle change (instances are created once per workstation by
  `New-DeveloperSqlServerInstances` and removed only by
  `Remove-DeveloperSqlServerInstances`; sprint boundaries reset only the
  databases inside them via `Reset-SprintDatabases` / `Remove-SprintDatabases`),
  the instance naming convention, and the dbatools prerequisites. Migrated from
  `_Planning/Explainers/0028-developer-onboarding-sql-instances.md` (Sprint 0008,
  Task 8.4).

---

## Security Considerations

_Teach / Tell how to create software (with two "describe" entries noted)._

- [Security Shift-Left](Security%20Shift-Left.md) — **779 lines.** Framed as
  CI/CD secret-handling principles, but the bulk is an OpenSSL + PKI tutorial:
  Root CA creation; SSL server certs via `New-DistinguishedNameHash`,
  `New-RandomPassPhraseToFile`, `New-EncryptedPrivateKey`, `New-CACertificate`,
  `Create-CertificateAndSign`; `RootCACertStoreLocation` usage;
  `SecretManagement.BitWarden` integration (`Register-SecretVault`,
  `Unlock-SecretVault`, `Get-Secret`); direct Bitwarden CLI (`bw login`,
  `bw unlock`, `BW_SESSION`); and Wireshark SSL-key capture.
- [Secrets Plugin Architecture](SecretsPluginArchitecture.md) — _Describes Ace
  Commander._ Full April-2026 specification for consolidating two existing
  Secrets implementations (`ATAP.Utilities.Configuration.Secrets/` and
  `ATAP.Utilities.Configuration/Secrets/Shims/`) into a new
  `ATAP.Utilities.Secrets` family. Defines `ISecretsAbstract`,
  `ISecretsConfigurableAbstract`, `ISecretsOptionsAbstract`,
  `ISecretsPluginShim`, `SecretMapping` record, `SecretsRouter`,
  `BitwardenSecretsOptions` (`SessionEnvVarName` / `BwCliPath` / `Timeout` /
  `DefaultFieldName`), `BitwardenSecretsShim`, `BitwardenConfigurationSource`
  and `BitwardenConfigurationProvider`, and a `SecretsPluginShim` implementing
  `ILoadDynamicSubModules`.
- [Developer Musings — SecSub Design](ReviewedAndArchived/DeveloperMusings.md) (archived 2026-07-06) — _Describes Ace
  Commander._ Three "brainstorming" iterations of the Security Subsystem.
  Explains PowerShell SecretManagement limitations (single-vault and
  local-disk-only ACLs), then defines SCVP (Secure Cloud Vault Path), EMBs
  (Encrypted Master Passwords), SMVs (Secret Management Vaults), DECs (Data
  Encryption Certificates), the `SMEVInfo` custom type, and the AUMPs.txt
  mapping file.
- [Service Accounts and Bitwarden](ServiceAccountsAndBitwarden.md) —
  Sprint-0007 design and implementation guide for service accounts used by
  BuildMaster, ProGet, and other automation processes to access Bitwarden
  secrets. Covers `SvcBuildMaster` and `SvcProGet` service account setup,
  Bitwarden API key provisioning, and the `Get-SecretATAP` integration pattern
  for non-interactive service contexts.
- [Bitwarden Secrets Manager Access Token Runbook](Runbook-BitwardenServiceAccounts.md) —
  Operational checklist for service-account and interactive-user BWS project/key
  inventory, `bws` installation validation, ACL-protected DPAPI access-token
  provisioning, runtime validation, rotation, and troubleshooting. The current
  `ReadOnly` DPAPI baseline covers `whertzing` plus `SvcBuildMaster`, `SvcProGet`,
  `SvcSeq`, `SvcSQLServer`, and `SvcParityAudit` on `utat01` and `utat022`.
- [Service Accounts and Bitwarden — Alternatives Considered](ServiceAccountsAndBitwarden-AlternativesConsidered.md) —
  Design alternatives and trade-off analysis for service account Bitwarden
  access patterns evaluated in Sprint 0007.

---

## How to Produce a Software Product — Building, Versioning, Testing, Packaging, Publishing

_Teach / Tell how to create software._

- [Building](Building.md) — Solution-level build flow, `Directory.Build.props`
  and `Directory.Build.targets`, project-type GUID
  `{9A19103F-16F7-4668-BE54-9A1E7A4F7556}`, the `UpdateVersionIfNecessary` and
  `PrintBuildVariables` targets, `ATAP.Utilities.BuildTooling` (Net Full and
  .NetCore editions, Release / Debug), `NuGetLocalFeedPath`,
  `PublishAfterBuild`, Authenticode signing, imgbot, and PowerShell module
  packaging (Plaster / Catesta / Psake / Invoke-Build).
- **[HISTORICAL — file removed]** `BuildMaster-ProGet-CSharp-Package-Pipeline.md`
  — Superseded by [BuildMaster Pipeline Topology](BuildMaster-Pipeline-Topology.md).
  Covered the 5-stage OtterScript plan, five `nuget-*` feeds, NBGV labels, and
  `PROGET_ADMIN_API_KEY` retrieval. Content merged into the Topology doc in Sprint 0007.
- [MSBuild Binary Logging](MSBuild%20Binary%20Logging.md) — **8-line note.** Use
  of the `-bl` switch and the MSBuildStructuredLog viewer for diagnosing
  build issues.
- [C# Central Package Management](CSharp-Central-Package-Management.md) —
  Central package-management conventions and migration guidance for C# projects.
- [ADR: ZSandbox Ownership and Disposition](ADR-ZSandbox-Ownership-And-Disposition.md) —
  Accepted ownership and project-boundary decision for retained experimental code.
- [C# Packages — Build Process](CSharp-Packages-Build-Process.md) —
  Step-by-step C# package build flow. Also names the separate
  `Build\Invoke-RepoHealthGate.ps1` RepoHealth gate for shared MSBuild property
  checks that must run after restore and before pack/publish.
- [C# Packages — Test Process](CSharp-Packages-Test-Process.md) —
  C# package testing process and expected test artifacts, including the
  repo-wide `tests\RepoHealth` Pester gate that is intentionally outside
  package/module test discovery.
- [C# Packages — Pack and Push](CSharp-Packages-Pack-and-Push.md) —
  Packaging and publishing flow for C# packages.
- [C# Packages — Versioning](CSharp-Packages-Versioning.md) —
  Versioning policy for C# packages across sprint and release promotion.
- [PowerShell Modules — Build Process](PowerShell-Modules-Build-Process.md) —
  Build flow for repository PowerShell modules.
- [PowerShell Modules — Test Process](PowerShell-Modules-Test-Process.md) —
  Test flow for PowerShell modules and associated test artifacts.
- [PowerShell Modules — Pack and Publish](PowerShell-Modules-Pack-and-Publish.md) —
  Packaging and publishing flow for PowerShell modules.
- [PowerShell Modules — Versioning](PowerShell-Modules-Versioning.md) —
  Versioning strategy for PowerShell modules.
- [BuildMaster Pipeline Topology](BuildMaster-Pipeline-Topology.md) —
  Current BuildMaster topology and trigger strategy (including polling-based
  feed checks). Covers all four durable pipelines (C#, PowerShell, Release Bundle,
  Database), the ProGet feed family per pipeline, the full PowerShell automation
  surface, and the ProGet-polling integration.
  **[DEPRECATED cmdlets]** `Set-BuildMasterSprintVariables` and
  `Set-BuildMasterStableVariables` are deprecated as of Sprint 0007 and will be
  removed in Sprint 0008. Use `Set-BuildMasterApplicationVariables` instead.
- [Generated Diagram Pipeline](Generated-Diagram-Pipeline.md) —
  Runbook for rendering editable PlantUML, UML, and Draw.io sources into
  checked-in `_generated/diagrams` images with `Convert-DiagramsToImages`.
  Also records the PlantUML MCP relationship for interactive clients.
- [BuildMaster Install Runbook](BuildMaster-Install-Runbook.md) —
  Comprehensive installation, verification, and ongoing-configuration guide for
  the BuildMaster server. Covers application setup, raft strategy, application
  variables, ProGet API keys, and per-component smoke checklists. Updated in
  V4-G01 and V4-E09 for database pipeline applications
  (`ATAPUtilitiesDatabase`, `AceCommanderDatabase`).
- [BuildMaster Run-State Runbook](BuildMaster-Run-State-Runbook.md) —
  Operational guide for the build-id scoped `_generated/buildmaster/<BuildMasterBuildId>/`
  inter-stage state channel.
- [BuildMaster Plan Raft Sync Requirement](BuildMaster-Plan-Raft-Sync-Requirement.md) —
  Why a committed `.otter` change is not live until `Sync-BuildMasterPlans` runs, and how
  a stale raft plan silently hangs a stage forever on a hidden mandatory-parameter prompt.
  Includes the 2026-08-03 incident, a triage checklist, and fail-fast guidance.
- [Authenticode Signing and the MAX_PATH Constraint](Authenticode-Signing-MAX_PATH-Constraint.md) —
  Open defect: `Set-AuthenticodeSignature` fails with a misleading `UnknownError` on paths
  over 260 characters regardless of `LongPathsEnabled`. Affects long-named modules built
  from sprint worktrees.
- [Feed Protocol HTTP to HTTPS Migration](Feed-Protocol-HTTP-to-HTTPS-Migration.md) —
  Runbook for the ProGet/BuildMaster cutover to HTTPS after the `utat022` PKI change.
  Covers the four independent client registration surfaces (PowerShellGet v2,
  PSResourceGet, dotnet/NuGet sources, repo `NuGet.Config`), the required
  `localhost` to `utat022` host change forced by the certificate SAN, all 20 server
  feeds, strict-TLS verification, rollback, and the Avast TLS-interception caveat.
- [PowerShell-Module Pipeline -NoProfile Runbook](PowerShellModule-Pipeline-NoProfile-Runbook.md) —
  V4-B02 audit + policy of record: every settings lookup in the PowerShell-module
  plan/runner resolves under `-NoProfile` via explicit parameter, env var, or
  null-guarded default; the runner never calls `Resolve-ProGetFeedFromSettings` so it
  needs no `Set-NoProfileProGetFeedSettings` bootstrap. Pinned by
  `Plans/tests/PowerShellModule-5Stage.Tests.ps1`.
- [Release Bundle Pipeline](Release-Bundle-Pipeline.md) —
  Multi-stage release bundle execution model.
- [ReleaseBundle vs Database Package Architecture](ReleaseBundle-vs-DatabasePackage-Architecture.md) —
  Sprint-0007 decision record: database change packages promote through the
  `database-*` feed family independently of the Release Bundle; the Release
  Bundle consumes compatible database packages at deploy time. Authored V4-F01.
- [Release Branch and Manifest](Release-Branch-and-Manifest.md) —
  Rules for release branch creation and manifest generation.
- [Database Change Unit and Flyway Promotion](Database-Change-Unit-and-Flyway-Promotion.md)
  — Database change-unit lifecycle and promotion mechanics.
- [Database Package Artifact and Feed Decision](Database-Package-Artifact-And-Feed-Decision.md)
  — Sprint-0007 sprint-owner decision record: database change units ship as
  NuGet content packages through the five-feed `database-*` family
  (`database-experimental` / `-development` / `-integration` / `-qa` /
  `-stable`); package-id convention `<App>.Database`; version labels match
  the existing `Sprint` / `Alpha` / `Beta` / `QA` / _(stable)_ pattern;
  Universal Packages considered and rejected for pipeline consistency.
- [Database Package Ceiling File](Database-Package-Ceiling-File.md)
  — Defines `database-package-ceiling.json`, the source-controlled
  consumer-side ceiling file that caps the highest `database-*` feed a sprint,
  feature, integration, QA, release, or hotfix lane may consume.
- [Database Package Consumer Resolution](Database-Package-Consumer-Resolution.md)
  — How a consumer selects the correct `database-*` feed for an environment
  tier, respects `database-package-ceiling.json`, narrows by
  `compatibleAppPackageRanges`, and resolves a specific package version via
  `Install-Package` or `dotnet restore`. DBA2-T05 / V4-E11.
- [Database Package Compatibility](Database-Package-Compatibility.md)
  — How `compatibleAppPackageRanges` in the database package manifest
  constrains compatible application versions, how release bundles record
  the expected pairing, and how `Test-DatabasePackageCompatibility`
  validates it at promotion/deploy time. DBA2-T06 / V4-E12.
- [Database MultiDB Future Requirements](Database-MultiDB-Future-Requirements.md)
  — Forward-looking notes for multi-database scope deferred from
  Sprint 0007: AceCommander per-user database evolution, multi-stream
  databases, tenant-fanout migration orchestration, and tenant-level
  ceiling/rollback work. DBA2-T08 / V4-E16.
- [ATAPUtilities Instantiation Tables](ATAPUtilities-Instantiation-Tables.md)
  — Sprint 0012 design for Philote-backed organization, user, computer,
  repository, source-module, instantiation-version, and manifestation-artifact
  tables. Defines the source-ingestion and renderer contracts; Tasks 12.26.b-e
  implemented the read-only scanner, renderer, and v1/v2 manifestation evidence.

### Database/Documentation (implementation deep-reference)

- [`Database/Documentation/ReadMe.md`](../Database/Documentation/ReadMe.md)
  — Purpose and scope of the in-repo `Database/Documentation/` folder;
  links to the cross-cutting `SolutionDocumentation/` documents
  rather than restating them. DBA2-T09 / V4-E17.
- [`Database/Documentation/Index.md`](../Database/Documentation/Index.md)
  — In-folder inventory plus deep-link pointers into the
  `SolutionDocumentation/` documents the database pipeline depends on.
  Includes settings-key and Bitwarden secret-name conventions used by
  the database cmdlets. DBA2-T09 / V4-E17.

### DatabaseManagement.PowerShell/Documentation (per-cmdlet deep-reference)

- [`src/ATAP.Utilities.DatabaseManagement.Powershell/Documentation/ReadMe.md`](../src/ATAP.Utilities.DatabaseManagement.Powershell/Documentation/ReadMe.md)
  — Purpose and scope of the module's `Documentation/` sub-folder,
  summary of required env vars and Bitwarden secret-name patterns.
  Module root `ReadMe.md` and `INDEX.md` remain DBA1-owned. DBA2-T10 / V4-E18.
- [`src/ATAP.Utilities.DatabaseManagement.Powershell/Documentation/INDEX.md`](../src/ATAP.Utilities.DatabaseManagement.Powershell/Documentation/INDEX.md)
  — Per-cmdlet deep references (description, required env vars,
  Bitwarden secret names, example invocation) for the database-pipeline
  cmdlets in the module. Placeholder rows are included for
  `New-DatabasePreMigrationSnapshot`, `Restore-DatabaseFromSnapshot`,
  and `Test-DatabaseRollbackReadiness` until DBA1 lands them.
  DBA2-T10 / V4-E18.
  — Defines the `compatibleAppPackageRanges` field, NuGet range notation, release
  bundle pairing, the DB-C-01 deployment-block rule, and the
  `Test-DatabasePackageCompatibility` cmdlet. DBA2-T06 / V4-E12.
- [Legacy DatabaseBuildAndMigrateTasks Support Boundary](../src/ATAP.Utilities.DatabaseManagement.Powershell/Documentation/Legacy-DatabaseBuildAndMigrateTasks-Support-Boundary.md)
  — Closes the support-boundary story for the legacy Redgate / Phil Factor
  `DatabaseBuildAndMigrateTasks.ps1` task-script bundle. Lists every legacy
  capability as supported (covered by current cmdlets), deferred (named
  replacement planned, priority P1-P4), or retired (will not be rebuilt),
  and documents the reactivation procedure.
- [Sprint Infrastructure Naming](SprintInfrastructure-Naming.md) —
  Naming conventions for sprint-scoped infrastructure resources, including
  BWS-owned dotted `dbConnectionString.*` keys for Development and Experimental
  database connection strings.
- [Production and Tooling Overview](Production-and-Tooling-Overview.md) —
  Cross-cut overview of production-facing flows and supporting tooling.
- [Immutable Build Strategy](Immutable-Build-Strategy.md) —
  Primary strategy document for immutable build and promotion flows.
- [version.json as Promotion Ceiling](VersionJsonAsCeiling.md) —
  Explains `CurrentTier` versus `CeilingTier` and the stage-skip guard.
- [Critical Analysis of Immutable Build Strategy](ReviewedAndArchived/CriticalAnalysisOfImmutableBuildStrategy.md) (archived 2026-07-06)
  — Risk and trade-off analysis of the immutable strategy.
- [PowerShell Script Consolidation](PowerShell-Script-Consolidation.md) —
  Consolidation plan for overlapping automation scripts.
- [Worktree Source-of-Truth Inventory](Worktree-Source-of-Truth-Inventory.md) —
  Worktree ownership and source-of-truth inventory for sprint workflows.
- [Sprint-0006 5-Tier Retrospective](ReviewedAndArchived/Sprint-0006-5Tier-Retrospective.md) (archived 2026-07-06) —
  Lessons learned and follow-up actions from sprint 0006.
- [Long Developing Features](Long-Developing-Features.md) —
  Tracking document for long-running feature efforts.
- [CS0246 Errors — Type Not Found](CS0246-Errors-TypeNotFound.md) — Catalog of
  compile errors on branch `65-migrate-central-package-management` (dated
  2026-03-03), grouped by missing type: `DiFixture` (16), `ISerializerOptions`
  (14), `TestData<>` (14), `DiFixtureNInject` (4), `IPhilote<>` (4),
  `ConfigurableFixture` (2), `Dictionary<,>` (2), `IDynamicSubModulesInfo` (2),
  `ILoadDynamicSubModules` (2), `IModel/RabbitMQ` (2), `SerializationFixture`
  (2), `SqlFunction` (2), `SqlFunctionAttribute` (2), with prioritized
  resolutions.
- [Testing Methodology](TestingMethodology.md) — **Pester-only (62 lines).**
  Pester layout with `RegularTests` and `RequiresNewProcess` directories, the
  `_NewProcess` suffix convention, and Pester `-Tag` / `-RunInNewProcess`
  usage. Does not currently cover xUnit / C# test conventions.
- [Refactoring — Phase 1 Discovery Report](ReviewedAndArchived/Refactoring-Phase1-Discovery-Report.md) (archived 2026-07-06)
  — Dated 2026-02-28, branch `60-update-overall-systems-documentation`.
  22 candidate groups (16 safe, 6 "Both"-type conflicts). Conflict resolution
  uses `git mv` to rename conflicting parents to `*.Model`. Specific
  conflicts listed: `ATAP.Services.GenerateProgram`, `ATAP.Utilities.Loader`,
  `ATAP.Utilities.MessageQueue`, `ATAP.Utilities.Persistence`,
  `ATAP.Utilities.Philote`, `ATAP.Utilities.Serializer`.
- [Tasks ToDo — Plugin Work](ReviewedAndArchived/Tasks-ToDo-For-Plugin.md) (archived 2026-07-06) — **702-line**
  50-task plan across 5 agents and 6 phases (0–5), on branch
  `94-sprint-0004-work-items`, dated 2026-04-05. Includes full dependency
  graph, task matrix, and agent workload table: Tasks 1–5 Loader (Agent 1),
  6–13 Secrets base (Agent 2), 14–15 Plugin tests (Agent 5), 16–19
  PluginFamily (Agent 1), 20–28 Bitwarden shim + Secrets facade (Agents 3, 4),
  29–37 Plugin integration + tests (Agents 4, 5), 38–46 PluginDemo +
  integration tests (Agents 4, 5), 47–50 cleanup + PowerShell (Agents 1, 3).
- [Plugin Creation Prompt](ReviewedAndArchived/Plugin-Creation-Prompt.md) (archived 2026-07-06) — **78 lines, an
  authorial brief, not a specification.** The prompt the user issued to
  generate the plugin-architecture and SecretsPluginArchitecture documents.
  Lists the plugin-capable families (Secrets / MessageQueue / Serializer /
  Testing), demands no-ServiceStack implementation, requires zeroing of
  sensitive data on unload and deep-copied DTOs across the plugin boundary,
  and calls for a PowerShell-consumable design plus a demo console app.
- [Blog Post 001](BlogPost001.md) / [Daily Dev Log](DailyDevLog.md) — **Near
  duplicates.** Goals and running log, including the ACE co-operative
  non-anonymous-internet idea and automation task sketches (ski reservations,
  photo curation). Both files share roughly the same content with minor
  formatting differences.
- [Example — Rule Instantiation: Hello World](Example.RuleInstantiation.HelloWorld.md)
  — T-SQL seed showing `Rule` / `RuleInstantiation` / `RuleInstantiationBinding`
  (with `RelativePath`, `FileName`, `FileContent` bindings) producing
  `Program.cs`, `HelloWorld.cs`, and `HelloWorld.csproj` under
  `Database/_generated/HelloWorld`. Also shows the Philote-seeding pattern
  and the expected rendered contents of each generated file.
- [DocFX TOC](toc.yml) — **12-line stub.** Lists only ReadMe, GettingStarted,
  Building, VisualStudioExtensions, Attribution, and Contributing — badly out
  of date with the current document set.

---

## Rules Compendium

_Teach / Tell how to create software._ These are the authoritative
language-scoped catalogs of Rule Primitives that power the RRSBS
(Rules, Rule Sets, Build Sets) code-generation framework. Every primitive,
rule, rule set, and build set in these documents carries a stable
`IPhilote<GUID>` identifier, keyed back into the Ace Commander Instantiations
database. Each primitive maps to a single BNF non-terminal in the target
language's grammar; an instantiation binds primitive inputs to specific
values and renders deterministic output text.

- [Rules Compendium — C#](Rules%20Compendium.CSharp.md) — C# 14 / .NET 10 Rule
  Primitives mapped to BNF productions; attributes, XML-doc, DI registration,
  and project-file conventions. (~1,076 lines.)
- [Rules Compendium — SQL](Rules%20Compendium.SQL.md) — T-SQL Rule Primitives
  for schema objects, Flyway migrations, and stored-procedure conventions.
  (~1,158 lines.)
- [Rules Compendium — PowerShell](Rules%20Compendium.Powershell.md) — Rule
  Primitives for module layout, advanced functions, PSFramework logging,
  Pester testing, and PowerShell conventions. Includes rule sets added in
  sprint 0006: **Logging** (`Write-PSFMessage` canonical template, external-call
  tags `RestCall` / `WebRequestCall` / `InvokeExpressionCall` /
  `InvokeCommandCall`, GELF/SEQ named-instance pattern); **Error Handling**
  (mandatory try/catch/finally template with `-ErrorAction Stop` and
  `Write-PSFMessage -Level Error`); **Input Validation**
  (`[string]::IsNullOrWhiteSpace` / `ValidateScript` patterns); and a
  **Debugging Tools** appendix (`Wait-Debugger`,
  `[System.Diagnostics.Debugger]::Break()`, `Set-PSBreakpoint -Command`).
  **~2,063 lines.**
- [Rules Compendium — MSBuild](Rules%20Compendium.MSBuild.md) — Rule Primitives
  for `.props` / `.targets`, Directory.Build files, custom tasks, and solution
  orchestration. (~858 lines.)
- [Rules Compendium — Manim](Rules%20Compendium.Manim.md) — Defines the
  `ManimScene` RulesKind and its Rule Primitives for the
  `ATAP.Utilities.ManimVideoGenerator` subsystem and the AceCommander bolt-on
  module. Cross-references the BNF in
  `src/ATAP.Utilities.ManimVideoGenerator/Documentation/Overview.md`
  (moved from `_Planning/Explainers/0200`, 2026-07-06). (~345 lines.)
- [Rules Compendium — Path](Rules%20Compendium.Path.md) — Rule Primitives for
  Windows filesystem path syntax, including reserved names (`CON`, `PRN`,
  `AUX`, `NUL`, `COM1–COM9`, `LPT1–LPT9`), `MAX_PATH` (260 / 32,767 with
  `\\?\` prefix), trailing-character restrictions, and case-insensitivity
  semantics. (~399 lines.)
- [Rules Compendium — Snippet](Rules%20Compendium.Snippet.md) — Rule
  Primitives for VS Code snippet JSON/JSONC: prefix / body / description
  properties, placeholder substitution, tab stops, and language-neutral
  metadata. (~1,147 lines.)
- [Rules Compendium — OtterScript](Rules%20Compendium.OtterScript.md) —
  Rule primitives and conventions for BuildMaster OtterScript automation.
- [Rules Compendium — AgentText](Rules%20Compendium.AgentText.md) —
  Agent/instruction text kind for loading SharedVSCode `.ai` sources into
  RRSBS records and rendering Claude, Codex, and GitHub Copilot adapters.
- [Rules Compendium — Markdown](Rules%20Compendium.Markdown.md) —
  Task 13.85's exact-byte CommonMark/GFM subset, Kind ID 10, 14 primitives,
  27 inputs, approved composition, grammar, frozen corpus hashes, and verified
  InstantiationVersion 2 deployment and manifestation.
- [Rules Compendium Template](Rules-Compendium-Template.md) —
  Template for creating new language-specific Rules Compendium documents.

---

## Ace Commander — Application Description

_Describes how Ace Commander will work (not how to build software in general)._

- [Task 13.79 — Corrected ATAP.org InstantiationVersion 1](Task-13.79-Instantiation-V1.md)
  — Approved immutable ordered-source-line model, version-1 seed graph,
  exact-byte reconstruction contract, and rehearsal evidence.
- [Task 13.80 — Instantiation Query, Ingestion, and Execution](Task-13.80-Instantiation-Execution.md)
  — immutable snapshot loading, read-only version proposals, safe exact-byte
  manifestation, provenance, and database-to-temporary-root evidence.
- [Task 13.82 — Instantiation Package Rehearsal](Task-13.82-Instantiation-Package-Rehearsal.md)
  — immutable 0.1.1 bundle identity, exact fresh/current Flyway rehearsals,
  adversarial review, and operator hash approval.
- [Task 13.83 — Instantiation Deployment and Manifestation](Task-13.83-Instantiation-Deployment-and-Manifestation.md)
  — approved ExpWhertzing migration, deployed-state verification, separately
  approved exact five-entry filesystem manifestation, and provenance evidence.

- [Architecture Overview](architecture-overview.md) — 2026-03-15 automated
  survey of the ATAP.Utilities repository in its role as the computational
  and building core of Ace Commander. Inventories Core Utility Libraries
  (Serializer, Philote, StronglyTypedId, Persistence, GraphDataStructures,
  ComputerInventory, CryptoCoin/Miner, Configuration.Extensions,
  GenericHost.Extensions, Logging, ETW, MessageQueue, Loader,
  GenerateProgram, Tags, FileIO, DatabaseManagement, Gmail, FinancialAPI,
  etc.), Service Adapters (ConsoleMonitor, FileSystemWatchers,
  TcpWithResilience, Timers, GenerateProgram), Console apps, PowerShell
  modules, the `ATAPUtilities` SQL Server database, MSBuild tooling, the
  `ATAP-AiAssist` VS Code extension, and DocFX/PlantUML/Draw.io docs
  infrastructure. (328 lines.)
- [Module Catalog](Module%20Catalog.md) — Ace Commander module catalog v0.9
  (2026-02-22 baseline, change-controlled). Covers CEMA Core
  (rules/rule-sets/build-sets/instantiations with bi-temporal history),
  Module Lifecycle & Assembly, Data Analysis & Visualization, Photos / Media
  / Image Packages (including watermarking, Hydrus ingestion, remote photo
  hosting, time-based media generation), Tags (upgradeable taxonomy),
  Specialized Image Classifiers (face recognition, wildflowers), Outdoor /
  Routes / GPX, and Inter-instance Sharing & Sync. Section 3.3 adds VS Code
  C# build configuration, multi-project NuGet aggregator patterns, and the
  detailed Bitwarden-CLI / PowerShell SecretManagement integration notes
  (CI/CD headless unlock, VS Code BW_SESSION inheritance, WSL2, Docker) and
  WSL2 runtime environment (install, drive mounting, networking, Ansible,
  Docker). (1,175 lines.)
- [AI on WSL2 Ansible Docker and Bitwarden](ReviewedAndArchived/AI%20on%20WSL2%20Ansible%20Docker%20and%20Bitwarden.md) —
  Perplexity.ai Q&A transcript (7 exchanges). Covers: WSL2 install and
  `/mnt/{c,d,e}` DrvFs auto-mount; Windows↔WSL2 bidirectional networking;
  Ansible install and PowerShell-driven playbook generation on Windows;
  Docker inside WSL2 with APIs callable from .NET and PowerShell;
  Ubuntu-24.04 as recommended distro; Bitwarden CLI (`bw`) in Ubuntu for
  secrets access and `BW_SESSION` auto-creation at WSL login via a pwsh
  profile; why CLIXML is unsuitable for WSL unlocking. Material overlaps
  with Module Catalog §3.3.10; primary value is the Bitwarden
  WSL/Docker patterns. (706 lines.)
- [Generic Plugin Architecture](GenericPluginArchitecture.md) — **761-line
  full specification (April 2026).** Goals (dual consumption, plugin
  families, hot-swap and collectible unload, boundary security, observable
  `IData`, configuration layering, PowerShell compatibility); explicit
  non-goals (no ServiceStack, no Redis, no UI-framework mandate). Defines
  plugin families (Secrets, Serializer, MessageQueue, Testing), the shim
  pattern, `IPluginMetadata`, `PluginState` lifecycle, `IPluginShim<T>`,
  `IPluginFamily<T>`, collectible `AssemblyLoadContext`, `IAssemblyLoader`,
  `IPluginData`, `IPluginConfigStore`, the Ace legacy mapping, and the
  PowerShell cmdlet-wrapper pattern.
- [Library and App Package Distribution Overview](Library%20and%20App%20Package%20Distribution%20Overview.drawio)
  — Diagram of how ATAP.Utilities packages flow from source through the
  five-feed pipeline to consumers.
- [Package Lifecycles Over Time](Package%20Lifecycles%20Over%20Time.drawio) —
  Diagram of package promotion through the 5-tier feed pipeline across time.
- [TheBigIdea](TheBigIdea.drawio) — Concept-level sketch of the Ace Commander
  vision.
- [Users](Users.drawio.svg) — Diagram of user roles and their interactions
  with Ace Commander.
- [Windows Library and App Packages for Multiple Platforms and Runtimes](Windows%20Library%20and%20App%20Packages%20for%20Multiple%20Platforms%20and%20RuntImes.drawio)
  — Diagram mapping packages across target platforms and runtime variants.
  (Note: the on-disk filename is `RuntImes` with a capital **I**.)
- [Windows Packages](Windows%20Packages.drawio) — Windows-specific packaging
  topology diagram.
- [architecture-overview (diagram)](architecture-overview.drawio) — Visual
  companion to the architecture-overview document.
- [SW Production Diagrams](SWProductionDiagrams.drawio) —
  Supplemental software-production diagram set.

---

## Historical: AI-Generated Repository Snapshots

_These documents are AI-generated point-in-time snapshots retained as historical
artifacts. They are superseded by the living documents listed above and should
not be used as references for the current codebase._

- [AI Conversations](AI%20Conversations.md) —
  Curated notes and summaries from AI-assisted repository work sessions.
- [Reviewed and Archived AI Notes](ReviewedAndArchived/) —
  Archived AI-generated materials retained for historical context, including
  [AI on WSL2 Ansible Docker and Bitwarden](ReviewedAndArchived/AI%20on%20WSL2%20Ansible%20Docker%20and%20Bitwarden.md)
  and other prior assistant artifacts.
