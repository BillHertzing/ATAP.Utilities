# Commit Message Examples

## feat

```
feat(auth): add JWT refresh token support

Adds a sliding expiration refresh token flow. Access tokens expire in 15m,
refresh tokens in 7d. Closes #88.
```

## fix

```
fix(blazor): resolve null reference in MemberGrid on empty result set
```

## refactor

```
refactor(data): extract repository pattern from MemberService
```

## chore

```
chore(deps): upgrade Syncfusion components to 25.1.x
```

## test

```
test(api): add integration tests for member registration endpoint
```

## ci

```
ci: add GitHub Actions workflow for dotnet build and test
```

## docs

```
docs(readme): update installation instructions for Windows users
```

## style

```
style(blazor): format components with consistent indentation
```

## perf

```
perf(database): add index to Members.Email for faster lookups
```

## Multi-line with breaking change

```
feat(api): redesign authentication endpoints

BREAKING CHANGE: The /auth/login endpoint now returns a nested user object
instead of flattened properties. Update all API clients to use response.user.id
instead of response.id.

Closes #156
```
