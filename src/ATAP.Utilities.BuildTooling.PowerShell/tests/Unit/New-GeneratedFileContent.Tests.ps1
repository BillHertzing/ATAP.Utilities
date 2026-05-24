BeforeAll {
  Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force
}

Describe 'New-GeneratedFileContent [private]' {
  BeforeAll {
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ngfc_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
  }

  AfterAll {
    Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'Prepends the generated header containing the source path' {
    $sourceFile = Join-Path $script:tempDir 'source.txt'
    Set-Content -Path $sourceFile -Value 'original content' -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    $result | Should -Match 'GENERATED FILE - DO NOT EDIT DIRECTLY'
    $result | Should -Match ([regex]::Escape($sourceFile))
    $result | Should -Match 'original content'
  }

  It 'Includes a UTC timestamp in ISO 8601 format' {
    $sourceFile = Join-Path $script:tempDir 'timestamped.txt'
    Set-Content -Path $sourceFile -Value 'data' -Encoding UTF8

    $result = New-GeneratedFileContent -SourcePath $sourceFile

    $result | Should -Match '# Generated: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z'
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

  It 'Throws when the source file does not exist' {
    { New-GeneratedFileContent -SourcePath 'C:\nonexistent\file.txt' } |
      Should -Throw '*not found*'
  }
}
