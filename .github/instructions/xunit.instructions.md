---
applyTo: "**/tests/**/*.cs"
---
# xUnit Testing Guidelines

- `Theory` + member data for transition tables; `Fact` for edge cases.
- Verify DI graphs using `ServiceCollection` + `ServiceProvider` and scope creation.
- Use fakes/mocks; assert logging scopes and absence of secret material in logs.
