# Build-DocumentationOverview — draft for integration

**Status:** draft. Tested in isolation; not yet added to any repository, module manifest, or feed.

## What it is

A new public command for `ATAP.Utilities.BuildTooling.AiRendering.PowerShell`, the child
module that already owns documentation-adjacent tooling (`Convert-DiagramsToImages`, the
repository instruction combiners). It regenerates the factual half of the cross-repository
documentation overview:

| Output (under `_generated/DocumentationOverview/` by default, SC-0033) | Content |
| --- | --- |
| `DocumentationCatalog.csv` | One row per tracked documentation file: Repository, Area, IsEvidence, Path, Type, SizeBytes, Title, FirstSentence |
| `UnresolvedLinks.csv` | Every unresolved relative Markdown link in curated (non-evidence) documents |
| `DocumentationOverview.Summary.json` | Totals, per-repository counts, source branch and commit, missing expected documents |
| `DocumentationOverview.Statistics.md` | Readable tables for the four outputs above, plus PlantUML diagrams that have no `title` |

The narrative README (glossary, reading paths, findings) stays human-authored.

## Files in this draft

```text
src/ATAP.Utilities.BuildTooling.AiRendering.PowerShell/
  public/Build-DocumentationOverview.ps1          # the command (functions only; no top-level code)
  tests/Build-DocumentationOverview.Tests.ps1     # Pester 6.2 suite, 18 tests
```

## Verification already done (in a Linux container, PowerShell 7.4.6)

| Claim | Evidence |
| --- | --- |
| 18/18 Pester 6.2.0 tests pass | `Invoke-Pester` on the test file |
| The tests caught and fixed a real defect: a single-line `git` result was unrolled to a string, and `[0]` then returned its first character (branch showed as `m`) | first run 17/18 → fix → 18/18 |
| Acceptance against the five real clones: 2,060 documents in about 10 seconds | `acceptance/` run |
| Totals match the earlier Python survey: 2,043 + 17 `.uml` files that the survey did not scan | per-repo counts |
| Link totals match exactly for ATAP.Utilities (2,151/541), Ace (110/3), SharedVSCode (113/16), ATAP.IAC (42/0). _Planning shows 737/54 vs 714/48 because the survey skipped all of `.github/`; the command excludes only the rendered sub-folders | `Statistics.md` |
| `-ExpectedDocument` reports `SolutionDocumentation/Rules Compendium.md` as Missing | `Summary.json` |
| Repository working trees are untouched (`git status` is clean) | `git status --short` |

**Not verified:** a Windows run, a PSFramework-loaded run (the fallback path ran instead),
module import through the `.psm1`/`.psd1`, and promotion through the tier ladder.

## Integration steps (in the ATAP.Utilities sprint worktree)

1. Copy the two files into `src\ATAP.Utilities.BuildTooling.AiRendering.PowerShell\public\` and `tests\`.
2. In `ATAP.Utilities.BuildTooling.AiRendering.PowerShell.psm1`, add `'Build-DocumentationOverview',` to the `Export-ModuleMember -Function` list (it is alphabetical; place it first).
3. In the `.psd1`, add it to `FunctionsToExport` if that list is explicit.
4. Update `ReadMe.md` ("public surface contains eleven commands" → twelve), `INDEX.md`, and `ReleaseNotes.md`:

   ```markdown
   - Add `Build-DocumentationOverview`: catalogs tracked documentation across one or more
     repository roots and writes a catalog CSV, an unresolved-link CSV, a JSON summary and a
     statistics page under `_generated/DocumentationOverview` (SC-0033). Read-only;
     supports -WhatIf.
   ```

5. Run the suite with profiles loaded (no `-NoProfile`):

   ```powershell
   pwsh -Command "Import-Module Pester -RequiredVersion 6.2.0; Invoke-Pester -Path '.\src\ATAP.Utilities.BuildTooling.AiRendering.PowerShell\tests\Build-DocumentationOverview.Tests.ps1' -Output Detailed"
   ```

6. Version-bump and promote with the `build-deploy-module` skill. "Done" means installed in
   the consuming scope, not just built.

## Typical use

```powershell
$roots = @(
  ${SPRINT_WORKTREE_PATH_ATAP_UTILITIES}, ${SPRINT_WORKTREE_PATH_ACE},
  ${SPRINT_WORKTREE_PATH_SHAREDVSCODE}, ${SPRINT_WORKTREE_PATH_ATAP_PLANNING},
  ${SPRINT_WORKTREE_PATH_ATAP_IAC}
)   # substitute the real worktree paths; the command never guesses a root

Build-DocumentationOverview -RepositoryRoot $roots `
  -ExpectedDocument 'ATAP.Utilities:SolutionDocumentation/Rules Compendium.md',
                    'ATAP.Utilities:SolutionDocumentation/INDEX.md',
                    'SharedVSCode:SolutionDocumentation/INDEX.md'
```

## Design decisions to confirm

1. **Home module:** AiRendering (it already owns diagram rendering). Alternative: a new
   `ATAP.Utilities.BuildTooling.Documentation.PowerShell` child if documentation tooling grows.
2. **Tracked files only** (`git ls-files`). Untracked drafts are ignored on purpose so results are reproducible from a commit.
3. **Repository name** is the root's leaf name with any `-wt-…` sprint suffix stripped. Two roots
   for the same repository fail closed.
4. **Link check is case-insensitive** on every platform, matching Windows.
5. **SprintEnd hook (future):** call it from SprintEnd and copy `Statistics.md` into
   `_Planning\InformationForTheFuture\` (R-38), because `_generated` is deleted at sprint end.
   Not wired in this draft.
6. **Possible gate:** add `-FailOnMissingExpected` / `-MaxUnresolvedLinks` so RepoHealth can fail a
   build when dead links grow. Not included yet, to keep the first version read-only and
   report-only.
