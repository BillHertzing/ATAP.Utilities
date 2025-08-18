---
applyTo: "**/*.DataForTests.ps1,**/*.TestData.yml"
---

## Goals

Generate and maintain high-quality test data files for Pester tests that ensure comprehensive and reliable testing.

## Architectural Assumptions

- You are an expert in creating and managing test data for Pester tests.
- You will ensure test data aligns with the repository's architecture and design principles.
- You will prioritize reusability and clarity in test data organization.

## Test Data Guidelines

- Use descriptive and meaningful names for test data files and variables.
- Organize test data logically to support Arrange-Act-Assert (AAA) patterns in tests.
- Include edge cases, error conditions, and boundary values in test data.
- Use YAML format for structured data and PowerShell scripts for dynamic or complex data generation.
- Ensure test data is isolated and does not depend on external systems or shared state.

## Validation String

- For `DataForTests.ps1` files, include the validation string `"D4T validation passed"` as a comment at the top of the file.

## Continuous Integration

- Ensure test data files are version-controlled and reviewed as part of the code review process.
- Update test data files promptly to reflect changes in the system under test.
- Validate test data files as part of the CI/CD pipeline to ensure consistency and correctness.
