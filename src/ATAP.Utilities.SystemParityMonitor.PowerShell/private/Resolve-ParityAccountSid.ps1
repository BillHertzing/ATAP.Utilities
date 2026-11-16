function Resolve-ParityAccountSid {
  <#
  .SYNOPSIS
    Resolves a Windows account name to its string SID, failing closed.

  .PARAMETER AccountName
    Account in DOMAIN\Name or HOST\Name form.

  .OUTPUTS
    String SID.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $AccountName
  )

  begin {
    $fn = 'Resolve-ParityAccountSid'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
  }

  process {
    try {
      ([System.Security.Principal.NTAccount]$AccountName).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Account '$AccountName' could not be resolved to a SID: $($_.Exception.Message)"
      throw "Account '$AccountName' could not be resolved to a SID."
    }
  }

  end {
  }
}
