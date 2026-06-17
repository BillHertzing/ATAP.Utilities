#Requires -Version 7.0
# Pester 5+ tests that enforce the module's structural rules:
#   - every public/*.ps1 contains ONLY an eponymous function definition (no top-level code)
#   - the manifest exports exactly those functions, all Verb-Noun, no dotted names
#   - the manifest declares no binary cmdlets

# Computed at DISCOVERY time so the -ForEach data tables below are populated when
# Pester enumerates the test cases (BeforeAll runs too late for -ForEach).
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:publicDir = Join-Path $script:moduleRoot 'public'
$script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.ConfigRootKeys.PowerShell.psd1'
$script:publicFileCases = @(
  Get-ChildItem -LiteralPath $script:publicDir -Filter '*.ps1' -File |
    ForEach-Object { @{ Name = $_.Name; BaseName = $_.BaseName; FullName = $_.FullName } }
)

BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'
  $script:manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.ConfigRootKeys.PowerShell.psd1'
  $script:manifest = Import-PowerShellDataFile -LiteralPath $script:manifestPath
  $script:publicFiles = @(Get-ChildItem -LiteralPath $script:publicDir -Filter '*.ps1' -File)
}

Describe 'Public section files are eponymous functions with no top-level code' -Tag 'Unit' {
  It 'parses <Name> without errors' -ForEach $script:publicFileCases {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$errors)
    @($errors).Count | Should -Be 0
  }

  It '<Name> contains exactly one top-level statement and it is a function definition' -ForEach $script:publicFileCases {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$errors)
    $topLevel = @($ast.EndBlock.Statements)
    $topLevel.Count | Should -Be 1
    $topLevel[0] | Should -BeOfType ([System.Management.Automation.Language.FunctionDefinitionAst])
  }

  It '<Name> defines a function eponymous with the file and shaped as a cmdlet (begin/process/end)' -ForEach $script:publicFileCases {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$errors)
    $funcAst = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))[0]
    $funcAst.Name | Should -BeExactly $BaseName
    $funcAst.Body.BeginBlock | Should -Not -BeNullOrEmpty
    $funcAst.Body.ProcessBlock | Should -Not -BeNullOrEmpty
    $funcAst.Body.EndBlock | Should -Not -BeNullOrEmpty
  }
}

Describe 'Module manifest export surface' -Tag 'Unit' {
  It 'exports exactly the set of public function files' {
    $exported = @($script:manifest.FunctionsToExport) | Sort-Object
    $expected = @($script:publicFiles | ForEach-Object { $_.BaseName }) | Sort-Object
    $exported | Should -Be $expected
  }

  It 'exports no dotted (non-Verb-Noun) function names' {
    foreach ($name in $script:manifest.FunctionsToExport) {
      $name | Should -Not -Match '\.'
      $name | Should -Match '^[A-Z][a-z]+-[A-Za-z0-9]+$'
    }
  }

  It 'declares no binary cmdlets to export' {
    @($script:manifest.CmdletsToExport).Count | Should -Be 0
  }

  It 'no longer references the legacy dotted fragment names' {
    $manifestText = Get-Content -LiteralPath $script:manifestPath -Raw
    $manifestText | Should -Not -Match 'BuildMaster\.ConfigRootKeys'
    $manifestText | Should -Not -Match 'Databases\.ATAPUtilities\.ConfigRootKeys'
    $manifestText | Should -Not -Match 'RulesManagement\.ConfigRootKeys'
  }
}
