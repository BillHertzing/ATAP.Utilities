function Grant-PkiPrivateKeyReadAccess {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Principal
  )

  begin {
    $fn = 'Grant-PkiPrivateKeyReadAccess'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
  }

  process {
    if (-not $IsWindows) {
      throw 'Windows private-key ACL operations are supported only on Windows.'
    }
    if (-not $Certificate.HasPrivateKey) {
      throw "Certificate '$($Certificate.Thumbprint)' has no private key."
    }

    $privateKey = $null
    try {
      $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
      if ($null -eq $privateKey) {
        throw "Certificate '$($Certificate.Thumbprint)' does not have an RSA private key."
      }

      if ($privateKey.GetType().FullName -eq 'System.Security.Cryptography.RSACryptoServiceProvider') {
        $privateKeyPath = Join-Path $env:ProgramData "Microsoft\Crypto\RSA\MachineKeys\$($privateKey.CspKeyContainerInfo.UniqueKeyContainerName)"
      } elseif ($privateKey.GetType().FullName -eq 'System.Security.Cryptography.RSACng') {
        $privateKeyCandidates = @(
          (Join-Path $env:ProgramData "Microsoft\Crypto\Keys\$($privateKey.Key.UniqueName)"),
          (Join-Path $env:ProgramData "Microsoft\Crypto\RSA\MachineKeys\$($privateKey.Key.UniqueName)")
        )
        $privateKeyPath = $privateKeyCandidates |
          Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
          Select-Object -First 1
      } else {
        throw "Unsupported RSA private-key provider '$($privateKey.GetType().FullName)'."
      }
    } finally {
      if ($null -ne $privateKey) { $privateKey.Dispose() }
    }

    if ([string]::IsNullOrWhiteSpace($privateKeyPath) -or -not (Test-Path -LiteralPath $privateKeyPath -PathType Leaf)) {
      throw "Private-key file was not found for certificate '$($Certificate.Thumbprint)'."
    }

    try {
      $acl = Get-Acl -LiteralPath $privateKeyPath
      foreach ($identity in $Principal) {
        $sid = [System.Security.Principal.NTAccount]::new($identity).Translate(
          [System.Security.Principal.SecurityIdentifier]
        )
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
          $sid,
          [System.Security.AccessControl.FileSystemRights]::Read,
          [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.SetAccessRule($rule)
      }
      Set-Acl -LiteralPath $privateKeyPath -AclObject $acl
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to grant private-key read access: $($_.Exception.Message)"
      throw
    }

    [PSCustomObject]@{
      Thumbprint = $Certificate.Thumbprint
      PrivateKeyPath = $privateKeyPath
      Principal = @($Principal)
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Private-key ACL operation completed.' -Tag 'Trace'
  }
}
