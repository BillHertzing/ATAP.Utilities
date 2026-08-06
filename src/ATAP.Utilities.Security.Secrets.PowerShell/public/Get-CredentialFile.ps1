<#
.SYNOPSIS
Imports a DPAPI-protected credential file.

.DESCRIPTION
Imports a credential previously written by Set-CredentialFile and verifies that the
deserialized value is a PSCredential. The file remains protected by Windows DPAPI, so
it can only be read by the same Windows identity on the same host that wrote it.

.PARAMETER Path
Absolute path to an existing credential XML file.

.OUTPUTS
System.Management.Automation.PSCredential

.EXAMPLE
Get-CredentialFile -Path 'C:\ProgramData\ATAP\Credentials\PowershellCredentials-user-host.xml'

.NOTES
This function is intentionally not imported by the machine PowerShell profile. PowerShell
module autoloading resolves it only for callers that need credential-file access.
#>
function Get-CredentialFile {
  [CmdletBinding()]
  [OutputType([System.Management.Automation.PSCredential])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not [IO.Path]::IsPathFullyQualified($_)) {
          throw "Credential file path must be absolute: '$_'."
        }
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
          throw "Credential file does not exist: '$_'."
        }
        $true
      })]
    [string]$Path
  )

  begin {
    $fn = 'Get-CredentialFile'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    try {
      $credential = Import-Clixml -LiteralPath $Path -ErrorAction Stop
      if ($credential -isnot [System.Management.Automation.PSCredential]) {
        throw "Credential file '$Path' did not deserialize to a PSCredential."
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Imported credential file '$Path'."
      return $credential
    }
    catch {
      $errorMessage = "Failed to import credential file '$Path'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
