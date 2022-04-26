#############################################################################
#region Install-ModulesPerComputer
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
function Install-ModulesPerComputer {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]] $modulesToInstall
    , [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $ComputerName
    , [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [PSCredential] $RunAs
    , [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $repositoriesToTrust = @('PSGallery')
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

    # ToDo: implement CIMSession if ComputerName is not the current computer, or if RunAs is not the current user
    # import the SecretManagement and SecretStore modules if they are not yet present
    $modulesToInstall | ForEach-Object { $moduleName = $_
      Write-PSFMessage -Level Debug -Message "Processing module named : $modulename"
      # Has it already been loaded in machine scope?
      if (-not (Get-Module -Name $moduleName -ListAvailable)) {
        Write-PSFMessage -Level Debug -Message "Module named : $modulename has NOT been installed"
        # ToDo: wrap in try/catch
        # In what repository does it exist?
        $foundModule = Find-Module $moduleName
        Write-PSFMessage -Level Debug -Message "Module named : $modulename was found in the $($foundModule.Repository) repository"

        # Is that repository trusted?
        $installationPolicy = (Get-PSRepository -Name $foundModule.Repository).InstallationPolicy
        if ( $installationPolicy -eq 'Untrusted') {
          Write-PSFMessage -Level Debug -Message ("Repository $($foundModule.Repository) is NOT trusted")
          # Todo: add feature and process flow to allow admin running this script to decide if the Repository should be trusted for this user on this machine
          if ($repositoriesToTrust.Contains($foundModule.Repository)) {
            Write-PSFMessage -Level Debug -Message ("Repository $($foundModule.Repository) is IN the repositoriesToTrust array")
            if ($PSCmdlet.ShouldProcess($foundModule.Repository , 'Set-PSRepository -Name <target> -InstallationPolicy Trusted')) {
              Set-PSRepository -Name $foundModule.Repository -InstallationPolicy Trusted
            }
          }
          else {
            Write-PSFMessage -Level Debug -Message ("Repository $($foundModule.Repository) is NOT in the repositoriesToTrust array")
          }
        }
        # ToDo: Version checking?
        # The missing module has been found and the repository is trusted
        if ($PSCmdlet.ShouldProcess(@($moduleName), 'Install-Module -Name <target> -Scope AllUsers ')) {
          Install-Module -Name $moduleName -Scope 'AllUsers'
        }
        Write-PSFMessage -Level Debug -Message "Module named : $modulename has been installed"
      }
      else {
        Write-PSFMessage -Level Debug -Message "Module named : $modulename has already been installed"
      }
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion Install-ModulesPerComputer
#############################################################################


