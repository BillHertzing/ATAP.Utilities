# Plan: Migrate to Modern Central Package Management

## Current State Analysis

**Current State:**

[Directory.Build.targets](c:\Dropbox\whertzing\GitHub\ATAP.Utilities\Directory.Build.targets) (lines 145-304) contains **80+ `<PackageReference Update>` elements** implementing the OLD method of central package versioning. This approach works but has limitations:
- Less efficient than modern approach
- No `Directory.Packages.props` file exists
- `ManagePackageVersionsCentrally` property is not set
- Test projects with version-less PackageReferences fail to resolve

**Modern Approach (NuGet 6.2+):** Use [Directory.Packages.props](c:\Dropbox\whertzing\GitHub\ATAP.Utilities\Directory.Packages.props) with `<PackageVersion>` elements and enable `ManagePackageVersionsCentrally`.

---

## Steps

### 1. Create Directory.Packages.props at solution root

- Add property: `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`
- Convert all `<PackageReference Update="PackageName" Version="X.Y.Z">` from [Directory.Build.targets](c:\Dropbox\whertzing\GitHub\ATAP.Utilities\Directory.Build.targets#L145-L304) to `<PackageVersion Include="PackageName" Version="X.Y.Z" />`
- Migrate framework-conditional package versions (lines 279-304) using Condition attributes
- Total packages to migrate: ~85 packages including:
  - Security patches: System.Text.RegularExpressions, System.Private.URI, System.Net.HTTP
  - Core libraries: StateMachine (Stateless), QuickGraph, Reactive Extensions, ServiceStack suite
  - Microsoft.Extensions.\* packages (Configuration, Hosting, Logging, DI)
  - Polly resilience packages
  - Serilog logging suite
  - xUnit test packages (Microsoft.NET.Test.Sdk, FluentAssertions, Moq, xunit.*)
  - Build tools: Microsoft.Build.Framework, Microsoft.Build.Utilities.Core

### 2. Handle framework-specific package versions in Directory.Packages.props

Framework-conditional versions from [Directory.Build.targets](c:\Dropbox\whertzing\GitHub\ATAP.Utilities\Directory.Build.targets#L279-L304):
- System.Text.Json - net472+ only
- System.Collections.Immutable - different versions for netstandard/core vs net4x
- Newtonsoft.Json - both frameworks
- McMaster.NETCore.Plugins - core/net5+ only

Use Condition attributes on `<PackageVersion>` elements to replicate framework-specific logic

### 3. Clean up Directory.Build.targets

- **Keep**: Lines 1-144 (imports, resource handling, plugin config, JSON settings copy, multi-RID publishing, Source Link `<PackageReference Include>` on line 122)
- **Remove**: Lines 145-304 (all `<PackageReference Update>` elements now in Directory.Packages.props)
- **Keep**: Lines 305-334 (framework-conditional ItemGroups - will work with new system)
- **Result**: Reduce file from 334 to ~180 lines

### 4. Verify all test projects can now resolve packages

Projects like [ATAP.Utilities.CryptoMiner.UnitTests.csproj](c:\Dropbox\whertzing\GitHub\ATAP.Utilities\tests\ATAP.Utilities.CryptoMiner.UnitTests\ATAP.Utilities.CryptoMiner.UnitTests.csproj#L20-L35) have version-less PackageReferences that will now resolve from Directory.Packages.props

### 5. Test build with dotnet restore and dotnet build

- Run: `dotnet restore c:\Dropbox\whertzing\GitHub\ATAP.Utilities\ATAP.Utilities.sln`
- Run: `dotnet build c:\Dropbox\whertzing\GitHub\ATAP.Utilities\ATAP.Utilities.sln`
- Verify no NU1008 errors (package version not found)

---

## Verification

**Success Criteria:**
- Directory.Packages.props created with 85+ PackageVersion entries
- Directory.Build.targets reduced by ~120 lines
- `dotnet restore` completes without NU1008 errors
- `dotnet build` shows reduced errors compared to baseline
- Test projects resolve all package versions correctly

**Traceability:**
- Addresses Priority #1 from original analysis
- Resolves build failures in ~20-25 test projects
- Modernizes to NuGet 6.2+ standard (supported since .NET SDK 6.0.300)

---

## Decisions

**Chose Modern Directory.Packages.props** over keeping legacy `<PackageReference Update>` approach because:
- Native NuGet support (better tooling, IDE integration)
- Cleaner separation: Directory.Packages.props = versions, Directory.Build.targets = build logic
- Better performance (NuGet cache optimization)
- Industry standard since 2022

**Framework-conditional versions** will use Condition attributes in Directory.Packages.props rather than separate ItemGroups for consistency

---

## Package Inventory

### Security Patches (Critical)
- System.Text.RegularExpressions 5.0.0 (4.3.0 has vulnerability)
- System.Private.URI 4.3.4 (4.3.0 has vulnerability)
- System.Net.HTTP 4.8.1 (4.3.0 has vulnerability)
- System.Runtime.InteropServices 4.3.0
- System.Runtime.Handles 4.3.0

### Core Libraries
- Stateless 5.1.2
- YC.QuickGraph 3.7.4
- DotNet.Contracts 1.10.20606.1
- FSharp.Core 4.3.4
- FSharpx.Collections.Experimental 2.1.3
- System.Reactive 5.0.0
- System.Speech 5.0.0

### ServiceStack Suite
- ServiceStack 5.12.0
- ServiceStack.Text.EnumMemberSerializer 3.0.0.50044
- ServiceStack.Text 5.12.0
- ServiceStack.HttpClient 5.12.0
- ServiceStack.OrmLite 5.12.0
- ServiceStack.OrmLite.SqlServer 5.12.0
- ServiceStack.OrmLite.MySQL 5.12.0
- ServiceStack.OrmLite.Sqlite 5.12.0
- ServiceStack.OrmLite.Core 5.12.0
- ServiceStack.OrmLite.SqlServer.Core 5.12.0
- ServiceStack.OrmLite.MySQL.Core 5.12.0
- ServiceStack.OrmLite.Sqlite.Core 5.12.0

### Time Libraries
- TimePeriodLibrary.NET 2.1.5

### Microsoft.Extensions.\* (Hosting & Configuration)
- Microsoft.Extensions.Configuration 9.0.0
- Microsoft.Extensions.Configuration.Binder 9.0.0
- Microsoft.Extensions.Configuration.CommandLine 9.0.0
- Microsoft.Extensions.Configuration.EnvironmentVariables 9.0.0
- Microsoft.Extensions.Configuration.Json 9.0.0
- Microsoft.Extensions.Hosting 9.0.0
- Microsoft.Extensions.Localization 9.0.0
- Microsoft.Extensions.Logging 9.0.0
- Microsoft.Extensions.Logging.Abstractions 9.0.0
- Microsoft.Extensions.DependencyInjection 9.0.0

### Dependency Injection Alternatives
- Ninject 3.3.6
- Ninject.extensions.conventions 3.3.0

### Resilience Policies
- Polly 8.5.0
- Polly.Contrib.WaitAndRetry 1.1.1

### File I/O & Abstractions
- System.IO.Abstractions 21.1.3
- System.IO.Abstractions.TestingHelpers 21.1.3

### Aspect-Oriented Programming
- MethodBoundaryAspect.Fody 2.0.150

### Messaging & Dataflow
- RabbitMQ.Client 7.0.0
- System.Threading.Tasks.Dataflow 9.0.0

### Object Mapping
- AutoMapper 13.0.1

### Build Tools
- Microsoft.Build.Framework 17.12.6
- Microsoft.Build.Utilities.Core 17.12.6

### Source Link
- Microsoft.SourceLink.GitHub 8.0.0

### Serilog Logging Suite
- Serilog 4.1.0
- Serilog.Settings.Configuration 8.0.4
- Serilog.Enrichers.Thread 4.0.0
- Serilog.Extensions.Hosting 4.1.2
- Serilog.Extensions.Logging 3.0.1
- Serilog.Exceptions 7.1.0
- Serilog.Sinks.Console 4.0.0
- Serilog.Sinks.Debug 2.0
- Serilog.Sinks.File 5.0.0
- Serilog.Sinks.Seq 5.0.0
- SerilogAnalyzer 0.15.0
- Seq.Extensions.Logging 6.0.0

### Process Management
- MedallionShell 1.6.2

### Units of Measure
- UnitsNet 5.60.0

### DI Extensions
- Scrutor 3.3.0

### xUnit Testing Suite
- Microsoft.NET.Test.Sdk 17.0.0
- FluentAssertions 6.2.0
- Moq 4.16.1
- Xunit.DependencyInjection 7.1.0
- xunit 2.4.1
- xunit.runner.console 2.4.1
- xunit.runner.visualstudio 2.4.3
- coverlet.collector 3.1.0

### Legacy/Unsorted
- NLog 4.7.0
- NLog.Config 4.7.0
- Microsoft.CSharp 4.7.0
- System.Dynamic.Runtime 4.3.0
- docfx 2.56.5
- Microsoft.CodeAnalysis.Common 3.5.0

### Framework-Conditional Packages

**All Frameworks (net472+, netstandard, netcore, net5+):**
- System.Text.Json 5.0.0

**netstandard/core/net5+ only:**
- System.Collections.Immutable 5.0.0
- Newtonsoft.Json 12.0.3

**net4x only:**
- System.Collections.Immutable 1.7.1
- Newtonsoft.Json 12.0.3

**core/net5+ only:**
- McMaster.NETCore.Plugins 1.4.0

### Deprecated/Commented
- dotnet-xunit 2.3.1 (DotNetCliToolReference)
- Microsoft.CodeAnalysis.FxCopAnalyzers 3.3.2 (deprecated)
- Polly.Extensions.Http 3.0.0 (deprecated)
- Microsoft.AspNetCore.Hosting.Abstractions 5.0.0 (commented)

---

## Note — `allowInsecureConnections` for HTTP NuGet sources

When build failures mention `Unable to load the service index for source
http://localhost:50000/...`, the root cause is usually that NuGet 6.0+ blocks
HTTP sources unless `allowInsecureConnections = true` is declared for that source.

**This setting must go inside `<packageSourceSettings>`, NOT inside `<config>`.**
Placing it in `<config>` is silently ignored by NuGet.

Full canonical schema and all five ProGet feed entries:
see [`BuildMaster-ProGet-CSharp-Package-Pipeline.md` §13](BuildMaster-ProGet-CSharp-Package-Pipeline.md#13-nugetconfig-reference).

Verify the effective merged config with:

```powershell
nuget config -list        # shows merged effective settings
dotnet nuget list source  # shows registered sources
```
