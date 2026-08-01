# ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell

Pester test-template and configuration helpers extracted from the BuildTooling parent
as the Task 13.71 pilot. The module depends on
`ATAP.Utilities.BuildTooling.Common.PowerShell` 0.1.5 or later. That floor is the
first deployed Common version containing `Get-RepositoryRoot`, the global contract
used by test source rendered from the Pester templates.

The module also requires Pester 5.7.1 or later because the configuration merge
commands expose and construct the Pester 5 `PesterConfiguration` type.

## Functional area

PowerShell Build & Packaging - START HERE:
`SolutionDocumentation/PowerShell-Modules-Build-Process.md`.
