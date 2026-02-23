# Ace Commander – Module Catalog v0.4

**Status:** Baseline (change-controlled)
**Supersedes:** Module Catalog v0.3
**Date:** February 22, 2026
**Change:** Section 2.4 expanded into subsections covering Claude Code CLAUDE.md configuration hierarchy (multi-project repo pattern), AI model selection strategy (Opus 4.5 vs Sonnet 4.5 for C#/.NET/PowerShell), and Copilot/Claude usage-limit awareness and optimization.

---

## Section 1: User-Facing Modules

### 1.1 CEMA Core (Engineering/Configuration)

| Capability              | Description                                                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Rule authoring/storage  | Rules (code, compiled artifacts, visual/text constructs, formulas), versioning, metadata, and composition                                        |
| Rule Sets               | Curated collections of rules; parameterization; reuse across builds                                                                              |
| Build Sets              | Assemble Rule Sets into a buildable Bill of Materials (BOM) definition for an Installation (generic: hardware BOM, system-of-systems BOM, SWBOM) |
| Instantiations (assets) | Represent real-world instances of an Installation (serial number, hostname, rack address, data center address, etc.)                             |
| Time modeling           | Bi-temporal history for Rules/RuleSets/BuildSets/Installations/Instances (Valid-Time + Transaction-Time)                                         |
| Change tracking         | BOM revisions, instance growth/upgrades/repairs over time, baselines/snapshots, and "as-of" queries                                              |

---

### 1.2 Module Lifecycle & Assembly (Ace Commander "build fabric")

| Capability          | Description                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Module registry     | Store software components and artifacts, and "assembly rules" for libraries/executables                             |
| Build orchestration | Drive the .NET build pipeline and test execution for modules; produce versioned artifacts                           |
| Wiring rules        | Declaratively connect modules and define data/work flows between them                                               |
| Formula engine      | Formula rules with stored value vs recommended value, "dirty" indicator, and "used non-recommended terms" indicator |

---

### 1.3 Data Analysis & Visualization

| Capability                | Description                                                                                                      |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Dataset module            | Define datasets from SQL queries/views, formula-derived datasets, imported files                                 |
| Visualization spec module | Save/share chart/dashboard definitions as versioned rules                                                        |
| Dashboard module          | Compose multiple visuals, filtering, drill-down, exports (initially "spec + data binding," then image/PDF later) |
| Web-to-chart workflows    | Take extracted datasets and generate visuals                                                                     |

---

### 1.4 Photos, Media, and Image Packages

| Capability                  | Description                                                                                                                                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image library               | Ingest, store, dedupe, organize photos (local-first; later sync)                                                                                                                                                  |
| Image packages              | Bundle raw images + metadata + derived artifacts (thumbnails, tags, classifiers, share payloads)                                                                                                                  |
| Photo prompts               | Context-aware reminders (group photo at trip start/end; "take a picture at peak/POI")                                                                                                                             |
| Remote photo hosting        | Host photos on a backend and return stable URLs so external sites (blog, social) can embed images by link rather than hosting locally; one canonical image host; render/serve elsewhere on demand                 |
| Hydrus integration          | Ingest photos into Hydrus for first-pass categorization as part of the photo management workflow                                                                                                                  |
| Watermarking                | Generate watermarked derivative images for publishing/sales; package image sets for online sale ("productization" of image packages)                                                                              |
| Time-based media generation | Generate time-ordered collections driven by photo timestamps; e.g., time-lapse seasonal collections of a flower species across spring/summer/fall; montages of a person's face filtered by date and identity tags |

---

### 1.5 Tags (Upgradeable Taxonomy)

| Capability                     | Description                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------- |
| Tagging core                   | Tags, tag assignments, confidence, provenance ("user," "classifier," "import")  |
| Tag hierarchy module (upgrade) | Parent/child taxonomies, synonyms, rules-based tag propagation, "views" of tags |
| Tag governance                 | Versioning and migrations of tag schema/ontology over time                      |

---

### 1.6 Specialized Image Classifiers (Plugin ML)

| Capability                     | Description                                                                                                                                                                               |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Classifier training            | Create user-specific classifiers (e.g., "my friends," "my gear," "trail signs," "ski day")                                                                                                |
| Inference                      | Propose tentative tags with confidence scores and explanations/provenance                                                                                                                 |
| Safety/privacy controls        | Local-only training/inference option; opt-in sharing of models                                                                                                                            |
| Wildflower-focused classifiers | Specialized classifiers for wildflower species and plant parts (leaves, buds, stems, etc.), including mapping to both common names and scientific names, capture location, and date taken |
| Face recognition classifier    | Train a model to recognize family members by face; scan the full photo library and tag each photo with identified person(s); preserve/add metadata including location and date            |

---

### 1.7 Outdoor / Routes / GPX

| Capability        | Description                                                                                                      |
| ----------------- | ---------------------------------------------------------------------------------------------------------------- |
| GPX import/export | Routes, tracks, waypoints; attach metadata and photos                                                            |
| Trip planning     | Planned hikes/trips, checklists, reminders, itinerary scaffolding                                                |
| Stats module      | Mileage, elevation gain (later), averages, streaks, per-season summaries, ski records                            |
| Tracking triggers | Detect "started hike" using GPS + exertion; optional launch of a third-party tracker app (AllTrails, Gaia, etc.) |

---

### 1.8 Inter-instance Sharing & Sync

| Capability          | Description                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| Near-field exchange | Share routes/photos directly between devices nearby (pairing + approval + encryption)            |
| Cloud sync          | Encrypted blob sync (ciphertext storage), multi-device, conflict handling                        |
| Share packages      | Export/import bundles (routes + photos + tags + selected stats), with time-bounded links/invites |

---

### 1.9 Social / Friends / Check-ins (Privacy-first)

| Capability               | Description                                                                                                                                                                   |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Friend graph             | Private, encrypted representation of connections and groups (family/friends)                                                                                                  |
| Messaging / coordination | Share trip plans, routes, photos, check-ins                                                                                                                                   |
| Location sharing         | Explicit, time-bounded live share; minimize stored history; per-recipient permissions                                                                                         |
| Personal website section | Publish/share personal maps, trail maps, AllTrails links, and ski records as a website section where family/friends can check in and view shared content                      |
| Technical blog           | Publish a technical blog about the stack/code being built; pulls from the same data stores and image host as the rest of the application; blog embeds images via hosted links |

---

### 1.10 Deals / Web Scraping

| Capability  | Description                                                                |
| ----------- | -------------------------------------------------------------------------- |
| Deal finder | Scrape/search web for best deals; store extracted price + link + timestamp |
| Alerting    | Thresholds, watchlists, "notify me under $X," seasonal deal patterns       |

---

### 1.11 Calendar & Seasonality

| Capability           | Description                                                                                               |
| -------------------- | --------------------------------------------------------------------------------------------------------- |
| Calendar integration | Read/write events; map internal "suggestions" to external calendar objects                                |
| Seasonality rules    | Suggest activities by time-of-year/location (e.g., "October aspen colors"), auto-propose calendar entries |
| Planning notes       | User notes become structured intents that can generate suggestions/tasks/events                           |

---

### 1.12 Email Import (Gmail Takeout) + Pattern Matching

| Capability              | Description                                                                                                        |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Gmail Takeout ingestion | Parse exported mail archives into a local searchable store                                                         |
| Pattern matching        | User-defined rules/regex/classifiers to extract signals (receipts, reservations, confirmations, shipment tracking) |
| Cross-linking           | Connect extracted entities to trips, purchases, deals, and calendar suggestions                                    |

---

### 1.13 Voice-to-Action Assistant

| Capability                                      | Description                                                                                                                                                                                                                    |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Voice → transcription → AI planning → execution | Takes voice input, transcribes to text, sends to one or more AI engines, receives a step-by-step plan using Ace Commander's own module capabilities, executes those steps automatically, and presents results back to the user |
| Voice note capture                              | Capture voice notes on mobile and associate them with concurrent events (photos, GPS location, timestamps)                                                                                                                     |

---

### 1.14 Timestamp-based Note↔Photo Auto-linking

| Capability                 | Description                                                                                                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Automatic association rule | Link a dictated note to the photo taken at the same time on the same device, using timestamp proximity as the linking key                                                                  |
| Cross-module linkage       | Notes/Voice module + Photos module share a timestamp index so that any note, photo, or GPS track recorded within a configurable time window are automatically grouped and cross-referenced |

---

### 1.15 Photography Monetization Workflow

| Capability          | Description                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| End-to-end workflow | Ingest via Hydrus → first-pass categorization → classifier tagging (species, plant parts, common/scientific names, location, date) → watermark derivation → package into sets → publish/sell online |
| Sales packaging     | Assemble tagged, watermarked image sets into purchasable products for online sale                                                                                                                   |

---

## Section 2: Third-Party Interoperability Modules

### 2.1 Smart Home Hub Integration

| Capability                    | Description                                                                                                                                                            |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Smart home connector(s)       | Integrate with a hub ecosystem (initial target: Home Assistant-style hub integration), ingest sensor events, control devices                                           |
| Presence detection            | Detect "person entered home" from sensors/phones; trigger workflows                                                                                                    |
| Guest/tradesperson onboarding | Homeowner "introduces" a person, assigns them to a role group, and grants time-limited permissions with configurable scope (capability + device/area scope + duration) |

---

### 2.2 Wearables / Health Sensors

| Capability         | Description                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------- |
| Wearable providers | Connect to Fitbit/smart watches; read heart rate and (optionally) blood oxygen when available |
| Exertion inference | Combine wearable telemetry with GPS to detect activity starts/stops and safety anomalies      |

---

### 2.3 Web Search / Retrieval

| Capability        | Description                                                                                 |
| ----------------- | ------------------------------------------------------------------------------------------- |
| Search connector  | Run web queries and store results as cited sources                                          |
| Extractors        | Turn web pages into structured datasets suitable for analysis/visualization                 |
| Media referencing | Store links/metadata for external media; avoid redistributing copyrighted frames by default |

---

### 2.4 VS Code Multi-AI Extension

#### 2.4.1 Core Extension Capabilities

| Capability                    | Description                                                                                                                                                                                                                                  |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Multi-AI panel                | A VS Code extension that sends one question simultaneously to multiple major AI chat engines via their APIs, receives all answers, and displays them side-by-side (e.g., four panes) so the developer can compare and select the best answer |
| Apply-to-code action          | Take the chosen AI result and apply it back into the active workspace as a controlled patch (single file or multi-file change set)                                                                                                           |
| ESM-first extension guideline | The extension and its toolchain are built targeting ECMAScript modules (ESM), aligned with the VS Code team's active ESM support rollout                                                                                                     |
| Extension bundling pipeline   | A dedicated bundler configuration (esbuild or equivalent) for TypeScript-to-JavaScript transpilation and bundling of the VS Code extension for distribution                                                                                  |

#### 2.4.2 Claude Code Configuration (CLAUDE.md Hierarchy)

Claude Code reads layered `CLAUDE.md` instruction files at multiple scopes. The `.github/instructions/*.instructions.md` pattern is a **GitHub Copilot** convention; Claude Code does not natively load those files. The supported hierarchy is:

| Scope              | File path                                  | Purpose                                                                                                                      |
| ------------------ | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Global (user)      | `~/.claude/CLAUDE.md`                      | Applies to all Claude Code sessions on the machine; user-wide defaults and preferences                                       |
| Repo root          | `<repo-root>/CLAUDE.md`                    | Shared repo-wide conventions, build commands, architecture notes; loaded for all work in the repo                            |
| Per-project folder | `<repo-root>/<project>/CLAUDE.md`          | Project-specific stack, commands, coding standards; loaded automatically when working with files in that project's directory |
| Personal overrides | `CLAUDE.local.md` (any level, git-ignored) | Machine- or user-specific overrides that are not committed to source control                                                 |

**Multi-project repo guidance:** For this repository (monorepo with many project subfolders and a VS Code multi-root workspace), the recommended pattern is:

- One `CLAUDE.md` at the repo root describing shared conventions (build discipline, naming, logging patterns).
- One `CLAUDE.md` inside each project folder describing that project's specific stack, key commands, and standards.
- Claude Code will automatically apply the root file plus the relevant project-level file when working in that project's files.

#### 2.4.3 AI Model Selection Strategy

For C#, PowerShell, and .NET development specifically:

| Model             | Best used for                                                                                                                                                           | Notes                                                                                                    |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Claude Sonnet 4.5 | Inner-loop / daily coding: quick edits, C# and PowerShell function refactors, test scaffolding, iterative REPL-style changes in VS Code                                 | Optimized for cost + speed; ~90–95% of Opus quality for routine work; preferred default model in VS Code |
| Claude Opus 4.5   | Large multi-file refactors across several projects, complex architecture decisions, framework migrations, multi-step design tasks where correctness trumps cost/latency | Most capable model; stronger on long-horizon coding tasks and benchmarks; reserve for gnarlier work      |

#### 2.4.4 Copilot / Claude Usage Limits

When Claude is routed through GitHub Copilot (as a chat agent or via Claude Code actions), usage is governed by Copilot's **premium request quota** (separate from Anthropic's own model limits).

