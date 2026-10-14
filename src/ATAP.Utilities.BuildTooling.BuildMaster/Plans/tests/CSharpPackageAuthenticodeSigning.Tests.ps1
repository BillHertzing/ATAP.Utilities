BeforeAll {
  $script:PlansPath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
  $script:RepoRoot = Resolve-Path -LiteralPath (Join-Path $script:PlansPath '..\..\..')
  $script:HelperPath = Join-Path $script:PlansPath 'CSharpPackageAuthenticodeSigning.ps1'
  $script:RunnerPath = Join-Path $script:PlansPath 'Invoke-CSharpPackageBuildMasterStage.ps1'
  $script:ApprovalPath = Join-Path $script:RepoRoot '_generated/Sprint0015/Task15.182/F03/hitl-signing-approval.json'
  . $script:HelperPath

  function New-Task15189ApprovalFile {
    param(
      [Parameter(Mandatory)][string]$Path,
      [string]$SourceCommit = ('a' * 40)
    )
    $approval = Get-Content -LiteralPath $script:ApprovalPath -Raw | ConvertFrom-Json -Depth 20
    $approval.taskId = '15.189.d'
    $approval.scope.expectedPackageCount = 25
    $approval.scope.expectedAssetCount = 72
    $approval.scope.packageIds = @(Get-CSharpPackageAuthenticodeTask15189PackageNames)
    $approval.scope | Add-Member -NotePropertyName packageIdentities -NotePropertyValue @(Get-CSharpPackageAuthenticodeTask15189PackageIdentities) -Force
    $approval.scope | Add-Member -NotePropertyName assetIds -NotePropertyValue @(Get-CSharpPackageAuthenticodeTask15189AssetIds) -Force
    $approval | Add-Member -NotePropertyName sourceCommit -NotePropertyValue $SourceCommit -Force
    $approval | Add-Member -NotePropertyName feedMutationApproved -NotePropertyValue $true -Force
    $approval | Add-Member -NotePropertyName authorizedRoute -NotePropertyValue @('nuget-experimental', 'nuget-development', 'nuget-integration', 'nuget-qa', 'nuget-stable') -Force
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
    return $approval
  }

  function New-Task15189RecoveryApprovalFile {
    param(
      [Parameter(Mandatory)][string]$Path,
      [string]$SourceCommit = ('c' * 40)
    )
    $approval = New-Task15189ApprovalFile -Path $Path -SourceCommit $SourceCommit
    $approval.taskId = '15.189.d-recovery'
    $approval.scope.expectedPackageCount = 19
    $approval.scope.expectedAssetCount = 54
    $approval.scope.packageIds = @(Get-CSharpPackageAuthenticodeTask15189RecoveryPackageNames)
    $approval.scope.packageIdentities = @(Get-CSharpPackageAuthenticodeTask15189RecoveryPackageIdentities)
    $approval.scope.assetIds = @(Get-CSharpPackageAuthenticodeTask15189RecoveryAssetIds)
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
    return $approval
  }
}

