BeforeAll {
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  . (Join-Path $PSScriptRoot '../../public/Export-AgentTextToFiles.ps1')
  $artifactRoot = $env:ARTIFACTS_PATH
  if ([string]::IsNullOrWhiteSpace($artifactRoot)) { $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
  if ([string]::IsNullOrWhiteSpace($artifactRoot) -or -not [IO.Path]::IsPathFullyQualified($artifactRoot)) { throw 'ARTIFACTS_PATH required' }
  $fixtureRoot = Join-Path $artifactRoot ('Sprint0017/Task17.9.b/RulesExportLF328/Tests-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
  function New-Record([string] $body, [string] $path, [string] $mode) {
    [pscustomobject]@{ SourceId = 'test'; BodySha256 = 'source-hash'; BodyText = $body; AdapterTargets = @([pscustomobject]@{ Path = $path; Materialization = $mode }) }
  }
}
AfterAll {
  # Retain task-scoped disposable outputs for root evidence inspection.
}

Describe 'Export-AgentTextToFiles LF output' -Tag 'Unit' {
  It 'normalizes mixed line endings and retains Unicode for copy, wrapper and AGENTS' {
    $body = "café`r`n東京`rline`nlast"
    foreach ($target in @(@{ Path = 'copy.txt'; Mode = 'copy' }, @{ Path = 'wrapper.md'; Mode = 'generated-wrapper' }, @{ Path = 'AGENTS.md'; Mode = 'generated-wrapper' })) {
      $result = Export-AgentTextToFiles -AgentText (New-Record $body $target.Path $target.Mode) -TargetRoot $fixtureRoot
      $path = Join-Path $fixtureRoot $target.Path
      $bytes = [IO.File]::ReadAllBytes($path)
      $text = [Text.Encoding]::UTF8.GetString($bytes)
      $text | Should -Not -Match "`r"
      $text.EndsWith("`n") | Should -BeTrue
      $text | Should -Match 'café'
      $text | Should -Match '東京'
      ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
      $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
      $result.Results[0].Sha256 | Should -Be $hash
      $result.Results[0].Bytes | Should -Be $bytes.Length
      $again = Export-AgentTextToFiles -AgentText (New-Record $body $target.Path $target.Mode) -TargetRoot $fixtureRoot
      $again.Results[0].Action | Should -Be 'unchanged'
      [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($path))).ToLowerInvariant() | Should -Be $hash
    }
  }

  It 'repairs decoded-equal BOM bytes and is idempotent' {
    $path = Join-Path $fixtureRoot 'repair.txt'
    [IO.File]::WriteAllText($path, "one`ntwo`n", [Text.UTF8Encoding]::new($true))
    $record = New-Record "one`ntwo`n" 'repair.txt' 'copy'
    $first = Export-AgentTextToFiles -AgentText $record -TargetRoot $fixtureRoot
    $first.Results[0].Action | Should -Be 'written'
    [Convert]::ToHexString([IO.File]::ReadAllBytes($path)) | Should -Be ([Convert]::ToHexString([Text.UTF8Encoding]::new($false).GetBytes("one`ntwo`n")))
    (Export-AgentTextToFiles -AgentText $record -TargetRoot $fixtureRoot).Results[0].Action | Should -Be 'unchanged'
  }

  It 'does not create target directories under WhatIf' {
    $target = Join-Path $fixtureRoot 'missing'
    $null = Export-AgentTextToFiles -AgentText (New-Record 'body' 'missing/file.txt' 'copy') -TargetRoot $fixtureRoot -WhatIf
    Test-Path -LiteralPath $target | Should -BeFalse
  }
}
