function Test-ServiceBinPath {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string]$ServiceName
    , [string]$REPattern
  )
  Write-PSFMessage -Level Verbose -Message "Entering function: Test-ServiceBinPath"
  try {
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$serviceName'"

    if (-not $service) {
      Write-PSFMessage -Level Error -Message "Service '$serviceName' not found."
      return $false
    }

    $cmdLine = $service.PathName
    return ($cmdLine -match $REPattern)
    # '--config\s+\"(?<path>.+?)\"') {
  }
  catch {
    $errorMessage = "Failed to validateProGet service $ServiceName config path. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }
  finally {
    Write-PSFMessage -Level Verbose -Message "Exiting function: Test-ProGetServiceConfigPath"
  }
  Write-PSFMessage -Level Verbose -Message "Exiting function: Test-ServiceBinPath"
}
