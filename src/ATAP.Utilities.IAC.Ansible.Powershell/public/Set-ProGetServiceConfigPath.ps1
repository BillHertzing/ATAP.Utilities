function Set-ProGetServiceConfigPath {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string]$ConfigPath = "C:/Dropbox/Apps/ProGet/$env:COMPUTERNAME/ProGet.config"
  )

  Write-PSFMessage -Level Verbose -Message "Entering function: Set-ProGetServiceConfigPath"

  $progetServiceName = "INEDOPROGETSVC"
  $hostName = $env:COMPUTERNAME
  $configPath = "C:/Dropbox/Apps/ProGet/$hostName/ProGet.config"
  $exePath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$progetServiceName").ImagePath

  try {
    if (-not (Test-Path $ConfigPath)) {
      $errorMessage = "Configuration file does not exist at path: $ConfigPath"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }

    if ($PSCmdlet.ShouldProcess("$progetServiceName", "Update ImagePath with config file path")) {
      # Quote original exe path and append --config
      $newImagePath = $exePath + " --config """ + $ConfigPath + '"'
      $result = sc.exe config $progetServiceName binPath= $newImagePath

      if ($result -match '\[SC\] ChangeServiceConfig SUCCESS') {
        Write-PSFMessage -Level Important -Message "Updated '$progetServiceName' binPath to include config path: $ConfigPath"
      }
      else {
        $errorMessage = "Failed to update service config. sc.exe result: $result"
        Write-PSFMessage -Level Error -Message $errorMessage
        throw $errorMessage
      }
    }
  }
  catch {
    $errorMessage = "Failed to update service '$progetServiceName' binPath. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }
  finally {
    Write-PSFMessage -Level Verbose -Message "Exiting function: Set-ProGetServiceConfigPath"
  }
}
