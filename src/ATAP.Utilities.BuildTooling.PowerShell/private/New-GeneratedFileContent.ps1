function New-GeneratedFileContent {
  <#
  .SYNOPSIS
    Wraps source file content with a generated-file header.
  .DESCRIPTION
    Reads the source file and prepends a stamped header block including source
    path, UTC timestamp, and regeneration instructions.
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
  # If the source is already a generated derivative, strip the old header so
  # repeated regeneration replaces metadata instead of stacking header blocks.
  $existingHeaderPattern = '(?s)\A# ===================================================================\r?\n# GENERATED FILE - DO NOT EDIT DIRECTLY\r?\n# Source: .*?\r?\n# Generated: .*?\r?\n# Regenerate using Set-DownstreamSharedVSCodeContext\r?\n# ===================================================================\r?\n(?:\r?\n)?'
  $source = [regex]::Replace($source, $existingHeaderPattern, '', 1)
  $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

  $header = @(
    '# ==================================================================='
    '# GENERATED FILE - DO NOT EDIT DIRECTLY'
    "# Source: $SourcePath"
    "# Generated: $timestamp"
    '# Regenerate using Set-DownstreamSharedVSCodeContext'
    '# ==================================================================='
    ''
  ) -join [Environment]::NewLine

  return $header + $source
}
