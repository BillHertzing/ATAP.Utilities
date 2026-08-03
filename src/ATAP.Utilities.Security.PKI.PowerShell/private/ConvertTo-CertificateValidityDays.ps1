function ConvertTo-CertificateValidityDays {
  [CmdletBinding()]
  [OutputType([int])]
  param(
    [Parameter(Mandatory)] [ValidateRange(1, 1000)] [int] $ValidityPeriod,
    [Parameter(Mandatory)] [ValidateSet('days', 'weeks', 'years')] [string] $ValidityPeriodUnits,
    [ValidateRange(1, 365000)] [int] $MaximumDays = 365000
  )
  begin { $fn = 'ConvertTo-CertificateValidityDays'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    $days = switch ($ValidityPeriodUnits) {
      'days' { $ValidityPeriod }
      'weeks' { $ValidityPeriod * 7 }
      'years' { $ValidityPeriod * 365 }
    }
    if ($days -gt $MaximumDays) {
      throw "The requested validity of $days days exceeds the $MaximumDays-day policy maximum."
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved certificate validity to $days days." -Tag 'Trace'
    [int]$days
  }
  end {}
}
