BeforeAll {
  Import-Module PSFramework -ErrorAction Stop
  $script:moduleRoot = (Resolve-Path "$PSScriptRoot/../..").Path
  . "$script:moduleRoot/private/Get-AICoreInstructionBody.ps1"
  . "$script:moduleRoot/public/Build-CLAUDEPerRepository.ps1"
  . "$script:moduleRoot/public/Build-AGENTSPerRepository.ps1"
  . "$script:moduleRoot/public/Build-AgentSpecificPerRepository.ps1"
  . "$script:moduleRoot/public/Build-AIInstructionsPerRepository.ps1"

  # Use the real renderer API; never substitute a mocked body generator. Release
  # verification can supply an exact canonical checkout. Standalone runs use the
  # stable sibling checkout, never a timestamp-based worktree selection.
  $script:sharedSource = $env:ATAP_AI_CONTRACT_SHARED_ROOT
  if (-not $script:sharedSource) {
    $script:sharedSource = [IO.Path]::GetFullPath((Join-Path $script:moduleRoot '../../../SharedVSCode'))
  }
  $script:evidenceRoot = Join-Path $script:moduleRoot '../../_generated/Sprint0016/StartupRecovery/InstructionDistributor/Fixtures'
  New-Item -ItemType Directory -Path $script:evidenceRoot -Force | Out-Null
}

