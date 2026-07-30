# Task 13.79 — Corrected ATAP.org InstantiationVersion 1

Task 13.79 establishes the first corrected RRSBS graph that can reconstruct an
authored source file exactly. The graph targets:

```text
ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1
```

The frozen source is 2,800 bytes, UTF-8 without BOM, 75 CRLF-terminated source
lines, with a final newline. Its SHA-256 is
`207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A`.

## Approved source-line model

The Task 13.79.g HITL decision approved
`ATAPUtilities.RuleInstantiationVersionSourceLine` as a separate immutable,
ordered entity. Each row belongs to one `RuleInstantiationVersion` and stores:

- a contiguous one-based `Ordinal`;
- exact `LineText`, including blank or duplicate values;
- the exact `LineEnding` (`CRLF`, `LF`, or `None`);
- the effective-dating interval.

This is smaller and more enforceable than synthetic binding names such as
`Line0001`. `RuleInstantiationBinding` remains the scalar-input surface for
declared values such as encoding, BOM, final-newline state, and path values.
Source lines are version-snapshotted and cannot be updated or deleted.

## Migration and verification

- Forward migration:
  `Database/Flyway/SQL/V00.02.000110__Seed_ATAPorg_Instantiation_V1.sql`
- Read-only verifier:
  `Database/Verify/PromotionUnit_00.02/Verify_ATAPorg_Instantiation_V1.sql`
- Generated rehearsal evidence:
  `_generated/InstantiationFix/13.79/Task-13.79-Clone-Rehearsal.json`

The migration adds only the three reused Path/PowerShell primitive definitions
when a historical tier lacks them. It then seeds eight Rules and RuleVersions,
two RuleSets and RuleSetVersions, one BuildSet and BuildSetVersion, eight
RuleInstantiations and RuleInstantiationVersions, one InstantiationVersion
snapshot, 75 source-line rows, and five planned artifacts. No `Build` or
`BuildVersion` entity is introduced.

The rehearsal restored a copy of the UTAT022 Experimental database at schema
`00.02.000040`, applied `000060` through `000110`, executed `000110` a second
time, and ran the verifier. Both runs produced 75 source lines, eight snapshot
members, and five planned artifacts. The verifier reconstructed the exact path
and the 2,800-byte file with the frozen SHA-256. The temporary database and
copy-only backup were removed.

## Deployment state

Task 13.79 is source-complete and rehearsal-verified. It does not deploy the
migration to Experimental. Tasks 13.82 and 13.83 own immutable bundle rehearsal,
hash approval, deployment, and the separately approved filesystem
manifestation.
