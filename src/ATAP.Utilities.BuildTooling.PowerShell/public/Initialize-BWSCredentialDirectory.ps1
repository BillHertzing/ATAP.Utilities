<#
.SYNOPSIS
Creates and hardens the per-account Bitwarden Secrets Manager credential directory.

.DESCRIPTION
Initialize-BWSCredentialDirectory creates the folder that holds a Windows account's
DPAPI-protected BWS access-token file, then replaces inherited ACLs with explicit
FullControl grants for the owning account, SYSTEM, and local Administrators.

By default the account is the current Windows identity and the folder is
`C:\ProgramData\ATAP\BitwardenCredentials\<SamAccountName>`. Pass AccountName to prepare
the folder for another local service account from an elevated administrative session.

.PARAMETER AccountName
Windows account that should own the credential directory ACL. Defaults to the current
Windows identity, for example `UTAT022\whertzing`.

.PARAMETER CredentialRoot
Root directory for BWS credential folders. Defaults to
`C:\ProgramData\ATAP\BitwardenCredentials`.

.PARAMETER CredentialDirectory
Exact credential directory path. When omitted, the path is derived from CredentialRoot and
the account SAM name.

.OUTPUTS
PSCustomObject with Success (bool), Path (string), AccountName (string), SamAccountName
(string), and Message (string).

.EXAMPLE
Initialize-BWSCredentialDirectory

.EXAMPLE
Initialize-BWSCredentialDirectory -AccountName '.\SvcBuildmaster'

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>
function Initialize-BWSCredentialDirectory {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$AccountName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CredentialRoot = 'C:\ProgramData\ATAP\BitwardenCredentials',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory
  )

  BEGIN {
    $fn = 'Initialize-BWSCredentialDirectory'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'bws-token'

    if ([string]::IsNullOrWhiteSpace($AccountName)) {
      $AccountName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }

    $samName = ($AccountName -split '\\') | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($samName)) {
      throw 'Unable to derive a SAM account name for the BWS credential directory.'
    }

    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = Join-Path $CredentialRoot $samName
    }
  }

  PROCESS {
    try {
      if ($PSCmdlet.ShouldProcess($CredentialDirectory, "Create and ACL BWS credential directory for '$AccountName'")) {
        New-Item -ItemType Directory -Path $CredentialDirectory -Force -ErrorAction Stop | Out-Null

        $acl = Get-Acl -LiteralPath $CredentialDirectory -ErrorAction Stop
        $acl.SetAccessRuleProtection($true, $false)
        @($acl.Access) | ForEach-Object { [void]$acl.RemoveAccessRule($_) }

        $inheritFlags = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
        $propFlags = [System.Security.AccessControl.PropagationFlags]::None
        $allowType = [System.Security.AccessControl.AccessControlType]::Allow
        $fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl

        $rules = @(
          [System.Security.AccessControl.FileSystemAccessRule]::new($AccountName, $fullControl, $inheritFlags, $propFlags, $allowType),
          [System.Security.AccessControl.FileSystemAccessRule]::new('SYSTEM', $fullControl, $inheritFlags, $propFlags, $allowType),
          [System.Security.AccessControl.FileSystemAccessRule]::new('Administrators', $fullControl, $inheritFlags, $propFlags, $allowType)
        )

        foreach ($rule in $rules) {
          $acl.AddAccessRule($rule)
        }

        Set-Acl -LiteralPath $CredentialDirectory -AclObject $acl -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Initialized BWS credential directory '$CredentialDirectory'" -Tag 'bws-token'

        return [PSCustomObject]@{
          Success = $true
          Path = $CredentialDirectory
          AccountName = $AccountName
          SamAccountName = $samName
          Message = 'BWS credential directory initialized'
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Initialize-BWSCredentialDirectory failed. Exception: $($_.Exception.Message)" -Tag 'bws-token'
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'bws-token'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'bws-token'
  }
}
