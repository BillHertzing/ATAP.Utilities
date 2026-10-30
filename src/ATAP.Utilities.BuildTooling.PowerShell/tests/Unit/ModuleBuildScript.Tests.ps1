#Requires -Version 7.0

Describe 'module.build.ps1 package staging contract' {
  BeforeAll {
    $script:moduleBuildPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))) -ChildPath 'module.build.ps1'
  }

  It 'does not mutate the source module manifest during BuildManifest' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Not -Match 'Update-ModuleManifest\s+@sourceManifestParams'
    $text | Should -Not -Match 'updated source'
    $text | Should -Match 'Build-PSModuleManifest'
  }

  It 'packages the generated module directory that contains the generated psm1' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\$script:PackageSrcDir = Join-Path \$script:PackagesDir \$script:ModuleName'
    $text | Should -Match '\$script:GeneratedPsm1Path = Join-Path \$script:PackageSrcDir'
    $text | Should -Match 'Publish-PSResource[ \t]+`\r?\n[ \t]+-Path \$script:PackageSrcDir'
  }

  It 'stages every supported static module payload folder before packaging' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\$moduleContentDirectories = @\(''scripts'', ''Resources'', ''Documentation'', ''Profiles'', ''CertificateRequestConfigurations'', ''schemas''\)'
    $text | Should -Match 'Copy-Item -LiteralPath \$sourceContentDirectory -Destination \$script:PackageSrcDir'
    $text | Should -Match 'Copy-Item[^\r\n]+\r?\n\s+-Recurse -Force -ErrorAction Stop'
  }

  It 'supports a caller-supplied OutputRoot override for isolated package staging' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\[string\] \$OutputRoot'
    $text | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$OutputRoot\)'
    $text | Should -Match '\$script:OutputRoot = \$script:meta.OutputRoot'
    $text | Should -Match '\$script:OutputRoot = \(\$resolvedOutputRoot'
  }

  It 'bootstraps the failure-acknowledgement gate from the AiRendering child source' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match "'Test-FailureAcknowledgedGate'\s*=\s*'ATAP\.Utilities\.BuildTooling\.AiRendering\.PowerShell'"
    $text | Should -Match '\$bootstrapModuleName'
    $text | Should -Not -Match "\$script:_bootstrapPublicDir.+ATAP\.Utilities\.BuildTooling\.PowerShell"
  }

  It 'makes sibling source modules discoverable only for the build process' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\$script:_originalPSModulePath = \$env:PSModulePath'
    $text | Should -Match '\$env:PSModulePath = \$resolvedModulePath'
    $text | Should -Match 'Exit-Build\s*\{\s*\$env:PSModulePath = \$script:_originalPSModulePath'
  }

  It 'derives exported aliases from the source manifest and public function Alias attributes only' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match 'Import-PowerShellDataFile -LiteralPath \$script:meta\.ManifestPath'
    $text | Should -Match '\$functionAst\.Body\.ParamBlock\.Attributes'
    $text | Should -Match 'if \(\$null -eq \$functionAst\.Body\.ParamBlock\)'
    $text | Should -Not -Match "GetCommandName\(\) -in @\('Set-Alias', 'New-Alias'\)"
  }

  It 'retains source-manifest exports for runtime-created child compatibility proxies' {
    $text = Get-Content -LiteralPath $script:moduleBuildPath -Raw

    $text | Should -Match '\$physicalPublicFunctions'
    $text | Should -Match '\$sourceManifestData\.FunctionsToExport'
    $text | Should -Match '\[string\[\]\] \$publicFunctions = @\('
  }

  It 'declares the legacy BWS compatibility names as function Alias metadata that survives package flattening' {
    $moduleRoot = Split-Path -Parent $script:moduleBuildPath
    $getSource = Get-Content -LiteralPath (Join-Path $moduleRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Get-BWSAccessToken.ps1') -Raw
    $initializeSource = Get-Content -LiteralPath (Join-Path $moduleRoot 'src\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public\Initialize-BWSAccessToken.ps1') -Raw

    $getSource | Should -Match "\[Alias\('Get-ServiceAccountBWSAccessToken'\)\]"
    $initializeSource | Should -Match "\[Alias\('Initialize-ServiceAccountBWSAccessToken'\)\]"
  }
}

