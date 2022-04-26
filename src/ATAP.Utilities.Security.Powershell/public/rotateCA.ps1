#function rotateCA {
#[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet' )]
#Param(
#$ValidityPeriod = 1
#, $ValidityPeriodUnits = 'year'
#, [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
#[string] $Encoding
#
#)
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-DNSubject.ps1'
function Get-CertificateSecurityDNFilePath {
  param(
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $DNSubject
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    # BaseFileName mustinclude an extension
    [ValidateScript({ Split-Path $_ -Extension })]
    $BaseFileName
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $OutDirectory
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType leaf })]
    [string] $CrossReferenceFilePath
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
  )
  # [Replace invalid filename chars](https://stackoverflow.com/questions/67884618/replace-invalid-filename-chars) accepted answer by
  $pattern = '[' + ([System.IO.Path]::GetInvalidFileNameChars() -join '').Replace('\', '\\') + ']+'
  $DNFileName = [regex]::Replace("$($DNSubject.AsFileName)-$BaseFileName", $pattern, '-')
  # get the crossreferences from persistence
  # ToDo: Add Force paramter, whatif, etc,
  $crossreferences = Get-Content -Path $CrossReferenceFilePath -Encoding $encoding | ConvertFrom-Json -AsHashtable
  # If the DNFilename already exist in the cross reference file, replace it, else add a new crossreference to a new guid
  # Associate a GUID to the DNFilename, and use the suffix from the BaseFileName
  $crossreferences[$DNFileName] = $(Join-Path $OutDirectory $(New-Guid)) + $(Split-Path $BaseFileName -Extension)
  # update the crossreferences in presistence
  $crossreferences | ConvertTo-Json | Out-File -FilePath $CrossReferenceFilePath -Encoding $Encoding
  # return the obsfucated DNFilePath
  $crossreferences[$DNFileName]
}
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-EncryptionKeyPassPhraseFile.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-EncryptedPrivateKey.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-CACertificate.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-CertificateRequest.ps1'
Function New-SignedCertificate {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CertificateRequestPath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CACertificatePath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CAEncryptedPrivateKeyPath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CAEncryptionKeyPassPhrasePath
    # ToDo: figure out better validation for ValidityPeriod and ValidityRange
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateRange(1, 1000)]
    [int16] $ValidityPeriod
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateSet('days', 'weeks', 'years')]
    [string] $ValidityPeriodUnits
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType Container })]
    [string] $CertificatePath
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # Convert vaility period/units into days
    $internalValidityDays =
    switch ($ValidityPeriodUnits) {
      'days' { $ValidityPeriod }
      'weeks' { $ValidityPeriod * 7 }
      'years' { $ValidityPeriod * 365 }
    }
    # SSL Certificates are capped at 365 days, enforce that here
    if ($internalValidityDays -gt 365) {
      Write-PSFMessage -Level Warning -Message "Certificate's validity periods are capped at 365 days, $internalValidityDays days is too long"
      $internalValidityDays = 365
    }
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # openssl must be in the path
    # ToDo: lots of error handling
    openssl ca -batch -cert $CACertificatePath -keyfile $CAEncryptedPrivateKeyPath -passin file:$CAEncryptionKeyPassPhrasePath -days $internalValidityDays -in $CertificateRequestPath -out $CertificatePath > $null
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}

