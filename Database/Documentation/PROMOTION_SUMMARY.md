# ATAPUtilities.Database 0.1.0 source and release summary

Status: source accepted at Gate PTV-G4; unpublished and uninstalled.

## Exact artifact contract

| Property | Accepted value |
| --- | --- |
| Package ID | `ATAPUtilities.Database` |
| Version | `0.1.0` |
| Active migration | `V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql` |
| Active CSV inputs | 11 |
| Tables | 11 |
| Columns | 45 |
| Named constraints | 72 |
| Temporal procedures | 8 |
| Temporal table types | 1 |
| Initial Philotes | 22 |
| Initial validity periods | 22 |

The PTV-460 local candidate was 18,213 bytes with SHA-256
`3749DCEFDE8D4890786F2F41184BE3CD94DE8DEC6EE19CA601115AC452735A89`.
That hash identifies the accepted unpublished rehearsal artifact; any later
candidate must be independently verified at its authorization gate.

## Lineage

The active package begins from one consolidated initial migration. The
superseded 13-migration pre-adoption V3 sequence is preserved under
`Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity` and is not an
active migration source. Its retired temporal CSV is archive evidence, not seed
input.

The active temporal contract is `PhiloteValidityPeriod`: half-open
`[ValidFromUtc, ValidToUtc)` business-validity intervals linked by exact
predecessor ends. The package contains one initially open period for each of the
22 Philotes.

## Promotion boundary

Gate PTV-G4 approves source and documentation alignment only. It does not
publish the package or authorize ProGet, BuildMaster, permanent SQL Server,
promotion, installation, or deployment activity. Those actions require the
later package/feed and exact-target gates and must use the unchanged approved
identity and content.

Logical tier names such as experimental or development describe package/feed
stages. They are not SQL Server instance names. The developer-scoped SQL Server
instance in the rehearsal evidence is `utat022\expWhertzing`; no instance named
`Experimental` exists.
