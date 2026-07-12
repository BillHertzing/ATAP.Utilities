function Open-FilteredLinksInBrave {
  <#
  .SYNOPSIS
    Opens filtered links in a new Brave window.
  .DESCRIPTION
    Resolves matching links through Get-LinksFiltered and launches Brave only after ShouldProcess approval.
  .PARAMETER SearchString
    String converted to a regular expression.
  .PARAMETER SearchRegex
    Regular expression matched against link titles and URLs.
  .PARAMETER Path
    Attribution scan path.
  .PARAMETER Include
    Attribution file patterns.
  .OUTPUTS
    System.Diagnostics.Process.
  .EXAMPLE
    Open-FilteredLinksInBrave -SearchString PowerShell -Path C:\Repos
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    Get-LinksFiltered
  #>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'String')]
  [OutputType([System.Diagnostics.Process])]
  param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'String')][string] $SearchString,
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Regex')][regex] $SearchRegex,
    [string] $Path = (Get-Location).Path,
    [string[]] $Include = @('*.ps1', '*.md')
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    if (-not (Get-Command -Name Get-LinksFiltered -ErrorAction SilentlyContinue)) { throw 'Get-LinksFiltered is required.' }
  }
  process {
    $regex = if ($PSCmdlet.ParameterSetName -eq 'Regex') { $SearchRegex } else { [regex]::new($SearchString) }
    $urls = @((Get-LinksFiltered -Path $Path -Include $Include -FindRegex $regex -Recurse).URL | Where-Object { $_ })
    if ($urls.Count -eq 0) { return }
    if ($PSCmdlet.ShouldProcess("$($urls.Count) URL(s)", 'Open in a new Brave window')) {
      $arguments = @('--new-window') + $urls
      Start-Process -FilePath 'brave.exe' -ArgumentList $arguments -PassThru
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
