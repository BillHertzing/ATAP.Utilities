function Get-ParityAuditSnapshotPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [Parameter(Mandatory = $true)]
    [datetime] $TimestampUtc
  )

  begin {
    $fn = 'Get-ParityAuditSnapshotPath'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving audit snapshot path for host '$HostName'."
  }

  process {
    $stamp = $TimestampUtc.ToString('yyyyMMddTHHmmssZ', [Globalization.CultureInfo]::InvariantCulture)
    Join-Path $StatePath "ParityAudit.$($HostName.ToLowerInvariant()).$stamp.json"
  }

  end {
  }
}
