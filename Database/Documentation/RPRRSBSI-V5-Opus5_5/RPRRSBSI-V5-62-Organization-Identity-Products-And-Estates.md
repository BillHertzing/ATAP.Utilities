# RPRRSBSI-V5 Organization, Identity, Products and Estates

> **New in V5 (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Records the developer requirements of 2026-11-04 on software products, development processes, host-scoped accounts and deceased persons' households, against the built organization model (V00160–V00210). Designs here are **proposals**; the decisions are listed in [HANDOFF-V5.md](HANDOFF-V5.md). Under DEC-3 every table below is an `Ace` table with owner columns and, where a template makes sense, an `ATAPUtilities` template twin ([V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md)).

## 1. Built baseline (checked in SQL)

| Object | Built shape |
| --- | --- |
| `ACE.OrganizationFactProvenance` | Every organization fact's `PhiloteId`; `PrincipalId`, `SourceReference`, occurred/recorded UTC; `OriginKind` `Manual` or `Template` with template id/revision/hashes. V5: `Manual` → `Asserted` ([V5-12](RPRRSBSI-V5-12-Instantiation-And-Materialization.md)). |
| `ACE.OrganizationEntity` | `EntityTypeCode` ∈ `Person`, `Household`, `Organization`, `Host`, `Project`. |
| `ACE.Person` | `DisplayName`, `ClaimStatusCode` ∈ `Self`, `Placeholder`, `Invited`, `Claimed`. No life state. |
| `ACE.Organization`, `ACE.Household` | Household is an organization subtype; no state. `CombinedHouseholdLink` joins households. |
| `ACE.Membership` | Person in organization; `IsPrimary`; `MembershipKindCode` = `Unspecified` only. |
| `ACE.Host`, `ACE.HostAffiliation` | Host in organization as `Owner` or `SharedWith`. |
| `ACE.User`, `ACE.UserState` | `User.PersonId` links the account to a person; state `Pending`, `Active`, `Suspended`, `Closed`. |
| `ACE.UserIdentityBinding(+State)` | `IdentityKindCode` = `LocalAccount` only; `HostId`; Windows SID; requested account name; state `Pending`, `Verified`, `Revoked`. |
| `ACE.Project(+State)`, `ACE.ProjectOwnership`, `ACE.RoleAssignment` | Project owned by a **person**; roles `Developer`, `Administrator` scoped to a household or project. |
| `ACE.ReadOrganizationEligibility` (V00190) | Returns a membership/affiliation row only where the person's organization and the host's organization are the **same** organization, all valid at one instant. |

## 2. Host-scoped Windows accounts

**Finding.** A Windows account in the built model is not an external identity. A `UserIdentityBinding` is "this application user is the local account with this SID on this host", and eligibility requires that host and person share an organization. The developer's expectation (2026-11-04) is already the design.

- **V5-ORG-001:** Documentation and UI text SHALL describe a binding as "a link between an application user and a local Windows account on a specific host that belongs to, or is shared with, the user's organization".
- **V5-ORG-002 (proposed):** The binding-creation procedure SHALL refuse a binding unless, at the binding's start instant, the user's person has a membership in an organization that has a `HostAffiliation` to the host. Today the rule is enforced only when reading.
- **V5-ORG-003 (proposed, optional):** Materialize `HostAccount(HostId, SecurityIdentifier, AccountName, state)` if accounts need their own lifecycle. Domain or cloud identities (Active Directory, Entra ID) would be genuinely external and need new `IdentityKindCode` values.

## 3. Software products and development processes

- **V5-ORG-010:** An organization owns software products and software development processes; a software product is built with a development process (developer requirement, 2026-11-04).

| Proposed table | Key columns | Notes |
| --- | --- | --- |
| `SoftwareProduct` | PK = `PhiloteId`, code, display name, owner columns | Organization-owned (`OwnerOrganizationId`). A marketplace bolt-on is a software product ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)). |
| `SoftwareProductState` | validity period, lifecycle (`Planned`, `Active`, `Retired`) | Follows `ProjectState`. |
| `SoftwareDevelopmentProcess` | PK = `PhiloteId`, code, display name, `BuildSetId` (or ExpertSystem id), owner columns | A process is the RRSBS definition that materializes a product. |
| `SoftwareProductBuiltWithProcess` | product, process, validity period | Temporal: a product can change process. |
| `ProductRepository` | product, `Repository` (V00100) | Connects to the built ContentSummary repository identity. |

