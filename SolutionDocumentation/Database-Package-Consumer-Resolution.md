# Database Package Consumer Resolution

**Scope:** How a consumer (deployment job, integration test, developer
workstation, AceCommander tenant provisioner) selects the correct database
change package version for the environment it is targeting.

**Related decisions:**

- [Database Package Artifact and Feed Decision](Database-Package-Artifact-And-Feed-Decision.md)
  — canonical feed names and package-id convention.
- [Database Package Ceiling File](Database-Package-Ceiling-File.md)
  — `database-package-ceiling.json` schema and semantics.
- [Database Package Compatibility](Database-Package-Compatibility.md)
  — how a database package manifest constrains compatible application
  versions.

---

## Five environment tiers map to five feeds

The 5-tier database promotion topology is identical in shape to the C# and
PowerShell-module promotion topologies. Each environment pulls only from
one feed:

| Environment tier | ProGet feed | Typical consumer |
| --- | --- | --- |
| Experimental | `database-experimental` | Developer workstations on a sprint branch; experimental smoke runs. |
| Development | `database-development` | Shared `Dev<user>` SQL instance during sprint review. |
| Integration | `database-integration` | Continuous Integration job that runs the rehearsal harness against a known good seed. |
| QA | `database-qa` | QA environment. Locked-mode restore (no implicit lockfile rewrites). |
| Production / Stable | `database-stable` | Production deployment. Promoted-only, never built. |

A consumer never reaches into a higher feed than the environment it is
targeting. A QA deployer never pulls from `database-stable`; a Development
deployer never pulls from `database-integration`. Direction is always
toward `database-stable`, one tier at a time.

---

## How to choose a feed at runtime

The helper cmdlet
[`Resolve-DatabasePackageFeed`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Resolve-DatabasePackageFeed.ps1)
returns the canonical feed name for a tier. Always use it in preference to
hard-coding feed names in scripts:

```powershell
$feed = Resolve-DatabasePackageFeed -Tier 'Integration'
# -> 'database-integration'

$feed = Resolve-DatabasePackageFeed -Tier 'Production'
# -> 'database-stable'
```

Passing an unknown tier value raises a terminating error with the list of
valid values. Do not catch and swallow this error; an unknown tier means
the consumer's configuration is mis-set and should fail fast.

---

## How to respect `database-package-ceiling.json`

Each application database that ships through this pipeline has a ceiling
file in the source repo at
`Database/<Application>/database-package-ceiling.json`. The ceiling is the
highest tier a sprint, feature, integration, QA, release, or hotfix lane
may consume. It is enforced by the BuildMaster runner before any promotion
call.

Consumers that resolve packages outside BuildMaster (developer scripts,
ad-hoc rehearsals) must read the ceiling file themselves before deciding
which feed to pull from:

```powershell
$ceilingFile = Join-Path $repoRoot 'Database' $Application 'database-package-ceiling.json'
if (Test-Path -LiteralPath $ceilingFile) {
    $ceiling = (Get-Content -Raw $ceilingFile | ConvertFrom-Json).ceiling
    # $ceiling is one of: 'Experimental','Development','Integration','QA','Production'
    $feed = Resolve-DatabasePackageFeed -Tier $ceiling
}
```

If the ceiling is lower than the consumer's target environment, fall back
to the ceiling. Never escalate above the ceiling, even for a one-off test.
See `Database-Package-Ceiling-File.md` for the full schema and the canonical
list of legitimate ceiling values.

---

## Resolving a specific package version via NuGet

ProGet exposes each `database-*` feed as a NuGet v3 source. Both
`Install-Package` (PowerShellGet / NuGet) and `dotnet restore` can be
pointed at it.

### Example: PowerShell `Install-Package`

```powershell
$tier = 'Development'
$feed = Resolve-DatabasePackageFeed -Tier $tier
$feedUri = "$ProGetBaseUrl/nuget/$feed/v3/index.json"

Register-PackageSource `
  -Name "ProGet-$feed" `
  -ProviderName NuGet `
  -Location $feedUri `
  -Trusted

Install-Package `
  -Name 'ATAPUtilities.Database' `
  -Source "ProGet-$feed" `
  -RequiredVersion '1.0.0-development.42'
```

### Example: `dotnet restore` from a sprint script

```powershell
$tier = 'Integration'
$feed = Resolve-DatabasePackageFeed -Tier $tier
$feedUri = "$ProGetBaseUrl/nuget/$feed/v3/index.json"

dotnet restore './consumers/MyConsumer.csproj' `
  --source "$feedUri" `
  --packages "$packagesDir" `
  --locked-mode
```

The `--locked-mode` switch is mandatory for Integration, QA, and Production
consumers: it refuses to update the lock file silently when a transitive
package moves. Development consumers may omit `--locked-mode` so they can
write a fresh lockfile during sprint work.

---

## Narrowing by `compatibleAppPackageRanges`

The database package's manifest (`db-release-unit-manifest.json`) declares
which application package versions are compatible. When a release bundle
pins both an application version and a database version, the deployer
must verify the pin lies within `compatibleAppPackageRanges` before
applying migrations. The
[`Test-DatabasePackageCompatibility`](../src/ATAP.Utilities.BuildTooling.PowerShell/public/Test-DatabasePackageCompatibility.ps1)
cmdlet implements this check.

```powershell
$result = Test-DatabasePackageCompatibility `
  -DatabasePackageManifestPath './expanded/db-release-unit-manifest.json' `
  -AppPackageVersion '2.4.0'

if (-not $result.IsCompatible) {
    throw "App package 2.4.0 is outside the database package's compatible ranges (failed range: $($result.FailedRange))."
}
```

When the check fails, the deployment must abort with a human-readable
error and not auto-downgrade or auto-upgrade either package. The release
bundle itself encodes the intended pair; any drift is operator error and
deserves visibility.

---

## Quick reference

| You need… | Use… |
| --- | --- |
| The feed name for a tier | `Resolve-DatabasePackageFeed -Tier <Tier>` |
| To know the highest feed allowed for this lane | Read `Database/<App>/database-package-ceiling.json` |
| To install a specific package version | `dotnet restore --source <feed-v3-index>` or `Install-Package` against the feed |
| To check app/db compatibility | `Test-DatabasePackageCompatibility` |
| The canonical feed list and decision rationale | [Database-Package-Artifact-And-Feed-Decision.md](Database-Package-Artifact-And-Feed-Decision.md) |
