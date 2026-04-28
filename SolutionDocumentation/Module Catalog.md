# Ace Commander – Module Catalog v0.9

**Status:** Baseline (change-controlled)
**Supersedes:** Module Catalog v0.8
**Date:** February 22, 2026
**Change:** Section 3.3 gains new §3.3.7 VS Code C# Build Configuration (tasks.json and launch.json for class library DLL projects) and §3.3.8 Multi-Project Repository Structure: Aggregator Libraries and NuGet Packaging, covering ProjectReference aggregator patterns, cross-feature referencing, HintPath external DLL references, and single-package NuGet bundling. §3.3.9 Secrets Management: Bitwarden CLI and PowerShell SecretManagement Integration added, covering the known `match`-property extension bug and workaround, the CI/CD headless unlock pattern for Jenkins service accounts, VS Code development BW_SESSION inheritance, Bitwarden CLI in WSL2, Docker container secrets access patterns, and auto-creating BW_SESSION on WSL login (including pwsh profile setup). §3.3.10 WSL2 Runtime Environment: Installation and Configuration added, covering WSL2 install, distro selection (Ubuntu 24.04 LTS), drive mounting, Windows ↔ WSL2 networking, Ansible setup, PowerShell driving Ansible from Windows, and Docker in WSL2 with API access from .NET and PowerShell.

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

| Topic                        | Detail                                                                                                                                                                                                                                                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Limit message                | "You've hit your limit · resets 12pm (America/Denver)" — Copilot premium-request quota exhausted; Claude requests blocked until shown reset time                                                                                                                                                      |
| Two overlapping limit layers | Anthropic-side model caps (per account/plan) and Copilot-side premium-request buckets; the effective limit is whichever is exhausted first                                                                                                                                                            |
| Optimization — batch tasks   | Combine several related tasks in one Claude chat instead of many small prompts; iterate within the same thread rather than opening new chats                                                                                                                                                          |
| Optimization — model routing | Set the VS Code default model to a non-premium model (GPT-based Copilot); switch to Claude manually only for complex C#/.NET refactors, deep code reviews, or multi-project reasoning tasks                                                                                                           |
| Optimization — plan tier     | Higher-tier Copilot plans (Enterprise/Pro+) offer larger or more generous premium-request allocations; consult the org admin if limits are hit frequently                                                                                                                                             |
| Fallback when limit hit      | Switch to another Copilot model temporarily, or use the Claude web app / API directly where the plan and quota are managed explicitly                                                                                                                                                                 |
| Token usage monitoring       | No per-chat token counter is available in the VS Code Copilot Chat UI; monitor usage via GitHub web (Settings → Billing & Licensing → Usage → Copilot requests); third-party tools (e.g., "Copilot Usage Monitor" OS menu-bar app) can estimate daily usage by observing API traffic or usage reports |
| Plan management / downgrade  | Downgrade Copilot Pro+ to Copilot Pro: github.com → Profile → Settings → Billing & Licensing → Copilot → Manage Subscription → Downgrade to Copilot Pro; change takes effect at start of next billing cycle; choose Cancel Subscription in the same UI to stop paying entirely                        |

#### 2.4.5 Copilot Coding Agent: Pull Request Workflow

When you ask the Copilot coding agent (Agent mode, e.g., with Claude Opus 4.5) to "create a pull request," the agent creates a branch, edits files, commits, and opens a PR; a link to the PR appears in the chat window when the operation completes.

| Step                                             | Action                                                                                                                                                                                                                                                               |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Confirm PR link in chat                          | Scroll to the bottom of the agent chat and look for a GitHub link (`https://github.com/<org>/<repo>/pull/<N>`)                                                                                                                                                       |
| If no link — trigger execution                   | Reply: "Go ahead and apply these changes and open a pull request against `<base-branch>`" to step past any confirmation gate; wait for the link                                                                                                                      |
| Find a created PR if you missed the link         | GitHub → Pull Requests → Created by: you / Open; or use the Source Control / GitHub Pull Requests extension view in VS Code                                                                                                                                          |
| Fallback — agent only produced draft description | If Agent mode behaved like regular chat (no tools invoked): copy the generated title/description, commit and push your branch manually, use "Create Pull Request" in the GitHub Pull Requests extension, and paste the Copilot-generated text into the PR title/body |

#### 2.4.6 Claude Code: Windows Installation Reference

The official Claude Code CLI installer on Windows places `claude.exe` in `%USERPROFILE%\.local\bin`; there is no supported install-time flag to redirect to `Program Files`.

| Approach                                     | Detail                                                                                                                                                                                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Recommended — add existing location to PATH  | System Properties → Advanced → Environment Variables → User variables → Path → add `%USERPROFILE%\.local\bin`; reopen terminal; run `claude doctor` to verify                                                                                   |
| Wrapper in a custom folder (no UAC friction) | Create `C:\Tools\claude-bin\claude.bat` containing `@"%USERPROFILE%\.local\bin\claude.exe" %*`; add `C:\Tools\claude-bin` to PATH; the real binary stays where updater/uninstall logic expects it                                               |
| Do not move the executable                   | Moving `claude.exe` to `Program Files` breaks the updater and the documented uninstall commands (`Remove-Item` on `.local\bin` / `.local\share\claude`, or `winget uninstall Anthropic.ClaudeCode`), which assume the binary is in `.local\bin` |
| Default install paths                        | Binary: `%USERPROFILE%\.local\bin\claude.exe` · Data/config: `%USERPROFILE%\.local\share\claude`                                                                                                                                                |

#### 2.4.7 AI Service Subscription Reference (Google One / Google AI Plans)

As of 2025, Google markets two overlapping subscription products that are easily confused in developer conversations about AI tooling cost:

| Product                                     | Focus                      | Summary                                                                                                                                                                                                      |
| ------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Google One                                  | Storage-first subscription | Extra cloud storage (above the free 15 GB) shared across Drive, Photos, and Gmail; higher tiers bundle Google AI features (Gemini in Gmail/Docs/Slides, photo editing, Meet enhancements) and family sharing |
| Google AI Plans (sometimes called "One AI") | AI-first tiers             | Emphasize advanced Gemini model access, higher message/context limits, and AI creative tools (Veo video generation, Flow/Whisk, NotebookLM, etc.); storage is included but secondary                         |

