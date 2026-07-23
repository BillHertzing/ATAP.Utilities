# Private helper that translates ATAP feed type names to ProGet feed type names.
# ProGet uses different strings from ATAP.Utilities to represent feed types
function Convert-ProGetFeedType {
  param (
    [string]$FeedType
  )

  switch ($FeedType.ToLowerInvariant()) {
    'nuget' { return 'nuget' }
    'chocolatey' { return 'chocolatey' }
    'chocolateyget' { return 'chocolatey' }
    'powershell' { return 'powershell' }
    'powershellget' { return 'powershell' }
    'psresourceget' { return 'powershell' }
    'universal' { return 'universal' }
    'upack' { return 'universal' }
    default {
      $errorMessage = "Unknown feed type: $FeedType"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }
}