$needNewCACertificate = $true
if ($needNewCACertificate) {
  $DNSubject = New-Object PSObject -Property @{
    CN                                       = 'utat022'
    EmailAddress                             = 'SecurityAdminsList@ATAPUtilities.org'
    Country                                  = 'US'
    StateOrTerritory                         = 'UT'
    Locality                                 = 'HD'
    Organization                             = 'ATAPUtilities.org'
    OrganizationUnit                         = 'Development'
    SubjectReplacementPattern                = 'CN="{0}",OU="{1}",O="{2}",L="{3}",ST="{4},C="{5}"'
    SubjectAlternativeNameReplacementPattern = 'E="{0}"'
    #KeyUseage                                = @('critical', 'cRLSign', 'digitalSignature', 'keyCertSign')
    #ExtendedKeyUseage                        = 'CA:TRUE'
    # ExtendedKeyUseage = @('critical','codeSigning')
  } | Get-DNSubject

  # ToDo: Investigte fast ways to validate the string provided for the ECCurve is supported by openSSL
  $ECCurve = 'P-256'
  $ValidityPeriod = 2
  $ValidityPeriodUnits = 'years'
  $Encoding = 'UTF8'

  $EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
  $EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'RootCertificateAuthorityCertificatePassPhraseFile.txt' -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']]
  New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath
  # validate the EncryptedPrivateKeyPath exists and is non-zero
  if (Test-Path -Path $EncryptionKeyPassPhrasePath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $EncryptionKeyPassPhrasePath -Name 'Length')) {
      throw "New-EncryptionKeyPassPhraseFile created 0-length EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
    }
  }
  else {
    throw "New-EncryptionKeyPassPhraseFile failed to create the EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
  }

  $EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
  $EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificateEncryptedPrivateKey.pem' -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
  New-EncryptedPrivateKey -ECCurve $ECCurve -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath
  # validate the EncryptedPrivateKeyPath exists and is non-zero
  if (Test-Path -Path $EncryptedPrivateKeyPath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $EncryptedPrivateKeyPath -Name 'Length')) {
      throw "New-EncryptedPrivateKey created 0-length EncryptedPrivateKey at $EncryptedPrivateKeyPath"
    }
  }
  else {
    throw "New-EncryptedPrivateKey failed to create the EncryptedPrivateKey at $EncryptedPrivateKeyPath"
  }

  # A CA certificate does not need a Certificate Request
  # $CertificateRequestConfigPath = {
  #   $EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
  #   Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']] 'CATemplate.cnf'
  # }
  $CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
  $CertificatePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificate.crt' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']]
  # Write-PSFMessage -Level Critical -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
  #       EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath
  #       EncryptedPrivateKeyPath     = $EncryptedPrivateKeyPath
  #       CertificateRequestPath      = $CertificateRequestPath
  #       CertificatePath             = $CertificatePath
  #     }))
  New-CACertificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CertificatePath $CertificatePath
  #New-CACertificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestConfigPath $CertificateRequestConfigPath -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CertificatePath $CertificatePath
  if (Test-Path -Path $CertificatePath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $CertificatePath -Name 'Length')) {
      throw "New-CACertificate created 0-length Certificate at $CertificatePath"
    }
  }
  else {
    throw "New-CACertificate failed to create the Certificate at $CertificatePath"
  }

  # Store in Secret Vault
  $SecretVaultName = 'SecurityAdminSecrets'
  $SecretVaultDescription = 'Secrets for Security Administrators'
  $ExtensionVaultModuleName = 'SecretManagement.Keepass'
  $PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet

  $KeyFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Certificates', 'EncryptedKeys', 'SecretVaultTestingEncryption.key' # Join-Path $env:TEMP 'SecretVaultTestingEncryption.key'
  $EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'EncryptedPasswordFiles', 'SecretVaultTestingEncryptedPassword.txt' # $env:TEMP 'SecretVaultTestingEncryptedPassword.txt'

  $PasswordTimeout = 300

  $EncryptionKeyData = Get-Content -Encoding $Encoding -Path $KeyFilePath
  $PasswordSecureString = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $EncryptedPasswordFilePath) -Key $EncryptionKeyData

  Write-PSFMessage -Level Important -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
        KeyFilePath               = $KeyFilePath
        EncryptedPasswordFilePath = $EncryptedPasswordFilePath
        EncryptionKeyData         = $EncryptionKeyData
        PasswordSecureString      = $PasswordSecureString
      }))

  $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
  switch ($ExtensionVaultModuleName) {
    'Microsoft.PowerShell.SecretStore' {
      # $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
      #Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
    }
    'SecretManagement.Keepass' {
      # Note that the MasterVaultPassword is supplied when registering a 'Microsoft.PowerShell.SecretStore' vault
      $VP += @{Path = $PathToKeePassDB; KeyPath = $KeyFilePath }
      #Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
    }
  }
  # Clear any previously registered secret vault
  Get-SecretVault | Unregister-SecretVault
  # register the requested SecretVault
  Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP

  # ToDo: figure out how to capture the warnings issued when Unlock-SecretVault fails
  switch ($ExtensionVaultModuleName) {
    'Microsoft.PowerShell.SecretStore' {
      Unlock-SecretStore -Name $SecretVaultName -Password $PasswordSecureString
    }
    'SecretManagement.Keepass' {
      Unlock-SecretVault -Name $SecretVaultName -Password $PasswordSecureString
    }
  }
  # ToDo: figure out how to capture the warnings issued when Test-SecretVault fails
  $success = Test-SecretVault -Name $SecretVaultName
  if (! $Success) {
    Write-PSFMessage -Level Error -Message "Could not unlock SecretVault $SecretvaultName" -Tag 'Security'
    throw "Could not unlock SecretVault $SecretvaultName"
  }

  # Some vaults allow a secret to be changed, but others require a secret be deleted and then added

  # ToDo: handle errors if a secret cannot be found
  $SecretName = 'CAEncryptionKeyPassPhrasePath'
  Write-PSFMessage -Level Important -Message " EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath"
  Remove-Secret -Name $SecretName -Vault $SecretVaultName
  Set-Secret -Name $SecretName -Vault $SecretVaultName -Secret $EncryptionKeyPassPhrasePath # -Metadata @{description = "Current Root CA Key PassPhrase Path"}
  $SecretName = 'CAEncryptedPrivateKeyPath'
  Remove-Secret -Name $SecretName -Vault $SecretVaultName
  Set-Secret -Name $SecretName -Vault $SecretVaultName -Secret $EncryptedPrivateKeyPath # -Metadata @{description = "Current Root CA Encrypted Private Key Path"}
  $SecretName = 'CACertificatePath'
  Remove-Secret -Name $SecretName -Vault $SecretVaultName
  Set-Secret -Name $SecretName -Vault $SecretVaultName -Secret $CertificatePath # -Metadata @{description = "Current Root CA Certificate Path"}
}

