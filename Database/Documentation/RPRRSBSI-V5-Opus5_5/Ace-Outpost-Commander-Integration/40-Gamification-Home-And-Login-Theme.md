# AceCommander Gamification Home Page and Login Theme Step

> **New in V5 (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Client UI companion of [RPRRSBSI-V5-70 Training and Gamification](../RPRRSBSI-V5-70-Training-And-Gamification.md). Requirements only; it authorizes no code change. Any implementation must load the Blazor/Syncfusion rules before editing `.razor`, `.razor.cs` or Syncfusion-related files (repository rule R-37).

## Login workflow

- **AC-GAM-001:** After a successful sign-in, if the user has no current theme selection, AceCommander SHALL show a **Choose your theme** step before any other page.
- **AC-GAM-002:** The step SHALL list the schemes returned by `ReadAvailableGamificationSchemes`, each with its preview image, name and description; the user picks one and confirms.
- **AC-GAM-003:** Confirming calls `SelectGamificationTheme`; on success the user lands on the gamification home page.
- **AC-GAM-004:** The step SHALL keep the existing sign-in contract: navigation stays in the same circuit (a full-page reload resets it today, per the 2026-11-03 identity handoff).
- **AC-GAM-005:** A user with a current selection skips the step.

## Gamification home page

- **AC-GAM-010:** The home page is the primary landing page for signed-in users.
- **AC-GAM-011:** It shows the displayable scenes of the selected theme (`ReadUserGamificationHome`), each as the base scene image with the user's placed items overlaid at their stored position, scale, rotation and z-order.
- **AC-GAM-012:** Locked scenes appear as locked tiles naming the training module that unlocks them.
- **AC-GAM-013:** An item tray shows unlocked, unplaced items for the current scene; the user drags an item onto the scene and can move, scale, rotate, layer or remove it. Each change calls the placement procedures; rejected placements show the reason (not unlocked, zone not allowed, limit reached).
- **AC-GAM-014:** A progress panel shows training progress and the next module, linking to the training wizard.
- **AC-GAM-015:** When a module completes, the page shows the newly unlocked tier, items or scenes.

## Training wizard

- **AC-GAM-020:** Each training module runs as a step wizard (`TrainingWizardStep` order); completing a step calls `CompleteTrainingStep`; the final step completes the module and triggers rewards.

## Anonymous visitors

- **AC-GAM-030:** Anonymous visitors see a read-only preview scene of a default scheme and the training catalog, with a call to register.

## Diagram viewer

- **AC-GAM-040:** The gamification tables appear in the diagram viewer like other `Ace` tables; personal tables show metadata only, never another user's rows ([V5-65](../RPRRSBSI-V5-65-Protected-Authentication.md) §2).

## Open UI questions

Recorded in [HANDOFF-V5.md](../HANDOFF-V5.md): can the theme be changed later from settings, and are placements kept per theme; scene canvas technology (Syncfusion Diagram, HTML canvas or SVG); mobile layout; accessibility of drag-and-drop (keyboard placement).
