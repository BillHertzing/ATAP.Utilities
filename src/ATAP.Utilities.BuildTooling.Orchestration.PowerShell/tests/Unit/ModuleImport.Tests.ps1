BeforeAll {
  $entry = (Resolve-Path (Join-Path $PSScriptRoot '../../ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psm1')).Path
}

Describe 'Orchestration module import boundary' -Tag 'Unit' {
  BeforeEach {
    $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixture | Out-Null
    Copy-Item -LiteralPath $entry -Destination (Join-Path $fixture 'Fixture.psm1')
    $modulePath = Join-Path $fixture 'Fixture.psm1'
  }
  AfterEach {
    Get-Module | Where-Object { $_.Path -eq $modulePath } | Remove-Module -Force
  }

  It 'imports with missing directories and exports no operations' {
    $module = Import-Module -Name $modulePath -PassThru -Force -ErrorAction Stop
    @($module.ExportedCommands.Keys).Count | Should -Be 0
    @(Get-ChildItem -LiteralPath $fixture -Force).Count | Should -Be 1
  }

  It 'loads definitions from empty and populated folders without calling them or exporting them' {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'public'), (Join-Path $fixture 'private') | Out-Null
    $sentinel = Join-Path $fixture 'invoked.txt'
    Set-Content -LiteralPath (Join-Path $fixture 'public/Example.ps1') -Value "function Invoke-Example { Set-Content -LiteralPath '$sentinel' -Value 'called' }"
    $module = Import-Module -Name $modulePath -PassThru -Force -ErrorAction Stop
    @($module.ExportedCommands.Keys).Count | Should -Be 0
    Test-Path -LiteralPath $sentinel | Should -BeFalse
    & $module { [bool](Get-Command Invoke-Example -ErrorAction SilentlyContinue) } | Should -BeTrue
  }

  It 'rejects executable top-level code before any helper runs' {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'public') | Out-Null
    $sentinel = Join-Path $fixture 'executed.txt'
    Set-Content -LiteralPath (Join-Path $fixture 'public/Bad.ps1') -Value "Set-Content -LiteralPath '$sentinel' -Value 'executed'"
    { Import-Module -Name $modulePath -Force -ErrorAction Stop } | Should -Throw
    Test-Path -LiteralPath $sentinel | Should -BeFalse
  }

  It 'rejects malformed helper syntax' {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'private') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture 'private/Bad.ps1') -Value 'function Broken {'
    { Import-Module -Name $modulePath -Force -ErrorAction Stop } | Should -Throw
  }
  It 'rejects a top-level clean block without executing it' {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'public') | Out-Null
    $sentinel = Join-Path $fixture 'clean.txt'
    Set-Content -LiteralPath (Join-Path $fixture 'public/Bad.ps1') -Value "clean { Set-Content -LiteralPath '$sentinel' -Value 'executed' }"
    { Import-Module -Name $modulePath -Force -ErrorAction Stop } | Should -Throw
    Test-Path -LiteralPath $sentinel | Should -BeFalse
  }

  It 'rejects using module without loading it' {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'public') | Out-Null
    $sentinel = Join-Path $fixture 'module-loaded.txt'
    $dependency = Join-Path $fixture 'Dependency.psm1'
    Set-Content -LiteralPath $dependency -Value "Set-Content -LiteralPath '$sentinel' -Value 'executed'"
    Set-Content -LiteralPath (Join-Path $fixture 'public/Bad.ps1') -Value "using module '$dependency'`nfunction Example { }"
    { Import-Module -Name $modulePath -Force -ErrorAction Stop } | Should -Throw
    Test-Path -LiteralPath $sentinel | Should -BeFalse
  }

  It 'rejects requires module without loading it' {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'public') | Out-Null
    $sentinel = Join-Path $fixture 'requires-loaded.txt'
    $dependency = Join-Path $fixture 'Dependency.psm1'
    Set-Content -LiteralPath $dependency -Value "Set-Content -LiteralPath '$sentinel' -Value 'executed'"
    Set-Content -LiteralPath (Join-Path $fixture 'public/Bad.ps1') -Value "#requires -Modules '$dependency'`nfunction Example { }"
    { Import-Module -Name $modulePath -Force -ErrorAction Stop } | Should -Throw
    Test-Path -LiteralPath $sentinel | Should -BeFalse
  }
}
