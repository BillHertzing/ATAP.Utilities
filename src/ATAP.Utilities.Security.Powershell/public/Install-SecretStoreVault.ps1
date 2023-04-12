#############################################################################
#region Install-SecretStoreVault
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Install-SecretStoreVault {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'BuiltIn')]
  param (
    # a Name for the vault
    [string] $Name
    # a Description for the vault
    , [string] $Description
    # The SecretManagement vault extension for the vault
    , [ValidateScript({ Get-InstalledModule -Name $_ })]
    [string] $ExtensionVaultModuleName
    , [Parameter(ParameterSetName = 'KeePass')]
    [ValidateScript({ Test-Path $_ })]
    [string] $PathToKeePassDB
    # a Subject for the DataEncryptionCertificateRequest
    , [string] $Subject
    # a SAN for the DataEncryptionCertificateRequest
    , [string] $SubjectAlternativeName
    # a template for the DataEncryptionCertificateRequest
    , [string] $DataEncryptionCertificateRequestConfigPath
    # A secure place for creating the DataEncryptionCertificateRequest and the DataEncryptionCertificate
    , [ValidateScript({ Test-Path $_ })]
    [string] $SecureTempBasePath
    , [string] $DataEncryptionCertificateRequestFilenameTemplate
    , [string] $DataEncryptionCertificateFilenameTemplate
    # Todo: CertificateValidityPeriodUnits, CertificateValidityPeriod
    # A place to persist the encryption key
    , [string] $KeyFilePath
    # Number of bytes in the key
    , [ValidateSet(16, 24, 32)]
    [int16] $KeySizeInt
    # A place to persist the MasterKey for this specific vault
    , [string] $EncryptedPasswordFilePath
    # a Secure-String password for the vault
    , [SecureString] $PasswordSecureString
    # a password timeout for the vault in seconds
    , [int32] $PasswordTimeout
    # Force the creation of the DEC certificate if one exists, overwrite the KeyFilePath if one exists
    , [switch] $Force
  )
  #endregion FunctionParameters
  Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

  # ToDo: write a script to be run once for each user that will setup SecretManagement
  # ToDo: write a script to be run (usually once for each user) that will setup access to specific SecretManagementExtensionVault
  # ToDo: write a script to be run on-demand that will revoke access to a specific SecretManagementExtensionVault
  # ToDo: write a script to be run once for each SecretManagementExtensionVault to create the vault
  # ToDo: put all the SecretManagememnt code into a dedicated ATAP.Utilities module

  .  $(Join-Path -Path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities', 'src', 'ATAP.Utilities.Security.Powershell', 'public', 'Install-DataEncryptionCertificate.ps1'))


  $originalPSBoundParameters = $PSBoundParameters

  # Does a SecretVault by this name already exist
  if ((Get-SecretVault).Name -eq $Name) {
    #ToDo: if -Force, Add -confirm for this operation instead of always throwing
    #Log('Error',"A SecretVault by this name already exists, remove it and retry this operation: $Name")
    Throw "A SecretVault by this name already exists, remove it and retry this operation: $Name"
  }

  # This function strings together three operations. The function's parameters are used by different operations
  #   We create a subset of the PSBoundParameters, and pass just the needed subset to the functions that perform the three operations

  # Construct a new DataEncryptionCertificateRequest file on disk
  $dataEncryptionCertificateRequestPath = Join-Path $SecureTempBasePath ($DataEncryptionCertificateRequestFilenameTemplate -f $Name)
  Write-PSFMessage -Level Debug -Message ("dataEncryptionCertificateRequestPath = $dataEncryptionCertificateRequestPath")

  $subsetPSBoundParameters = @{}
  ('Subject', 'SubjectAlternativeName', 'DataEncryptionCertificateRequestConfigPath', 'Force') | ForEach-Object { $subsetPSBoundParameters[$_] = $originalPSBoundParameters[$_] }
  New-DataEncryptionCertificateRequest -DataEncryptionCertificateRequestPath $dataEncryptionCertificateRequestPath @subsetPSBoundParameters # Pass this function's parameters to the called function
  # Construct the $dataEncryptionCertificatePath
  $dataEncryptionCertificatePath = Join-Path $SecureTempBasePath ($DataEncryptionCertificateFilenameTemplate -f $Name)
  # Install the -dataEncryptionCertificate for this user on this machine, creating the $dataEncryptionCertificatePath file
  $DataEncryptionCertificateInstallationResults = $null
  $subsetPSBoundParameters.Clear()
  ('Force') | ForEach-Object { $subsetPSBoundParameters[$_] = $originalPSBoundParameters[$_] }
  if ($PSCmdlet.ShouldProcess($null, "Install-DataEncryptionCertificate -dataEncryptionCertificateRequestPath $dataEncryptionCertificateRequestPath -dataEncryptionCertificatePath $dataEncryptionCertificatePath @subsetPSBoundParameters")) {
    try {
      $DataEncryptionCertificateInstallationResults = Install-DataEncryptionCertificate -DataEncryptionCertificateRequestPath $DataEncryptionCertificateRequestPath -dataEncryptionCertificatePath $dataEncryptionCertificatePath @subsetPSBoundParameters # Pass this function's parameters to the called function
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Install-DataEncryptionCertificate failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Install-DataEncryptionCertificate failed with $FailedItem : $ErrorMessage at `n $where."
    }
  }
  # Get the thumbprint of the certificate just installed : gci cert: -r  -DocumentEncryptionCert

  # CertReq modifies the Subject, replaceing a ';' with a ', '
  # ToDo: make this a function so it can be easily modified and updated if the behaviour of CertReq changes
  $modSubject = $Subject -replace ';', ', '

  # ToDo: ponder the possibility that there may be more than one data encryption certificate with the same Subject and SubjectAlternativeName
  $thumbprint = (Get-ChildItem -Path 'cert:/Current*/my/*' -Recurse -DocumentEncryptionCert | Where-Object { $_.Subject -match "^$modSubject$" }).Thumbprint
  Write-PSFMessage -Level Debug -Message ("thumbprint = $thumbprint")

  # Encrypt the Password
  if ($PSCmdlet.ShouldProcess($null, 'Encrypt the Password')) {
    # ToDo: wrap in a try/catch block
    $encryptedPassword = ConvertFrom-SecureString -SecureString $PasswordSecureString -AsPlainText | Protect-CmsMessage -To $Thumbprint
    Write-PSFMessage -Level Debug -Message ("encryptedPassword = $encryptedPassword")
  }

  # write the encrypted password to the $EncryptedPasswordFilePath
  $EncryptionKeyBytes = New-Object Byte[] $KeySizeInt
  [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKeyBytes)
  # ToDo: Add whatif
  #ToDo: Convert to a securestring before writing to the file
  $EncryptionKeyBytes | Out-File -FilePath $KeyFilePath

  # ToDo import KeyFilePath contents as a secure key
  $EncryptionKeyData = Get-Content $KeyFilePath
  # ToDo: Add whatif
  # ToDo change -key to -securekey
  $PasswordSecureString | ConvertFrom-SecureString -Key $EncryptionKeyData | Out-File -FilePath $EncryptedPasswordFilePath

  #####
  # $PasswordSecureString = ConvertTo-SecureString -String '2345' -AsPlainText -Force
  #####
  # Create the SecretVault using a SecretStore extension vault, and configre it, in one call
  # Use different commands based on parameterset
  $command = $null
  Write-PSFMessage -Level Debug -Message "ParameterSetName = $($PSCmdlet.ParameterSetName)"

  switch ($PSCmdlet.ParameterSetName) {
    BuiltIn {
      $command = "Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = ""$Description""; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }"
    }
    KeePass {
      $command = "Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = ""$Description""; UseMasterPassword = ""$false""; Path = ""$PathToKeePassDB"" }"
    }
  }
  Write-PSFMessage -Level Debug -Message "command = $command"
  if ($PSCmdlet.ShouldProcess($null, "Register-SecretVault -ModuleName $ExtensionVaultModuleName -VaultParameters @{Authentication='Password';Interaction='None';Password='PasswordSecureStringNotshown';PasswordTimeout=$PasswordTimeout} @subsetPSBoundParameters")) {
    try {
      # ToDo: figure out how to pass the UseMasterPassword switch paramter in a $VaultParamter's hash when run as $command via Invoke-Expression
      #Invoke-Expression $command
      switch ($PSCmdlet.ParameterSetName) {
        BuiltIn {
          Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = $Description; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
        }
        KeePass {
          Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = $Description; UseMasterPassword = $true; Path = $PathToKeePassDB }
        }
      }
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Register-SecretVault failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Register-SecretVault failed with $FailedItem : $ErrorMessage at `n $where."
    }
  }

  $SecretManagementExtensionVaultInfo = @{Name = $Name; EncryptedPassword = $encryptedPassword; Timeout = $PasswordTimeout; Thumbprint = $Thumbprint; Certificate = $dataEncryptionCertificatePath; CertificateValidityPeriod = ''; CertificateValidityPeriodUnits = '' }

  # Unlock the newly created SecretStore vault
  if ($PSCmdlet.ShouldProcess($null, "Unlock-UsersSecretStore -Name $Name -Dictionary $(Write-HashIndented $SecretManagementExtensionVaultInfo 2 2)")) {
    try {
      Unlock-UsersSecretStore -Name $Name -Dictionary $SecretManagementExtensionVaultInfo
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Unlock-UsersSecretStore failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Unlock-UsersSecretStore Threw an exception with $FailedItem : $ErrorMessage at `n $where."
    }
  }

  $SecretVaultTestPassed = $false
  if ($PSCmdlet.ShouldProcess($null, "Test-SecretVault -Name $Name")) {
    try {
      $SecretVaultTestPassed = Test-SecretVault -Name $Name 2>$null # send the Error Output stream to the ol' bitbucket
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Test-SecretVault failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Test-SecretVault Threw an exception with $FailedItem : $ErrorMessage at `n $where."
    }
    if (-not $SecretVaultTestPassed) {
      Throw "Test-SecretVault failed with $($error[0])"
    }
  }
  Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

  # Return the SecretManagementExtensionVaultInfo structure
  $SecretManagementExtensionVaultInfo
}

