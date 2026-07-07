# Domain & Personal Utilities

Created 2026-07-07 (Sprint 0012 Task 12.46.g; area approved by the user 2026-07-07).
START-HERE document for the **Domain & Personal Utilities** functional area — the
PowerShell modules that serve personal or domain-specific applications rather than the
ecosystem's build/database/configuration infrastructure. These modules were reviewed in
the Task 12.46 PowerShell reorganization (`PlanPowershellReorganization.md`), left in
place by design (default leave-alone for non-infrastructure modules), and grouped here
so the Functional Area Map covers the entire `src\` PowerShell surface.

## Modules in this area

| Module | Purpose |
| --- | --- |
| `src\ATAP.Utilities.FinancialAPI` | Financial data fetchers (personal finance APIs) |
| `src\ATAP.Utilities.Hydrus.Powershell` | Hydrus media-management automation |
| `src\ATAP.Utilities.Neo4j.Powershell` | Neo4j graph-database admin helpers |
| `src\ATAP.Utilities.Speech.Powershell` | Text-to-speech / speech-to-text helpers |
| `src\ATAP.Utilities.VennDiagramGenerator.Powershell` | Venn-diagram image generation |
| `src\ATAP.Utilities.VoiceRecognition.Powershell` | Voice-recognition helpers |

Each module carries its own `ReadMe.md` and `INDEX.md`; consult those for per-function
detail. Standards/coverage debt for these modules, where found, is tracked through the
scope-creep process (see SC-0248 for the Sprint 0012 audit of the infrastructure
modules; these six were not in that audit's scope).

## Related

- Functional Area Map: `SolutionDocumentation\INDEX.md`
- Reorganization plan and decisions: `PlanPowershellReorganization.md` (GitHub root)
