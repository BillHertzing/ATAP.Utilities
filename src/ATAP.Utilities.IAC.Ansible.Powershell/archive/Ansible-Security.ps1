# ═══════════════════════════════════════════════════════════════════════════
# ARCHIVED DRAFT — moved from ATAP.IAC repo root 2026-07-07 (Sprint 0012
# Task 12.46.d, PlanPowershellReorganization.md 3.a). NOT loaded by the module
# (archive\ is not dot-sourced by the .psm1). This is aspirational/draft code:
# top-level data script with placeholder GUIDs/passwords and calls to Get-AnsibleCertificates that only exists in this module; it was never importable as a function.
# Superseded by the module''s live functions (Get-AnsibleBuildoutInventory,
# Get-AnsibleCertificates, Get-HostSettings). Kept for design reference only.
# ═══════════════════════════════════════════════════════════════════════════
#   # Need additional arguments to specify that CChoco should be imported into all Powershell scripts that need to control Windows Features `import-module CChoco -scope Global`
#   # Need additional arguments to specify that DISM should be imported into all Powershell scripts that need to control Windows Features `import-module C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DISM -scope Global`
# Get the ansibleInventory from a file by the same name.

# Until the organizations 'infrastructure-as-code (IAC)' is stored in a vault, import the function from the organizations current IAC directory
. $(Join-Path -Path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.IAC', 'Windows', 'HostSettings.ps1'))

# read the organization's People and their IDs
# read the organization's Service accounts and their IDs
# assign


$LocalUsersType1 = [ordered]@{
  People          = @('{GUID_ID1}', '{GUID_ID2}', '{GUID_ID3}' ) # allow login right
  ServiceAccounts = @( '{GUID_ID4}', '{GUID_ID4}', '{GUID_ID5}', '{GUID_ID6}', '{GUID_ID7}', '{GUID_ID8}', '{GUID_ID9}') # allow login as a service right

  UserNames       = [ordered]@{
    '{GUID_ID1}' = 'Administrator'
    '{GUID_ID2}' = 'ansibleAdmin'
    '{GUID_ID3}' = 'whertzing'
    '{GUID_ID4}' = 'JenkinsAgentSrvAcct'
    '{GUID_ID5}' = 'JenkinsCntrlSrvAcct'
    '{GUID_ID6}' = 'SQLServerSrvAcct'
    '{GUID_ID7}' = 'MySQLSrvAcct'
    '{GUID_ID8}' = 'IISSrvAcct'
    '{GUID_ID9}' = 'ProGetPackageRepositoryProviderSrvAcct'
  }
  Passwords       = [ordered]@{
    '{GUID_ID1}' = 'ChangeMe'
    '{GUID_ID2}' = 'ChangeMe'
    '{GUID_ID3}' = 'ChangeMe'
    '{GUID_ID4}' = 'ChangeMe'
    '{GUID_ID5}' = 'ChangeMe'
    '{GUID_ID6}' = 'ChangeMe'
    '{GUID_ID7}' = 'ChangeMe'
    '{GUID_ID8}' = 'ChangeMe'
    '{GUID_ID9}' = 'ChangeMe'
  }
}

$LocalPKICertificatesType1 = [ordered]@{
  'CACertificate'             = @{
    CertificatePath          = 'SecurityPathToCertificates'
    EncryptedPrivateKeyPath  = 'OnlyToBeReadByPKICAServer'
    PrivateKeyPassPhraseFile = 'OnlyToBeReadByPKICAServer'
  }
  # TBD - loop over subordinate CA Certificates
  'WinRMCertificate'          = @{
    CertificatePath          = 'SecurityPathToCertificates'
    EncryptedPrivateKeyPath  = 'ToBeReadByAnsibleForInstalling'
    PrivateKeyPassPhraseFile = 'ToBeReadByAnsibleForInstalling'
  }
  'SSLCertificate'            = @{
    CertificatePath          = 'TBD'
    EncryptedPrivateKeyPath  = 'TBD'
    PrivateKeyPassPhraseFile = 'TBD'
  }
  'CodeSigningCertificate'    = @{
    CertificatePath          = 'TBD'
    EncryptedPrivateKeyPath  = 'TBD'
    PrivateKeyPassPhraseFile = 'TBD'
  }
  # ToD: Move these to 'per-LocalUser' data structure
  'DataEncryptionCertificate' = @{
    CertificatePath          = 'TBD'
    EncryptedPrivateKeyPath  = 'TBD'
    PrivateKeyPassPhraseFile = 'TBD'
  }

}

$ansibleSecurity = [ordered]@{
  'utat01'    = @{
    LocalUsers      = Get-ClonedAndModifiedHashtable $LocalUsersType1
    PKICertificates = Get-ClonedAndModifiedHashtable $LocalPKICertificatesType1 @($(Get-AnsibleCertificates'WinRM' 'utat01'), $(Get-AnsibleCertificates'SSL' 'utat01'))
  }

  'utat022'   = @{
    LocalUsers      = Get-ClonedAndModifiedHashtable $LocalUsersType1
    PKICertificates = Get-ClonedAndModifiedHashtable $LocalPKICertificatesType1 @($(Get-AnsibleCertificates'WinRM' 'utat022'), $(Get-AnsibleCertificates'SSL' 'utat022'))
  }
  'ncat-ltb1' = @{
    LocalUsers      = Get-ClonedAndModifiedHashtable $LocalUsersType1 @{UserNames = [ordered]@{ '{GUID_ID3}' = 'whertzing56' } }
    PKICertificates = Get-ClonedAndModifiedHashtable $LocalPKICertificatesType1 @($(Get-AnsibleCertificates'WinRM' 'ncat-ltb1'), $(Get-AnsibleCertificates'SSL' 'ncat-ltb1'))
  }

  'ncat016'   = @{
    LocalUsers      = Get-ClonedAndModifiedHashtable $LocalUsersType1 @{UserNames = [ordered]@{ '{GUID_ID3}' = 'whertzing56' } }
    PKICertificates = Get-ClonedAndModifiedHashtable $LocalPKICertificatesType1 @($(Get-AnsibleCertificates'WinRM' 'ncat016'), $(Get-AnsibleCertificates'SSL' 'ncat016'))
  }

}


return $ansibleSecurity
