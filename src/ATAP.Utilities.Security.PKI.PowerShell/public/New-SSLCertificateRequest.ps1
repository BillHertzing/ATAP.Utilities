function New-SSLCertificateRequest {
  <#
  .SYNOPSIS
  Creates a TLS server certificate signing request with required SANs and EKU.
  .DESCRIPTION
  Constructs a server-authentication descriptor and delegates CSR creation to New-CertificateRequest.
  .PARAMETER Path
  CSR destination path retained for compatibility.
  .PARAMETER CommonName
  Primary host name.
  .PARAMETER SubjectAlternativeName
  All DNS/IP identities clients use, including the common name.
  .PARAMETER Organization
  Organization represented by the certificate subject. This is mandatory because the same PKI tooling serves multiple organizations.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-SSLCertificateRequest -Path 'C:/secure/utat01.csr' -CommonName 'utat01' -Organization 'ATAP Foundation' -SubjectAlternativeName 'DNS:utat01','DNS:utat01.atap.local' -EncryptedPrivateKeyPath 'C:/secure/utat01.key.pem' -EncryptionKeyPassPhrasePath 'C:/secure/utat01.pass'
  .NOTES
  Clients must connect with a name present in SubjectAlternativeName.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory)] [Alias('CertificateRequestPath')] [string] $Path,
    [Parameter(Mandatory)] [string] $CommonName,
    [Parameter(Mandatory)] [ValidateCount(1, 100)] [string[]] $SubjectAlternativeName,
    [Parameter(Mandatory)] [string] $EncryptedPrivateKeyPath,
    [Parameter(Mandatory)] [string] $EncryptionKeyPassPhrasePath,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Organization,
    [string] $Country = 'US',
    [switch] $Force
  )
  begin { $fn = 'New-SSLCertificateRequest'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    if ("DNS:$CommonName" -notin $SubjectAlternativeName) { throw "SubjectAlternativeName must include DNS:$CommonName." }
    $dn = New-DistinguishedNameHash -CN $CommonName -O $Organization -C $Country -SubjectAlternateName $SubjectAlternativeName -ExtendedkeyUsage 'serverAuth'
    if ($PSCmdlet.ShouldProcess($Path, "Create TLS CSR for '$CommonName'")) {
      New-CertificateRequest -DistinguishedNameHash $dn -CertificateRequestPath $Path -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -Force:$Force -Confirm:$false
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
