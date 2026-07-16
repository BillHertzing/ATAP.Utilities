#Requires -Version 7.0

Describe 'Task 12.49.e moved profile functions' {
  BeforeAll {
    $script:publicPath = Join-Path $PSScriptRoot '..\public'
    $script:expectedNames = @(
      'TailLatestPSFrameworkLog',
      'FindFilesByES',
      'Get-Attributions',
      'Get-LinksFromDrafts',
      'Get-AllBookmarks',
      'Get-LinksFiltered',
      'Open-FilteredLinksInBrave',
      'Open-BookmarksInBrave',
      'WatchFile',
      'TailLog'
    )
  }

  It 'contains all ten user-selected files without disturbing pre-existing pending functions' {
    $actualNames = @(Get-ChildItem -LiteralPath $script:publicPath -File -Filter '*.ps1' | Select-Object -ExpandProperty BaseName | Sort-Object)
    @($script:expectedNames | Where-Object { $_ -notin $actualNames }) | Should -BeNullOrEmpty
  }

  It 'gives <FunctionName> one parseable eponymous advanced function with standard blocks and help' -ForEach @(
    @{ FunctionName = 'TailLatestPSFrameworkLog' }
    @{ FunctionName = 'FindFilesByES' }
    @{ FunctionName = 'Get-Attributions' }
    @{ FunctionName = 'Get-LinksFromDrafts' }
    @{ FunctionName = 'Get-AllBookmarks' }
    @{ FunctionName = 'Get-LinksFiltered' }
    @{ FunctionName = 'Open-FilteredLinksInBrave' }
    @{ FunctionName = 'Open-BookmarksInBrave' }
    @{ FunctionName = 'WatchFile' }
    @{ FunctionName = 'TailLog' }
  ) {
    $path = Join-Path $script:publicPath "$FunctionName.ps1"
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    $errors | Should -BeNullOrEmpty
    $functions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))
    $functions.Count | Should -Be 1
    $functions[0].Name | Should -Be $FunctionName
    $functions[0].Body.BeginBlock | Should -Not -BeNullOrEmpty
    $functions[0].Body.ProcessBlock | Should -Not -BeNullOrEmpty
    $functions[0].Body.EndBlock | Should -Not -BeNullOrEmpty
    $content = Get-Content -LiteralPath $path -Raw
    $content | Should -Match '\[CmdletBinding\(SupportsShouldProcess = \$true'
    foreach ($section in @('.SYNOPSIS', '.DESCRIPTION', '.OUTPUTS', '.EXAMPLE', '.NOTES', '.LINK')) {
      $content | Should -Match ([regex]::Escape($section))
    }
    if ($functions[0].Body.ParamBlock.Parameters.Count -gt 0) {
      $content | Should -Match ([regex]::Escape('.PARAMETER'))
    }
  }
}
