function Protect-SqlServerBackupArtifact {
  <#
  .SYNOPSIS
  Compresses and encrypts one Production ATAPUtilities SQL backup artifact.

  .DESCRIPTION
  Creates an authenticated ATAP database-backup container without placing encryption
  material in a process argument, environment variable, log, evidence file, or Git.
  The encryption value is resolved at the operation boundary through Get-SecretATAP.

  The container uses GZip compression followed by AES-256-CBC encryption and an
  encrypt-then-MAC HMAC-SHA256. Separate encryption and authentication keys are derived
  with PBKDF2-HMAC-SHA256 using a random 128-bit salt. Restore-SqlServerBackupArtifact
  verifies the HMAC before decrypting any bytes.

  .PARAMETER InputPath
  Absolute path to the completed .bak file.

  .PARAMETER OutputPath
  Optional absolute output path. Defaults to <InputPath>.gz.atapenc.

  .PARAMETER EncryptionSecretName
  SecretName resolved through Get-SecretATAP. The Production backup contract fixes this
  to dbEncryption.ATAPUtilities.Production on every host.

  .PARAMETER IterationCount
  PBKDF2 iteration count. Defaults to 310000.

  .OUTPUTS
  PSCustomObject containing only non-secret paths, hashes, lengths, and verification flags.

  .EXAMPLE
  Protect-SqlServerBackupArtifact -InputPath 'C:\Temp\ATAPUtilities_FULL_20260912_022000.bak' -Confirm:$false

  .NOTES
  The source .bak is retained. Its caller owns secure cleanup after successful verification.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ [System.IO.Path]::IsPathFullyQualified($_) })]
    [string] $InputPath,

    [Parameter()]
    [string] $OutputPath,

    [Parameter()]
    [ValidateSet('dbEncryption.ATAPUtilities.Production')]
    [string] $EncryptionSecretName = 'dbEncryption.ATAPUtilities.Production',

    [Parameter()]
    [ValidateRange(100000, 2000000)]
    [int] $IterationCount = 310000
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    $magic = [System.Text.Encoding]::ASCII.GetBytes('ATAPDB01')
    $headerPrefixLength = 44
    $tagLength = 32
    $headerLength = $headerPrefixLength + $tagLength
    $passwordBytes = $null
    $derivedKeyMaterial = $null
    $encryptionKey = $null
    $authenticationKey = $null
    $temporaryOutputPath = $null
    $outputCreatedByFunction = $false

    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
      throw "Input backup does not exist as a file: $InputPath"
    }
    $resolvedInputPath = [System.IO.Path]::GetFullPath($InputPath)
    $OutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
      "$resolvedInputPath.gz.atapenc"
    }
    else {
      [System.IO.Path]::GetFullPath($OutputPath)
    }
    if (-not [System.IO.Path]::IsPathFullyQualified($OutputPath)) {
      throw 'OutputPath must be absolute.'
    }
    if ([string]::Equals($resolvedInputPath, $OutputPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw 'OutputPath must differ from InputPath.'
    }
    if (Test-Path -LiteralPath $OutputPath) {
      throw "OutputPath already exists; overwrite is prohibited: $OutputPath"
    }
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
      throw "Output directory does not exist: $outputDirectory"
    }
    $temporaryOutputPath = Join-Path $outputDirectory ('.{0}.{1}.protecting' -f ([System.IO.Path]::GetFileName($OutputPath)), [guid]::NewGuid().ToString('N'))
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($OutputPath, "Compress and encrypt Production ATAPUtilities backup using SecretName '$EncryptionSecretName'")) {
      return [pscustomobject]@{
        Success = $false
        Status = 'WhatIf'
        InputPath = $resolvedInputPath
        OutputPath = $OutputPath
        EncryptionSecretName = $EncryptionSecretName
      }
    }

    try {
      $getSecretCommand = Get-Command -Name 'Get-SecretATAP' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $getSecretCommand) {
        throw 'Get-SecretATAP is required for database-backup encryption but could not be autoloaded.'
      }

      $password = [string](& $getSecretCommand -SecretName $EncryptionSecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop)
      if ([string]::IsNullOrWhiteSpace($password)) {
        throw "Secret '$EncryptionSecretName' resolved to an empty value."
      }
      $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($password)
      $password = $null

      $salt = [byte[]]::new(16)
      $iv = [byte[]]::new(16)
      [System.Security.Cryptography.RandomNumberGenerator]::Fill($salt)
      [System.Security.Cryptography.RandomNumberGenerator]::Fill($iv)

      $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($passwordBytes, $salt, $IterationCount, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
      try {
        $derivedKeyMaterial = $derive.GetBytes(64)
      }
      finally {
        $derive.Dispose()
      }
      $encryptionKey = [byte[]]$derivedKeyMaterial[0..31]
      $authenticationKey = [byte[]]$derivedKeyMaterial[32..63]

      $outputStream = $null
      $cryptoStream = $null
      $gzipStream = $null
      $inputStream = $null
      $aes = $null
      try {
        $outputStream = [System.IO.File]::Open($temporaryOutputPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $outputStream.Write($magic, 0, $magic.Length)
        $iterationBytes = [System.BitConverter]::GetBytes($IterationCount)
        $outputStream.Write($iterationBytes, 0, $iterationBytes.Length)
        $outputStream.Write($salt, 0, $salt.Length)
        $outputStream.Write($iv, 0, $iv.Length)
        $emptyTag = [byte[]]::new($tagLength)
        $outputStream.Write($emptyTag, 0, $emptyTag.Length)

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $encryptionKey
        $aes.IV = $iv

        $encryptor = $aes.CreateEncryptor()
        $cryptoStream = [System.Security.Cryptography.CryptoStream]::new($outputStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write, $true)
        $gzipStream = [System.IO.Compression.GZipStream]::new($cryptoStream, [System.IO.Compression.CompressionLevel]::Optimal, $true)
        $inputStream = [System.IO.File]::Open($resolvedInputPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $inputStream.CopyTo($gzipStream)
        $gzipStream.Dispose()
        $gzipStream = $null
        $cryptoStream.FlushFinalBlock()
        $cryptoStream.Dispose()
        $cryptoStream = $null
        $outputStream.Flush($true)
      }
      finally {
        if ($null -ne $inputStream) { $inputStream.Dispose() }
        if ($null -ne $gzipStream) { $gzipStream.Dispose() }
        if ($null -ne $cryptoStream) { $cryptoStream.Dispose() }
        if ($null -ne $aes) { $aes.Dispose() }
        if ($null -ne $outputStream) { $outputStream.Dispose() }
      }

      $hmac = [System.Security.Cryptography.HMACSHA256]::new($authenticationKey)
      $macStream = $null
      try {
        $macStream = [System.IO.File]::Open($temporaryOutputPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $prefix = [byte[]]::new($headerPrefixLength)
        if ($macStream.Read($prefix, 0, $prefix.Length) -ne $prefix.Length) {
          throw 'Encrypted backup header is incomplete.'
        }
        [void]$hmac.TransformBlock($prefix, 0, $prefix.Length, $null, 0)
        $macStream.Position = $headerLength
        $buffer = [byte[]]::new(1MB)
        while (($read = $macStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
          [void]$hmac.TransformBlock($buffer, 0, $read, $null, 0)
        }
        $emptyFinalBlock = [byte[]]::new(0)
        [void]$hmac.TransformFinalBlock($emptyFinalBlock, 0, 0)
        $tag = $hmac.Hash
        $macStream.Position = $headerPrefixLength
        $macStream.Write($tag, 0, $tag.Length)
        $macStream.Flush($true)
      }
      finally {
        if ($null -ne $macStream) { $macStream.Dispose() }
        $hmac.Dispose()
      }

      [System.IO.File]::Move($temporaryOutputPath, $OutputPath, $false)
      $temporaryOutputPath = $null
      $outputCreatedByFunction = $true

      $inputItem = Get-Item -LiteralPath $resolvedInputPath -Force
      $outputItem = Get-Item -LiteralPath $OutputPath -Force
      $inputHash = (Get-FileHash -LiteralPath $resolvedInputPath -Algorithm SHA256).Hash.ToUpperInvariant()
      $outputHash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToUpperInvariant()

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Protected Production ATAPUtilities backup at '$OutputPath' using SecretName '$EncryptionSecretName'."
      [pscustomobject]@{
        Success = $true
        Status = 'Protected'
        InputPath = $resolvedInputPath
        OutputPath = $OutputPath
        InputLengthBytes = [long]$inputItem.Length
        OutputLengthBytes = [long]$outputItem.Length
        InputSha256 = $inputHash
        OutputSha256 = $outputHash
        CompressionVerified = $true
        EncryptionVerified = $true
        EncryptionSecretName = $EncryptionSecretName
        ContainerVersion = 1
      }
    }
    catch {
      if ($temporaryOutputPath -and (Test-Path -LiteralPath $temporaryOutputPath -PathType Leaf)) {
        [System.IO.File]::Delete($temporaryOutputPath)
      }
      if ($outputCreatedByFunction -and (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        [System.IO.File]::Delete($OutputPath)
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to protect Production ATAPUtilities backup using SecretName '$EncryptionSecretName'. $($_.Exception.Message)"
      throw
    }
    finally {
      foreach ($sensitiveBytes in @($passwordBytes, $derivedKeyMaterial, $encryptionKey, $authenticationKey)) {
        if ($null -ne $sensitiveBytes) {
          [System.Array]::Clear($sensitiveBytes, 0, $sensitiveBytes.Length)
        }
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "$fn complete."
  }
}
