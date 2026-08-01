function Get-BrokerTaskAceMask {
  <#
  .SYNOPSIS
    Returns the access mask of the allow-ACE for a SID in a task SDDL, or $null if absent.

  .DESCRIPTION
    Windows does not store the SDDL a caller supplies. It maps generic rights to a specific
    access mask and rewrites the DACL in canonical order, so an ACE submitted as
    (A;;GRGX;;;<sid>) comes back as e.g. (A;;0x1200a9;;;<sid>) in a different position.
    Any check that string-matches the submitted ACE therefore reports a false negative on a
    grant that actually succeeded. Locate the ACE by SID and inspect its mask instead.

  .PARAMETER Sddl
    Security descriptor string as returned by IRegisteredTask.GetSecurityDescriptor.

  .PARAMETER Sid
    SID whose ACE to find.

  .OUTPUTS
    [string] the mask token (e.g. '0x1200a9', 'GRGX', 'FA'), or $null.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string] $Sddl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Sid
  )

  begin {
    $fn = 'Get-BrokerTaskAceMask'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Locating ACE for SID '$Sid'."
  }

  process {
    if ([string]::IsNullOrWhiteSpace($Sddl)) { return $null }
    if ($Sddl -match "\(A;[^;]*;([^;]+);;;$([regex]::Escape($Sid))\)") { return $Matches[1] }
    return $null
  }

  end {
  }
}