Describe 'Triple-stream exact 45-package/119-asset signing contract' {
  It 'binds exactly 45 packages and the 119 actually evaluated shipping DLL assets' {
    $release = Get-CSharpPackageAuthenticodeReleaseContract

    $release.Packages.Count | Should -Be 45
    $release.Assets.Count | Should -Be 119
    @($release.Packages.PackageName | Sort-Object -Unique).Count | Should -Be 45
    @(Get-CSharpPackageAuthenticodeReleaseAssetIds).Count | Should -Be 119
    @((Get-CSharpPackageAuthenticodeReleaseAssetIds) | Sort-Object -Unique).Count | Should -Be 119
    (Get-Content -LiteralPath $script:HelperPath -Raw) | Should -Match '\$allPackageDlls\.Count\s+-ne\s+\$expectedRelativePaths\.Count'
    @($release.Assets | Group-Object PackageName | ForEach-Object Count | Sort-Object -Unique) | Should -Be @(1, 3)
    @($release.Assets | Group-Object PackageName | Where-Object Count -eq 1 | Select-Object -ExpandProperty Name | Sort-Object) |
      Should -Be @('ATAP.Utilities.RRSBS.Contracts', 'ATAP.Utilities.RRSBS.Domain')
    @($release.Packages | Where-Object { $_.Assets.Count -eq 0 } | Select-Object -ExpandProperty PackageName | Sort-Object) |
      Should -Be @('ATAP.Utilities.Configuration', 'ATAP.Utilities.Secrets', 'ATAP.Utilities.Serializer', 'ATAP.Utilities.Serializer.Shim')
    @($release.Packages | Where-Object { $_.Assets.Count -eq 0 } | ForEach-Object { $_.SupportedTargetFrameworks.Count } | Sort-Object -Unique) |
      Should -Be @(3)
    @($release.Packages | Where-Object { $_.Assets.Count -eq 0 } | ForEach-Object { $_.SupportedTargetFrameworks } | Sort-Object -Unique) |
      Should -Be @('net10.0', 'net8.0', 'net9.0')
    @($release.Assets | Where-Object PackageName -like 'ATAP.Utilities.RRSBS.*' | Select-Object -ExpandProperty BuildTargetFramework -Unique) |
      Should -Be @('net10.0')
    @($release.Assets | Where-Object PackageName -eq 'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows' | Select-Object -ExpandProperty PackageTargetFramework | Sort-Object) |
      Should -Be @('net10.0-windows7.0', 'net8.0-windows7.0', 'net9.0-windows7.0')
  }

  It 'maps every contract package to an existing exact project and rejects every other package' {
    foreach ($contract in (Get-CSharpPackageAuthenticodeReleaseContract).Packages) {
      $projectPath = Join-Path $script:RepoRoot $contract.ProjectPath
      $projectPath | Should -Exist
      $contract.AssemblyName | Should -BeExactly $contract.PackageName
      [xml]$project = Get-Content -LiteralPath $projectPath -Raw
      $includeBuildOutputNode = $project.SelectSingleNode('//IncludeBuildOutput')
      $excludesBuildOutput = $null -ne $includeBuildOutputNode -and [string]$includeBuildOutputNode.InnerText -ceq 'false'
      ($contract.Assets.Count -eq 0) | Should -Be $excludesBuildOutput -Because "the signing asset contract must match IncludeBuildOutput for $($contract.PackageName)"
    }
    Get-CSharpPackageAuthenticodeContract -PackageName 'Vendor.Library' | Should -BeNullOrEmpty
  }

  It 'keeps the DateTime package boundary independently packable with stable version authorities' {
    $dateTimePackages = @(
      'ATAP.Utilities.DateTime.Interfaces'
      'ATAP.Utilities.DateTime.Model'
      'ATAP.Utilities.DateTime.StringConstants'
    )

    foreach ($packageName in $dateTimePackages) {
      $contract = Get-CSharpPackageAuthenticodeContract -PackageName $packageName
      [xml]$project = Get-Content -LiteralPath (Join-Path $script:RepoRoot $contract.ProjectPath) -Raw
      $version = Get-Content -LiteralPath (Join-Path (Split-Path -Parent (Join-Path $script:RepoRoot $contract.ProjectPath)) 'version.json') -Raw |
        ConvertFrom-Json

      [string]$project.Project.PropertyGroup.IsPackable | Should -BeExactly 'true'
      [string]$version.version | Should -Match '^\d+\.\d+\.\d+$'
    }

    [xml]$modelProject = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/ATAP.Utilities.DateTime.Model/ATAP.Utilities.DateTime.Model.csproj') -Raw
    $timePeriodReference = @($modelProject.SelectNodes('//PackageReference') | Where-Object Include -eq 'TimePeriodLibrary.NET')
    $timePeriodReference.Count | Should -Be 1
    [string]$timePeriodReference[0].GetAttribute('PrivateAssets') | Should -BeNullOrEmpty
  }
}

