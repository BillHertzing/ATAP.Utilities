#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  . (Join-Path $moduleRoot 'public\Export-InstantiationManifestation.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  function Get-TestSha256 {
    param([byte[]]$Bytes)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
  }

  function New-TestInstantiationGraph {
    param(
      [string]$RelativePath = 'ATAP.Utilities\src\Sample.ps1',
      [object[]]$Lines = @(
        [pscustomobject]@{ Ordinal = 1; LineText = 'one'; LineEnding = 'CRLF' }
        [pscustomobject]@{ Ordinal = 2; LineText = ''; LineEnding = 'CRLF' }
        [pscustomobject]@{ Ordinal = 3; LineText = 'one'; LineEnding = 'None' }
      ),
      [string]$Bom = 'none',
      [string]$FinalNewline = 'false',
      [string]$ExpectedHash,
      [object[]]$AdditionalArtifacts = @()
    )

    $riv = [guid]'11111111-2222-3333-4444-555555555555'
    $ri = [guid]'22222222-3333-4444-5555-666666666666'
    if ([string]::IsNullOrWhiteSpace($ExpectedHash)) {
      $text = [Text.StringBuilder]::new()
      foreach ($line in $Lines | Sort-Object Ordinal) {
        [void]$text.Append([string]$line.LineText)
        if ($line.LineEnding -eq 'CRLF') { [void]$text.Append("`r`n") }
        if ($line.LineEnding -eq 'LF') { [void]$text.Append("`n") }
      }
      $payload = [Text.UTF8Encoding]::new($false).GetBytes($text.ToString())
      if ($Bom -eq 'utf8') {
        $preamble = [Text.UTF8Encoding]::new($true).GetPreamble()
        $bytes = [byte[]]::new($preamble.Length + $payload.Length)
        [Array]::Copy($preamble, 0, $bytes, 0, $preamble.Length)
        [Array]::Copy($payload, 0, $bytes, $preamble.Length, $payload.Length)
      } else {
        $bytes = $payload
      }
      $ExpectedHash = Get-TestSha256 -Bytes $bytes
    }
    [pscustomobject]@{
      InstantiationVersionPhiloteId = [guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
      RuleInstantiations = @(
        [pscustomobject]@{
          RuleInstantiationVersionPhiloteId = $riv
          RuleInstantiationPhiloteId = $ri
          Bindings = @(
            [pscustomobject]@{ InputName = 'Encoding'; InputValue = 'utf8' }
            [pscustomobject]@{ InputName = 'Bom'; InputValue = $Bom }
            [pscustomobject]@{ InputName = 'FinalNewline'; InputValue = $FinalNewline }
          )
          SourceLines = $Lines
        }
      )
      ManifestationArtifacts = @(
        [pscustomobject]@{
          ArtifactKind = 'Directory'
          RelativePath = 'ATAP.Utilities\src'
          SortOrder = 10
        }
        [pscustomobject]@{
          ArtifactKind = 'ModuleSource'
          RelativePath = $RelativePath
          ContentSha256 = $ExpectedHash
          SortOrder = 20
          BuildSetVersionPhiloteId = [guid]'33333333-4444-5555-6666-777777777777'
          ProducingRuleInstantiationPhiloteId = $ri
          ProducingRuleInstantiationVersionPhiloteId = $riv
        }
      ) + @($AdditionalArtifacts)
    }
  }
}

