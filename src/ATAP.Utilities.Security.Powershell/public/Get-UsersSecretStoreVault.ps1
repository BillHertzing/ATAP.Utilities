#############################################################################
#region Get-UsersSecretStoreVault
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
Function Get-UsersSecretStoreVault {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultName
    ,[parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultDescription
    ,[parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateSet('SecretManagement.Keepass','Microsoft.PowerShell.SecretStore')]
    [string] $ExtensionVaultModuleName
    ,[parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $KeyFilePath
    ,[parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $EncryptedPasswordFilePath
    ,[parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateRange(5, 300)]
    [string] $PasswordTimeout
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $false, ParameterSetName = 'KeePass'  )]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $PathToKeePassDB
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $Force
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    $EncryptionKeyData = Get-Content -Encoding $Encoding -Path $KeyFilePath
    $PasswordSecureString = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $EncryptedPasswordFilePath) -Key $EncryptionKeyData
    $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
    switch ($PSCmdlet.ParameterSetName) {
      'KeePass' {$VP += @{Path = $PathToKeePassDB; KeyPath = $KeyFilePath }}
    }
  # Clear any previously registered secret vault
  Get-SecretVault | Unregister-SecretVault
  # register the requested SecretVault
  Register-SecretVault -Name $SecretVaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
  # unlock the requested SecretVault
  # ToDo: figure out how to capture the warnings issued when Unlock-SecretVault fails

  Unlock-SecretStore -Name $SecretVaultName -Password $PasswordSecureString
  # ToDo: figure out how to capture the warnings issued when Test-SecretVault fails
  $success = Test-SecretVault -Name $SecretVaultName
  if (! $Success) {
    Write-PSFMessage -Level Error -Message "Could not unlock SecretVault $SecretvaultName" -Tag 'Security'
    throw "Could not unlock SecretVault $SecretvaultName"
  }

    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion Get-UsersSecretStoreVault
#############################################################################