| Topic                        | Detail                                                                                                                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Limit message                | "You've hit your limit · resets 12pm (America/Denver)" — Copilot premium-request quota exhausted; Claude requests blocked until shown reset time                                            |
| Two overlapping limit layers | Anthropic-side model caps (per account/plan) and Copilot-side premium-request buckets; the effective limit is whichever is exhausted first                                                  |
| Optimization — batch tasks   | Combine several related tasks in one Claude chat instead of many small prompts; iterate within the same thread rather than opening new chats                                                |
| Optimization — model routing | Set the VS Code default model to a non-premium model (GPT-based Copilot); switch to Claude manually only for complex C#/.NET refactors, deep code reviews, or multi-project reasoning tasks |
| Optimization — plan tier     | Higher-tier Copilot plans (Enterprise/Pro+) offer larger or more generous premium-request allocations; consult the org admin if limits are hit frequently                                   |
| Fallback when limit hit      | Switch to another Copilot model temporarily, or use the Claude web app / API directly where the plan and quota are managed explicitly                                                       |

---

### 2.5 Home Fleet Management (Ansible)

| Capability                             | Description                                                                                                                                                                                                                                |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ansible-based home computer management | Manage configuration across all home computers using Ansible playbooks; ensure required software is installed, correct settings are applied, and environment variables/process environment are configured consistently across all machines |
| Continuous distribution pipeline       | A CI/CD-style "continuous distribution" approach for home systems so changes to the fleet configuration are applied automatically and verifiably                                                                                           |

