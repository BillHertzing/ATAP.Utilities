function Assert-ContentSummaryCaptureAcknowledgement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] [object] $Result,
    [Parameter(Mandatory = $true)] [guid] $IdempotencyKey,
    [Parameter(Mandatory = $true)] [guid] $SourceArtifactId,
    [Parameter(Mandatory = $true)] [guid] $SourceArtifactVersionId,
    [Parameter(Mandatory = $true)] [guid] $ContentSummaryId,
    [Parameter(Mandatory = $true)] [guid] $ContentSummaryVersionId
  )

  begin {
    $fn = 'Assert-ContentSummaryCaptureAcknowledgement'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $matches =
      [guid]$Result.IdempotencyKey -eq $IdempotencyKey -and
      [guid]$Result.SourceArtifactId -eq $SourceArtifactId -and
      [guid]$Result.SourceArtifactVersionId -eq $SourceArtifactVersionId -and
      [guid]$Result.ContentSummaryId -eq $ContentSummaryId -and
      [guid]$Result.ContentSummaryVersionId -eq $ContentSummaryVersionId
    if (-not $matches) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Capture acknowledgement identity mismatch.' -Tag 'Database'
      throw 'CS-SQL-002: capture acknowledgement identities do not match the request.'
    }
    return $Result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