**Relationship:** Both are part of the Google One subscription family; "Google AI Plans" is the branding applied to the AI Premium and higher tiers — not a separate product. Concrete plan names (e.g., "AI Premium 2 TB") bundle both storage and AI access.

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

#### 3.3.3 Flyway Configuration Reference (OSS 10.21.0)

**Version check:** `flyway -v` (or `flyway --version`) prints the installed edition and version and exits without running any migrations.

**Environment-variable naming rule:** Every Flyway configuration parameter `flyway.<key>` maps to an environment variable by: stripping the `flyway.` prefix, replacing any remaining dots with underscores, uppercasing the result, and prefixing with `FLYWAY_`.

_Example:_ `flyway.defaultSchema` → `FLYWAY_DEFAULTSCHEMA`

##### Common FLYWAY\_\* Environment Variables

| Environment Variable             | Configuration Key                | Purpose                                                                          |
| -------------------------------- | -------------------------------- | -------------------------------------------------------------------------------- |
| `FLYWAY_URL`                     | `flyway.url`                     | JDBC connection URL for the target database                                      |
| `FLYWAY_USER`                    | `flyway.user`                    | Database username (leave empty when using Windows Integrated Authentication)     |
| `FLYWAY_PASSWORD`                | `flyway.password`                | Database password (leave empty when using Windows Integrated Authentication)     |
| `FLYWAY_DRIVER`                  | `flyway.driver`                  | Fully qualified JDBC driver class name (auto-detected if omitted)                |
| `FLYWAY_SCHEMAS`                 | `flyway.schemas`                 | Comma-separated list of schemas managed by Flyway                                |
| `FLYWAY_DEFAULTSCHEMA`           | `flyway.defaultSchema`           | Default schema for the migration history table and unqualified SQL objects       |
| `FLYWAY_LOCATIONS`               | `flyway.locations`               | Locations of migration scripts (e.g., `filesystem:./sql`)                        |
| `FLYWAY_TABLE`                   | `flyway.table`                   | Name of the schema history table (default: `flyway_schema_history`)              |
| `FLYWAY_TABLESPACE`              | `flyway.tablespace`              | Tablespace for the schema history table (if supported by the DB)                 |
| `FLYWAY_TARGET`                  | `flyway.target`                  | Target migration version; Flyway migrates up to this version only                |
| `FLYWAY_MIXED`                   | `flyway.mixed`                   | Allow mixing versioned and repeatable migrations in the same run                 |
| `FLYWAY_OUTOFORDER`              | `flyway.outOfOrder`              | Allow out-of-order migrations                                                    |
| `FLYWAY_VALIDATEONMIGRATE`       | `flyway.validateOnMigrate`       | Validate applied migrations against available scripts on each `migrate`          |
| `FLYWAY_VALIDATEMIGRATIONNAMING` | `flyway.validateMigrationNaming` | Fail if a file in the locations folder doesn't match the expected naming pattern |
| `FLYWAY_CLEANDISABLED`           | `flyway.cleanDisabled`           | Disable the `clean` command (strongly recommended in non-dev environments)       |
| `FLYWAY_CREATESCHEMAS`           | `flyway.createSchemas`           | Let Flyway create schemas listed in `flyway.schemas` if they don't exist         |
| `FLYWAY_BASELINEONMIGRATE`       | `flyway.baselineOnMigrate`       | Automatically baseline when `migrate` is called on a non-empty schema            |
| `FLYWAY_BASELINEVERSION`         | `flyway.baselineVersion`         | Version tag applied to the schema baseline                                       |
| `FLYWAY_BASELINEDESCRIPTION`     | `flyway.baselineDescription`     | Description applied to the schema baseline record                                |
| `FLYWAY_IGNOREMIGRATIONPATTERNS` | `flyway.ignoreMigrationPatterns` | Patterns for migrations to ignore during validate (e.g., `*:missing`)            |
| `FLYWAY_CONNECTRETRIES`          | `flyway.connectRetries`          | Number of times to retry DB connection on startup failure                        |
| `FLYWAY_CONNECTRETRIESINTERVAL`  | `flyway.connectRetriesInterval`  | Interval in seconds between connection retries                                   |
| `FLYWAY_INITSQL`                 | `flyway.initSql`                 | SQL executed once per connection before migrations run                           |
| `FLYWAY_JDBCPROPERTIES`          | `flyway.jdbcProperties`          | Additional JDBC connection properties                                            |
| `FLYWAY_WORKINGDIRECTORY`        | `flyway.workingDirectory`        | Working directory for Flyway; relative paths are resolved against this           |
| `FLYWAY_LOGGERS`                 | `flyway.loggers`                 | Logger(s) to use (e.g., `console`, `file`)                                       |
| `FLYWAY_SKIPDEFAULTRESOLVERS`    | `flyway.skipDefaultResolvers`    | Skip the built-in migration resolvers                                            |
| `FLYWAY_SKIPDEFAULTCALLBACKS`    | `flyway.skipDefaultCallbacks`    | Skip the built-in callbacks                                                      |
| `FLYWAY_SKIPEXECUTINGMIGRATIONS` | `flyway.skipExecutingMigrations` | Scan and validate but do not actually execute migrations                         |
| `FLYWAY_OUTPUTQUERYRESULTS`      | `flyway.outputQueryResults`      | Output query results to the console during migration                             |
| `FLYWAY_REPORTFILENAME`          | `flyway.reportFilename`          | Path/filename for the HTML/JSON report generated after a `migrate` run           |
| `FLYWAY_PLACEHOLDERS_<NAME>`     | `flyway.placeholders.<name>`     | User-defined placeholder value (see subsection below)                            |
| `FLYWAY_JDBCPROPERTIES_<PROP>`   | `flyway.jdbcProperties.<prop>`   | Individual JDBC property (e.g., `FLYWAY_JDBCPROPERTIES_ACCESSTOKEN`)             |

_For the authoritative full list, see the Parameters reference in the Flyway 10.x documentation and apply the naming rule to every entry._

