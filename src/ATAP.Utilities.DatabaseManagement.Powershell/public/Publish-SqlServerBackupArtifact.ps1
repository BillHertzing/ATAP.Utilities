function Publish-SqlServerBackupArtifact {
  <#
  .SYNOPSIS
  Publishes one verified SQL Server backup artifact without overwriting an existing file.

  .DESCRIPTION
  Copies one completed staged artifact to a unique incoming file in the configured
  publication directory, atomically renames that incoming file to the final name without
  overwrite, and verifies the final length and SHA-256. This bounded function deliberately
  retains the staged source on success and failure; cleanup belongs to a separate retention
  operation that can safely prove file identity.

  InputObject must expose these exact properties:
  - StagedArtifactPath [string]: absolute path beneath StagingRoot.
  - DatabaseName [string]: one safe destination directory name.
  - ExpectedLengthBytes [Int64]: positive verified artifact length.
  - ExpectedSha256 [string]: 64 hexadecimal SHA-256 characters.
  - HeaderVerified [bool]: true only after trusted SQL backup-header verification.
  - ChecksumVerified [bool]: true only after trusted SQL backup-checksum verification.
  - CompressionVerified [bool]: true only after trusted compression verification.
  - EncryptionVerified [bool]: true only after trusted encryption verification.

  This function verifies the supplied trust metadata and current artifact bytes. It does
  not query SQL Server, compress or encrypt bytes, resolve an encryption secret, or infer
  verification success from a filename.

  .PARAMETER InputObject
  Verified backup metadata using the exact property contract documented above.

  .PARAMETER Settings
  Optional settings object used by Get-PVal. Defaults to $global:Settings.

  .PARAMETER ComputerName
  Host namespace below DatabaseBackupPublicationRoot. Defaults to the current computer.

  .PARAMETER DatabaseBackupPublicationRoot
  Configured publication root. Defaults through
  DatabaseBackupPublicationRootConfigRootKey and Get-PVal.

  .PARAMETER StagingRoot
  Exact allowed staging root. Defaults to the configured FastTempBasePath plus
  CobianReflectorBackup.

  .PARAMETER StabilityCheckMilliseconds
  Delay between two source metadata observations before exclusive-open verification.

  .OUTPUTS
  PSCustomObject with PublicationStatus=CopiedLocally and CloudSyncStatus=SyncAssumed on
  success. SyncAssumed explicitly does not claim cloud completion.

  .EXAMPLE
  $verified = [pscustomobject]@{
    StagedArtifactPath = 'C:\Temp\CobianReflectorBackup\ProGet\ProGet_FULL_20260911_010000.bak.7z'
    DatabaseName = 'ProGet'
    ExpectedLengthBytes = [long]9250000
    ExpectedSha256 = '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'
    HeaderVerified = $true
    ChecksumVerified = $true
    CompressionVerified = $true
    EncryptionVerified = $true
  }
  Publish-SqlServerBackupArtifact -InputObject $verified -Confirm:$false

  .NOTES
  Publication is local filesystem completion only. Dropbox synchronization must be
  observed independently.

  .LINK
  Test-DatabaseBackupHealth
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNull()]
    [psobject] $InputObject,

    [Parameter()]
    [hashtable] $Settings,

    [Parameter()]
    [string] $ComputerName,

    [Parameter()]
    [string] $DatabaseBackupPublicationRoot,

    [Parameter()]
    [string] $StagingRoot,

    [Parameter()]
    [ValidateRange(1, 5000)]
    [int] $StabilityCheckMilliseconds = 250
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.DatabaseManagement.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Resolving configured backup publication scope.'

    $getPValCommand = Get-Command -Name 'Get-PVal' -CommandType Alias, Function -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if (-not $getPValCommand) {
      $getPValCommand = Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue |
        Select-Object -First 1
    }
    if (-not $getPValCommand) {
      $message = 'Get-PVal is required to resolve backup publication configuration but could not be autoloaded.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      throw $message
    }

    $effectiveSettings = if ($PSBoundParameters.ContainsKey('Settings') -and $Settings) {
      $Settings
    }
    else {
      $global:Settings
    }

    $publicationKey = if ($global:ConfigRootKeys) {
      $global:ConfigRootKeys['DatabaseBackupPublicationRootConfigRootKey']
    }
    else {
      $null
    }
    $publicationDefault = if ($publicationKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($publicationKey)) {
      $effectiveSettings[$publicationKey]
    }
    else {
      $null
    }
    $DatabaseBackupPublicationRoot = & $getPValCommand `
      -ParameterName 'DatabaseBackupPublicationRoot' `
      -originalPSBoundParameters $PSBoundParameters `
      -Settings $effectiveSettings `
      -DefaultValue $publicationDefault `
      -AllowMissing
    if ([string]::IsNullOrWhiteSpace($DatabaseBackupPublicationRoot)) {
      $message = 'DatabaseBackupPublicationRoot could not be resolved; refusing to guess a publication scope.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      throw $message
    }

    $ComputerName = & $getPValCommand `
      -ParameterName 'ComputerName' `
      -originalPSBoundParameters $PSBoundParameters `
      -Settings $effectiveSettings `
      -DefaultValue $env:COMPUTERNAME `
      -AllowMissing
    if ([string]::IsNullOrWhiteSpace($ComputerName) -or $ComputerName -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,62}$') {
      $message = "ComputerName '$ComputerName' is not a safe host namespace."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      throw $message
    }
    $ComputerName = $ComputerName.ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($StagingRoot)) {
      $fastTempKey = if ($global:ConfigRootKeys) {
        $global:ConfigRootKeys['FastTempBasePathConfigRootKey']
      }
      else {
        $null
      }
      $fastTempBase = if ($fastTempKey -and $effectiveSettings -and $effectiveSettings.ContainsKey($fastTempKey)) {
        $effectiveSettings[$fastTempKey]
      }
      else {
        $null
      }
      if ([string]::IsNullOrWhiteSpace($fastTempBase)) {
        $message = 'StagingRoot could not be resolved from FastTempBasePathConfigRootKey; refusing to guess a staging scope.'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
        throw $message
      }
      $StagingRoot = Join-Path $fastTempBase 'CobianReflectorBackup'
    }

    $normalizeRoot = {
      param([string] $Path)
      if ([string]::IsNullOrWhiteSpace($Path) -or [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path)) {
        throw "Path '$Path' is empty or contains wildcard characters."
      }
      if (-not [System.IO.Path]::IsPathFullyQualified($Path)) {
        throw "Path '$Path' must be absolute."
      }
      [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    }

    $assertWithinRoot = {
      param([string] $Root, [string] $Candidate, [string] $Label)
      $relative = [System.IO.Path]::GetRelativePath($Root, $Candidate)
      if ([System.IO.Path]::IsPathRooted($relative) -or $relative -eq '..' -or $relative.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::Ordinal)) {
        throw "$Label '$Candidate' escapes configured root '$Root'."
      }
    }

    $assertNoReparsePoint = {
      param([string] $Root, [string] $Candidate, [string] $Label)
      $relative = [System.IO.Path]::GetRelativePath($Root, $Candidate)
      $cursorPath = $Root
      $pathsToCheck = @($cursorPath)
      if ($relative -ne '.') {
        foreach ($segment in $relative.Split([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), [System.StringSplitOptions]::RemoveEmptyEntries)) {
          $cursorPath = Join-Path $cursorPath $segment
          $pathsToCheck += $cursorPath
        }
      }
      foreach ($pathToCheck in $pathsToCheck) {
        $item = Get-Item -LiteralPath $pathToCheck -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
          throw "$Label traverses reparse point '$($item.FullName)'."
        }
      }
    }

    try {
      $resolvedPublicationRoot = & $normalizeRoot $DatabaseBackupPublicationRoot
      $resolvedStagingRoot = & $normalizeRoot $StagingRoot
      if (-not (Test-Path -LiteralPath $resolvedPublicationRoot -PathType Container)) {
        throw "Configured publication root is unavailable: $resolvedPublicationRoot"
      }
      if (-not (Test-Path -LiteralPath $resolvedStagingRoot -PathType Container)) {
        throw "Configured staging root is unavailable: $resolvedStagingRoot"
      }
      & $assertNoReparsePoint $resolvedPublicationRoot $resolvedPublicationRoot 'Publication root'
      & $assertNoReparsePoint $resolvedStagingRoot $resolvedStagingRoot 'Staging root'
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      throw
    }
  }

  process {
    $incomingPath = $null
    $destinationPath = $null
    $sourcePath = $null
    $incomingCreated = $false
    $destinationCreated = $false
    $publicationCommitted = $false

    try {
      $requiredProperties = @(
        'StagedArtifactPath',
        'DatabaseName',
        'ExpectedLengthBytes',
        'ExpectedSha256',
        'HeaderVerified',
        'ChecksumVerified',
        'CompressionVerified',
        'EncryptionVerified'
      )
      foreach ($propertyName in $requiredProperties) {
        if (-not $InputObject.PSObject.Properties[$propertyName]) {
          throw "InputObject is missing required property '$propertyName'."
        }
      }

      if ($InputObject.StagedArtifactPath -isnot [string] -or [string]::IsNullOrWhiteSpace($InputObject.StagedArtifactPath)) {
        throw 'StagedArtifactPath must be a non-empty string.'
      }
      if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($InputObject.StagedArtifactPath)) {
        throw 'StagedArtifactPath must be exact and cannot contain wildcard characters.'
      }
      if (-not [System.IO.Path]::IsPathFullyQualified($InputObject.StagedArtifactPath)) {
        throw 'StagedArtifactPath must be absolute.'
      }
      $sourcePath = [System.IO.Path]::GetFullPath($InputObject.StagedArtifactPath)
      & $assertWithinRoot $resolvedStagingRoot $sourcePath 'StagedArtifactPath'
      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Staged artifact does not exist as a file: $sourcePath"
      }
      & $assertNoReparsePoint $resolvedStagingRoot $sourcePath 'StagedArtifactPath'

      if ($InputObject.DatabaseName -isnot [string] -or $InputObject.DatabaseName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' -or $InputObject.DatabaseName -in @('.', '..')) {
        throw 'DatabaseName must be one safe directory-name string.'
      }
      $databaseName = $InputObject.DatabaseName

      if ($InputObject.ExpectedLengthBytes -isnot [long] -or $InputObject.ExpectedLengthBytes -le 0) {
        throw 'ExpectedLengthBytes must be a positive System.Int64 value.'
      }
      $expectedLength = $InputObject.ExpectedLengthBytes

      if ($InputObject.ExpectedSha256 -isnot [string] -or $InputObject.ExpectedSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw 'ExpectedSha256 must contain exactly 64 hexadecimal characters.'
      }
      $expectedSha256 = $InputObject.ExpectedSha256.ToUpperInvariant()

      if ($InputObject.HeaderVerified -isnot [bool] -or -not $InputObject.HeaderVerified) {
        throw 'HeaderVerified must be Boolean true from trusted backup verification.'
      }
      if ($InputObject.ChecksumVerified -isnot [bool] -or -not $InputObject.ChecksumVerified) {
        throw 'ChecksumVerified must be Boolean true from trusted backup verification.'
      }
      if ($InputObject.CompressionVerified -isnot [bool] -or -not $InputObject.CompressionVerified) {
        throw 'CompressionVerified must be Boolean true from trusted backup-seam verification.'
      }
      if ($InputObject.EncryptionVerified -isnot [bool] -or -not $InputObject.EncryptionVerified) {
        throw 'EncryptionVerified must be Boolean true from trusted backup-seam verification.'
      }

      $sourceLeafName = [System.IO.Path]::GetFileName($sourcePath)
      if ([string]::IsNullOrWhiteSpace($sourceLeafName) -or $sourceLeafName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw 'Staged artifact filename is invalid.'
      }

      $hostDirectory = [System.IO.Path]::GetFullPath((Join-Path $resolvedPublicationRoot $ComputerName))
      $publicationDirectory = [System.IO.Path]::GetFullPath((Join-Path $hostDirectory $databaseName))
      & $assertWithinRoot $resolvedPublicationRoot $hostDirectory 'Host publication directory'
      & $assertWithinRoot $resolvedPublicationRoot $publicationDirectory 'Database publication directory'
      if (-not (Test-Path -LiteralPath $publicationDirectory -PathType Container)) {
        throw "Database publication directory is unavailable: $publicationDirectory"
      }
      & $assertNoReparsePoint $resolvedPublicationRoot $publicationDirectory 'Database publication directory'

      $destinationPath = [System.IO.Path]::GetFullPath((Join-Path $publicationDirectory $sourceLeafName))
      & $assertWithinRoot $resolvedPublicationRoot $destinationPath 'Destination path'
      if (Test-Path -LiteralPath $destinationPath) {
        throw "Destination already exists; overwrite is prohibited: $destinationPath"
      }

      $before = Get-Item -LiteralPath $sourcePath -Force -ErrorAction Stop
      Start-Sleep -Milliseconds $StabilityCheckMilliseconds
      $after = Get-Item -LiteralPath $sourcePath -Force -ErrorAction Stop
      if ($before.Length -ne $after.Length -or $before.LastWriteTimeUtc -ne $after.LastWriteTimeUtc) {
        throw "Staged artifact changed during stability observation: $sourcePath"
      }

      if (-not $PSCmdlet.ShouldProcess($destinationPath, "Publish verified staged artifact '$sourcePath' without overwrite")) {
        return [pscustomobject]@{
          Success = $false
          PublicationStatus = 'WhatIf'
          CloudSyncStatus = 'NotAttempted'
          SourcePath = $sourcePath
          DestinationPath = $destinationPath
          LengthBytes = $expectedLength
          Sha256 = $expectedSha256
          SourcePreserved = $true
          StagingCleanupRequired = $false
        }
      }

      $incomingPath = Join-Path $publicationDirectory ('.{0}.{1}.incoming' -f $sourceLeafName, [guid]::NewGuid().ToString('N'))
      $sourceStream = $null
      $incomingStream = $null
      try {
        $sourceStream = [System.IO.File]::Open($sourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        if ($sourceStream.Length -ne $expectedLength) {
          throw "Staged artifact length $($sourceStream.Length) does not match expected length $expectedLength."
        }
        $currentHash = (Get-FileHash -InputStream $sourceStream -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
        if ($currentHash -ne $expectedSha256) {
          throw "Staged artifact SHA-256 does not match ExpectedSha256."
        }
        $sourceStream.Position = 0
        $incomingStream = [System.IO.File]::Open($incomingPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $incomingCreated = $true
        $sourceStream.CopyTo($incomingStream)
        $incomingStream.Flush($true)
      }
      finally {
        if ($null -ne $incomingStream) { $incomingStream.Dispose() }
        if ($null -ne $sourceStream) { $sourceStream.Dispose() }
      }

      $incoming = Get-Item -LiteralPath $incomingPath -Force -ErrorAction Stop
      $incomingHash = (Get-FileHash -LiteralPath $incomingPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
      if ($incoming.Length -ne $expectedLength -or $incomingHash -ne $expectedSha256) {
        throw 'Incoming publication copy failed length or SHA-256 verification.'
      }

      [System.IO.File]::Move($incomingPath, $destinationPath, $false)
      $incomingCreated = $false
      $destinationCreated = $true

      $publishedHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
      $published = Get-Item -LiteralPath $destinationPath -Force -ErrorAction Stop
      if ($published.Length -ne $expectedLength -or $publishedHash -ne $expectedSha256) {
        throw 'Final published artifact failed post-move length or SHA-256 verification.'
      }
      $publicationCommitted = $true

      $result = [pscustomobject]@{
        Success = $true
        PublicationStatus = 'CopiedLocally'
        CloudSyncStatus = 'SyncAssumed'
        SourcePath = $sourcePath
        DestinationPath = $destinationPath
        LengthBytes = [long]$published.Length
        Sha256 = $publishedHash
        SourcePreserved = $true
        StagingCleanupRequired = $true
      }

      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Published verified backup locally to '$destinationPath'; staged source retained for separate cleanup; cloud synchronization is assumed, not verified."
      }
      catch {
        # Publication is already committed. Logging is observational and must not turn a
        # verified publication into a rollback or a failing command result.
      }
      $result
    }
    catch {
      $originalError = $_
      if (-not $publicationCommitted) {
        if ($destinationCreated -and $destinationPath -and (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
          try { [System.IO.File]::Delete($destinationPath) } catch { }
        }
        if ($incomingCreated -and $incomingPath -and (Test-Path -LiteralPath $incomingPath -PathType Leaf)) {
          try { [System.IO.File]::Delete($incomingPath) } catch { }
        }
      }
      $sourcePresent = $sourcePath -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)
      $message = if ($publicationCommitted) {
        "Backup publication committed and verified, but a post-commit error occurred; no rollback was attempted and this invocation did not delete the staged source. StagedSourcePresent=$sourcePresent. $($originalError.Exception.Message)"
      }
      else {
        "Backup publication failed before commit; this invocation did not delete the staged source. StagedSourcePresent=$sourcePresent. $($originalError.Exception.Message)"
      }
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      }
      catch {
        # Preserve the publication exception when the logger itself is unavailable.
      }
      throw [System.InvalidOperationException]::new($message, $originalError.Exception)
    }
  }

  end {
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Backup publication processing finished.'
    }
    catch {
      # End-of-command logging is non-transactional and cannot invalidate publication.
    }
  }
}
