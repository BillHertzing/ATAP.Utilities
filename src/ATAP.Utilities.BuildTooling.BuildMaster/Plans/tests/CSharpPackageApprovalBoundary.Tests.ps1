BeforeAll {
  $script:PlansDir = Join-Path $PSScriptRoot '..'
  $script:BoundaryPath = Join-Path $script:PlansDir 'CSharpPackageApprovalBoundary.ps1'
  . $script:BoundaryPath
}

Describe 'Task 15.181.h/S2 prepare-inspect-approve-publish boundary' {
  BeforeEach {
    $script:ArtifactsPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $script:PackagePath = Join-Path $script:ArtifactsPath 'packages/Example.1.2.3.nupkg'
    $script:ManifestPath = Join-Path $script:ArtifactsPath 'approval/prepared.json'
    $script:ApprovalPath = Join-Path $script:ArtifactsPath 'approval/approved.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $script:PackagePath) -Force | Out-Null
    [System.IO.File]::WriteAllBytes($script:PackagePath, [byte[]](1, 3, 3, 7))
  }

  It 'prepares an immutable manifest and returns its exact SHA without feed access' {
    $prepared = New-CSharpPackagePreparedManifest `
      -ArtifactsPath $script:ArtifactsPath `
      -ManifestPath $script:ManifestPath `
      -NupkgPath $script:PackagePath `
      -BuildMasterBuildId 'build-42' `
      -SourceCommit ('a' * 40) `
      -PackageVersion '1.2.3'

    $prepared.PreparedManifestSha256 | Should -Match '^[0-9a-f]{64}$'
    $prepared.Manifest.Packages.Count | Should -Be 1
    $prepared.Manifest.Packages[0].RelativePath | Should -BeExactly 'packages/Example.1.2.3.nupkg'
    $prepared.PreparedManifestSha256 | Should -BeExactly (Get-CSharpPackageApprovalFileSha256 -Path $script:ManifestPath)
  }

  It 'makes identical prepare idempotent but refuses changed immutable state' {
    $parameters = @{
      ArtifactsPath = $script:ArtifactsPath; ManifestPath = $script:ManifestPath; NupkgPath = $script:PackagePath
      BuildMasterBuildId = 'build-42'; SourceCommit = ('a' * 40); PackageVersion = '1.2.3'
    }
    $first = New-CSharpPackagePreparedManifest @parameters
    $second = New-CSharpPackagePreparedManifest @parameters
    $second.PreparedManifestSha256 | Should -BeExactly $first.PreparedManifestSha256

    $parameters.PackageVersion = '1.2.4'
    { New-CSharpPackagePreparedManifest @parameters } | Should -Throw '*Immutable approval-boundary record*'
  }

  It 'fails inspection after package bytes are changed' {
    New-CSharpPackagePreparedManifest `
      -ArtifactsPath $script:ArtifactsPath -ManifestPath $script:ManifestPath -NupkgPath $script:PackagePath `
      -BuildMasterBuildId 'build-42' -SourceCommit ('a' * 40) -PackageVersion '1.2.3' | Out-Null
    [System.IO.File]::WriteAllBytes($script:PackagePath, [byte[]](9, 9, 9))

    { Get-CSharpPackagePreparedManifestInspection -ManifestPath $script:ManifestPath } |
      Should -Throw '*changed after inspection*'
  }

  It 'refuses approval when the operator SHA does not match' {
    New-CSharpPackagePreparedManifest `
      -ArtifactsPath $script:ArtifactsPath -ManifestPath $script:ManifestPath -NupkgPath $script:PackagePath `
      -BuildMasterBuildId 'build-42' -SourceCommit ('a' * 40) -PackageVersion '1.2.3' | Out-Null

    { Approve-CSharpPackagePreparedManifest `
        -ManifestPath $script:ManifestPath -ExpectedPreparedManifestSha256 ('f' * 64) `
        -ApprovedBy 'operator@example' -ApprovalPath $script:ApprovalPath } |
      Should -Throw '*SHA mismatch*'
  }

  It 'authorizes unchanged packages only after the exact SHA is persisted' {
    $prepared = New-CSharpPackagePreparedManifest `
      -ArtifactsPath $script:ArtifactsPath -ManifestPath $script:ManifestPath -NupkgPath $script:PackagePath `
      -BuildMasterBuildId 'build-42' -SourceCommit ('a' * 40) -PackageVersion '1.2.3'

    { Assert-CSharpPackagePublicationAuthorized -ManifestPath $script:ManifestPath -ApprovalPath $script:ApprovalPath } |
      Should -Throw '*approval record is missing*'

    Approve-CSharpPackagePreparedManifest `
      -ManifestPath $script:ManifestPath `
      -ExpectedPreparedManifestSha256 $prepared.PreparedManifestSha256 `
      -ApprovedBy 'operator@example' `
      -ApprovalPath $script:ApprovalPath | Out-Null

    $authorization = Assert-CSharpPackagePublicationAuthorized `
      -ManifestPath $script:ManifestPath `
      -ApprovalPath $script:ApprovalPath
    $authorization.Authorized | Should -BeTrue
    $authorization.ApprovedBy | Should -BeExactly 'operator@example'
    $authorization.PreparedManifestSha256 | Should -BeExactly $prepared.PreparedManifestSha256
  }

  It 'contains no feed or publication command in the isolated state functions' {
    $text = Get-Content -LiteralPath $script:BoundaryPath -Raw
    $text | Should -Not -Match 'Publish-NuGetPackageToProGet|Promote-ProGetPackage|Invoke-RestMethod|dotnet\s+nuget\s+push'
  }

  It 'keeps publication on the original prepared build behind exact persisted authorization' {
    $runnerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-CSharpPackageBuildMasterStage.ps1'
    $runner = Get-Content -LiteralPath $runnerPath -Raw
    $runner | Should -Match '\$tier\s+-eq\s+''Development''\s+-and\s+\$ApprovalAction\s+-eq\s+''Publish'''
    $runner | Should -Match 'original build''s Development transition'
    $runner | Should -Match '(?s)Assert-CSharpPackagePublicationAuthorized.*Publish-NuGetPackageToProGet.*Set-CSharpPackageStageCompleted[^\r\n]+-Tier ''Experimental''.*continuing immutable promotion'
    $runner | Should -Match 'No new\s+#?\s*build or pack occurs on this branch'
  }

  It 'resumes Experimental Publish at Development without entering Experimental build or pack' {
    $runnerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-CSharpPackageBuildMasterStage.ps1'
    $runner = Get-Content -LiteralPath $runnerPath -Raw
    $experimentalGateStart = $runner.IndexOf("if (`$tier -eq 'Experimental' -and `$ApprovalAction -ne 'Prepare')", [System.StringComparison]::Ordinal)
    $publishStart = $runner.IndexOf("'Publish' {", $experimentalGateStart, [System.StringComparison]::Ordinal)
    $tierOrderStart = $runner.IndexOf('$tierOrder = @(Get-TierOrder)', $publishStart, [System.StringComparison]::Ordinal)
    $publishFallback = $runner.Substring($publishStart, $tierOrderStart - $publishStart)

    $experimentalGateStart | Should -BeGreaterOrEqual 0
    $publishStart | Should -BeGreaterThan $experimentalGateStart
    $tierOrderStart | Should -BeGreaterThan $publishStart
    $publishFallback | Should -Match 'Assert-CSharpPackagePublicationAuthorized'
    $publishFallback | Should -Match 'Publish-NuGetPackageToProGet'
    $publishFallback | Should -Match 'Set-CSharpPackageStageCompleted[^\r\n]+-Tier ''Experimental'''
    $publishFallback | Should -Match '\$resumePromotionAfterExperimentalPublish\s*=\s*\$true'
    $publishFallback | Should -Not -Match '(?m)^\s*return\s*$'
    $publishFallback | Should -Not -Match 'dotnet\s+build'
    $publishFallback | Should -Not -Match '''/t:Pack'''

    $authorizationIndex = $publishFallback.IndexOf('Assert-CSharpPackagePublicationAuthorized', [System.StringComparison]::Ordinal)
    $publicationIndex = $publishFallback.IndexOf('Publish-NuGetPackageToProGet', [System.StringComparison]::Ordinal)
    $completionIndex = $publishFallback.IndexOf('Set-CSharpPackageStageCompleted', [System.StringComparison]::Ordinal)
    $publicationIndex | Should -BeGreaterThan $authorizationIndex
    $completionIndex | Should -BeGreaterThan $publicationIndex
    $runner | Should -Match '(?s)\$currentTierIndex\s*=\s*if\s*\(\$resumePromotionAfterExperimentalPublish\).*?\$tierOrder\.IndexOf\(''Development''\).*?else\s*\{.*?\$tierOrder\.IndexOf\(\$tier\)'
    $runner | Should -Match '(?s)for\s*\(\$tierIndex\s*=\s*\$currentTierIndex.*?\$tiersToRun\s*\+=\s*\$tierOrder\[\$tierIndex\]'
  }
  It 'makes resumed Experimental Publish idempotent only after exact authorization and context reconstruction' {
    $runnerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-CSharpPackageBuildMasterStage.ps1'
    $runner = Get-Content -LiteralPath $runnerPath -Raw
    $experimentalGateStart = $runner.IndexOf("if (`$tier -eq 'Experimental' -and `$ApprovalAction -ne 'Prepare')", [System.StringComparison]::Ordinal)
    $publishStart = $runner.IndexOf("'Publish' {", $experimentalGateStart, [System.StringComparison]::Ordinal)
    $tierOrderStart = $runner.IndexOf('$tierOrder = @(Get-TierOrder)', $publishStart, [System.StringComparison]::Ordinal)
    $publishFallback = $runner.Substring($publishStart, $tierOrderStart - $publishStart)

    $authorizationIndex = $publishFallback.IndexOf('Assert-CSharpPackagePublicationAuthorized', [System.StringComparison]::Ordinal)
    $contextIndex = $publishFallback.IndexOf('Update-CSharpPackagePackageContext', [System.StringComparison]::Ordinal)
    $completionTestIndex = $publishFallback.IndexOf('Test-CSharpPackageStageCompleted', [System.StringComparison]::Ordinal)
    $completedBranchStart = $publishFallback.IndexOf('if ($experimentalAlreadyCompleted)', [System.StringComparison]::Ordinal)
    $freshBranchStart = $publishFallback.IndexOf('else {', $completedBranchStart, [System.StringComparison]::Ordinal)
    $resumeIndex = $publishFallback.IndexOf('$resumePromotionAfterExperimentalPublish = $true', [System.StringComparison]::Ordinal)
    $completedBranch = $publishFallback.Substring($completedBranchStart, $freshBranchStart - $completedBranchStart)
    $freshBranch = $publishFallback.Substring($freshBranchStart, $resumeIndex - $freshBranchStart)

    $authorizationIndex | Should -BeGreaterOrEqual 0
    $contextIndex | Should -BeGreaterThan $authorizationIndex
    $completionTestIndex | Should -BeGreaterThan $contextIndex
    $completedBranch | Should -Match 'Get-Content[^\r\n]+\$experimentalCompletionPath.*ConvertFrom-Json'
    $completedBranch | Should -Match 'PackageVersion\s+-cne\s+\$packageVersionForRun'
    $completedBranch | Should -Match 'publication is skipped.*resumes at Development'
    $completedBranch | Should -Not -Match 'Publish-NuGetPackageToProGet|Set-CSharpPackageStageCompleted|Enable-BwsExecutableForCurrentProcess'
    ([regex]::Matches($freshBranch, 'Publish-NuGetPackageToProGet')).Count | Should -Be 2
    ([regex]::Matches($freshBranch, 'Set-CSharpPackageStageCompleted')).Count | Should -Be 1
    $resumeIndex | Should -BeGreaterThan $freshBranchStart
    $publishFallback | Should -Not -Match 'dotnet\s+build|''/t:Pack'''
  }


  It 'leaves Prepare on the Experimental build and two-pack path' {
    $runnerPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-CSharpPackageBuildMasterStage.ps1'
    $runner = Get-Content -LiteralPath $runnerPath -Raw

    $runner | Should -Match '\$resumePromotionAfterExperimentalPublish\s*=\s*\$false'
    $runner | Should -Match '(?s)else\s*\{\s*\$tierOrder\.IndexOf\(\$tier\)\s*\}'
    ([regex]::Matches($runner, '''build'',\s*\$resolvedProjectPath')).Count | Should -Be 1
    $runner | Should -Match 'foreach\s*\(\$packRun\s+in\s+1\.\.2\)'
    $runner | Should -Match '(?s)New-CSharpPackagePreparedManifest.*No feed was mutated.*return'
  }
}
