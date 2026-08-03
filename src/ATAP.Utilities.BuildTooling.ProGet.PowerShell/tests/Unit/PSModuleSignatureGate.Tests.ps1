#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Test-PSModulePackageSignature.ps1')
  . (Join-Path $publicDir 'Set-PSModuleFileSignature.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'PowerShell module package signature gate' -Tag 'Unit' {
  BeforeEach {
    $packageSource = Join-Path $TestDrive 'package-source'
    New-Item -ItemType Directory -Path $packageSource -Force | Out-Null
    'function Get-Synthetic { }' | Set-Content -LiteralPath (Join-Path $packageSource 'Synthetic.psm1')
    '@{ RootModule = ''Synthetic.psm1''; ModuleVersion = ''1.0.0'' }' | Set-Content -LiteralPath (Join-Path $packageSource 'Synthetic.psd1')
    $script:packagePath = Join-Path $TestDrive 'Synthetic.1.0.0.nupkg'
    Remove-Item -LiteralPath $script:packagePath -Force -ErrorAction SilentlyContinue
    [IO.Compression.ZipFile]::CreateFromDirectory($packageSource, $script:packagePath)
    $script:signer = [PSCustomObject]@{ Thumbprint = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' }
    $script:timestamp = [PSCustomObject]@{ Thumbprint = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' }
  }

  It 'accepts only valid timestamped signatures and writes metadata evidence' {
    Mock Get-AuthenticodeSignature {
      [PSCustomObject]@{
        Status = [Management.Automation.SignatureStatus]::Valid
        StatusMessage = 'Signature verified.'
        SignerCertificate = $script:signer
        TimeStamperCertificate = $script:timestamp
      }
    }
    $report = Test-PSModulePackageSignature -NupkgPath $script:packagePath -ResultsPath (Join-Path $TestDrive 'evidence') -RequireTimestamp
    $report.Valid | Should -BeTrue
    $report.SignableFileCount | Should -Be 2
    (Split-Path -Leaf $report.InspectionPath) | Should -Match '^[a-f0-9]{12}$'
    Test-Path -LiteralPath (Join-Path $report.InspectionPath 'signature-report.json') | Should -BeTrue
  }

  It 'rejects an unsigned file' {
    Mock Get-AuthenticodeSignature {
      [PSCustomObject]@{
        Status = [Management.Automation.SignatureStatus]::NotSigned
        StatusMessage = 'Not signed.'
        SignerCertificate = $null
        TimeStamperCertificate = $null
      }
    }
    { Test-PSModulePackageSignature -NupkgPath $script:packagePath -ResultsPath (Join-Path $TestDrive 'unsigned') -RequireTimestamp } |
      Should -Throw '*signature verification failed*NotSigned*'
  }

  It 'rejects a valid signature without a timestamp when policy requires one' {
    Mock Get-AuthenticodeSignature {
      [PSCustomObject]@{
        Status = [Management.Automation.SignatureStatus]::Valid
        StatusMessage = 'Signature verified.'
        SignerCertificate = $script:signer
        TimeStamperCertificate = $null
      }
    }
    { Test-PSModulePackageSignature -NupkgPath $script:packagePath -ResultsPath (Join-Path $TestDrive 'notimestamp') -RequireTimestamp } |
      Should -Throw '*Timestamped=False*'
  }

  It 'rejects a package with no signable PowerShell files' {
    $emptySource = Join-Path $TestDrive 'empty-source'
    New-Item -ItemType Directory -Path $emptySource -Force | Out-Null
    'metadata' | Set-Content -LiteralPath (Join-Path $emptySource 'readme.txt')
    $emptyPackage = Join-Path $TestDrive 'Empty.1.0.0.nupkg'
    [IO.Compression.ZipFile]::CreateFromDirectory($emptySource, $emptyPackage)
    { Test-PSModulePackageSignature -NupkgPath $emptyPackage -ResultsPath (Join-Path $TestDrive 'empty') } |
      Should -Throw '*no signable PowerShell files*'
  }

  It 'keeps the signing authority outside source and selects it by thumbprint' {
    $command = Get-Command Set-PSModuleFileSignature
    $command.Parameters.Keys | Should -Contain 'CertificateThumbprint'
    $command.Parameters.Keys | Should -Contain 'TimestampServerUri'
    $command.Parameters.Keys | Should -Not -Contain 'CertificatePath'
    $command.Parameters.Keys | Should -Not -Contain 'PrivateKeyPath'
    $source = Get-Content -LiteralPath (Join-Path $publicDir 'Set-PSModuleFileSignature.ps1') -Raw
    $source | Should -Match ([regex]::Escape('Cert:\CurrentUser\My'))
    $source | Should -Match ([regex]::Escape('Cert:\LocalMachine\My'))
    $source | Should -Match '1\.3\.6\.1\.5\.5\.7\.3\.3'
    $source | Should -Match 'No provider was specified for the store or object'
    $source | Should -Match 'Keyset does not exist'
    $source | Should -Match 'attempt -le 3'
  }

  It 'makes signing mandatory for publish builds and verifies the packed artifact' {
    $buildFile = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))) 'module.build.ps1'
    $source = Get-Content -LiteralPath $buildFile -Raw
    $source | Should -Match 'Task StageContent BuildPSM1, BuildManifest'
    $source | Should -Match 'Task Sign StageContent'
    $source | Should -Match 'Task Package Sign'
    $source | Should -Match 'Invoke-PSModuleFileSigningWorker\.ps1'
    $source | Should -Match 'ATAP_SIGNING_RESULT:'
    $source | Should -Match "-SkipSigning is permitted only with -SkipPublish"
    $source | Should -Match '(?s)Test-PSModulePackageSignature.+-RequireTimestamp'
  }
}
