BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\private\New-GeneratedFileContent.ps1')
}

Describe 'New-GeneratedFileContent [private]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ngfc_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'prepends the generated header containing a stable logical source label' {
    $sourceFile = Join-Path $script:tempDir 'source.txt'
    Set-Content -Path $sourceFile -Value 'original content' -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    $result | Should -Match 'GENERATED FILE - DO NOT EDIT DIRECTLY'
    $result | Should -Match 'Source: SharedVSCode/source\.txt'
    $result | Should -Not -Match ([regex]::Escape($script:tempDir))
    $result | Should -Match 'original content'
  }

  It 'excludes timestamps so regeneration is deterministic' {
    $sourceFile = Join-Path $script:tempDir 'timestamped.txt'
    Set-Content -Path $sourceFile -Value 'data' -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    $result | Should -Not -Match '# Generated:'
  }

  It 'Includes the regeneration command reference' {
    $sourceFile = Join-Path $script:tempDir 'regen.txt'
    Set-Content -Path $sourceFile -Value 'data' -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    $result | Should -Match 'Regenerate using Set-DownstreamSharedVSCodeContext'
  }

  It 'Preserves multi-line source content intact' {
    $sourceFile = Join-Path $script:tempDir 'multiline.txt'
    $multiline = "line one`nline two`nline three"
    Set-Content -Path $sourceFile -Value $multiline -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    $result | Should -Match 'line one'
    $result | Should -Match 'line three'
  }

  It 'Replaces an existing generated header instead of stacking a second one' {
    $sourceFile = Join-Path $script:tempDir 'generated-source.txt'
    $existing = @(
      '# ==================================================================='
      '# GENERATED FILE - DO NOT EDIT DIRECTLY'
      '# Source: C:\Old\source.txt'
      '# Generated: 2026-06-01T00:00:00Z'
      '# Regenerate using Set-DownstreamSharedVSCodeContext'
      '# ==================================================================='
      ''
      'real content'
    ) -join [Environment]::NewLine
    Set-Content -Path $sourceFile -Value $existing -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    ([regex]::Matches($result, 'GENERATED FILE - DO NOT EDIT DIRECTLY')).Count | Should -Be 1
    $result | Should -Match 'real content'
    $result | Should -Not -Match ([regex]::Escape('C:\Old\source.txt'))
  }

  It 'returns identical bytes for repeated generation of unchanged content' {
    $sourceFile = Join-Path $script:tempDir '.gitattributes'
    Set-Content -Path $sourceFile -Value '*.ps1 text eol=crlf' -Encoding UTF8

    $first = New-GeneratedFileContent -SourcePath $sourceFile
    Start-Sleep -Milliseconds 20
    $second = New-GeneratedFileContent -SourcePath $sourceFile

    $second | Should -BeExactly $first
  }

  It 'Throws when the source file does not exist' {
    { New-GeneratedFileContent -SourcePath 'C:\nonexistent\file.txt' } |
      Should -Throw '*not found*'
  }
}
