function Set-InedoServicesDependency {
  <#
  .SYNOPSIS
    Ensures both Inedo services (ProGet and BuildMaster) depend on SQL Server before starting.
  .DESCRIPTION
    Sets the Windows service dependency for INEDOPROGETSVC and INEDOBMSVC so both services
    start after MSSQL$PRODUCTION. Idempotent — skips any service that already has the dependency.
  .OUTPUTS
    None. Writes status via Write-PSFMessage.
  .EXAMPLE
    Set-InedoServicesDependency
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Set-ServiceLogonAccount.ps1
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param ()

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'

    $sqlServiceName = 'MSSQL$PRODUCTION'
    $serviceNames = @('INEDOPROGETSVC', 'INEDOBMSVC')
  }

  process {
    foreach ($serviceName in $serviceNames) {
      try {
        $null = Get-Service -Name $serviceName -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Service '$serviceName' does not exist. Exception: $($_.Exception.Message)" -Exception $_.Exception
        throw $_
      }

      try {
        $currentConfig = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName").DependOnService

        if ($currentConfig -contains $sqlServiceName) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "'$serviceName' already depends on '$sqlServiceName'. No changes made."
        } else {
          if ($PSCmdlet.ShouldProcess($serviceName, "Add dependency on $sqlServiceName")) {
            $newDependencies = if ($currentConfig) { $currentConfig + $sqlServiceName } else { @($sqlServiceName) }
            sc.exe config $serviceName depend= ($newDependencies -join ',') | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Updated '$serviceName' to depend on '$sqlServiceName'."
          }
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to set dependency for '$serviceName'. Exception: $($_.Exception.Message)" -Exception $_.Exception
        throw $_
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
