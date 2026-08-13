function Get-ParitySurfaceCoverageFindings {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [object[]] $Surfaces,

    [Parameter(Mandatory = $true)]
    [hashtable] $ExpectedSurfaceMinimumCounts,

    [string] $HostName
  )

  begin {
    $fn = 'Get-ParitySurfaceCoverageFindings'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Evaluating parity surface coverage.'
  }

  process {
    if ($ExpectedSurfaceMinimumCounts.Count -eq 0) {
      throw 'ExpectedSurfaceMinimumCounts must contain at least one category.'
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($expectedCategory in @($ExpectedSurfaceMinimumCounts.Keys | Sort-Object)) {
      if ([string]::IsNullOrWhiteSpace([string]$expectedCategory)) {
        throw 'Expected surface minimum category keys must be non-empty.'
      }

      $minimumCount = 0
      if (-not [int]::TryParse([string]$ExpectedSurfaceMinimumCounts[$expectedCategory], [ref]$minimumCount) -or $minimumCount -lt 1) {
        throw "Expected minimum count for category '$expectedCategory' must be at least one."
      }

      $actualCount = @($Surfaces | Where-Object { $_.Category -eq $expectedCategory }).Count
      if ($actualCount -lt $minimumCount) {
        $findings.Add([pscustomobject]@{
            HostName = $HostName
            Category = [string]$expectedCategory
            Item = [string]$expectedCategory
            Classification = if ($actualCount -eq 0) { 'Missing' } else { 'Thin' }
            ActualCount = $actualCount
            ExpectedMinimumCount = $minimumCount
          })
      }
    }

    foreach ($surface in @($Surfaces | Where-Object {
          [string]$_.Value -match '^AuditError=' -or [string]$_.Item -match '(^|/)AuditError$'
        })) {
      $findings.Add([pscustomobject]@{
          HostName = $HostName
          Category = [string]$surface.Category
          Item = [string]$surface.Item
          Classification = 'AuditError'
          ActualCount = 1
          ExpectedMinimumCount = 1
        })
    }

    @($findings)
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed parity surface coverage evaluation.'
  }
}
