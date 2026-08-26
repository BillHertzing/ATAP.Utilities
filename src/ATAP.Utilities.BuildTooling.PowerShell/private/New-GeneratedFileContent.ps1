function New-GeneratedFileContent {
  <#
  .SYNOPSIS
    Wraps source file content with a generated-file header.
  .DESCRIPTION
    Reads the source file and prepends a deterministic header block including
    logical source identity and regeneration instructions. Absolute worktree
    paths and timestamps are deliberately excluded so repeated sprint-boundary
    generation is byte-idempotent.
  .PARAMETER SourcePath
    Path to the source file whose content will be wrapped.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath
  )

  if (-not (Test-Path -Path $SourcePath)) {
    throw "Source file not found: '$SourcePath'."
  }

  $source = Get-Content -Path $SourcePath -Raw -Encoding UTF8
  # Strip every consecutive generated header one anchored block at a time so
  # repeated regeneration replaces metadata without altering payload bytes.
  $existingHeaderPattern = '(?s)\A# ===================================================================\r?\n# GENERATED FILE - DO NOT EDIT DIRECTLY\r?\n# Source: .*?\r?\n(?:# Generated: .*?\r?\n)?# Regenerate using Set-DownstreamSharedVSCodeContext\r?\n# ===================================================================\r?\n(?:\r?\n)?'
  while ([regex]::IsMatch($source, $existingHeaderPattern)) {
    $source = [regex]::Replace($source, $existingHeaderPattern, '', 1)
  }
  $sourceLabel = 'SharedVSCode/' + [IO.Path]::GetFileName($SourcePath)

  $header = @(
    '# ==================================================================='
    '# GENERATED FILE - DO NOT EDIT DIRECTLY'
    "# Source: $sourceLabel"
    '# Regenerate using Set-DownstreamSharedVSCodeContext'
    '# ==================================================================='
    ''
  ) -join [Environment]::NewLine

  return $header + $source
}
