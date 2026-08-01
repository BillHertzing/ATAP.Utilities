<#
.SYNOPSIS
Compares a file's SHA-256 to an expected pin.

.DESCRIPTION
Case-insensitive ordinal comparison, so a pin recorded in either case matches. Used by
Install-ATAPModuleAllUsers to prove the downloaded package is the exact artifact that was tested
and promoted, before anything is written under Program Files.

.PARAMETER Path
File to hash.

.PARAMETER ExpectedSha256
64-character hexadecimal SHA-256 pin.

.OUTPUTS
System.Boolean

.EXAMPLE
Test-ATAPModuleFileHash -Path $nupkg -ExpectedSha256 $pin

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Test-ATAPModuleFileHash {
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedSha256
  )

  begin {
    $fn = 'Test-ATAPModuleFileHash'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $actual = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
    $matched = [string]::Equals($actual, $ExpectedSha256, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $matched) {
      # Hashes are not secrets; logging both sides makes a pin mismatch diagnosable.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "SHA-256 mismatch for '$Path': expected $ExpectedSha256, actual $actual."
    }
    return $matched
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