Describe 'Task 15.182.F03 machine-readable HITL boundary' {
  It 'accepts the named Foundation approval record without accessing a certificate or signing tool' {
    Mock Get-CSharpPackageAuthenticodeCertificate { throw 'certificate access is forbidden in this test' }
    Mock Invoke-CSharpPackageAuthenticodeProcess { throw 'signing-tool access is forbidden in this test' }

    $approval = Get-CSharpPackageAuthenticodeApproval -ApprovalPath $script:ApprovalPath

    $approval.publisher | Should -BeExactly 'ATAP Foundation'
    $approval.certificate.sha1Thumbprint | Should -BeExactly '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
    $approval.certificate.sha256Fingerprint | Should -BeExactly 'CDEB3095ADFB200E65E36378E699316552D7CDA328AB8FE3E4DEAD113227DB81'
    $approval.certificate.rootSha1Thumbprint | Should -BeExactly '14BF4006BBFEFE19C3C8F37EC999DE1595AFB1B1'
    $approval.certificate.custodianPrincipal | Should -BeExactly 'UTAT022\SvcBuildmaster'
    $approval.execution.identity | Should -BeExactly 'UTAT022\SvcBuildmaster'
    $approval.tool.productVersion | Should -BeExactly '10.0.28000.2526'
    $approval.tool.signToolSha256 | Should -BeExactly '80972965E7FC311D293222B1A0E2C1BFB60F363239173964DBE2A71638314B9F'
    $approval.timestampAuthority.protocol | Should -BeExactly 'RFC3161'
    Should -Invoke Get-CSharpPackageAuthenticodeCertificate -Times 0 -Exactly
    Should -Invoke Invoke-CSharpPackageAuthenticodeProcess -Times 0 -Exactly
  }

  It 'fails before certificate or signing-tool access when approval is missing' {
    Mock Get-CSharpPackageAuthenticodeCertificate { throw 'certificate access must not run' }
    Mock Invoke-CSharpPackageAuthenticodeProcess { throw 'signing-tool access must not run' }
    $contract = Get-CSharpPackageAuthenticodeContract -PackageName 'ATAP.Utilities.ETW'

    { Invoke-CSharpPackageAuthenticodeStageSigning -Contract $contract -ProjectPath 'C:\synthetic\project.csproj' `
        -Configuration Release -ArtifactsPath 'C:\synthetic\artifacts' -ApprovalPath (Join-Path $TestDrive 'missing.json') `
        -SignToolPath 'C:\synthetic\signtool.exe' -EvidencePath $TestDrive -Confirm:$false } |
      Should -Throw '*private-key use is denied*missing*'

    Should -Invoke Get-CSharpPackageAuthenticodeCertificate -Times 0 -Exactly
    Should -Invoke Invoke-CSharpPackageAuthenticodeProcess -Times 0 -Exactly
  }

  It 'records metadata-only packages without accessing the certificate or signing tool' {
    $approvalPath = Join-Path $TestDrive 'metadata-only-approval.json'
    '{}' | Set-Content -LiteralPath $approvalPath -Encoding utf8NoBOM
    Mock Get-CSharpPackageAuthenticodeApproval { [pscustomobject]@{ taskId = 'triple-stream-csharp-signing-contract-45' } }
    Mock Assert-CSharpPackageAuthenticodeExecutionBoundary {}
    Mock Get-CSharpPackageAuthenticodeCertificate { throw 'certificate access is forbidden for a metadata-only package' }
    Mock Invoke-CSharpPackageAuthenticodeProcess { throw 'signing-tool access is forbidden for a metadata-only package' }
    $contract = Get-CSharpPackageAuthenticodeContract -PackageName 'ATAP.Utilities.Secrets'
    $projectPath = Join-Path $script:RepoRoot $contract.ProjectPath

    $result = Invoke-CSharpPackageAuthenticodeStageSigning -Contract $contract -ProjectPath $projectPath `
      -Configuration Release -ArtifactsPath (Join-Path $TestDrive 'artifacts') -ApprovalPath $approvalPath `
      -SignToolPath (Join-Path $TestDrive 'signtool.exe') -EvidencePath $TestDrive -Confirm:$false

    $result.Assets.Count | Should -Be 0
    $result.Contract.PackageName | Should -BeExactly 'ATAP.Utilities.Secrets'
    $result.EvidencePath | Should -Exist
    Should -Invoke Get-CSharpPackageAuthenticodeCertificate -Times 0 -Exactly
    Should -Invoke Invoke-CSharpPackageAuthenticodeProcess -Times 0 -Exactly
  }

  It 'rejects an approval whose package allowlist drifts' {
    $approval = Get-Content -LiteralPath $script:ApprovalPath -Raw | ConvertFrom-Json -Depth 20
    $approval.scope.packageIds[0] = 'Vendor.Library'
    $path = Join-Path $TestDrive 'drifted-approval.json'
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path } |
      Should -Throw '*does not bind the exact ATAP Foundation eight-package/24-asset release slice*'
  }
  It 'accepts a fresh exact 45-package/119-asset approval without certificate or tool access' {
    $approval = Get-Content -LiteralPath $script:ApprovalPath -Raw | ConvertFrom-Json -Depth 20
    $approval.taskId = 'triple-stream-csharp-signing-contract-45'
    $approval.scope.expectedPackageCount = 45
    $approval.scope.expectedAssetCount = 119
    $approval.scope.packageIds = @(Get-CSharpPackageAuthenticodeReleasePackageNames)
    $approval.scope | Add-Member -NotePropertyName assetIds -NotePropertyValue @(Get-CSharpPackageAuthenticodeReleaseAssetIds)
    $path = Join-Path $TestDrive 'current-approval.json'
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -PackageName 'ATAP.Utilities.Collection.Extensions' } |
      Should -Not -Throw
  }

  It 'rejects a fresh approval whose exact evaluated asset set drifts' {
    $approval = Get-Content -LiteralPath $script:ApprovalPath -Raw | ConvertFrom-Json -Depth 20
    $approval.taskId = 'triple-stream-csharp-signing-contract-45'
    $approval.scope.expectedPackageCount = 45
    $approval.scope.expectedAssetCount = 119
    $approval.scope.packageIds = @(Get-CSharpPackageAuthenticodeReleasePackageNames)
    $assetIds = @(Get-CSharpPackageAuthenticodeReleaseAssetIds)
    $assetIds[0] = $assetIds[0] + '|drift'
    $approval.scope | Add-Member -NotePropertyName assetIds -NotePropertyValue $assetIds
    $path = Join-Path $TestDrive 'drifted-current-approval.json'
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path } |
      Should -Throw '*does not bind the exact ATAP Foundation current 45-package/119-asset filter release slice*'
  }

  It 'keeps the historical F03 approval compatible only with its eight named packages' {
    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $script:ApprovalPath -PackageName 'ATAP.Utilities.ETW' } |
      Should -Not -Throw
    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $script:ApprovalPath -PackageName 'ATAP.Utilities.Collection.Extensions' } |
      Should -Throw '*outside approval task*15.182.F03*'
  }
}

