#requires -Modules Pester

Describe 'ATAP.Utilities.Security.Secrets.PowerShell module contract' {

  # Pester 5 expands -ForEach during DISCOVERY, before BeforeAll runs. Data used by -ForEach
  # must therefore be defined in BeforeDiscovery, not BeforeAll.
  BeforeDiscovery {
    $ExpectedFunctions = @(
      'Get-BitWardenCredential'
      'List-BitwardenSecrets'
      'Load-BitwardenBackup'
      'New-BitwardenBackup'
      'Set-BitWardenSecret'
      'Sync-BitWardenDedicatedSecrets'
    )

    $ExpectedAliasPairs = @(
      @{ Alias = 'New-BWSecret'; Target = 'Set-BitWardenSecret' }
      @{ Alias = 'Add-BitWardenLogin'; Target = 'Set-BitWardenSecret' }
      @{ Alias = 'Sync-DedicatedSecrets'; Target = 'Sync-BitWardenDedicatedSecrets' }
    )
  }

  BeforeAll {
    $script:ModuleName = 'ATAP.Utilities.Security.Secrets.PowerShell'
    $script:ModulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.Security.Secrets.PowerShell.psd1'
    $script:ModuleRoot = Join-Path $PSScriptRoot '..\..'

    $script:ExpectedFunctions = @(
      'Get-BitWardenCredential'
      'List-BitwardenSecrets'
      'Load-BitwardenBackup'
      'New-BitwardenBackup'
      'Set-BitWardenSecret'
      'Sync-BitWardenDedicatedSecrets'
    )

    Import-Module -Name $script:ModulePath -Force -ErrorAction Stop
  }

  AfterAll {
    Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
  }

  Context 'Import hygiene' {

    It 'imports without emitting any error' {
      $errs = @()
      Import-Module -Name $script:ModulePath -Force -ErrorVariable errs -ErrorAction SilentlyContinue
      $errs | Should -BeNullOrEmpty
    }

    It 'defines no top-level executable code: no public file runs a command at dot-source time' {
      # Every public .ps1 must contain exactly one eponymous function and nothing else executable.
      foreach ($file in Get-ChildItem (Join-Path $script:ModuleRoot 'public') -Filter '*.ps1') {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
          $file.FullName, [ref]$tokens, [ref]$parseErrors)

        $parseErrors | Should -BeNullOrEmpty -Because "$($file.Name) must parse cleanly"

        # Top-level statements in the file's script block, excluding function definitions.
        $topLevel = $ast.EndBlock.Statements |
          Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }

        $topLevel | Should -BeNullOrEmpty -Because "$($file.Name) must define only a function (no top-level code)"
      }
    }

    It 'has one eponymous function per public file' {
      foreach ($file in Get-ChildItem (Join-Path $script:ModuleRoot 'public') -Filter '*.ps1') {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        $funcs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
        $funcs.Count | Should -Be 1 -Because "$($file.Name) must declare exactly one function"
        $funcs[0].Name | Should -Be $file.BaseName -Because "$($file.Name) must be eponymous"
      }
    }
  }

  Context 'Exported command surface' {

    It 'exports exactly the six expected functions' {
      $actual = (Get-Command -Module $script:ModuleName -CommandType Function).Name | Sort-Object
      $actual | Should -Be ($script:ExpectedFunctions | Sort-Object)
    }

    It 'exports <_>' -ForEach $ExpectedFunctions {
      Get-Command -Module $script:ModuleName -Name $_ -ErrorAction SilentlyContinue |
        Should -Not -BeNullOrEmpty
    }

    It 'exports Load-BitwardenBackup, which the umbrella manifest omitted' {
      # Regression guard: Load-BitwardenBackup existed in the umbrella's public/ but was
      # missing from its FunctionsToExport, so it was unreachable as a cmdlet.
      Get-Command -Module $script:ModuleName -Name 'Load-BitwardenBackup' |
        Should -Not -BeNullOrEmpty
    }

    It 'exports alias <alias> pointing at <target>' -ForEach $ExpectedAliasPairs {
      $resolved = Get-Command -Module $script:ModuleName -Name $alias -CommandType Alias -ErrorAction SilentlyContinue
      $resolved | Should -Not -BeNullOrEmpty
      $resolved.ResolvedCommand.Name | Should -Be $target
    }

    It 'exports no cmdlets and no variables' {
      $manifest = Import-PowerShellDataFile -Path $script:ModulePath
      $manifest.CmdletsToExport | Should -BeNullOrEmpty
      $manifest.VariablesToExport | Should -BeNullOrEmpty
    }
  }

  Context 'Manifest hygiene' {

    BeforeAll { $script:Manifest = Import-PowerShellDataFile -Path $script:ModulePath }

    It 'declares PowerShell 7.0 / Core only' {
      $script:Manifest.PowerShellVersion | Should -Be '7.0'
      $script:Manifest.CompatiblePSEditions | Should -Be @('Core')
    }

    It 'uses no wildcard exports' {
      $script:Manifest.FunctionsToExport | Should -Not -Contain '*'
      $script:Manifest.CmdletsToExport | Should -Not -Contain '*'
      $script:Manifest.VariablesToExport | Should -Not -Contain '*'
    }

    It 'declares its real dependencies and takes no PKI dependency' {
      $script:Manifest.RequiredModules | Should -Contain 'PSFramework'
      $script:Manifest.RequiredModules | Should -Contain 'Microsoft.PowerShell.SecretManagement'
      # Design decision D1: Invoke-RotateSecretsATAP calls no PKI function.
      $script:Manifest.RequiredModules | Should -Not -Contain 'ATAP.Utilities.Security.PKI.PowerShell'
    }

    It 'FunctionsToExport matches the public file basenames exactly' {
      $files = (Get-ChildItem (Join-Path $script:ModuleRoot 'public') -Filter '*.ps1').BaseName | Sort-Object
      ($script:Manifest.FunctionsToExport | Sort-Object) | Should -Be $files
    }
  }

  Context 'Logging and secret-handling standards' {

    It '<_> uses PSFramework logging, never Write-Host or Write-Output' -ForEach $ExpectedFunctions {
      $content = Get-Content (Join-Path $script:ModuleRoot "public\$_.ps1") -Raw
      $content | Should -Not -Match 'Write-Host'
      $content | Should -Not -Match 'Write-Output'
      $content | Should -Match 'Write-PSFMessage'
    }

    It '<_> never logs at the forbidden -Level Info' -ForEach $ExpectedFunctions {
      $content = Get-Content (Join-Path $script:ModuleRoot "public\$_.ps1") -Raw
      $content | Should -Not -Match '-Level\s+Info'
    }

    It '<_> declares [CmdletBinding()]' -ForEach $ExpectedFunctions {
      $content = Get-Content (Join-Path $script:ModuleRoot "public\$_.ps1") -Raw
      $content | Should -Match 'CmdletBinding'
    }
  }

  Context 'Commands resolve without touching a real vault' {

    It 'Sync-BitWardenDedicatedSecrets depends on Test-SecretVault from SecretManagement, not a sibling function' {
      # Regression guard for the Task 12.55.b finding: the umbrella's public/Test-SecretVault.ps1
      # defined no function; the call resolves to the Microsoft cmdlet. If a sibling function of
      # that name ever appears, the extraction has a hidden child->umbrella edge.
      $cmd = Get-Command 'Test-SecretVault' -ErrorAction SilentlyContinue
      $cmd | Should -Not -BeNullOrEmpty
      $cmd.Source | Should -Be 'Microsoft.PowerShell.SecretManagement'
    }
  }
}
