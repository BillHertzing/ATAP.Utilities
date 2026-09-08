#Requires -Version 7.0
#Requires -Module Pester

Describe 'Ace consumer package version-line policy' -Tag 'RepoHealth' {
  BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $script:FilterPaths = @(
      'ATAP.Utilities.AceCommander.slnf'
      'ATAP.Utilities.AceOutpost.slnf'
    )
    $script:AllowlistPath = 'tests/RepoHealth/Package.AceConsumerVersionLine.Allowlist.json'
    $script:ProtectedVersionPaths = @(
      'src/ATAP.Utilities.Collection.Extensions/version.json'
      'src/ATAP.Utilities.DateTime.Interfaces/version.json'
      'src/ATAP.Utilities.DateTime.Model/version.json'
      'src/ATAP.Utilities.DateTime.StringConstants/version.json'
      'src/ATAP.Utilities.DateTime/version.json'
      'src/ATAP.Utilities.Loader/version.json'
      'src/ATAP.Utilities.Logging/version.json'
      'src/ATAP.Utilities.Philote/version.json'
      'src/ATAP.Utilities.Secrets/BitwardenSecretsManager/version.json'
      'src/ATAP.Utilities.Secrets/BitwardenSecretsManager/Windows/version.json'
      'src/ATAP.Utilities.Serializer/Interfaces/version.json'
      'src/ATAP.Utilities.Serializer/Shim/Newtonsoft/version.json'
      'src/ATAP.Utilities.Serializer/Shim/SystemTextJson/version.json'
      'src/ATAP.Utilities.Serializer/Shim/version.json'
      'src/ATAP.Utilities.StronglyTypedId/version.json'
      'src/ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson/version.json'
      'src/ATAP.Utilities.Testing.Fixture.Serialization/version.json'
    )

    function ConvertTo-RepoRelativePath {
      param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Context
      )

      if ([IO.Path]::IsPathRooted($Path) -or $Path -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "$Context must be a repository-relative path without parent traversal: '$Path'."
      }
      $normalized = $Path.Replace('\', '/').TrimStart('/')
      if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized.IndexOfAny([char[]]@('*', '?', '[', ']')) -ge 0) {
        throw "$Context is empty or overbroad: '$Path'."
      }
      return $normalized
    }

    function Read-StrictJson {
      param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Context
      )

      if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Context was not found: $Path"
      }
      try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
      } catch {
        throw "$Context is malformed JSON: $Path. $($_.Exception.Message)"
      }
    }

    function Assert-ExactProperties {
      param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)][string[]] $Expected,
        [Parameter(Mandatory)][string] $Context
      )

      $actual = @($Object.PSObject.Properties.Name | Sort-Object)
      $expectedSorted = @($Expected | Sort-Object)
      if (($actual -join '|') -cne ($expectedSorted -join '|')) {
        throw "$Context must contain exactly [$($expectedSorted -join ', ')]; found [$($actual -join ', ')]."
      }
    }

    function Get-ProjectProperty {
      param(
        [Parameter(Mandatory)][xml] $ProjectXml,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $ProjectPath
      )

      $values = @(
        $ProjectXml.Project.PropertyGroup.ChildNodes |
          Where-Object { $_.NodeType -eq [Xml.XmlNodeType]::Element -and $_.LocalName -ceq $Name } |
          ForEach-Object { $_.InnerText.Trim() } |
          Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
          Sort-Object -Unique
      )
      if ($values.Count -gt 1) {
        throw "Project '$ProjectPath' has ambiguous $Name values: $($values -join ', ')."
      }
  if ($values.Count -eq 1) {
    return $values[0]
  }
  return $null
    }

    function Resolve-PackableProject {
      param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $RelativePath
      )

      $normalizedProject = ConvertTo-RepoRelativePath -Path $RelativePath -Context 'Solution-filter project path'
      if (-not $normalizedProject.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Solution-filter entry is not a C# project: '$normalizedProject'."
      }
      $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
      $projectFull = [IO.Path]::GetFullPath((Join-Path $rootFull $normalizedProject))
      if (-not $projectFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
          -not (Test-Path -LiteralPath $projectFull -PathType Leaf)) {
        throw "Solution-filter project is unresolved or outside the repository: '$normalizedProject'."
      }

      try {
        [xml] $projectXml = Get-Content -LiteralPath $projectFull -Raw -ErrorAction Stop
      } catch {
        throw "Project is not parseable XML: '$normalizedProject'. $($_.Exception.Message)"
      }
      $isPackableText = Get-ProjectProperty -ProjectXml $projectXml -Name 'IsPackable' -ProjectPath $normalizedProject
      if ($null -eq $isPackableText -or $isPackableText -ieq 'false') {
        return [pscustomobject]@{ ProjectPath = $normalizedProject; IsPackable = $false }
      }
      if ($isPackableText -ine 'true') {
        throw "Project '$normalizedProject' has invalid IsPackable value '$isPackableText'."
      }

      $packageId = Get-ProjectProperty -ProjectXml $projectXml -Name 'PackageId' -ProjectPath $normalizedProject
      if ([string]::IsNullOrWhiteSpace($packageId)) {
        $packageId = [IO.Path]::GetFileNameWithoutExtension($projectFull)
      }
      if ([string]::IsNullOrWhiteSpace($packageId) -or $packageId -match '[*?\[\]]') {
        throw "Packable project '$normalizedProject' has an empty or overbroad PackageId '$packageId'."
      }

      $directory = Split-Path -Parent $projectFull
      $versionFull = $null
      while ($directory.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        $candidate = Join-Path $directory 'version.json'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
          $versionFull = [IO.Path]::GetFullPath($candidate)
          break
        }
        if ($directory -ceq $rootFull) { break }
        $directory = Split-Path -Parent $directory
      }
      if ($null -eq $versionFull) {
        throw "Packable project '$normalizedProject' has no governing version.json in its ancestor chain."
      }

      $versionDocument = Read-StrictJson -Path $versionFull -Context "Governing version for '$normalizedProject'"
      $version = [string] $versionDocument.version
      if ($version -notmatch '^(?<major>0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$') {
        throw "Packable project '$normalizedProject' has invalid governing version '$version'."
      }

      return [pscustomobject]@{
        ProjectPath = $normalizedProject
        IsPackable = $true
        PackageId = $packageId
        Version = $version
        Major = [int] $Matches.major
        GoverningVersionPath = [IO.Path]::GetRelativePath($rootFull, $versionFull).Replace('\', '/')
      }
    }

    function Get-AceConsumerPackageClosure {
      param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string[]] $FilterPaths,
        [Parameter(Mandatory)][string[]] $ProtectedVersionPaths
      )

      if ($FilterPaths.Count -ne 2) {
        throw "Exactly two Ace solution filters are required; found $($FilterPaths.Count)."
      }
      $normalizedProtected = @($ProtectedVersionPaths | ForEach-Object {
        ConvertTo-RepoRelativePath -Path $_ -Context 'Protected governing-version path'
      })
      if (@($normalizedProtected | Sort-Object -Unique).Count -ne $normalizedProtected.Count) {
        throw 'Protected governing-version paths contain duplicates.'
      }
      $protectedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $normalizedProtected | ForEach-Object { [void] $protectedSet.Add($_) }

      $solutionPath = $null
      $union = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($filterRelative in $FilterPaths) {
        $normalizedFilter = ConvertTo-RepoRelativePath -Path $filterRelative -Context 'Solution-filter path'
        $filterFull = Join-Path $Root $normalizedFilter
        $filter = Read-StrictJson -Path $filterFull -Context "Solution filter '$normalizedFilter'"
        if ($null -eq $filter.solution -or [string]::IsNullOrWhiteSpace([string] $filter.solution.path) -or $null -eq $filter.solution.projects) {
          throw "Solution filter '$normalizedFilter' is missing solution.path or solution.projects."
        }
        $currentSolutionPath = ConvertTo-RepoRelativePath -Path ([string] $filter.solution.path) -Context "Solution path in '$normalizedFilter'"
        if ($null -eq $solutionPath) { $solutionPath = $currentSolutionPath }
        elseif ($solutionPath -ine $currentSolutionPath) {
          throw "Solution filters disagree: '$solutionPath' versus '$currentSolutionPath'."
        }

        $seenInFilter = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($projectRelative in @($filter.solution.projects)) {
          $normalizedProject = ConvertTo-RepoRelativePath -Path ([string] $projectRelative) -Context "Project in '$normalizedFilter'"
          if (-not $seenInFilter.Add($normalizedProject)) {
            throw "Solution filter '$normalizedFilter' contains duplicate project '$normalizedProject'."
          }
          if (-not $union.ContainsKey($normalizedProject)) {
            $union.Add($normalizedProject, (Resolve-PackableProject -Root $Root -RelativePath $normalizedProject))
          }
        }
      }

      $packable = @($union.Values | Where-Object IsPackable)
      $byPackageId = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($project in $packable) {
        if ($byPackageId.ContainsKey($project.PackageId)) {
          $prior = $byPackageId[$project.PackageId]
          throw "Duplicate PackageId '$($project.PackageId)' maps to '$($prior.ProjectPath)' and '$($project.ProjectPath)'."
        }
        $byPackageId.Add($project.PackageId, $project)
      }

      $closure = @($packable | Where-Object { $protectedSet.Contains($_.GoverningVersionPath) } | Sort-Object PackageId)
      $represented = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $closure | ForEach-Object { [void] $represented.Add($_.GoverningVersionPath) }
      $missingProtected = @($normalizedProtected | Where-Object { -not $represented.Contains($_) })
      if ($missingProtected.Count -gt 0) {
        throw "Filter disagreement: protected governing-version paths have no packable project in the union: $($missingProtected -join ', ')."
      }
      return $closure
    }

    function Read-FutureMajorAllowlist {
      param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $RelativePath,
        [Parameter(Mandatory)][object[]] $Closure
      )

      $normalizedPath = ConvertTo-RepoRelativePath -Path $RelativePath -Context 'Allowlist path'
      $document = Read-StrictJson -Path (Join-Path $Root $normalizedPath) -Context 'Future-major allowlist'
      Assert-ExactProperties -Object $document -Expected @('schema', 'entries') -Context 'Future-major allowlist root'
      if ([string] $document.schema -cne 'atap.repohealth.ace-consumer-future-major-allowlist.v1') {
        throw "Future-major allowlist has unsupported schema '$($document.schema)'."
      }
      if ($null -eq $document.entries) {
        throw 'Future-major allowlist entries must be an array (empty is valid).'
      }

      $authorizations = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($entry in @($document.entries)) {
        Assert-ExactProperties -Object $entry -Expected @('packageId', 'version', 'decisionEvidencePath', 'decisionEvidenceSha256') -Context 'Future-major allowlist entry'
        $packageId = [string] $entry.packageId
        $version = [string] $entry.version
        if ([string]::IsNullOrWhiteSpace($packageId) -or $packageId -match '[*?\[\]]') {
          throw "Future-major allowlist PackageId is empty or overbroad: '$packageId'."
        }
        if ($version -notmatch '^(?<major>[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$') {
          throw "Future-major allowlist version must be an exact major-version semantic version: '$version'."
        }
        $evidenceRelative = ConvertTo-RepoRelativePath -Path ([string] $entry.decisionEvidencePath) -Context 'Decision-evidence path'
        $expectedHash = [string] $entry.decisionEvidenceSha256
        if ($expectedHash -cnotmatch '^[0-9a-f]{64}$') {
          throw "Decision-evidence SHA-256 must be 64 lowercase hexadecimal characters: '$expectedHash'."
        }
        $evidenceFull = [IO.Path]::GetFullPath((Join-Path $Root $evidenceRelative))
        $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        if (-not $evidenceFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $evidenceFull -PathType Leaf)) {
          throw "Decision evidence is missing or outside the repository: '$evidenceRelative'."
        }
        $actualHash = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne $expectedHash) {
          throw "Decision-evidence SHA-256 mismatch for '$evidenceRelative'."
        }
        $key = "$packageId|$version"
        if ($authorizations.ContainsKey($key)) {
          throw "Future-major allowlist contains duplicate authorization '$key'."
        }
        $match = @($Closure | Where-Object { $_.PackageId -ceq $packageId -and $_.Version -ceq $version })
        if ($match.Count -ne 1) {
          throw "Future-major allowlist contains stale authorization '$key'; the exact package/version is not in the protected closure."
        }
        $authorizations.Add($key, $entry)
      }
      return $authorizations
    }

    function Assert-AceConsumerVersionLine {
      param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string[]] $FilterPaths,
        [Parameter(Mandatory)][string[]] $ProtectedVersionPaths,
        [Parameter(Mandatory)][string] $AllowlistPath
      )

      $closure = @(Get-AceConsumerPackageClosure -Root $Root -FilterPaths $FilterPaths -ProtectedVersionPaths $ProtectedVersionPaths)
      $authorizations = Read-FutureMajorAllowlist -Root $Root -RelativePath $AllowlistPath -Closure $closure
      foreach ($package in $closure) {
        if ($package.Major -ge 1 -and -not $authorizations.ContainsKey("$($package.PackageId)|$($package.Version)")) {
          throw "Unratified major version '$($package.Version)' for protected Ace consumer package '$($package.PackageId)'."
        }
      }
      return $closure
    }

    function New-VersionLineFixture {
      param(
        [Parameter(Mandatory)][string] $Root,
        [string] $Version = '0.1.1',
        [string] $PackageId = 'Contoso.Real.Package',
        [switch] $NoVersion
      )

      $Root = Join-Path $Root ([guid]::NewGuid().ToString('N'))
      [IO.Directory]::CreateDirectory($Root) | Out-Null
      $parent = Join-Path $Root 'src\Parent'
      $projectDirectory = Join-Path $parent 'Directory.Does.Not.Match.Package'
      [IO.Directory]::CreateDirectory($projectDirectory) | Out-Null
      $projectRelative = 'src/Parent/Directory.Does.Not.Match.Package/Different.Project.Name.csproj'
      @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <IsPackable>true</IsPackable>
    <PackageId>$PackageId</PackageId>
  </PropertyGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $Root $projectRelative)
      if (-not $NoVersion) {
        @{
          '$schema' = 'https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/main/src/NerdBank.GitVersioning/version.schema.json'
          version = $Version
          publicReleaseRefSpec = @('^refs/heads/main$')
          cloudBuild = @{ setVersionVariables = $true }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $parent 'version.json')
      }
      foreach ($name in @('Commander.slnf', 'Outpost.slnf')) {
        @{ solution = @{ path = 'Fixture.sln'; projects = @($projectRelative) } } |
          ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Root $name)
      }
      @{ schema = 'atap.repohealth.ace-consumer-future-major-allowlist.v1'; entries = @() } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $Root 'allowlist.json')
      return [pscustomobject]@{
        Root = $Root
        FilterPaths = @('Commander.slnf', 'Outpost.slnf')
        ProtectedVersionPaths = @('src/Parent/version.json')
        AllowlistPath = 'allowlist.json'
        ProjectPath = $projectRelative
      }
    }
  }

  It 'accepts the current empty allowlist and exact 25-identity protected closure' {
    $closure = @(Assert-AceConsumerVersionLine -Root $script:RepoRoot -FilterPaths $script:FilterPaths -ProtectedVersionPaths $script:ProtectedVersionPaths -AllowlistPath $script:AllowlistPath)
    $closure.Count | Should -Be 25
    @($closure.PackageId | Sort-Object -Unique).Count | Should -Be 25
    @($closure.GoverningVersionPath | Sort-Object -Unique).Count | Should -Be 17
    @($closure | Where-Object Major -GE 1).Count | Should -Be 0
    @((Read-StrictJson -Path (Join-Path $script:RepoRoot $script:AllowlistPath) -Context 'Current allowlist').entries).Count | Should -Be 0
  }

  It 'resolves an inherited parent version and explicit PackageId independently of directory and project names' {
    $fixture = New-VersionLineFixture -Root $TestDrive
    $closure = @(Get-AceConsumerPackageClosure -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths $fixture.ProtectedVersionPaths)
    $closure.Count | Should -Be 1
    $closure[0].PackageId | Should -BeExactly 'Contoso.Real.Package'
    $closure[0].ProjectPath | Should -BeExactly $fixture.ProjectPath
    $closure[0].GoverningVersionPath | Should -BeExactly 'src/Parent/version.json'
  }

  It 'rejects an unratified major version' {
    $fixture = New-VersionLineFixture -Root $TestDrive -Version '1.0.0'
    { Assert-AceConsumerVersionLine -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths $fixture.ProtectedVersionPaths -AllowlistPath $fixture.AllowlistPath } |
      Should -Throw '*Unratified major version*'
  }

  It 'accepts one exact future-major authorization with matching decision evidence' {
    $fixture = New-VersionLineFixture -Root $TestDrive -Version '2.3.4'
    $evidenceRelative = 'InformationForTheFuture/Decision-2.3.4.md'
    $evidenceFull = Join-Path $fixture.Root $evidenceRelative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $evidenceFull)) | Out-Null
    'Ratified decision for Contoso.Real.Package 2.3.4.' | Set-Content -LiteralPath $evidenceFull
    $hash = (Get-FileHash -LiteralPath $evidenceFull -Algorithm SHA256).Hash.ToLowerInvariant()
    @{
      schema = 'atap.repohealth.ace-consumer-future-major-allowlist.v1'
      entries = @(@{
        packageId = 'Contoso.Real.Package'
        version = '2.3.4'
        decisionEvidencePath = $evidenceRelative
        decisionEvidenceSha256 = $hash
      })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $fixture.Root $fixture.AllowlistPath)

    { Assert-AceConsumerVersionLine -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths $fixture.ProtectedVersionPaths -AllowlistPath $fixture.AllowlistPath } |
      Should -Not -Throw
  }

  It 'rejects malformed, overbroad, duplicate, and stale allowlist content' -ForEach @(
    @{ Case = 'malformed'; Configure = { param($root, $fixture) '{not-json' | Set-Content -LiteralPath (Join-Path $root $fixture.AllowlistPath) }; Pattern = '*malformed JSON*' }
    @{ Case = 'overbroad'; Configure = {
        param($root, $fixture)
        @{ schema = 'atap.repohealth.ace-consumer-future-major-allowlist.v1'; entries = @(@{ packageId = '*'; version = '1.0.0'; decisionEvidencePath = 'decision.md'; decisionEvidenceSha256 = ('a' * 64) }) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $root $fixture.AllowlistPath)
      }; Pattern = '*empty or overbroad*' }
    @{ Case = 'duplicate'; Configure = {
        param($root, $fixture)
        $evidence = Join-Path $root 'decision.md'; 'decision' | Set-Content -LiteralPath $evidence; $hash = (Get-FileHash $evidence -Algorithm SHA256).Hash.ToLowerInvariant()
        $entry = @{ packageId = 'Contoso.Real.Package'; version = '1.0.0'; decisionEvidencePath = 'decision.md'; decisionEvidenceSha256 = $hash }
        @{ schema = 'atap.repohealth.ace-consumer-future-major-allowlist.v1'; entries = @($entry, $entry) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $root $fixture.AllowlistPath)
      }; Pattern = '*duplicate authorization*' }
    @{ Case = 'stale'; Configure = {
        param($root, $fixture)
        $evidence = Join-Path $root 'decision.md'; 'decision' | Set-Content -LiteralPath $evidence; $hash = (Get-FileHash $evidence -Algorithm SHA256).Hash.ToLowerInvariant()
        @{ schema = 'atap.repohealth.ace-consumer-future-major-allowlist.v1'; entries = @(@{ packageId = 'Contoso.Other'; version = '1.0.0'; decisionEvidencePath = 'decision.md'; decisionEvidenceSha256 = $hash }) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $root $fixture.AllowlistPath)
      }; Pattern = '*stale authorization*' }
  ) {
    $caseRoot = Join-Path $TestDrive $Case
    [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
    $fixture = New-VersionLineFixture -Root $caseRoot -Version '1.0.0'
    & $Configure $fixture.Root $fixture
    { Assert-AceConsumerVersionLine -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths $fixture.ProtectedVersionPaths -AllowlistPath $fixture.AllowlistPath } |
      Should -Throw $Pattern
  }

  It 'fails closed on a missing governing version' {
    $fixture = New-VersionLineFixture -Root $TestDrive -NoVersion
    { Get-AceConsumerPackageClosure -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths $fixture.ProtectedVersionPaths } |
      Should -Throw '*no governing version.json*'
  }

  It 'fails closed on duplicate PackageId values' {
    $fixture = New-VersionLineFixture -Root $TestDrive
    $secondDirectory = Join-Path $fixture.Root 'src\Second'
    [IO.Directory]::CreateDirectory($secondDirectory) | Out-Null
    Copy-Item -LiteralPath (Join-Path $fixture.Root $fixture.ProjectPath) -Destination (Join-Path $secondDirectory 'Second.csproj')
    Copy-Item -LiteralPath (Join-Path $fixture.Root 'src\Parent\version.json') -Destination (Join-Path $secondDirectory 'version.json')
    foreach ($filter in $fixture.FilterPaths) {
      $document = Get-Content -LiteralPath (Join-Path $fixture.Root $filter) -Raw | ConvertFrom-Json
      $document.solution.projects = @($document.solution.projects) + 'src/Second/Second.csproj'
      $document | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $fixture.Root $filter)
    }
    { Get-AceConsumerPackageClosure -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths @($fixture.ProtectedVersionPaths + 'src/Second/version.json') } |
      Should -Throw '*Duplicate PackageId*'
  }

  It 'fails closed on an unresolved project and solution-filter disagreement' -ForEach @(
    @{ Case = 'unresolved'; Configure = { param($root) $document = Get-Content (Join-Path $root 'Commander.slnf') -Raw | ConvertFrom-Json; $document.solution.projects = @('src/Missing/Missing.csproj'); $document | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'Commander.slnf') }; Pattern = '*unresolved or outside*' }
    @{ Case = 'disagreement'; Configure = { param($root) $document = Get-Content (Join-Path $root 'Outpost.slnf') -Raw | ConvertFrom-Json; $document.solution.path = 'Other.sln'; $document | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'Outpost.slnf') }; Pattern = '*Solution filters disagree*' }
  ) {
    $caseRoot = Join-Path $TestDrive $Case
    [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
    $fixture = New-VersionLineFixture -Root $caseRoot
    & $Configure $fixture.Root
    { Get-AceConsumerPackageClosure -Root $fixture.Root -FilterPaths $fixture.FilterPaths -ProtectedVersionPaths $fixture.ProtectedVersionPaths } |
      Should -Throw $Pattern
  }
}
