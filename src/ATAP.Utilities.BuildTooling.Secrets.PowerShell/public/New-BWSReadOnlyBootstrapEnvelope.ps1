function New-BWSReadOnlyBootstrapEnvelope {
  <#
  .SYNOPSIS
    Creates an account-specific CMS envelope for BWS ReadOnly bootstrap.
  .DESCRIPTION
    Protects a SecureString with a caller-supplied public document-encryption
    certificate whose simple name exactly matches one of the three approved
    service accounts. Project and purpose are fixed to CI-Shared and ReadOnly.
  .PARAMETER AccountName
    Local service account. Only SvcBuildMaster, SvcProGet, and SvcSQLServer are accepted.
  .PARAMETER AccessToken
    BWS access token as SecureString. Raw string token parameters are not supported.
  .PARAMETER RecipientCertificatePath
    Path to the account-specific public .cer document-encryption certificate.
  .PARAMETER OutputPath
    Destination for the encrypted CMS envelope. The parent directory must exist.
  .PARAMETER Force
    Replaces an existing encrypted envelope after all policy checks pass.
  .OUTPUTS
    Redacted PSCustomObject containing account, project, purpose, path, thumbprint, and status.
  .EXAMPLE
    $token = Read-Host 'CI-Shared ReadOnly token' -AsSecureString
    $parameters = @{
      AccountName = '.\SvcProGet'
      AccessToken = $token
      RecipientCertificatePath = '.\SvcProGet.cer'
      OutputPath = '.\bootstrap.cms'
    }
    New-BWSReadOnlyBootstrapEnvelope @parameters
  .NOTES
    Does not provision certificates, private keys, grants, accounts, or tokens.
  .LINK
    https://learn.microsoft.com/powershell/module/microsoft.powershell.security/protect-cmsmessage
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountName,

    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [System.Security.SecureString]$AccessToken,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RecipientCertificatePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [switch]$Force
  )

  begin {
    $fn = 'New-BWSReadOnlyBootstrapEnvelope'
    $mn = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started.' -Tag 'bws-bootstrap'
    if (-not (Get-Command -Name 'Resolve-BWSReadOnlyBootstrapIdentity' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Resolve-BWSReadOnlyBootstrapIdentity.ps1')
    }
  }

  process {
    $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName
    $certificatePath = [IO.Path]::GetFullPath($RecipientCertificatePath)
    $envelopePath = [IO.Path]::GetFullPath($OutputPath)
    $envelopeDirectory = Split-Path -Parent $envelopePath

    if ([IO.Path]::GetExtension($certificatePath) -ne '.cer') {
      throw 'RecipientCertificatePath must reference a public .cer file.'
    }
    if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
      throw "Recipient public certificate was not found at '$certificatePath'."
    }
    if (-not (Test-Path -LiteralPath $envelopeDirectory -PathType Container)) {
      throw "Envelope parent directory was not found at '$envelopeDirectory'."
    }
    if ((Test-Path -LiteralPath $envelopePath -PathType Leaf) -and -not $Force) {
      throw "Encrypted bootstrap envelope already exists at '$envelopePath'; use -Force to replace it."
    }

    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
    try {
      $simpleName = $certificate.GetNameInfo(
        [System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
        $false)
      if ($simpleName -ne $identity.SamAccountName) {
        throw "Certificate identity '$simpleName' does not match approved account '$($identity.SamAccountName)'."
      }
      if ($certificate.HasPrivateKey) {
        throw 'RecipientCertificatePath must contain a public certificate only.'
      }
      if ((Get-Date) -lt $certificate.NotBefore -or (Get-Date) -gt $certificate.NotAfter) {
        throw 'Recipient document-encryption certificate is not currently valid.'
      }

      $documentEncryptionOid = '1.3.6.1.4.1.311.80.1'
      $ekuOids = @($certificate.Extensions |
          Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension] } |
          ForEach-Object { $_.EnhancedKeyUsages })
      if (@($ekuOids | Where-Object { $_.Value -eq $documentEncryptionOid }).Count -eq 0) {
        throw 'Recipient certificate is not authorized for document encryption.'
      }

      $result = [ordered]@{
        Status                = 'Planned'
        AccountName           = $identity.AccountName
        ProjectName           = $identity.ProjectName
        TokenPurpose          = $identity.TokenPurpose
        EnvelopePath          = $envelopePath
        CertificateThumbprint = $certificate.Thumbprint
      }
      if (-not $PSCmdlet.ShouldProcess($envelopePath, "Create CMS BWS ReadOnly bootstrap envelope for $($identity.AccountName)")) {
        return [PSCustomObject]$result
      }

      $bstr = [IntPtr]::Zero
      try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
        $plaintextToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        Protect-CmsMessage -Content $plaintextToken -To $certificate -OutFile $envelopePath -ErrorAction Stop
      } finally {
        $plaintextToken = $null
        if ($bstr -ne [IntPtr]::Zero) {
          [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
      }

      $result.Status = 'Created'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created encrypted BWS ReadOnly bootstrap envelope for '$($identity.AccountName)'." -Tag 'bws-bootstrap'
      [PSCustomObject]$result
    } finally {
      $certificate.Dispose()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed.' -Tag 'bws-bootstrap'
  }
}
