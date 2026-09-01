#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
  $script:repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
  $script:explicitRidProjects = @(
    'src/ATAP.Utilities.Testing.DI.Fixture.Serialization/ATAP.Utilities.Testing.Fixture.Serialization.DI.csproj'
    'src/ATAP.Utilities.Testing.Fixture.Database/ATAP.Utilities.Testing.Fixture.Database.csproj'
    'src/ATAP.Utilities.Testing.Fixture.Serialization/ATAP.Utilities.Testing.Fixture.Serialization.csproj'
    'src/ATAP.Utilities.Testing.Fixture.Serialization.Shim.Plugin/ATAP.Utilities.Testing.Fixture.Serialization.Shim.Plugin.csproj'
    'src/ATAP.Utilities.Testing.Fixture.Serialization.Shim.ServiceStack/ATAP.Utilities.Testing.Fixture.Serialization.Shim.ServiceStack.csproj'
    'tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests/ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests.csproj'
    'tests/ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests/BwsProcessTestDouble/BwsProcessTestDouble.csproj'
  )

  function Get-LockRuntimeIdentifiers {
    param([Parameter(Mandatory)] [string] $LockPath)

    $lock = Get-Content -LiteralPath $LockPath -Raw | ConvertFrom-Json -AsHashtable
    @($lock.dependencies.Keys | Where-Object { $_ -match '^[^/]+/[^/]+$' } | ForEach-Object { ($_ -split '/', 2)[1] } | Sort-Object -Unique)
  }
}

Describe 'Task 15.186 runtime-identifier and lock contract' {
  It 'keeps the repository-wide RuntimeIdentifiers default empty' {
    [xml] $props = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Directory.Build.props') -Raw
    @($props.Project.PropertyGroup.RuntimeIdentifiers | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }).Count | Should -Be 0
  }

  It 'limits explicit project RIDs to the reviewed portable win-x64 boundary' {
    $declared = [Collections.Generic.List[string]]::new()
    foreach ($relativePath in @(git -C $script:repoRoot ls-files -- ':(glob)**/*.csproj')) {
      if ($relativePath -match '/tests/fixtures/') { continue }
      [xml] $project = Get-Content -LiteralPath (Join-Path $script:repoRoot $relativePath) -Raw
      $values = @($project.Project.PropertyGroup.RuntimeIdentifier) + @($project.Project.PropertyGroup.RuntimeIdentifiers)
      $rids = @($values | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) } | ForEach-Object { ([string] $_).Split(';') } | Where-Object { $_ } | Sort-Object -Unique)
      if ($rids.Count) {
        $declared.Add($relativePath.Replace('\', '/'))
        $rids | Should -Be @('win-x64')
      }
    }
    @($declared | Sort-Object) | Should -Be ($script:explicitRidProjects | Sort-Object)
  }

  It 'contains RID lock groups only beside projects that explicitly declare that RID' {
    $violations = [Collections.Generic.List[string]]::new()
    foreach ($relativeLock in @(git -C $script:repoRoot ls-files -- ':(glob)**/packages.lock.json')) {
      $lockPath = Join-Path $script:repoRoot $relativeLock
      $rids = @(Get-LockRuntimeIdentifiers -LockPath $lockPath)
      if (-not $rids.Count) { continue }
      $projects = @(Get-ChildItem -LiteralPath (Split-Path -Parent $lockPath) -Filter '*.csproj' -File)
      if ($projects.Count -ne 1) {
        $violations.Add("${relativeLock}: expected one adjacent project, found $($projects.Count)")
        continue
      }
      [xml] $project = Get-Content -LiteralPath $projects[0].FullName -Raw
      $declared = @(@($project.Project.PropertyGroup.RuntimeIdentifier) + @($project.Project.PropertyGroup.RuntimeIdentifiers) | ForEach-Object { ([string] $_).Split(';') } | Where-Object { $_ } | Sort-Object -Unique)
      foreach ($rid in $rids) {
        if ($rid -notin $declared) { $violations.Add("${relativeLock}: undeclared RID $rid") }
      }
    }
    $violations | Should -BeNullOrEmpty
  }

  It 'recognizes a close-variant version-specific RID as undeclared' {
    $fixture = Join-Path $TestDrive 'packages.lock.json'
    '{"version":2,"dependencies":{"net10.0/win10-x64":{}}}' | Set-Content -LiteralPath $fixture
    Get-LockRuntimeIdentifiers -LockPath $fixture | Should -BeExactly 'win10-x64'
    'win10-x64' | Should -Not -BeIn @('win-x64')
  }
}
