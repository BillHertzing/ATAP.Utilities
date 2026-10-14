# Discovery-scope detection: -Skip: is evaluated before BeforeAll runs, so the Ace sprint
# worktree (a sibling of this repository's worktree) must be located here. Cross-repository
# assertions run only when it is present; they are skipped, never faked, otherwise.
$script:GitHubRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..\..')
$script:AceRoot = @(Get-ChildItem -LiteralPath $script:GitHubRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^Ace-wt-\d+-[Ss]print-\d{4}-' } |
  Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName)
$script:AceAvailable = $script:AceRoot.Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $script:AceRoot[0] 'Build\Invoke-DeterministicApplicationPublish.ps1'))

BeforeAll {
  $script:PlansPath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
  $script:HelperPath = Join-Path $script:PlansPath 'ApplicationReleaseAuthenticodeSigning.ps1'
  . $script:HelperPath
  $script:GitHubRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..\..')
  $script:AceRoot = @(Get-ChildItem -LiteralPath $script:GitHubRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^Ace-wt-\d+-[Ss]print-\d{4}-' } |
    Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName)
}

Describe 'ApplicationReleaseAuthenticodeSigning boundary (Task 15.196.q, q.1)' {
  It 'admits exactly two products and twelve signed files, nothing else' {
    $contract = Get-ApplicationReleaseAuthenticodeReleaseContract
    ($contract.Products.ProductId -join ',') | Should -Be 'AceOutpost,AceCommander'
    $contract.SignedFiles.Count | Should -Be 12
    @($contract.SignedFiles | Sort-Object -Unique).Count | Should -Be 12
  }

  It 'fails closed for a product outside the allowlist, including case variants' {
    { Get-ApplicationReleaseAuthenticodeContract -ProductId 'AceMobile' } | Should -Throw -ExpectedMessage '*not admitted*'
    { Get-ApplicationReleaseAuthenticodeContract -ProductId 'aceoutpost' } | Should -Throw -ExpectedMessage '*not admitted*'
  }

  It 'describes AceOutpost as a Windows service signed at its app host and owned assemblies' {
    $c = Get-ApplicationReleaseAuthenticodeContract -ProductId 'AceOutpost'
    $c.ArtifactKind | Should -Be 'WindowsApplicationOrService'
    $c.BundleEntryPointKind | Should -Be 'RepositoryScript'
    $c.BundleEntryPoint | Should -Be 'AceOutpost.Windows/Deployment/New-AceOutpostReleaseBundle.ps1'
    $c.InstallerRelativePath | Should -Be 'AceOutpost.Windows/Deployment/Install-AceOutpostRelease.ps1'
    ($c.SignedFileNames -join ';') | Should -Be 'AceOutpostService.exe;AceOutpostService.dll;AceOutpost.Database.dll;AceOutpost.Instrumentation.dll;AceCommon.dll;AceETW.dll'
  }

  It 'describes AceCommander as a hosted web application bundled by the BuildTooling function' {
    $c = Get-ApplicationReleaseAuthenticodeContract -ProductId 'AceCommander'
    $c.ArtifactKind | Should -Be 'HostedWebApplication'
    $c.BundleEntryPointKind | Should -Be 'BuildToolingFunction'
    $c.BundleFunctionName | Should -Be 'New-CommanderReleaseBundle'
    $c.SignedFileNames | Should -Contain 'AceCommander.dll'
    $c.SignedFileNames | Should -Contain 'AceCommon.dll'
    $c.SignedFileNames | Should -Not -Contain 'AceCommander.Server.dll'
  }

  It 'signs only ATAP-owned leaf names ending in .dll or .exe' {
    foreach ($product in (Get-ApplicationReleaseAuthenticodeReleaseContract).Products) {
      foreach ($name in $product.SignedFileNames) {
        $name | Should -Match '^(Ace[A-Za-z.]*|AceOutpostService)\.(dll|exe)$'
        $name | Should -Not -Match '[\\/]'
      }
    }
  }

  Context 'signer admissions' {
    It 'admits exactly one leaf per host: utat022 3B5E… and utat01 D4C1…' {
      Get-ApplicationReleaseAdmittedSignerThumbprint -HostName 'utat022' | Should -Be '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E'
      Get-ApplicationReleaseAdmittedSignerThumbprint -HostName 'UTAT01' | Should -Be 'D4C19B2224C80F19D4BAF5609BCD6255A83D3BC7'
      @(Get-ApplicationReleaseSignerAdmissions).Count | Should -Be 2
    }

    It 'fails closed for an unknown host' {
      { Get-ApplicationReleaseAdmittedSignerThumbprint -HostName 'ncat-ltb1' } | Should -Throw -ExpectedMessage '*no admitted application-release signer*'
    }

    It 'refuses the other host''s leaf and any foreign thumbprint, and returns the normalized admitted one' {
      { Test-ApplicationReleaseSignerAdmitted -HostName 'utat01' -Thumbprint '3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E' } | Should -Throw -ExpectedMessage '*not admitted for application releases on*'
      { Test-ApplicationReleaseSignerAdmitted -HostName 'utat01' -Thumbprint ('A' * 40) } | Should -Throw
      Test-ApplicationReleaseSignerAdmitted -HostName 'utat01' -Thumbprint 'd4c19b2224c80f19d4baf5609bcd6255a83d3bc7' | Should -Be 'D4C19B2224C80F19D4BAF5609BCD6255A83D3BC7'
    }

    It 'rejects a malformed thumbprint before any lookup' {
      { Test-ApplicationReleaseSignerAdmitted -HostName 'utat01' -Thumbprint 'D4C1' } | Should -Throw
    }

    It 'pins the timestamp authority every shipped release used' {
      (Get-ApplicationReleaseTimestampServerUri).AbsoluteUri | Should -Be 'http://timestamp.digicert.com/'
    }
  }

  Context 'publish-root resolution' {
    BeforeEach {
      $script:publishRoot = Join-Path ([IO.Path]::GetTempPath()) "appsign_$([guid]::NewGuid().ToString('N'))"
      New-Item -ItemType Directory -Path $script:publishRoot -Force | Out-Null
    }
    AfterEach { Remove-Item -LiteralPath $script:publishRoot -Recurse -Force -ErrorAction SilentlyContinue }

    It 'returns every allowlisted file when all are present and ignores extra third-party files' {
      foreach ($n in 'AceOutpostService.exe', 'AceOutpostService.dll', 'AceOutpost.Database.dll', 'AceOutpost.Instrumentation.dll', 'AceCommon.dll', 'AceETW.dll', 'Newtonsoft.Json.dll') {
        Set-Content -LiteralPath (Join-Path $script:publishRoot $n) -Value 'x'
      }
      $files = Get-ApplicationReleaseSignedFileContract -ProductId 'AceOutpost' -PublishRoot $script:publishRoot
      $files.Count | Should -Be 6
      $files.Name | Should -Not -Contain 'Newtonsoft.Json.dll'
    }

    It 'fails closed when any allowlisted file is missing from the publish root' {
      foreach ($n in 'AceOutpostService.exe', 'AceOutpostService.dll') { Set-Content -LiteralPath (Join-Path $script:publishRoot $n) -Value 'x' }
      { Get-ApplicationReleaseSignedFileContract -ProductId 'AceOutpost' -PublishRoot $script:publishRoot } | Should -Throw -ExpectedMessage '*missing allowlisted signable files*AceCommon.dll*'
    }

    It 'fails closed when the publish root does not exist' {
      { Get-ApplicationReleaseSignedFileContract -ProductId 'AceCommander' -PublishRoot (Join-Path $script:publishRoot 'absent') } | Should -Throw -ExpectedMessage '*does not exist*'
    }
  }

  Context 'cross-repository consistency (skipped when the Ace sprint worktree is absent)' {
    It 'every entry point, record and installer path exists in the Ace worktree' -Skip:(-not $script:AceAvailable) {
      foreach ($product in (Get-ApplicationReleaseAuthenticodeReleaseContract).Products) {
        Join-Path $script:AceRoot[0] $product.ProductRecordPath | Should -Exist
        Join-Path $script:AceRoot[0] $product.PublishEntryPoint | Should -Exist
        Join-Path $script:AceRoot[0] $product.InstallerRelativePath | Should -Exist
        if ($product.BundleEntryPointKind -eq 'RepositoryScript') { Join-Path $script:AceRoot[0] $product.BundleEntryPoint | Should -Exist }
      }
    }

    It 'the product record''s declared assemblies are a subset of the signed set' -Skip:(-not $script:AceAvailable) {
      foreach ($product in (Get-ApplicationReleaseAuthenticodeReleaseContract).Products) {
        $record = Get-Content -LiteralPath (Join-Path $script:AceRoot[0] $product.ProductRecordPath) -Raw | ConvertFrom-Json -Depth 20
        $record.productId | Should -Be $product.ProductId
        $record.artifactKind | Should -Be $product.ArtifactKind
        $declared = @($record.applicationRoot.assemblyFile) + @($record.components | ForEach-Object assemblyFile)
        foreach ($d in $declared) { $product.SignedFileNames | Should -Contain $d }
        if ($record.publish.useAppHost) { $product.SignedFileNames | Should -Contain ([IO.Path]::GetFileNameWithoutExtension($record.applicationRoot.assemblyFile) + '.exe') }
      }
    }

    It 'the BuildTooling bundle function exists for function-kind bundle entry points' {
      $publicRoot = Join-Path $script:PlansPath '..\..\ATAP.Utilities.BuildTooling.PowerShell\public'
      foreach ($product in (Get-ApplicationReleaseAuthenticodeReleaseContract).Products | Where-Object BundleEntryPointKind -eq 'BuildToolingFunction') {
        Join-Path $publicRoot "$($product.BundleFunctionName).ps1" | Should -Exist
      }
    }
  }

  It 'contains no secret material and no Decrypt call' {
    $text = Get-Content -LiteralPath $script:HelperPath -Raw
    $text | Should -Not -Match '\$Decrypt\(|BEGIN (RSA |)PRIVATE KEY|Password\s*='
    $text | Should -Not -Match 'Get-SecretATAP'
  }
}
