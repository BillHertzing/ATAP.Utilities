#############################################################################
#region Get-UsersSecretStoreInfo
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
Function Get-UsersSecretStoreInfo {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
    [ValidateScript({$($global:CanaconicalUserRoleStrings).Values.Contains($_)})]
    [string] $Role
    # ToDo: add Machine and User Parameters, but only for securityadmins
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # ToDo: add Machine and User Parameters, but only for securityadmins
    # Since most security certificates depend on the DNS-resolved HostName, and because the following method is cross-platform...
    # [How to Get a Computer Name with PowerShell](https://adamtheautomator.com/powershell-get-computer-name/)
    $hostName = ([System.Net.DNS]::GetHostByName($Null)).Hostname
    # Again to be cross-platform, use a .Net library
    # In a Domain, the prefix is the AD domain name, in a workgroup, it is the computer name, ToDo: what is the prefix in *nix or MacOS?
    # [How to Get the Current User Logged On with PowerShell (All the Ways)](https://adamtheautomator.com/how-to-get-the-current-user-logged-on-with-powershell-all-the-ways/)
    #  ToDo: does the split pattern change based on OS? Can an AD domain name contain the split-pattern?
    $MachineDomainUserNameSplitPattern = '\\'
    $userName = (((([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name) -split $MachineDomainUserNameSplitPattern))[1]
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    # ToDo: support multiple vaults, secrets specific for each machine-role and secrets per each user-role pair, minimum permissions, rotation, revocation, and disaster recovery
    $dictionary = @{
      'VaultName'                           = $global:settings[$global:configRootKeys['SecretVaultNameConfigRootKey' ]]
      'VaultModuleName'                     = $global:settings[$global:configRootKeys['SecretVaultExtensionModuleNameConfigRootKey' ]]
      'VaultPath'                           = $global:settings[$global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']]
      'KeyFilePath'                         = $global:settings[$global:configRootKeys['SecretVaultKeyFilePathConfigRootKey']]
      'EncryptedPasswordFilePath'           = $global:settings[$global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey']]
      'DataEncryptionCertificateThumbprint' = ''
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $dictionary
  }
  #endregion EndBlock
}
#endregion Get-UsersSecretStoreInfo
#############################################################################
