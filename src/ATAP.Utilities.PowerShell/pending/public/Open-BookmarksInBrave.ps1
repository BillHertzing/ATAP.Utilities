function Open-BookmarksInBrave {
  <#
  .SYNOPSIS
    Opens URL values in a new Brave window.
  .DESCRIPTION
    Accepts URL strings directly or from pipeline objects and launches one Brave process after pipeline collection completes.
  .PARAMETER Url
    URL value to open.
  .OUTPUTS
    System.Diagnostics.Process.
  .EXAMPLE
    Get-AllBookmarks | Open-BookmarksInBrave
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    Get-AllBookmarks
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([System.Diagnostics.Process])]
  param([Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('URL', 'URLs')][uri[]] $Url)
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    $urlList = [System.Collections.Generic.List[string]]::new()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
  }
  process { foreach ($item in $Url) { [void]$urlList.Add($item.AbsoluteUri) } }
  end {
    if ($urlList.Count -gt 0 -and $PSCmdlet.ShouldProcess("$($urlList.Count) URL(s)", 'Open in a new Brave window')) {
      $arguments = @('--new-window') + $urlList.ToArray()
      Start-Process -FilePath 'brave.exe' -ArgumentList $arguments -PassThru
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn"
  }
}
