# RPRRSBSI V4 Ace and Mobile Integration Specification Suite

Status: requirements and architecture specification companion to Task 15.140.b.

This suite integrates the Ace Outpost mobile SQL decision record and the operator's
2026-08-28 Ace-schema requirements with the RPRRSBSI V4 design produced by Task
15.140.b. It does not edit, replace, or claim completion of the seven Task 15.140.b
design documents. It supplies additional normative requirements, use cases, architecture
constraints, security boundaries, and acceptance criteria for later implementation work.

## Authority order

When two sources conflict, later explicit operator direction governs the new work:

1. the operator's 2026-08-28 Ace-schema and publication-path requirements;
2. ratified Task 15.140.a decisions and the Sprint 0015 Decision Register;
3. the seven Task 15.140.b RPRRSBSI V4 design documents;
4. accepted decisions in `AceOutpost SQL Database Decision Document.pdf`; and
5. historical V1/V2/V3 documents used only for traceability.

This order does not rewrite historical documents. A conflict is recorded as an amendment
or implementation gate in this suite.

## Normative language

`SHALL` is mandatory. `SHOULD` is the preferred architecture unless a later decision
records an exception. `MAY` is optional. `HITL-PENDING` identifies an unresolved design
choice that SHALL NOT be inferred during implementation.

## Controlling additions

- The `ATAPUtilities` database core-schema migrations MAY create the `Ace` schema and
  MAY create or evolve explicitly declared Ace objects. This permission was clarified
  by the operator on 2026-08-28 and supersedes the earlier dictation that said the core
  migrations did not create Ace.
- Every core-migration change to `Ace` SHALL be explicit in the migration manifest,
  tested against the Ace parity and isolation contracts, and applied by a deployment
  principal distinct from ordinary AceCommander runtime access. A separate Ace migration
  lineage is an implementation option, not a requirement established by this suite.
- `Ace` SHALL contain an Ace-owned duplicate of every application table in
  `ATAPUtilities` except the authoritative `User` table. The duplication contract is
  structural parity, not shared row identity or automatic bidirectional replication.
- AceCommander SHALL be predominantly read-only against `ATAPUtilities` and read/write
  against `Ace`.
- In restricted `ModifyPlugin` mode, AceCommander MAY propose and apply authorized DDL
  only within the Ace-owned change boundary. It SHALL NOT modify `ATAPUtilities` DDL.
- A user SHALL see and modify only Ace data owned by or shared with that user's durable
  user ID. DDL visibility and mutation SHALL be restricted to authorized plugin-change
  workspaces and Ace objects; ordinary row ownership cannot make shared DDL user-local.
- The sole Ace-to-ATAP publication path is the operator-named
  `productionPublishNewOrModifiedPLugin` pathway. Its detailed design remains
  `HITL-PENDING`; until ratified, no data or DDL transfer from `Ace` to
  `ATAPUtilities` is authorized.
- Ace Outpost Windows, Android, and iOS variants SHALL operate offline, persist a
  minimal local projection, execute approved expert-system/plugin work locally where
  permitted, and synchronize selectively through device-initiated communication.

## Document map

| Document | Purpose |
| --- | --- |
| [Requirements Catalog](10-Requirements-Catalog.md) | Functional, data, security, expert-system, synchronization, and quality requirements. |
| [Use Cases and Analysis Scenarios](20-Use-Cases-And-Analysis-Scenarios.md) | Actors, preconditions, flows, failure paths, and expert-system analysis scenarios. |
| [Target Architecture](30-Target-Architecture.md) | Central schemas, edge services, local stores, APIs, execution planes, and deployment ownership. |
| [Data, Tenancy, and Synchronization](40-Data-Tenancy-And-Synchronization.md) | Schema parity, user segmentation, projection stores, change envelopes, conflicts, and retention. |
| [Plugin Security and Production Publication](50-Plugin-Security-And-Production-Publication.md) | Plugin trust, `ModifyPlugin`, malware defenses, and the closed publication boundary. |
| [Acceptance and Traceability](60-Acceptance-And-Traceability.md) | Source mapping, conformance tests, decision gates, and implementation slicing. |

## Source set

- `Database/Documentation/RPRRSBSI-V4-00-Specification-Overview.md`
- `Database/Documentation/RPRRSBSI-V4-05-Source-Synthesis-And-Traceability.md`
- `Database/Documentation/RPRRSBSI-V4-10-Core-Schema-Enhancements.md`
- `Database/Documentation/RPRRSBSI-V4-20-Seed-Data-And-Loaders.md`
- `Database/Documentation/RPRRSBSI-V4-30-Tags-Expert-System.md`
- `Database/Documentation/RPRRSBSI-V4-40-Mechanized-Engineering.md`
- `Database/Documentation/RPRRSBSI-V4-50-Layered-Implementation-Handoff.md`
- `_Planning/InformationForTheFuture/AceOutpost SQL Database Decision Document.pdf`
- `_Planning/InformationForTheFuture/InstantiationInfo.md`
- `Database/Documentation/CrossSchema_UserView_Design.md`

## Scope boundary

This suite defines requirements and architecture. It creates no SQL, Flyway migration,
schema, seed, API, mobile database, signing root, credential, deployment, or live-system
change. Every implementation increment must cite requirement IDs from this suite and
the applicable V4 requirement and decision IDs.
