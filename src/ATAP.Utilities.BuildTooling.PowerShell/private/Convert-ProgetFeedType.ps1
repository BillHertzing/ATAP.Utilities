# ToDo: Move this to a private function, and eventually into a module that implements ProGet as a plugin for a generic internal packageProvider
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
    default {
      $errorMessage = "Unknown feed type: $FeedType"
      Write-PSFMessage -Level Error -Message $errorMessage
      throw $errorMessage
    }
  }
}
