function Get-AllBookmarks {
  <#
  .SYNOPSIS
    Returns distinct bookmarks from all browsers and bookmark sets.
  .DESCRIPTION
    Calls Get-BrowserBookmarks and normalizes results to the common link record shape.
  .OUTPUTS
    PSCustomObject records with FullPath, Title, and URL.
  .EXAMPLE
    Get-AllBookmarks
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    Get-BrowserBookmarks
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param()
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    if (-not (Get-Command -Name Get-BrowserBookmarks -ErrorAction SilentlyContinue)) { throw 'Get-BrowserBookmarks is required.' }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess('all browser bookmark stores', 'Read bookmarks')) { return }
    foreach ($bookmark in @(Get-BrowserBookmarks '*' '*' | Sort-Object URL -Unique)) {
      [PSCustomObject]@{ FullPath = 'BrowserBookmarksAllBrowsersAllBookmarks'; Title = $bookmark.Title; URL = $bookmark.URL }
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
