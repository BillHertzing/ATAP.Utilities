# ATAP.Utilities Copilot Instructions

## Repository Overview

ATAP.Utilities is a comprehensive collection of .NET utility libraries, PowerShell modules, and development tools designed to enhance productivity across multiple platforms. The repository contains over 150 C# projects and 11 PowerShell modules targeting enterprise development scenarios.

**Key Technologies:**
- C# targeting .NET 8.0+ (originally .NET 9.0)
- PowerShell 7+ with Pester testing framework
- MSBuild with custom build tooling
- xUnit for C# unit testing
- Entity Framework for database operations
- Serilog for logging
- SQL Server with Flyway migrations

**Repository Size:** ~150 C# projects, 11 PowerShell modules
**Architecture:** Modular utility library with custom MSBuild tooling

## Critical Build Requirements

### .NET Framework Compatibility Issue
**IMPORTANT:** The repository targets .NET 9.0 but most environments only have .NET 8.0 SDK. You MUST make these changes before building:

1. **Create global.json** (if missing):
```json
{
  "sdk": {
    "version": "8.0.118"
  }
}
```

2. **Update Directory.Build.props** - Change target framework:
```xml
<TargetFrameworks>net8.0;</TargetFrameworks>
```

3. **Update tests/Directory.Build.props** - Change target framework:
```xml
<TargetFrameworks>net8.0</TargetFrameworks>
```

4. **Fix individual project files** that override with net9.0:
```bash
find . -name "*.csproj" -exec grep -l "net9.0" {} \; | xargs sed -i 's/net9.0/net8.0/g'
```

### NuGet Configuration Fix
The repository has a broken symlink for NuGet.Config. Always fix this first:

```bash
rm NuGet.Config
cp src/ATAP.Utilities.BuildTooling.PowerShell/Resources/NuGet.Config .
```

For clean builds, use simplified NuGet.Config (original has unreachable feeds):
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
  <packageRestore>
    <add key="enabled" value="True" />
    <add key="automatic" value="True" />
  </packageRestore>
</configuration>
```

### Build System Issues
The custom MSBuild tooling requires careful handling:

**Disable custom build imports temporarily** in Directory.Build.targets:
```xml
<!-- Import MSBuild tasks temporarily disabled for initial build
<Import Project="$(MSBuildCommunityTasksPath)\MSBuildTasks.Targets" />
<Import Project="$(ATAPUtilitiesBuildToolingTargetsPath)\ATAP.Utilities.BuildTooling.targets" />
-->
```

**Re-enable after building ATAP.Utilities.BuildTooling.CSharp project first.**

## Build Instructions

### Prerequisites
- .NET 8.0 SDK
- PowerShell 7+
- Pester 5+ (`Install-Module -Name Pester -Force`)
- PSFramework (`Install-Module -Name PSFramework -Force`)

### Step-by-Step Build Process

1. **Setup** (ALWAYS do this first):
```bash
cd /path/to/ATAP.Utilities
rm NuGet.Config
cp src/ATAP.Utilities.BuildTooling.PowerShell/Resources/NuGet.Config .
```

2. **Fix .NET targeting** (for .NET 8.0 environments):
```bash
# Create global.json
echo '{"sdk":{"version":"8.0.118"}}' > global.json

# Update Directory.Build.props
sed -i 's/net9.0/net8.0/g' Directory.Build.props

# Update test targeting
sed -i 's/net9.0/net8.0/g' tests/Directory.Build.props
```

3. **Disable custom build tooling temporarily**:
Comment out imports in Directory.Build.targets

4. **Build individual projects** (solution has missing projects):
```bash
dotnet build src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.CSharp.csproj
```

5. **Test individual projects**:
```bash
dotnet test tests/ATAP.Utilities.String.UnitTests/ATAP.Utilities.String.UnitTests.csproj
```

### PowerShell Module Testing

Use Pester 5+ for PowerShell testing:

```powershell
# Install required modules
Install-Module -Name Pester -Force
Install-Module -Name PSFramework -Force

