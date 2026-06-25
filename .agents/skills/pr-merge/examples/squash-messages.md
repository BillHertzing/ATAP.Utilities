# Squash Commit Message Examples

These are the final commit messages that appear in `main`'s history after
squash-merging a PR. They should provide a complete, standalone summary of
all changes from the PR.

## Feature PR

```
feat(auth): add OAuth2 provider support for GitHub and Google

Adds OAuth2 authentication support for GitHub and Google identity
providers, enabling users to sign in using existing accounts instead
of creating new credentials. Implements authorization code flow with
token exchange and user profile mapping.

- Implemented OAuth2 authorization code flow
- Added GitHub and Google provider configurations
- Created callback endpoint for token exchange
- Updated login UI with provider selection buttons
- Added user profile mapping from provider claims

Breaking change: User model now includes ProviderId and Provider fields.
Migration script included for existing users.

Closes #42
```

## Bug Fix PR

```
fix(blazor): resolve memory leak in grid component disposal

Fixes a memory leak where event handlers in the DataGrid component were
not being unsubscribed during disposal, causing retained references and
gradual memory consumption.

- Added explicit event handler cleanup in Dispose() method
- Implemented IDisposable pattern correctly
- Added null checks before unsubscribing

Verified with dotMemory profiler that objects are now properly collected.

Closes #156
```

## Documentation PR

```
docs(readme): add Windows setup instructions and troubleshooting guide

Expands the README with detailed Windows-specific installation steps,
PowerShell prerequisites, and a troubleshooting section for common
certificate and path configuration issues.

- Added PowerShell prerequisites section
- Documented Windows-specific path configurations
- Created troubleshooting guide for certificate errors
- Added screenshots for Visual Studio setup

Verified on fresh Windows 11 VM installation.
```

## Refactoring PR

```
refactor(data): extract repository pattern and unit of work

Refactors data access layer to use Repository pattern with Unit of Work,
improving testability and separation of concerns. No breaking changes to
public APIs.

- Created IRepository<T> and Repository<T> base classes
- Extracted IUnitOfWork interface and UnitOfWork implementation
- Migrated MemberService to use repositories
- Updated dependency injection registration
- Removed direct DbContext usage from services

All existing integration tests pass with no performance regression.
Future work will migrate remaining services to this pattern.
```

## Dependency Update PR

```
chore(deps): upgrade .NET 8 and Syncfusion components

Updates project to .NET 8 and upgrades Syncfusion component suite to
version 25.1.x for latest features, performance improvements, and
security patches.

- Updated target framework to net8.0
- Upgraded Syncfusion.Blazor.* packages to 25.1.35
- Updated global.json to require .NET 8.0.2 SDK
- Resolved breaking changes in Grid component API
- Updated CI/CD workflow to use .NET 8 runner

Requires .NET 8 SDK to build. No user-facing breaking changes.
Full test suite passes (327 tests).
```

## Multiple Related Commits

When a PR contains several logically distinct commits that all contribute to
a single feature, the squash message should summarize the collective impact:

```
feat(reporting): add export functionality for member reports

Adds comprehensive export functionality supporting Excel, PDF, and CSV
formats with customizable column selection and filtering. Includes
server-side generation, streaming for large datasets, and email delivery.

- Implemented Excel export using EPPlus library
- Added PDF generation with customizable templates
- Created CSV export with configurable delimiters
- Built export preview UI with column picker
- Added background job processing for large exports
- Implemented email delivery with attachment support

Supports datasets up to 100K rows with memory-efficient streaming.

Closes #89, Closes #91, Closes #104
```

## Key Principles

1. **Subject line** matches the PR title (Conventional Commits format)
2. **First paragraph** explains the "why" and high-level "what"
3. **Bullet list** captures the specific "how" (key implementation details)
4. **Footer** includes testing notes, breaking changes, and issue refs
5. **Self-contained** — readable without looking at the PR or individual commits