# Retrieve the signing Certificate Authority Certificate from a Secret Vault

$SecretVaultName = 'SecurityAdminSecrets'
$SecretVaultDescription = 'Secrets for Security Administrators'
$ExtensionVaultModuleName = 'SecretManagement.Keepass'
$PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet

$KeyFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Certificates', 'EncryptedKeys', 'SecretVaultTestingEncryption.key' # Join-Path $env:TEMP 'SecretVaultTestingEncryption.key'
$EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'EncryptedPasswordFiles', 'SecretVaultTestingEncryptedPassword.txt' # $env:TEMP 'SecretVaultTestingEncryptedPassword.txt'

$PasswordTimeout = 300

$EncryptionKeyData = Get-Content -Encoding $Encoding -Path $KeyFilePath
$PasswordSecureString = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $EncryptedPasswordFilePath) -Key $EncryptionKeyData

$VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    # $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
    #Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
  }
  'SecretManagement.Keepass' {
    # Note that the MasterVaultPassword is supplied when registering a 'Microsoft.PowerShell.SecretStore' vault
    $VP += @{Path = $PathToKeePassDB; KeyPath = $KeyFilePath }
    #Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
  }
}
# Clear any previously registered secret vault
Get-SecretVault | Unregister-SecretVault
# register the requested SecretVault
Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP

# ToDo: figure out how to capture the warnings issued when Unlock-SecretVault fails
switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    Unlock-SecretStore -Name $SecretVaultName -Password $PasswordSecureString
  }
  'SecretManagement.Keepass' {
    Unlock-SecretVault -Name $SecretVaultName -Password $PasswordSecureString
  }
}
# ToDo: figure out how to capture the warnings issued when Test-SecretVault fails
$success = Test-SecretVault -Name $SecretVaultName
if (! $Success) {
  Write-PSFMessage -Level Error -Message "Could not unlock SecretVault $SecretvaultName" -Tag 'Security'
  throw "Could not unlock SecretVault $SecretvaultName"
}

# Get the current root CA certificate files
$SecretName = 'CAEncryptionKeyPassPhrasePath'
$CAEncryptionKeyPassPhrasePath = ConvertFrom-SecureString -SecureString (Get-Secret -Name $SecretName -Vault $name) -AsPlainText
$SecretName = 'CAEncryptedPrivateKeyPath'
$CAEncryptedPrivateKeyPath = ConvertFrom-SecureString -SecureString (Get-Secret -Name $SecretName -Vault $name) -AsPlainText
$SecretName = 'CACertificatePath'
$CACertificatePath = ConvertFrom-SecureString -SecureString (Get-Secret -Name $SecretName -Vault $name) -AsPlainText

Write-PSFMessage -Level Critical -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
      CAEncryptionKeyPassPhrasePath = $CAEncryptionKeyPassPhrasePath
      CACertificatePath             = $CACertificatePath
      CAEncryptedPrivateKeyPath     = $CAEncryptedPrivateKeyPath
    }))


# The following will print out information about the CACertificate
openssl x509 -text -in $CACertificatePath -noout

# Install the new CA to the Certificate Store in the LocalMachine's Trusted Root subdirectory
$RootCertificateAuthorityCertificateCertStoreLocation = 'cert:\LocalMachine\Root'
# ToDo: error handling
Import-Certificate -FilePath $CACertificatePath -CertStoreLocation $RootCertificateAuthorityCertificateCertStoreLocation >$null


