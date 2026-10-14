function Get-Sha256Base16 {
  <#
  .SYNOPSIS
    Computes the SHA-256 of a string and returns it as lowercase base16.

  .DESCRIPTION
    Task 15.183.B02 extracted this from the `begin` block of Write-GatherCallRecord
    unchanged. The text is encoded UTF-8 without a BOM before hashing, because the digest
    is defined over the JCS form of the response `items` array and a BOM would change the
    bytes without changing the value.

  .PARAMETER Text
    The text to hash.

  .OUTPUTS
    [string] - 64 lowercase hexadecimal characters.

  .EXAMPLE
    Get-Sha256Base16 -Text '[]'

    Returns 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945, the known
    constant the contract assigns to an empty `items` array.

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M). Private helper for Write-GatherCallRecord.
  #>
  param([Parameter(Mandatory = $true)][string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return -join ($hash | ForEach-Object { $_.ToString('x2') })
  } finally {
    $sha.Dispose()
  }
}
