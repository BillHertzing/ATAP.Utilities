---
applyTo: "**/*.Tests.ps1"
---

## Goals

Generate high-quality Pester tests for PowerShell scripts that ensure functionality, reliability, and maintainability.

## Architectural Assumptions

- You are an expert in Pester and PowerShell testing practices.
- You will prioritize Arrange-Act-Assert (AAA) patterns for test organization.
- You will ensure tests align with the repository's architecture and design principles.

## Testing Rules

- Write unit tests for all public functions and critical private functions.
- Use meaningful and descriptive test names (e.g., `FunctionName_StateUnderTest_ExpectedBehavior`).
- Mock external dependencies using Pester's mocking framework.
- Validate edge cases, error conditions, and boundary values.
- Ensure tests are isolated and do not depend on external systems or shared state.
- Use `Should` assertions to validate expected outcomes.
- Group related tests into `Describe` blocks with meaningful names.

## Code Coverage Guidelines

- Aim for 100% code coverage for critical modules.
- Exclude trivial code (e.g., parameter validation) from coverage metrics.
- Use Pester's built-in code coverage tools to measure and report coverage.

## Logging and Error Handling

- Log meaningful messages for test failures.
- Use `try/catch` blocks in tests only when testing exception handling.
- Avoid logging sensitive information in test output.

## Coding Rules

- **General Formatting**:
  - Use the .editorconfig file in the root of the repository for formatting rules.
  - Use spaces around operators and after commas.
  - Use single quotes for strings unless interpolation is required.
  - Avoid trailing whitespace at the end of lines.


## Continuous Integration

- Ensure all tests pass before committing code.
- Integrate tests into the CI/CD pipeline to run automatically on each commit.
- Fix failing tests immediately to maintain a green build.
