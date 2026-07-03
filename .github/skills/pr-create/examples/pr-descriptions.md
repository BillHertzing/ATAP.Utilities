# PR Title and Body Examples

## Feature Branch

**Title:**

```
feat(auth): add OAuth2 provider support for GitHub and Google
```

**Body:**

```markdown
## Summary

Adds OAuth2 authentication support for GitHub and Google identity providers.
Users can now sign in using their existing accounts instead of creating
new credentials.

## Changes

- Implemented OAuth2 authorization code flow
- Added GitHub and Google provider configurations
- Created callback endpoint for token exchange
- Updated login UI with provider selection buttons
- Added user profile mapping from provider claims

## Testing

- Manual testing with test GitHub OAuth app
- Manual testing with test Google OAuth app
- Integration tests for callback endpoint
- Unit tests for provider configuration and claim mapping

## Notes

Breaking change: The `User` model now includes a `ProviderId` and `Provider`
field. Existing users will have `Provider = "local"` by default.

Migration script included in `migrations/20260304_add_oauth_fields.sql`.

Closes #42
```

## Bug Fix Branch

**Title:**

```
fix(blazor): resolve memory leak in grid component disposal
```

**Body:**

```markdown
## Summary

Fixes a memory leak where event handlers in the DataGrid component were
not being unsubscribed during disposal, causing retained references.

## Changes

- Added explicit event handler cleanup in `Dispose()` method
- Implemented `IDisposable` pattern correctly
- Added null checks before unsubscribing

## Testing

- Verified with dotMemory profiler that objects are now collected
- Existing unit tests pass
- No regressions in grid functionality

## Notes

None

Closes #156
```

## Documentation Branch

**Title:**

```
docs(readme): add Windows setup instructions and troubleshooting guide
```

**Body:**

```markdown
## Summary

Expands the README with detailed Windows-specific installation steps and
a troubleshooting section for common issues.

## Changes

- Added PowerShell prerequisites section
- Documented Windows-specific path configurations
- Created troubleshooting guide for certificate errors
- Added screenshots for Visual Studio setup

## Testing

- Followed instructions on fresh Windows 11 VM
- Verified all links and commands work
- Reviewed with team member on Windows

## Notes

None
```

## Refactoring Branch

**Title:**

```
refactor(data): extract repository pattern and unit of work
```

**Body:**

```markdown
## Summary

Refactors data access layer to use Repository pattern with Unit of Work,
improving testability and separation of concerns.

## Changes

- Created `IRepository<T>` and `Repository<T>` base classes
- Extracted `IUnitOfWork` interface and `UnitOfWork` implementation
- Migrated `MemberService` to use repositories
- Updated dependency injection registration
- Removed direct DbContext usage from services

## Testing

- All existing integration tests pass
- Added unit tests for repository implementations
- Verified no performance regression with benchmark suite

## Notes

No breaking changes to public APIs. Internal service constructors have
changed but all are registered via DI.

Future work: Migrate remaining services (EventService, PaymentService) to
use the new repository pattern.
```

## Chore Branch

**Title:**

```
chore(deps): upgrade .NET 8 and Syncfusion components
```

**Body:**

```markdown
## Summary

Updates project to .NET 8 and upgrades Syncfusion component suite to
version 25.1.x for latest features and security patches.

## Changes

- Updated target framework to net8.0
- Upgraded Syncfusion.Blazor.\* packages to 25.1.35
- Updated global.json to require .NET 8.0.2 SDK
- Resolved breaking changes in Grid component API
- Updated CI/CD workflow to use .NET 8 runner

## Testing

- Full test suite passes (327 tests)
- Manual smoke testing of all Blazor pages
- Verified production build completes successfully

## Notes

Requires .NET 8 SDK to build. See updated README for installation
instructions.

No user-facing breaking changes.
```