---

### 2.6 Calendar Provider Connectors

| Capability                      | Description                                           |
| ------------------------------- | ----------------------------------------------------- |
| Microsoft 365/Outlook connector | Read/write calendar events via Microsoft Graph API    |
| Google Calendar connector       | Planned                                               |
| iCalendar (.ics) export/import  | Baseline interchange format for any calendar provider |

---

### 2.7 Tracking App Connectors

| Capability          | Description                                                                   |
| ------------------- | ----------------------------------------------------------------------------- |
| AllTrails connector | Store AllTrails links; launch app via deep link/URI when hike detection fires |
| Gaia GPS connector  | Similar launch and data-exchange integration                                  |

---

## Section 3: Internal / Platform Modules

### 3.1 Security, Privacy, and Policy Engine

| Capability                    | Description                                                                                                                         |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Threat model baseline         | Design to protect friend graph + location history against powerful adversaries including authoritarian governments                  |
| Encryption & key management   | Local encryption, E2EE sharing primitives, secure key storage, rotation, and recovery options                                       |
| Data minimization & retention | Per-module retention defaults; fine-grained "pin" vs "expire" controls; configurable location history resolution and expiry windows |
| Consent and auditing          | Explicit consent flows, permission grants with duration, audit logs (with careful privacy boundaries)                               |

