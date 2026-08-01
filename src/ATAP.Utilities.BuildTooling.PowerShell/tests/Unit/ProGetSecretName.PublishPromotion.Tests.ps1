#Requires -Version 7.0

BeforeDiscovery {
  $script:targets = @(
    'Publish-UniversalPackageToProGet',
    'Publish-PSModuleToProGetFeed',
    'Publish-PSModuleToProGet',
    'Publish-NuGetPackageToProGet',
    'Publish-DatabaseChangePackageToProGet',
    'Promote-DatabaseChangePackage',
    'Promote-ProGetPackage',
    'Move-ProGetPackageInterTier',
    'Move-ProGetPackageIntraTier',
    'Invoke-PairedTierPromotion',
    'Invoke-PromotedModuleTests',
    'Set-FloatingPackagePins',
    'New-HostSettingsForPackageRepositoryFeeds'
  )
}

BeforeAll {
  $script:publicDir = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
  $script:proGetPublicDir = Join-Path $PSScriptRoot '..\..\..\ATAP.Utilities.BuildTooling.ProGet.PowerShell\public' | Resolve-Path
  $script:parentCommands = @('Invoke-PromotedModuleTests', 'New-HostSettingsForPackageRepositoryFeeds')
}

Describe 'Task 13.62 publish and promotion SecretName contract' -Tag 'Unit', 'Security' {
  It '<Name> exposes only the SecretName boundary' -ForEach ($script:targets | ForEach-Object { @{ Name = $_ } }) {
    $commandRoot = if ($Name -in $script:parentCommands) { $script:publicDir } else { $script:proGetPublicDir }
    $path = Join-Path $commandRoot "$Name.ps1"
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    $errors.Count | Should -Be 0
    $functionAst = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name }, $true)
    $parameterNames = @($functionAst.Body.ParamBlock.Parameters.Name.VariablePath.UserPath)
    $parameterNames | Should -Contain 'ProGetApiKeySecretName'
    $parameterNames | Should -Not -Contain 'ApiKey'
    $parameterNames | Should -Not -Contain 'ProGetApiKey'
  }

  It '<Name> has no ProGet API-key environment fallback' -ForEach ($script:targets | ForEach-Object { @{ Name = $_ } }) {
    $commandRoot = if ($Name -in $script:parentCommands) { $script:publicDir } else { $script:proGetPublicDir }
    $content = Get-Content -LiteralPath (Join-Path $commandRoot "$Name.ps1") -Raw
    $content | Should -Not -Match '(?i)PROGET_(ADMIN|BUILDMASTER)_API_KEY'
    $content | Should -Not -Match '(?i)\$env:PROGET[^\r\n]*API.?KEY'
  }

  It 'uses the BuildMaster publishing SecretName as the fail-closed default' {
    foreach ($name in $script:targets) {
      $commandRoot = if ($name -in $script:parentCommands) { $script:publicDir } else { $script:proGetPublicDir }
      $content = Get-Content -LiteralPath (Join-Path $commandRoot "$name.ps1") -Raw
      $content | Should -Match "ProGet\.BuildMaster\.API\.Key"
    }
  }

  It 'records only a SecretName in generated host settings' {
    $content = Get-Content -LiteralPath (Join-Path $script:publicDir 'New-HostSettingsForPackageRepositoryFeeds.ps1') -Raw
    $content | Should -Match 'ApiKeySecretName'
    $content | Should -Not -Match "ApiKeyName\s*="
    $content | Should -Not -Match 'Get-SecretATAP'
  }
}
