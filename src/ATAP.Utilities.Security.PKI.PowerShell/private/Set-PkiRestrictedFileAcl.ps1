function Set-PkiRestrictedFileAcl {
  [CmdletBinding()]
  [OutputType([System.Security.AccessControl.FileSecurity])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Path
  )

  begin {
    $fn = 'Set-PkiRestrictedFileAcl'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
  }

  process {
    if (-not $IsWindows) {
      throw 'Windows file ACL operations are supported only on Windows.'
    }

    try {
      $acl = [System.Security.AccessControl.FileSecurity]::new()
      $acl.SetAccessRuleProtection($true, $false)
      $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      foreach ($identity in @($currentIdentity, 'BUILTIN\Administrators', 'NT AUTHORITY\SYSTEM')) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
          $identity,
          [System.Security.AccessControl.FileSystemRights]::FullControl,
          [System.Security.AccessControl.AccessControlType]::Allow
        )
        $null = $acl.AddAccessRule($rule)
      }
      Set-Acl -LiteralPath $Path -AclObject $acl
      Get-Acl -LiteralPath $Path
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to restrict '$Path': $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Restricted file ACL operation completed.' -Tag 'Trace'
  }
}