Describe 'module.build.ps1 genuine isolated StageContent task' {
  BeforeAll {
    $script:moduleBuildPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))) -ChildPath 'module.build.ps1'
    $tokens = $null; $parseErrors = $null
    $buildAst = [System.Management.Automation.Language.Parser]::ParseFile($script:moduleBuildPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'module.build.ps1 did not parse.' }
    $tasks = @($buildAst.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Task'
    }, $true))
    $stageTasks = @($tasks | Where-Object { $_.CommandElements[1].Extent.Text -ceq 'StageContent' })
    if ($stageTasks.Count -ne 1) { throw 'Expected one genuine StageContent task.' }
    $script:stageContentAst = $stageTasks[0].CommandElements[2].Elements[-1].ScriptBlock
    $script:stageContentBody = $script:stageContentAst.GetScriptBlock()
    $script:signTask = @($tasks | Where-Object { $_.CommandElements[1].Extent.Text -ceq 'Sign' })[0]

    $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')
    if ([string]::IsNullOrWhiteSpace($artifactRoot)) {
      $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User')
    }
    if ([string]::IsNullOrWhiteSpace($artifactRoot)) { throw 'ARTIFACTS_PATH is required for StageContent fixtures.' }
    $artifactRoot = [IO.Path]::GetFullPath($artifactRoot).TrimEnd('\', '/')
    if ($artifactRoot -ine 'D:\ATAPArtifacts') { throw 'D:\ATAPArtifacts StageContent fixtures required.' }
    $script:stageFixtureRoot = Join-Path $artifactRoot 'Sprint0017/Task17.26/PackageContent308/RootTests'
    $script:stageUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $null = Get-Command Write-PSFMessage -ErrorAction Stop

    function New-StageContentFixture {
      $root = Join-Path $script:stageFixtureRoot ([guid]::NewGuid().ToString('N'))
      $script:ModuleRoot = Join-Path $root 'SourceFixture'
      $script:PackageSrcDir = Join-Path $root 'PackageFixture'
      $script:GeneratedPsm1Path = Join-Path $script:PackageSrcDir 'Fixture.psm1'
      $script:GeneratedManifestPath = Join-Path $script:PackageSrcDir 'Fixture.psd1'
      $null = [IO.Directory]::CreateDirectory($script:ModuleRoot)
      $null = [IO.Directory]::CreateDirectory($script:PackageSrcDir)
      [IO.File]::WriteAllText($script:GeneratedPsm1Path, 'function Get-Fixture { }' + [char]10, $script:stageUtf8)
      [IO.File]::WriteAllText($script:GeneratedManifestPath, '@{}' + [char]10, $script:stageUtf8)
      return $root
    }
  }

  BeforeEach { Mock Write-PSFMessage {} }

  It 'copies schemas and every existing static payload directory without changing raw bytes' {
    $null = New-StageContentFixture
    $directories = @('scripts', 'Resources', 'Documentation', 'Profiles', 'CertificateRequestConfigurations', 'schemas')
    [byte[]]$payload = @(239, 187, 191, 0, 255, 13, 10, 65)
    foreach ($directory in $directories) {
      $nested = Join-Path $script:ModuleRoot "$directory/nested"
      $null = [IO.Directory]::CreateDirectory($nested)
      [IO.File]::WriteAllBytes((Join-Path $nested 'opaque.fixture'), $payload)
    }
    $schemaPath = Join-Path $script:ModuleRoot 'schemas/state-v1.schema.json'
    [byte[]]$schemaBytes = @(239, 187, 191) + $script:stageUtf8.GetBytes('{"title":"raw schema"}' + [char]13 + [char]10)
    [IO.File]::WriteAllBytes($schemaPath, $schemaBytes)
    $sourceBefore = @(Get-ChildItem -LiteralPath $script:ModuleRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
      $_.FullName + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    }) -join '|'

    & $script:stageContentBody

    foreach ($directory in $directories) {
      $copied = Join-Path $script:PackageSrcDir "$directory/nested/opaque.fixture"
      [Convert]::ToBase64String([IO.File]::ReadAllBytes($copied)) | Should -BeExactly ([Convert]::ToBase64String($payload))
    }
    [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $script:PackageSrcDir 'schemas/state-v1.schema.json'))) |
      Should -BeExactly ([Convert]::ToBase64String($schemaBytes))
    $sourceAfter = @(Get-ChildItem -LiteralPath $script:ModuleRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
      $_.FullName + ':' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    }) -join '|'
    $sourceAfter | Should -BeExactly $sourceBefore
  }

  It 'normalizes only generated staged psm1 and psd1 to exact UTF8 LF bytes before Sign' {
    $null = New-StageContentFixture
    $sourcePath = Join-Path $script:ModuleRoot 'SourceOnly.psm1'
    [byte[]]$sourceBytes = @(239, 187, 191) + $script:stageUtf8.GetBytes('source stays CRLF' + [char]13 + [char]10)
    [IO.File]::WriteAllBytes($sourcePath, $sourceBytes)
    $content = "  # café `tretained  " + [char]13 + [char]10 + 'literal \r\n stays text' + [char]13 + 'end' + [char]10 + [char]10
    [byte[]]$generated = @(239, 187, 191) + $script:stageUtf8.GetBytes($content)
    foreach ($path in @($script:GeneratedPsm1Path, $script:GeneratedManifestPath)) {
      [IO.File]::WriteAllBytes($path, $generated)
    }
    $expected = "  # café `tretained  " + [char]10 + 'literal \r\n stays text' + [char]10 + 'end' + [char]10

    & $script:stageContentBody

    foreach ($path in @($script:GeneratedPsm1Path, $script:GeneratedManifestPath)) {
      $bytes = [IO.File]::ReadAllBytes($path)
      [Convert]::ToBase64String($bytes) | Should -BeExactly ([Convert]::ToBase64String($script:stageUtf8.GetBytes($expected)))
      ($bytes -contains [byte]13) | Should -BeFalse
      $bytes[-1] | Should -Be 10
      [Convert]::ToHexString($bytes) | Should -Not -Match '^EFBBBF'
    }
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath)) | Should -BeExactly ([Convert]::ToBase64String($sourceBytes))
    $script:signTask.CommandElements[2].Elements[0].Extent.Text | Should -BeExactly 'StageContent'
    $script:signTask.CommandElements[2].Elements[-1].ScriptBlock.Extent.StartOffset |
      Should -BeGreaterThan $script:stageContentAst.Extent.EndOffset
  }

  It 'skips absent optional payload directories without creating source content' {
    $null = New-StageContentFixture

    & $script:stageContentBody

    @(Get-ChildItem -LiteralPath $script:ModuleRoot -Force).Count | Should -Be 0
    @(Get-ChildItem -LiteralPath $script:PackageSrcDir -Directory -Force).Count | Should -Be 0
    [IO.File]::ReadAllText($script:GeneratedManifestPath) | Should -BeExactly ('@{}' + [char]10)
  }

  It 'refuses malformed generated UTF8 instead of replacing content with fallback characters' {
    $null = New-StageContentFixture
    [byte[]]$bad = @(255, 10)
    [IO.File]::WriteAllBytes($script:GeneratedManifestPath, $bad)

    { & $script:stageContentBody } | Should -Throw

    [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:GeneratedManifestPath)) | Should -BeExactly ([Convert]::ToBase64String($bad))
  }
}
