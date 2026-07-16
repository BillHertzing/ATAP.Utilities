function Get-LinksFiltered {
  <#
  .SYNOPSIS
    Returns distinct bookmarks and attributions matching a regular expression.
  .DESCRIPTION
    Combines browser bookmarks with Markdown attributions, excludes Brave search-result URLs, and deduplicates by URL.
  .PARAMETER Path
    Path scanned for Markdown attributions.
  .PARAMETER Include
    File patterns included in the attribution scan.
  .PARAMETER FindRegex
    Expression matched against title or URL.
  .PARAMETER Recurse
    Recurse while scanning attributions.
  .OUTPUTS
    PSCustomObject link records.
  .EXAMPLE
    Get-LinksFiltered -Path C:\Repos -FindRegex 'PowerShell' -Recurse
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    Get-AllBookmarks
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [string] $Path = (Get-Location).Path,
    [string[]] $Include = @('*.ps1', '*.md'),
    [Parameter(Mandatory)][regex] $FindRegex,
    [switch] $Recurse
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    foreach ($dependency in @('Get-AllBookmarks', 'Get-Attributions')) {
      if (-not (Get-Command -Name $dependency -ErrorAction SilentlyContinue)) { throw "$dependency is required." }
    }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess($Path, "Collect links matching '$FindRegex'")) { return }
    $links = @((Get-AllBookmarks) + (Get-Attributions -Path $Path -Include $Include -Recurse:$Recurse))
    $links |
      Where-Object { ($FindRegex.IsMatch([string]$_.Title) -or $FindRegex.IsMatch([string]$_.URL)) -and [string]$_.URL -notmatch 'search\.brave\.com' } |
      Sort-Object URL -Unique
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
