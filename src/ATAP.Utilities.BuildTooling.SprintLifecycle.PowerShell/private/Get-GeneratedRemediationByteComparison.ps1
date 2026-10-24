function Get-GeneratedRemediationByteComparison {
  <#
  .SYNOPSIS
    Compares default-data bytes at one literal path in a supplied repository pair.
  .DESCRIPTION
    Read-only observation with Equal, Different or Hold status. The supplied
    roots and repository label are a lexical binding, not verified Git identity.
    Uses bounded buffers and read-sharing handles; metadata is checked again
    before returning. Non-atomic observations cannot exclude ABA, hard-link
    aliases or replacement with identical metadata. Producers must be quiet.
    No ADS, custody, recovery, inventory or removal approval is established.
  .PARAMETER StableRoot
    Absolute local NTFS stable root whose leaf matches RepositoryName.
  .PARAMETER SprintRoot
    Absolute local NTFS sprint root whose leaf begins RepositoryName-wt-.
  .PARAMETER RepositoryName
    Supplied corresponding repository label; not discovered or Git-verified.
  .PARAMETER RelativePath
    One canonical forward-slash file path below _generated in BOTH roots.
  .OUTPUTS
    One envelope; DefaultDataEqual is true, false, or null for Hold.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][string]$StableRoot,
    [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][string]$SprintRoot,
    [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][string]$RepositoryName,
    [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][string]$RelativePath
  )
  begin {
    $fn = 'Get-GeneratedRemediationByteComparison'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
      Import-Module PSFramework -ErrorAction Stop
    }
  }
  process {
    $result = [pscustomobject]@{
      Status = 'Hold'; Reason = 'ObservationFailed'; DefaultDataEqual = $null
      Binding = $null; BytesCompared = 0L; StableSHA256 = $null; SprintSHA256 = $null
      Approved = $false; ReadyForRemoval = $false; CustodyVerified = $false
      NamedStreamsVerified = $false; RepositoryIdentityVerified = $false
      Errors = @()
      Limitations = @('Default data only; no ADS or custody proof.',
        'Supplied repository binding is not Git identity.',
        'Non-atomic metadata observations; ABA, hard-link aliases and identical replacement can be missed.',
        'The witness expires when either input changes; no persistent approval.')
    }
    $stableStream = $null
    $sprintStream = $null
    $digest = $null
    function assertComparisonSegment([string]$Segment) {
      if (-not $Segment -or $Segment -in @('.', '..') -or
        $Segment -match '[\x00-\x1f\x7f<>:"|?*]' -or $Segment -match '[ .]$' -or
        $Segment -match '^(?i:CON|PRN|AUX|NUL|COM[0-9\u00b9\u00b2\u00b3]|LPT[0-9\u00b9\u00b2\u00b3])(?:\.|$)' -or
        $Segment -ieq '.git') { throw 'Invalid or ambiguous comparison path segment.' }
    }
    function getComparisonRoot([string]$Root) {
      if (-not $IsWindows -or $Root -notmatch '\A[A-Za-z]:[\\/]' -or
        $Root -match '[\x00-\x1f\x7f]' -or $Root.Substring(2).Contains(':')) {
        throw 'Expected an absolute local Windows root.'
      }
      $tail = $Root.Substring(3).TrimEnd('\', '/')
      if (-not $tail -or ($tail.Contains('\') -and $tail.Contains('/'))) { throw 'Ambiguous comparison root.' }
      foreach ($segment in ($tail -split '[\\/]')) { assertComparisonSegment $segment }
      $drive = [IO.DriveInfo]::new($Root.Substring(0, 3))
      if ($drive.DriveType -ne [IO.DriveType]::Fixed -or $drive.DriveFormat -ne 'NTFS') {
        throw 'Only fixed local NTFS is supported.'
      }
      [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    }
    function getComparisonState([string]$Root) {
      $current = [IO.Path]::GetPathRoot($Root)
      $segments = @($Root.Substring($current.Length) -split '[\\/]') + @($RelativePath.Split('/'))
      $node = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      foreach ($segment in $segments) {
        if (-not $node.PSIsContainer) { throw 'Non-directory comparison ancestor.' }
        if (($node.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $null -ne $node.LinkTarget) {
          throw 'Redirecting comparison ancestor refused.'
        }
        if ($current.Length -gt $Root.Length) {
          $markers = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop | Where-Object Name -IEQ '.git')
          if ($markers.Count) { throw 'Nested repository boundary refused.' }
        }
        $current = Join-Path $current $segment
        $node = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      }
      if ($node.PSIsContainer -or ($node.Attributes -band ([IO.FileAttributes]::ReparsePoint -bor
        [IO.FileAttributes]::Device -bor [IO.FileAttributes]::Encrypted -bor [IO.FileAttributes]::Offline))) {
        throw 'Unsupported comparison file shape or provider state.'
      }
      [pscustomobject]@{
        Path = $current; Bytes = [long]$node.Length
        Creation = $node.CreationTimeUtc.Ticks; Written = $node.LastWriteTimeUtc.Ticks
        Attributes = [long]$node.Attributes
      }
    }
    try {
      assertComparisonSegment $RepositoryName
      if (-not $RelativePath.StartsWith('_generated/', [StringComparison]::Ordinal) -or $RelativePath.Contains('\')) {
        throw 'Expected one canonical _generated/ relative path.'
      }
      foreach ($segment in $RelativePath.Split('/')) { assertComparisonSegment $segment }
      $stable = getComparisonRoot $StableRoot
      $sprint = getComparisonRoot $SprintRoot
      if ([IO.Path]::GetFileName($stable) -ine $RepositoryName -or
        -not [IO.Path]::GetFileName($sprint).StartsWith($RepositoryName + '-wt-', [StringComparison]::OrdinalIgnoreCase) -or
        $stable -ieq $sprint -or $sprint.StartsWith($stable + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $stable.StartsWith($sprint + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Supplied repository pair binding refused.' }
      $result.Binding = [pscustomobject]@{ RepositoryName = $RepositoryName; StableRoot = $stable; SprintRoot = $sprint; RelativePath = $RelativePath }
      $beforeStable = getComparisonState $stable
      $beforeSprint = getComparisonState $sprint
      $stableStream = [IO.File]::Open($beforeStable.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      $sprintStream = [IO.File]::Open($beforeSprint.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
      if ($stableStream.Length -ne $beforeStable.Bytes -or $sprintStream.Length -ne $beforeSprint.Bytes) { throw 'Comparison length drift.' }
      $equal = $stableStream.Length -eq $sprintStream.Length
      $left = [byte[]]::new(65536)
      $right = [byte[]]::new(65536)
      $digest = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
      while ($equal -and $stableStream.Position -lt $stableStream.Length) {
        $count = [int][Math]::Min($left.Length, $stableStream.Length - $stableStream.Position)
        $stableStream.ReadExactly($left, 0, $count)
        $sprintStream.ReadExactly($right, 0, $count)
        for ($i = 0; $i -lt $count; $i++) {
          $result.BytesCompared++
          if ($left[$i] -ne $right[$i]) { $equal = $false; break }
        }
        if ($equal) { $digest.AppendData($left, 0, $count) }
      }
      $afterStable = getComparisonState $stable
      $afterSprint = getComparisonState $sprint
      if (($beforeStable | ConvertTo-Json -Compress) -cne ($afterStable | ConvertTo-Json -Compress) -or
        ($beforeSprint | ConvertTo-Json -Compress) -cne ($afterSprint | ConvertTo-Json -Compress) -or
        $stableStream.Length -ne $beforeStable.Bytes -or $sprintStream.Length -ne $beforeSprint.Bytes) {
        throw 'Comparison metadata drift.'
      }
      $result.DefaultDataEqual = $equal
      if ($equal) {
        $result.Status = 'Equal'; $result.Reason = 'DefaultDataBytesEqual'
        $result.StableSHA256 = [Convert]::ToHexString($digest.GetHashAndReset())
        $result.SprintSHA256 = $result.StableSHA256
      } else { $result.Status = 'Different'; $result.Reason = 'DefaultDataBytesDiffer' }
    } catch {
      $result.Status = 'Hold'; $result.Reason = 'MissingUnsupportedUnreadableOrDrift'
      $result.DefaultDataEqual = $null
      $result.Errors = @($_.Exception.Message)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Byte comparison held; no removal readiness established.'
    } finally {
      if ($null -ne $digest) { $digest.Dispose() }
      if ($null -ne $sprintStream) { $sprintStream.Dispose() }
      if ($null -ne $stableStream) { $stableStream.Dispose() }
    }
    $result
  }
  end { }
}
