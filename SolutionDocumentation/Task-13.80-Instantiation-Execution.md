# Task 13.80 — Instantiation Query, Ingestion, and Execution

Task 13.80 implements the executable path for the corrected immutable
InstantiationVersion model introduced by Task 13.79.

## Loader

`Get-InstantiationVersionRuleGraph` returns:

- the ordered BuildSetVersion → RuleSetVersion → RuleVersion graph, with no
  invented Build layer;
- ordered RuleInstantiationVersion snapshot membership;
- declared primitive inputs and bindings resolved at the snapshot
  `EffectiveFrom` timestamp;
- ordered exact source lines; and
- the current planned ManifestationArtifact rows.

The loader fails closed for a missing required input, duplicate input, undeclared
input, RuleVersion outside the selected graph, or non-contiguous source-line
ordinal. Binding interval predicates prevent a later durable binding value from
changing a prior InstantiationVersion.

## Read-only ingestion proposal

`Get-InstantiationSourceModuleInventory -AsVersionProposal` hashes source files
as bytes and compares paths with ordinal case sensitivity. It reports
`Unchanged`, `Added`, `Changed`, `CaseChanged`, and `Removed` deltas and derives
stable proposed RuleVersion, RuleSetVersion, BuildSetVersion, and
InstantiationVersion identifiers. It never writes SQL or source files.

## Renderer

`Export-InstantiationManifestation -InstantiationGraph`:

- defaults to `C:\Dropbox\ATAP.org\_generated`;
- accepts only descendant relative paths;
- rejects rooted paths, drive changes, `..`, non-canonical `.` segments,
  duplicate outputs, and case-colliding outputs;
- supports inspect-only `-DryRun`;
- preserves blank and duplicate lines, CRLF/LF/None terminators, UTF-8 BOM
  policy, and final-newline state;
- compares reconstructed bytes to the planned SHA-256 before writing; and
- skips a file write when the existing target already has the exact hash.

With `-PersistProvenance`, the renderer promotes the one planned artifact row to
`RenderFromModel` and records the exact hash and producing
RuleInstantiation/RuleInstantiationVersion. Exact repeat execution is a no-op.
This in-place promotion is required by the currently deployed schema:
`UQ_ManifestationArtifact_Path` from V00.02.000060 still covers all history, so
the filtered current-path index added by V00.02.000100 cannot support closing a
row and inserting a successor at the same path. Task 13.82 carries this
constraint conflict as an adversarial-release finding.

## Verification

- Loader focused tests: 7 passed.
- Ingestion focused tests: 10 passed.
- Corrected renderer focused tests: 10 passed.
- Legacy renderer compatibility: 1 passed.
- Module export consistency and combined focused suite: 32 passed, 0 failed.
- Database-to-temporary-root integration: 1 passed against
  `ATAPUtilities_Task1380_Ephemeral`.
- The complete five-entry tree was rendered and
  `Write-ArrayIndented.ps1` matched 2,800 bytes and SHA-256
  `207425988293F2ACA9BAC4A9B72E7F18CA971EB3CF5AFE78FEB46130C219F63A`.
- Real SQL provenance promotion and exact repeat execution passed.
- The ephemeral database and copy-only backup were both removed.

Point-in-time evidence is under `_generated/InstantiationFix/13.80/`.