##### Flyway Placeholders (`FLYWAY_PLACEHOLDERS_*`)

Placeholders allow the same SQL migration script to be customized per environment. In scripts, write `${variable_name}`; Flyway substitutes the configured value before sending SQL to the database.

```sql
-- Example migration using placeholders
CREATE SCHEMA ${schema_name};
GRANT SELECT ON SCHEMA ${schema_name} TO ${readonly_user};
```

Configuration mapping:

| Configuration key                   | Environment variable                | Script token       |
| ----------------------------------- | ----------------------------------- | ------------------ |
| `flyway.placeholders.schema_name`   | `FLYWAY_PLACEHOLDERS_SCHEMA_NAME`   | `${schema_name}`   |
| `flyway.placeholders.readonly_user` | `FLYWAY_PLACEHOLDERS_READONLY_USER` | `${readonly_user}` |
| `flyway.placeholders.myPlaceholder` | `FLYWAY_PLACEHOLDERS_MYPLACEHOLDER` | `${myPlaceholder}` |

**`FP__flyway_<name>__` variables:** When Flyway (or Redgate wrapper tooling) runs callbacks or external scripts, it exports resolved placeholder values as `FP__flyway_<name>__` environment variables so those scripts can access the same values the migrations saw, without re-parsing configuration files.

- `FLYWAY_PLACEHOLDERS_*` — how you **provide** placeholder values **to** Flyway.
- `FP__flyway_<name>__` — how Flyway **exports** resolved placeholder values **out to** callbacks and scripts.

##### Common Pitfalls: Placeholders in Repeatable Migrations

| Pitfall                                      | Detail                                                                                                                                                                                                                     | Mitigation                                                                                                                                                                                                          |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Placeholder change doesn’t re-run repeatable | Flyway checksums repeatable (`R__`) scripts from the **raw script text**, typically before substituting placeholders. Changing a `FLYWAY_PLACEHOLDERS_*` value does not change the stored checksum; the script is skipped. | Change the script body itself when you want it to re-run, rather than relying on a placeholder-value flip.                                                                                                          |
| “Always-run” via changing placeholder fails  | Putting a changing value (e.g., a timestamp placeholder) in a repeatable script and expecting it to run every `migrate` does not work in older versions because checksum is taken pre-substitution.                        | Use Flyway **callbacks** (`beforeMigrate.sql`, `afterMigrate.sql`) for logic that must run every time. Or use the `${flyway:timestamp}` built-in placeholder, which is designed to change the checksum on each run. |
| Hidden coupling of env config to repeatables | Different `FLYWAY_PLACEHOLDERS_*` values across environments can cause the same repeatable script to produce different SQL, making environment-specific results hard to trace.                                             | Document all placeholder values in version-controlled config files; review placeholder-driven SQL in migration code reviews.                                                                                        |

#### 3.3.4 GitHub Issue & Branch Workflow

Three supported options for creating a branch tied to a GitHub issue, listed in recommended order:

| Option                                                           | Where      | Steps                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| From the GitHub issue (recommended — auto-links branch to issue) | GitHub web | Issues → open the issue → Development section in the right sidebar → Create a branch → set branch name (e.g., `issue-<N>-short-description`) and base branch → Create branch; then `git fetch && git switch <branch-name>` in your local clone |
| From VS Code Source Control view                                 | VS Code    | Ensure you are on the correct base branch → + Create new branch (or Command Palette: "Git: Create Branch…") → name it `issue-<N>-short-description`; VS Code switches automatically after creation                                             |
| GitHub CLI (good for scripted flows)                             | Terminal   | `gh issue develop <issue-number> --base main --checkout` — creates a sensibly named branch from `main` and checks it out in one step                                                                                                           |

#### 3.3.5 Jenkins vs. ProGet: Toolchain Role Comparison

Jenkins and ProGet serve fundamentally different and complementary roles in the build pipeline; they are not alternatives — they are typically used together.

| Dimension             | Jenkins                                                                                                                                                       | ProGet                                                                                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Primary role          | CI/CD automation server — executes build, test, and deploy pipeline steps (agents, stages, Jenkinsfile steps)                                                 | Package registry/repository — stores, secures, curates, and promotes versioned packages and containers (NuGet, npm, Maven, Docker, Universal Packages, etc.)          |
| Build execution       | Runs actual build and test steps on agents; orchestrates the full pipeline                                                                                    | Does not execute builds; integrates with CI runners to ingest build/SCA data (SBOM publishing, build scanning via `pgutil`)                                           |
| Artifact storage      | Can archive Jenkins "artifacts" per build run, but has no package versioning or governance model                                                              | System-of-record for versioned packages; provides package metadata, audit history, and policies across all consumers                                                  |
| Security / compliance | Security of pipeline scripts and credentials; plugin ecosystem for scanning, but not package-level governance                                                 | Approval workflows, vulnerability and license scanning (SCA), policy enforcement governing which package versions are allowed and how they progress toward production |
| Promotion model       | Pipeline stages can deploy artifacts to successive environments                                                                                               | Built-in package promotion across feeds (unlisted → tested → production), tracking status and approvals alongside the packages themselves                             |
| Integration point     | Jenkins publishes built packages **to** ProGet using the Jenkins ProGet plugin or API keys; downstream environments consume approved packages **from** ProGet | Provides a stable, controlled feed URL that Jenkins (and other consumers) pull dependencies from; ensures only approved dependency versions enter builds              |
| Plugin ecosystem      | Huge plugin ecosystem for almost every tool and service                                                                                                       | Focused integrations: NuGet, npm, Maven, Docker, Helm, Universal Packages; Jenkins plugin; `pgutil` CLI for CI integration                                            |
| When to reach for it  | When you need a flexible engine to orchestrate builds/tests across repos/branches                                                                             | When you need a hardened internal registry with caching, promotion, and security/compliance controls for dependencies and release artifacts                           |

**Typical pipeline flow for this project:**
Jenkins build → test → publish packages to ProGet feed → BuildMaster release orchestration → environments pull approved packages from ProGet for deployment.

#### 3.3.6 PowerShell Database Connectivity: dbatools & SqlClient

