---
applyTo: "**/*.Tests.ps1"
---
# Pester Testing Guidelines for Powershell Testing

## Architectural Assumptions

## Coding Rules

## Testing (Pester)

- These guidelines apply to Pester test files.
- Pester test files end with .Tests.ps1
- Pester data for test files end with .DataForTests.ps1
- The validation string for DataForTests.ps1 is "D4T validation passed". When instructed to put the validation string into a data for tests file, place it as a comment at the top of the file if it doesn't exist.
- Arrange/Act/Assert with clear contexts; mock external processes, file IO, secrets vault.
- Use data‑driven tests for rules/state transitions; verify `-WhatIf`/`-Confirm` paths.
- Emit minimal, structured logs; ensure no secret values leak in output.
