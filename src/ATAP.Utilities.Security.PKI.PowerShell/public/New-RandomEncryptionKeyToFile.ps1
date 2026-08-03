function New-RandomEncryptionKeyToFile {
  <#
  .SYNOPSIS
  Creates a cryptographically random key file.
  .DESCRIPTION
  Writes 16, 24, or 32 random bytes as Base64 text. The destination is never overwritten unless -Force is supplied.
  .PARAMETER KeyFilePath
  Destination path for the key file.
  .PARAMETER KeySizeInt
  Key size in bytes.
  .PARAMETER Encoding
  Text encoding used for the Base64 payload.
  .PARAMETER Force
  Allows replacement of an existing file.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-RandomEncryptionKeyToFile -KeyFilePath 'C:/secure/vault.key' -KeySizeInt 32
  .NOTES
  Restrict the destination ACL before use. The key file is secret material.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [Alias('Path', 'KeyFile')]
    [ValidateNotNullOrEmpty()]
    [string] $KeyFilePath,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateSet(16, 24, 32)]
    [int] $KeySizeInt,

    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateSet('ascii', 'utf8', 'utf8BOM')]
    [string] $Encoding = 'utf8',

    [Parameter(ValueFromPipelineByPropertyName)]
    [switch] $Force
  )

  begin {
    $fn = 'New-RandomEncryptionKeyToFile'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    $parentPath = Split-Path -Path $KeyFilePath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
      throw "The key-file parent directory does not exist: '$parentPath'."
    }
    if ((Test-Path -LiteralPath $KeyFilePath -PathType Leaf) -and -not $Force) {
      throw "The key file already exists: '$KeyFilePath'. Use -Force to replace it."
    }
    if (-not $PSCmdlet.ShouldProcess($KeyFilePath, "Write a new $KeySizeInt-byte encryption key")) {
      return
    }

    $keyBytes = [byte[]]::new($KeySizeInt)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($keyBytes)
    [Convert]::ToBase64String($keyBytes) | Set-Content -LiteralPath $KeyFilePath -Encoding $Encoding -NoNewline -Force:$Force
    Get-Item -LiteralPath $KeyFilePath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