##### SQL Server Connection String Builder Libraries

The following libraries provide builder-style objects for constructing SQL Server connection strings from typed properties (analogous to `UriBuilder` for URLs), with varying degrees of PowerShell integration and JDBC URL support:

| Library                                                              | NuGet / Source                                 | PowerShell friendly                                                                                                 | JDBC URL support                                                                 | Notes                                                                                                       |
| -------------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **dbatools** `New-DbaConnectionStringBuilder`                        | PowerShell Gallery (`dbatools`)                | Native — cmdlet returns a `Microsoft.Data.SqlClient.SqlConnectionStringBuilder`                                     | Indirect — builder holds all parameters; emit JDBC with a small helper template  | MIT-licensed; largest OSS SQL Server PowerShell module; recommended starting point for PS-centric workflows |
| **Microsoft.Data.SqlClient** `SqlConnectionStringBuilder`            | NuGet (`Microsoft.Data.SqlClient`)             | Yes — load via `Add-Type` or `#r "nuget:…"` in PS7+; use as `[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]` | Indirect — all parameters available to derive `jdbc:sqlserver://` string         | Current ADO.NET provider; MIT-licensed; used internally by dbatools                                         |
| **DatabaseWrapper** (`jchristn/DatabaseWrapper`)                     | NuGet / GitHub                                 | Yes — load .dll via `Add-Type`                                                                                      | Indirect — centralises all parameters; easy to add JDBC template                 | C# wrapper for SQL Server, MySQL, PostgreSQL, SQLite; higher-level than raw builder                         |
| **Aireforge SQL Server Connection String Generator**                 | Web tool / source                              | Primarily GUI/web; compiled logic reusable                                                                          | Native — explicitly generates `jdbc:sqlserver://` URLs alongside ADO.NET strings | Useful reference for JDBC parameter mapping                                                                 |
| **Microsoft Elastic DB Tools for Java** `SqlConnectionStringBuilder` | GitHub (`microsoft/elastic-db-tools-for-java`) | Java-side only                                                                                                      | Native — designed specifically to emit `jdbc:sqlserver://` URLs                  | Mirrors the .NET `SqlConnectionStringBuilder` API in Java; useful for mixed .NET/Java environments          |

**Recommended pattern for this project:** Use `dbatools` `New-DbaConnectionStringBuilder` for ADO.NET strings in PowerShell scripts; add a small helper function that maps the builder's properties to a `jdbc:sqlserver://` template for Flyway/JDBC consumers.

##### Importing dbatools

Pattern to test for presence and import conditionally:

```powershell
$module = Get-Module -ListAvailable -Name dbatools

if ($null -eq $module) {
    Write-PSFMessage -Level Warning -Message "dbatools module is not installed. Install it with: Install-Module -Name dbatools"
} else {
    Import-Module -Name dbatools -ErrorAction Stop
    Write-PSFMessage -Level Important -Message "dbatools module imported. Version: $((Get-Module dbatools).Version)"
}
```

To auto-install when missing (acceptable in interactive/dev sessions; evaluate for automation contexts):

```powershell
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Install-Module -Name dbatools -Scope CurrentUser -Force
}
Import-Module -Name dbatools -ErrorAction Stop
```

##### Microsoft.Data.SqlClient DLL Version Conflict

**Symptom:** `Import-Module dbatools -ErrorAction Stop` throws:

> `Couldn't import … Microsoft.Data.SqlClient.dll | Could not load file or assembly 'Microsoft.Data.SqlClient, Version=6.0.0.0 …'. Assembly with same name is already loaded`

**Cause:** A different version of `Microsoft.Data.SqlClient` is already loaded in the runspace (most commonly from `Import-Module SqlServer` earlier in the session).

| Resolution                | Detail                                                                                                                                                                     |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Import dbatools first     | Always import dbatools before `SqlServer` or any other module that bundles its own `Microsoft.Data.SqlClient`; dbatools maintainers explicitly recommend this import order |
| Use only one in a session | Prefer using either dbatools or SqlServer per script/session, not both; if both are required, dbatools first is the safest order                                           |
| Fresh PowerShell session  | Assemblies cannot be unloaded in Windows PowerShell 5.1; close the session, open a new one, and import dbatools first                                                      |
| PowerShell 7+             | Experimental workarounds exist (enumerate and avoid the conflicting assembly), but dbatools maintainers treat them as fragile; the import-order rule is more reliable      |

##### VS Code SQL Extensions and PowerShell Module Loading

The VS Code extensions **mssql** (SQL Server / ms-mssql.mssql) and **SQL Language Server** run their SQL tooling inside their own extension host processes (SQL Tools Service); they do **not** automatically import the `SqlServer` PowerShell module into any integrated terminal window.

The only things that will auto-load `SqlServer` into a VS Code PowerShell terminal are:

- PowerShell profile scripts (e.g. `Microsoft.VSCode_profile.ps1`) that contain `Import-Module SqlServer`.
- Commands explicitly run in that terminal session.

**PowerShellProTools** (`PowerShellProTools` and `PowerShellProTools.VSCode`) — the Ironman Software GUI designer and VS Code integration modules — do not automatically import `SqlServer` either. They package/debugs PowerShell scripts but have no built-in SQL Server module dependency; any `Import-Module SqlServer` would be explicit in user script code or profiles.

##### Inspecting Loaded Modules in a VS Code Terminal

```powershell
# List all modules currently loaded in this session
Get-Module

# Check if specific modules are loaded
Get-Module SqlServer, dbatools

# List all modules installed and available (not necessarily loaded)
Get-Module -ListAvailable

# List a specific installed module
Get-Module -ListAvailable -Name dbatools
```

If `Get-Module SqlServer` returns nothing, the `SqlServer` module is not loaded in that session and cannot be causing a DLL version conflict.

#### 3.3.7 VS Code C# Build Configuration: tasks.json and launch.json

Minimal setup to build a C# class library (`.dll`) inside VS Code: a `.csproj` targeting `OutputType=Library`, a `tasks.json` entry running `dotnet build`, and a `launch.json` entry wired to that task via `preLaunchTask`.

