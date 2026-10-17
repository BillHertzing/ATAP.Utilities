BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/Get-GeneratedRemediationDirectorySnapshot.ps1')
  $script:fixture = 'D:/ATAPArtifacts/_generated/GeneratedFolderRemediation/Sprint0016/DirectorySnapshot/' + [guid]::NewGuid().ToString('N')
  $null = New-Item -ItemType Directory -Path "$fixture/_generated" -Force
  $script:getItemCommand = Get-Command Microsoft.PowerShell.Management\Get-Item
  function New-DirectoryFixture {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Synthetic fixture only.')]
    [CmdletBinding()]
    param([string]$Name = ([guid]::NewGuid().ToString('N')))
    $null = New-Item -ItemType Directory -Path "$fixture/_generated/$Name" -Force
    "_generated/$Name"
  }
}
Describe 'Explicit directory named-stream acquisition' {
  BeforeEach {
    Mock Get-Item {
      if ($Stream) { & $script:getItemCommand -LiteralPath $LiteralPath -Stream $Stream -Force -ErrorAction Stop }
      else { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    }
  }
  It 'captures real root streams, empty streams and Unicode without payload or file hash' {
    $path = "$fixture/_generated"
    [IO.File]::WriteAllText($path + ':notes', 'métadata')
    [IO.File]::WriteAllBytes($path + ':empty', [byte[]]@())
    $before = (Get-FileHash -LiteralPath ($path + ':notes')).Hash
    $results = @(Get-GeneratedRemediationDirectorySnapshot $fixture '_generated')
    $results.Count | Should -Be 1
    $result = $results[0]
    $result.Success | Should -BeTrue
    $result.Binding.Kind | Should -Be 'Root'
    $result.Observations.Count | Should -Be 2
    $result.Observations[0].Streams.Count | Should -Be 2
    ($result.Observations[0].Streams | Where-Object Name -EQ 'empty').Bytes | Should -Be 0
    $result.Observations[0].Metadata.PSObject.Properties.Name | Should -Not -Contain 'Bytes'
    $result.PSObject.Properties.Name | Should -Not -Contain 'SHA256'
    $result.InventoryComplete | Should -BeFalse
    $result.ChildInventoryComplete | Should -BeFalse
    $result.ReadyForManifest | Should -BeFalse
    $result.CustodyVerified | Should -BeFalse
    (Get-FileHash -LiteralPath ($path + ':notes')).Hash | Should -Be $before
  }
  It 'captures an actual long Unicode subdirectory stream' {
    $relative = New-DirectoryFixture -Name (('longdirectory012345/' * 9) + 'folder ü')
    $path = '\\?\' + "$fixture/$relative".Replace('/', '\') + ':附注'
    [IO.File]::WriteAllText($path, 'actual')
    $before = (Get-FileHash -LiteralPath $path).Hash
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeTrue
    $result.Binding.Kind | Should -Be 'Directory'
    $result.Observations[0].Streams[0].SHA256 | Should -Be $before
    (Get-FileHash -LiteralPath $path).Hash | Should -Be $before
  }
  It 'allows a supported zero-stream census on a nonempty directory without emptiness claims' {
    $relative = New-DirectoryFixture
    [IO.File]::WriteAllText("$fixture/$relative/child", 'preserve')
    $before = (Get-FileHash -LiteralPath "$fixture/$relative/child").Hash
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeTrue
    $result.Observations[0].Streams.Count | Should -Be 0
    $result.ChildInventoryComplete | Should -BeFalse
    $result.PSObject.Properties.Name | Should -Not -Contain 'Empty'
    (Get-FileHash -LiteralPath "$fixture/$relative/child").Hash | Should -Be $before
  }
  It 'rejects UNC device traversal and malformed relative paths without target probes' {
    foreach ($root in @('\\do-not-contact.invalid\share', '\\?\C:\temp', 'C:relative')) {
      (Get-GeneratedRemediationDirectorySnapshot $root '_generated').Success | Should -BeFalse
    }
    foreach ($relative in @('_generated/..', '_generated/a:stream', '_generated/NUL', '_generated/a\b', '_generated/', '_generated//a', '_generated/.git')) {
      (Get-GeneratedRemediationDirectorySnapshot $fixture $relative).Success | Should -BeFalse
    }
    Should -Invoke Get-Item -Times 0
  }
  It 'rejects files and missing targets without stream access' {
    [IO.File]::WriteAllText("$fixture/_generated/file", 'content')
    (Get-GeneratedRemediationDirectorySnapshot $fixture '_generated/file').Success | Should -BeFalse
    (Get-GeneratedRemediationDirectorySnapshot $fixture '_generated/missing').Success | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream }
  }
  It 'checks a nested Git marker on the target before stream reads' {
    $relative = New-DirectoryFixture
    [IO.File]::WriteAllText("$fixture/$relative/.git", 'marker')
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Errors[0] | Should -Match 'Nested repository'
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream }
  }
  It 'stops before a descendant probe at a redirecting ancestor' {
    Mock Get-Item { [pscustomobject]@{Attributes=[IO.FileAttributes]::ReparsePoint;LinkTarget='do-not-follow';PSIsContainer=$true} } -ParameterFilter { $LiteralPath -like '*_generated' -and -not $Stream }
    (Get-GeneratedRemediationDirectorySnapshot $fixture '_generated/child/target').Success | Should -BeFalse
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath -like '*child*' }
  }
  It 'rejects a real target junction' {
    $relative = New-DirectoryFixture
    $link = '_generated/junction'
    $null = New-Item -ItemType Junction -Path "$fixture/$link" -Target "$fixture/$relative"
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $link
    $result.Errors[0] | Should -Match 'Redirecting link'
  }
  It 'does not treat an unsupported stream census as empty' {
    $relative = New-DirectoryFixture
    Mock Get-Item { throw [NotSupportedException]::new('unsupported') } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 0
    $result.Attempts.Count | Should -Be 1
  }
  It 'excludes only a valid zero-length default marker and never opens unnamed data' {
    $relative = New-DirectoryFixture
    Mock Get-Item { [pscustomobject]@{Stream=':$DATA';Length=[long]0} } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeTrue
    $result.Observations[0].Streams.Count | Should -Be 0
  }
  It 'rejects duplicate aliases invalid names and unsupported default-type markers' {
    $relative = New-DirectoryFixture
    foreach ($mode in @('aliases','invalid','type','defaultlength','duplicateDefault','unknownLength')) {
      $script:mode = $mode
      Mock Get-Item {
        switch ($script:mode) {
          'aliases' { [pscustomobject]@{Stream='notes';Length=[long]0}; [pscustomobject]@{Stream='NOTES';Length=[long]0} }
          'invalid' { [pscustomobject]@{Stream='bad:name';Length=[long]0} }
          'type' { [pscustomobject]@{Stream='::$INDEX_ALLOCATION';Length=[long]0} }
          'defaultlength' { [pscustomobject]@{Stream=':$DATA';Length=[long]1} }
          'duplicateDefault' { [pscustomobject]@{Stream=':$DATA';Length=[long]0}; [pscustomobject]@{Stream=':$DATA';Length=[long]0} }
          'unknownLength' { [pscustomobject]@{Stream='notes';Length=$null} }
        }
      } -ParameterFilter { $Stream }
      $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
      $result.Success | Should -BeFalse
      $result.Observations.Count | Should -Be 0
    }
  }
  It 'retries transient permissions with retained failures and revalidation' {
    $relative = New-DirectoryFixture
    $script:reads = 0
    Mock Start-Sleep { }
    Mock Get-Item {
      $script:reads++
      if ($script:reads -eq 1) { throw [UnauthorizedAccessException]::new('transient') }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeTrue
    $result.Attempts.Count | Should -Be 3
    $result.Attempts[0].Error | Should -Match 'transient'
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 500 }
  }
  It 'stops after three failed permission attempts in an observation' {
    $relative = New-DirectoryFixture
    Mock Start-Sleep { }
    Mock Get-Item { throw [UnauthorizedAccessException]::new('locked') } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Attempts.Count | Should -Be 3
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 500 }
    Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Milliseconds -eq 1000 }
  }
  It 'detects same-length stream changes despite restored directory times' {
    $relative = New-DirectoryFixture
    $script:changedPath = "$fixture/$relative"
    [IO.File]::WriteAllText($script:changedPath + ':notes', 'first')
    $script:originalTime = [IO.Directory]::GetLastWriteTimeUtc($script:changedPath)
    $script:reads = 0
    Mock Get-Item {
      $script:reads++
      if ($script:reads -eq 3) {
        [IO.File]::WriteAllText($script:changedPath + ':notes', 'other')
        [IO.Directory]::SetLastWriteTimeUtc($script:changedPath, $script:originalTime)
      }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Errors[0] | Should -Match 'Content drift'
    $result.Observations.Count | Should -Be 1
    $result.Attempts[-1].Retry | Should -BeFalse
  }
  It 'rejects partial stream reads without a complete observation' {
    $relative = New-DirectoryFixture
    [IO.File]::WriteAllText("$fixture/${relative}:a", 'first')
    Mock Get-Item { [pscustomobject]@{Stream='a';Length=[long]5}; [pscustomobject]@{Stream='missing';Length=[long]0} } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 0
  }
  It 'detects a stream added between observations without retry' {
    $relative = New-DirectoryFixture
    $script:changedPath = "$fixture/$relative"
    $script:reads = 0
    Mock Get-Item {
      $script:reads++
      if ($script:reads -eq 3) { [IO.File]::WriteAllText($script:changedPath + ':new', 'new') }
      & $script:getItemCommand -LiteralPath $LiteralPath -Stream '*' -Force -ErrorAction Stop
    } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Observations.Count | Should -Be 1
    $result.Attempts[-1].Retry | Should -BeFalse
  }
  It 'revalidates ancestors on retry and stops when a link appears' {
    $relative = New-DirectoryFixture
    $script:retryLink = $false
    Mock Start-Sleep { }
    Mock Get-Item {
      if ($script:retryLink) { [pscustomobject]@{Attributes=[IO.FileAttributes]::ReparsePoint;LinkTarget='do-not-follow';PSIsContainer=$true} }
      else { & $script:getItemCommand -LiteralPath $LiteralPath -Force -ErrorAction Stop }
    } -ParameterFilter { $LiteralPath -like '*_generated' -and -not $Stream }
    Mock Get-Item { $script:retryLink = $true; throw [UnauthorizedAccessException]::new('transient') } -ParameterFilter { $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Success | Should -BeFalse
    $result.Attempts.Count | Should -Be 2
    $result.Attempts[-1].Error | Should -Match 'Redirecting link'
    Should -Invoke Get-Item -Times 1 -ParameterFilter { $Stream }
  }
  It 'checks ancestor nested Git before probing descendants' {
    $relative = New-DirectoryFixture -Name 'nested/child'
    [IO.File]::WriteAllText("$fixture/_generated/nested/.git", 'marker')
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Errors[0] | Should -Match 'Nested repository'
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $LiteralPath -like '*nested*child*' }
  }
  It 'refuses encrypted metadata without opening streams' {
    $relative = New-DirectoryFixture -Name 'encrypted'
    Mock Get-Item { [pscustomobject]@{Attributes=[IO.FileAttributes]::Encrypted;PSIsContainer=$true} } -ParameterFilter { $LiteralPath -like '*encrypted' -and -not $Stream }
    $result = Get-GeneratedRemediationDirectorySnapshot $fixture $relative
    $result.Errors[0] | Should -Match 'Encrypted'
    Should -Invoke Get-Item -Times 0 -ParameterFilter { $Stream }
  }
}
