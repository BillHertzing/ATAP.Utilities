#Requires -Version 7.0

BeforeDiscovery {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $repositoryRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
  $publicRoot = Join-Path $moduleRoot 'public'
  $proGetPublicRoot = Join-Path (Split-Path -Parent $moduleRoot) 'ATAP.Utilities.BuildTooling.ProGet.PowerShell\public'

  $proGetCommandNames = @(
    'Invoke-PairedTierPromotion'
    'Invoke-PromotedModuleTests'
    'List-ProGetApiKeys'
    'List-ProGetConnectors'
    'List-ProGetFeeds'
    'Move-ProGetPackageInterTier'
    'Move-ProGetPackageIntraTier'
    'New-HostSettingsForPackageRepositoryFeeds'
    'New-ProGetApiKey'
    'New-ProGetConnector'
    'New-ProGetFeedSet'
    'Promote-DatabaseChangePackage'
    'Promote-ProGetPackage'
    'Publish-DatabaseChangePackageToProGet'
    'Publish-NuGetPackageToProGet'
    'Publish-PSModuleToProGet'
    'Publish-PSModuleToProGetFeed'
    'Publish-UniversalPackageToProGet'
    'Remove-ProGetApiKeys'
    'Remove-ProGetFeeds'
    'Rename-ProGetFeed'
    'Set-FloatingPackagePins'
  )

  $commandCases = @(
    foreach ($commandName in $proGetCommandNames) {
      $commandRoot = if ($commandName -in @('Invoke-PromotedModuleTests', 'New-HostSettingsForPackageRepositoryFeeds')) {
        $publicRoot
      } else {
        $proGetPublicRoot
      }
      @{
        CommandName = $commandName
        CommandFile = Join-Path $commandRoot "$commandName.ps1"
      }
    }
  )

  $repositoryCase = @{ RepositoryRoot = $repositoryRoot; ModuleRoot = $moduleRoot }
}

Describe 'Task 13.62 ProGet SecretName-only public contract' -Tag 'Unit', 'Security' {
  It '<CommandName> parses and exposes a SecretName boundary without raw API-key parameters or aliases' -ForEach $commandCases {
    param($CommandName, $CommandFile)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($CommandFile, [ref]$tokens, [ref]$parseErrors)

    $parseErrors | Should -BeNullOrEmpty
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $CommandName
      }, $true)
    $functionAst | Should -Not -BeNullOrEmpty
    $parameterNames = @($functionAst.Body.ParamBlock.Parameters.Name.VariablePath.UserPath)
    $parameterNames | Should -Contain 'ProGetApiKeySecretName'
    $parameterNames | Should -Not -Contain 'ApiKey'
    $parameterNames | Should -Not -Contain 'ProGetApiKey'

    $content = Get-Content -LiteralPath $CommandFile -Raw
    $content | Should -Not -Match '(?i)Alias\s*\([^)]*\b(?:ApiKey|ProGetApiKey)\b'
    $content | Should -Not -Match '(?i)\$env:PROGET_(?:ADMIN|BUILDMASTER)_API_KEY'
    $content | Should -Not -Match '(?i)GetEnvironmentVariable\s*\(\s*[''"]PROGET_(?:ADMIN|BUILDMASTER)_API_KEY'
    $content | Should -Not -Match 'ProGet(?:Admin|BuildMaster)ApiKeyConfigRootKey'
  }

  It 'active BuildMaster plans carry SecretNames and contain no legacy ProGet environment-variable dependency' -TestCases $repositoryCase {
    param($RepositoryRoot)

    $plansRoot = Join-Path $RepositoryRoot 'src\ATAP.Utilities.BuildTooling.BuildMaster\Plans'
    $planFiles = @(Get-ChildItem -LiteralPath $plansRoot -File -Recurse |
        Where-Object { $_.FullName -notmatch '[\\/]tests[\\/]' -and $_.Extension -in '.ps1', '.otter' })

    $planFiles | Should -Not -BeNullOrEmpty
    $violations = @(
      foreach ($file in $planFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        if ($content -match '(?i)PROGET_(?:ADMIN|BUILDMASTER)_API_KEY|ProGet(?:Admin|BuildMaster)ApiKeyConfigRootKey') {
          $file.FullName
        }
      }
    )
    $violations | Should -BeNullOrEmpty
  }

  It 'active MSBuild and NuGet caller surfaces contain no legacy ProGet environment-variable dependency' -TestCases $repositoryCase {
    param($RepositoryRoot, $ModuleRoot)

    $candidateFiles = @(
      Join-Path $RepositoryRoot 'src\ATAP.Utilities.BuildTooling.CSharp\ATAP.Utilities.BuildTooling.targets'
      Join-Path $ModuleRoot 'Resources\NuGet.Config'
      Join-Path $RepositoryRoot 'NuGet.Config'
    )

    $violations = @(
      foreach ($file in $candidateFiles) {
        if ((Test-Path -LiteralPath $file) -and
          ((Get-Content -LiteralPath $file -Raw) -match '(?i)PROGET_(?:ADMIN|BUILDMASTER)_API_KEY|ProGet(?:Admin|BuildMaster)ApiKeyConfigRootKey')) {
          $file
        }
      }
    )
    $violations | Should -BeNullOrEmpty
  }
}
