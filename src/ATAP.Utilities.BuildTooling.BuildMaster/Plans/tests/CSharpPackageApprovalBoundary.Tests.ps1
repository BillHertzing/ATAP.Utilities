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
}
