BeforeAll {
  $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:RepositoryRoot = Split-Path -Parent (Split-Path -Parent $script:ModuleRoot)
  $script:FixtureBase = Join-Path $script:RepositoryRoot '_generated\Sprint0015\Recovery20260911\Task-15.192.f.publisher\fixtures'
  [System.IO.Directory]::CreateDirectory($script:FixtureBase) | Out-Null

  function global:Get-PVal {
    param(
      [string] $ParameterName,
      [hashtable] $originalPSBoundParameters,
      $Settings,
      $DefaultValue,
      [switch] $AllowMissing
    )
    if ($originalPSBoundParameters.ContainsKey($ParameterName)) {
      return $originalPSBoundParameters[$ParameterName]
    }
    return $DefaultValue
  }

  function global:Write-PSFMessage {
    param($FunctionName, $ModuleName, $Level, $Message, $Tag)
  }

  function New-PublisherInput {
    param(
      [Parameter(Mandatory)][string] $Path,
      [Parameter(Mandatory)][string] $DatabaseName
    )
    $item = Get-Item -LiteralPath $Path
    [pscustomobject]@{
      StagedArtifactPath = $item.FullName
      DatabaseName = $DatabaseName
      ExpectedLengthBytes = [long]$item.Length
      ExpectedSha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
      HeaderVerified = [bool]$true
      ChecksumVerified = [bool]$true
      CompressionVerified = [bool]$true
      EncryptionVerified = [bool]$true
    }
  }

  $script:ComputeStreamSha256 = {
    param([System.IO.Stream] $Stream)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hashBytes = $sha.ComputeHash($Stream)
      -join ($hashBytes | ForEach-Object { $_.ToString('X2') })
    }
    finally {
      $sha.Dispose()
    }
  }

  $script:ComputeFileSha256 = {
    param([string] $Path)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
      & $script:ComputeStreamSha256 $stream
    }
    finally {
      $stream.Dispose()
    }
  }

  . (Join-Path $script:ModuleRoot 'public\Publish-SqlServerBackupArtifact.ps1')
}

AfterAll {
  Remove-Item -LiteralPath 'Function:\Get-PVal' -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath 'Function:\New-PublisherInput' -ErrorAction SilentlyContinue
}