### The SSL Certificate for utat022
$DNSubject = New-Object PSObject -Property @{
  CN                                       = 'utat022'
  EmailAddress                             = 'SecurityAdminsList@ATAPUtilities.org'
  Country                                  = 'US'
  StateOrTerritory                         = 'UT'
  Locality                                 = 'HD'
  Organization                             = 'ATAPUtilities.org'
  OrganizationUnit                         = 'Development'
  SubjectReplacementPattern                = 'CN="{0}",OU="{1}",O="{2}",L="{3}",ST="{4},C="{5}"'
  SubjectAlternativeNameReplacementPattern = 'E="{0}"'
  ExtendedKeyUseage                        = 'serverAuth, clientAuth'
} | Get-DNSubject


$ECCurve = 'P-256'
$ValidityPeriod = 2
$ValidityPeriodUnits = 'years'
$Encoding = 'UTF8'

$EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'RootCertificateAuthorityCertificatePassPhraseFile.txt' -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey']]
New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath
# validate the EncryptedPrivateKeyPath exists and is non-zero
if (Test-Path -Path $EncryptionKeyPassPhrasePath -PathType Leaf) {
  if (-not (Get-ItemPropertyValue -Path $EncryptionKeyPassPhrasePath -Name 'Length')) {
    throw "New-EncryptionKeyPassPhraseFile created 0-length EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
  }
}
else {
  throw "New-EncryptionKeyPassPhraseFile failed to create the EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
}

$EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificateEncryptedPrivateKey.pem' -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
New-EncryptedPrivateKey -ECCurve $ECCurve -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath
# validate the EncryptedPrivateKeyPath exists and is non-zero
if (Test-Path -Path $EncryptedPrivateKeyPath -PathType Leaf) {
  if (-not (Get-ItemPropertyValue -Path $EncryptedPrivateKeyPath -Name 'Length')) {
    throw "New-EncryptedPrivateKey created 0-length EncryptedPrivateKey at $EncryptedPrivateKeyPath"
  }
}
else {
  throw "New-EncryptedPrivateKey failed to create the EncryptedPrivateKey at $EncryptedPrivateKeyPath"
}

# The configuration file for a SSL Client and Server Certificate
$CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']] 'SSLCertificateTemplate.cnf'
$CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$CertificateRequestPath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'CACertificateRequest.csr' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']]
New-CertificateRequest -DNSubject $DNSubject -CertificateRequestConfigPath $CertificateRequestConfigPath -CertificateRequestPath $CertificateRequestPath
if (Test-Path -Path $CertificateRequestPath -PathType Leaf) {
  if (-not (Get-ItemPropertyValue -Path $CertificateRequestPath -Name 'Length')) {
    throw "New-CertificateRequest created 0-length CertificateRequest at $CertificateRequestPath"
  }
}
else {
  throw "New-CertificateRequest failed to create the CertificateRequest at $CertificateRequestPath"
}


# print out the certificate request details
#openssl req -text -in $CertificateRequestPath -noout


# Sign the SSL Certificate Request with the CA Certificate
$CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']] $global:settings[$global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']]
$CertificatePath = Get-CertificateSecurityDNFilePath -DNSubject $DNSubject -BaseFileName 'WinRMHTTPSCertificate.crt' -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']]
Write-PSFMessage -Level Critical -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
      EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath
      EncryptedPrivateKeyPath     = $EncryptedPrivateKeyPath
      CertificateRequestPath      = $CertificateRequestPath
      CertificatePath             = $CertificatePath
      CACertificatePath           = $CACertificatePath
      CAEncryptedPrivateKeyPath   = $CAEncryptedPrivateKeyPath
    }))

New-SignedCertificate -CertificateRequestPath $CertificateRequestPath -CACertificatePath $CACertificatePath -CAEncryptedPrivateKeyPath $CAEncryptedPrivateKeyPath -CAEncryptionKeyPassPhrasePath $CAEncryptionKeyPassPhrasePath -ValidityPeriod 1 -ValidityPeriodUnits 'years' -CertificatePath $CertificatePath

# print out the certificate details
openssl req -x509 -text -in $CertificatePath -noout

# Get the signed certificate from the location where the openssl CA command places it
# Install the new SSL Server certificate to the Certificate Store in the LocalMachine's Personal
#$CertStoreLocation = 'cert:\LocalMachine\My'
# ToDo: error handling
#Import-Certificate -FilePath $CACertificatePath -CertStoreLocation $CertStoreLocation >$null


#}

$ValidityPeriod = 1
$ValidityPeriodUnits = 'years'

#. rotateCa -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits
