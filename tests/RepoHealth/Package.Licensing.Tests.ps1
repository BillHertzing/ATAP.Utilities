#Requires -Module Pester

# Task 15.185.j: package licensing contract.
#
# The repository-level block asserts the declarations in Directory.Build.props and the
# currency of THIRD-PARTY-NOTICES.md. The packed block packs a representative project
# and asserts against the EXACT BUILT BYTES of the resulting .nupkg, because the defect
# this task exists to prevent — an MIT expression with no MIT text in the package — is
# invisible in the project file and visible only in the package.

BeforeAll {
  $testDirectory = Split-Path -Path $PSCommandPath -Parent
  $script:repoRoot = (Resolve-Path -Path (Join-Path $testDirectory '..\..')).Path
  $script:buildPropsPath = Join-Path $script:repoRoot 'Directory.Build.props'
  $script:packagesPropsPath = Join-Path $script:repoRoot 'Directory.Packages.props'
  $script:licensePath = Join-Path $script:repoRoot 'LICENSE'
  $script:noticesPath = Join-Path $script:repoRoot 'THIRD-PARTY-NOTICES.md'

  # Representative package: a leaf project with no package dependencies, so a pack
  # failure here is attributable to the licensing contract and not to a dependency.
  $script:representativeProject = Join-Path $script:repoRoot 'src\ATAP.Services.GenerateProgram.StringConstants\ATAP.Services.GenerateProgram.StringConstants.csproj'

  foreach ($name in @('ATAP_ARTIFACTS_ROOT', 'ATAP_ARTIFACTS_WORKTREE_ID', 'ATAP_ARTIFACTS_EXECUTION_ID', 'ATAP_ARTIFACTS_PATH')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, 'Process'))) {
      throw "RepoHealth requires process environment value $name."
    }
  }

  [xml] $script:buildProps = Get-Content -LiteralPath $script:buildPropsPath -Raw
  [xml] $script:packagesProps = Get-Content -LiteralPath $script:packagesPropsPath -Raw

  function script:Get-BuildPropValue {
    param([Parameter(Mandatory)][string] $Name)
    foreach ($group in $script:buildProps.Project.PropertyGroup) {
      $node = $group.SelectSingleNode($Name)
      if ($null -ne $node) { return [string] $node.InnerText }
    }
    return $null
  }

  function script:Invoke-RepresentativePack {
    # R-34: drain both redirected streams before waiting on the process.
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'dotnet'
    $start.WorkingDirectory = $script:repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        'pack', $script:representativeProject, '-c', 'Release', '--nologo'
        "-property:ATAPArtifactsRoot=$env:ATAP_ARTIFACTS_ROOT"
        "-property:ATAPArtifactsWorktreeId=$env:ATAP_ARTIFACTS_WORKTREE_ID"
        "-property:ATAPArtifactsExecutionId=$env:ATAP_ARTIFACTS_EXECUTION_ID"
        "-property:ArtifactsPath=$env:ATAP_ARTIFACTS_PATH"
        '-property:ATAPExplicitPublicationInvocation=true'
      )) { $start.ArgumentList.Add($argument) }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Could not start dotnet pack.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $text = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw "dotnet pack failed (exit $($process.ExitCode)): $text" }

    $packageDirectory = Join-Path $env:ATAP_ARTIFACTS_PATH 'package\release'
    $package = Get-ChildItem -LiteralPath $packageDirectory -Filter 'ATAP.Services.GenerateProgram.StringConstants.*.nupkg' -File |
      Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if (-not $package) { throw "No representative package was produced under '$packageDirectory'." }
    return $package.FullName
  }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $script:packagePath = script:Invoke-RepresentativePack
  $archive = [IO.Compression.ZipFile]::OpenRead($script:packagePath)
  try {
    $script:packageEntryNames = @($archive.Entries | ForEach-Object { $_.FullName })

    $licenseEntry = $archive.Entries | Where-Object { $_.FullName -ceq 'LICENSE' } | Select-Object -First 1
    $script:packagedLicenseText = if ($licenseEntry) {
      $reader = [IO.StreamReader]::new($licenseEntry.Open())
      try { $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    else { $null }

    $nuspecEntry = $archive.Entries | Where-Object { $_.FullName -like '*.nuspec' } | Select-Object -First 1
    if (-not $nuspecEntry) { throw "The representative package contains no .nuspec." }
    $reader = [IO.StreamReader]::new($nuspecEntry.Open())
    try { $script:packedNuspecText = $reader.ReadToEnd() } finally { $reader.Dispose() }
  }
  finally { $archive.Dispose() }

  [xml] $script:packedNuspec = $script:packedNuspecText
  $script:packedMetadata = $script:packedNuspec.package.metadata
}

Describe 'ATAP.Utilities repository licensing declarations' -Tag 'RepoHealth', 'Packaging', 'Licensing' {
  It 'has a root LICENSE file' {
    Test-Path -LiteralPath $script:licensePath -PathType Leaf | Should -BeTrue
  }

  It 'declares a PackageLicenseExpression' {
    script:Get-BuildPropValue -Name 'PackageLicenseExpression' | Should -Be 'MIT'
  }

  It 'does not declare PackageLicenseFile anywhere: NuGet treats expression and file as mutually exclusive' {
    # Scanned across every project file too, not just the repository-level props/targets:
    # a single csproj re-declaring PackageLicenseFile reintroduces the contradiction for
    # that package alone, which the representative-package pack would not catch.
    $searchPaths = @(
      Join-Path $script:repoRoot 'Directory.Build.props'
      Join-Path $script:repoRoot 'Directory.Build.targets'
    ) + @(
      Get-ChildItem -LiteralPath (Join-Path $script:repoRoot 'src') -Filter '*.csproj' -Recurse -File |
        ForEach-Object { $_.FullName }
    )
    $declarations = Select-String -Path $searchPaths -Pattern '<PackageLicenseFile>' -SimpleMatch -ErrorAction SilentlyContinue
    @($declarations) | Should -HaveCount 0 -Because "found in: $(@($declarations | ForEach-Object { $_.Path }) -join ', ')"
  }

  It 'states the same copyright holder in LICENSE and in the Copyright property' {
    $copyrightProperty = script:Get-BuildPropValue -Name 'Copyright'
    $copyrightProperty | Should -Not -BeNullOrEmpty
    $licenseText = Get-Content -LiteralPath $script:licensePath -Raw
    $licenseText | Should -Match ([regex]::Escape($copyrightProperty))
  }

  It 'declares a real PackageProjectUrl rather than a placeholder' {
    $projectUrl = script:Get-BuildPropValue -Name 'PackageProjectUrl'
    $projectUrl | Should -Not -BeNullOrEmpty
    $projectUrl | Should -Not -Match '(?i)(project|icon)\.url'
    [uri]::IsWellFormedUriString($projectUrl, [UriKind]::Absolute) | Should -BeTrue
  }

  It 'does not declare the deprecated PackageIconUrl' {
    script:Get-BuildPropValue -Name 'PackageIconUrl' | Should -BeNullOrEmpty
  }

  It 'declares repository source attribution' {
    $repositoryUrl = script:Get-BuildPropValue -Name 'RepositoryUrl'
    $repositoryUrl | Should -Not -BeNullOrEmpty
    [uri]::IsWellFormedUriString($repositoryUrl, [UriKind]::Absolute) | Should -BeTrue
  }
}

Describe 'ATAP.Utilities third-party notices' -Tag 'RepoHealth', 'Packaging', 'Licensing' {
  It 'has a generated THIRD-PARTY-NOTICES.md' {
    Test-Path -LiteralPath $script:noticesPath -PathType Leaf | Should -BeTrue
  }

  It 'records a notice entry for every third-party package version under central package management' {
    $noticesText = Get-Content -LiteralPath $script:noticesPath -Raw
    $missing = foreach ($packageVersion in $script:packagesProps.Project.ItemGroup.PackageVersion) {
      if (-not $packageVersion.Include) { continue }
      if ($packageVersion.Include -like 'ATAP.*') { continue }
      $row = '| `{0}` | `{1}` |' -f [string] $packageVersion.Include, [string] $packageVersion.Version
      # String.Contains, not -like: the notices file is multi-line and the row text is a
      # literal substring, not a wildcard pattern.
      if (-not $noticesText.Contains($row)) { $row }
    }
    # Regenerate with: pwsh -File Build\New-ThirdPartyNotices.ps1
    @($missing) | Should -HaveCount 0 -Because "every third-party package must carry a notice row; missing: $($missing -join ', ')"
  }
}

Describe 'ATAP.Utilities dependency license tripwire' -Tag 'RepoHealth', 'Packaging', 'Licensing' {
  # A version bump can silently move a dependency onto a paid commercial license.
  # AutoMapper v15+ and FluentAssertions v8+ are the known cases. This block fails the
  # build when a restored dependency's DECLARED license no longer matches the reviewed
  # baseline, or when a dependency appears that has never been license-reviewed.
  BeforeAll {
    $script:baselinePath = Join-Path (Split-Path -Parent $PSCommandPath) 'Package.Licensing.Baseline.json'
    $script:baseline = (Get-Content -LiteralPath $script:baselinePath -Raw | ConvertFrom-Json).packages
    $script:globalPackagesFolder = Join-Path $env:USERPROFILE '.nuget\packages'

    function script:Get-DeclaredLicense {
      param([Parameter(Mandatory)][string] $Id, [Parameter(Mandatory)][string] $Version)
      $nuspecPath = Join-Path $script:globalPackagesFolder (Join-Path $Id.ToLowerInvariant() (Join-Path $Version ($Id.ToLowerInvariant() + '.nuspec')))
      if (-not (Test-Path -LiteralPath $nuspecPath)) { return $null }
      $metadata = ([xml](Get-Content -LiteralPath $nuspecPath -Raw)).package.metadata
      if ($metadata.license) {
        $prefix = switch ([string] $metadata.license.type) { 'expression' { 'SPDX ' } 'file' { 'file: ' } default { '' } }
        return $prefix + [string] $metadata.license.'#text'
      }
      if ($metadata.licenseUrl) { return 'url: ' + [string] $metadata.licenseUrl }
      return 'NONE-DECLARED'
    }
  }

  It 'has a reviewed license baseline' {
    Test-Path -LiteralPath $script:baselinePath -PathType Leaf | Should -BeTrue
  }

  It 'reports no restored third-party dependency whose declared license changed or is unreviewed' {
    $violations = foreach ($packageVersion in $script:packagesProps.Project.ItemGroup.PackageVersion) {
      if (-not $packageVersion.Include) { continue }
      if ($packageVersion.Include -like 'ATAP.*') { continue }
      $id = [string] $packageVersion.Include
      $version = [string] $packageVersion.Version

      $declared = script:Get-DeclaredLicense -Id $id -Version $version
      # Not restored on this workstation: unknown, not changed. Reported by
      # Build\New-ThirdPartyNotices.ps1 as UNRESOLVED rather than failed here.
      if ($null -eq $declared) { continue }

      $baselineEntry = $script:baseline.$id
      if ($null -eq $baselineEntry) {
        "$id $version is not in the license baseline (new dependency requires license review)"
        continue
      }
      if ($declared -cne [string] $baselineEntry.license) {
        "$id moved from '$([string] $baselineEntry.license)' at $([string] $baselineEntry.version) to '$declared' at $version"
      }
    }
    # If a change here is intended and reviewed, regenerate Package.Licensing.Baseline.json
    # deliberately and record the decision. Do not regenerate to silence this test.
    @($violations) | Should -HaveCount 0 -Because ($violations -join '; ')
  }
}

Describe 'ATAP.Utilities packed package licensing contract' -Tag 'RepoHealth', 'Integration', 'Packaging', 'Licensing' {
  It 'packs the license file into the package bytes' {
    $script:packageEntryNames | Should -Contain 'LICENSE'
  }

  It 'packs license text identical to the repository LICENSE' {
    $script:packagedLicenseText | Should -Not -BeNullOrEmpty
    $expected = (Get-Content -LiteralPath $script:licensePath -Raw) -replace "`r`n", "`n"
    ($script:packagedLicenseText -replace "`r`n", "`n") | Should -BeExactly $expected
  }

  It 'declares exactly one license form in the packed nuspec' {
    $licenseNode = $script:packedMetadata.SelectSingleNode('*[local-name()="license"]')
    $licenseNode | Should -Not -BeNullOrEmpty
    # A file-type license alongside the expression is the contradiction Task 15.185.j forbids.
    [string] $licenseNode.type | Should -Be 'expression'
  }

  It 'declares the MIT expression in the packed nuspec' {
    $licenseNode = $script:packedMetadata.SelectSingleNode('*[local-name()="license"]')
    [string] $licenseNode.InnerText | Should -Be 'MIT'
  }

  It 'declares a non-placeholder projectUrl in the packed nuspec' {
    $projectUrl = [string] $script:packedMetadata.projectUrl
    $projectUrl | Should -Not -BeNullOrEmpty
    # The historical defect was the literal string 'www.project.url'. Rejecting only the
    # bare form would let 'http://www.project.url' through as a well-formed absolute URI,
    # so the placeholder token itself is rejected wherever it appears.
    $projectUrl | Should -Not -Match '(?i)(project|icon)\.url'
    [uri]::IsWellFormedUriString($projectUrl, [UriKind]::Absolute) | Should -BeTrue
  }

  It 'declares no iconUrl in the packed nuspec' {
    [string] $script:packedMetadata.iconUrl | Should -BeNullOrEmpty
  }

  It 'declares repository source attribution with a commit in the packed nuspec' {
    $repository = $script:packedMetadata.SelectSingleNode('*[local-name()="repository"]')
    $repository | Should -Not -BeNullOrEmpty
    [string] $repository.url | Should -Not -BeNullOrEmpty
    [string] $repository.commit | Should -Match '^[0-9a-f]{40}$'
  }

  It 'declares a copyright in the packed nuspec' {
    [string] $script:packedMetadata.copyright | Should -Not -BeNullOrEmpty
  }
}
