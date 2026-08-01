<#
.SYNOPSIS
Reports whether a URI answers a HEAD request.

.DESCRIPTION
Probe used to choose among candidate download endpoints. Any failure is reported as unreachable
rather than thrown, because the caller's job is to try the next candidate; a 404 from one endpoint
form is expected, not exceptional.

.PARAMETER Uri
Absolute URI to probe.

.PARAMETER TimeoutSec
HEAD request timeout.

.OUTPUTS
System.Boolean

.EXAMPLE
Test-ATAPModuleEndpointReachable -Uri 'http://localhost:50000/nuget/powershellget-stable/package/M/1.0.0'

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Test-ATAPModuleEndpointReachable {
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Uri,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 300)]
    [int]$TimeoutSec = 10
  )

  begin {
    $fn = 'Test-ATAPModuleEndpointReachable'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $Uri" -Tag 'WebRequestCall'
      $null = Invoke-WebRequest -Method Head -Uri $Uri -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $Uri" -Tag 'WebRequestCall'
      return $true
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Endpoint '$Uri' is not reachable: $($_.Exception.Message)" -Tag 'WebRequestCall'
      return $false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
