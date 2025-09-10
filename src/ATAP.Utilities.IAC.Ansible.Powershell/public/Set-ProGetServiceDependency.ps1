function Set-ProGetServiceDependency {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param ()

  Write-PSFMessage -Level Verbose -Message "Entering function: Set-ProGetServiceDependency"

  $progetServiceName = "INEDOPROGETSVC"
  $sqlServiceName = "MSSQL`$PRODUCTION"

  try {
    $progetService = Get-Service -Name $progetServiceName -ErrorAction Stop
  }
  catch {
    $errorMessage = "ProGet service '$progetServiceName' does not exist. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }

  try {
    $currentConfig = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$progetServiceName").DependOnService

    if ($currentConfig -contains $sqlServiceName) {
      Write-PSFMessage -Level Important -Message "'$progetServiceName' already depends on '$sqlServiceName'. No changes made."
    }
    else {
      if ($PSCmdlet.ShouldProcess("$progetServiceName", "Add dependency on $sqlServiceName")) {
        $newDependencies = if ($currentConfig) { $currentConfig + $sqlServiceName } else { @($sqlServiceName) }
        sc.exe config $progetServiceName depend= ($newDependencies -join ",") | Out-Null
        Write-PSFMessage -Level Important -Message "Updated '$progetServiceName' to depend on '$sqlServiceName'."
      }
    }
  }
  catch {
    $errorMessage = "Failed to check or set service dependency for '$progetServiceName'. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }
  finally {
    Write-PSFMessage -Level Verbose -Message "Leaving function: Set-ProGetServiceDependency"
  }
}
