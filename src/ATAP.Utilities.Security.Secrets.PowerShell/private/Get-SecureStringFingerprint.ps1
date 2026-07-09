<#
.SYNOPSIS
Produces a non-revealing fingerprint of a SecureString: its character length and a short
SHA-256 hex prefix.

.DESCRIPTION
Get-SecureStringFingerprint lets an operator confirm that the value they pasted into a
Read-Host -AsSecureString prompt is the value they intended, without the value ever being
echoed, logged, or written to a transcript.

A paste into -AsSecureString echoes nothing, so a truncated paste, a stale clipboard, or two
tokens entered in the wrong order are all invisible at entry. Length plus a 12-hex-character
SHA-256 prefix is enough for the operator to compare against the value shown in the Bitwarden
UI, and far too little to reconstruct the token.

The plaintext exists only inside an unmanaged BSTR, which is zeroed in the finally block. The
transient .NET string produced by PtrToStringBSTR is immutable and cannot be zeroed; it is left
to the garbage collector. This is the same exposure every ConvertFrom-SecureString caller has,
and is acceptable here because the value is already resident in the session that just read it.

.PARAMETER SecureValue
The SecureString to fingerprint. An empty SecureString yields Length 0 and an empty
Fingerprint, which callers treat as a failed paste.

.PARAMETER PrefixLength
Number of hex characters of the SHA-256 digest to return. Defaults to 12.

.OUTPUTS
PSCustomObject with Length (int) and Fingerprint (string).

.EXAMPLE
$fp = Get-SecureStringFingerprint -SecureValue $token
"length $($fp.Length), sha256:$($fp.Fingerprint)"

.NOTES
Private helper for Invoke-RotateSecretsATAP. Design decision D4.3 / D4.4 in
Documentation/Invoke-RotateSecretsATAP.DesignDecisions.md.
AI assisted using Powershell.instructions.md as guidelines.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-SecureStringFingerprint {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNull()]
    [System.Security.SecureString]$SecureValue,

    [Parameter(Mandatory = $false)]
    [ValidateRange(4, 64)]
    [int]$PrefixLength = 12
  )

  BEGIN {
    $fn = 'Get-SecureStringFingerprint'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'secret-rotation'
  }

  PROCESS {
    $bstr = [IntPtr]::Zero
    try {
      if ($SecureValue.Length -eq 0) {
        return [PSCustomObject]@{ Length = 0; Fingerprint = '' }
      }

      $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
      $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($plain)
      $sha = [System.Security.Cryptography.SHA256]::Create()
      try {
        $digest = $sha.ComputeHash($bytes)
      }
      finally {
        $sha.Dispose()
        [System.Array]::Clear($bytes, 0, $bytes.Length)
      }

      $hex = [System.BitConverter]::ToString($digest).Replace('-', '').ToLowerInvariant()
      return [PSCustomObject]@{
        Length      = $SecureValue.Length
        Fingerprint = $hex.Substring(0, [System.Math]::Min($PrefixLength, $hex.Length))
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-SecureStringFingerprint failed. Exception: $($_.Exception.Message)" -Tag 'secret-rotation'
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
