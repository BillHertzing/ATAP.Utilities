function New-ContentSummaryDeterministicSafeSummaryGenerator {
  <#
  .SYNOPSIS
    Creates a deterministic generator that returns only a bounded prefix of safe input.
  #>
  [CmdletBinding()]
  param(
    [ValidateRange(1, 65536)]
    [int] $MaximumCharacters = 4096
  )

  begin {
    $fn = 'New-ContentSummaryDeterministicSafeSummaryGenerator'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $boundedLength = $MaximumCharacters
    $generator = {
      param(
        [Parameter(Mandatory = $true)]
        [string] $SafeContent,
        [Parameter(Mandatory = $true)]
        [object] $Context,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
      )
      $CancellationToken.ThrowIfCancellationRequested()
      if ([string]::IsNullOrWhiteSpace($SafeContent)) {
        throw 'CS-SUMMARY-001: safe input is empty.'
      }
      foreach ($requiredName in @('repositoryId', 'repoRelativePath', 'sourceArtifactVersionId', 'byteSha256', 'normalizedContentSha256', 'classificationCode')) {
        if ($null -eq $Context.PSObject.Properties[$requiredName]) {
          throw 'CS-SUMMARY-001: generator context is incomplete.'
        }
      }
      $trimmed = $SafeContent.Trim()
      $textElements = [Globalization.StringInfo]::GetTextElementEnumerator($trimmed)
      $builder = [System.Text.StringBuilder]::new()
      $count = 0
      while ($textElements.MoveNext()) {
        if ($count -ge $boundedLength) { break }
        [void]$builder.Append($textElements.GetTextElement())
        $count++
      }
      $CancellationToken.ThrowIfCancellationRequested()
      [pscustomobject][ordered]@{ SafeSummaryText = $builder.ToString(); SafeLocator = $null }
    }.GetNewClosure()
    return $generator
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
