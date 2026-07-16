function ConvertTo-ParityPackageName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name
  )

  begin {
    $fn = 'ConvertTo-ParityPackageName'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Normalizing package name '$Name'."
  }

  process {
    ($Name.Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '^-|-$', ''
  }

  end {
  }
}
