```
applyTo: ["**/*.sql", "*/.sql"]
```

# AI instructions for SQL files

This file is a set of instructions for AI to follow when generating or modifying SQL (.sql) files in this repository.

---

## Goals

- Generate production-grade SQL functions and scripts that follow the repository's database design conventions.

---

## AI Guidelines

- You are an expert in SQL coding standards.

## Database Architecture

### Database Design

### Filesystem Layout

``` text
<repo>/
  databases/
    _shared/
      sql/                             # shared repeatables & (rare) shared versioned migrations
        R__udf_helpers.sql
        R__common_views.sql
      data/                            # shared CSVs (slow-changing)
        countries.csv
        currencies.csv
    orders/
      flyway/
        flyway.conf
        sql/
          V1__baseline_schema.sql
          V2__load_reference_data.sql      # uses BULK INSERT with ${data_dir}
          R__functions_and_helpers.sql
      data/                                # orders-specific CSVs (small, slow-changing)
        order_status.csv
    billing/
      flyway/
        flyway.conf
        sql/
          V1__baseline_schema.sql
          V3__new_indexes.sql
          R__functions_and_helpers.sql
      data/
        tax_codes.csv
  ops/                                      # optional: CI scripts, env configs, secrets templates
    flyway.dev.conf
    flyway.prod.conf
```



- Use a modular approach to database design, organizing SQL files by functionality or feature.

### Database Migration
- Use versioned migrations for schema changes.
- Use Flyway from Redgate Software for versioned migrations. Each migration should be a single SQL file with a descriptive name, following the format `V{version}__{description}.sql`. Ensure migrations are idempotent and can be applied multiple times without error.

Data-in-SQL instead of CSV
For dozens of rows (true constants), inline INSERT statements in versioned migrations are fine and remove the need to stage files. Use CSVs when: many rows, reused across DBs, or maintained by non-engineers.

hierarchyid/modules
If shared logic is complex (e.g., your rule tree UDFs), consider a dedicated shared schema (e.g., common) with repeatables that every DB consumes. This keeps shared code clearly scoped.
