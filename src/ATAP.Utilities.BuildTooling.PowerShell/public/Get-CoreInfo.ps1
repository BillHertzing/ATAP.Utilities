#############################################################################
#region Get-CoreInfo
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
Function Get-CoreInfo {
  #region FunctionParameters
  param (
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    # ToDo: rework default/environment/commandline values for $path
    $defaultInstalledPath = "/usr/share/dotnet" # Linux and MacOS
    $defaultInstalledPath = "IDontKnow" # Windows 32 on a 64-bit OS See DotNet_Root(x86)
    $defaultInstalledPath = "C:\Program Files\dotnet" # Windows 64
    $InstalledPath = "$env:DOTNET_ROOT" ? "$env:DOTNET_ROOT" : $defaultInstalledPath
    Write-Verbose "InstalledPath = $InstalledPath"
    # validate InstalledPath exists
    if (!(Test-Path -Path $InstalledPath)) { throw "$InstalledPath was not found, verify at least one DotNet Runtime or SDK has been installed" }
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
      try {

        [Collections.Generic.List[string]] $info = dotnet --info

        # the line after the line containing this string holds the DotNet version
        $DotNetSDKVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '.NET SDK (reflecting any global.json):' } ) + 1
        # to the right of the colon and trimmed
        $DotNetSDKVersion = (($info[$DotNetSDKVersionLineIndex]).Split(':')[1]).Trim()

        # the line after the line containing this string holds the DotNet Core version
        $DotNetCoreSDKVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '.NET Core SDK (reflecting any global.json):' } ) + 1
        # to the right of the colon and trimmed
        $DotNetCoreSDKVersion = (($info[$DotNetCoreSDKVersionLineIndex]).Split(':')[1]).Trim()

        $OSVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+OS\s+Version:\s+' } )
        $OSVersion = (($info[$OSVersionLineIndex]).Split(':')[1]).Trim()
        $OSNameLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+OS\s+Name:\s+' } )
        $OSName = (($info[$OSNameLineIndex]).Split(':')[1]).Trim()
        $OSPlatformLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+OS\s+Platform:\s+' } )
        $OSPlatform = (($info[$OSPlatformLineIndex]).Split(':')[1]).Trim()
        $RIDLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -match '^\s+RID:\s+' } )
        $RID = (($info[$RIDLineIndex]).Split(':')[1]).Trim()

        # the lines after the line containing this string holds the installed runtimes
        $DotNetCoreSDKVersionLineIndex = $info.FindIndex( { $args[0].ToString().ToLower() -like '.NET Core runtimes installed:' } ) + 1
        # ToDo: Include the list of DotNet sdk s and the list of DotNet runtimes installed
        # ToDo: validate the information returned byt dotnet --info matches the subdirectories  found on disk
        $runtimes = (Get-ChildItem "$env:programfiles/dotnet/shared/Microsoft.NETCore.App").Name | Out-String
        $object = New-Object -TypeName pscustomobject -Property (@{
            'DotNetSDKVersion'     = $DotNetSDKVersion;
            'DotNetCoreSDKVersion' = $DotNetCoreSDKVersion;
            'OSName'               = $OSName;
            'OSVersion'            = $OSVersion;
            'OSPlatform'           = $OSPlatform;
            'RID'                  = $RID;
            'BIOSSerial'           = $bios.SerialNumber
          })

        return  $object
      }
      catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Something went wrong`r`nError: $errorMessage"
        return ''
      }

    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Get-CoreInfo
#############################################################################
