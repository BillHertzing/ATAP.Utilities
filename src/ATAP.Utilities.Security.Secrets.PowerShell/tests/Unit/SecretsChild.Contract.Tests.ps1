#requires -Modules Pester

Describe 'ATAP.Utilities.Security.Secrets.PowerShell module contract' {

  # Pester 5 expands -ForEach during DISCOVERY, before BeforeAll runs. Data used by -ForEach
  # must therefore be defined in BeforeDiscovery, not BeforeAll.
  BeforeDiscovery {
    $ExpectedFunctions = @(
      'Get-BitWardenCredential'
      'Invoke-RotateSecretsATAP'
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
      'Invoke-RotateSecretsATAP'
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

    It 'exports exactly the seven expected functions' {
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

    It 'backs alias <alias> with a function-level [Alias()] attribute, not Set-Alias in the .psm1' -ForEach $ExpectedAliasPairs {
      # Regression guard. Build-PSModulePsm1 regenerates the shipped .psm1 from public\ and private\
      # and DISCARDS the source .psm1. A Set-Alias there works from source and then silently vanishes
      # from the published package, leaving AliasesToExport naming aliases that nothing defines --
      # which is exactly what shipped in 0.1.0. Only a function-level [Alias()] attribute survives.
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $script:ModuleRoot "public\$target.ps1"), [ref]$null, [ref]$null)
      $func = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)[0]

      $aliasAttributeValues = @(
        $func.Body.ParamBlock.Attributes |
          Where-Object { $_.TypeName.Name -in @('Alias', 'AliasAttribute') } |
          ForEach-Object { $_.PositionalArguments.Value }
      )

      $aliasAttributeValues | Should -Contain $alias -Because "$target.ps1 must declare [Alias('$alias')] so it survives the module build"
    }

    It 'defines no Set-Alias in the source .psm1, because the build discards it' {
      $psm1 = Get-Content (Join-Path $script:ModuleRoot "$script:ModuleName.psm1") -Raw
      $psm1 | Should -Not -Match '^\s*Set-Alias' -Because 'Set-Alias in the source .psm1 never reaches the published package'
    }

    It 'every alias in AliasesToExport is actually defined by the loaded module' {
      # The manifest must not promise an alias that no code creates.
      $manifest = Import-PowerShellDataFile -Path $script:ModulePath
      foreach ($alias in $manifest.AliasesToExport) {
        Get-Command -Module $script:ModuleName -Name $alias -CommandType Alias -ErrorAction SilentlyContinue |
          Should -Not -BeNullOrEmpty -Because "AliasesToExport names '$alias'"
      }
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

    It 'pins the BuildTooling Secrets child that owns -TokenPurpose' {
      # Invoke-RotateSecretsATAP resolves Get-BWSAccessToken / Initialize-BWSAccessToken with
      # -TokenPurpose. The dedicated child owns those parameters; an older child would bind-fail
      # at rotation time rather than at import time, which is the wrong place to find out.
      $pin = $script:Manifest.RequiredModules |
        Where-Object { $_ -is [hashtable] -and $_.ModuleName -eq 'ATAP.Utilities.BuildTooling.Secrets.PowerShell' }
      $pin | Should -Not -BeNullOrEmpty
      [version]$pin.ModuleVersion | Should -BeGreaterOrEqual ([version]'0.1.0')
    }

    It 'the pinned Secrets child actually exposes -TokenPurpose on both functions' {
      # Guards the pin itself: a version number is only as good as what it contains.
      foreach ($name in @('Get-BWSAccessToken', 'Initialize-BWSAccessToken')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty -Because "$name must resolve once the child is imported"
        $cmd.Parameters.Keys | Should -Contain 'TokenPurpose' -Because "$name must accept -TokenPurpose"
      }
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

    It '<_> attributes its PSFramework messages to this module, not the umbrella it moved out of' -ForEach $ExpectedFunctions {
      $content = Get-Content (Join-Path $script:ModuleRoot "public\$_.ps1") -Raw
      $content | Should -Not -Match "'ATAP\.Utilities\.Security\.Powershell'"
    }

    It 'Get-BitWardenCredential supports ShouldProcess, because it writes credential files' {
      # Rule 11 debt fixed in Task 12.55.c: this Get- function backs up, creates a directory, and
      # writes two Export-Clixml files. A -WhatIf that silently wrote them would be worse than none.
      (Get-Command 'Get-BitWardenCredential' -Module $script:ModuleName).Parameters.Keys |
        Should -Contain 'WhatIf'
    }

    It 'private helpers also define only functions' {
      foreach ($file in Get-ChildItem (Join-Path $script:ModuleRoot 'private') -Filter '*.ps1') {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        $topLevel = $ast.EndBlock.Statements |
          Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }
        $topLevel | Should -BeNullOrEmpty -Because "$($file.Name) must define only a function"
      }
    }

    It 'keeps the private helpers private' {
      # Fingerprinting and console-state helpers are implementation detail; exporting them would
      # invite a caller to fingerprint a secret outside the rotation path.
      foreach ($name in @('Get-SecureStringFingerprint', 'Test-BWSAccessTokenFormat', 'Test-RotationSessionIsInteractive')) {
        Get-Command -Module $script:ModuleName -Name $name -ErrorAction SilentlyContinue |
          Should -BeNullOrEmpty -Because "$name is a private helper"
      }
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
