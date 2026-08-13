# ATAPUtilities.Database 0.1.0 V3 Experimental release record

## Release identity

- Package: `ATAPUtilities.Database` `0.1.0`
- Deployed SHA-256: `9603A12CFBC1C02402C9CB636649BDB1DE81089B15F3480FA3DBDC7DCCB10D61`
- Package provenance commit: `8d7bc42a4f1b32f5807f7e5cc1bba4f0cef22d36`
- ProGet feed: `database-experimental` only
- BuildMaster application: `ATAPUtilitiesDatabase` (`1005`)
- BuildMaster release/build/deployment/execution: `10138` / `21279` / `21757` / `21758`
- SQL target: `ATAPUtilities` on `utat022\expWhertzing`
- Authorized tier: logical `Experimental` only

The reviewed local candidate had SHA-256
`27297CD07A57C8A45EEA84D846029CDE02055D128DFBFBA4C3DAEF0582D09FDE`.
The immutable BuildMaster artifact differs only in package timestamp, NuGet
metadata, and provenance. Independent comparison found all twelve migration and
seed payload files byte-identical. HITL explicitly approved the deployed hash.

## Deployed state

Independent verification recorded:

- one successful Flyway history row at version `00010`;
- 11 tables, 45 columns, 72 constraints, 8 stored procedures, and 1 table type;
- seed counts of 1 BuildSet, 1 BuildSetRuleSet, 1 Instantiation, 22 Philotes,
  22 Philote validity periods, 2 Rules, 2 RuleKinds, 15 RulePrimitives,
  21 RulePrimitiveInputs, 1 RuleSet, and 2 RuleSetRules;
- protected-catalog SHA-256
  `5BDDA841E245FF76EC584E667753A7C883006A40215357123F0098017BA5ADD4`,
  unchanged from the preflight;
- focused BuildMaster runner Pester: 62 passed, 0 failed; and
- deployed database Pester: 21 passed, 0 failed, including rollback-only
  mutation, rejection, and concurrency fixtures.

The package is absent from Development, Integration, QA, and stable feeds. No
later-tier database or package mutation was authorized or performed. Backup and
restore were not applicable because two independent preflight checks proved the
target database absent before creation.

## Operational corrections retained

- Select the application-scoped `DatabaseChangePackage-5Stage` pipeline. The
  invalid `global::DatabaseChangePackage-5Stage` release was purged without
  package, feed, or database mutation.
- Preload dbatools before dot-sourcing runner files whose signatures use
  `Microsoft.Data.SqlClient` types.
- If publication succeeds but apply fails, reuse and re-hash the exact captured
  immutable nupkg during the retry; do not rebuild or republish it.
- The BuildMaster service identity has one exact Git `safe.directory` entry for
  this sprint worktree and `db_owner` only in this Experimental database. These
  are lifecycle-bound operational grants, not broader repository or SQL rights.

## Evidence

Point-in-time evidence is under:

- `_generated/RPRRSBSI-V3/V3-520/`
- `_generated/RPRRSBSI-V3/V3-530/`
- `_generated/RPRRSBSI-V3/V3-540/`
- `_generated/RPRRSBSI-V3/V3-550/`
- `_generated/PhiloteTemporalValidity/PTV-610/`
- `_generated/PhiloteTemporalValidity/PTV-620/`
- `_generated/PhiloteTemporalValidity/PTV-630/`

Those generated folders are intentionally not committed. This release record is
the durable summary; the sprint planning records carry the gate and approval
history.
