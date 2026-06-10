# V4-D02 Production Restore / Lock File Evidence

Date: 2026-05-25
Repository: `ATAP.Utilities-wt-100-Sprint-0007-work-items`
Baseline: `df6ad8eb feat(test): wire UsePackageReferenceForSUT in StronglyTypedIDs.Tests (V4-C05)`

## Result

V4-D02 is accepted with documented lock-file exceptions.

## Restore

- The first sandboxed restore failed while MSBuild probed `C:\Users\whertzing\AppData\Local\Microsoft SDKs`; this was an environment access denial, not a repo restore result.
- Final command: `dotnet restore ATAP.Utilities.Production.slnf --force-evaluate -v minimal`
- Final exit code: 0

## Lock File Baseline

- Production filter project count: 177
- Existing project paths in the production filter: 177
- `packages.lock.json` files for production-filter projects: 172
- Repository-wide `packages.lock.json` count after D02: 173
- New lock files produced during D02 work:
  - `src/ATAP.Utilities.AutoDoc/packages.lock.json`
  - `tests/ATAP.Utilities.CryptoMiner.Tests/packages.lock.json`

## Missing Lock File Exceptions

These five production-filter projects still do not have `packages.lock.json` files after `dotnet restore ATAP.Utilities.Production.slnf --force-evaluate` exits 0. Each is a facade/aggregator project with `<EnableDefaultItems>false</EnableDefaultItems>` and only project references in its own `.csproj`; NuGet restore completes without emitting a lock file for these aggregator nodes.

| Project | Reason |
| --- | --- |
| `src/ATAP.Utilities.ComputerInventory/ATAP.Utilities.ComputerInventory.csproj` | Facade/aggregator project; project references only. |
| `src/ATAP.Utilities.ComputerInventory/Hardware/ATAP.Utilities.ComputerInventory.Hardware.csproj` | Facade/aggregator project; project references only. |
| `src/ATAP.Utilities.ComputerInventory/ProcessInfo/ATAP.Utilities.ComputerInventory.ProcessInfo.csproj` | Facade/aggregator project; project references only. |
| `src/ATAP.Utilities.ComputerInventory/Software/ATAP.Utilities.ComputerInventory.Software.csproj` | Facade/aggregator project; project references only. |
| `src/ATAP.Utilities.IAC.Ansible/ATAP.Utilities.IAC.Ansible.csproj` | Facade/aggregator project; project references only. |

## Issues

- The restore still logs skipped project-reference paths for stale relative references to `ATAP.Utilities.ETW.csproj`; a static project-reference audit also found stale Loader references under the MessageQueue shim projects. These should be repaired before D04/D05 lock enforcement becomes strict.
- The restore reports NuGet vulnerability warnings for existing package versions, including legacy `Newtonsoft.Json`, `System.Data.SqlClient`, and `System.Security.Cryptography.Xml` usages.
- A direct restore of `src/ATAP.Utilities.AutoDoc/ATAP.Utilities.AutoDoc.csproj` reports `NU1008` because it still declares explicit `PackageReference Version` values while central package management is enabled. The production solution-filter restore exits 0, but AutoDoc should be normalized to central package versions in a follow-up.
