#Requires -Module Pester

BeforeAll {
  function script:Remove-CSharpNonCodeText {
    param([Parameter(Mandatory = $true)][string] $Text)

    $builder = [Text.StringBuilder]::new($Text.Length)
    $state = 'Code'
    for ($index = 0; $index -lt $Text.Length; $index++) {
      $character = $Text[$index]
      $next = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char] 0 }
      $afterNext = if ($index + 2 -lt $Text.Length) { $Text[$index + 2] } else { [char] 0 }
      switch ($state) {
        'Code' {
          if ($character -eq '/' -and $next -eq '/') { [void] $builder.Append('  '); $index++; $state = 'LineComment' }
          elseif ($character -eq '/' -and $next -eq '*') { [void] $builder.Append('  '); $index++; $state = 'BlockComment' }
          elseif (($character -eq '$' -and $next -eq '@' -and $afterNext -eq '"') -or ($character -eq '@' -and $next -eq '$' -and $afterNext -eq '"')) { [void] $builder.Append('   '); $index += 2; $state = 'VerbatimString' }
          elseif ($character -eq '@' -and $next -eq '"') { [void] $builder.Append('  '); $index++; $state = 'VerbatimString' }
          elseif ($character -eq '$' -and $next -eq '"') { [void] $builder.Append('  '); $index++; $state = 'String' }
          elseif ($character -eq '"') { [void] $builder.Append(' '); $state = 'String' }
          elseif ($character -eq "'") { [void] $builder.Append(' '); $state = 'Character' }
          else { [void] $builder.Append($character) }
        }
        'LineComment' {
          if ($character -eq "`n") { [void] $builder.Append($character); $state = 'Code' } else { [void] $builder.Append(' ') }
        }
        'BlockComment' {
          if ($character -eq '*' -and $next -eq '/') { [void] $builder.Append('  '); $index++; $state = 'Code' }
          elseif ($character -eq "`r" -or $character -eq "`n") { [void] $builder.Append($character) }
          else { [void] $builder.Append(' ') }
        }
        'String' {
          if ($character -eq '\' -and $next -ne [char] 0) { [void] $builder.Append('  '); $index++ }
          elseif ($character -eq '"') { [void] $builder.Append(' '); $state = 'Code' }
          elseif ($character -eq "`r" -or $character -eq "`n") { [void] $builder.Append($character) }
          else { [void] $builder.Append(' ') }
        }
        'VerbatimString' {
          if ($character -eq '"' -and $next -eq '"') { [void] $builder.Append('  '); $index++ }
          elseif ($character -eq '"') { [void] $builder.Append(' '); $state = 'Code' }
          elseif ($character -eq "`r" -or $character -eq "`n") { [void] $builder.Append($character) }
          else { [void] $builder.Append(' ') }
        }
        'Character' {
          if ($character -eq '\' -and $next -ne [char] 0) { [void] $builder.Append('  '); $index++ }
          elseif ($character -eq "'") { [void] $builder.Append(' '); $state = 'Code' }
          else { [void] $builder.Append(' ') }
        }
      }
    }
    $builder.ToString()
  }

  $script:systemDataNamespacePattern = '(?m)(?:^\s*(?:global\s+)?using\s+(?:(?:[A-Za-z_]\w*)\s*=\s*)?(?:static\s+)?(?:global::)?System\.Data\.SqlClient\b|(?<![A-Za-z0-9_.])(?:global::)?System\.Data\.SqlClient\b)'
  $script:repoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) '..\..')).Path
  $script:excludedPathPattern = '(^|/)OpenHardwareMonitorLib(/|$)|(^|/)(bin|obj|_generated)(/|$)'
  $trackedAndCurrentPaths = @(git -C $script:repoRoot ls-files --cached --others --exclude-standard)
  if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed while building the package-security inventory.' }
  $script:inventoryPaths = @($trackedAndCurrentPaths | ForEach-Object { $_ -replace '\\', '/' } | Where-Object { $_ -notmatch $script:excludedPathPattern -and (Test-Path -LiteralPath (Join-Path $script:repoRoot $_) -PathType Leaf) } | Sort-Object -Unique)
  $script:packageSourcePaths = @($script:inventoryPaths | Where-Object { $_ -match '\.(csproj|props|targets)$' })
  $script:csharpSourcePaths = @($script:inventoryPaths | Where-Object { $_ -match '^(src|tests|samples)/.+\.cs$' })
  $script:lockPaths = @($script:inventoryPaths | Where-Object { $_ -match '(^|/)packages\.lock\.json$' })
  $script:lockDocuments = foreach ($relativePath in $script:lockPaths) {
    [pscustomobject]@{ Path = $relativePath; Json = Get-Content -LiteralPath (Join-Path $script:repoRoot $relativePath) -Raw | ConvertFrom-Json -AsHashtable }
  }
  $script:lockNodes = foreach ($lock in $script:lockDocuments) {
    foreach ($targetFramework in $lock.Json.dependencies.Keys) {
      foreach ($packageName in $lock.Json.dependencies[$targetFramework].Keys) {
        $node = $lock.Json.dependencies[$targetFramework][$packageName]
        [pscustomobject]@{ Path = $lock.Path; TargetFramework = $targetFramework; Package = $packageName; Type = [string] $node.type; Requested = [string] $node.requested; Resolved = [string] $node.resolved }
      }
    }
  }
  $script:packageReferences = foreach ($relativePath in $script:packageSourcePaths) {
    try { [xml] $document = Get-Content -LiteralPath (Join-Path $script:repoRoot $relativePath) -Raw } catch { throw "Package source is not parseable XML: $relativePath. $($_.Exception.Message)" }
    foreach ($node in @($document.SelectNodes('//PackageReference|//PackageVersion'))) {
      [pscustomobject]@{ Path = $relativePath; Element = $node.LocalName; Package = [string] $node.Include; Version = [string] $node.Version }
    }
  }
}

