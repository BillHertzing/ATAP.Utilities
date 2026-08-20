#Requires -Module Pester

BeforeAll {
  $script:testPath = $PSCommandPath
  $script:repoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $script:testPath) '..\..')).Path
  $script:fixtureRoot = Join-Path $script:repoRoot '_generated\Sprint0015\Task15.180\j\common-build-tests'
  $script:projectPath = Join-Path $script:fixtureRoot 'Fixture.csproj'
  $script:externalRoot = Join-Path ([IO.Path]::GetTempPath()) ('ATAP-Task15.180j-' + [guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($script:fixtureRoot) | Out-Null
  [IO.Directory]::CreateDirectory($script:externalRoot) | Out-Null
  [IO.File]::WriteAllText($script:projectPath, '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>', [Text.UTF8Encoding]::new($false))

  function script:Invoke-CommonBuildTarget {
    param(
      [string] $Root = $script:externalRoot,
      [string] $Worktree = 'wt-a',
      [string] $Execution = 'exec-a',
      [string] $Artifacts,
      [hashtable] $Properties = @{}
    )
    if (-not $PSBoundParameters.ContainsKey('Artifacts')) {
      $Artifacts = if ($Root) { Join-Path $Root "dotnet\ATAP.Utilities\$Worktree\$Execution" } else { '' }
    }
    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($value in @('msbuild', $script:projectPath, '-t:ValidateATAPCommonBuildContract', '-v:minimal', "-p:ATAPArtifactsRoot=$Root", "-p:ATAPArtifactsWorktreeId=$Worktree", "-p:ATAPArtifactsExecutionId=$Execution", "-p:ArtifactsPath=$Artifacts")) {
      $arguments.Add($value)
    }
    foreach ($entry in $Properties.GetEnumerator()) { $arguments.Add("-p:$($entry.Key)=$($entry.Value)") }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'dotnet'
    $start.WorkingDirectory = $script:repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Could not start dotnet msbuild.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    [pscustomobject]@{
      ExitCode = $process.ExitCode
      Text = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
      ArtifactsPath = $Artifacts
    }
  }
}

AfterAll {
  if (Test-Path -LiteralPath $script:fixtureRoot) { Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force }
  if (Test-Path -LiteralPath $script:externalRoot) { Remove-Item -LiteralPath $script:externalRoot -Recurse -Force }
}

Describe 'Task 15.180.j common-build root contract' -Tag 'RepoHealth', 'CommonBuild' {
  It 'accepts one canonical external artifacts path and writes its owner marker' {
    $result = Invoke-CommonBuildTarget
    $result.ExitCode | Should -Be 0 -Because $result.Text
    Get-Content -LiteralPath (Join-Path $result.ArtifactsPath '.atap-artifacts-owner') -Raw |
      Should -BeExactly 'ATAP.Utilities|wt-a|exec-a'
  }

  It 'fails missing root with ATAPBUILD003' {
    $result = Invoke-CommonBuildTarget -Root '' -Artifacts ''
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD003'
  }

  It 'fails relative and Dropbox-contained paths with ATAPBUILD004' -ForEach @(
    @{ Root = 'relative-root'; Artifacts = 'relative-root\dotnet\ATAP.Utilities\wt-a\exec-a' }
    @{ Root = 'C:\Dropbox\Task15.180j'; Artifacts = 'C:\Dropbox\Task15.180j\dotnet\ATAP.Utilities\wt-a\exec-a' }
  ) {
    $result = Invoke-CommonBuildTarget -Root $Root -Artifacts $Artifacts
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD004'
  }

  It 'fails an owner-marker conflict with ATAPBUILD005' {
    $path = Join-Path $script:externalRoot 'dotnet\ATAP.Utilities\wt-conflict\exec-conflict'
    [IO.Directory]::CreateDirectory($path) | Out-Null
    [IO.File]::WriteAllText((Join-Path $path '.atap-artifacts-owner'), 'other|owner|claim')
    $result = Invoke-CommonBuildTarget -Worktree 'wt-conflict' -Execution 'exec-conflict' -Artifacts $path
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD005'
  }

  It 'fails Build-coupled packaging with ATAPBUILD007' {
    $result = Invoke-CommonBuildTarget -Execution 'coupled' -Properties @{ GeneratePackageOnBuild = 'true' }
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD007'
  }

  It 'fails a non-forced load-bearing lock validation with ATAPBUILD008' {
    $result = Invoke-CommonBuildTarget -Execution 'lock-invalid' -Properties @{ ATAPLoadBearingLockValidation = 'true' }
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD008'
  }

  It 'accepts forced locked validation flags' {
    $result = Invoke-CommonBuildTarget -Execution 'lock-valid' -Properties @{ ATAPLoadBearingLockValidation = 'true'; RestoreForceEvaluate = 'true'; RestoreLockedMode = 'true' }
    $result.ExitCode | Should -Be 0 -Because $result.Text
  }

  It 'fails an unauthorized CPM override with ATAPBUILD009' {
    $result = Invoke-CommonBuildTarget -Execution 'override' -Properties @{ CentralPackageVersionOverrideEnabled = 'true' }
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD009'
  }

  It 'fails a required missing BuildTooling package with ATAPBUILD019' {
    $result = Invoke-CommonBuildTarget -Execution 'missing-buildtooling' -Properties @{ ATAPRequireBuildToolingPackage = 'true' }
    $result.ExitCode | Should -Not -Be 0
    $result.Text | Should -Match 'ATAPBUILD019'
  }
}

Describe 'Task 15.180.j deterministic and publication boundaries' -Tag 'RepoHealth', 'CommonBuild' {
  BeforeAll {
    [xml] $script:props = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Directory.Build.props') -Raw
    [xml] $script:targets = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Directory.Build.targets') -Raw
  }

  It 'sets deterministic build and disables package-on-build centrally' {
    ([string] $script:props.Project.PropertyGroup.Deterministic).Trim() | Should -BeExactly 'true'
    ([string] $script:targets.Project.PropertyGroup.GeneratePackageOnBuild).Trim() | Should -BeExactly 'false'
  }

  It 'contains no credential, push, or feed-mutation command in the common target' {
    $node = $script:targets.SelectSingleNode("//*[local-name()='Target' and @Name='ValidateATAPCommonBuildContract']")
    $node.OuterXml | Should -Not -Match 'Get-SecretATAP|NuGetApiKey|ProGetApiKey|dotnet nuget push|Move-ProGet|PublishRepository'
  }
}
