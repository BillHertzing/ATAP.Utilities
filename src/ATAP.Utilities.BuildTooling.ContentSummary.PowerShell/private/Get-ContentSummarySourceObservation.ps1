function Get-ContentSummarySourceObservation {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [byte[]] $SourceBytes,

    [Parameter(Mandatory = $true)]
    [ValidateSet('utf-8', 'utf-8-bom', 'us-ascii', 'utf-16le', 'utf-16be')]
    [string] $EncodingCode,

    [ValidatePattern('^[0-9a-f]{64}$')]
    [string] $ExpectedByteSha256,

    [ValidatePattern('^[0-9a-f]{64}$')]
    [string] $ExpectedNormalizedContentSha256,

    [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
  )

  begin {
    $fn = 'Get-ContentSummarySourceObservation'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $CancellationToken.ThrowIfCancellationRequested()

    $preambleLength = 0
    $decoder = switch ($EncodingCode) {
      'utf-8' {
        if ($SourceBytes.Length -ge 3 -and $SourceBytes[0] -eq 0xEF -and $SourceBytes[1] -eq 0xBB -and $SourceBytes[2] -eq 0xBF) {
          throw [System.IO.InvalidDataException]::new('CS-REQ-001: utf-8 input must not contain a BOM.')
        }
        [System.Text.UTF8Encoding]::new($false, $true)
      }
      'utf-8-bom' {
        if ($SourceBytes.Length -lt 3 -or $SourceBytes[0] -ne 0xEF -or $SourceBytes[1] -ne 0xBB -or $SourceBytes[2] -ne 0xBF) {
          throw [System.IO.InvalidDataException]::new('CS-REQ-001: utf-8-bom input must contain the UTF-8 BOM.')
        }
        $preambleLength = 3
        [System.Text.UTF8Encoding]::new($false, $true)
      }
      'us-ascii' {
        if (@($SourceBytes | Where-Object { $_ -gt 0x7F }).Count -gt 0) {
          throw [System.IO.InvalidDataException]::new('CS-REQ-001: us-ascii input contains a non-ASCII byte.')
        }
        [System.Text.ASCIIEncoding]::new()
      }
      'utf-16le' {
        if ($SourceBytes.Length -ge 2 -and $SourceBytes[0] -eq 0xFF -and $SourceBytes[1] -eq 0xFE) {
          $preambleLength = 2
        }
        [System.Text.UnicodeEncoding]::new($false, $false, $true)
      }
      'utf-16be' {
        if ($SourceBytes.Length -ge 2 -and $SourceBytes[0] -eq 0xFE -and $SourceBytes[1] -eq 0xFF) {
          $preambleLength = 2
        }
        [System.Text.UnicodeEncoding]::new($true, $false, $true)
      }
    }

    $CancellationToken.ThrowIfCancellationRequested()
    try {
      $text = $decoder.GetString($SourceBytes, $preambleLength, $SourceBytes.Length - $preambleLength)
    } catch {
      throw [System.IO.InvalidDataException]::new('CS-REQ-001: source bytes are invalid for the declared encoding.')
    }

    $crlfCount = [regex]::Matches($text, [regex]::Escape([string][char]13 + [char]10)).Count
    $crOnlyCount = [regex]::Matches($text, ([string][char]13 + '(?!' + [string][char]10 + ')')).Count
    $lfOnlyCount = [regex]::Matches($text, ('(?<!' + [string][char]13 + ')' + [string][char]10)).Count
    $lineEndingKinds = @($crlfCount, $crOnlyCount, $lfOnlyCount | Where-Object { $_ -gt 0 }).Count
    $lineEndingCode = if ($lineEndingKinds -eq 0) {
      'none'
    } elseif ($lineEndingKinds -gt 1) {
      'mixed'
    } elseif ($crlfCount -gt 0) {
      'crlf'
    } elseif ($crOnlyCount -gt 0) {
      'cr'
    } else {
      'lf'
    }
    $finalNewline = $text.EndsWith([string][char]10, [StringComparison]::Ordinal) -or $text.EndsWith([string][char]13, [StringComparison]::Ordinal)
    $normalizedText = $text.Replace(([string][char]13 + [char]10), [string][char]10).Replace([string][char]13, [string][char]10)
    $byteSha256 = Get-ContentSummarySha256 -Bytes $SourceBytes
    $normalizedContentSha256 = Get-ContentSummarySha256 -Text $normalizedText

    if ($ExpectedByteSha256 -and -not [string]::Equals($ExpectedByteSha256, $byteSha256, [StringComparison]::Ordinal)) {
      throw [System.IO.InvalidDataException]::new('CS-HASH-001: supplied byte hash does not match the source bytes.')
    }
    if ($ExpectedNormalizedContentSha256 -and -not [string]::Equals($ExpectedNormalizedContentSha256, $normalizedContentSha256, [StringComparison]::Ordinal)) {
      throw [System.IO.InvalidDataException]::new('CS-HASH-001: supplied normalized hash does not match normalized source content.')
    }

    [pscustomobject][ordered]@{
      Text = $text
      NormalizedText = $normalizedText
      ByteSha256 = $byteSha256
      NormalizedContentSha256 = $normalizedContentSha256
      ByteCount = [long]$SourceBytes.LongLength
      EncodingCode = $EncodingCode
      LineEndingCode = $lineEndingCode
      FinalNewline = $finalNewline
      BomExcluded = ($preambleLength -gt 0)
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
