function New-CertificateRequest {
  <#
  .SYNOPSIS
  Creates a PKCS#10 certificate signing request with OpenSSL.
  .DESCRIPTION
  Builds an argument array from a normalized distinguished-name object and never evaluates a command string.
  .PARAMETER DistinguishedNameHash
  Object returned by New-DistinguishedNameHash.
  .PARAMETER CertificateRequestPath
  Destination CSR path.
  .PARAMETER EncryptedPrivateKeyPath
  Existing encrypted PEM private key.
  .PARAMETER EncryptionKeyPassPhrasePath
  Existing passphrase file for OpenSSL.
  .PARAMETER Force
  Allows replacement of an existing CSR.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-CertificateRequest -DistinguishedNameHash $dn -CertificateRequestPath 'C:/secure/utat01.csr' -EncryptedPrivateKeyPath 'C:/secure/utat01.key.pem' -EncryptionKeyPassPhrasePath 'C:/secure/utat01.pass'
  .NOTES
  Private keys and passphrase files must remain outside source control and evidence.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [Alias('DNHash')] [PSObject] $DistinguishedNameHash,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $CertificateRequestPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $EncryptedPrivateKeyPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $EncryptionKeyPassPhrasePath,
    [switch] $Force
  )
  begin { $fn = 'New-CertificateRequest'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    $parentPath = Split-Path -Path $CertificateRequestPath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) { throw "The CSR parent directory does not exist: '$parentPath'." }
    if ((Test-Path -LiteralPath $CertificateRequestPath -PathType Leaf) -and -not $Force) { throw "The CSR already exists: '$CertificateRequestPath'. Use -Force to replace it." }
    if ([string]::IsNullOrWhiteSpace($DistinguishedNameHash.DNAsParameter)) { throw 'DistinguishedNameHash must contain DNAsParameter.' }
    if (-not $PSCmdlet.ShouldProcess($CertificateRequestPath, "Create certificate request for '$($DistinguishedNameHash.CN)'")) { return }

    $arguments = [Collections.Generic.List[string]]::new()
    @('req', '-new', '-batch', '-sha384', '-subj', [string]$DistinguishedNameHash.DNAsParameter) | ForEach-Object { [void]$arguments.Add($_) }
    foreach ($extensionName in @('BasicConstraints', 'KeyUsage', 'ExtendedkeyUsage', 'SubjectAlternateName')) {
      $extension = [string]$DistinguishedNameHash.$extensionName
      if (-not [string]::IsNullOrWhiteSpace($extension)) {
        [void]$arguments.Add('-addext')
        [void]$arguments.Add($extension)
      }
    }
    @('-key', $EncryptedPrivateKeyPath, '-passin', "file:$EncryptionKeyPassPhrasePath", '-out', $CertificateRequestPath) | ForEach-Object { [void]$arguments.Add($_) }
    Invoke-OpenSslCommand -Operation 'create certificate signing request' -ArgumentList $arguments.ToArray() | Out-Null
    Get-Item -LiteralPath $CertificateRequestPath
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
