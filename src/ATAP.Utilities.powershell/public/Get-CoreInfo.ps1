#############################################################################
<#
.SYNOPSIS
Retrieves information about the installed .NET SDKs, runtimes, and operating system details.

.DESCRIPTION
The Get-CoreInfo function gathers and returns details about the .NET environment on the current system. It collects the installed .NET SDK and runtime versions, operating system name, version, platform, and runtime identifier (RID). This function is useful for diagnostics, environment validation, and reporting purposes.

.PARAMETER None
This function does not accept any parameters.

.INPUTS
None. You cannot pipe objects to this function.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a custom object containing .NET and OS information.

.EXAMPLE
PS> Get-CoreInfo
Returns a custom object with details about the .NET SDK, runtimes, and OS.

.EXAMPLE
PS> $coreInfo = Get-CoreInfo
PS> $coreInfo.DotNetSDKVersion
Displays the installed .NET SDK version.

.ATTRIBUTION
Based on information and techniques from Microsoft documentation and community scripts.

.LINK
https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet --info
.LINK
https://docs.microsoft.com/en-us/powershell/

.SCM
$Id$
#>
Function Get-CoreInfo {
  param (
  )

  BEGIN {
    $message = "Starting Get-CoreInfo $($MyInvocation.MyCommand)"
    Write-PSFMessage -Level Important -Message $message -Tag 'Trace', 'Get-CoreInfo'
    # ToDo: rework default/environment/commandline values for $path
    $defaultInstalledPath = '/usr/share/dotnet' # Linux and MacOS
    $defaultInstalledPath = 'IDontKnow' # Windows 32 on a 64-bit OS See DotNet_Root(x86)
    $defaultInstalledPath = 'C:\Program Files\dotnet' # Windows 64
    $InstalledPath = "$env:DOTNET_ROOT" ? "$env:DOTNET_ROOT" : $defaultInstalledPath
    Write-Verbose "InstalledPath = $InstalledPath"
    # validate InstalledPath exists
    if (!(Test-Path -Path $InstalledPath)) { throw "$InstalledPath was not found, verify at least one DotNet Runtime or SDK has been installed" }
  }

  PROCESS {
    #
  }

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
      $object = New-Object -TypeName PSCustomObject -Property (@{
          'DotNetSDKVersion'     = $DotNetSDKVersion
          'DotNetCoreSDKVersion' = $DotNetCoreSDKVersion
          'OSName'               = $OSName
          'OSVersion'            = $OSVersion
          'OSPlatform'           = $OSPlatform
          'RID'                  = $RID
          'BIOSSerial'           = $bios.SerialNumber
        })

      return  $object
    } catch {
      $errorMessage = $_.Exception.Message
      Write-Host "Something went wrong`r`nError: $errorMessage"
      return ''
    }

    Write-Verbose -Message "Ending $($MyInvocation.MyCommand)"
  }
}
#############################################################################
