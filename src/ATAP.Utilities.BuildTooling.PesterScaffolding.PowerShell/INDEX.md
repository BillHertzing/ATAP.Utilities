# ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell index

This module owns the Pester configuration and test-template public functions formerly
provided directly by the BuildTooling parent.

## Public commands

- `Get-MergedPesterConfigurations`
- `Merge-PesterConfiguration`
- `New-MockTestFileStructure`
- `New-PesterBasicUnitTestTemplate`
- `New-PesterContextBlock`
- `New-PesterDataDrivenTestTemplate`
- `New-PesterDescribeBlock`
- `New-PesterFileModel`
- `New-PesterItBlock`
- `New-PesterTestFile`

## Tests

The `tests/` tree owns the five moved behavioral suites plus
`tests/Unit/ParentCompatibility.Tests.ps1`, which verifies parent parameter metadata
and named-argument forwarding.
