#Requires -Module Pester

BeforeAll {
  $script:repoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) '..\..')).Path
  $script:projectPath = Join-Path $script:repoRoot 'src\ATAP.Utilities.Configuration\ATAP.Utilities.Configuration.csproj'
  $script:lockPath = Join-Path $script:repoRoot 'src\ATAP.Utilities.Configuration\packages.lock.json'
  $script:expectedProjectNodes = @(
    'atap.utilities.configuration.extensions'
    'atap.utilities.configuration.secrets'
    'atap.utilities.configuration.secrets.shims'
    'atap.utilities.configuration.secrets.shims.interfaces'
    'atap.utilities.etw'
    'atap.utilities.plugin.interfaces'
    'atap.utilities.secrets'
    'atap.utilities.secrets.enumerations'
    'atap.utilities.secrets.interfaces'
    'atap.utilities.secrets.model'
    'atap.utilities.secrets.stringconstants'
  )
}

Describe 'ATAP.Utilities.Configuration provider-neutral package boundary' -Tag RepoHealth, PackageBoundary {
  It 'aggregates only the three approved provider-neutral projects and no packages' {
    [xml] $project = Get-Content -LiteralPath $script:projectPath -Raw
    $references = @($project.Project.ItemGroup.ProjectReference.Include) |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { ([string] $_).Replace('/', '\') } |
      Sort-Object

    $references | Should -Be @(
      '..\ATAP.Utilities.Secrets\ATAP.Utilities.Secrets.csproj'
      'Extensions\ATAP.Utilities.Configuration.Extensions.csproj'
      'Secrets\ATAP.Utilities.Configuration.Secrets.csproj'
    )
    @($project.Project.ItemGroup.PackageReference | Where-Object { $null -ne $_ }) | Should -HaveCount 0
  }

  It 'contains exactly the approved provider-neutral project closure in every target framework' {
    $lock = Get-Content -LiteralPath $script:lockPath -Raw | ConvertFrom-Json -AsHashtable
    $frameworks = @($lock.dependencies.Keys | Where-Object { $_ -notmatch '/' })

    $frameworks | Sort-Object | Should -Be @('net10.0', 'net8.0', 'net9.0')
    foreach ($framework in $frameworks) {
      $projectNodes = @($lock.dependencies[$framework].Keys |
          Where-Object { $lock.dependencies[$framework][$_].type -eq 'Project' } |
          Sort-Object)
      $projectNodes | Should -Be $script:expectedProjectNodes
    }
  }
}