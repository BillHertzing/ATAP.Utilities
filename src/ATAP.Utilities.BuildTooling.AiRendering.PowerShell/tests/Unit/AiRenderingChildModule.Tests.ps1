Describe 'AiRendering child module contract' -Tag 'Unit' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell.psd1'
  }

  It 'contains only function definitions in implementation files' {
    $errors = @()
    foreach ($file in Get-ChildItem -LiteralPath $script:moduleRoot -Recurse -File -Filter '*.ps1') {
      if ($file.FullName -match '\\tests\\') {
        continue
      }
      $tokens = $null
      $parseErrors = $null
      $ast = [Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref] $tokens,
        [ref] $parseErrors
      )
      $errors += $parseErrors
      @($ast.EndBlock.Statements |
        Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count |
        Should -Be 0 -Because "$($file.Name) must not execute at module load"
    }
    $errors | Should -BeNullOrEmpty
  }

  It 'exports the frozen child surface' {
    $expected = @(
      'Build-AgentSpecificPerRepository'
      'Build-AGENTSPerRepository'
      'Build-AIInstructionsPerRepository'
      'Build-CLAUDEPerRepository'
      'Convert-DiagramsToImages'
      'Get-NumberOfFailingTestsFromTRX'
      'Invoke-FailureAcknowledgedGate'
      'Reset-DownstreamToSharedVSCodeMain'
      'Set-ClaudeSettingsSymlink'
      'Test-FailureAcknowledgedGate'
      'Test-PairedAgentTextSuite'
    )

    $manifest = Test-ModuleManifest -Path $script:manifestPath

    @($manifest.ExportedFunctions.Keys | Sort-Object) | Should -Be @($expected | Sort-Object)
  }

  It 'owns the FailureAcknowledged schema required by its gate command' {
    Test-Path -LiteralPath (
      Join-Path $script:moduleRoot 'Resources\FailureAcknowledged.schema.json'
    ) | Should -BeTrue
  }

  It 'has stable-release NBGV metadata' {
    $metadata = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'version.json') -Raw |
      ConvertFrom-Json
    $metadata.version | Should -Be '0.1.2'
    @($metadata.publicReleaseRefSpec) | Should -Contain '.*'
  }
}
