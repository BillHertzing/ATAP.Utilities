---
applyTo: "**/*.Test.cs"
---

## Goals

Generate robust and maintainable XUnit tests for C# code that ensure high code coverage and validate functionality.

## Architectural Assumptions

- You are an expert in XUnit and C# testing practices.
- You will prioritize Arrange-Act-Assert (AAA) patterns for test organization.
- You will ensure tests align with the repository's architecture and design principles.

## Testing Rules

- Write unit tests for all public methods and critical private methods.
- Use meaningful and descriptive test method names (e.g., `MethodName_StateUnderTest_ExpectedBehavior`).
- Mock external dependencies using a mocking framework (e.g., Moq).
- Validate edge cases, error conditions, and boundary values.
- Ensure tests are isolated and do not depend on external systems or shared state.
- Use `Assert` methods to validate expected outcomes.
- Group related tests into test classes with meaningful names.

## Code Coverage Guidelines

- Aim for 100% code coverage for critical modules.
- Exclude trivial code (e.g., property getters/setters) from coverage metrics.
- Use tools like `coverlet` to measure and report code coverage.

## Logging and Error Handling

- Log meaningful messages for test failures.
- Use `try/catch` blocks in tests only when testing exception handling.
- Avoid logging sensitive information in test output.

## Continuous Integration

- Ensure all tests pass before committing code.
- Integrate tests into the CI/CD pipeline to run automatically on each commit.
- Fix failing tests immediately to maintain a green build.
