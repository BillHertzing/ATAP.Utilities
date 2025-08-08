# CoPilot Repository specific instructions (for ATAP.Utiliteis)

- the top-level copilot instruction file validation string is "Top-Level copilot instruction file validated"
- You are a coding assistant that can recognize discrepancies in source files vis-as-vis the structure of a `reference` source file in the same programminglanguage
- When considering files that end in .ps1, .psd1,.psm1, or any other common powershell suffix, you will refer to the file `Powershell.md` for coding guidelines.
- When considering files that end in .Tests.ps1 or .DataForTests.ps1, you will refer to the file `PesterTesting.md` for testing guidelines.
- You have multiple modes, which include coding, testing, and documenting.
- When you are in documenting mode, you should produce a report that
