#####################################
#region Unlock-UsersSecretVault
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
Function Unlock-UsersSecretVault {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName ='DefaultParameterSetNameReplacementPattern'  )]
  param (
    [parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    # script to validate all needed keys are present in the hashtable
    # ToDo validate that all data fields resolve to valid paths, integers, and thumbprints
    [ValidateScript({
      $d = $_
       $s = $true
       ($global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey'], $global:configRootKeys['SecretVaultEncryptionKeyFilePathConfigRootKey'], $global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey'] ,$global:configRootKeys['SecretVaultNameConfigRootKey' ] ,$global:configRootKeys['SecretVaultModuleNameConfigRootKey' ] ,$global:configRootKeys['SecretVaultDescriptionConfigRootKey' ],$global:configRootKeys['SecretVaultKeySizeIntConfigRootKey' ], $global:configRootKeys['SecretVaultPasswordTimeoutConfigRootKey' ])|
 ForEach-Object{$s = $s -and $d.ContainsKey($_) }; $s})]
    [System.Collections.IDictionary] $SecretVaultInfo
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
    # ToDo Add switch parameter to use Data Encryption Certificate
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    # $DebugPreference = 'SilentlyContinue'
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # Write-PSFMessage -Level Debug -Message "SecretVaultInfo = $(Write-HashIndented $SecretVaultInfo 0 2)"
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {  }
  #endregion ProcessBlock
  #region EndBlock
  END {
    # Todo: Convert the EncryptedPassword to a SecureString using the Data Encryption Certificate as identified by the Thumbprint in the SecretVaultInfo
    # $passwordSecureString = ConvertTo-SecureString -String $(Unprotect-CmsMessage -Content $($SecretVaultInfo['EncryptedPassword']) -To $SecretVaultInfo['Thumbprint']) -AsPlainText -Force
    $EncryptionKeyData = $null
    $passwordSecureStringFromPersistence = $null
    $success = $null
    #Invoke-PSFProtectedCommand -Action "'Unlock the SecretStore" -ScriptBlock {
      $EncryptionKeyData = Get-Content -Encoding $Encoding -Path $SecretVaultInfo[$global:configRootKeys['SecretVaultEncryptionKeyFilePathConfigRootKey']]
      $passwordSecureStringFromPersistence = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $SecretVaultInfo['EncryptedPasswordFilePath']) -Key $EncryptionKeyData
      switch ($SecretVaultInfo['VaultModuleName']) {
        'Microsoft.PowerShell.SecretStore' {
          # ToDo: Figure out how to catch the output if it fails
          Unlock-SecretStore -Name $SecretVaultInfo['VaultName'] -Password $passwordSecureStringFromPersistence
        }
        'SecretManagement.Keepass' {
          Unlock-SecretVault -Name $SecretVaultInfo['VaultName'] -Password $passwordSecureStringFromPersistence
        }
      }
      # return the result of Test-SecretVault
      $success = Test-SecretVault -Name $SecretVaultInfo['VaultName']

    #} -EnableException $true

    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $success
  }
  #endregion EndBlock
}
#endregion Unlock-UsersSecretVault
#####################################


