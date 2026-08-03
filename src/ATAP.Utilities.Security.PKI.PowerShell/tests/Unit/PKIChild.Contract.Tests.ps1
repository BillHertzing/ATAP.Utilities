BeforeAll {
  $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:ManifestPath = Join-Path $script:ModuleRoot 'ATAP.Utilities.Security.PKI.PowerShell.psd1'
  $script:Manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
  Import-Module $script:ManifestPath -Force -ErrorAction Stop -DisableNameChecking
}

AfterAll {
  Remove-Module 'ATAP.Utilities.Security.PKI.PowerShell' -Force -ErrorAction SilentlyContinue
}

Describe 'ATAP.Utilities.Security.PKI.PowerShell module contract' -Tag 'Unit' {
  It 'exports the approved nineteen-function PKI boundary' {
    $expected = @(
      'Get-DistinguishedNameQualifiedFilePath', 'Install-CACertificate',
      'Install-CodeSigningCertificate', 'Install-DataEncryptionCertificate',
      'Install-SSLCertificate', 'Install-TrustedPublisherCertificate',
      'List-CodeSigningCertificates', 'New-CACertificate',
      'New-CertificateRequest', 'New-DataEncryptionCertificateRequest',
      'New-DistinguishedNameHash', 'New-EncryptedPasswordFile',
      'New-EncryptedPrivateKey', 'New-RandomEncryptionKeyToFile',
      'New-RandomPassPhraseToFile', 'New-SignedCertificate',
      'New-SSLCertificateRequest', 'Update-KeySecurestringFile',
      'Update-MasterPasswordSecureStringFile'
    )
    @($script:Manifest.FunctionsToExport).Count | Should -Be 19
    @($script:Manifest.FunctionsToExport | Sort-Object) | Should -Be ($expected | Sort-Object)
    @(Get-Command -Module 'ATAP.Utilities.Security.PKI.PowerShell').Count | Should -Be 19
  }

  It 'uses explicit empty cmdlet variable and alias exports' {
    @($script:Manifest.CmdletsToExport).Count | Should -Be 0
    @($script:Manifest.VariablesToExport).Count | Should -Be 0
    @($script:Manifest.AliasesToExport).Count | Should -Be 0
  }

  It 'has an independent module version source' {
    $version = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'version.json') -Raw | ConvertFrom-Json
    $version.version | Should -Be '0.1.1'
    @($version.pathFilters) | Should -Be @('./')
  }

  It 'defines exactly one eponymous function in every public file and no top-level statements' {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:ModuleRoot 'public') -Filter '*.ps1') {
      $tokens = $null
      $parseErrors = $null
      $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
      @($parseErrors).Count | Should -Be 0 -Because $file.Name
      $functions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))
      $functions.Count | Should -Be 1 -Because $file.Name
      $functions[0].Name | Should -Be $file.BaseName
      @($ast.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count | Should -Be 0 -Because $file.Name
    }
  }

  It 'contains no expression evaluation or direct console logging' {
    $commandNames = foreach ($file in Get-ChildItem -LiteralPath $script:ModuleRoot -Filter '*.ps1' -Recurse) {
      $tokens = $null
      $parseErrors = $null
      $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
      $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) |
        ForEach-Object { $_.GetCommandName() }
    }
    $commandNames | Should -Not -Contain 'Invoke-Expression'
    $commandNames | Should -Not -Contain 'Write-Host'
    $commandNames | Should -Not -Contain 'Write-Verbose'
  }

  It 'uses the PowerShell 7 certificate-store API and supports TrustedPublisher' {
    $installerSource = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'private/Install-PkiCertificate.ps1') -Raw
    $publisherSource = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'public/Install-TrustedPublisherCertificate.ps1') -Raw
    $installerSource | Should -Match 'X509Store'
    $installerSource | Should -Match 'TrustedPublisher'
    $installerSource | Should -Not -Match 'Import-Certificate|Import-PfxCertificate|Get-PfxData'
    $publisherSource | Should -Match '1\.3\.6\.1\.5\.5\.7\.3\.3'
  }

  It 'packages a CA configuration with distinct EKU profiles' {
    $config = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'CertificateRequestConfigurations/AUdefault.cnf') -Raw
    $config | Should -Match '(?m)^\[ server_cert \]$'
    $config | Should -Match '(?m)^extendedKeyUsage = serverAuth$'
    $config | Should -Match '(?m)^\[ code_signing_cert \]$'
    $config | Should -Match '(?m)^extendedKeyUsage = codeSigning$'
    $config | Should -Match '(?m)^\[ data_encryption_cert \]$'
    $config | Should -Match '1\.3\.6\.1\.4\.1\.311\.80\.1'
  }
}

