BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/Get-GeneratedRemediationFileSnapshot.ps1')
  $script:fixture = 'D:/ATAPArtifacts/_generated/GeneratedFolderRemediation/Sprint0016/FileSnapshot/' + [guid]::NewGuid().ToString('N')
  $null = New-Item -ItemType Directory -Path "$fixture/_generated" -Force
  $script:getItemCommand = Get-Command Microsoft.PowerShell.Management\Get-Item
  function New-SnapshotFixture {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Synthetic test fixture creation only.')]
    [CmdletBinding()]
    param([string]$Name = ([guid]::NewGuid().ToString('N') + '.txt'), [string]$Text = 'content')
    $path = "$fixture/_generated/$Name"
    $null = New-Item -ItemType Directory -Path (Split-Path $path) -Force
    [IO.File]::WriteAllText($path, $Text)
    return "_generated/$Name"
  }
}
Describe 'Single-file acquisition boundary' {
  BeforeEach {
    Mock Get-Item {
      if ($Stream) { & $script:getItemCommand -LiteralPath $LiteralPath -Stream $Stream -Force -ErrorAction Stop }
      else { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    }
  }
  It 'returns exactly one object and preserves real Unicode, empty and named streams' {
    $relative = New-SnapshotFixture -Name 'space ü.txt' -Text ''
    $path = "$fixture/$relative"
    [IO.File]::WriteAllText($path + ':notes', 'métadata')
    [IO.File]::WriteAllBytes($path + ':empty', [byte[]]@())
    $before = (Get-FileHash -LiteralPath ($path + ':notes')).Hash
    $results = @(Get-GeneratedRemediationFileSnapshot $fixture $relative)
    $results.Count | Should -Be 1
    $result = $results[0]
    $result.Success | Should -BeTrue
    $result.Observations.Count | Should -Be 2
    $result.Observations[0].Streams.Count | Should -Be 3
    ($result.Observations[0].Streams | Where-Object Name -EQ 'empty').Bytes | Should -Be 0
    $result.InventoryComplete | Should -BeFalse
    $result.ReadyForManifest | Should -BeFalse
    $result.CustodyVerified | Should -BeFalse
    (Get-FileHash -LiteralPath ($path + ':notes')).Hash | Should -Be $before
  }
  It 'hashes actual long file and ADS paths' {
    $relative = New-SnapshotFixture -Name (('longfolder0123456789/' * 9) + 'long ü.txt')
    [IO.File]::WriteAllText('\\?\' + "$fixture/$relative".Replace('/', '\') + ':附注', 'value')
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeTrue
    $result.Observations[0].Streams.Count | Should -Be 2
  }
  It 'rejects malformed paths before target metadata calls' {
    Mock Get-Item { throw 'Unexpected target probe' }
    foreach ($root in @('\\do-not-contact.invalid\share', '\\?\C:\temp', 'C:relative')) {
      (Get-GeneratedRemediationFileSnapshot $root '_generated/a').Success | Should -BeFalse
    }
    foreach ($relative in @('_generated/../a', '_generated/a:stream', '_generated/NUL.txt', '_generated/a\b', '_generated/a.', '_generated//a', '_generated/.git/config')) {
      (Get-GeneratedRemediationFileSnapshot $fixture $relative).Success | Should -BeFalse
    }
    Should -Invoke Get-Item -Times 0
  }
  It 'refuses missing files and directories without reporting a complete capture' {
    (Get-GeneratedRemediationFileSnapshot $fixture '_generated/missing').Success | Should -BeFalse
    $null = New-Item -ItemType Directory -Path "$fixture/_generated/directory" -Force
    $result = Get-GeneratedRemediationFileSnapshot $fixture '_generated/directory'
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 0
  }
  It 'rejects a nested repository before reading its descendant' {
    $relative = New-SnapshotFixture -Name 'nested/a.txt'
    [IO.File]::WriteAllText("$fixture/_generated/nested/.git", 'invalid marker')
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Errors[0] | Should -Match 'Nested repository'
  }
  It 'stops at an actual junction without reading its child' {
    $null = New-Item -ItemType Junction -Path "$fixture/_generated/link" -Target "$fixture/_generated/directory"
    $result = Get-GeneratedRemediationFileSnapshot $fixture '_generated/link/absent'
    $result.Success | Should -BeFalse
    $result.Errors[0] | Should -Match 'Redirecting link'
  }
  It 'does not interpret failed stream enumeration as an empty stream list' {
    $relative = New-SnapshotFixture
    Mock Get-Item { throw [InvalidOperationException]::new('stream provider failed') } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Attempts.Count | Should -Be 1
    $result.Observations.Count | Should -Be 0
  }
  It 'rejects absent default, case-duplicate and invalid stream census metadata' {
    $relative = New-SnapshotFixture
    foreach ($mode in @('absent', 'duplicate', 'invalid')) {
      $script:censusMode = $mode
      Mock Get-Item {
        if ($script:censusMode -ne 'absent') { [pscustomobject]@{Stream=':$DATA';Length=[long]7} }
        [pscustomobject]@{Stream='notes';Length=[long]0}
        if ($script:censusMode -eq 'duplicate') { [pscustomobject]@{Stream='NOTES';Length=[long]0} }
        if ($script:censusMode -eq 'invalid') { [pscustomobject]@{Stream='bad:stream';Length=[long]0} }
      } -ParameterFilter { $Stream }
      $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
      $result.Success | Should -BeFalse
      $result.Observations.Count | Should -Be 0
    }
  }
  It 'retries transient permissions with full revalidation and retains the first failure' {
    $relative = New-SnapshotFixture
    $script:censusCalls = 0
    Mock Start-Sleep { }
    Mock Get-Item {
      $script:censusCalls++
      if ($script:censusCalls -eq 1) { throw [UnauthorizedAccessException]::new('synthetic transient') }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeTrue
    $result.Attempts.Count | Should -Be 3
    $result.Attempts[0].Error | Should -Match 'synthetic transient'
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 500 }
  }
  It 'stops after three permission failures preserving every attempt' {
    $relative = New-SnapshotFixture
    Mock Start-Sleep { }
    Mock Get-Item { throw [UnauthorizedAccessException]::new('locked') } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Attempts.Count | Should -Be 3
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 500 }
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 1000 }
  }
  It 'holds stream-set changes between observations without retry' {
    $relative = New-SnapshotFixture
    $script:changedPath = "$fixture/$relative"
    $script:censusCalls = 0
    Mock Get-Item {
      $script:censusCalls++
      if ($script:censusCalls -eq 3) { [IO.File]::WriteAllText($script:changedPath + ':new', 'changed') }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 1
    $result.Attempts[-1].Retry | Should -BeFalse
  }
  It 'detects changed default bytes even with restored metadata' {
    $relative = New-SnapshotFixture
    $script:changedPath = "$fixture/$relative"
    $script:originalWriteTime = [IO.File]::GetLastWriteTimeUtc($script:changedPath)
    $script:censusCalls = 0
    Mock Get-Item {
      $script:censusCalls++
      if ($script:censusCalls -eq 3) {
        [IO.File]::WriteAllText($script:changedPath, 'CONTENT')
        [IO.File]::SetLastWriteTimeUtc($script:changedPath, $script:originalWriteTime)
      }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Errors[0] | Should -Match 'Content drift'
  }
  It 'fails partial stream reading without emitting a successful observation' {
    $relative = New-SnapshotFixture
    Mock Get-Item {
      [pscustomobject]@{Stream=':$DATA';Length=[long]7}
      [pscustomobject]@{Stream='missing';Length=[long]0}
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 0
  }
  It 'never probes a child after a mocked redirecting ancestor' {
    Mock Get-Item {
      [pscustomobject]@{ Attributes = [IO.FileAttributes]::ReparsePoint; LinkTarget = 'do-not-follow'; PSIsContainer = $true }
    } -ParameterFilter { $LiteralPath -like '*_generated' -and -not $Stream }
    Mock Get-Item { throw 'descendant must not be accessed' } -ParameterFilter { $LiteralPath -like '*_generated*child*' }
    (Get-GeneratedRemediationFileSnapshot $fixture '_generated/child/file.txt').Success | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath -like '*_generated*child*' }
  }
  It 'never probes a child below a nested repository marker' {
    $relative = New-SnapshotFixture -Name 'nested2/child.txt'
    [IO.File]::WriteAllText("$fixture/_generated/nested2/.git", 'marker')
    Mock Get-Item { throw 'descendant must not be accessed' } -ParameterFilter { $LiteralPath -like '*nested2*child.txt' }
    (Get-GeneratedRemediationFileSnapshot $fixture $relative).Success | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath -like '*nested2*child.txt' }
  }
  It 'detects same-length named stream changes between passes' {
    $relative = New-SnapshotFixture
    $script:changedPath = "$fixture/$relative"
    [IO.File]::WriteAllText($script:changedPath + ':notes', 'first')
    $script:originalWriteTime = [IO.File]::GetLastWriteTimeUtc($script:changedPath)
    $script:censusCalls = 0
    Mock Get-Item {
      $script:censusCalls++
      if ($script:censusCalls -eq 3) {
        [IO.File]::WriteAllText($script:changedPath + ':notes', 'other')
        [IO.File]::SetLastWriteTimeUtc($script:changedPath, $script:originalWriteTime)
      }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Errors[0] | Should -Match 'Content drift'
    $result.Attempts[-1].Retry | Should -BeFalse
  }
  It 'rejects encrypted file metadata without stream access' {
    $relative = New-SnapshotFixture -Name 'encrypted.txt'
    Mock Get-Item {
      [pscustomobject]@{Attributes=[IO.FileAttributes]::Encrypted;PSIsContainer=$false}
    } -ParameterFilter { $LiteralPath -like '*encrypted.txt' -and -not $Stream }
    Mock Get-Item { throw 'streams must not be accessed' } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationFileSnapshot $fixture $relative
    $result.Errors[0] | Should -Match 'Encrypted'
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream }
  }
}
