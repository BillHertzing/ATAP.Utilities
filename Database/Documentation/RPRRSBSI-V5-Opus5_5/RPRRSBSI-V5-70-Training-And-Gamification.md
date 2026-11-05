# RPRRSBSI-V5 Training and Gamification

> **New in V5 (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Records the developer requirement of 2026-11-05 for training-wizard progress, gamification themes, scenes and reward items, theme selection during login, and a gamification home page. Logical design for task authoring; nothing here is built. Diagram: [RPRRSBSI-V5-Training-And-Gamification.puml](RPRRSBSI-V5-Training-And-Gamification.puml). UI companion: [Ace-Outpost-Commander-Integration/40](Ace-Outpost-Commander-Integration/40-Gamification-Home-And-Login-Theme.md).

## 1. Requirement (developer, 2026-11-05)

- Tables in `ATAPUtilities` and in `Ace` represent the stages of a user's journey through the **training wizards**. As users complete training modules they are rewarded with upgraded components for the gamification screens.
- Tables represent the **gamification theme** a user selects and the set of available **gamification schemes**. A scheme has multiple **images**; within each scheme and each image there are multiple **items**. Items can be overlaid on the base scene, and higher-value items become available as the user progresses through training modules.
- The AceCommander client gets a primary **gamification page**. The user selects an initial theme when they log in, as part of the login workflow. The home page then displays a set of scenes from the selected theme; the displayable set depends on the user's training progress.

## 2. Placement under DEC-3

| Kind of data | Where | Why |
| --- | --- | --- |
| Training catalog (programs, modules, steps, prerequisites, rewards) and gamification catalog (schemes, scenes, items, value tiers, unlock rules) | `ATAPUtilities` template rows, plus the full `Ace` copies with owner columns | Open foundation content anyone can see; organizations and marketplace developers can add their own owned schemes and training in `Ace`. |
| A user's progress, unlocked items, theme selection and item placements | `Ace`-only tables, `OwnerUserId` = the user | Personal data, visible only to the user (and ACE administrators). |

A gamification scheme or a training program published by a marketplace developer is a bolt-on ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)); its template rows become `ATAPUtilities` rows through the submission process.

## 3. Catalog tables (`ATAPUtilities` templates and `Ace` copies)

All tables use Philote-backed keys, and the append/close-only state pattern for anything that changes over time.

| Table | Key columns | Notes |
| --- | --- | --- |
| `TrainingProgram` | PK, code, title, description, state (validity period) | A curriculum. |
| `TrainingModule` | PK, program FK, code, title, `Ordinal`, estimated minutes, `RewardValueTierId` FK | One unit of training, delivered by a wizard. |
| `TrainingModulePrerequisite` | module, prerequisite module | Must form a directed acyclic graph per program. |
| `TrainingWizardStep` | PK, module FK, `Ordinal`, step kind (`Content`, `Exercise`, `Quiz`, `Confirmation`), completion rule | The stages of the wizard journey. Content can be a file instantiation ([V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md)). |
| `GamificationValueTier` | PK, code, rank (1 = lowest), display name | The value ladder; higher rank = higher-value items. |
| `GamificationScheme` | PK, code, display name, description, preview image asset, state | A theme. |
| `GamificationScene` | PK, scheme FK, code, `Ordinal`, base image asset, width/height in logical units | The developer's "images" within a scheme: each is a base scene. |
| `GamificationItem` | PK, scheme FK, optional scene FK (null = usable on any scene of the scheme), code, item image asset, `ValueTierId` FK, default size, allowed placement zones, max instances per scene | The overlay items. |
| `GamificationSceneUnlockRule` | scene, required module **or** required value tier | Which scenes are displayable for which progress. |
| `TrainingModuleReward` | module, reward kind (`ValueTier`, `SpecificItem`, `Scene`), target id | What completing a module unlocks. |
| `GamificationAsset` | PK, media type, byte length, SHA-256, storage locator | Images are stored outside the table (asset store or repository file) and referenced by hash and locator; the row is a file instantiation reference. |

