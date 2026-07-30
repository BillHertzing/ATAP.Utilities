# Task 13.83 — Instantiation deployment and manifestation

Status: complete on 2026-07-30.

## Approved deployment

The operator separately approved the final live preflight for:

- target: `UTAT022\EXPWHERTZING.ATAPUtilities`
- package: `ATAPUtilities.Database.0.1.1.nupkg`
- package SHA-256:
  `02495D66DA6D640A39259E169DD230B6A49BD17627B67A4BDFD30EF758462448`
- target Flyway version: `00.02.000110`

The preflight found an online database at `00.02.000040`, zero failed Flyway
rows, valid applied checksums, and exactly six expected pending migrations
(`000060` through `000110`). Credentials were resolved only through
`dbConnectionString.ATAPUtilities.localhost.Exp.whertzing` and
`dbConnectionString.master.localhost.Exp.whertzing`; no value was recorded.

One copy-only backup was created and verified before deployment. The repository
`Invoke-Flyway` wrapper was invoked exactly once with `migrate`, the approved
package migration directory, and no `repair`, `clean`, baseline, or history
edit. It succeeded.

## Deployed-state proof

Independent read-only verification returned:

- Flyway head `00.02.000110`
- 19 successful and zero failed Flyway history rows
- strict Flyway validation exit code 0
- durable-schema verifier PASS
- corrected graph verifier PASS
- zero Sprint 0012 retired sample versions
- three typed-membership deprecation markers
- 75 current source lines
- eight immutable snapshot members
- five current manifestation artifacts
- zero incomplete provenance rows
- zero orphan bindings and zero orphan snapshot members
- exact reconstructed path
  `ATAP.Utilities\src\ATAP.Utilities.PowerShell\public\Write-ArrayIndented.ps1`
- exact 2,800 bytes and SHA-256
  `207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A`

## Approved manifestation

The operator separately approved the dry-run's exact five-entry tree below
`C:\Dropbox\ATAP.org\_generated`. The root did not exist before the dry-run,
and before/after fingerprints proved the inspection made no filesystem change.

The renderer was then invoked exactly once with provenance persistence. It
created only:

```text
C:\Dropbox\ATAP.org\_generated\
└── ATAP.Utilities\
    └── src\
        └── ATAP.Utilities.PowerShell\
            └── public\
                └── Write-ArrayIndented.ps1
```

The complete descendant inventory is exactly those four directories and one
file. The file is 2,800 bytes at the frozen SHA-256. Its unique current
database row is `RenderFromModel`, carries the same content hash, and has
complete BuildSetVersion, producing RuleInstantiation, and producing
RuleInstantiationVersion keys.

After every deployment and manifestation assertion passed, the hash-verified
temporary copy-only backup was deleted. It is not recoverable. No unrelated
target-root content was removed.

The generic physical SQL instance name `Experimental` remains prohibited and
was not created. The deployed physical instance is the supported
developer-scoped `EXPWHERTZING`.

## Evidence

Generated, ignored evidence is under `_generated/InstantiationFix/13.83/`:

- `Task-13.83-Preflight.json`
- `Task-13.83-Flyway-Info.log`
- `Task-13.83-Flyway-Validate.log`
- `Task-13.83-Deploy.json`
- `Task-13.83-Flyway-Migrate.log`
- `Task-13.83-Deployed-State-Verification.json`
- `Task-13.83-PostDeploy-Flyway-Validate.log`
- `Task-13.83-Manifestation-DryRun.json`
- `Task-13.83-Manifestation.json`

