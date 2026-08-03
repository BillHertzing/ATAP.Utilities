<#
.SYNOPSIS
Builds the ordered list of package-download URIs to try for a module version.

.DESCRIPTION
Endpoint order is load-bearing on the ATAP ProGet server:

  <feed>/package/<name>/<version>          works
  <feed>/api/v2/package/<name>/<version>   404 / "OData method is not implemented"

The 2026-07-25 standalone installer emitted ONLY the /api/v2 form, so every download failed against
the ProGet the ATAP feeds actually run on (found while deploying SprintLifecycle 0.1.6). The direct
form is therefore tried first, with /api/v2 retained as a fallback for a NuGet server that does
implement OData v2.

A utat01 base also yields a localhost candidate first: session evidence shows the loopback endpoint
reachable when the host name is not.

.PARAMETER BaseFeedUrl
Feed base URL, with or without a trailing slash or an explicit /api/v2 suffix.

.PARAMETER ModuleName
Package id.

.PARAMETER RequiredVersion
Exact package version.

.OUTPUTS
System.String[] in try-order.

.EXAMPLE
Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl 'https://localhost:50000/nuget/powershellget-stable' -ModuleName 'M' -RequiredVersion '1.0.0'

.NOTES
Task 13.76.c. Promoted from the _Planning CodexMisstepFixes standalone installer.
#>
function Get-ATAPModuleDownloadCandidateUris {
  [CmdletBinding()]
  [OutputType([string[]])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseFeedUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredVersion
  )

  begin {
    $fn = 'Get-ATAPModuleDownloadCandidateUris'
    $mn = 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $normalizedBase = $BaseFeedUrl.Trim().TrimEnd('/')
    $candidates = [System.Collections.Generic.List[string]]::new()
    $ordered = [System.Collections.Generic.List[string]]::new()

    # A malformed URI is a caller error, not something to paper over: let it surface.
    $uri = [uri]$normalizedBase
    if ($uri.Host -ieq 'utat01') {
      $builder = [System.UriBuilder]::new($uri)
      $builder.Host = 'localhost'
      $fallback = $builder.Uri.AbsoluteUri.TrimEnd('/')
      if ($fallback -notin $ordered) { $ordered.Add($fallback) }
    }
    if ($normalizedBase -notin $ordered) { $ordered.Add($normalizedBase) }

    foreach ($base in $ordered) {
      $baseNoTrailing = $base.TrimEnd('/')
      if ($baseNoTrailing -match '/api/v2$') {
        # Caller supplied an explicit OData base; honor it, then try it without the suffix.
        $candidates.Add("$baseNoTrailing/package/$ModuleName/$RequiredVersion")
        $candidates.Add("$($baseNoTrailing -replace '/api/v2$', '')/package/$ModuleName/$RequiredVersion")
        continue
      }
      $candidates.Add("$baseNoTrailing/package/$ModuleName/$RequiredVersion")
      $candidates.Add("$baseNoTrailing/api/v2/package/$ModuleName/$RequiredVersion")
    }

    return $candidates.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