Describe 'Export-InstantiationManifestation corrected graph' -Tag 'Unit' {
  BeforeEach {
    $script:targetRoot = Join-Path ([IO.Path]::GetTempPath()) "atap-corrected-render-$([guid]::NewGuid().ToString('N'))"
  }

  AfterEach {
    Remove-Item -LiteralPath $script:targetRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'returns a deterministic dry-run without touching the filesystem' {
    $result = Export-InstantiationManifestation -InstantiationGraph (New-TestInstantiationGraph) -TargetRoot $script:targetRoot -DryRun

    $result.DryRun | Should -BeTrue
    $result.WroteFileSystem | Should -BeFalse
    $result.Artifacts.RelativePath | Should -Be @('ATAP.Utilities\src', 'ATAP.Utilities\src\Sample.ps1')
    Test-Path -LiteralPath $script:targetRoot | Should -BeFalse
  }

  It 'rejects absolute children, drive changes, and parent traversal' -ForEach @(
    @{ BadPath = 'C:\Windows\escape.ps1'; Pattern = '*absolute or changes drive*' }
    @{ BadPath = 'D:escape.ps1'; Pattern = '*absolute or changes drive*' }
    @{ BadPath = 'ATAP.Utilities\..\escape.ps1'; Pattern = '*parent traversal*' }
  ) {
    { Export-InstantiationManifestation -InstantiationGraph (New-TestInstantiationGraph -RelativePath $BadPath) -TargetRoot $script:targetRoot -DryRun } |
      Should -Throw -ExpectedMessage $Pattern
  }

  It 'rejects duplicate outputs' {
    $extra = [pscustomobject]@{ ArtifactKind = 'Directory'; RelativePath = 'ATAP.Utilities\src'; SortOrder = 30 }
    { Export-InstantiationManifestation -InstantiationGraph (New-TestInstantiationGraph -AdditionalArtifacts $extra) -TargetRoot $script:targetRoot -DryRun } |
      Should -Throw -ExpectedMessage '*Duplicate manifestation output*'
  }

  It 'rejects case-colliding outputs' {
    $extra = [pscustomobject]@{ ArtifactKind = 'Directory'; RelativePath = 'atap.utilities\SRC'; SortOrder = 30 }
    { Export-InstantiationManifestation -InstantiationGraph (New-TestInstantiationGraph -AdditionalArtifacts $extra) -TargetRoot $script:targetRoot -DryRun } |
      Should -Throw -ExpectedMessage '*Case-colliding manifestation outputs*'
  }

  It 'preserves blank and duplicate lines, mixed line endings, no BOM, and no final newline at the exact hash' {
    $lines = @(
      [pscustomobject]@{ Ordinal = 1; LineText = 'same'; LineEnding = 'CRLF' }
      [pscustomobject]@{ Ordinal = 2; LineText = ''; LineEnding = 'LF' }
      [pscustomobject]@{ Ordinal = 3; LineText = 'same'; LineEnding = 'None' }
    )
    $graph = New-TestInstantiationGraph -Lines $lines
    $result = Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $script:targetRoot
    $path = Join-Path $script:targetRoot 'ATAP.Utilities\src\Sample.ps1'
    $bytes = [IO.File]::ReadAllBytes($path)

    [Text.UTF8Encoding]::new($false).GetString($bytes) | Should -BeExactly "same`r`n`nsame"
    $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
    (Get-TestSha256 -Bytes $bytes) | Should -Be $result.Artifacts[-1].ContentSha256
  }

  It 'preserves a UTF-8 BOM and final CRLF' {
    $lines = @([pscustomobject]@{ Ordinal = 1; LineText = 'final'; LineEnding = 'CRLF' })
    $graph = New-TestInstantiationGraph -Lines $lines -Bom utf8 -FinalNewline true
    Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $script:targetRoot | Out-Null
    $bytes = [IO.File]::ReadAllBytes((Join-Path $script:targetRoot 'ATAP.Utilities\src\Sample.ps1'))

    $bytes[0] | Should -Be 0xEF
    $bytes[1] | Should -Be 0xBB
    $bytes[2] | Should -Be 0xBF
    $bytes[-2] | Should -Be 0x0D
    $bytes[-1] | Should -Be 0x0A
  }

  It 'round-trips the Markdown <Construct> source form exactly' -ForEach @(
    @{ Construct = 'ATX heading'; Text = '## Parameters' }
    @{ Construct = 'paragraph'; Text = 'Formats every element in source order.' }
    @{ Construct = 'blank line'; Text = '' }
    @{ Construct = 'unordered list'; Text = '- First item' }
    @{ Construct = 'fenced code'; Text = '```powershell' }
    @{ Construct = 'link'; Text = '[Source](../public/Write-ArrayIndented.ps1)' }
    @{ Construct = 'pipe table'; Text = '| Name | Type | Default |' }
  ) {
    $lines = @([pscustomobject]@{ Ordinal = 1; LineText = $Text; LineEnding = 'CRLF' })
    $graph = New-TestInstantiationGraph -RelativePath 'ATAP.Utilities\src\Sample.md' -Lines $lines -FinalNewline true

    Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $script:targetRoot | Out-Null

    $actual = [Text.UTF8Encoding]::new($false).GetString(
      [IO.File]::ReadAllBytes((Join-Path $script:targetRoot 'ATAP.Utilities\src\Sample.md')))
    $actual | Should -BeExactly "$Text`r`n"
  }

  It 'fails closed on an exact-byte hash mismatch' {
    $graph = New-TestInstantiationGraph -ExpectedHash ('0' * 64)
    { Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $script:targetRoot -DryRun } |
      Should -Throw -ExpectedMessage '*Exact-byte SHA-256 mismatch*'
  }

  It 'persists provenance idempotently and does not rewrite unchanged bytes' {
    $script:provenanceKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $writer = {
      param($record)
      $key = "$($record.InstantiationVersionPhiloteId)|$($record.RelativePath)|$($record.ContentSha256)"
      [pscustomobject]@{ Created = $script:provenanceKeys.Add($key) }
    }
    $graph = New-TestInstantiationGraph
    $first = Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $script:targetRoot -PersistProvenance -ProvenanceWriter $writer
    $second = Export-InstantiationManifestation -InstantiationGraph $graph -TargetRoot $script:targetRoot -PersistProvenance -ProvenanceWriter $writer

    $first.Artifacts[-1].Action | Should -Be 'Written'
    $first.Artifacts[-1].ProvenanceResult.Created | Should -BeTrue
    $second.Artifacts[-1].Action | Should -Be 'Unchanged'
    $second.Artifacts[-1].ProvenanceResult.Created | Should -BeFalse
    $script:provenanceKeys | Should -HaveCount 1
  }
}