- **V5-ORG-011:** `OrganizationEntity.EntityTypeCode` gains `SoftwareProduct` and `SoftwareDevelopmentProcess` (forward migration changing its `CHECK`).
- **V5-ORG-012:** Decide the relation between `ACE.Project` and `SoftwareProduct`: keep both (a project produces products), or merge. Either way, project ownership by an **organization** must become possible; today `ProjectOwnership.OwnerPersonId` allows only a person.
- **V5-ORG-013:** The Sprint 0016 Codex-V3 proposals for repositories, clones and worktrees (`Org.Repository`, `Org.RepositoryClone`, `Org.Worktree`, shown in `../Ace_Schema.puml` but **not built**) are candidates to attach products to source code; they are not adopted by V5.

## 4. Deceased persons, households, executors and assets

Developer requirement (2026-11-04): a person in a household may be deceased; the household keeps its assets until an executor is assigned; the executor transfers assets to other organizations; the household passes from an "intestate" stage to "closed" once it has no assets.

| Proposed table | Key columns | Notes |
| --- | --- | --- |
| `PersonState` | person, validity period, `LifeStatusCode` (`Living`, `Deceased`), date of death, evidence reference | Temporal, follows `UserState`. |
| `HouseholdState` | household, validity period, `EstateStageCode` | Stages below. |
| `Estate` | household, deceased person, `WillStatusCode` (`Unknown`, `Testate`, `Intestate`), jurisdiction | *Intestate* means "no valid will"; it describes the estate, not a stage, so it is an attribute here rather than a household stage. |
| `EstateRoleAssignment` | estate, person, `RoleCode` (`Executor`, `Administrator`), validity period, evidence | Alternatively extend `ACE.RoleAssignment.RoleCode`. |
| `Asset` | PK = `PhiloteId`, asset kind, description, owner columns | Hosts, software products, bolt-on entitlements and other holdings can be assets. |
| `AssetOwnershipState` | asset, owning organization, validity period | Temporal ownership. |
| `AssetTransfer` | asset, from organization, to organization, authorized by (estate role), effective instant, evidence | Event; closes one ownership state and opens the next. |

Proposed household stages (`EstateStageCode`): `Active` → `DeceasedUnadministered` (a member died; no executor yet; assets stay) → `UnderAdministration` (executor or administrator assigned; transfers allowed) → `Closed` (no assets remain).

- **V5-ORG-020:** `Closed` requires that no `AssetOwnershipState` for the household is open at the closing instant.
- **V5-ORG-021:** Only a person holding an active `Executor` or `Administrator` estate role may authorize an `AssetTransfer` out of a household in `UnderAdministration`.
- **V5-ORG-022:** Legal terms are used as in the developer notes; jurisdiction-specific rules are out of scope until a target jurisdiction is chosen.

## 5. Roles and rights

V5 needs more than `Developer` and `Administrator`. Proposed capability codes (granted per user, temporal): `DdlAuthoring`, `MarketplaceDeveloper`, `MarketplaceReviewer`, `AtapMaintainer` ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)); `AceAdministrator` ([V5-65](RPRRSBSI-V5-65-Protected-Authentication.md)); estate roles above. Decision needed: extend `ACE.RoleAssignment` (today scoped to household or project) or add a separate user-capability table (recommended, because these rights are scoped to the platform, not to a household or project).

## 6. Open items

See [HANDOFF-V5.md](HANDOFF-V5.md): project vs product; organization ownership of projects; capability table; estate stages and asset kinds; write-time same-organization check for bindings.