Describe 'Task 15.189.d exact 25-package signing boundary' {
  It 'derives exactly 25 packages and 72 unique shipping assets' {
    @(Get-CSharpPackageAuthenticodeTask15189PackageNames).Count | Should -Be 25
    @(Get-CSharpPackageAuthenticodeTask15189PackageIdentities).Count | Should -Be 25
    @(Get-CSharpPackageAuthenticodeTask15189AssetIds).Count | Should -Be 72
    @((Get-CSharpPackageAuthenticodeTask15189AssetIds) | Sort-Object -Unique).Count | Should -Be 72
    $metadataOnly = @(Get-CSharpPackageAuthenticodeTask15189PackageNames | Where-Object { (Get-CSharpPackageAuthenticodeContract -PackageName $_).Assets.Count -eq 0 })
    $metadataOnly | Should -Be @('ATAP.Utilities.Serializer.Shim')
  }

  It 'accepts only the exact source-bound identities, assets, and feed route' {
    $path = Join-Path $TestDrive 'task-15.189.d.json'
    New-Task15189ApprovalFile -Path $path | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -PackageName 'ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows' -ExpectedSourceCommit ('a' * 40) } |
      Should -Not -Throw
  }

  It 'derives the repository HEAD when the existing runner omits ExpectedSourceCommit' {
    $headCommit = (& git -C $script:RepoRoot rev-parse HEAD).Trim()
    $path = Join-Path $TestDrive 'task-15.189.d-runner-compatible.json'
    New-Task15189ApprovalFile -Path $path -SourceCommit $headCommit | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -PackageName 'ATAP.Utilities.Collection.Extensions' } |
      Should -Not -Throw
  }

  It 'rejects reordered or duplicate package and asset scopes' -ForEach @(
    @{ Name = 'package order'; Mutate = { param($a) $a.scope.packageIds = @($a.scope.packageIds | Sort-Object -Descending) } }
    @{ Name = 'duplicate package'; Mutate = { param($a) $a.scope.packageIds[0] = $a.scope.packageIds[1] } }
    @{ Name = 'asset order'; Mutate = { param($a) $a.scope.assetIds = @($a.scope.assetIds | Sort-Object -Descending) } }
    @{ Name = 'duplicate asset'; Mutate = { param($a) $a.scope.assetIds[0] = $a.scope.assetIds[1] } }
  ) {
    $path = Join-Path $TestDrive ("task-15.189.d-$Name.json" -replace ' ', '-')
    $approval = New-Task15189ApprovalFile -Path $path
    & $Mutate $approval
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('a' * 40) } |
      Should -Throw '*does not bind the exact*Task 15.189.d*'
  }

  It 'rejects wrong identity version, feed route, source commit, or broader scope' -ForEach @(
    @{ Name = 'identity'; Mutate = { param($a) $a.scope.packageIdentities[0] = 'ATAP.Utilities.Collection.Extensions|1.0.2' } }
    @{ Name = 'route'; Mutate = { param($a) $a.authorizedRoute[4] = 'nuget-other' } }
    @{ Name = 'source'; Mutate = { param($a) $a.sourceCommit = ('b' * 40) } }
    @{ Name = 'broader'; Mutate = { param($a) $a.scope.packageIdentities += 'ATAP.Utilities.ETW|0.1.5' } }
    @{ Name = 'feed permission'; Mutate = { param($a) $a.feedMutationApproved = $false } }
    @{ Name = 'string feed permission'; Mutate = { param($a) $a.feedMutationApproved = 'false' } }
  ) {
    $path = Join-Path $TestDrive "task-15.189.d-$Name.json"
    $approval = New-Task15189ApprovalFile -Path $path
    & $Mutate $approval
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('a' * 40) } |
      Should -Throw '*does not bind the exact source, identities, assets, and feed route*'
  }

  It 'rejects a missing or malformed source binding' -ForEach @('', '0b8eaa37') {
    $path = Join-Path $TestDrive "task-15.189.d-source-$($_.Length).json"
    New-Task15189ApprovalFile -Path $path -SourceCommit $_ | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('a' * 40) } |
      Should -Throw '*does not bind the exact source, identities, assets, and feed route*'
  }
}

