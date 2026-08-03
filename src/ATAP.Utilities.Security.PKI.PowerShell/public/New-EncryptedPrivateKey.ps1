function New-EncryptedPrivateKey {
  <#
  .SYNOPSIS
  Creates an AES-encrypted elliptic-curve private key with OpenSSL.
  .DESCRIPTION
  Calls OpenSSL without Invoke-Expression. The passphrase is read by OpenSSL from the supplied file and is never returned or logged.
  .PARAMETER EncryptedPrivateKeyPath
  Destination PEM path.
  .PARAMETER EncryptionKeyPassPhrasePath
  Existing passphrase file readable only by the authorized operator or service identity.
  .PARAMETER ECCurve
  OpenSSL elliptic-curve name.
  .PARAMETER Force
  Allows replacement of an existing key.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-EncryptedPrivateKey -EncryptedPrivateKeyPath 'D:/offline/ca.key.pem' -EncryptionKeyPassPhrasePath 'D:/offline/ca.pass' -ECCurve prime256v1
  .NOTES
  Creating CA or signing private keys is a separately authorized live operation.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $EncryptedPrivateKeyPath,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $EncryptionKeyPassPhrasePath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateSet('prime256v1', 'secp384r1', 'secp521r1')]
    [string] $ECCurve = 'secp384r1',

    [Parameter(ValueFromPipelineByPropertyName)]
    [switch] $Force
  )

  begin {
    $fn = 'New-EncryptedPrivateKey'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    $parentPath = Split-Path -Path $EncryptedPrivateKeyPath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
      throw "The private-key parent directory does not exist: '$parentPath'."
    }
    if ((Test-Path -LiteralPath $EncryptedPrivateKeyPath -PathType Leaf) -and -not $Force) {
      throw "The encrypted private key already exists: '$EncryptedPrivateKeyPath'. Use -Force to replace it."
    }
    if (-not $PSCmdlet.ShouldProcess($EncryptedPrivateKeyPath, "Create an encrypted $ECCurve private key")) {
      return
    }

    Invoke-OpenSslCommand -Operation 'create encrypted private key' -ArgumentList @(
      'genpkey', '-quiet', '-algorithm', 'EC', '-pkeyopt', "ec_paramgen_curve:$ECCurve",
      '-aes-256-cbc', '-pass', "file:$EncryptionKeyPassPhrasePath", '-out', $EncryptedPrivateKeyPath
    ) | Out-Null
    Get-Item -LiteralPath $EncryptedPrivateKeyPath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