# Run tests
cd src/ATAP.Utilities.IAC.Ansible.Powershell
Invoke-Pester -Path tests/Unit/ATAP.Utilities.IAC.Ansible.Powershell.Tests.ps1 -Output Detailed
```

**Note:** PowerShell tests may require Assert module: `Install-Module -Name Assert -Force`

## Project Structure

### Source Organization
```
src/
├── ATAP.Utilities.BuildTooling.CSharp/    # MSBuild custom tasks
├── ATAP.Utilities.BuildTooling.PowerShell/ # PowerShell build tools
├── ATAP.Utilities.*/                      # Core utility libraries
├── ATAP.Console.*/                        # Console applications
└── ATAP.VSCExtension.AI/                  # VS Code extension

tests/
├── ATAP.Utilities.*.UnitTests/            # xUnit test projects
└── Directory.Build.props                  # Test-specific build props

Build/                                     # Custom MSBuild tooling
Databases/                                 # SQL Server scripts
SolutionDocumentation/                     # Comprehensive docs
```

### Key Configuration Files
- **Directory.Build.props**: Solution-wide MSBuild properties
- **Directory.Build.targets**: Custom build targets and tasks
- **NuGet.Config**: Package sources (fix symlink first)
- **.editorconfig**: Code formatting rules
- **global.json**: .NET SDK version pinning

### Important Dependencies
- **Serilog**: Logging framework
- **PSFramework**: PowerShell logging (`Write-PSFMessage`)
- **ServiceStack**: Serialization and ORM
- **Microsoft.Extensions.***: Configuration and DI
- **xUnit**: C# testing
- **Pester**: PowerShell testing

## Development Workflow

### Making Changes
1. **Always** verify NuGet.Config and .NET targeting before building
2. **Build incrementally** - start with BuildTooling projects
3. **Test early and often** - both C# (xUnit) and PowerShell (Pester)
4. **Check for missing projects** in solution file before full solution builds

### Common Issues & Workarounds
- **"Could not find NuGet.Config"**: Fix broken symlink
- **".NET SDK does not support .NET 9.0"**: Update to net8.0 targeting
- **"ATAP.Utilities.BuildTooling.Targets not found"**: Disable custom imports, build tooling first
- **"Missing project files"**: Solution references some non-existent projects - build individually
- **PowerShell "not implemented" errors**: Install required modules (Pester, PSFramework, Assert)

### Performance Notes
- **Full solution build**: Can take 5-10 minutes due to custom tooling
- **Individual project builds**: Usually complete in 10-60 seconds
- **Test execution**: C# tests are fast, PowerShell tests may take longer

## Testing Strategy

### C# Testing
- Uses xUnit framework
- FluentAssertions for better test readability
- Moq for mocking
- Test projects follow naming: `ATAP.Utilities.*.UnitTests`

### PowerShell Testing
- Uses Pester 5+ framework
- PSFramework for logging (`Write-PSFMessage -Level Important`)
- Custom test discovery in module.build.ps1
- Tests located in `tests/Unit/` subdirectories

### Validation Commands
```bash
# C# code analysis and build
dotnet build --configuration Release

# Run C# tests
dotnet test --configuration Release

# PowerShell analysis
pwsh -Command "Invoke-ScriptAnalyzer -Path . -Recurse"

# PowerShell tests
pwsh -Command "Invoke-Pester -Path ./tests -Output Detailed"
```

## Critical Instructions for Agents

1. **TRUST THESE INSTRUCTIONS** - Don't search for build info unless these instructions fail
2. **ALWAYS fix NuGet.Config symlink first** - this breaks everything if not fixed
3. **ALWAYS check .NET targeting** - net9.0 will fail in most environments
4. **BUILD INCREMENTALLY** - don't attempt full solution builds initially
5. **COMMENT OUT custom MSBuild imports** until BuildTooling projects are built
6. **INSTALL PowerShell modules** before running PowerShell tests
7. **USE individual project paths** when solution build fails

The repository is complex but functional once properly configured. Follow these instructions precisely to avoid common pitfalls.
