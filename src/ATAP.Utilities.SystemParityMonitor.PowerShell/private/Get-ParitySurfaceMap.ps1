function Get-ParitySurfaceMap {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object[]] $Surfaces
  )

  begin {
    $fn = 'Get-ParitySurfaceMap'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    $map = @{}
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Building parity surface lookup map.'
  }

  process {
    foreach ($surface in $Surfaces) {
      if ($null -eq $surface.Category -or $null -eq $surface.Item) {
        continue
      }

      $key = "$($surface.Category)|$($surface.Item)"
      $map[$key] = $surface
    }
  }

  end {
    $map
  }
}
