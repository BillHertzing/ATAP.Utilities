<#
.SYNOPSIS
Reports whether a SecureString holds a plausibly well-formed Bitwarden Secrets Manager
machine-account access token.

.DESCRIPTION
A bws access token has the shape `0.<machine-account-uuid>.<secret>` with a trailing
base64url-ish body. Checking that shape at paste time catches the mis-paste class that a
hidden Read-Host prompt otherwise hides completely: a stale clipboard, a copied secret
*name* instead of its value, a truncated selection, or a Password Manager item id.

It is a shape check, not an authentication check. A token can match this pattern and still be
revoked. Only a live bws call proves the token works, and that is deliberately out of this
helper's scope.

The plaintext exists only inside an unmanaged BSTR, which is zeroed in the finally block, and
is never logged. Only the boolean result leaves this function.

.PARAMETER SecureValue
The SecureString to inspect. An empty SecureString returns $false.

.OUTPUTS
System.Boolean

.EXAMPLE
if (-not (Test-BWSAccessTokenFormat -SecureValue $pasted)) { throw 'That does not look like a bws token.' }

.NOTES
Private helper for Invoke-RotateSecretsATAP.
AI assisted using Powershell.instructions.md as guidelines.

.LINK
https://bitwarden.com/help/secrets-manager-cli/

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Test-BWSAccessTokenFormat {
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNull()]
    [System.Security.SecureString]$SecureValue
  )

  BEGIN {
    $fn = 'Test-BWSAccessTokenFormat'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'secret-rotation'

    # 0.<uuid>.<non-empty body>
    $tokenPattern = '^0\.[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.\S+$'
  }

  PROCESS {
    $bstr = [IntPtr]::Zero
    try {
      if ($SecureValue.Length -eq 0) { return $false }
      $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
      $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
      return [bool]($plain -match $tokenPattern)
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Test-BWSAccessTokenFormat failed. Exception: $($_.Exception.Message)" -Tag 'secret-rotation'
      throw
    }
    finally {
      if ($bstr -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn" -Tag 'secret-rotation'
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'secret-rotation'
  }
}
