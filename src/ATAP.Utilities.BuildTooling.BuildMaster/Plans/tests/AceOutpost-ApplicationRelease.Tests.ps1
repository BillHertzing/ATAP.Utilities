# Pester 5+ static-contract tests for Task 16.79: AceOutpost-ApplicationRelease.otter and its
# five-stage pipeline must be a thin adapter over Invoke-ApplicationReleaseStage.ps1 whose
# argument list satisfies every mandatory runner parameter (the raft silent-hang guard).

BeforeAll {
  $script:PlansDir     = Join-Path $PSScriptRoot '..'
  $script:PlanPath     = Join-Path $script:PlansDir 'AceOutpost-ApplicationRelease.otter'
  $script:PipelinePath = Join-Path $script:PlansDir 'AceOutpost-ApplicationRelease-5Stage.pipeline.json'
  $script:RunnerPath   = Join-Path $script:PlansDir 'Invoke-ApplicationReleaseStage.ps1'
  $script:PlanText     = Get-Content -LiteralPath $script:PlanPath -Raw
  # Comment prose is excluded from behavioral assertions; only executable OtterScript counts.
  $script:PlanCode     = (@($script:PlanText -split "\r?\n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
  $script:Arguments    = [regex]::Match($script:PlanCode, '(?s)Arguments:\s*>>(?<args>.*?)>>').Groups['args'].Value
}

Describe 'AceOutpost-ApplicationRelease.otter is a thin release adapter' {
  It 'plan, pipeline and runner exist' {
    Test-Path -LiteralPath $script:PlanPath | Should -BeTrue
    Test-Path -LiteralPath $script:PipelinePath | Should -BeTrue
    Test-Path -LiteralPath $script:RunnerPath | Should -BeTrue
  }

  It 'contains exactly one Exec block invoking pwsh -NonInteractive -File with the release runner, keeping profiles' {
    ([regex]::Matches($script:PlanCode, 'InedoCore::Exec')).Count | Should -Be 1
    $script:PlanCode | Should -Match 'FileName:\s*pwsh'
    $script:Arguments | Should -Match '^-NonInteractive -File "\$ApplicationReleaseRunner"'
    $script:PlanCode | Should -Not -Match '-NoProfile'
  }

  It 'passes every mandatory runner parameter (the silent-hang guard)' {
    $ast = [Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$null, [ref]$null)
    $function = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-ApplicationReleaseStage' }, $true)
    $mandatory = @($function.Body.ParamBlock.Parameters | Where-Object {
        $_.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' -and ($_.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' }) }
      } | ForEach-Object { $_.Name.VariablePath.UserPath })
    $mandatory.Count | Should -BeGreaterThan 0
    $passed = @([regex]::Matches($script:Arguments, '(?<=\s|^)-(?<name>[A-Za-z][A-Za-z0-9]*)\s+"') | ForEach-Object { $_.Groups['name'].Value })
    foreach ($name in $mandatory) { $passed | Should -Contain $name }
    foreach ($name in $passed | Where-Object { $_ -notin @('File') }) {
      @($function.Body.ParamBlock.Parameters.Name.VariablePath.UserPath) | Should -Contain $name
    }
  }

  It 'binds the stage to the pipeline stage name and the BuildMaster build id' {
    $script:Arguments | Should -Match '-Stage "\$PipelineStageName"'
    $script:PlanCode | Should -Match 'set \$ReleaseBuildId = \$BuildMasterId\(build\);'
    $script:Arguments | Should -Match '-BuildId "\$ReleaseBuildId"'
  }

  It 'contains no secret, build, database, install or distribution step' {
    $script:PlanCode | Should -Not -Match '\$Decrypt\(|X-ApiKey|-Command\b'
    $script:PlanCode | Should -Not -Match '(?i)Flyway|Chocolatey|WinGet|Install-|dotnet|Invoke-ApplicationBuildMasterStage|Distribution'
  }
}

Describe 'AceOutpost-ApplicationRelease-5Stage pipeline' {
  BeforeAll { $script:Pipeline = Get-Content -LiteralPath $script:PipelinePath -Raw | ConvertFrom-Json }

  It 'is named for its raft item and ends at Production with no Distribution stage' {
    $script:Pipeline.Name | Should -BeExactly 'AceOutpost-ApplicationRelease-5Stage'
    ($script:Pipeline.Stages.Name -join ',') | Should -BeExactly 'Experimental,Development,Integration,QA,Production'
  }

  It 'stage names are exactly the runner ValidateSet, in ladder order' {
    $ast = [Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$null, [ref]$null)
    $function = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-ApplicationReleaseStage' }, $true)
    $stageParameter = $function.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Stage' }
    $validateSet = $stageParameter.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }
    (@($validateSet.PositionalArguments.Value) -join ',') | Should -BeExactly ($script:Pipeline.Stages.Name -join ',')
  }

  It 'wires every stage to the global AceOutpost plan on localhost with no automatic approvals or listeners' {
    foreach ($stage in $script:Pipeline.Stages) {
      @($stage.Targets).Count | Should -Be 1
      $stage.Targets[0].ScriptId | Should -BeExactly 'global::AceOutpost-ApplicationRelease.otter'
      ($stage.Targets[0].ServerNames -join ',') | Should -BeExactly 'localhost'
      @($stage.Gate.AutomaticApprovals).Count | Should -Be 0
      $stage.AllowMultipleActiveBuilds | Should -BeFalse
    }
    @($script:Pipeline.EventListeners).Count | Should -Be 0
  }

  It 'does not reference the AceCommander plan' {
    (Get-Content -LiteralPath $script:PipelinePath -Raw) | Should -Not -Match 'AceCommander'
  }
}