Requirements:

- **V5-GAM-001:** Value tiers are totally ordered by rank; an item is available to a user when the user has unlocked its tier for that scheme (or the specific item).
- **V5-GAM-002:** A scene is displayable to a user when every unlock rule on that scene is satisfied by the user's progress at the display instant; a scene with no rule is always displayable (at least one such scene per scheme, so a new user sees something).
- **V5-GAM-003:** Unlocks are computed from completed modules and their rewards; they are recorded (§4) so later catalog changes do not take away what a user earned.
- **V5-GAM-004:** Catalog content changes follow the D-3 identity rules and State history: an item's image change is a new state; changing an item's tier is a material change and creates a new item identity, so earned items are not silently revalued.

## 4. Per-user tables (`Ace`-only, owned by the user)

| Table | Key columns | Notes |
| --- | --- | --- |
| `UserTrainingModuleProgress` | user, module, validity period, `ProgressStatusCode` (`NotStarted`, `InProgress`, `Completed`, `Abandoned`) | Temporal state; completion instant is the start of the `Completed` period. |
| `UserTrainingStepCompletion` | user, step, completed at, evidence (quiz score, confirmation) | Append-only. |
| `UserGamificationUnlock` | user, scheme, unlock kind (`ValueTier`, `Item`, `Scene`), target, source module, unlocked at | Append-only; written when a module completes. |
| `UserGamificationThemeSelection` | user, scheme, validity period | The selected theme; temporal so a change keeps history. Exactly one current selection per user once onboarding completes. |
| `UserScenePlacement` | user, scene, placement id, item, x, y, scale, rotation, z-order, validity period | The user's arrangement of unlocked items on a scene; append/close-only so earlier arrangements remain. |

- **V5-GAM-010:** A placement is valid only when the item is unlocked for the user and allowed on that scene and zone, and the per-scene instance limit is not exceeded; enforced by the placement procedure.
- **V5-GAM-011:** Progress and unlock rows are written only by procedures driven by the training wizard, never directly by the client.
- **V5-GAM-012:** A user's first completed sign-in with no current theme selection SHALL route the user to theme selection (§5) before the home page.

## 5. Login workflow and home page (summary)

- **Login:** sign in (V5-65) → if `UserState` is `Active` and no current `UserGamificationThemeSelection` exists → **choose a theme** from the schemes available to the user (all `ATAPUtilities` schemes, the organization's owned schemes, purchased schemes) → record the selection → home page.
- **Home page:** load the current theme → compute the displayable scenes (V5-GAM-002) → render each scene's base image with the user's current placements → offer the unlocked, unplaced items for placement → show training progress and the next module that unlocks more.
- **Anonymous visitors** see a preview of one default scheme and the training catalog, as an incentive to register (V5-65 §4).

Details, screen states and query services: [Ace-Outpost-Commander-Integration/40](Ace-Outpost-Commander-Integration/40-Gamification-Home-And-Login-Theme.md).

## 6. Query contract

- `ReadUserGamificationHome(@UserId, @AsOfUtc)` → theme; displayable scenes with base image assets; current placements; unlocked unplaced items; next locked scene and the module that unlocks it.
- `ReadAvailableGamificationSchemes(@UserId)` → schemes the user may choose.
- `SelectGamificationTheme(@UserId, @SchemeId)`, `PlaceGamificationItem(...)`, `RemoveGamificationItemPlacement(...)`.
- `CompleteTrainingStep(@UserId, @StepId, @Evidence)` → updates progress and writes unlocks when a module completes.

All run under the caller's session identity and row-level security ([V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md)).

## 7. Open items

See [HANDOFF-V5.md](HANDOFF-V5.md): asset storage; whether theme can change after onboarding and whether placements are kept per theme; scoring and quiz rules; whether progress is per user or also per organization; first schemes and value tiers to seed; whether training content itself is RRSBS-materialized.
