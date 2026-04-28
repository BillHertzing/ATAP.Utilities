function Test-ProGetServiceConfigPath {
  [CmdletBinding()]
  param ()

  Write-PSFMessage -Level Verbose -Message "Entering function: Test-ProGetServiceConfigPath"
  $serviceName = "INEDOPROGETSVC", "INEDOPROGETWEBSVC"
  $serviceNames | ForEach-Object {
    $serviceName = $_
    try {
      $service = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'"

      if (-not $service) {
        Write-PSFMessage -Level Error -Message "Service '$serviceName' not found."
        return $false
      }

      $cmdLine = $service.PathName
      if ($cmdLine -match '--config\s+\"(?<path>.+?)\"') {
        $configPath = $matches['path']

        if (Test-Path $configPath) {
          Write-PSFMessage -Level Important -Message "ProGet service $ServiceName is configured to use: $configPath"
          return $true
        }
        else {
          Write-PSFMessage -Level Error -Message "Config path specified in command line does not exist: $configPath"
          return $false
        }
      }
      else {
        Write-PSFMessage -Level Error -Message "--config parameter not found in ProGet service $ServiceName command line."
        return $false
      }
    }
    catch {
      $errorMessage = "Failed to validateProGet service $ServiceName config path. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
      throw $_
    }
    finally {
      Write-PSFMessage -Level Verbose -Message "Leaving function: Test-ProGetServiceConfigPath"
    }
  }
}