Describe 'Task 15.189.d-recovery exact 19-package signing boundary' {
  It 'derives exactly 19 ordered identities and 54 unique shipping assets' {
    @(Get-CSharpPackageAuthenticodeTask15189RecoveryPackageNames).Count | Should -Be 19
    @(Get-CSharpPackageAuthenticodeTask15189RecoveryPackageIdentities).Count | Should -Be 19
    @(Get-CSharpPackageAuthenticodeTask15189RecoveryAssetIds).Count | Should -Be 54
    @((Get-CSharpPackageAuthenticodeTask15189RecoveryAssetIds) | Sort-Object -Unique).Count | Should -Be 54
    $metadataOnly = @(Get-CSharpPackageAuthenticodeTask15189RecoveryPackageNames | Where-Object {
      (Get-CSharpPackageAuthenticodeContract -PackageName $_).Assets.Count -eq 0
    })
    $metadataOnly | Should -Be @('ATAP.Utilities.Serializer.Shim')
  }

  It 'accepts only the exact source-bound recovery identities, assets, route, and signer metadata' {
    $path = Join-Path $TestDrive 'task-15.189.d-recovery.json'
    New-Task15189RecoveryApprovalFile -Path $path | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -PackageName 'ATAP.Utilities.Serializer.Shim' -ExpectedSourceCommit ('c' * 40) } |
      Should -Not -Throw
  }

  It 'derives and requires the repository HEAD when the runner omits ExpectedSourceCommit' {
    $headCommit = (& git -C $script:RepoRoot rev-parse HEAD).Trim()
    $path = Join-Path $TestDrive 'task-15.189.d-recovery-runner-compatible.json'
    New-Task15189RecoveryApprovalFile -Path $path -SourceCommit $headCommit | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -PackageName 'ATAP.Utilities.FileIO' } |
      Should -Not -Throw
  }

  It 'rejects every package, identity, asset, or route reordering, duplicate, and extra' -ForEach @(
    @{ Name = 'package reorder'; Mutate = { param($a) $a.scope.packageIds = @($a.scope.packageIds | Sort-Object -Descending) } }
    @{ Name = 'package duplicate'; Mutate = { param($a) $a.scope.packageIds[0] = $a.scope.packageIds[1] } }
    @{ Name = 'package missing'; Mutate = { param($a) $a.scope.packageIds = @($a.scope.packageIds | Select-Object -Skip 1) } }
    @{ Name = 'package extra'; Mutate = { param($a) $a.scope.packageIds += 'ATAP.Utilities.Logging' } }
    @{ Name = 'identity reorder'; Mutate = { param($a) $a.scope.packageIdentities = @($a.scope.packageIdentities | Sort-Object -Descending) } }
    @{ Name = 'identity duplicate'; Mutate = { param($a) $a.scope.packageIdentities[0] = $a.scope.packageIdentities[1] } }
    @{ Name = 'identity missing'; Mutate = { param($a) $a.scope.packageIdentities = @($a.scope.packageIdentities | Select-Object -Skip 1) } }
    @{ Name = 'identity extra'; Mutate = { param($a) $a.scope.packageIdentities += 'ATAP.Utilities.Logging|0.1.1' } }
    @{ Name = 'asset reorder'; Mutate = { param($a) $a.scope.assetIds = @($a.scope.assetIds | Sort-Object -Descending) } }
    @{ Name = 'asset duplicate'; Mutate = { param($a) $a.scope.assetIds[0] = $a.scope.assetIds[1] } }
    @{ Name = 'asset missing'; Mutate = { param($a) $a.scope.assetIds = @($a.scope.assetIds | Select-Object -Skip 1) } }
    @{ Name = 'asset extra'; Mutate = { param($a) $a.scope.assetIds += 'Vendor.Library|Vendor.csproj|Vendor.Library|net8.0|net8.0' } }
    @{ Name = 'route reorder'; Mutate = { param($a) $a.authorizedRoute = @($a.authorizedRoute | Sort-Object -Descending) } }
    @{ Name = 'route duplicate'; Mutate = { param($a) $a.authorizedRoute[0] = $a.authorizedRoute[1] } }
    @{ Name = 'route missing'; Mutate = { param($a) $a.authorizedRoute = @($a.authorizedRoute | Select-Object -Skip 1) } }
    @{ Name = 'route extra'; Mutate = { param($a) $a.authorizedRoute += 'nuget-other' } }
  ) {
    $path = Join-Path $TestDrive ("task-15.189.d-recovery-$Name.json" -replace ' ', '-')
    $approval = New-Task15189RecoveryApprovalFile -Path $path
    & $Mutate $approval
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('c' * 40) } |
      Should -Throw '*Task 15.189.d-recovery*'
  }

  It 'rejects wrong, missing, malformed, or differently cased source commits' -ForEach @(
    @{ Name = 'wrong'; SourceCommit = ('d' * 40) }
    @{ Name = 'missing'; SourceCommit = '' }
    @{ Name = 'short'; SourceCommit = '9ebac8ec' }
    @{ Name = 'uppercase'; SourceCommit = ('A' * 40) }
  ) {
    $path = Join-Path $TestDrive "task-15.189.d-recovery-source-$Name.json"
    New-Task15189RecoveryApprovalFile -Path $path -SourceCommit $SourceCommit | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('c' * 40) } |
      Should -Throw '*Task 15.189.d-recovery*'
  }

  It 'requires both authorization flags to be actual JSON Boolean true values' -ForEach @(
    @{ Name = 'private false'; Property = 'privateKeyUseApproved'; Value = $false }
    @{ Name = 'private string false'; Property = 'privateKeyUseApproved'; Value = 'false' }
    @{ Name = 'private string true'; Property = 'privateKeyUseApproved'; Value = 'true' }
    @{ Name = 'feed false'; Property = 'feedMutationApproved'; Value = $false }
    @{ Name = 'feed string false'; Property = 'feedMutationApproved'; Value = 'false' }
    @{ Name = 'feed string true'; Property = 'feedMutationApproved'; Value = 'true' }
  ) {
    $path = Join-Path $TestDrive ("task-15.189.d-recovery-$Name.json" -replace ' ', '-')
    $approval = New-Task15189RecoveryApprovalFile -Path $path
    $approval.$Property = $Value
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('c' * 40) } |
      Should -Throw
  }

  It 'rejects drift in certificate, execution, tool, or timestamp metadata' -ForEach @(
    @{ Name = 'certificate subject'; Mutate = { param($a) $a.certificate.subject = 'CN=Other' } }
    @{ Name = 'certificate root'; Mutate = { param($a) $a.certificate.rootSha256Fingerprint = ('0' * 64) } }
    @{ Name = 'certificate export string'; Mutate = { param($a) $a.certificate.privateKeyExportAllowed = 'false' } }
    @{ Name = 'execution identity'; Mutate = { param($a) $a.execution.identity = 'UTAT022\Other' } }
    @{ Name = 'execution acl string'; Mutate = { param($a) $a.execution.aclMutationAllowed = 'false' } }
    @{ Name = 'tool hash'; Mutate = { param($a) $a.tool.signToolSha256 = ('0' * 64) } }
    @{ Name = 'tool digest'; Mutate = { param($a) $a.tool.fileDigest = 'SHA384' } }
    @{ Name = 'timestamp protocol'; Mutate = { param($a) $a.timestampAuthority.protocol = 'Authenticode' } }
    @{ Name = 'timestamp uri'; Mutate = { param($a) $a.timestampAuthority.uri = 'http://example.invalid' } }
  ) {
    $path = Join-Path $TestDrive ("task-15.189.d-recovery-metadata-$Name.json" -replace ' ', '-')
    $approval = New-Task15189RecoveryApprovalFile -Path $path
    & $Mutate $approval
    $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8NoBOM

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -ExpectedSourceCommit ('c' * 40) } |
      Should -Throw '*Task 15.189.d-recovery*'
  }

  It 'does not broaden the recovery approval to a package outside its 19 identities' {
    $path = Join-Path $TestDrive 'task-15.189.d-recovery-outside.json'
    New-Task15189RecoveryApprovalFile -Path $path | Out-Null

    { Get-CSharpPackageAuthenticodeApproval -ApprovalPath $path -PackageName 'ATAP.Utilities.Logging' -ExpectedSourceCommit ('c' * 40) } |
      Should -Throw '*outside approval task*15.189.d-recovery*'
  }
}

