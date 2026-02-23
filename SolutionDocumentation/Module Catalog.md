# Ace Commander – Module Catalog v0.7

**Status:** Baseline (change-controlled)
**Supersedes:** Module Catalog v0.6
**Date:** February 22, 2026
**Change:** Section 3.3 gains new §3.3.5 Jenkins vs ProGet: Toolchain Role Comparison, clarifying the distinct and complementary roles of Jenkins (CI build/test execution) and ProGet (package governance/registry) and how they integrate in the build pipeline.

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