Describe 'Instruction distributor current canonical contract' {
  BeforeEach {
    $script:fixtureRoot = Join-Path $script:evidenceRoot ([guid]::NewGuid().ToString('N'))
    $script:shared = Join-Path $script:fixtureRoot 'SharedVSCode-wt-68-Sprint-0016-work-items'
    $script:repo = Join-Path $script:fixtureRoot 'Example-wt-1-Sprint-0016-work-items'
    foreach ($directory in @('.ai/tools', '.ai/manifests', '.ai/core', '.github')) {
      New-Item -ItemType Directory -Path (Join-Path $script:shared $directory) -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $script:repo -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:sharedSource '.ai/tools/Render-AIAdapters.ps1') -Destination (Join-Path $script:shared '.ai/tools/Render-AIAdapters.ps1')
    Set-Content (Join-Path $script:shared '.ai/core/main-instructions.md') -Value "# Canonical core`nPreserved Unicode: café.`n" -NoNewline -Encoding utf8
    Set-Content (Join-Path $script:shared 'GEMINI.md') -Value 'Core instructions live in AGENTS.md. Gemini delta.' -Encoding utf8
    Set-Content (Join-Path $script:shared '.github/copilot-instructions.md') -Value 'Core instructions live in AGENTS.md. Copilot delta.' -Encoding utf8
    Set-Content (Join-Path $script:repo 'ai-local.md') -Value '# Local overlay' -Encoding utf8
    $script:manifest = [pscustomobject]@{
      records = @([pscustomobject]@{
        id = 'ai.core.main-instructions.v1'
        source = [pscustomobject]@{ path = '.ai/core/main-instructions.md' }
        targets = @(
          [pscustomobject]@{ tool = 'ClaudeCode'; path = 'CLAUDE.md'; materialization = 'composer-owner'; composedMaterialization = 'copy' }
          [pscustomobject]@{ tool = 'Codex'; path = 'AGENTS.md'; materialization = 'composer-owner'; composedMaterialization = 'generated-wrapper' }
        )
      })
    }
    $script:manifestPath = Join-Path $script:shared '.ai/manifests/instruction-map.json'
    $script:manifest | ConvertTo-Json -Depth 10 | Set-Content $script:manifestPath -Encoding utf8
    $script:workspace = Join-Path $script:fixtureRoot 'Overview.Sprint.0016.code-workspace'
    @{ folders = @(@{path=$script:shared}, @{path=$script:repo}); sprintEphemeral = @{sprintNumber='0016'} } |
      ConvertTo-Json -Depth 10 | Set-Content $script:workspace -Encoding utf8
  }

  It 'distributes all four surfaces without any retired base files or targets and repeats unchanged' {
    $first = Build-AIInstructionsPerRepository -WorktreeRoot $script:repo -WorkspacePath $script:workspace -Confirm:$false
    $first.Success | Should -BeTrue
    $first.Errors | Should -BeNullOrEmpty
    $first.Builders.Claude.CoreOrigin | Should -Be 'canonical'
    $first.Builders.Agents.CoreOrigin | Should -Be 'canonical'
    $first.RepositoryResults.Success | Should -Not -Contain $false
    $paths = @('CLAUDE.md', 'AGENTS.md', 'GEMINI.md', '.github/copilot-instructions.md')
    $before = @{}
    foreach ($relative in $paths) {
      $path = Join-Path $script:repo $relative
      $before[$relative] = @{ Hash=(Get-FileHash $path).Hash; Time=(Get-Item $path).LastWriteTimeUtc }
    }
    $agents = Get-Content (Join-Path $script:repo 'AGENTS.md') -Raw
    $agents | Should -Match 'SourceId: ai.core.main-instructions.v1'
    $agents | Should -Match 'Preserved Unicode: café.'
    $agents | Should -Match '# Local overlay'
    $claude = Get-Content (Join-Path $script:repo 'CLAUDE.md') -Raw
    $claude | Should -Match 'Canonical core'
    $claude | Should -Not -Match 'SourceId: ai.core.main-instructions.v1'
    $second = Build-AIInstructionsPerRepository -WorktreeRoot $script:repo -WorkspacePath $script:workspace -Confirm:$false
    $second.Success | Should -BeTrue
    foreach ($relative in $paths) {
      $path = Join-Path $script:repo $relative
      (Get-FileHash $path).Hash | Should -Be $before[$relative].Hash
      (Get-Item $path).LastWriteTimeUtc | Should -Be $before[$relative].Time
    }
    @(Get-ChildItem $script:fixtureRoot -Recurse -Filter '*-base.md') | Should -BeNullOrEmpty
  }

  It 'surfaces missing and ambiguous carrier targets: <Variant>' -ForEach @(
    @{Variant='missing'; ExpectedCount=0}, @{Variant='ambiguous'; ExpectedCount=2}
  ) {
    if ($Variant -eq 'missing') { $script:manifest.records[0].targets = @($script:manifest.records[0].targets | Where-Object path -ne 'AGENTS.md') }
    else { $script:manifest.records[0].targets += $script:manifest.records[0].targets[1] }
    $script:manifest | ConvertTo-Json -Depth 10 | Set-Content $script:manifestPath -Encoding utf8
    $result = Build-AIInstructionsPerRepository -WorktreeRoot $script:repo -WorkspacePath $script:workspace -Confirm:$false
    $result.Success | Should -BeFalse
    $result.Errors -join ' ' | Should -BeLike "*Expected exactly one 'AGENTS.md' target*found $ExpectedCount*"
  }

  It 'rejects missing or unsupported composition shape: <Shape>' -ForEach @(
    @{Shape=''; Expected="*declares no 'composedMaterialization'*"}
    @{Shape='composer-owner'; Expected='*unsupported composedMaterialization*'}
  ) {
    $script:manifest.records[0].targets[1].composedMaterialization = $Shape
    $script:manifest | ConvertTo-Json -Depth 10 | Set-Content $script:manifestPath -Encoding utf8
    { Get-AICoreInstructionBody -SharedVSCodeRoot $script:shared -Carrier AGENTS } | Should -Throw -ExpectedMessage $Expected
  }

  It 'rejects a target that the renderer owns instead of the composer' {
    $script:manifest.records[0].targets[1].materialization = 'copy'
    $script:manifest | ConvertTo-Json -Depth 10 | Set-Content $script:manifestPath -Encoding utf8
    { Get-AICoreInstructionBody -SharedVSCodeRoot $script:shared -Carrier AGENTS } | Should -Throw -ExpectedMessage "*must declare materialization 'composer-owner'*"
  }

  It 'reports a missing canonical source without silently using a stale base' {
    Remove-Item -LiteralPath (Join-Path $script:shared '.ai/core/main-instructions.md')
    { Get-AICoreInstructionBody -SharedVSCodeRoot $script:shared -Carrier AGENTS } | Should -Throw -ExpectedMessage '*Canonical core instructions*not found*'
  }

  It 'surfaces missing and ambiguous core records: <Variant>' -ForEach @(
    @{Variant='missing'; ExpectedCount=0}, @{Variant='ambiguous'; ExpectedCount=2}
  ) {
    if ($Variant -eq 'missing') { $script:manifest.records = @() }
    else { $script:manifest.records += $script:manifest.records[0] }
    $script:manifest | ConvertTo-Json -Depth 10 | Set-Content $script:manifestPath -Encoding utf8
    { Get-AICoreInstructionBody -SharedVSCodeRoot $script:shared -Carrier CLAUDE } |
      Should -Throw -ExpectedMessage "*Expected exactly one 'ai.core.main-instructions.v1' record*found $ExpectedCount*"
  }
}