Describe 'Task 15.182.F03 signature, extraction, vendor, and tamper gates' {
  BeforeEach {
    Mock Invoke-CSharpPackageAuthenticodeProcess {
      [pscustomobject]@{ ExitCode = 0; StandardOutput = ''; StandardError = '' }
    }
    Mock Get-CSharpPackageAuthenticodeSignatureRecord {
      [pscustomobject]@{
        Status = 'Valid'
        SignerSha1 = '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
        SignerSha256 = 'CDEB3095ADFB200E65E36378E699316552D7CDA328AB8FE3E4DEAD113227DB81'
        TimeStamperPresent = $true
      }
    }
  }

  It 'requires Valid status, the exact Foundation signer, and a timestamp' {
    $approval = Get-CSharpPackageAuthenticodeApproval -ApprovalPath $script:ApprovalPath

    { Assert-CSharpPackageAuthenticodeSignatureValid -Path 'synthetic.dll' -SignToolPath 'signtool.exe' -Approval $approval } |
      Should -Not -Throw
    Should -Invoke Invoke-CSharpPackageAuthenticodeProcess -Times 1 -Exactly -ParameterFilter {
      $ArgumentList[0] -eq 'verify' -and $ArgumentList -contains '/pa' -and $ArgumentList -contains '/all'
    }
  }

  It 'rejects a close variant with the wrong signer or no timestamp' -TestCases @(
    @{ SignerSha1 = '0B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'; Timestamp = $true }
    @{ SignerSha1 = '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'; Timestamp = $false }
  ) {
    param($SignerSha1, $Timestamp)
    Mock Get-CSharpPackageAuthenticodeSignatureRecord {
      [pscustomobject]@{
        Status = 'Valid'
        SignerSha1 = $SignerSha1
        SignerSha256 = 'CDEB3095ADFB200E65E36378E699316552D7CDA328AB8FE3E4DEAD113227DB81'
        TimeStamperPresent = $Timestamp
      }
    }
    $approval = Get-CSharpPackageAuthenticodeApproval -ApprovalPath $script:ApprovalPath
    { Assert-CSharpPackageAuthenticodeSignatureValid -Path 'synthetic.dll' -SignToolPath 'signtool.exe' -Approval $approval } |
      Should -Throw '*signer or timestamp verification failed*'
  }

  It 'verifies exact extracted lib TFM bytes and rejects a vendor DLL' {
    $approval = Get-CSharpPackageAuthenticodeApproval -ApprovalPath $script:ApprovalPath
    $contract = Get-CSharpPackageAuthenticodeContract -PackageName 'ATAP.Utilities.ETW'
    $staging = Join-Path $TestDrive 'staging'
    New-Item -ItemType Directory -Path $staging | Out-Null
    $assets = foreach ($asset in $contract.Assets) {
      $path = Join-Path $staging "$($asset.BuildTargetFramework).dll"
      [IO.File]::WriteAllBytes($path, [Text.Encoding]::UTF8.GetBytes("signed-$($asset.BuildTargetFramework)"))
      [pscustomobject]@{
        BuildTargetFramework = $asset.BuildTargetFramework
        PackageTargetFramework = $asset.PackageTargetFramework
        Path = $path
        Sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
      }
    }
    $signingResult = [pscustomobject]@{ Approval = $approval; Contract = $contract; Assets = @($assets) }
    $packageRoot = Join-Path $TestDrive 'package-root'
    foreach ($asset in $assets) {
      $lib = Join-Path $packageRoot "lib/$($asset.PackageTargetFramework)"
      New-Item -ItemType Directory -Path $lib -Force | Out-Null
      Copy-Item -LiteralPath $asset.Path -Destination (Join-Path $lib 'ATAP.Utilities.ETW.dll')
    }
    $nupkg = Join-Path $TestDrive 'ATAP.Utilities.ETW.1.0.0.nupkg'
    [IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $nupkg)

    $verified = Assert-CSharpPackageAuthenticodeNupkg -NupkgPath $nupkg -SigningResult $signingResult `
      -SignToolPath 'signtool.exe' -ScratchRoot $TestDrive
    $verified.Assets.Count | Should -Be 3

    $vendorPath = Join-Path $packageRoot 'lib/net8.0/Vendor.dll'
    [IO.File]::WriteAllBytes($vendorPath, [byte[]]@(1, 2, 3))
    $vendorNupkg = Join-Path $TestDrive 'ATAP.Utilities.ETW.1.0.1.nupkg'
    [IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $vendorNupkg)
    { Assert-CSharpPackageAuthenticodeNupkg -NupkgPath $vendorNupkg -SigningResult $signingResult `
        -SignToolPath 'signtool.exe' -ScratchRoot $TestDrive } | Should -Throw '*no vendor binaries*'
  }

  It 'proves a one-byte task-owned copy is rejected without altering staging' {
    $source = Join-Path $TestDrive 'source.dll'
    [IO.File]::WriteAllBytes($source, [byte[]](1..32))
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    Mock Invoke-CSharpPackageAuthenticodeProcess {
      [pscustomobject]@{ ExitCode = 1; StandardOutput = ''; StandardError = '' }
    }
    Mock Get-CSharpPackageAuthenticodeSignatureRecord {
      [pscustomobject]@{ Status = 'HashMismatch'; SignerSha1 = $null; SignerSha256 = $null; TimeStamperPresent = $false }
    }

    $result = Test-CSharpPackageAuthenticodeTamperNegative -SourcePath $source -SignToolPath 'signtool.exe' -ScratchRoot $TestDrive

    $result.SignToolRejected | Should -BeTrue
    $result.AuthenticodeRejected | Should -BeTrue
    (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash | Should -BeExactly $sourceHash
  }

  It 'drains both redirected streams and returns one process result' {
    $result = @(Invoke-CSharpPackageAuthenticodeProcess -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-Command', 'exit 0'))
    $result.Count | Should -Be 1
    $result[0].ExitCode | Should -Be 0
  }
}

Describe 'Task 15.182.F03 runner orchestration order' {
  It 'builds locked once without package generation, signs once, then packs the same staging tree twice' {
    $runner = Get-Content -LiteralPath $script:RunnerPath -Raw
    $buildIndex = $runner.IndexOf("'build', `$resolvedProjectPath")
    $signIndex = $runner.IndexOf('Invoke-CSharpPackageAuthenticodeStageSigning')
    $packIndex = $runner.IndexOf('foreach ($packRun in 1..2)')

    $buildIndex | Should -BeGreaterThan -1
    $signIndex | Should -BeGreaterThan $buildIndex
    $packIndex | Should -BeGreaterThan $signIndex
    ([regex]::Matches($runner, '''build'', \$resolvedProjectPath')).Count | Should -Be 1
    $runner | Should -Match "'-p:RestoreLockedMode=true'"
    $runner | Should -Not -Match "'--locked-mode'"
    $runner | Should -Match "'-p:GeneratePackageOnBuild=false'"
    $runner | Should -Match "'/p:NoBuild=true'"
    $runner | Should -Match 'Assert-CSharpPackageAuthenticodeNupkg'
    $runner | Should -Match 'Test-CSharpPackageAuthenticodeTamperNegative'
    $runner | Should -Match 'if\s*\(@\(\$signingResult\.Assets\)\.Count\s+-gt\s+0\)'
    $runner | Should -Match "metadata-only package contains no shipping DLL asset to tamper"
    $runner | Should -Match 'authenticodeContract\.SupportedTargetFrameworks'
  }
}
