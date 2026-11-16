function Assert-ParityTrustedDirectory {
  <#
  .SYNOPSIS
    Throws unless no broad identity can write to a directory.

  .DESCRIPTION
    A dispatcher is only as trustworthy as its directory: if a broad identity could write there,
    an unelevated caller could edit the dispatcher and run code as the task's identity. This is
    the same rule ATAP.Utilities.BuildTooling.ProGet.PowerShell Register-ATAPParityScheduledTasks
    applies to C:\Program Files\ATAP\ParityDispatchers.

  .PARAMETER Path
    Directory to check.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path
  )

  begin {
    $fn = 'Assert-ParityTrustedDirectory'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
  }

  process {
    $writeRights = @(
      [System.Security.AccessControl.FileSystemRights]::WriteData
      [System.Security.AccessControl.FileSystemRights]::AppendData
      [System.Security.AccessControl.FileSystemRights]::WriteExtendedAttributes
      [System.Security.AccessControl.FileSystemRights]::WriteAttributes
      [System.Security.AccessControl.FileSystemRights]::Delete
      [System.Security.AccessControl.FileSystemRights]::TakeOwnership
      [System.Security.AccessControl.FileSystemRights]::ChangePermissions
    )
    $untrustedIdentities = @(
      'Everyone'
      'BUILTIN\Users'
      'NT AUTHORITY\Authenticated Users'
      'NT AUTHORITY\INTERACTIVE'
    )
    $offending = @((Get-Acl -LiteralPath $Path -ErrorAction Stop).Access | Where-Object {
        if ($_.AccessControlType -ne 'Allow') { return $false }
        if ($_.IdentityReference.Value -notin $untrustedIdentities) { return $false }
        foreach ($right in $writeRights) {
          if ($_.FileSystemRights.HasFlag($right)) { return $true }
        }
        return $false
      })
    if ($offending.Count -gt 0) {
      $who = ($offending | ForEach-Object { $_.IdentityReference.Value } | Sort-Object -Unique) -join ', '
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Directory '$Path' is writable by an untrusted identity ($who)."
      throw "Directory '$Path' is writable by an untrusted identity ($who); refusing to write a dispatcher there."
    }
  }

  end {
  }
}