##### Minimal Class Library `.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <OutputType>Library</OutputType>
  </PropertyGroup>
</Project>
```

Compiles all `*.cs` files in the project folder into `bin/Debug/net8.0/<AssemblyName>.dll`. For projects using `Microsoft.NET.Sdk`, the default `OutputType` is already `Library`; the explicit entry is included here for clarity.

##### tasks.json Build Entry

```jsonc
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build MyLib",
      "type": "process",
      "command": "dotnet",
      "args": ["build", "${workspaceFolder}/MyLib.csproj", "/property:GenerateFullPaths=true", "/consoleloggerparameters:NoSummary"],
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "problemMatcher": "$msCompile"
    }
  ]
}
```

##### launch.json Entry with preLaunchTask

For a build-only arrangement (the DLL is the artifact, not a runnable executable), wire a `coreclr` launch configuration with `preLaunchTask` so the DLL is rebuilt on every debug session:

```jsonc
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Build MyLib only",
      "type": "coreclr",
      "request": "launch",
      "preLaunchTask": "build MyLib",
      "program": "",
      "cwd": "${workspaceFolder}",
      "console": "internalConsole",
      "justMyCode": true
    }
  ]
}
```

In practice, set `program` to point to an executable host that references the DLL and keep `preLaunchTask` so the DLL is always rebuilt before the host runs.

| Configuration key              | Purpose                                                                                    |
| ------------------------------ | ------------------------------------------------------------------------------------------ |
| `type: "coreclr"`              | Targets the .NET CLR debugger (C# Dev Kit / C# extension requirement)                      |
| `request: "launch"`            | Launch a new process rather than attach to an existing one                                 |
| `preLaunchTask`                | Name of the `tasks.json` task to run before launch; ensures the DLL is current             |
| `program`                      | Path to the executable host; leave empty if the sole goal is to confirm the library builds |
| `problemMatcher: "$msCompile"` | Enables VS Code to parse MSBuild error output and populate the Problems panel              |

---

#### 3.3.8 Multi-Project Repository Structure: Aggregator Libraries and NuGet Packaging

The repository's pattern for feature libraries (`<FeatureName>.StringConstants`, `<FeatureName>.Enumerations`, `<FeatureName>.DefaultConfiguration`, `<FeatureName>.Interfaces`, `<FeatureName>.Models`) can be organized under a higher-level `<FeatureName>` aggregator project. The aggregator is itself a class library that references all sub-projects via `<ProjectReference>`; consumers reference only the aggregator rather than each sub-project individually.

##### Recommended Directory Structure

```path
src/
└── <FeatureName>/
    ├── <FeatureName>.StringConstants/
    │   └── <FeatureName>.StringConstants.csproj
    ├── <FeatureName>.Enumerations/
    │   └── <FeatureName>.Enumerations.csproj
    ├── <FeatureName>.DefaultConfiguration/
    │   └── <FeatureName>.DefaultConfiguration.csproj
    ├── <FeatureName>.Interfaces/
    │   └── <FeatureName>.Interfaces.csproj
    ├── <FeatureName>.Models/
    │   └── <FeatureName>.Models.csproj
    └── <FeatureName>/                          ← aggregator
        └── <FeatureName>.csproj
```

##### Aggregator `.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\<FeatureName>.StringConstants\<FeatureName>.StringConstants.csproj" />
    <ProjectReference Include="..\<FeatureName>.Enumerations\<FeatureName>.Enumerations.csproj" />
    <ProjectReference Include="..\<FeatureName>.DefaultConfiguration\<FeatureName>.DefaultConfiguration.csproj" />
    <ProjectReference Include="..\<FeatureName>.Interfaces\<FeatureName>.Interfaces.csproj" />
    <ProjectReference Include="..\<FeatureName>.Models\<FeatureName>.Models.csproj" />
  </ItemGroup>
</Project>
```

`<ProjectReference>` gives the compiler visibility of all public types from sub-projects; the aggregator DLL depends on those sub-project DLLs at runtime (multiple physical DLLs — this is not IL merging).

##### Cross-Feature References

Within the same multi-project repository, prefer `<ProjectReference>` to the target feature's aggregator `.csproj`:

```xml
<ItemGroup>
  <!-- Billing depends on the full OrderProcessing feature -->
  <ProjectReference Include="..\OrderProcessing\OrderProcessing\OrderProcessing.csproj" />
</ItemGroup>
```

This ensures correct build ordering, incremental builds, and proper transitive dependency expression when the consuming project is later packed as a NuGet package.

To reference a pre-built DLL from an external source when a project reference is not available, use `<Reference>` with `HintPath`:

```xml
<ItemGroup>
  <Reference Include="ExternalLib">
    <HintPath>..\packages\ExternalLib\lib\net8.0\ExternalLib.dll</HintPath>
    <Private>true</Private> <!-- copy to output directory -->
  </Reference>
