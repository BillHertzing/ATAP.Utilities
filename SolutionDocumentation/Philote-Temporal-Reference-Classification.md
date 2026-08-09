# Philote temporal residual-reference classification

Date: 2026-08-09

Task: PTV-540

## Scope and result

The repository-wide case-insensitive scan for
`Itenso|ITimeBlock|TimeBlock|timeBlocks` found 41 files after excluding only
generated output and build artifacts. Every file was classified: 10 approved
adapter/guard surfaces, eight historical archive files, 19 unrelated or
historical prose/domain/test-fixture surfaces, and four defects. The four
defects were retired on 2026-08-09, leaving zero active defects and zero
unclassified files. The literal post-retirement reproduction command returns 38
files: the 37 substantive classified surfaces plus this self-referential
classification document.

The active Flyway package has zero temporal defects: its only match is the
transition comment in the consolidated migration, and its source test explicitly
proves the retired CSV is absent. The four defects belonged to the separate
legacy Rule Export reference/PowerShell utility and never entered the active
Flyway package. They were retired after a repository-wide consumer scan found
no application or automation callers outside that self-contained legacy family.

## Approved adapter implementation and guards (10)

- `Database/Flyway/SQL/V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql`
  — transition comment names the replaced contract; active DDL contains only
  `PhiloteValidityPeriod`.
- `Database/Powershell/tests/PhiloteTemporalValidity-Source.Tests.ps1` — negative
  source guard proves the retired CSV is absent.
- `src/ATAP.Utilities.DateTime.Model/ItensoTemporalPeriodCalculator.cs` — sole
  approved private vendor adapter.
- `src/ATAP.Utilities.DateTime/ServiceCollectionExtensions.cs` — DI registration
  of the approved adapter.
- `src/ATAP.Utilities.DateTime/ReadMe.md` — names the adapter and its private
  boundary.
- `src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/JsonConverter.Shim.SystemTextJson.cs`
  — rejects the retired JSON property family.
- `tests/ATAP.Utilities.DateTime.Tests/ATAP.Utilities.DateTime.Interfaces.Unit.cs`
  — public-surface absence guard.
- `tests/ATAP.Utilities.DateTime.Tests/ATAP.Utilities.DateTime.ItensoAdapter.Unit.cs`
  — focused adapter behavior and public-surface guard.
- `tests/ATAP.Utilities.DateTime.Tests/ATAP.Utilities.DateTime.Serialization.Unit.cs`
  — converter/public-surface guard.
- `tests/ATAP.Utilities.Philote.Tests/ATAP.Utilities.Philote.Unit.cs` — legacy JSON
  rejection and public Philote surface guards.

## Historical archive (8)

- `Database/Flyway/Archive/RPRRSBSI-PreV3/ObsoleteSQL/V00.01.000040__Create_AceCommander_Schema.sql`
- `Database/Flyway/Archive/RPRRSBSI-PreV3/SQL/V00.01.000010__Create_ATAPUtilities_Core_Schema.sql`
- `Database/Flyway/Archive/RPRRSBSI-PreV3/SQL/V00.01.000300__Create_Stored_Procedure_GetRuleByName.sql`
- `Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity/Data/TimeBlock.csv`
- `Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity/MANIFEST.md`
- `Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity/SQL/V00010__Create_RPRRSBSI_V3_Core_Schema.sql`
- `Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity/SQL/V00030__Load_RPRRSBSI_V3_TimeBlock.sql`
- `Database/Flyway/Archive/RPRRSBSI-V3-Pre-PhiloteTemporalValidity/SQL/V00130__Assert_RPRRSBSI_V3_Initial_Graph.sql`

These files are outside the configured Flyway location. Their matches are
preserved evidence and must not be copied into active package roots.

## Unrelated or historical prose/domain/test fixtures (19)

- `Database/Documentation/ADR-Philote-Temporal-Validity-Relational-Contract.md`
  — pre-adoption facts and explicit replacement reasoning.
- `Database/Documentation/RRSBS-RDB-160-Source-to-Target-Disposition-Manifest.md`
  — historical source inventory.
