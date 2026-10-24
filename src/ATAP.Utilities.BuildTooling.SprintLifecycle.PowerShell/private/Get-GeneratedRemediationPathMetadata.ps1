function Get-GeneratedRemediationPathMetadata {
  <#
  .SYNOPSIS
    Reads final-component no-follow metadata for a caller-guarded local path.
  .DESCRIPTION
    Internal TreeCensus adapter. Caller must validate ancestors before passing a
    descendant. This does not establish identity or prevent races. Source mode
    only: unknown preloaded types are refused. No native timeout is promised.
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='Metadata is the approved mass-noun API name.')]
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$LiteralPath)
  begin {
    # Inspect keys only before loader commands; never invoke default scriptblocks.
    foreach ($key in $PSDefaultParameterValues.Keys) {
      if ([string]$key -ieq 'Disabled') { continue }
      $parts = ([string]$key).Split(':', 2)
      if ($parts.Count -ne 2) { throw 'Unsupported ambient defaults.' }
      if ($parts[1].Trim() -in @('Encoding', 'Settings')) { continue }
      $pattern = [Management.Automation.WildcardPattern]::new($parts[0].Trim(), [Management.Automation.WildcardOptions]::IgnoreCase)
      foreach ($command in @('Add-Type', 'Microsoft.PowerShell.Utility\Add-Type', 'Get-FileHash', 'Microsoft.PowerShell.Utility\Get-FileHash',
        'Get-Variable', 'gv', 'Microsoft.PowerShell.Utility\Get-Variable',
        'Join-Path', 'Microsoft.PowerShell.Management\Join-Path', 'Get-GeneratedRemediationPathMetadata')) {
        if ($pattern.IsMatch($command)) { throw 'Applicable ambient adapter/loader defaults refused.' }
      }
    }
    if (-not $IsWindows -or $LiteralPath -notmatch '^[A-Za-z]:[\\/]' -or $LiteralPath.Substring(2).Contains(':') -or
      $LiteralPath -match '[\x00-\x1f\x7f<>"|?*]' -or $LiteralPath -match '(^|[\\/])\.\.?(?:[\\/]|$)') { throw 'Expected validated local path.' }
    foreach ($segment in ($LiteralPath.Substring(3).TrimEnd('\','/') -split '[\\/]')) {
      if ($segment -match '[ .]$' -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])(?:\.|$)') { throw 'Ambiguous local path.' }
    }
    $typePath = Join-Path $PSScriptRoot '../lib/GeneratedRemediationPathMetadata.types.ps1'
    $sourceHash = (Get-FileHash -LiteralPath $typePath -Algorithm SHA256 -ErrorAction Stop).Hash
    $nativeType = 'ATAP.GeneratedRemediation.NativePathMetadataV1' -as [type]
    if (-not $nativeType) {
      $loadedTypes = @(. $typePath)
      $nativeType = 'ATAP.GeneratedRemediation.NativePathMetadataV1' -as [type]
      if ($null -eq $nativeType -or -not ($loadedTypes -contains $nativeType)) { throw 'Native type load did not return expected type.' }
      $script:GeneratedRemediationNativeProvenanceV1 = [pscustomobject]@{Assembly=$nativeType.Assembly;SourceHash=$sourceHash;Type=$nativeType}
    }
    if (-not (Get-Variable -Name GeneratedRemediationNativeProvenanceV1 -Scope Script -ErrorAction SilentlyContinue) -or
      -not [object]::ReferenceEquals($script:GeneratedRemediationNativeProvenanceV1.Assembly, $nativeType.Assembly) -or
      -not [object]::ReferenceEquals($script:GeneratedRemediationNativeProvenanceV1.Type, $nativeType) -or
      $script:GeneratedRemediationNativeProvenanceV1.SourceHash -cne $sourceHash -or
      [Runtime.InteropServices.Marshal]::SizeOf([Activator]::CreateInstance(('ATAP.GeneratedRemediation.AttributeTagInfoV1' -as [type]))) -ne 8 -or
      $nativeType::DesiredAccess -ne 0 -or $nativeType::ShareMode -ne 7 -or $nativeType::Disposition -ne 3 -or
      $nativeType::Flags -ne 0x02200000 -or $nativeType::InformationClass -ne 9) { throw 'Untrusted or incompatible loaded native type.' }
  }
  process {
    $normalized = [IO.Path]::GetFullPath($LiteralPath).Replace('/', '\')
    $nativeType::Read(('\\?\' + $normalized))
  }
  end { }
}
