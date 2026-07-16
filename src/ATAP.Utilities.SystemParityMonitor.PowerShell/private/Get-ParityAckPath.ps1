function Get-ParityAckPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $StatePath,

    [Parameter(Mandatory = $true)]
    [string] $HostName
  )

  begin {
    $fn = 'Get-ParityAckPath'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving ack path for host '$HostName'."
  }

  process {
    Join-Path $StatePath "ChangeAck.$($HostName.ToLowerInvariant()).jsonl"
  }

  end {
  }
}