Describe 'PKI child safe value and file behavior' -Tag 'Unit' {
  It 'normalizes TLS SAN and EKU values' {
    $dn = New-DistinguishedNameHash -CN 'utat01' -O 'ATAP Foundation' -C 'US' `
      -SubjectAlternateName 'DNS:utat01', 'DNS:utat01.atap.local' -ExtendedkeyUsage 'serverAuth'
    $dn.DNAsParameter | Should -Be '/CN=utat01/O=ATAP Foundation/C=US'
    $dn.SubjectAlternateName | Should -Be 'subjectAltName=DNS:utat01,DNS:utat01.atap.local'
    $dn.ExtendedkeyUsage | Should -Be 'extendedKeyUsage=serverAuth'
  }

  It 'rejects malformed SAN entries' {
    { New-DistinguishedNameHash -CN 'utat01' -SubjectAlternateName 'utat01' } | Should -Throw '*Invalid SubjectAlternativeName*'
  }

  It 'does not create a key file under WhatIf' {
    $path = Join-Path $TestDrive 'whatif.key'
    New-RandomEncryptionKeyToFile -KeyFilePath $path -KeySizeInt 32 -WhatIf
    Test-Path -LiteralPath $path | Should -BeFalse
  }

  It 'creates a 32-byte Base64 key and refuses an implicit overwrite' {
    $path = Join-Path $TestDrive 'value.key'
    New-RandomEncryptionKeyToFile -KeyFilePath $path -KeySizeInt 32 -Confirm:$false | Out-Null
    $bytes = [Convert]::FromBase64String((Get-Content -LiteralPath $path -Raw))
    $bytes.Length | Should -Be 32
    { New-RandomEncryptionKeyToFile -KeyFilePath $path -KeySizeInt 32 -Confirm:$false } | Should -Throw '*already exists*'
  }

  It 'round-trips an encrypted SecureString with the generated key' {
    $keyPath = Join-Path $TestDrive 'roundtrip.key'
    $valuePath = Join-Path $TestDrive 'roundtrip.enc'
    New-RandomEncryptionKeyToFile -KeyFilePath $keyPath -KeySizeInt 32 -Confirm:$false | Out-Null
    $secure = ConvertTo-SecureString 'synthetic-test-value' -AsPlainText -Force
    New-EncryptedPasswordFile -PasswordSecureString $secure -PasswordFilePath $valuePath -EncryptionKeyFilePath $keyPath -Confirm:$false | Out-Null
    $key = [Convert]::FromBase64String((Get-Content -LiteralPath $keyPath -Raw))
    $decrypted = ConvertTo-SecureString (Get-Content -LiteralPath $valuePath -Raw) -Key $key
    [Net.NetworkCredential]::new('', $decrypted).Password | Should -Be 'synthetic-test-value'
  }

  It 'reuses an existing cross-reference mapping' {
    $mapPath = Join-Path $TestDrive 'cross-reference.json'
    '{}' | Set-Content -LiteralPath $mapPath
    $dn = New-DistinguishedNameHash -CN 'utat01'
    $first = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $dn -BaseFileName 'server.crt' -OutDirectory $TestDrive -CrossReferenceFilePath $mapPath -Confirm:$false
    $second = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $dn -BaseFileName 'server.crt' -OutDirectory $TestDrive -CrossReferenceFilePath $mapPath -Confirm:$false
    $second | Should -Be $first
  }

  It 'requires the TLS common name to appear in SANs before any OpenSSL call' {
    { New-SSLCertificateRequest -Path (Join-Path $TestDrive 'server.csr') -CommonName 'utat01' -Organization 'ATAP Foundation' `
        -SubjectAlternativeName 'DNS:wrong-host' -EncryptedPrivateKeyPath 'missing.key' `
        -EncryptionKeyPassPhrasePath 'missing.pass' -WhatIf } | Should -Throw '*must include DNS:utat01*'
  }
}
