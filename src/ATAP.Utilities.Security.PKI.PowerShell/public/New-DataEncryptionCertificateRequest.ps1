function New-DataEncryptionCertificateRequest {
  <#
  .SYNOPSIS
  Materializes a Windows certreq request configuration for document encryption.
  .DESCRIPTION
  Safely replaces only the Subject and SAN fields in a reviewed template and writes the result as an explicit operator input to certreq.
  .PARAMETER Subject
  X.500 subject string.
  .PARAMETER SubjectAlternativeName
  SAN text expected by the template.
  .PARAMETER DataEncryptionCertificateRequestConfigPath
  Reviewed certreq INF template.
  .PARAMETER DataEncryptionCertificateRequestPath
  Destination INF path.
  .PARAMETER Force
  Creates a missing parent and replaces an existing file.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-DataEncryptionCertificateRequest -Subject 'CN=user, O=ATAP Foundation' -SubjectAlternativeName 'email=user@example.org' -DataEncryptionCertificateRequestConfigPath './dec.template.inf' -DataEncryptionCertificateRequestPath 'C:/secure/user.inf'
  .NOTES
  The generated INF contains identity metadata but no private key or secret.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Subject,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $SubjectAlternativeName,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string] $DataEncryptionCertificateRequestConfigPath,
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $DataEncryptionCertificateRequestPath,
    [switch] $Force
  )
  begin { $fn = 'New-DataEncryptionCertificateRequest'; $mn = 'ATAP.Utilities.Security.PKI.PowerShell' }
  process {
    if ($Subject -match '[\r\n]' -or $SubjectAlternativeName -match '[\r\n]') { throw 'Subject and SubjectAlternativeName cannot contain line breaks.' }
    $parentPath = Split-Path -Path $DataEncryptionCertificateRequestPath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
      if (-not $Force) { throw "The request parent directory does not exist: '$parentPath'. Use -Force to create it." }
      if ($PSCmdlet.ShouldProcess($parentPath, 'Create request directory')) { New-Item -ItemType Directory -Path $parentPath -Force | Out-Null }
    }
    if ((Test-Path -LiteralPath $DataEncryptionCertificateRequestPath -PathType Leaf) -and -not $Force) { throw "The request file already exists: '$DataEncryptionCertificateRequestPath'. Use -Force to replace it." }
    if ($PSCmdlet.ShouldProcess($DataEncryptionCertificateRequestPath, 'Write data-encryption request configuration')) {
      $content = Get-Content -LiteralPath $DataEncryptionCertificateRequestConfigPath -Raw
      $content = $content -replace '(?m)^Subject\s*=.*$', ('Subject = "' + $Subject.Replace('"', '\"') + '"')
      $content = $content -replace '(?m)^%szOID_SUBJECT_ALTERNATIVE_NAME%\s*=.*$', ('%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}' + $SubjectAlternativeName.Replace('"', '\"') + '"')
      Set-Content -LiteralPath $DataEncryptionCertificateRequestPath -Value $content -Encoding ascii -NoNewline -Force:$Force
      Get-Item -LiteralPath $DataEncryptionCertificateRequestPath
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace' }
}