Describe 'Task 15.180.n deterministic package-security graph' -Tag 'RepoHealth', 'PackageSecurity' {
  It 'uses an explicit deterministic inventory and excludes OpenHardwareMonitorLib and generated/build output' {
    $script:packageSourcePaths.Count | Should -BeGreaterThan 0
    $script:lockPaths.Count | Should -BeGreaterThan 0
    @($script:inventoryPaths | Where-Object { $_ -match $script:excludedPathPattern }).Count | Should -Be 0
  }

  It 'has no legacy ServiceStack SQL Server provider package ingress or resolution' {
    $legacyProviders = @('ServiceStack.OrmLite.SqlServer', 'ServiceStack.OrmLite.SqlServer.Core')
    @($script:packageReferences | Where-Object { $_.Package -in $legacyProviders }).Count | Should -Be 0
    @($script:lockNodes | Where-Object { $_.Package -in $legacyProviders }).Count | Should -Be 0
  }

  It 'has no System.Data.SqlClient package or C# namespace ingress' {
    @($script:packageReferences | Where-Object { $_.Package -eq 'System.Data.SqlClient' }).Count | Should -Be 0
    @($script:lockNodes | Where-Object { $_.Package -eq 'System.Data.SqlClient' }).Count | Should -Be 0
    $namespaceIngress = foreach ($relativePath in $script:csharpSourcePaths) {
      $codeOnlyText = Remove-CSharpNonCodeText -Text (Get-Content -LiteralPath (Join-Path $script:repoRoot $relativePath) -Raw)
      if ($codeOnlyText -match $script:systemDataNamespacePattern) { $relativePath }
    }
    @($namespaceIngress).Count | Should -Be 0
  }

  It 'detects alias and fully qualified System.Data.SqlClient ingress without matching comments or literals' {
    $prohibitedVariants = @('using LegacySql = System.Data.SqlClient;', 'global using LegacySql = global::System.Data.SqlClient;', 'var connection = new System.Data.SqlClient.SqlConnection();', 'var connection = new global::System.Data.SqlClient.SqlConnection();')
    foreach ($variant in $prohibitedVariants) { (Remove-CSharpNonCodeText -Text $variant) | Should -Match $script:systemDataNamespacePattern }
    $allowedNonCode = @('// System.Data.SqlClient.SqlConnection', '/* using LegacySql = System.Data.SqlClient; */', 'const string packageName = "System.Data.SqlClient";', 'const string verbatimName = @"System.Data.SqlClient";') -join [Environment]::NewLine
    (Remove-CSharpNonCodeText -Text $allowedNonCode) | Should -Not -Match $script:systemDataNamespacePattern
  }

  It 'pins and resolves XML crypto exactly at 10.0.10' {
    $centralPin = @($script:packageReferences | Where-Object { $_.Element -eq 'PackageVersion' -and $_.Package -eq 'System.Security.Cryptography.Xml' })
    $centralPin.Count | Should -Be 1
    $centralPin[0].Version | Should -BeExactly '10.0.10'
    $resolvedVersions = @($script:lockNodes | Where-Object { $_.Package -eq 'System.Security.Cryptography.Xml' } | Select-Object -ExpandProperty Resolved -Unique)
    $resolvedVersions | Should -Be @('10.0.10')
  }

  It 'retains exactly the three intentional direct XML crypto references' {
    $expectedPaths = @('samples/ATAP.Service.Service02/ATAP.Service.Service02.csproj', 'src/ATAP.Utilities.Http/ATAP.Utilities.Http.csproj', 'src/ATAP.Utilities.Testing.Fixture.Database/ATAP.Utilities.Testing.Fixture.Database.csproj')
    $actualPaths = @($script:packageReferences | Where-Object { $_.Element -eq 'PackageReference' -and $_.Package -eq 'System.Security.Cryptography.Xml' -and $_.Path -notmatch '^tests/' } | Select-Object -ExpandProperty Path | Sort-Object -Unique)
    $actualPaths | Should -Be $expectedPaths
  }

  It 'permits only the reviewed resolved prerelease package allowlist' {
    $allowedPrereleases = @('Azure.AI.OpenAI|2.7.0-beta.2', 'Microsoft.Extensions.AI.OpenAI|10.0.1-preview.1.25571.5')
    $actualPrereleases = @($script:lockNodes | Where-Object { $_.Resolved -match '-' } | ForEach-Object { "$($_.Package)|$($_.Resolved)" } | Sort-Object -Unique)
    $actualPrereleases | Should -Be $allowedPrereleases
  }

  It 'has parseable version 2 lock files with dependency graphs' {
    $script:lockDocuments.Count | Should -Be $script:lockPaths.Count
    @($script:lockDocuments | Where-Object { $_.Json.version -ne 2 }).Count | Should -Be 0
    @($script:lockDocuments | Where-Object { $_.Json.dependencies.Count -eq 0 }).Count | Should -Be 0
  }
}