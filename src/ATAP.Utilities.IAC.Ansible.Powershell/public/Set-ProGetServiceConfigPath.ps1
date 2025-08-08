# OBSOLETE FUNCTION
# ProGet does NOT have a -config command line option.

# Although obsolete, the code is useful in case another service needs to have it's startup command line changed

# This function is used to set the ProGet service config path for the INEDOPROGETSVC and INEDOPROGETWEBSVC services.
# It checks if the services exist, retrieves their current command line arguments, and updates the binPath to include the config path.
# It also validates the file at the config path exists and handles errors appropriately.
function Set-ProGetServiceConfigPath {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string]$ServicePath = $global:Settings[$global:configRootKeys['ProGetServiceExePathConfigRootKey']]
    , [string]$ConfigPath = "C:/Dropbox/Apps/ProGet/$env:COMPUTERNAME/ProGet.config"
  )

  Write-PSFMessage -Level Verbose -Message "Entering function: Set-ProGetServiceConfigPath"

  $serviceNames = ("INEDOPROGETSVC", "INEDOPROGETWEBSVC")

  $serviceNames | ForEach-Object {
    $serviceName = $_
    Write-PSFMessage -Level Verbose -Message "Processing service: $serviceName"

    try {
      $service = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'"
      if (-not $service) {
        $errorMessage = "service $serviceName not found"
        Write-PSFMessage -Level Error -Message $errorMessage
        throw $errorMessage
      }
      $exepath = ''
      if ($service.PathName -match '^(\".*?\")(.*)$') {
        $exePath = $matches[1]
        $arguments = $matches[2]
      }
      else {
        $parts = $service -split '\s+'
        $exePath = $parts[0]
        $arguments = $parts[1]
      }

      # until packaging works..
      . $PSScriptRoot\Test-ProGetServiceConfigPath.ps1
      $configArgument = '-config "{0}"' -f $ConfigPath
      $configArgumentRegex = '-config\s+\"(?<path>.+?)\"'
      # until packaging works..
      . $PSScriptRoot\Test-ServiceBinPath.ps1
      # ToDo: Return the matches
      $exists = Test-ServiceBinPath $serviceName $configArgumentRegex
      if (-not $exists ) {

        $newImagePath = '{0}{1} {2}' -f $exePath, $arguments, $configArgument

        if ($PSCmdlet.ShouldProcess($serviceName, "Update binPath to include config path")) {
          $result = sc.exe config $serviceName binPath= $newImagePath

          if ($result -match '\[SC\] ChangeServiceConfig SUCCESS') {
            Write-PSFMessage -Level Important -Message "Updated '$serviceName' binPath to include config argument: $configArgument"
          }
          else {
            $errorMessage = "Failed to update service config for service $serviceName. sc.exe result: $result"
            Write-PSFMessage -Level Error -Message $errorMessage
            throw $errorMessage
          }
        }
      }

      # until packaging works..
      . $PSScriptRoot\Test-ProGetServiceConfigPath.ps1
      # ToDo:expand for both service
      $exists = Test-ServiceBinPath $serviceName $configArgumentRegex

    }
    catch {
      $errorMessage = "Failed to update service '$serviceName' binPath. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
      throw $_
    }
    finally {
      Write-PSFMessage -Level Verbose -Message "Exiting function: Set-ProGetServiceConfigPath"
    }
  }
}
