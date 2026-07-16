function Get-ParityLatestAuditSnapshot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [string] $HostName
  )

  begin {
    $fn = 'Get-ParityLatestAuditSnapshot'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finding latest audit snapshot for host '$HostName'."
  }

  process {
    Get-ChildItem -LiteralPath $StatePath -Filter "ParityAudit.$($HostName.ToLowerInvariant()).*.json" -File -ErrorAction SilentlyContinue |
      Sort-Object -Property LastWriteTimeUtc -Descending |
      Select-Object -First 1
  }

  end {
  }
}