---

### 3.2 Marketplace, Packaging, and Trust

| Capability               | Description                                                                      |
| ------------------------ | -------------------------------------------------------------------------------- |
| Module packaging format  | Manifests, dependencies, capabilities, required permissions                      |
| Secure marketplace       | Signing, verification, reputation, reviews, update channels, rollback            |
| Sandboxing & permissions | Module capability declarations; runtime policy enforcement; least-privilege APIs |

---

### 3.3 Dev/Build/Repo Toolchain (for module developers)

**Infrastructure management model:** Infrastructure as Code (IaC). All build agents and developer machines are managed declaratively; configuration drift is not permitted.

**Early development runtime:** Ansible is executed from a WSL2 environment; workloads are containerized where practical.

#### 3.3.1 Toolchain Components

| Tool / Capability      | Role                   | Description                                                                                                                                                                                            |
| ---------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ansible                | IaC / provisioning     | Ensures all required build/test/package tools are installed on every organizational computer; enforces consistent configuration, settings, and environment prerequisites across all build environments |
| Jenkins                | Continuous Integration | Automation server that executes CI pipelines automatically to validate every code change (build + test); drives the module build pipeline and test execution                                           |
| Inedo BuildMaster      | Release automation     | Automates release orchestration and final packaging; integrates with ProGet to track packages/dependencies as part of builds (scanning outputs, publishing dependency metadata)                        |
| Inedo ProGet           | Package governance     | Organization's package source of truth; ensures only approved versions of dependencies and tools are consumed via approval workflows and controlled access; supports vulnerability scanning features   |
| .NET build integration | Build                  | Compile/test/package C# modules; PowerShell scripting modules where appropriate                                                                                                                        |
| Database migrations    | Schema management      | Flyway-managed versioned migrations and repeatable DB objects (views/procs/functions)                                                                                                                  |

