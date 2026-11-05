# RPRRSBSI-V5-Opus5_5

V5 of the RPRRSBSI database design for the ATAP platform, produced 2026-11-05 by a cloud Claude session (Opus 5.5) for developer review. It succeeds the V4 family in `Database/Documentation` (the newest version of each, V4-2 where it exists) and incorporates the developer decisions and requirements of 2026-11-03 to 2026-11-05.

**Status:** design documents for task authoring. Nothing here authorizes a migration, deployment or code change. The built schema remains migrations `V00010`, `V00030`–`V00210` in `Database/Flyway/SQL`.

## What changed from V4-2

- **Vocabulary (DEC-6/7/8):** an *Instantiation* is a produced file or row; a *Materialization* is the run of a *materializer* over a *materialization specification*. The V00010 table `Instantiation` is renamed `MaterializationSpecification` by a forward migration, and a new `Instantiation` table is created.
- **Origin (DEC-1/2):** instantiations are `Asserted` or `Generated`; hand-entered content summaries use a dedicated asserted rule set.
- **Ace copy (DEC-3/9):** `Ace` holds every `ATAPUtilities` table plus Ace-only tables, with owner columns on every row and row-level security; changes start in `Ace`.
- **Developers and marketplace (DEC-4/5):** DDL Authoring mode for developer-owned tables; a reviewed bolt-on submission process that publishes tables and template rows to `ATAPUtilities` and owned copies to `Ace`.
- **New areas:** software products and processes, estates and assets, host-scoped accounts, protected authentication and access tiers, training wizards and gamification (with a login theme step and a gamification home page).

## Reading order

1. [RPRRSBSI-V5-00 Specification Overview](RPRRSBSI-V5-00-Specification-Overview.md) — decisions DEC-1…DEC-10 and the document map.
2. [HANDOFF-V5](HANDOFF-V5.md) — decisions still needed and known gaps.
3. [V5-12 Instantiation and Materialization](RPRRSBSI-V5-12-Instantiation-And-Materialization.md) and [V5-60 Ownership and the Ace Copy](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md) — the two changes that reshape the design.
4. [V5-10 Core Schema](RPRRSBSI-V5-10-Core-Schema-Enhancements.md), then the subject documents listed in [INDEX.md](INDEX.md).

## Conventions

- Requirement IDs keep their V4-2 numbers with the prefix `V5-`; new requirements use new number ranges (`V5-INST-`, `V5-OWN-`, `V5-ORG-`, `V5-AUTH-`, `V5-GAM-`, `V5-CS-A`, `V5-PDB-030`+, `V5-CORE-013`, `V5-CORE-064`…`069`, `V5-CORE-077`…`079`).
- Each carried-forward document starts with a "V5 revision" note and a "V5 changes" section; the text below them is the V4-2 text with IDs and links updated. Where that text conflicts with a V5 decision, the V5 decision wins.
- Links to unchanged V4-2 diagrams and to other `Database/Documentation` files point back to the parent folder.
