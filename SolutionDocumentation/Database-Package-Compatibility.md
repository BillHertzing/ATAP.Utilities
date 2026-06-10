# Database Package Compatibility

**Status:** Authoritative
**Sprint:** 0007
**Source task:** V4-E12 / DBA2-T06

---

## Overview

A database change package (`.nupkg`) carries a `compatibleAppPackageRanges` field in
its `db-release-unit-manifest.json`. This field lists the application package version
ranges that are **valid consumers** of the database package. Deployment tooling **must**
check this field and block the deployment if the application package version being
deployed does not fall within any listed range.

This document defines:

1. How `compatibleAppPackageRanges` is expressed.
2. How a release bundle records the database + application version pairing.
3. The validation rule and the `Test-DatabasePackageCompatibility` cmdlet.

---

## 1. Expressing Compatibility Ranges

The `compatibleAppPackageRanges` manifest field is an array of **NuGet version range**
strings following the [NuGet versioning specification][nuget-ver-spec].

### Common range expressions

| Expression       | Meaning                                     |
| ---------------- | ------------------------------------------- |
| `[1.0.0, 2.0.0)` | ≥ 1.0.0 and < 2.0.0 (exclusive upper bound) |
| `[1.0.0, 2.0.0]` | ≥ 1.0.0 and ≤ 2.0.0 (inclusive upper bound) |
| `[1.5.0,)`       | ≥ 1.5.0 with no upper bound                 |
| `(,2.0.0)`       | any version strictly below 2.0.0            |
| `[1.2.3]`        | exactly version 1.2.3                       |

### Example manifest excerpt

```json
{
  "schemaVersion": 2,
  "dbChangeUnit": "ATAPUtilities.Database.1.5.0",
  "appVersion": "1.5.0",
  "compatibleAppPackageRanges": ["[1.4.0, 1.6.0)", "[2.0.0-Alpha.1, 2.0.0)"]
}
```

This database package can be deployed alongside any application package whose version
is in **either** of the two ranges. If the application package is `1.5.3`, it falls in
`[1.4.0, 1.6.0)` → compatible. If the application package is `1.7.0`, it falls in
neither range → **blocked**.

### Multiple ranges

Multiple ranges are logically OR'd. If the application version satisfies at least one
range, the compatibility check passes.

---

## 2. Release Bundles

A release bundle (`release-bundle.json`, produced by `New-ReleaseBundle`) records the
**expected** pair:

```json
{
  "bundleId": "ATAPUtilities-1.5.0",
  "appPackageId": "ATAPUtilities",
  "appPackageVersion": "1.5.0",
  "databasePackageId": "ATAPUtilities.Database",
  "databasePackageVersion": "1.5.0",
  "feeds": {
    "app": "csharp-stable",
    "database": "database-stable"
  }
}
```

Deployment tooling reads both the bundle and the database package manifest and verifies
that `bundle.appPackageVersion` is within `manifest.compatibleAppPackageRanges`.

---

## 3. Validation Rule

> **Rule DB-C-01**: Before any database migration is applied to a non-Experimental
> environment, confirm that the application package version being co-deployed is within
> at least one range in `compatibleAppPackageRanges`. If the check fails, the deployment
> must be blocked with a human-readable error that names the failing range(s).

### Failure message format

```
Database package 'ATAPUtilities.Database' version '1.5.0' is not compatible with
application package version '1.7.0'.
Compatible ranges: [1.4.0, 1.6.0), [2.0.0-Alpha.1, 2.0.0)
```

### When to skip the check

- In the `Experimental` tier (developer scratch validation) the check is informational
  only and never blocks.
- When the database package is a pure-schema change (`changeKind: schema`) the check
  is still performed — schema changes can break application code.

---

## 4. `Test-DatabasePackageCompatibility` Cmdlet

Located at:
`src/ATAP.Utilities.BuildTooling.PowerShell/public/Test-DatabasePackageCompatibility.ps1`

### Parameters

| Parameter                      | Type     | Required | Description                                                                        |
| ------------------------------ | -------- | -------- | ---------------------------------------------------------------------------------- |
| `-DatabasePackageManifestPath` | `string` | Yes      | Path to the `db-release-unit-manifest.json` file (or the expanded package folder). |
| `-AppPackageVersion`           | `string` | Yes      | The NuGet version string for the application package being co-deployed.            |

### Return value

```powershell
[PSCustomObject]@{
    IsCompatible      = [bool]      # true if AppPackageVersion is within at least one range,
                                    # or if compatibleAppPackageRanges is empty (no constraint)
    AppPackageVersion = [string]    # echo of the input version
    MatchedRange      = [string]    # the first range that admitted the version, or $null
    FailedRange       = [string]    # the last range that was tried and rejected, or $null
                                    # if a match was found
    TriedRanges       = [string[]]  # every range from the manifest, in order tried
}
```

### Example usage

```powershell
$result = Test-DatabasePackageCompatibility `
    -DatabasePackageManifestPath 'C:\pkg\ATAPUtilities.Database.1.5.0\db-release-unit-manifest.json' `
    -AppPackageVersion '1.5.3'

if (-not $result.IsCompatible) {
    throw "Database package is not compatible with app version '$($result.AppPackageVersion)'. " +
          "Failed range: $($result.FailedRange). Tried: $($result.TriedRanges -join ', ')"
}
```

---

## 5. NuGet Version Range Parsing

The cmdlet uses `[NuGet.Versioning.VersionRange]` from the `NuGet.Versioning`
assembly when available. When the assembly is not loaded, it falls back to a
lightweight parser that supports the four common bracket notations (`[A,B)`,
`[A,B]`, `(A,B)`, `(A,B]`) and open-ended ranges (`[A,)`, `(,B)`).

---

## 6. Integration with the BuildMaster Runner

The runner `Invoke-DatabasePackageBuildMasterStage.ps1` calls
`Test-DatabasePackageCompatibility` during the `Development` stage before calling
`Promote-DatabaseChangePackage`. A ceiling violation is recorded in the evidence
bundle by `Collect-DatabasePackageEvidence`.

---

## References

- [`db-release-unit.schema.json`](../SolutionDocumentation/schemas/db-release-unit.schema.json) — manifest schema
- [`Database-Package-Consumer-Resolution.md`](Database-Package-Consumer-Resolution.md) — feed selection per tier
- [`Database-Package-Ceiling-File.md`](Database-Package-Ceiling-File.md) — version ceiling enforcement
- [NuGet versioning specification][nuget-ver-spec]

[nuget-ver-spec]: https://learn.microsoft.com/en-us/nuget/concepts/package-versioning
