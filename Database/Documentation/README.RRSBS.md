# RPRRSBSI V3 database schema

## Overview

The active ATAPUtilities RPRRSBSI V3 database contract stores stable Philote
identity, Rule kinds and primitives, exact Rules, ordered RuleSet and BuildSet
membership, Instantiations, and Philote business-validity periods.

The canonical source is
`Database/Flyway/SQL/V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql`.
It is the sole active migration in package `ATAPUtilities.Database` `0.1.0`.

## Table inventory

1. `Philote`
2. `PhiloteValidityPeriod`
3. `RuleKind`
4. `RulePrimitive`
5. `RulePrimitiveInput`
6. `Rule`
7. `RuleSet`
8. `RuleSetRule`
9. `BuildSet`
10. `BuildSetRuleSet`
11. `Instantiation`

Every Philote-bearing entity uses the same GUID for its entity ID and
`PhiloteId`. Ordered memberships and primitive inputs use zero-based ordinals.
The initial graph contains two kinds, eight primitives, 21 primitive inputs, two
Rules, one RuleSet, two RuleSet members, one BuildSet, one BuildSet member, one
Instantiation, 22 Philotes, and 22 initial validity periods.

## Temporal validity

`PhiloteValidityPeriod` stores business-valid identity existence as half-open
intervals. A null end is open-ended. Gaps are valid; overlaps, duplicate starts,
duplicate ends, multiple roots, multiple open ends, broken predecessor links,
zero/reversed intervals, branches, and cycles are rejected by the exact
constraint set and procedure validation.

Applications mutate a Philote's set through the eight approved procedures. The
procedures serialize writers per Philote, apply whole-set repairs atomically,
and return the complete ordered five-column persistence result. Direct table DML
is a migration/test concern, not the application boundary.

## Source and operator references

- [Physical data dictionary](RPRRSBSI-V3-Data-Dictionary.md)
- [Temporal relational ADR](ADR-Philote-Temporal-Validity-Relational-Contract.md)
- [Core schema overview](CoreSchema_Overview.puml)
- [Rebuild runbook](RebuildDatabase.md)
- [Package/source summary](PROMOTION_SUMMARY.md)

The archived pre-adoption lineages are historical evidence only and must not be
applied to the active V3 package.
