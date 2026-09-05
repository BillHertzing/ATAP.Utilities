function Protect-ContentSummaryText {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string] $Text,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $RepoRelativePath,

    [scriptblock] $Redactor,

    [string[]] $AllowedExtension = @(
      '.cs', '.csproj', '.json', '.md', '.props', '.ps1', '.psd1', '.psm1',
      '.sql', '.targets', '.txt', '.xml', '.yaml', '.yml'
    ),

    [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
  )

  begin {
    $fn = 'Protect-ContentSummaryText'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $CancellationToken.ThrowIfCancellationRequested()

    $segments = @($RepoRelativePath.Split('/'))
    $invalidPath = [System.IO.Path]::IsPathRooted($RepoRelativePath) -or
      $RepoRelativePath.StartsWith('/', [StringComparison]::Ordinal) -or
      $RepoRelativePath.Contains('\', [StringComparison]::Ordinal) -or
      $RepoRelativePath -match '^[A-Za-z]:' -or
      $RepoRelativePath -match '[\x00-\x1f]' -or
      @($segments | Where-Object { [string]::IsNullOrEmpty($_) -or $_ -in @('.', '..') }).Count -gt 0

    if ($invalidPath) {
      return [pscustomobject][ordered]@{
        Status = 'Error'
        ClassificationCode = $null
        SafeText = $null
        RedactionCount = 0
        EvidenceCodes = @('source.locator.invalid')
        ErrorCode = 'CS-SRC-002'
        ErrorMessage = 'The repository-relative path is not canonical.'
      }
    }

    $extension = [System.IO.Path]::GetExtension($RepoRelativePath).ToLowerInvariant()
    $normalizedAllowedExtensions = @($AllowedExtension | ForEach-Object { $_.ToLowerInvariant() })
    if ($extension -notin $normalizedAllowedExtensions) {
      return [pscustomobject][ordered]@{
        Status = 'Excluded'
        ClassificationCode = 'excluded'
        SafeText = $null
        RedactionCount = 0
        EvidenceCodes = @('classification.unsupported-source')
        ErrorCode = 'CS-CLASS-001'
        ErrorMessage = 'The source type is excluded by classification policy.'
      }
    }

    $patterns = @(
      @{ Kind = 'canary'; Pattern = '(?i)\b(?:ATAP_)?SECRET_CANARY_[A-Z0-9_\-]{4,}\b' },
      @{ Kind = 'key'; Pattern = '-----BEGIN[A-Z ]*PRIVATE KEY-----[\s\S]*?-----END[A-Z ]*PRIVATE KEY-----' },
      @{ Kind = 'connection-string'; Pattern = '(?i)\b(?:password|pwd|accountkey|shared\s*access\s*key)\s*=\s*[^;''"\s\r\n]+' },
      @{ Kind = 'token'; Pattern = '(?i)\bbearer\s+[A-Za-z0-9._~+/\-]{16,}=*' },
      @{ Kind = 'token'; Pattern = '\bgh[pousr]_[A-Za-z0-9]{16,}' },
      @{ Kind = 'token'; Pattern = '\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}' },
      @{ Kind = 'token'; Pattern = '(?i)\bxox[baprs]-[A-Za-z0-9\-]{10,}' },
      @{ Kind = 'credential'; Pattern = '(?i)\b(?:password|passwd|pass|secret|apikey|api[_\-]?key|access[_\-]?key|client[_\-]?secret|token|credential)\s*[:=]\s*["'']?[^\s"'';,\r\n]{6,}' },
      @{ Kind = 'secret'; Pattern = '(?i)\b(?:AKIA|ASIA)[A-Z0-9]{16}\b' },
      @{ Kind = 'email'; Pattern = '(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b' },
      @{ Kind = 'ssn'; Pattern = '(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)' },
      @{ Kind = 'payment-card'; Pattern = '(?<!\d)(?:\d[ -]?){13,18}\d(?!\d)' }
    )

    try {
      if ($null -ne $Redactor) {
        $redactionResult = & $Redactor -Text $Text -CancellationToken $CancellationToken
        $CancellationToken.ThrowIfCancellationRequested()
        if ($null -eq $redactionResult) {
          throw [System.InvalidOperationException]::new('The redactor returned no result.')
        }
        if ($redactionResult -is [string]) {
          $safeText = [string]$redactionResult
          $redactionCount = [int](-not [string]::Equals($safeText, $Text, [StringComparison]::Ordinal))
        } elseif ($null -ne $redactionResult.PSObject.Properties['Text']) {
          $safeText = [string]$redactionResult.Text
          $redactionCount = if ($null -ne $redactionResult.PSObject.Properties['Count']) { [int]$redactionResult.Count } else { [int](-not [string]::Equals($safeText, $Text, [StringComparison]::Ordinal)) }
          if ($redactionCount -lt 0) {
            throw [System.InvalidOperationException]::new('The redactor returned an invalid count.')
          }
        } else {
          throw [System.InvalidOperationException]::new('The redactor result has no Text member.')
        }
      } else {
        $spans = [System.Collections.Generic.List[object]]::new()
        foreach ($pattern in $patterns) {
          $CancellationToken.ThrowIfCancellationRequested()
          foreach ($match in [regex]::Matches($Text, $pattern.Pattern)) {
            $start = $match.Index
            $end = $match.Index + $match.Length
            $overlaps = $false
            foreach ($span in $spans) {
              if ($start -lt $span.End -and $end -gt $span.Start) {
                $overlaps = $true
                break
              }
            }
            if (-not $overlaps) {
              [void]$spans.Add([pscustomobject]@{ Start = $start; End = $end; Kind = $pattern.Kind })
            }
          }
        }

        $orderedSpans = @($spans | Sort-Object -Property Start)
        $builder = [System.Text.StringBuilder]::new()
        $cursor = 0
        foreach ($span in $orderedSpans) {
          [void]$builder.Append($Text.Substring($cursor, $span.Start - $cursor))
          [void]$builder.Append(('[REDACTED:{0}]' -f $span.Kind))
          $cursor = $span.End
        }
        [void]$builder.Append($Text.Substring($cursor))
        $safeText = $builder.ToString()
        $redactionCount = $orderedSpans.Count
      }

      foreach ($pattern in $patterns) {
        $CancellationToken.ThrowIfCancellationRequested()
        if ([regex]::IsMatch($safeText, $pattern.Pattern)) {
          return [pscustomobject][ordered]@{
            Status = 'Error'
            ClassificationCode = $null
            SafeText = $null
            RedactionCount = 0
            EvidenceCodes = @('classification.redaction-verification-failed')
            ErrorCode = 'CS-CLASS-002'
            ErrorMessage = 'Redaction verification failed.'
          }
        }
      }
      if ($Text.Length -gt 0 -and $safeText.Length -eq 0) {
        return [pscustomobject][ordered]@{
          Status = 'Error'
          ClassificationCode = $null
          SafeText = $null
          RedactionCount = 0
          EvidenceCodes = @('classification.redaction-verification-failed')
          ErrorCode = 'CS-CLASS-002'
          ErrorMessage = 'Redaction verification failed.'
        }
      }

      $classificationCode = if ($redactionCount -gt 0 -or -not [string]::Equals($safeText, $Text, [StringComparison]::Ordinal)) { 'redacted' } else { 'admitted' }
      [pscustomobject][ordered]@{
        Status = 'Ready'
        ClassificationCode = $classificationCode
        SafeText = $safeText
        RedactionCount = $redactionCount
        EvidenceCodes = @(if ($classificationCode -eq 'redacted') { 'classification.redacted' } else { 'classification.admitted' })
        ErrorCode = $null
        ErrorMessage = $null
      }
    } catch [System.OperationCanceledException] {
      throw
    } catch {
      [pscustomobject][ordered]@{
        Status = 'Error'
        ClassificationCode = $null
        SafeText = $null
        RedactionCount = 0
        EvidenceCodes = @('classification.redaction-failed')
        ErrorCode = 'CS-CLASS-002'
        ErrorMessage = 'Redaction failed.'
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
