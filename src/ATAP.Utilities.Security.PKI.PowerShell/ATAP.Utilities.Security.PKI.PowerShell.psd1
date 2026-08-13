@{
  RootModule = 'ATAP.Utilities.Security.PKI.PowerShell.psm1'
  ModuleVersion = '0.1.2'
  GUID = '6529747a-4cf9-4b31-9c0e-8c9d85ab7f41'
  Author = 'Bill Hertzing for ATAP Foundation'
  CompanyName = 'ATAP Foundation'
  Copyright = '(c) 2018 - 2026 Bill Hertzing. All rights reserved. All code is under the MIT license'
  Description = 'Certificate authority, certificate lifecycle, distinguished-name, and protected key-file functions for ATAP.'
  PowerShellVersion = '7.0'
  CompatiblePSEditions = @('Core')
  RequiredModules = @('PSFramework')
  FunctionsToExport = @(
    'Get-DistinguishedNameQualifiedFilePath'
    'Install-CACertificate'
    'Install-CodeSigningCertificate'
    'Install-DataEncryptionCertificate'
    'Install-PkiTrustCertificate'
    'Install-SSLCertificate'
    'Install-TrustedPublisherCertificate'
    'List-CodeSigningCertificates'
    'New-CACertificate'
    'New-CertificateRequest'
    'New-DataEncryptionCertificateRequest'
    'New-DistinguishedNameHash'
    'New-EncryptedPasswordFile'
    'New-EncryptedPrivateKey'
    'New-PkiCertificatePfx'
    'New-PkiWindowsCodeSigningCertificate'
    'New-RandomEncryptionKeyToFile'
    'New-RandomPassPhraseToFile'
    'New-SignedCertificate'
    'New-SSLCertificateRequest'
    'Update-KeySecurestringFile'
    'Update-MasterPasswordSecureStringFile'
  )
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  PrivateData = @{
    PSData = @{
      Tags = @('ATAP', 'Security', 'PKI', 'Certificates', 'TLS')
      ProjectUri = 'https://github.com/whertzing/ATAP.Utilities'
      ReleaseNotes = 'Add reusable verified multi-host trust distribution and parameterized non-exportable Windows code-signing issuance.'
    }
  }
}
