# ATAPUtilities.Database 0.1.6 V00070 Five-Tier Release Record

## Outcome

`ATAPUtilities.Database` version `0.1.6` was built once and promoted through
Experimental, Development, Integration, QA, and Production on 2026-09-01. The
same package is available in `database-stable` and is applied to every canonical
UTAT022 `ATAPUtilities` database instance.

The release introduced migration
`V00070__Create_Ace_AISupervisor_Telemetry.sql`. Independent verification found
the expected six successful Flyway migrations, no failed Flyway rows, exactly
one V00070 history row, and the complete V00070 object and permission contract
at every tier.

## Immutable identity

- BuildMaster application: `ATAPUtilitiesDatabase` (`1005`)
- BuildMaster release: `10186`, release number `0.1.6`
- BuildMaster build: `21341`, build number `1`
- Pipeline: `DatabaseChangePackage-5Stage`
- Package: `ATAPUtilities.Database.0.1.6.nupkg`
- Package length: `37,507` bytes
- Package SHA-256:
  `E9CA804EFF2A25735CB3AC22B08D1F6A790C5E241BA54F3437FE82D9F41ACCCA`
- Package source commit: `341bcaa87aaa4423b9da8c478cba43a0be73f0bd`
- V00070 SHA-256:
  `501B2C9486C81C706C7C07BB8912053FBE91A5559865C43B57527DDB7E5453C8`

Each tier-specific verifier downloaded the package from that tier's ProGet
feed and compared its length and SHA-256 with the captured build artifact.

## Tier deployment evidence

| Tier | Parent execution | Target execution | Feed | Gate |
| --- | ---: | ---: | --- | --- |
| Experimental | `21995` | `21996` | `database-experimental` | Passed |
| Development | `21999` | `22000` | `database-development` | Passed |
| Integration | `22001` | `22002` | `database-integration` | Passed |
| QA | `22003` | `22004` | `database-qa` | Passed |
| Production | `22005` | `22006` | `database-stable` | Passed |

The independent evidence files are:

- [Experimental verification](../_generated/Sprint0015/Task15.185/b/AISUPERVISOR-DB02/release/experimental-verification.json)
- [Development verification](../_generated/Sprint0015/Task15.185/b/AISUPERVISOR-DB02/release/development-verification.json)
- [Integration verification](../_generated/Sprint0015/Task15.185/b/AISUPERVISOR-DB02/release/integration-verification.json)
- [QA verification](../_generated/Sprint0015/Task15.185/b/AISUPERVISOR-DB02/release/qa-verification.json)
- [Production verification](../_generated/Sprint0015/Task15.185/b/AISUPERVISOR-DB02/release/production-verification.json)

## Higher-tier recovery points

The Integration, QA, and Production gates required a non-empty full backup,
an independently calculated SHA-256, and a successful SQL Server
`RESTORE VERIFYONLY` before the next tier could proceed.

| Tier | Backup length | Backup SHA-256 | Restore verification |
| --- | ---: | --- | --- |
| Integration | `3,395,584` | `4414BC3B7F489F5F64AA00240B993EC2C41CD2C54DC80925D72A25E6CE717B2D` | Passed |
| QA | `3,592,192` | `FCB43722001E223BB9E476AD563A6B0A77BDA9A0F995979C0551F01515203123` | Passed |
| Production | `3,461,120` | `73715CA18567B770ADB53586FA560006D692190A6450B2AEDC4727ECD7BB73C1` | Passed |

The backup sets do not contain embedded SQL Server backup checksums. Their
readability and structure were verified with `RESTORE VERIFYONLY`, and their
immutable file identities are recorded with SHA-256.

## Deployment-principal and database repair

Before promotion beyond Development, the authorized UTAT022 repair created the
missing Integration, QA, and Production `ATAPUtilities` databases using each
instance's current defaults. It then reconciled the `UTAT022\SvcBuildMaster`
login by SID on all five instances and confirmed the mapped database principal
is a member of `db_owner`.

The SID-aware implementation preserves an existing mapped username, including
the pre-existing `UTAT022\SvcBuildmaster` principal on Experimental, instead of
attempting to create a conflicting short-name user. The implementation and its
focused tests are committed as `4378431330368f3306d0dbb0458c52e0185fb4b8`.

- [Database creation evidence](../_generated/Sprint0015/Task15.185/i/utat022-v00070-unblock/database-create-and-principal-apply.json)
- [Principal reconciliation evidence](../_generated/Sprint0015/Task15.185/i/utat022-v00070-unblock/principal-reconciliation-after-create.json)
- [Unexecuted rollback plan](../_generated/Sprint0015/Task15.185/i/utat022-v00070-unblock/rollback-plan-not-executed.md)

## Verification contract

Every tier passed these independent checks:

- BuildMaster parent and target executions ended successfully without warnings.
- The downloaded tier package matched the captured package byte-for-byte.
- The archive contained exactly six migrations and eleven seed files.
- V00070 inside the package matched its expected SHA-256.
- A disposable rehearsal database was created, migrated, and dropped.
- Flyway history was exactly `00010,00030,00040,00050,00060,00070`.
- V00070 appeared exactly once and no failed Flyway rows existed.
- Seven tables, two table types, four procedures, seven append-only triggers,
  two roles, and six execute grants were present.
- No rehearsal database remained.

## Adversarial closeout

The release checks reject a rebuilt or substituted package, a feed with
different bytes, extra or omitted migrations, a duplicate or failed V00070
history row, an incomplete V00070 object contract, a surviving rehearsal
database, and a missing or unreadable higher-tier backup. No Flyway repair was
used, and no rollback was required.
