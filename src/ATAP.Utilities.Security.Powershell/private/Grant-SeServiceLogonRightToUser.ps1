#############################################################################
#region Grant-SeServiceLogonRightToUser
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Path
  Specifies the path where searching should start. May be a string or an array in the form (p1[,p2][,p3]...)
.PARAMETER FileNamePattern
  Specifies the regex pattern to match filenames against. May be a string or an array in the form (r1[,r2][,r3]...)

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
[StackOverflow Answer](https://stackoverflow.com/questions/313831/using-powershell-how-do-i-grant-log-on-as-service-to-an-account/67010294#67010294) - [Andrew Gale](https://stackoverflow.com/users/6684130/andrew-gale)
.LINK
[Carbon](http://get-carbon.org/) -
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Grant-SeServiceLogonRightToUser {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Paramter set to suport LiteralPath
    [alias('user')]
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $true)] [ValidateNotNullOrEmpty()] [string] $Identity
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    # default values for settings
    $settings = @{
      Identity = ''
    }

    # Things to be initialized after settings are processed
    if ($Identity) { $Settings.Identity = $Identity }

    $privilege = 'SeServiceLogonRight'

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
    $success = $false
    $time = Measure-Command {
      # Crete a temporary directory
      $tmpdir = Join-Path $env:TEMP 'carbon' (Get-Random -Minimum 2000 -Maximum 3000 )
      New-Item -ItemType Directory -Path $tmpdir -WhatIf:([bool]$WhatIfPreference.IsPresent)
      # ToDo: test write privelages
      nuget install Carbon -OutputDirectory $tmpdir
      # Cafrbon cones with both coreclr and full clr
      # ToDo: Argument specifying which to use?
      # harcode full. This technique will probably not work with Linux systems, so not gonna try core
      $CarbonDllPath = Get-ChildItem -r $tmpdir | Where-Object -Property fullname -Match 'fullclr\\carbon\.dll$'
      if ($PSCmdlet.ShouldProcess($Settings.Identity, "[Reflection.Assembly]::LoadFile($CarbonDllPath)")) {
        # Todo: wrap in a try catch
        [Reflection.Assembly]::LoadFile($CarbonDllPath)
      }
      if ($PSCmdlet.ShouldProcess($Settings.Identity, "[Carbon.Security.Privilege]::GrantPrivileges($Settings.Identity, $privilege)")) {
        # Todo: wrap in a try catch
        [Carbon.Security.Privilege]::GrantPrivileges($Settings.Identity, $privilege)
      }
      # even if there is an exception, remove the tmpdir. make sure that WhiF is honored
      Remove-Item -Recurse -Force $tmpdir -ErrorAction 'SilentlyContinue' -WhatIf:([bool]$WhatIfPreference.IsPresent) -Verbose:$Verbosepreference
      # ToDo: Fix $success
      $success = $true
    }
    $OutObj = [PSCustomObject]@{
      Success = $success # sort according to sort requested
      Time    = $time
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
    return $OutObj
  }
  #endregion FunctionEndBlock
}
#endregion Grant-SeServiceLogonRightToUser
#############################################################################
