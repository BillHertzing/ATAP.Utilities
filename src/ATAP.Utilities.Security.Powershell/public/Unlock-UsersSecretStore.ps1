#####################################
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
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true )]
  param (
    [parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({$d = $_; $s = $true;  ('VaultPath','VaultName') | %{$s = $s -and $d.ContainsKey($_) }; $s})]
    # add script to validate all needed keys are present in the hashtable and that all resolve to valid paths and thumbprints
    [System.Collections.IDictionary] $SecretStoreInfo
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
    # ToDo Add switch parameter to use Data Encryption Certificate
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    # $DebugPreference = 'SilentlyContinue'
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # Write-PSFMessage -Level Debug -Message "SecretStoreInfo = $(Write-HashIndented $SecretStoreInfo 0 2)"
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {  }
  #endregion ProcessBlock
  #region EndBlock
  END {
    # Todo: Convert the EncryptedPassword to a SecureString using the Data Encryption Certificate as identified by the Thumbprint in the SecretStoreInfo
    # $passwordSecureString = ConvertTo-SecureString -String $(Unprotect-CmsMessage -Content $($SecretStoreInfo['EncryptedPassword']) -To $SecretStoreInfo['Thumbprint']) -AsPlainText -Force
    $EncryptionKeyData = $null
    $passwordSecureStringFromPersistence = $null
    $success = $null
    #Invoke-PSFProtectedCommand -Action "'Unlock the SecretStore" -ScriptBlock {
      $EncryptionKeyData = Get-Content -Encoding $Encoding -Path $SecretStoreInfo['KeyFilePath']
      $passwordSecureStringFromPersistence = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $SecretStoreInfo['EncryptedPasswordFilePath']) -Key $EncryptionKeyData
      switch ($SecretStoreInfo['VaultModuleName']) {
        'Microsoft.PowerShell.SecretStore' {
          # ToDo: Figure out how to catch the output if it fails
          Unlock-SecretStore -Name $SecretStoreInfo['VaultName'] -Password $passwordSecureStringFromPersistence
        }
        'SecretManagement.Keepass' {
          Unlock-SecretVault -Name $SecretStoreInfo['VaultName'] -Password $passwordSecureStringFromPersistence
        }
      }
      # return the result of Test-SecretVault
      $success = Test-SecretVault -Name $SecretStoreInfo['VaultName']

    #} -EnableException $true

    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $success
  }
  #endregion EndBlock
}
#endregion Name
#####################################


