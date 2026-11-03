#Requires -Version 7.0
# Pester 6.2+ tests that enforce the module's structural rules:
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

Describe 'Orchestration export and import boundaries in a disposable source fixture' {
  BeforeAll {
    $script:fixture943Root = Join-Path (Split-Path -Parent (Split-Path -Parent $script:moduleRoot)) '_generated/Sprint0017/Task17.19.a/RegistrationTests943'
    $script:fixture943 = Join-Path $script:fixture943Root ([guid]::NewGuid().ToString('N'))
    $script:fixture943SavedVariable = Get-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
    $script:fixture943SavedValue = if ($null -ne $script:fixture943SavedVariable) { $script:fixture943SavedVariable.Value } else { $null }
    $script:fixture943Module = $null
    # Metadata-only lifetime diagnostics; logging must never change fixture failure behavior.
    $script:fixture973Log = {
      param([string]$Boundary, [AllowNull()][System.Management.Automation.ErrorRecord]$CleanupError = $null)
      try {
        $globalFunction = Get-Item -LiteralPath 'Function:\Set-GlobalConfigRootKeys' -ErrorAction SilentlyContinue
        $orchestrationFunction = Get-Item -LiteralPath 'Function:\Set-OrchestrationConfigRootKeys' -ErrorAction SilentlyContinue
        $cleanupException = if ($null -ne $CleanupError) { $CleanupError.Exception.GetBaseException() } else { $null }
        $metadata = [ordered]@{
          Boundary = $Boundary
          PID = $PID
          PowerShellPWD = $PWD.Path
          EnvironmentCurrentDirectory = [Environment]::CurrentDirectory
          FixtureModuleManifestPath = Join-Path $script:fixture943 'ATAP.Utilities.ConfigRootKeys.PowerShell.psd1'
          LoadedModulePath = if ($null -ne $script:fixture943Module) { $script:fixture943Module.Path } else { $null }
          SetGlobalScriptBlockFile = if ($null -ne $globalFunction) { $globalFunction.ScriptBlock.File } else { $null }
          SetOrchestrationScriptBlockFile = if ($null -ne $orchestrationFunction) { $orchestrationFunction.ScriptBlock.File } else { $null }
          ExceptionType = if ($null -ne $cleanupException) { $cleanupException.GetType().FullName } else { $null }
          HResult = if ($null -ne $cleanupException) { $cleanupException.HResult } else { $null }
        }
        $level = if ($null -ne $cleanupException) { 'Error' } else { 'Important' }
        Write-PSFMessage -FunctionName 'ConfigRootKeysModule.Tests' -ModuleName 'ATAP.Utilities.ConfigRootKeys.PowerShell' -Level $level -Message ($metadata | ConvertTo-Json -Depth 4 -Compress)
      } catch {}
    }
    $null = New-Item -ItemType Directory -Path (Join-Path $script:fixture943 'public') -Force
    foreach ($name in @('ATAP.Utilities.ConfigRootKeys.PowerShell.psm1', 'ATAP.Utilities.ConfigRootKeys.PowerShell.psd1')) {
      Copy-Item -LiteralPath (Join-Path $script:moduleRoot $name) -Destination $script:fixture943
    }
    Get-ChildItem -LiteralPath $script:publicDir -Filter '*.ps1' -File | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:fixture943 'public')
    }
  }

  AfterAll {
    try {
      try { & $script:fixture973Log -Boundary 'BeforeRemoveModule' } catch {}
      if ($null -ne $script:fixture943Module) { Remove-Module -ModuleInfo $script:fixture943Module -Force }
      try { & $script:fixture973Log -Boundary 'AfterRemoveModule' } catch {}
      if ($null -ne $script:fixture943SavedVariable) { $global:configRootKeys = $script:fixture943SavedValue }
      else { Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue }
      try { & $script:fixture973Log -Boundary 'BeforeCleanup' } catch {}
      $fixturePath = [IO.Path]::GetFullPath($script:fixture943)
      $allowedPrefix = [IO.Path]::GetFullPath($script:fixture943Root).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
      if (-not $fixturePath.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path' }
      if (Test-Path -LiteralPath $fixturePath) { Remove-Item -LiteralPath $fixturePath -Recurse -Force }
      try { & $script:fixture973Log -Boundary 'AfterCleanup' } catch {}
    } catch {
      $cleanupError973 = $_
      try { & $script:fixture973Log -Boundary 'CleanupFailure' -CleanupError $cleanupError973 } catch {}
      throw
    }
  }

  It 'exports the new function but importing only defines functions and leaves globals untouched' {
    $sentinel = @{ Unrelated943 = 'unchanged' }
    $global:configRootKeys = $sentinel

    try { & $script:fixture973Log -Boundary 'BeforeImport' } catch {}
    $script:fixture943Module = Import-Module -Name (Join-Path $script:fixture943 'ATAP.Utilities.ConfigRootKeys.PowerShell.psd1') -Scope Local -Force -PassThru
    try { & $script:fixture973Log -Boundary 'AfterImport' } catch {}

    $script:fixture943Module.ExportedFunctions.Keys | Should -Contain 'Set-OrchestrationConfigRootKeys'
    [object]::ReferenceEquals($global:configRootKeys, $sentinel) | Should -BeTrue
    $global:configRootKeys.Count | Should -Be 1
  }

  It 'refuses an absent Orchestration source when no section definition is available' {
    $leaf = Join-Path $script:fixture943 'public/Set-OrchestrationConfigRootKeys.ps1'
    Remove-Item -LiteralPath $leaf
    . (Join-Path $script:fixture943 'public/Set-GlobalConfigRootKeys.ps1')
    Mock Get-Command {
      param($Name, $CommandType, $ErrorAction)
      if ($Name -eq 'Set-OrchestrationConfigRootKeys') { return $null }
      Microsoft.PowerShell.Core\Get-Command -Name $Name -CommandType $CommandType -ErrorAction $ErrorAction
    }

    { Set-GlobalConfigRootKeys -Path (Join-Path $script:fixture943 'public') -Confirm:$false } |
      Should -Throw -ExpectedMessage '*Set-OrchestrationConfigRootKeys*source file was not found*'
  }
}
