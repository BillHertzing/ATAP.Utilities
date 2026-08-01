#Requires -Version 7.0

function Test-SprintUrlReachable {
  <#
  .SYNOPSIS
      Private helper: HEAD-checks a single base URL for reachability.

  .DESCRIPTION
      Used by Test-SprintPrerequisites to assert the ProGet and BuildMaster base
      URLs are reachable. A null/empty URL is treated as a skipped (Ok=$true)
      check. Any HTTP status below 500 is treated as reachable (auth is not
      asserted). Never throws; always returns a [PSCustomObject].

  .NOTES
      AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [string]$Url,

    [Parameter()]
    [int]$TimeoutSeconds = 5,

    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  begin {
    $fn = 'Test-SprintUrlReachable'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    if ([string]::IsNullOrWhiteSpace($Url)) {
      return [PSCustomObject]@{
        Ok      = $true
        Detail  = "$Label base URL not supplied; reachability check skipped"
        Url     = $null
        Skipped = $true
      }
    }

    try {
      $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
      $code = [int]$response.StatusCode
      return [PSCustomObject]@{
        Ok      = ($code -lt 500)
        Detail  = "$Label HEAD $Url returned HTTP $code"
        Url     = $Url
        Skipped = $false
      }
    } catch {
      $code = $null
      if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response -and $_.Exception.Response.StatusCode) {
        $code = [int]$_.Exception.Response.StatusCode
      }
      if ($code -and $code -lt 500) {
        return [PSCustomObject]@{
          Ok      = $true
          Detail  = "$Label HEAD $Url returned HTTP $code (reachable; auth not asserted)"
          Url     = $Url
          Skipped = $false
        }
      }
      return [PSCustomObject]@{
        Ok      = $false
        Detail  = "$Label HEAD $Url failed: $($_.Exception.Message)"
        Url     = $Url
        Skipped = $false
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
