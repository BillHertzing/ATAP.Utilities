<#
.SYNOPSIS
Returns the first reachable package-download URI for a module version.

.DESCRIPTION
Probes the ordered candidates from Get-ATAPModuleDownloadCandidateUris with a HEAD request and
returns the first that answers. Throws when none is reachable, so a feed outage or a wrong feed name
fails before anything is downloaded or written.

.PARAMETER FeedUrl
Feed base URL.

.PARAMETER ModuleName
Package id.

.PARAMETER RequiredVersion
Exact package version.

.OUTPUTS
System.String

.EXAMPLE
Get-ATAPModuleDownloadUri -FeedUrl $feed -ModuleName 'M' -RequiredVersion '1.0.0'

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Get-ATAPModuleDownloadUri {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FeedUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredVersion
  )

  begin {
    $fn = 'Get-ATAPModuleDownloadUri'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $downloadCandidates = Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl $FeedUrl -ModuleName $ModuleName -RequiredVersion $RequiredVersion
    foreach ($downloadUri in $downloadCandidates) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $downloadUri" -Tag 'WebRequestCall'
      $reachable = Test-ATAPModuleEndpointReachable -Uri $downloadUri
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $downloadUri (reachable=$reachable)" -Tag 'WebRequestCall'
      if ($reachable) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Using download URI: $downloadUri"
        return $downloadUri
      }
    }

    throw "No reachable download URI was found for $ModuleName $RequiredVersion. Tried: $($downloadCandidates -join ', ')"
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
