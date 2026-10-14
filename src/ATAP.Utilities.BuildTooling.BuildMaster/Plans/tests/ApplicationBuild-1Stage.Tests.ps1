# Pester 5+ static-contract and gate tests for Task 15.196.q (SC-0443):
# ApplicationBuild-1Stage.otter must be a thin runner plan whose argument list
# satisfies every mandatory parameter of Invoke-ApplicationBuildMasterStage.ps1,
# and the runner must refuse before any compile when the approval boundary says no.

BeforeAll {
  $script:PlansDir     = Join-Path $PSScriptRoot '..'
  $script:PlanPath     = Join-Path $script:PlansDir 'ApplicationBuild-1Stage.otter'
  $script:PipelinePath = Join-Path $script:PlansDir 'ApplicationBuild-1Stage.pipeline.json'
  $script:RunnerPath   = Join-Path $script:PlansDir 'Invoke-ApplicationBuildMasterStage.ps1'
  $script:PlanText     = Get-Content -LiteralPath $script:PlanPath -Raw
  $script:RunnerText   = Get-Content -LiteralPath $script:RunnerPath -Raw

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }
  . $script:RunnerPath
}

Describe 'ApplicationBuild-1Stage.otter is a thin runner plan' {
  It 'plan, pipeline and runner exist' {
    $script:PlanPath | Should -Exist
    $script:PipelinePath | Should -Exist
    $script:RunnerPath | Should -Exist
  }

  It 'contains exactly one Exec block invoking pwsh -NoProfile -File with the runner' {
    ([regex]::Matches($script:PlanText, '(?im)^\s*(InedoCore::)?Exec\s*\(')).Count | Should -Be 1
    $script:PlanText | Should -Match 'FileName:\s*pwsh'
    $script:PlanText | Should -Match '-NoProfile\s+-File\s+"\$InvokeApplicationBuildStageScript"'
  }

  It 'contains no Decrypt call, no API key value and no inline -Command (comment prose excluded)' {
    $code = (($script:PlanText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
    $code | Should -Not -Match '\$Decrypt\('
    $code | Should -Not -Match '(?i)-ProGetApiKey\b'
    $code | Should -Not -Match '(?i)-Command\s'
    $code | Should -Match '-ProGetApiKeySecretName\s+"\$ProGetApiKeySecretName"'
  }

  It 'reads the product, signer and host binding from application variables, never literals' {
    $script:PlanText | Should -Match '-ProductId\s+"\$ProductId"'
    $script:PlanText | Should -Match '-CodeSigningCertificateThumbprint\s+"\$CodeSigningCertificateThumbprint"'
    $script:PlanText | Should -Match '-ExpectedHostName\s+"\$ApplicationBuildExpectedHostName"'
    $script:PlanText | Should -Not -Match '[0-9A-F]{40}'
  }

  It 'maps database evidence path and hash exactly once into the runner' {
    ([regex]::Matches($script:PlanText, '-DatabaseEvidencePath\s+"\$DatabaseEvidencePath"')).Count | Should -Be 1
    ([regex]::Matches($script:PlanText, '-DatabaseEvidenceSha256\s+"\$DatabaseEvidenceSha256"')).Count | Should -Be 1
  }

  It 'passes every mandatory runner parameter (the silent-hang guard)' {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$tokens, [ref]$errors)
    $errors.Count | Should -Be 0
    $function = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-ApplicationBuildMasterStage' }, $true)[0]
    $mandatory = @($function.Body.ParamBlock.Parameters | Where-Object {
        $_.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.Name -eq 'Parameter' -and ($_.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' -and ($_.ExpressionOmitted -or $_.Argument.Extent.Text -match '\$true') }) }
      } | ForEach-Object { $_.Name.VariablePath.UserPath })
    $mandatory.Count | Should -BeGreaterThan 15
    $arguments = [regex]::Match($script:PlanText, 'Arguments:\s*>>(.*?)>>', 'Singleline').Groups[1].Value
    $passed = @([regex]::Matches($arguments, '(?:^|\s)-([A-Za-z][A-Za-z0-9]*)\b') | ForEach-Object { $_.Groups[1].Value })
    foreach ($name in $mandatory) { $passed | Should -Contain $name }
    # And nothing the runner does not declare.
    $declared = @($function.Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    foreach ($name in ($passed | Where-Object { $_ -notin 'NoProfile', 'File' })) { $declared | Should -Contain $name }
  }

  It 'pipeline JSON is global, single-stage, targets this plan and declares no listeners' {
    $pipeline = Get-Content -LiteralPath $script:PipelinePath -Raw | ConvertFrom-Json
    $pipeline.Name | Should -Be 'ApplicationBuild-1Stage'
    @($pipeline.Stages).Count | Should -Be 1
    $pipeline.Stages[0].Name | Should -Be 'Build'
    $pipeline.Stages[0].Targets[0].ScriptId | Should -Be 'global::ApplicationBuild-1Stage.otter'
    @($pipeline.EventListeners).Count | Should -Be 0
  }

  It 'runner bootstraps host settings and reads the boundary and the shared signer from source' {
    $script:RunnerText | Should -Match 'Initialize-LocalHostSettings'
    $script:RunnerText | Should -Match 'ApplicationReleaseAuthenticodeSigning\.ps1'
    $script:RunnerText | Should -Match 'Set-AuthenticodeFileSignature\.ps1'
    $script:RunnerText | Should -Match 'Test-ApplicationReleaseSignerAdmitted'
    $script:RunnerText | Should -Not -Match 'Set-AuthenticodeSignature\s'
    $script:RunnerText | Should -Not -Match '\$Decrypt\('
  }

  It 'forwards database evidence only through the repository-script bundle branch' {
    $repositoryBranch = [regex]::Match(
      $script:RunnerText,
      "(?s)'RepositoryScript'\s*\{(?<body>.*?)\n\s*\}\s*'BuildToolingFunction'"
    ).Groups['body'].Value
    $buildToolingBranch = [regex]::Match(
      $script:RunnerText,
      "(?s)'BuildToolingFunction'\s*\{(?<body>.*?)\n\s*\}\s*default"
    ).Groups['body'].Value

    $repositoryBranch | Should -Match '\$bundleParameters\.DatabaseEvidencePath\s*=\s*\$DatabaseEvidencePath'
    $repositoryBranch | Should -Match '\$bundleParameters\.DatabaseEvidenceSha256\s*=\s*\$DatabaseEvidenceSha256'
    $buildToolingBranch | Should -Not -Match 'DatabaseEvidence(?:Path|Sha256)'
  }
}

Describe 'Invoke-ApplicationBuildMasterStage fails closed before any compile' {
  BeforeEach {
    $script:tmp = Join-Path ([IO.Path]::GetTempPath()) "appbuild_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path (Join-Path $script:tmp 'src\ATAP.Utilities.BuildTooling.PowerShell') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:tmp 'ace') -Force | Out-Null
    $script:manifest = Join-Path $script:tmp 'src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1'
    Set-Content -LiteralPath $script:manifest -Value '@{}'
    $script:databaseEvidencePath = Join-Path $script:tmp '_generated\database\release-evidence.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $script:databaseEvidencePath) -Force | Out-Null
    Set-Content -LiteralPath $script:databaseEvidencePath -Value '{"version":"0.1.17"}'
    $script:databaseEvidenceSha256 = (Get-FileHash -LiteralPath $script:databaseEvidencePath -Algorithm SHA256).Hash
    # The runner derives the ATAP.Utilities worktree root from the manifest path and reads the
    # shared signer from there; give the fake root a copy so the dot-source resolves.
    $signerDir = Join-Path $script:tmp 'src\ATAP.Utilities.BuildTooling.ProGet.PowerShell\public'
    New-Item -ItemType Directory -Path $signerDir -Force | Out-Null
    Copy-Item -Path (Join-Path $script:PlansDir '..\..\ATAP.Utilities.BuildTooling.ProGet.PowerShell\public\Set-AuthenticodeFileSignature.ps1') -Destination $signerDir
    if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) { function global:Get-SecretATAP { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) 'stub' } }
    . (Join-Path $script:PlansDir 'ApplicationReleaseAuthenticodeSigning.ps1')
    # Gate tests run on either admitted host; the admitted leaf for THIS host is the valid input.
    $script:hostLeaf = Get-ApplicationReleaseAdmittedSignerThumbprint -HostName $env:COMPUTERNAME
    $script:common = @{
      BuildToolingModulePath = $script:manifest; SourcePath = (Join-Path $script:tmp 'ace')
      BuildMasterBuildId = '1'; BuildNumber = '1'; ExecutionId = '1'; ApplicationName = 'AceOutpost-Build'; Branch = 'b'; Stage = 'Build'
      ArtifactsRoot = 'C:\ATAPArtifacts'; ReleaseVersion = '0.1.3+abcdef1234'; SourceTag = 'AceOutpost/v0.1.3+abcdef1'
      ProGetUrl = 'https://utat01:50000'; ProGetApiKeySecretName = 'ProGet.BuildMaster.API.Key.utat01'
      ReleaseNotes = 'n'; ExpectedTestsPassed = 1; ConversationId = '01a0a0b5-f9cf-7b83-8096-f3fdd7138ae0'
      DatabasePackagePinnedVersion = '0.1.13'; DatabasePackageCompatibleVersionRange = '[0.1.13,0.1.14)'; DatabasePackageLifecycleCeiling = 'database-experimental'
      DatabaseEvidencePath = $script:databaseEvidencePath; DatabaseEvidenceSha256 = $script:databaseEvidenceSha256
      EvidenceRoot = (Join-Path $script:tmp '_generated\q')
    }
  }
  AfterEach { Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }

  It 'refuses a product the boundary does not admit' {
    { Invoke-ApplicationBuildMasterStage @script:common -ProductId 'AceMobile' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw -ExpectedMessage '*not admitted*'
  }

  It 'refuses a signer leaf that is not admitted for this host' {
    { Invoke-ApplicationBuildMasterStage @script:common -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint ('A' * 40) -Confirm:$false } | Should -Throw -ExpectedMessage '*not admitted*'
  }

  It 'refuses to run on a host other than the one the application is bound to' {
    { Invoke-ApplicationBuildMasterStage @script:common -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -ExpectedHostName 'ncat-ltb1' -Confirm:$false } | Should -Throw -ExpectedMessage '*bound to host*'
  }

  It 'refuses a timestamp authority other than the pinned one' {
    { Invoke-ApplicationBuildMasterStage @script:common -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -TimestampServerUri 'http://timestamp.example.test' -Confirm:$false } | Should -Throw -ExpectedMessage '*not the pinned authority*'
  }

  It 'refuses an evidence root outside _generated' {
    $params = $script:common.Clone(); $params.EvidenceRoot = (Join-Path $script:tmp 'elsewhere')
    { Invoke-ApplicationBuildMasterStage @params -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw -ExpectedMessage '*_generated*'
  }

  It 'requires non-empty database evidence for the repository-script product' {
    $params = $script:common.Clone(); $params.DatabaseEvidencePath = ''; $params.DatabaseEvidenceSha256 = ''
    { Invoke-ApplicationBuildMasterStage @params -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw -ExpectedMessage '*DatabaseEvidencePath is required*'
  }

  It 'refuses database evidence outside _generated' {
    $params = $script:common.Clone()
    $params.DatabaseEvidencePath = $script:manifest
    $params.DatabaseEvidenceSha256 = (Get-FileHash -LiteralPath $script:manifest -Algorithm SHA256).Hash
    { Invoke-ApplicationBuildMasterStage @params -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw -ExpectedMessage '*must be under a _generated folder*'
  }

  It 'refuses a malformed database evidence hash' {
    $params = $script:common.Clone(); $params.DatabaseEvidenceSha256 = 'not-a-sha256'
    { Invoke-ApplicationBuildMasterStage @params -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw -ExpectedMessage '*exactly 64 hexadecimal characters*'
  }

  It 'refuses a database evidence hash that does not match the file' {
    $params = $script:common.Clone(); $params.DatabaseEvidenceSha256 = ('A' * 64)
    { Invoke-ApplicationBuildMasterStage @params -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw -ExpectedMessage '*does not match DatabaseEvidenceSha256*'
  }

  It 'refuses an unversioned or malformed release version' {
    $params = $script:common.Clone(); $params.ReleaseVersion = '0.1.3-beta'
    { Invoke-ApplicationBuildMasterStage @params -ProductId 'AceOutpost' -CodeSigningCertificateThumbprint $script:hostLeaf -Confirm:$false } | Should -Throw
  }
}