</ItemGroup>
```

| Reference type             | Use when                                                                                     |
| -------------------------- | -------------------------------------------------------------------------------------------- |
| `<ProjectReference>`       | Target project is in the same repo; preferred for build correctness and NuGet pack semantics |
| `<PackageReference>`       | Consuming a published NuGet package from an internal or public feed                          |
| `<Reference>` + `HintPath` | Consuming a pre-built external DLL not available via NuGet or project reference              |

##### NuGet Single-Package Bundling

To distribute all sub-project DLLs inside a single `.nupkg`, run `dotnet pack` against the aggregator project. Use a custom `pack.props`/targets file to copy all referenced project outputs into the same `lib/netX.Y` folder of the package before packing so that installing the single package brings in all constituent DLLs.

> **Note:** IL-merging multiple DLLs into a single physical DLL (ILRepack, etc.) is generally discouraged for .NET 6+; NuGet single-package bundling (multiple DLLs inside one `.nupkg`) is the idiomatic and supported alternative.

---

#### 3.3.9 Secrets Management: Bitwarden CLI and PowerShell SecretManagement Integration

This section documents patterns for using Bitwarden as the secrets vault in developer workflows and CI/CD pipelines, covering both the PowerShell SecretManagement extension approach and direct Bitwarden CLI usage.

##### Available Bitwarden SecretManagement Extensions

Two community-maintained PowerShell SecretManagement extensions wrap the Bitwarden CLI (`bw`):

| Extension                    | PowerShell Gallery slug      | GitHub                                                | Notes                            |
| ---------------------------- | ---------------------------- | ----------------------------------------------------- | -------------------------------- |
| `SecretManagement.BitWarden` | `SecretManagement.BitWarden` | (PSGallery-hosted)                                    | Older extension; still published |
| `SecretManagement.Warden`    | `SecretManagement.Warden`    | https://github.com/marshallwp/SecretManagement.Warden | Actively maintained; recommended |

Both extensions detect the `BW_SESSION` environment variable and append `--session $env:BW_SESSION` to internal `bw` calls automatically, so no interactive prompts occur while the session is valid.

##### Known Bug: `match` Property Error in SecretManagement Extensions

**Symptom:** Calls to `Get-Secret` via the Bitwarden SecretManagement extension fail with:

> `Failed to retrieve secret from Bitwarden. Exception: Exception setting "match": "The property 'match' cannot be found on this object. Verify that the property exists and can be set."`

**Cause:** This is an extension-side bug, not a vault-item configuration error. The extension iterates over `login.uris` objects returned by the Bitwarden CLI and attempts to set a `.match` enum property on each URI object:

```powershell
$_.login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })
```

If the CLI returns a URI object without a `match` property (e.g., because the CLI output format changed or the URI was created without a match-detection policy), PowerShell throws the error. The extension does not guard for missing properties before setting them. Nothing in the Bitwarden vault UI lets you define or fix a `match` property to prevent this exception.

| What to check / try                 | Detail                                                                                                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Item definition in vault            | **Not the cause** — no vault UI option prevents this extension exception                                                                                            |
| Extension version                   | Update to the latest `SecretManagement.Warden` or `SecretManagement.BitWarden`; some versions include guards                                                        |
| Bitwarden CLI version               | Ensure `bw` is at the latest stable release; CLI output format changes can trigger this                                                                             |
| Manual workaround (edit the module) | Locate the `ForEach` loop inside the extension and guard the assignment: `if ($_.PSObject.Properties['match']) { [BitwardenUriMatchType]$_.match = [int]$_.match }` |
| Bypass extension entirely           | Call `bw get password '<item-name>'` directly in scripts; avoids all extension JSON-handling issues                                                                 |

##### CI/CD Headless Unlock Pattern (Jenkins Service Account)

For pipelines where a `JenkinsClient` service (or Jenkins agent) runs on a build computer without interactive login, use the Bitwarden API key flow to authenticate non-interactively and inject `BW_SESSION` into the service's process environment.

**High-level pattern:**

1. Create a dedicated Bitwarden account or organization for CI/CD with minimal vault access (least privilege).
2. Store `BW_CLIENTID`, `BW_CLIENTSECRET`, and `BW_PASSWORD` as Jenkins Credentials (secret text / username+password) — **not** in scripts or files on disk.
3. At agent startup (or in a pre-build wrapper), map those credentials into environment variables and run:

   ```bash
   # Login (once per workspace / node image)
   bw login --apikey    # uses BW_CLIENTID / BW_CLIENTSECRET env vars

   # Unlock and capture the session token
   BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
   export BW_SESSION
   ```

   In PowerShell:

   ```powershell
   $env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw
   ```

4. All downstream pipeline stages use `bw get password '<item-name>'` or `Get-Secret -Name '<item-name>'` without further prompts.
5. Do **not** write `BW_SESSION` to disk; keep it in process environment scope only.
6. Optionally run `bw lock` at the end of long-lived jobs to force a fresh unlock on the next run.

| Security practice                      | Detail                                                                                                                                                                  |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API key over interactive login         | `bw login --apikey` is the supported non-interactive method for automation; uses `BW_CLIENTID` / `BW_CLIENTSECRET`                                                      |
| Jenkins credentials store              | Store all Bitwarden credentials as Jenkins Credentials; mask them in log output; never echo in pipeline scripts                                                         |
| Least privilege vault                  | CI/CD account/org has access only to the secrets the pipeline actually needs                                                                                            |
| Rotate credentials                     | Rotate API key and master password on a regular cadence                                                                                                                 |
| Jenkins Bitwarden Credentials Provider | Optional Jenkins plugin that handles token management and lets Jenkins treat Bitwarden items as native Jenkins credentials, removing the need for manual unlock scripts |
| Containers / ephemeral agents          | Bake `bw` into the agent image; add an entrypoint script that runs `bw login --apikey` + `bw unlock` before starting the Jenkins agent process                          |

##### VS Code Development: Inheriting BW_SESSION from the Shell

When VS Code is launched from an interactive shell that has already unlocked Bitwarden, it inherits `BW_SESSION`; all integrated terminal sessions and PowerShell tasks can access Bitwarden without interactive prompts.

**Recommended setup:**

1. In your PowerShell profile (`Microsoft.PowerShell_profile.ps1`), unlock Bitwarden and set `BW_SESSION`:

   ```powershell
   # Profile snippet — runs automatically when the shell starts
   $env:BW_SESSION = bw unlock --raw
   ```

2. Launch VS Code from **that same shell**: `code .`
   VS Code inherits the full environment, including `BW_SESSION`.

3. Verify inside the VS Code integrated terminal:

```powershell
$env:BW_SESSION          # should be non-empty
bw status                # should report status: "unlocked"
```

**Tasks integration:** Shell tasks in `tasks.json` that run `pwsh` inherit the environment automatically. Scripts can call Bitwarden directly:

```powershell
# Using Bitwarden CLI directly
$DbPassword = bw get password 'my-db-secret'

