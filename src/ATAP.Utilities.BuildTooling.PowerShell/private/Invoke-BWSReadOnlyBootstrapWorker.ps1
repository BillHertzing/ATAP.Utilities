function Get-BWSReadOnlyBootstrapCurrentIdentityName {
  [CmdletBinding()]
  [OutputType([string])]
  param()

  [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}

function Invoke-BWSReadOnlyBootstrapWorker {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvelopePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Fa-f0-9]{40}$')]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$CredentialDirectory,

    [switch]$Force
  )

  begin {
    $fn = 'Invoke-BWSReadOnlyBootstrapWorker'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
      Import-Module -Name PSFramework -ErrorAction Stop
    }
    if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
      throw 'Required bootstrap logging dependency is unavailable.'
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Worker started.' -Tag 'bws-bootstrap'
    if (-not (Get-Command -Name 'Resolve-BWSReadOnlyBootstrapIdentity' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Resolve-BWSReadOnlyBootstrapIdentity.ps1')
    }
    if (-not (Get-Command -Name 'Initialize-BWSAccessToken' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\public\Initialize-BWSAccessToken.ps1')
    }
  }

  process {
    $expectedIdentity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName
    $canonicalCredentialDirectory = [IO.Path]::GetFullPath(
      "C:\ProgramData\ATAP\BitwardenCredentials\$($expectedIdentity.SamAccountName)")
    $CredentialDirectory = [IO.Path]::GetFullPath($CredentialDirectory)
    if ($CredentialDirectory -ne $canonicalCredentialDirectory) {
      throw 'Worker CredentialDirectory is not the canonical account path.'
    }
    $tokenFileName = '{0}_{1}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml' -f $env:COMPUTERNAME, $expectedIdentity.SamAccountName
    $tokenPath = Join-Path $CredentialDirectory $tokenFileName
    if ((Test-Path -LiteralPath $tokenPath -PathType Leaf) -and -not $Force) {
      throw 'Worker found an existing unverified ReadOnly token file without Force authorization.'
    }
    $currentWindowsIdentity = Get-BWSReadOnlyBootstrapCurrentIdentityName
    $runningIdentity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $currentWindowsIdentity
    if ($runningIdentity.AccountName -ne $expectedIdentity.AccountName) {
      throw 'BWS ReadOnly bootstrap worker is running as the wrong identity.'
    }
    if (-not (Test-Path -LiteralPath $EnvelopePath -PathType Leaf)) {
      throw 'Encrypted BWS ReadOnly bootstrap envelope is missing.'
    }

    $certificatePath = "Cert:\CurrentUser\My\$CertificateThumbprint"
    $certificate = Get-Item -LiteralPath $certificatePath -ErrorAction SilentlyContinue
    if (-not $certificate -or -not $certificate.HasPrivateKey) {
      throw 'Matching account-private document-encryption certificate is unavailable.'
    }
    $simpleName = $certificate.GetNameInfo(
      [System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
      $false)
    if ($simpleName -ne $expectedIdentity.SamAccountName) {
      throw 'Worker certificate identity does not match the approved service account.'
    }
    $now = Get-Date
    if ($certificate.NotBefore -gt $now -or $certificate.NotAfter -lt $now) {
      throw 'Worker certificate is outside its validity period.'
    }
    $documentEncryptionOid = '1.3.6.1.4.1.311.80.1'
    $ekuExtension = $certificate.Extensions |
      Where-Object { $_.Oid.Value -eq '2.5.29.37' } |
      Select-Object -First 1
    $hasDocumentEncryptionEku = $ekuExtension -and @(
      $ekuExtension.EnhancedKeyUsages | Where-Object { $_.Value -eq $documentEncryptionOid }
    ).Count -gt 0
    if (-not $hasDocumentEncryptionEku) {
      throw 'Worker certificate is not authorized for document encryption.'
    }

    $secureToken = $null
    try {
      $plaintextToken = Unprotect-CmsMessage -Path $EnvelopePath -To $certificate -ErrorAction Stop
      $secureToken = ConvertTo-SecureString -String $plaintextToken -AsPlainText -Force
      $plaintextToken = $null

      Remove-Item -LiteralPath $EnvelopePath -Force -ErrorAction Stop
      $initializeParameters = @{
        AccessToken        = $secureToken
        CredentialDirectory = $CredentialDirectory
        TokenPurpose       = 'ReadOnly'
        Confirm            = $false
      }
      $writeResult = Initialize-BWSAccessToken @initializeParameters
      if (-not $writeResult.Success) {
        throw 'ReadOnly DPAPI token write did not report success.'
      }

      [PSCustomObject]@{
        Status       = 'Provisioned'
        AccountName  = $expectedIdentity.AccountName
        ProjectName  = $expectedIdentity.ProjectName
        TokenPurpose = $expectedIdentity.TokenPurpose
        TokenPath    = $writeResult.Path
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'BWS ReadOnly bootstrap worker failed closed.' -Tag 'bws-bootstrap'
      throw 'BWS ReadOnly bootstrap worker failed closed.'
    } finally {
      $plaintextToken = $null
      $secureToken = $null
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Worker completed.' -Tag 'bws-bootstrap'
  }
}
