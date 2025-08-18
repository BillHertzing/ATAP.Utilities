---
applyTo: "**/*.cs"
---

# C# (.NET) Guidelines

## Architectural Assumptions

- All libraries are **DI‑first** services with **interface boundaries**, registered via `IServiceCollection`.
- Configuration via **Options pattern**; bind from HostSettings, ConfigRootKey files, and Environment variables.
- Libraries run under hosts like **AceCommander** or ATAP test runners.

## Coding Rules

1. **Project setup**: enable `<Nullable>enable</Nullable>`; treat warnings as errors where feasible; include analyzers (`Microsoft.CodeAnalysis.NetAnalyzers`).
2. **APIs**: prefer `async` methods; accept `CancellationToken`; return `Task`/`ValueTask` appropriately.
3. **Logging**: use `ILogger<T>`; include member name and correlation/trace id in scopes; avoid logging secrets.
4. **Security**: validate inputs; avoid insecure defaults; use secure types/APIs for secrets and interprocess communication with the password manager.
5. **Configuration**: provide defaults; read from environment and HostSettings; expose strongly‑typed options with validation (`ValidateDataAnnotations`).
6. **State Machine/Rules**: model transitions as pure functions; keep side‑effects at the edges; provide unit tests for each state/transition.
7. **Packaging**: libraries target `netX.Y` LTS; avoid static globals—inject abstractions over time, file system, and clock.

## Testing (xUnit)

- Use `Fact`/`Theory` with data‑driven cases for rules/state transitions.
- Mock external services; assert logging and DI registration behavior.

## Example Registration

```csharp
services.AddOptions<MyFeatureOptions>()
        .Bind(configuration.GetSection("MyFeature"))
        .ValidateDataAnnotations()
        .ValidateOnStart();
services.AddSingleton<IMyFeature, MyFeature>();
```
