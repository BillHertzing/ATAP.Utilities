function Restore-SqlServerBackupArtifact {
  <#
  .SYNOPSIS
  Authenticates, decrypts, and decompresses a Production ATAPUtilities backup artifact.

  .DESCRIPTION
  Verifies the complete encrypt-then-MAC container before creating any plaintext output.
  Encryption material is resolved internally through Get-SecretATAP.

  .PARAMETER InputPath
  Absolute path to an .atapenc artifact created by Protect-SqlServerBackupArtifact.

  .PARAMETER OutputPath
  Absolute destination for the restored .bak. Existing files are never overwritten.

  .PARAMETER EncryptionSecretName
  Fixed Production backup SecretName, common to every host.

  .EXAMPLE
  Restore-SqlServerBackupArtifact -InputPath 'C:\Backups\ATAPUtilities_FULL_20260912_022000.bak.gz.atapenc' -OutputPath 'C:\Restore\ATAPUtilities.bak' -Confirm:$false
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ [System.IO.Path]::IsPathFullyQualified($_) })]
    [string] $InputPath,

    [Parameter(Mandatory)]
    [ValidateScript({ [System.IO.Path]::IsPathFullyQualified($_) })]
    [string] $OutputPath,

    [Parameter()]
    [ValidateSet('dbEncryption.ATAPUtilities.Production')]
    [string] $EncryptionSecretName = 'dbEncryption.ATAPUtilities.Production'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    $headerPrefixLength = 44
    $headerLength = 76
    $passwordBytes = $null
    $derivedKeyMaterial = $null
    $encryptionKey = $null
    $authenticationKey = $null
    $temporaryOutputPath = $null

    $InputPath = [System.IO.Path]::GetFullPath($InputPath)
    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) { throw "Encrypted backup does not exist: $InputPath" }
    if (Test-Path -LiteralPath $OutputPath) { throw "OutputPath already exists; overwrite is prohibited: $OutputPath" }
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) { throw "Output directory does not exist: $outputDirectory" }
    $temporaryOutputPath = Join-Path $outputDirectory ('.{0}.{1}.restoring' -f ([System.IO.Path]::GetFileName($OutputPath)), [guid]::NewGuid().ToString('N'))
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($OutputPath, "Authenticate and restore Production ATAPUtilities backup using SecretName '$EncryptionSecretName'")) {
      return [pscustomobject]@{ Success = $false; Status = 'WhatIf'; InputPath = $InputPath; OutputPath = $OutputPath; EncryptionSecretName = $EncryptionSecretName }
    }

    try {
      $getSecretCommand = Get-Command -Name 'Get-SecretATAP' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $getSecretCommand) { throw 'Get-SecretATAP is required for database-backup restore but could not be autoloaded.' }
      $password = [string](& $getSecretCommand -SecretName $EncryptionSecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($password)) { throw "Secret '$EncryptionSecretName' resolved to an empty value." }
      $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($password)
      $password = $null

      $containerStream = [System.IO.File]::Open($InputPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
      try {
        if ($containerStream.Length -le $headerLength) { throw 'Encrypted backup container is incomplete.' }
        $prefix = [byte[]]::new($headerPrefixLength)
        if ($containerStream.Read($prefix, 0, $prefix.Length) -ne $prefix.Length) { throw 'Encrypted backup header is incomplete.' }
        if ([System.Text.Encoding]::ASCII.GetString($prefix, 0, 8) -ne 'ATAPDB01') { throw 'Encrypted backup container magic or version is unsupported.' }
        $iterationCount = [System.BitConverter]::ToInt32($prefix, 8)
        if ($iterationCount -lt 100000 -or $iterationCount -gt 2000000) { throw 'Encrypted backup PBKDF2 iteration count is outside the accepted range.' }
        $salt = [byte[]]$prefix[12..27]
        $iv = [byte[]]$prefix[28..43]
        $storedTag = [byte[]]::new(32)
        if ($containerStream.Read($storedTag, 0, $storedTag.Length) -ne $storedTag.Length) { throw 'Encrypted backup authentication tag is incomplete.' }

        $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($passwordBytes, $salt, $iterationCount, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        try { $derivedKeyMaterial = $derive.GetBytes(64) } finally { $derive.Dispose() }
        $encryptionKey = [byte[]]$derivedKeyMaterial[0..31]
        $authenticationKey = [byte[]]$derivedKeyMaterial[32..63]

        $hmac = [System.Security.Cryptography.HMACSHA256]::new($authenticationKey)
        try {
          [void]$hmac.TransformBlock($prefix, 0, $prefix.Length, $null, 0)
          $containerStream.Position = $headerLength
          $buffer = [byte[]]::new(1MB)
          while (($read = $containerStream.Read($buffer, 0, $buffer.Length)) -gt 0) { [void]$hmac.TransformBlock($buffer, 0, $read, $null, 0) }
          [void]$hmac.TransformFinalBlock([byte[]]::new(0), 0, 0)
          if (-not [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($storedTag, $hmac.Hash)) {
            throw 'Encrypted backup authentication failed. The artifact is corrupt, tampered, or the wrong secret was supplied.'
          }
        }
        finally { $hmac.Dispose() }

        $containerStream.Position = $headerLength
        $aes = [System.Security.Cryptography.Aes]::Create()
        $cryptoStream = $null
        $gzipStream = $null
        $outputStream = $null
        try {
          $aes.KeySize = 256
          $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
          $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
          $aes.Key = $encryptionKey
          $aes.IV = $iv
          $cryptoStream = [System.Security.Cryptography.CryptoStream]::new($containerStream, $aes.CreateDecryptor(), [System.Security.Cryptography.CryptoStreamMode]::Read, $true)
          $gzipStream = [System.IO.Compression.GZipStream]::new($cryptoStream, [System.IO.Compression.CompressionMode]::Decompress, $true)
          $outputStream = [System.IO.File]::Open($temporaryOutputPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
          $gzipStream.CopyTo($outputStream)
          $outputStream.Flush($true)
        }
        finally {
          if ($null -ne $outputStream) { $outputStream.Dispose() }
          if ($null -ne $gzipStream) { $gzipStream.Dispose() }
          if ($null -ne $cryptoStream) { $cryptoStream.Dispose() }
          if ($null -ne $aes) { $aes.Dispose() }
        }
      }
      finally { $containerStream.Dispose() }

      [System.IO.File]::Move($temporaryOutputPath, $OutputPath, $false)
      $temporaryOutputPath = $null
      $outputItem = Get-Item -LiteralPath $OutputPath -Force
      [pscustomobject]@{
        Success = $true
        Status = 'Restored'
        InputPath = $InputPath
        OutputPath = $OutputPath
        OutputLengthBytes = [long]$outputItem.Length
        OutputSha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToUpperInvariant()
        AuthenticationVerified = $true
        CompressionVerified = $true
        EncryptionVerified = $true
        EncryptionSecretName = $EncryptionSecretName
      }
    }
    catch {
      if ($temporaryOutputPath -and (Test-Path -LiteralPath $temporaryOutputPath -PathType Leaf)) { [System.IO.File]::Delete($temporaryOutputPath) }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to restore Production ATAPUtilities backup using SecretName '$EncryptionSecretName'. $($_.Exception.Message)"
      throw
    }
    finally {
      foreach ($sensitiveBytes in @($passwordBytes, $derivedKeyMaterial, $encryptionKey, $authenticationKey)) {
        if ($null -ne $sensitiveBytes) { [System.Array]::Clear($sensitiveBytes, 0, $sensitiveBytes.Length) }
      }
    }
  }

  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "$fn complete." }
}