# [Display Subject Alternative Names of a Certificate with PowerShell](https://social.technet.microsoft.com/wiki/contents/articles/1447.display-subject-alternative-names-of-a-certificate-with-powershell.aspx)
# ((ls cert:/Current*/my/* | ?{$_.EnhancedKeyUsageList.FriendlyName -eq 'Document Encryption'}).extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)

<#
 Get-UsersSecretStoreVault -Name 'MyPersonalSecrets' `
  -Description 'Secrets For a specific user on a specific computer' `
  -ExtensionVaultModuleName 'SecretManagement.Keepass' `
  -PathToKeePassDB 'C:\KeePass\Local.ATAP.Utilities.Secrets.kdbx' `
  -Subject 'CN=Bill.hertzing@ATAPUtilities.org;OU=Supreme;O=ATAPUtilities' `
  -SubjectAlternativeName 'Email=Bill.hertzing@gmail.com' `
  -PasswordSecureString $( '1234'| ConvertTo-SecureString -AsPlainText -Force) `
  -PasswordTimeout 900 `
  -KeyFilePath 'C:/dropbox/whertzing/encryption.key'`
  -KeySizeInt 16
  -EncryptedPasswordFilePath 'C:/dropbox/whertzing/secret.encrypted'`
  -DataEncryptionCertificateRequestConfigPath  'C:\DataEncryptionCertificate.template' `
  -SecureTempBasePath $($global:settings[$global:configRootKeys['SecureTempBasePathConfigRootKey']]) `
  -DataEncryptionCertificateRequestFilenameTemplate '{0}_DataEncryptionCertificateRequest.inf' `
  -DataEncryptionCertificateFilenameTemplate '{0}_DataEncryptionCertificate.cer' `
  -Force -Whatif
#>

#endregion Security Subsystem core functions (to be moved into a seperate ATAP.Utilities module)