- `Database/Documentation/RRSBS-RDB-310-Non-RRSBS-Reset-Scope-Disposition.md`
  — preserved AceCommander legacy-scope inventory.
- `SolutionDocumentation/ADR-Philote-Temporal-Validity-CSharp-Contract.md` —
  migration evidence, adapter decision, and legacy-rejection requirements.
- `SolutionDocumentation/AceCommander-Modernization-Plan.md` — unrelated
  historical roadmap phrase.
- `SolutionDocumentation/CS0246-Errors-TypeNotFound.md` — historical compiler
  incident names for files that were removed by PTV-180.
- `samples/ATAP.Console.Console01/Console01BackgroundService.cs` — comment only.
- `samples/ATAP.Service.Service01/FileSystemToObjectGraphService.cs` — comment
  only.
- `src/ATAP.Services.ConsoleMonitor/New Text Document.txt` — comment/reference
  text only.
- `src/ATAP.Utilities.ComputerInventory/Hardware/Extensions/ConvertFileSystemToGraph.cs`
  — commented legacy example.
- `src/ATAP.Utilities.ComputerInventory/Hardware/Models/PowerConsumption.cs` —
  unrelated string-format TODO.
- `src/ATAP.Utilities.CryptoCoin/Extensions/ATAP.Utilities.CryptoCoin.Extensions.cs`
  — code inside comments only.
- `tests/ATAP.Utilities.ComputerInventory.Hardware.Tests/ATAP.Utilities.ComputerInventory.Hardware.CPU.DataForTests.cs`
  — commented legacy test draft.
- `tests/ATAP.Utilities.ComputerInventory.Hardware.Tests/ATAP.Utilities.ComputerInventory.Hardware.DiskDriveEnumerable.DataForTests.cs`
  — block-commented legacy test draft.
- `tests/ATAP.Utilities.ZSandbox.Tests/ATAP.Utilities.ZSandbox.Miner.Unit.cs` —
  comment only.
- `samples/ATAP.Console.Console02/Console02Settings.Development.json` — legacy
  sample configuration fixture outside the active Philote serializer tests.
- `tests/ATAP.Utilities.ComputerInventory.Software.Tests/ATAP.Utilities.ComputerInventory.Software.ComputerSoftwareProgramSerialization.DataForTests.cs`
  — historical serializer expectation fixture.
- `tests/ATAP.Utilities.ComputerInventory.Software.Tests/SerializationStrings.Designer.cs`
  — generated accessor text for that historical fixture.
- `tests/ATAP.Utilities.ComputerInventory.Software.Tests/SerializationStrings.resx`
  — historical serializer resource fixture.

The last four fixture-family entries are not the active Philote serializer
contract. PTV-350 already records the wider legacy consumer/test failures; this
classification does not claim those unrelated suites are modernized.

## Retired defects (4)

- `Database/Queries/Query_Rule_By_Name.sql`
- `Database/StoredProcedures/GetRuleByName.sql`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/public/Export-RuleToTextFile.ps1`
- `src/ATAP.Utilities.DatabaseManagement.Powershell/tests/Unit/Export-RuleToTextFile.Tests.ps1`

These paths were deleted on 2026-08-09. The associated example script and stale
Rule Export documentation were also retired, and the module manifest no longer
exports either legacy command. The archived pre-V3 migration remains historical
evidence. See `Database/Documentation/RuleExport-Retirement.md`.

## Reproduction

```powershell
rg -l -i 'Itenso|ITimeBlock|TimeBlock|timeBlocks' `
  --glob '!_generated/**' `
  --glob '!**/bin/**' `
  --glob '!**/obj/**' `
  .
```

Original source inventory: 41 files; 41 classified; zero unclassified. The
classification document itself subsequently became one additional search hit.
After retiring the four defects, the literal reproduction command returns 38
files: 37 substantive classified surfaces plus this report; zero active defects
and zero unclassified. Generated evidence and rendered diagrams remain under
`_generated/` and are intentionally outside this source classification.
