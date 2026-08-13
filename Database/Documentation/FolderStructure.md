# Database folder structure

Last updated: 2026-08-09

## Active package source

```text
Database/
├── Documentation/                         # Contract, runbook, and diagram sources
├── Flyway/
│   ├── version.json                       # ATAPUtilities.Database 0.1.0
│   ├── flyway.toml                        # Active location: filesystem:./SQL
│   ├── SQL/
│   │   └── V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql
│   ├── Data/
│   │   ├── Philote.csv
│   │   ├── PhiloteValidityPeriod.csv
│   │   ├── RuleKind.csv
│   │   ├── RulePrimitive.csv
│   │   ├── RulePrimitiveInput.csv
│   │   ├── Rule.csv
│   │   ├── RuleSet.csv
│   │   ├── RuleSetRule.csv
│   │   ├── BuildSet.csv
│   │   ├── BuildSetRuleSet.csv
│   │   └── Instantiation.csv
│   ├── Archive/
│   │   ├── RPRRSBSI-PreV3/
│   │   └── RPRRSBSI-V3-Pre-PhiloteTemporalValidity/
│   └── ObsoleteSQL/                       # Excluded from the configured location
├── Powershell/
│   ├── public/                            # Operator and export entry points
│   └── tests/                             # Source and guarded database tests
├── Queries/                               # Non-migration reference queries
├── StoredProcedures/                      # Non-migration reference definitions
└── Verify/                                # Historical/other-lineage verification assets
```

Only `Database/Flyway/SQL` is an active Flyway migration location. The one active
migration creates the complete 11-table schema, loads the eleven CSVs, creates
the temporal table type and eight mutation procedures, and validates the seed
graph in one transaction.

## Archive boundary

`Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity` preserves the
superseded 13-migration V3 source and its retired temporal CSV byte-for-byte with
a manifest. Archive content is evidence only. It is outside `flyway.toml` and
must never be copied into the active `SQL` or `Data` roots for execution.

`Queries`, `StoredProcedures`, `Verify`, and `ObsoleteSQL` are not package
migration inputs. A file in one of those folders cannot change a database unless
an operator separately executes it; such execution is outside the active V3
lineage and requires its own review.

## Documentation map

- [Data dictionary](RPRRSBSI-V3-Data-Dictionary.md)
- [Relational temporal-validity ADR](ADR-Philote-Temporal-Validity-Relational-Contract.md)
- [Rebuild runbook](RebuildDatabase.md)
- [Package/source release summary](PROMOTION_SUMMARY.md)
- [Documentation index](Index.md)