#### 3.3.2 Responsibility Summary

| Tool        | Primary Responsibilities                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------------------- |
| Ansible     | Provision build agents; install tooling; enforce environment consistency across all machines                  |
| Jenkins     | Validate every code change via automated build + test pipelines                                               |
| BuildMaster | Orchestrate releases; package artifacts; publish dependency metadata to ProGet                                |
| ProGet      | Govern approved package versions; gate dependency consumption; provide vulnerability scanning and audit trail |

---

### 3.4 GPS / Location Services (Platform)

| Capability                | Description                                                                                                                            |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Continuous GPS monitoring | Record device GPS coordinates on every device Ace Commander runs on, with configurable sampling interval and battery-aware throttling  |
| Activity detection        | Combine GPS movement patterns with exertion (wearable) signals to classify activity state (stationary, walking, hiking, driving, etc.) |
| Location privacy controls | Aggressive default expiry for precise tracks; opt-in pinning; per-share granularity controls                                           |

---

## Appendix A: Corporate Entities

### ATAP.Utilities.org (Nonprofit, FOSS)

**Mission (v0.1)**
ATAP.Utilities.org exists to create and steward open-source software and reference data — especially the ATAP.Utilities framework and foundational Ace Commander modules — for the public good, governed transparently and developed in collaboration with a global contributor community.

**Vision (v0.1)**
A world where trustworthy, community-governed open-source building blocks and reference data make advanced engineering and personal computing capabilities accessible to everyone.

---

### Ace Commander, Inc. (For-Profit)

**Mission (v0.1)**
Ace Commander, Inc. exists to deliver and operate the Ace Commander product — combining open foundations (including ATAP.Utilities modules) with proprietary integrations, user experience, and managed services — so customers can securely customize, deploy, and evolve a modular personal/enterprise assistant across devices and cloud backends.

**Vision (v0.1)**
A future where every person and organization can run a secure, privacy-preserving, highly customizable "commander" that coordinates their devices, data, and communities across platforms.

---

## Appendix B: Tech Stack Baseline

| Layer                       | Technology                                                                                                                                    |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Primary language            | C# (.NET, latest version; backwards-compatible libraries where feasible)                                                                      |
| Scripting                   | PowerShell                                                                                                                                    |
| Database                    | Microsoft SQL Server (Developer Edition for dev/test; Express or hyperscaler-hosted for production)                                           |
| Schema/migration management | Flyway (free edition, Redgate); versioned migrations + repeatables for views/procs/functions + repeatables for slowly-changing reference data |
| Package management          | ProGet (Inedo, free edition initially)                                                                                                        |
| Continuous Integration      | Jenkins (automation server; executes build + test pipelines on every code change)                                                             |
| Release automation          | Inedo BuildMaster (Free edition; release orchestration, packaging, ProGet integration)                                                        |
| IaC / provisioning          | Ansible (community/open-source; provision build agents and developer machines; WSL2 runtime during early development)                         |
| Source control              | Git + GitHub                                                                                                                                  |
| IDE / code review           | Visual Studio Code + extensions                                                                                                               |
| Extension language          | TypeScript (transpiles to JavaScript/ESM)                                                                                                     |
| Extension bundler           | esbuild (or equivalent)                                                                                                                       |

---