# Or via SecretManagement extension (detects BW_SESSION automatically)
$DbPassword = Get-Secret -Name 'my-db-secret'
```

**If VS Code is launched from the GUI (not a shell):**

Environment variables set in an interactive terminal session are not inherited by processes started from the Windows Start menu or taskbar. Options:

| Approach                           | Detail                                                                                                                                                                                         |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Always launch VS Code from a shell | `code .` from a PowerShell session where `BW_SESSION` is already set; cleanest approach                                                                                                        |
| Conditional unlock at task start   | Add to `build.ps1`: `if (-not $env:BW_SESSION) { $env:BW_SESSION = bw unlock --raw }` — will prompt once in the VS Code terminal, then reuse for the session                                   |
| User-level environment variable    | Set `BW_SESSION` persistently: `[System.Environment]::SetEnvironmentVariable('BW_SESSION', (bw unlock --raw), 'User')`; restart VS Code; be aware the session expires when the vault is locked |

##### Bitwarden CLI in WSL2 (Ubuntu)

For scripts and programs running directly in WSL2 (not inside Docker containers), install the Bitwarden CLI (`bw`) natively in the Ubuntu distro and fetch secrets via the same `BW_SESSION` pattern used on Windows.

**Installation in WSL2:**

- Direct binary (recommended): download the Linux CLI binary from Bitwarden's CLI docs and place `bw` on `$PATH` (e.g., `/usr/local/bin`).
- Via npm: `npm install -g @bitwarden/cli` — works if Node.js is already installed in WSL.

**Login and unlock:**

```bash
# One-time login (authenticates and syncs vault)
bw login

# Subsequent unlocks — returns raw session token
export BW_SESSION="$(bw unlock --raw)"
```

With `BW_SESSION` set, all subsequent `bw` calls in that shell are non-interactive until `bw lock` is called or the session expires.

**Fetching secrets:**

```bash
# Find an item by name
bw list items --search "my-api-key"

# Retrieve a password by item ID
bw get password <item-id>

# Use inline in a script
export DB_PASSWORD=$(bw get password db-prod)
```

**Self-hosted / Vaultwarden server:** Set `BW_SERVER` before logging in:

```bash
export BW_SERVER="https://your.vault.url"
bw login
```

##### Accessing Bitwarden Secrets from Docker Containers in WSL2

Two patterns for containers running inside WSL2. `SecretManagement` on Windows is not accessible directly from WSL or Docker containers — use Bitwarden as the single source of truth and access it via `bw`/`bws` inside WSL.

**Pattern A — Bitwarden Secrets Manager CLI (`bws`) with access token**

Use when you have a Bitwarden Secrets Manager subscription:

- Include the `bws` CLI in your container image (or use `bitwarden/bws` as a base image).
- At `docker run` time, pass a short-lived access token:

```bash
docker run -e BWS_ACCESS_TOKEN=<token> your-image
```

- Entry-point script runs `bws secret list` / `bws secret get` and exports values or writes a config file before starting the application.

**Pattern B — Standard `bw` CLI pre-deploy `.env` injection**

Use with the standard Bitwarden Password Manager:

1. In WSL (before running Docker), ensure `BW_SESSION` is set and generate an `.env` file:

   ```bash
   echo "DB_PASSWORD=$(bw get password db-prod)" > /tmp/app.env
   echo "API_KEY=$(bw get password my-api-key)" >> /tmp/app.env
   chmod 600 /tmp/app.env
   ```

2. Mount the file into the container at run time:

   ```bash
   docker run --env-file /tmp/app.env your-image
   # or with Docker Compose:  env_file: /tmp/app.env
   ```

3. Delete `/tmp/app.env` after the container starts if the file should not persist.

**Key principle:** Bitwarden credentials and session tokens must not be baked into container images. Fetch secrets at runtime and inject via environment variables or ephemeral config files.

##### Auto-creating BW_SESSION on WSL Login (Bash / pwsh)

To mirror the Windows logon-script behavior — automatically setting `BW_SESSION` on every shell startup inside Ubuntu WSL — hook a function into the appropriate startup file.

**Bash hook (`~/.bashrc` or `~/.bash_profile`):**

```bash
bw_auto_unlock() {
  if [ -z "$BW_SESSION" ]; then
    echo "Unlocking Bitwarden CLI session..."
    export BW_SESSION="$(bw unlock --raw)"
  fi
}
bw_auto_unlock
```

**pwsh (PowerShell 7) profile — `~/.config/powershell/Microsoft.PowerShell_profile.ps1`:**

Create the config directory and profile file if they do not yet exist:

```powershell
New-Item -ItemType Directory -Path ~/.config/powershell -Force | Out-Null
New-Item -ItemType File -Path ~/.config/powershell/Microsoft.PowerShell_profile.ps1 -Force | Out-Null
```

Confirm `$PROFILE` resolves to the expected path:

```powershell
$PROFILE
Test-Path $PROFILE
```

Add to the profile:

```powershell
# Auto-unlock Bitwarden in WSL sessions only
if ($env:WSL_DISTRO_NAME -and -not $env:BW_SESSION) {
    if ($env:BW_PASSWORD) {
        # Non-interactive: BW_PASSWORD env var was set before pwsh started
        $session = bw unlock --raw --passwordenv BW_PASSWORD
    } else {
        # Interactive: prompt once per session
        $session = bw unlock --raw
    }
    if ($LASTEXITCODE -eq 0 -and $session) {
        $env:BW_SESSION = $session
    }
}
```

**CLIXML (Windows `SecureString`) files — not suitable for WSL:** CLIXML-encrypted `SecureString` files depend on the Windows DPAPI context. Once moved into WSL, DPAPI is unavailable and the master password would be exposed as plaintext. Use Bitwarden's supported automation patterns instead:

| Automation approach                 | How                                                                                                                                                  |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| API key (non-interactive login)     | Set `BW_CLIENTID` and `BW_CLIENTSECRET`; run `bw login --apikey`; store these in a protected file (`chmod 600`) read into the environment at startup |
| `--passwordenv` for unlock          | Set `BW_PASSWORD` temporarily before running `bw unlock --passwordenv BW_PASSWORD --raw`; unset immediately after                                    |
| `--passwordfile` for unlock         | Write the master password to a file with `chmod 600`; pass with `bw unlock --passwordfile /path/to/mp.txt --raw`; restrict to owning user only       |
| Interactive prompt once per session | Allow `bw unlock --raw` to prompt; enter password manually at session start; appropriate when `BW_SESSION` lifespan matches a typical work session   |

**Security note:** `BW_SESSION` grants access to the decrypted vault for the duration of the session. Do not write it to disk, commit it to source control, or log it. Call `bw lock` in logout/cleanup scripts when stronger guarantees are needed.

---

#### 3.3.10 WSL2 Runtime Environment: Installation and Configuration

WSL2 is the Ansible execution runtime and Docker host for development and CI/CD workloads in this project (see §3.3.1 and §2.5). This section is the setup reference for WSL2 on Windows 11.

##### Installation

From an elevated PowerShell on Windows 11:

```powershell
wsl --install
wsl --set-default-version 2
```

Verify after install:

```powershell
wsl -l -v   # should show the distro with VERSION 2
```

##### Recommended Distro: Ubuntu 24.04 LTS

| Distro               | Recommendation                                                                                                                                                         |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ubuntu 24.04 LTS** | Primary choice — first-class WSL support, default Microsoft WSL distro, best tooling ecosystem for Ansible and Docker, largest community and troubleshooting resources |
| **Debian**           | Alternative — leaner image, more conservative package versions; preferred when production servers are Debian-based to reduce environment drift                         |
| Alpine               | Not recommended for this use case — library compatibility issues and far less WSL2 + Docker/Ansible guidance available                                                 |

Install the recommended distro:

```powershell
$distroToInstall = 'Ubuntu-24.04'
wsl --install $distroToInstall
wsl --set-default-version 2
```

With optional interactive default:

```powershell
$defaultDistro = 'Ubuntu-24.04'
$distroToInstall = Read-Host -Prompt "Distro to install [`$defaultDistro`]"
if ([string]::IsNullOrWhiteSpace($distroToInstall)) { $distroToInstall = $defaultDistro }
wsl --install $distroToInstall
wsl --set-default-version 2
```

List all available distros: `wsl --list --online`

##### Windows Drive Mounting (/mnt/c, /mnt/d, /mnt/e)

WSL2 auto-mounts fixed Windows drives under `/mnt` via DrvFs (C: → `/mnt/c` by default). If additional drives (D:, E:) are not auto-mounted:

```bash
sudo mkdir -p /mnt/d /mnt/e
sudo mount -t drvfs D: /mnt/d
sudo mount -t drvfs E: /mnt/e
```

To make additional mounts persistent, add to `/etc/wsl.conf`:

```ini
[automount]
enabled = true
root = /mnt/
```

Apply changes: run `wsl --shutdown` from Windows PowerShell, then re-open WSL.

##### Networking: Windows ↔ WSL2 and Organizational Network

| Direction                                          | How                                                                                                                                                                                                        |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| WSL2 → Windows host services                       | Get the Windows IP visible from WSL: `ip route show \| grep default \| awk '{print $3}'`; call services at `http://<host-ip>:port`                                                                         |
| WSL2 → org network                                 | WSL2 inherits the Windows host's network connectivity; services reachable from Windows are reachable from WSL2 at the same hostnames/IPs                                                                   |
| Windows → WSL2 services (mirrored networking mode) | Windows 11 22H2+ supports mirrored networking where `http://localhost:port` reaches WSL2 services directly                                                                                                 |
| Windows → WSL2 services (older NAT mode)           | Use the WSL2 VM IP (`wsl hostname -I`) and optionally configure port forwarding: `netsh interface portproxy add v4tov4 listenport=<port> listenaddress=0.0.0.0 connectport=<port> connectaddress=<wsl-ip>` |

