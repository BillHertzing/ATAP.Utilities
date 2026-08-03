function New-EncryptedPasswordFile {
  <#
  .SYNOPSIS
  Encrypts a SecureString with an explicit AES key file.
  .DESCRIPTION
  Reads a Base64 key created by New-RandomEncryptionKeyToFile and writes only the encrypted SecureString payload.
  .PARAMETER PasswordSecureString
  SecureString to encrypt.
  .PARAMETER PasswordFilePath
  Destination for the encrypted payload.
  .PARAMETER EncryptionKeyFilePath
  Path to a 16, 24, or 32-byte Base64 key.
  .PARAMETER Encoding
  Text encoding for both files.
  .PARAMETER Force
  Allows replacement of an existing encrypted payload.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-EncryptedPasswordFile -PasswordSecureString $secret -PasswordFilePath 'C:/secure/value.enc' -EncryptionKeyFilePath 'C:/secure/value.key'
  .NOTES
  The key and encrypted payload must be protected and backed up separately.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [SecureString] $PasswordSecureString,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $PasswordFilePath,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $EncryptionKeyFilePath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateSet('ascii', 'utf8', 'utf8BOM')]
    [string] $Encoding = 'utf8',

    [Parameter(ValueFromPipelineByPropertyName)]
    [switch] $Force
  )

  begin {
    $fn = 'New-EncryptedPasswordFile'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    $parentPath = Split-Path -Path $PasswordFilePath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
      throw "The encrypted-password parent directory does not exist: '$parentPath'."
    }
    if ((Test-Path -LiteralPath $PasswordFilePath -PathType Leaf) -and -not $Force) {
      throw "The encrypted password file already exists: '$PasswordFilePath'. Use -Force to replace it."
    }

    try {
      $keyBytes = [Convert]::FromBase64String((Get-Content -LiteralPath $EncryptionKeyFilePath -Raw -Encoding $Encoding).Trim())
    } catch {
      throw "EncryptionKeyFilePath does not contain a valid Base64 key: '$EncryptionKeyFilePath'."
    }
    if ($keyBytes.Length -notin @(16, 24, 32)) {
      throw "EncryptionKeyFilePath must decode to 16, 24, or 32 bytes; found $($keyBytes.Length)."
    }
    if (-not $PSCmdlet.ShouldProcess($PasswordFilePath, 'Write an encrypted SecureString payload')) {
      return
    }

    $encryptedValue = ConvertFrom-SecureString -SecureString $PasswordSecureString -Key $keyBytes
    $encryptedValue | Set-Content -LiteralPath $PasswordFilePath -Encoding $Encoding -NoNewline -Force:$Force
    Get-Item -LiteralPath $PasswordFilePath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
