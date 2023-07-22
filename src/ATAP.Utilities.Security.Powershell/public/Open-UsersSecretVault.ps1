#############################################################################
#region  Open-UsersSecretVault
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
Function  Open-UsersSecretVault {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultName
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultDescription
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateSet('SecretManagement.Keepass', 'Microsoft.PowerShell.SecretStore')]
    [string] $SecretVaultModuleName
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultEncryptionKeyFilePath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultEncryptedPasswordFilePath
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $false, ParameterSetName = 'KeePass'  )]
    [ValidateNotNullOrEmpty()]
    [string] $SecretVaultPathToKeePassDB
    , [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true )]
    $PasswordTimeout
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
    # further Validation of input parameters
    if (-not $(Test-Path $SecretVaultEncryptionKeyFilePath -PathType Leaf)) {
      $message = "SecretVaultEncryptionKeyFilePath: $SecretVaultEncryptionKeyFilePath not found"
      Write-PSFMessage -Level Error -Message $message
      throw $message
    }
    if (-not $(Test-Path $SecretVaultPathToKeePassDB -PathType Leaf)) {
      $message = "SecretVaultPathToKeePassDB: $SecretVaultPathToKeePassDB not found"
      Write-PSFMessage -Level Error -Message $message
      throw $message
    }
    if (-not $(Test-Path $SecretVaultEncryptionKeyFilePath -PathType Leaf)) {
      $message = "SecretVaultEncryptedPasswordFilePath: $SecretVaultEncryptedPasswordFilePath not found"
      Write-PSFMessage -Level Error -Message $message
      throw $message
    }
    $passwordTimeoutSecs = 0
    switch -regex ($PasswordTimeout.gettype().name) {
      'int' { if (-not  $PasswordTimeout -In 5..300) {
          $message = 'Parameter PasswordTimeout is an int but is not in the range 5..300'
          Write-PSFMessage -Level Error -Message $message
          throw $message
        }
        $passwordTimeoutSecs = $passwordTimeout
      }
      'string' { if (-not [int32]::TryParse($_, [ref]$passwordTimeoutSecs )) {
          $message = 'Parameter PasswordTimeout did not parse as an int'
          Write-PSFMessage -Level Error -Message $message
          throw $message
        }
        else {
          if (-not $passwordTimeoutSecs -In 5..300) {
            $message = 'Parameter PasswordTimeout is a string that parses as an int but is not in the range 5..300'
            Write-PSFMessage -Level Error -Message $message
            throw $message
          }
        }
        default {
          $message = 'Parameter PasswordTimeout is neither string nor int'
          Write-PSFMessage -Level Error -Message $message
          throw $message
        }
      }
    }

  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    $EncryptionKeyData = Get-Content -Encoding $Encoding -Path $SecretVaultEncryptionKeyFilePath
    $PasswordSecureString = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $SecretVaultEncryptedPasswordFilePath) -Key $EncryptionKeyData
    $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
    switch ($PSCmdlet.ParameterSetName) {
      'KeePass' { $VP += @{Path = $SecretVaultPathToKeePassDB; KeyPath = $SecretVaultEncryptionKeyFilePath } }
    }
    # Clear any previously registered secret vault
    Get-SecretVault | Unregister-SecretVault
    # register the requested SecretVault
    Register-SecretVault -Name $SecretVaultName -ModuleName $SecretVaultModuleName -VaultParameters $VP
    # unlock the requested SecretVault
    # ToDo: figure out how to capture the warnings issued when Unlock-SecretVault fails
    switch ($SecretVaultInfo['VaultModuleName']) {
      'Microsoft.PowerShell.SecretStore' {
        # ToDo: Figure out how to catch the output if it fails
        Unlock-SecretStore -Name $SecretVaultName -Password $passwordSecureStringFromPersistence
      }
      'SecretManagement.Keepass' {
        Unlock-SecretVault -Name $SecretVaultName # -Password $passwordSecureStringFromPersistence
      }
    }

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
#endregion  Open-UsersSecretVault
#############################################################################