##### Ansible Setup in WSL2

Install Ansible in the Ubuntu distro:

```bash
sudo apt update && sudo apt install ansible
```

Keep inventories and playbooks on the Linux filesystem (`/home/<user>/ansible`) for I/O performance. Playbooks in WSL2 can:

- Call Windows-hosted APIs via Ansible URI modules.
- Manage Linux and Windows targets on the organizational network as long as those endpoints are reachable from WSL2.

##### PowerShell on Windows Driving Ansible in WSL2

From Windows PowerShell, invoke commands inside WSL using `wsl -d <Distro>`:

```powershell
wsl -d Ubuntu-24.04 -- ansible-playbook /home/<user>/ansible/site.yml -i /home/<user>/ansible/inventory
```

**Pattern for generating and triggering playbooks from Windows:**

1. Keep "desired state" definitions in a Git repo on Windows (e.g., `D:\OrgInfraDefs`).
2. A PowerShell script reads definitions, generates Ansible YAML (playbooks + inventory) to an output folder on Windows (e.g., `D:\Generated\Ansible`).
3. Copy generated files into WSL — either write directly to `\\wsl$\<Distro>\home\<user>\ansible` from Windows, or have WSL read from `/mnt/d/Generated/Ansible`.
4. Trigger the run from PowerShell:

```powershell
wsl -d Ubuntu-24.04 -- ansible-playbook /home/<user>/ansible/site.yml -i /home/<user>/ansible/inventory
```

This pattern centralizes intent in a Windows-hosted repo, auto-generates Ansible assets in PowerShell, and uses WSL2 as the execution engine without requiring a separate Linux build machine.

##### Docker in WSL2 and API Access from Windows

Install Docker Engine directly in the Ubuntu WSL2 distro (or use Docker Desktop with WSL2 integration):

```bash
sudo apt update
sudo apt install docker.io
sudo usermod -aG docker $USER   # run docker without sudo
# Re-open the WSL session for group membership to take effect
```

Start a container that exposes an API:

```bash
docker run -p 5000:80 myorg/myapp
```

**Access the container API from Windows:**

| Runtime environment                    | URL to use                                                    |
| -------------------------------------- | ------------------------------------------------------------- |
| Windows 11 22H2+ (mirrored networking) | `http://localhost:5000` — works directly                      |
| Older Windows / NAT mode               | `http://<wsl-ip>:5000` — obtain WSL IP with `wsl hostname -I` |

**.NET programs on Windows:**

```csharp
var client = new HttpClient();
var response = await client.GetAsync("http://localhost:5000/api/resource");
```

**PowerShell on Windows:**

```powershell
Invoke-RestMethod -Uri 'http://localhost:5000/api/resource'
```

The WSL2 container behaves like any other local web service from the Windows side.

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
