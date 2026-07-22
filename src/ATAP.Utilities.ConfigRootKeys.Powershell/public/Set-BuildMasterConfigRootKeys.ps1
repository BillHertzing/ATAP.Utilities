# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds BuildMaster pipeline and OtterScript plan key constants to $global:configRootKeys.

.DESCRIPTION
Appends the BuildMaster automation-path and endpoint configuration key constants to
the $global:configRootKeys hashtable. These keys are used throughout the codebase to
look up the BuildMaster base URL, admin API-key secret name, raft identity, and the
repo-relative and host-absolute OtterScript plan / pipeline / script folder locations
from $global:settings.

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-BuildMasterConfigRootKeys

Adds all BuildMaster key constants to $global:configRootKeys.

.EXAMPLE
Set-BuildMasterConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-BuildMasterConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Set-BuildMasterConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys first).'
      Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add BuildMaster key constants')) {
        $global:configRootKeys.Add('BuildMasterBaseUrlConfigRootKey', 'BuildMasterBaseUrl')
        $global:configRootKeys.Add('BuildMasterAdminApiKeySecretNameConfigRootKey', 'BuildMasterAdminApiKeySecretName')
        $global:configRootKeys.Add('BuildMasterDefaultRaftIdConfigRootKey', 'BuildMasterDefaultRaftId')
        $global:configRootKeys.Add('BuildMasterDefaultRaftItemTypeCodeConfigRootKey', 'BuildMasterDefaultRaftItemTypeCode')
        # these folders are relative to the repo root
        $global:configRootKeys.Add('BuildMasterFilesFolderRelativePathConfigRootKey', 'BuildMasterFilesFolderRelativePath')
        $global:configRootKeys.Add('BuildMasterPlansFolderRelativePathConfigRootKey', 'BuildMasterPlansFolderRelativePath')
        $global:configRootKeys.Add('BuildMasterPipelinesFolderRelativePathConfigRootKey', 'BuildMasterPipelinesFolderRelativePath')
        $global:configRootKeys.Add('BuildMasterScriptsFolderRelativePathConfigRootKey', 'BuildMasterScriptsFolderRelativePath')
        # absolute path of the OtterScript plans directory on this host
        $global:configRootKeys.Add('BuildMasterPlansDirectoryConfigRootKey', 'BuildMasterPlansDirectory')
        $global:configRootKeys.Add('BuildMasterCSharpPerProjectPlanPathConfigRootKey', 'BuildMasterCSharpPerProjectPlanPath')
        # reviewed map: PowerShell module name -> BuildMaster application name.
        # Consumed by Resolve-BuildMasterApplicationForModule / Start-BuildMasterModulePipelineBatch;
        # the value (a hashtable) is supplied per host in the ATAP.IAC BuildMaster host-settings fragment.
        $global:configRootKeys.Add('BuildMasterApplicationByModuleConfigRootKey', 'BuildMasterApplicationByModule')
        Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added BuildMaster key constants.'
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn"
    }
  }

  end {
    Write-ConfigRootKeysMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