Describe 'Publish-SqlServerBackupArtifact' {
BeforeEach {
  $script:CaseRoot = Join-Path $script:FixtureBase ([guid]::NewGuid().ToString('N'))
  $script:StagingRoot = Join-Path $script:CaseRoot 'staging'
  $script:SourceDirectory = Join-Path $script:StagingRoot 'ProGet'
  $script:PublicationRoot = Join-Path $script:CaseRoot 'publication'
  $script:DatabasePublicationDirectory = Join-Path $script:PublicationRoot 'utat022\ProGet'
  [System.IO.Directory]::CreateDirectory($script:SourceDirectory) | Out-Null
  [System.IO.Directory]::CreateDirectory($script:DatabasePublicationDirectory) | Out-Null
  $script:SourcePath = Join-Path $script:SourceDirectory 'ProGet_FULL_20260911_010000.bak.7z'
  [System.IO.File]::WriteAllBytes($script:SourcePath, [System.Text.Encoding]::UTF8.GetBytes('verified-backup-payload'))
  $script:Input = New-PublisherInput -Path $script:SourcePath -DatabaseName 'ProGet'
  $script:DestinationPath = Join-Path $script:DatabasePublicationDirectory (Split-Path -Leaf $script:SourcePath)
}

Context 'filesystem contract' {
  It 'publishes verified bytes locally, retains staging for separate cleanup, and does not claim cloud completion' {
    $result = Publish-SqlServerBackupArtifact -InputObject $script:Input `
      -ComputerName 'UTAT022' `
      -DatabaseBackupPublicationRoot $script:PublicationRoot `
      -StagingRoot $script:StagingRoot `
      -StabilityCheckMilliseconds 1 `
      -Confirm:$false

    $result.Success | Should -BeTrue
    $result.PublicationStatus | Should -Be 'CopiedLocally'
    $result.CloudSyncStatus | Should -Be 'SyncAssumed'
    $result.SourcePreserved | Should -BeTrue
    $result.StagingCleanupRequired | Should -BeTrue
    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath -PathType Leaf | Should -BeTrue
    (Get-Item -LiteralPath $script:DestinationPath).Length | Should -Be $script:Input.ExpectedLengthBytes
    (Get-FileHash -LiteralPath $script:DestinationPath -Algorithm SHA256).Hash | Should -Be $script:Input.ExpectedSha256
    @(Get-ChildItem -LiteralPath $script:DatabasePublicationDirectory -Filter '*.incoming' -Force).Count | Should -Be 0
  }

  It 'does not mutate the source or destination under WhatIf' {
    $result = Publish-SqlServerBackupArtifact -InputObject $script:Input `
      -ComputerName 'UTAT022' `
      -DatabaseBackupPublicationRoot $script:PublicationRoot `
      -StagingRoot $script:StagingRoot `
      -StabilityCheckMilliseconds 1 `
      -WhatIf

    $result.PublicationStatus | Should -Be 'WhatIf'
    $result.CloudSyncStatus | Should -Be 'NotAttempted'
    $result.StagingCleanupRequired | Should -BeFalse
    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath | Should -BeFalse
  }

  It 'refuses an existing destination without changing either file' {
    [System.IO.File]::WriteAllText($script:DestinationPath, 'pre-existing')

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*Destination already exists*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    [System.IO.File]::ReadAllText($script:DestinationPath) | Should -Be 'pre-existing'
  }

  It 'fails when the publication directory is unavailable and preserves the source' {
    $missingRoot = Join-Path $script:CaseRoot 'missing-publication'

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $missingRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*publication root is unavailable*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }

  It 'fails a copy when the preflighted publication directory disappears and preserves the source' {
    Mock -CommandName Get-FileHash -MockWith {
      if ($null -ne $InputStream) {
        $hash = & $script:ComputeStreamSha256 $InputStream
        [System.IO.Directory]::Delete($script:DatabasePublicationDirectory)
        return [pscustomobject]@{ Hash = $hash }
      }
      [pscustomobject]@{ Hash = (& $script:ComputeFileSha256 $LiteralPath) }
    }

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*did not delete the staged source*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }

  It 'does not delete a destination introduced by a move race and preserves the source' {
    Mock -CommandName Get-FileHash -MockWith {
      if ($null -ne $InputStream) {
        return [pscustomobject]@{ Hash = (& $script:ComputeStreamSha256 $InputStream) }
      }
      $result = [pscustomobject]@{ Hash = (& $script:ComputeFileSha256 $LiteralPath) }
      if ($LiteralPath -like '*.incoming') {
        [System.IO.File]::WriteAllText($script:DestinationPath, 'racing-owner')
      }
      $result
    }

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*did not delete the staged source*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    [System.IO.File]::ReadAllText($script:DestinationPath) | Should -Be 'racing-owner'
    @(Get-ChildItem -LiteralPath $script:DatabasePublicationDirectory -Filter '*.incoming' -Force).Count | Should -Be 0
  }

  It 'removes only its invalid final copy after a post-move hash mismatch and preserves the source' {
    Mock -CommandName Get-FileHash -MockWith {
      if ($null -ne $InputStream) {
        return [pscustomobject]@{ Hash = (& $script:ComputeStreamSha256 $InputStream) }
      }
      if ([string]::Equals($LiteralPath, $script:DestinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ Hash = ('0' * 64) }
      }
      [pscustomobject]@{ Hash = (& $script:ComputeFileSha256 $LiteralPath) }
    }

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*post-move length or SHA-256*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath | Should -BeFalse
    @(Get-ChildItem -LiteralPath $script:DatabasePublicationDirectory -Filter '*.incoming' -Force).Count | Should -Be 0
  }

  It 'removes only its invalid final copy after a post-move length mismatch and preserves the source' {
    Mock -CommandName Get-FileHash -MockWith {
      if ($null -ne $InputStream) {
        return [pscustomobject]@{ Hash = (& $script:ComputeStreamSha256 $InputStream) }
      }
      if ($LiteralPath -eq $script:DestinationPath) {
        [System.IO.File]::AppendAllText($LiteralPath, '-post-move-tamper')
        return [pscustomobject]@{ Hash = $script:Input.ExpectedSha256 }
      }
      [pscustomobject]@{ Hash = (& $script:ComputeFileSha256 $LiteralPath) }
    }

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*post-move length or SHA-256*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath | Should -BeFalse
    @(Get-ChildItem -LiteralPath $script:DatabasePublicationDirectory -Filter '*.incoming' -Force).Count | Should -Be 0
  }

  It 'does not delete or alter a staged path replaced during incoming or final verification' -TestCases @(
    @{ MutationPoint = 'Incoming' }
    @{ MutationPoint = 'Final' }
  ) {
    param($MutationPoint)
    $replacementBytes = [System.Text.Encoding]::UTF8.GetBytes("replacement-$MutationPoint")
    Mock -CommandName Get-FileHash -MockWith {
      if ($null -ne $InputStream) {
        return [pscustomobject]@{ Hash = (& $script:ComputeStreamSha256 $InputStream) }
      }
      $hash = & $script:ComputeFileSha256 $LiteralPath
      $isMutationPoint = ($MutationPoint -eq 'Incoming' -and $LiteralPath.EndsWith('.incoming')) -or
        ($MutationPoint -eq 'Final' -and $LiteralPath -eq $script:DestinationPath)
      if ($isMutationPoint) {
        [System.IO.File]::Delete($script:SourcePath)
        [System.IO.File]::WriteAllBytes($script:SourcePath, $replacementBytes)
      }
      [pscustomobject]@{ Hash = $hash }
    }

    $result = Publish-SqlServerBackupArtifact -InputObject $script:Input `
      -ComputerName 'UTAT022' `
      -DatabaseBackupPublicationRoot $script:PublicationRoot `
      -StagingRoot $script:StagingRoot `
      -StabilityCheckMilliseconds 1 `
      -Confirm:$false

    $result.Success | Should -BeTrue
    $result.SourcePreserved | Should -BeTrue
    $result.StagingCleanupRequired | Should -BeTrue
    [System.IO.File]::ReadAllBytes($script:SourcePath) | Should -Be $replacementBytes
    (Get-FileHash -LiteralPath $script:DestinationPath -Algorithm SHA256).Hash | Should -Be $script:Input.ExpectedSha256
  }

  It 'keeps committed publication successful when post-commit logging fails' -TestCases @(
    @{ FailurePoint = 'Commit' }
    @{ FailurePoint = 'End' }
  ) {
    param($FailurePoint)
    Mock -CommandName Write-PSFMessage -MockWith {
      if (($FailurePoint -eq 'Commit' -and $Level -eq 'Important') -or
          ($FailurePoint -eq 'End' -and $Message -eq 'Backup publication processing finished.')) {
        throw "simulated-$FailurePoint-logger-failure"
      }
    }

    $result = Publish-SqlServerBackupArtifact -InputObject $script:Input `
      -ComputerName 'UTAT022' `
      -DatabaseBackupPublicationRoot $script:PublicationRoot `
      -StagingRoot $script:StagingRoot `
      -StabilityCheckMilliseconds 1 `
      -Confirm:$false

    $result.Success | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }
}

Context 'trust and stability validation' {
  It 'rejects untrusted header or checksum metadata and preserves the source' -TestCases @(
    @{ Property = 'HeaderVerified'; Value = $false; Expected = '*HeaderVerified*' }
    @{ Property = 'HeaderVerified'; Value = 'true'; Expected = '*HeaderVerified*' }
    @{ Property = 'ChecksumVerified'; Value = $false; Expected = '*ChecksumVerified*' }
    @{ Property = 'ChecksumVerified'; Value = 1; Expected = '*ChecksumVerified*' }
    @{ Property = 'CompressionVerified'; Value = $false; Expected = '*CompressionVerified*' }
    @{ Property = 'CompressionVerified'; Value = 'true'; Expected = '*CompressionVerified*' }
    @{ Property = 'EncryptionVerified'; Value = $false; Expected = '*EncryptionVerified*' }
    @{ Property = 'EncryptionVerified'; Value = 1; Expected = '*EncryptionVerified*' }
  ) {
    param($Property, $Value, $Expected)
    $script:Input.$Property = $Value

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw $Expected

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }

  It 'rejects missing compression or encryption verification metadata before publication' -TestCases @(
    @{ Property = 'CompressionVerified' }
    @{ Property = 'EncryptionVerified' }
  ) {
    param($Property)
    $script:Input.PSObject.Properties.Remove($Property)

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw "*missing required property '$Property'*"

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath | Should -BeFalse
  }

  It 'rejects a non-positive or non-Int64 expected length' -TestCases @(
    @{ Value = [long]0 }
    @{ Value = [long]-1 }
    @{ Value = 22 }
    @{ Value = '22' }
  ) {
    param($Value)
    $script:Input.ExpectedLengthBytes = $Value

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*positive System.Int64*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }

  It 'rejects an invalid or mismatching SHA-256 and preserves the source' -TestCases @(
    @{ Value = 'not-a-hash'; Expected = '*64 hexadecimal*' }
    @{ Value = ('0' * 64); Expected = '*does not match*' }
  ) {
    param($Value, $Expected)
    $script:Input.ExpectedSha256 = $Value

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw $Expected

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }

  It 'rejects an exclusively open source and preserves it' {
    $lock = [System.IO.File]::Open($script:SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
    try {
      { Publish-SqlServerBackupArtifact -InputObject $script:Input `
          -ComputerName 'UTAT022' `
          -DatabaseBackupPublicationRoot $script:PublicationRoot `
          -StagingRoot $script:StagingRoot `
          -StabilityCheckMilliseconds 1 `
          -Confirm:$false } | Should -Throw '*did not delete the staged source*'
    }
    finally {
      $lock.Dispose()
    }

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
  }

  It 'rejects a source that changes during stability observation' {
    Mock -CommandName Start-Sleep -MockWith {
      [System.IO.File]::AppendAllText($script:SourcePath, '-changed')
    }

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*changed during stability observation*'

    Test-Path -LiteralPath $script:SourcePath -PathType Leaf | Should -BeTrue
    Test-Path -LiteralPath $script:DestinationPath | Should -BeFalse
  }
}

Context 'path boundary validation' {
  It 'rejects missing, empty, relative, wildcard, and escaping source paths' -TestCases @(
    @{ Value = ''; Expected = '*non-empty string*' }
    @{ Value = 'relative.bak'; Expected = '*must be absolute*' }
    @{ Value = 'C:\Temp\*.bak'; Expected = '*cannot contain wildcard*' }
    @{ Value = $null; Expected = '*non-empty string*' }
  ) {
    param($Value, $Expected)
    $script:Input.StagedArtifactPath = $Value

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw $Expected
  }

  It 'rejects a missing source file' {
    $script:Input.StagedArtifactPath = Join-Path $script:SourceDirectory 'missing.bak'

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*does not exist as a file*'
  }

  It 'rejects a source outside the configured staging root' {
    $outside = Join-Path $script:CaseRoot 'outside.bak'
    [System.IO.File]::WriteAllText($outside, 'outside')
    $script:Input.StagedArtifactPath = $outside

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*escapes configured root*'
  }

  It 'rejects a staged path that traverses a reparse point' {
    $realDirectory = Join-Path $script:CaseRoot 'real-source'
    $junctionDirectory = Join-Path $script:StagingRoot 'junction-source'
    [System.IO.Directory]::CreateDirectory($realDirectory) | Out-Null
    $realSource = Join-Path $realDirectory 'linked.bak'
    [System.IO.File]::WriteAllText($realSource, 'linked-content')
    New-Item -ItemType Junction -Path $junctionDirectory -Target $realDirectory | Out-Null
    $linkedSource = Join-Path $junctionDirectory 'linked.bak'
    $script:Input = New-PublisherInput -Path $linkedSource -DatabaseName 'ProGet'

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*reparse point*'

    Test-Path -LiteralPath $realSource -PathType Leaf | Should -BeTrue
  }

  It 'rejects unsafe database-name path variants' -TestCases @(
    @{ Value = '..' }
    @{ Value = 'ProGet\escaped' }
    @{ Value = 'ProGet/escaped' }
    @{ Value = 'Pro*Get' }
  ) {
    param($Value)
    $script:Input.DatabaseName = $Value

    { Publish-SqlServerBackupArtifact -InputObject $script:Input `
        -ComputerName 'UTAT022' `
        -DatabaseBackupPublicationRoot $script:PublicationRoot `
        -StagingRoot $script:StagingRoot `
        -StabilityCheckMilliseconds 1 `
        -Confirm:$false } | Should -Throw '*safe directory-name*'
  }
}

Context 'module shape' {
  It 'contains exactly one top-level function definition and no executable statements' {
    $path = Join-Path $script:ModuleRoot 'public\Publish-SqlServerBackupArtifact.ps1'
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)

    $errors.Count | Should -Be 0
    $ast.EndBlock.Statements.Count | Should -Be 1
    $ast.EndBlock.Statements[0] | Should -BeOfType ([System.Management.Automation.Language.FunctionDefinitionAst])
    $ast.EndBlock.Statements[0].Name | Should -Be 'Publish-SqlServerBackupArtifact'
  }
}
}
