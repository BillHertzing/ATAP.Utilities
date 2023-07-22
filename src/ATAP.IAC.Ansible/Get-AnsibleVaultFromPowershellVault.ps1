<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function Get-AnsibleVaultFromPowershellVault {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  Param (
    # Param1 help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $PowershellVaultName,

    # Param2 help description
    [Parameter(ParameterSetName = 'Parameter Set 1')]
    [AllowNull()]
    [AllowEmptyCollection()]
    [AllowEmptyString()]
    [ValidateScript({ $true })]
    [ValidateRange(0, 5)]
    [int]
    $Param2,

    # Param3 help description
    [Parameter(ParameterSetName = 'Another Parameter Set')]
    [ValidatePattern('[a-z]*')]
    [ValidateLength(0, 15)]
    [String]
    $Param3
  )

  BEGIN {
    $DebugPreference = 'Continue'
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    $secretsFromGlobal = @{}
    $dictionary = @{
      $global:configRootKeys['SecretVaultNameConfigRootKey' ]                     = $global:settings[$global:configRootKeys['SecretVaultNameConfigRootKey' ]]
      $global:configRootKeys['SecretVaultModuleNameConfigRootKey' ]      = $global:settings[$global:configRootKeys['SecretVaultModuleNameConfigRootKey' ]]
      $global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']           = $global:settings[$global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']]
      $global:configRootKeys['SecretVaultEncryptionKeyFilePathConfigRootKey']               = $global:settings[$global:configRootKeys['SecretVaultEncryptionKeyFilePathConfigRootKey']]
      $global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey'] = $global:settings[$global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey']]
      'DataEncryptionCertificateThumbprint'                                       = ''
    }


    # If no argument provided, get from global:settings
    $keys =  [System.Collections.ArrayList]$($Global:Settings.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
      if ($keys[$i] -match 'Secret') {
        $secretsFromGlobal.Add($keys[$i],$Global:Settings[$keys[$i]])
      }
    }

    # Validate provided argument
    $keys = @('SecretSecretVaultModuleName','SecretVaultDescription','SecretVaultEncryptedPasswordFilePath','SecretVaultEncryptionKeyFilePath','SecretVaultKeySizeInt','SecretVaultName','SecretVaultPasswordTimeout','SecretVaultPathToKeePassDB')



    if ($DebugPreference -eq 'Continue') {
      $secretsString = Write-HashIndented $secretsFromGlobal
       Write-PSFMessage -Level Debug -Message "vaultFromGlobal =  $secretsString" -Tag 'Trace'
    }

    # Ensure the user's secret vault is available and ready
    . '/mnt/c/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Security.Powershell/public/Get-UsersSecretVaultInfo.ps1'
    . '/mnt/c/Dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Security.Powershell/public/Unlock-UsersSecretVault.ps1'
    Get-UsersSecretVaultInfo
    Unlock-UsersSecretVault
    Test-SecretVault
  }

  PROCESS {
    if ($pscmdlet.ShouldProcess('Target', 'Operation')) {
      # This runs in Linux on WSL2
      # validate the Powershell vault is open
      # loop over the structured input dictionary
      # for every Host
      #   create the host-specific vault
      #      ansible host-specific Vault Path
      #      Create Vault
      #      Permissions ansible host-specific Vault Path
      #      Permissions Vault
      #   for every host-specific secret
      #    copy the key and value to the ansible host-specific vault file
      #      Powershell Vault Key Name
      #      Powershell Vault Key Value [SecureString]
      #      ansible host-specific Key Name
      #      set the value of the ansible host-specific Key Name in the host-specific vault


      # Copy every specified

    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
