#############################################################################
#region Unlock-UsersSecretStore
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
Function Unlock-UsersSecretStore {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FromFile' )]
  param (
    # a Name for the vault
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Name
    , [Parameter(ParameterSetName = 'FromFile')]
    [ValidateScript({ Test-Path $_ })]
    [string] $EncryptedMasterPasswordsPath
    , [Parameter(ParameterSetName = 'FromHashTable')]
    [ValidateScript({ $_.ContainsKey('EncryptedPassword') })]
    # add script to validate all needed keys are present in the hashtable
    [System.Collections.IDictionary] $Dictionary
  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    # $DebugPreference = 'SilentlyContinue'
    Write-Debug "Starting $($MyInvocation.Mycommand)"
    Write-Debug "PsCmdlet.ParameterSetName = $($PsCmdlet.ParameterSetName)"
    $SecretStoreInfo = $null
    if ( $PsCmdlet.ParameterSetName -eq 'FromFile') {
      if (-not (Test-Path -Path $EncryptedMasterPasswordsPath)) {
        #Log('Error',"Unlock-UsersSecretStore failed, file does not exist. EncryptedMasterPasswordsPath = $EncryptedMasterPasswordsPath")
        throw "Unlock-UsersSecretStore failed, file does not exist. EncryptedMasterPasswordsPath = $EncryptedMasterPasswordsPath"
      }
      # Read the collection of SecretStoreInfo hashtable from the EncryptedMasterPasswordsPath
      $SecretStoreInfoCollection = (Get-Content -Path $EncryptedMasterPasswordsPath) | ConvertFrom-Json -AsHashtable
      # Take just the entry corresponding to the MyPersonalSecrets
      $SecretStoreInfo = $SecretStoreInfoCollection[$Name]
    }
    if ( $PsCmdlet.ParameterSetName -eq 'FromHashTable') {
      $SecretStoreInfo = $Dictionary
    }
    Write-Debug "SecretStoreInfo = $(Write-HashIndented $SecretStoreInfo 0 2)"
    $results = @{}
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    #
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    # Convert the EncryptedPassword to a SecureString using the Data Encryption Certificate as identified by the Thumbprint in the SecretStoreInfo
    if ($PSCmdlet.ShouldProcess($null, 'Unlock the SecretStore')) {
      # ToDo: wrap in try/catch if UnProtect fails
      Write-Debug "password is $(Unprotect-CmsMessage -Content $($SecretStoreInfo['EncryptedPassword']) -To $SecretStoreInfo['Thumbprint'])"
      $passwordSecureString = ConvertTo-SecureString -String $(Unprotect-CmsMessage -Content $($SecretStoreInfo['EncryptedPassword']) -To $SecretStoreInfo['Thumbprint']) -AsPlainText -Force
      #####
      $PasswordSecureString = ConvertTo-SecureString -String '2345' -AsPlainText -Force
      #####
      # Unlock the SecretStore identified as 'Name' using the SecureStringPassword
      if ($PSCmdlet.ShouldProcess($null, 'Unlock-SecretStore')) {
        try {
          Unlock-SecretStore -Password $PasswordSecureString # 2>$null # send the Error Output stream to the ol' bitbucket
        }
        catch { # if an exception ocurrs
          # handle the exception
          $where = $PSItem.InvocationInfo.PositionMessage
          $ErrorMessage = $_.Exception.Message
          $FailedItem = $_.Exception.ItemName
          #Log('Error',"Unlock-SecretStore failed with $FailedItem : $ErrorMessage at `n $where.")
          Throw "Unlock-SecretStore Threw an exception with $FailedItem : $ErrorMessage at `n $where."
        }
      }
    }
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
    # return a results object
    $results
  }
  #endregion FunctionEndBlock
}
#endregion FunctionName
#############################################################################


# Unlock the user's SecretStore for this session using an encrypted password and a data Encryption Certificate installed to the current machine
Function Unlock-UsersSecretStore {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'FromFile')]
  param (
    # a Name for the vault
    [string] $Name
    , [Parameter(ParameterSetName = 'FromFile')]
    [ValidateScript({ Test-Path $_ })]
    [string] $EncryptedMasterPasswordsPath
    , [Parameter(ParameterSetName = 'FromHashTable')]
    [ValidateScript({ $_.ContainsKey('EncryptedPassword') })]
    # add script to validate all needed keys are present in the hashtable
    [System.Collections.IDictionary] $Dictionary
  )
  BEGIN {
    Write-Debug "Starting $($MyInvocation.Mycommand)"
    Write-Debug "PsCmdlet.ParameterSetName = $($PsCmdlet.ParameterSetName)"
    $SecretStoreInfo = $null
    if ( $PsCmdlet.ParameterSetName -eq 'FromFile') {
      if (-not (Test-Path -Path $EncryptedMasterPasswordsPath)) {
        #Log('Error',"Unlock-UsersSecretStore failed, file does not exist. EncryptedMasterPasswordsPath = $EncryptedMasterPasswordsPath")
        throw "Unlock-UsersSecretStore failed, file does not exist. EncryptedMasterPasswordsPath = $EncryptedMasterPasswordsPath"
      }
      # Read the collection of SecretStoreInfo hashtable from the EncryptedMasterPasswordsPath
      $SecretStoreInfoCollection = (Get-Content -Path $EncryptedMasterPasswordsPath) | ConvertFrom-Json -AsHashtable
      # Take just the entry corresponding to the MyPersonalSecrets
      $SecretStoreInfo = $SecretStoreInfoCollection[$Name]
    }
    if ( $PsCmdlet.ParameterSetName -eq 'FromHashTable') {
      $SecretStoreInfo = $Dictionary
    }
    Write-Debug "SecretStoreInfo = $(Write-HashIndented $SecretStoreInfo 0 2)"
  }
  PROCESS {}
}
