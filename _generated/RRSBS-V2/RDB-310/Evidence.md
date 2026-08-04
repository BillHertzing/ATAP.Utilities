# RDB-310 Evidence

Date: 2026-08-04

## Verified source coverage

| Input | Verified result | RDB-310 result |
| --- | --- | --- |
| `RDB-015/source-permanent-object-inventory.md` | 64 persistent tables, 7 views, 5 procedures, 45 transient staging tables, and 47 CSV inputs | All 25 RDB-160 archived non-RRSBS tables, all views, all procedures, transient staging, and unreferenced seed inputs receive a disposition. |
| `RDB-160/PermanentObjectDispositionRegister.csv` | 25 archived non-RRSBS permanent tables | Tags (4) and Gmail (1) carry; ATAPUtilities user scope (3) and AceCommander scope (17) preserve. |
| `RRSBS-RDB-300-Flyway-Allocation-and-Bootstrap-Contract.md` | V2 `0.0.1` / `V00010` allocation; Tags/Gmail are reset scope; other deferred scope remains untouched | No whole-database-reset ambiguity remains in the RDB-310 plan. |

The RDB-310 decision document SHA-256 after the static coverage check is
`AD3F8ABC7B6204C5437CB1775E1376095B01CF4F0AE66DC0251AA8CF5EB1CF5D`.

## Static validation commands

```powershell
$rdb160 = Import-Csv '_generated/RRSBS-V2/RDB-160/PermanentObjectDispositionRegister.csv'
($rdb160 | Where-Object Disposition -eq 'archive').Count # expected: 25
Get-FileHash 'Database/Documentation/RRSBS-RDB-310-Non-RRSBS-Reset-Scope-Disposition.md' -Algorithm SHA256
```

The commands above are source-only validation.  They do not access a database,
execute a reset, or assert deployed state.

## Assertions deliberately not made

- No live catalog or row-count claim is made; RDB-010B remains incomplete.
- No package, baseline migration, seed, or SQL fragment exists yet.
- No actual target has been approved or reset.
- No GUID collision proof is claimed; that remains RDB-320.
