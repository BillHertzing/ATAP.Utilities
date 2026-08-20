#Requires -Module Pester
BeforeAll {
  $script:moduleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  . (Join-Path $script:moduleRoot 'public\Invoke-MSBuildWithLists.ps1')
  . (Join-Path $script:moduleRoot 'public\Invoke-DotnetBuildWithRetry.ps1')
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments=$true)]$Rest) }
  }
  $script:artifactsRoot = Join-Path ([IO.Path]::GetTempPath()) ('ATAP-Task15.180l-L1-' + [guid]::NewGuid().ToString('N'))
  $script:artifactsPath = Join-Path $script:artifactsRoot 'dotnet\ATAP.Utilities\wt-l1\exec-l1'
  $script:context = [pscustomobject]@{
    Root = $script:artifactsRoot
    WorktreeId = 'wt-l1'
    ExecutionId = 'exec-l1'
    ArtifactsPath = $script:artifactsPath
    BinlogPath = Join-Path $script:artifactsPath 'logs\l1.binlog'
    PackageStagingPath = Join-Path $script:artifactsPath 'packages'
    PublishStagingPath = Join-Path $script:artifactsPath 'publish'
  }
}
AfterAll {
  if (Test-Path -LiteralPath $script:artifactsRoot) { Remove-Item -LiteralPath $script:artifactsRoot -Recurse -Force }
}
Describe 'Task 15.180.l L1 artifacts propagation' -Tag Unit,ArtifactsPath {
  It 'replaces independent output overrides with one artifacts path for every list build' {
    $result = Invoke-MSBuildWithLists -Path $TestDrive -ArtifactsContext $script:context -RuntimeTargetList win-x64 -ConfigurationList Release -TargetFrameworkList net10.0 -WhatIf
    $joined = $result.Arguments -join ' '
    $joined | Should -Match '--artifacts-path'
    $joined | Should -Match ([regex]::Escape($script:artifactsPath))
    $joined | Should -Match 'ATAPArtifactsWorktreeId=wt-l1'
    $joined | Should -Not -Match '(?i)BaseIntermediateOutputPath|(?<!Artifacts)OutputPath'
    $result.ArtifactsPath | Should -BeExactly $script:artifactsPath
  }

  It 'fails a producing list build without an artifacts context' {
    { Invoke-MSBuildWithLists -Path $TestDrive -RuntimeTargetList win-x64 -ConfigurationList Release -TargetFrameworkList net10.0 -Confirm:$false } | Should -Throw '*ArtifactsContext*required*'
  }

  It 'carries the same path through restore and dependent no-restore build' {
    $result = Invoke-DotnetBuildWithRetry -SolutionOrProjectPath $TestDrive -ArtifactsContext $script:context -Configuration Release -WhatIf
    ($result.RestoreArguments -join ' ') | Should -Match '--artifacts-path'
    ($result.BuildArguments -join ' ') | Should -Match '--no-restore'
    ($result.RestoreArguments | Where-Object { $_ -ceq $script:artifactsPath }).Count | Should -Be 1
    ($result.BuildArguments | Where-Object { $_ -ceq $script:artifactsPath }).Count | Should -Be 1
    $result.OwnerMarkerPath | Should -BeExactly (Join-Path $script:artifactsPath '.atap-artifacts-owner')
  }

  It 'contains only marker-bounded external recovery and no cross-shell delete fallback' {
    $text = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'public\Invoke-DotnetBuildWithRetry.ps1') -Raw
    $text | Should -Match 'Remove-MarkerOwnedWebcilDirectories'
    $text | Should -Match '\.atap-artifacts-owner'
    $text | Should -Match 'StartsWith\(\$artifactsPath'
    $text | Should -Not -Match 'cmd\.exe|BaseIntermediateOutputPath|Remove-Item -Recurse -Force ''\$relObj'''
    $text | Should -Not -Match 'Find-ZeroByteRefAssemblies -RootPath \$projectDir'
  }

  It 'rejects an owner-marker conflict before any dotnet invocation' {
    [IO.Directory]::CreateDirectory($script:artifactsPath) | Out-Null
    [IO.File]::WriteAllText((Join-Path $script:artifactsPath '.atap-artifacts-owner'), 'other|owner|run')
    try {
      { Invoke-DotnetBuildWithRetry -SolutionOrProjectPath $TestDrive -ArtifactsContext $script:context -Configuration Release -WhatIf } | Should -Throw '*owned by*'
    } finally {
      [IO.File]::WriteAllText((Join-Path $script:artifactsPath '.atap-artifacts-owner'), 'ATAP.Utilities|wt-l1|exec-l1')
    }
  }
}