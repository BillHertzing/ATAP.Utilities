function TailLog {
  <#
  .SYNOPSIS
    Returns the newest lines from a log file and optionally waits for additions.
  .DESCRIPTION
    Uses the newest PSFramework file-system log when File is omitted and delegates safely to Get-Content without Invoke-Expression.
  .PARAMETER File
    Log file path. Defaults to the newest PSFramework file-system log.
  .PARAMETER NumLines
    Number of existing lines returned initially.
  .PARAMETER Wait
    Continue waiting for appended lines.
  .OUTPUTS
    String log lines.
  .EXAMPLE
    TailLog -NumLines 50 -Wait
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    Get-Content
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([string])]
  param(
    [string] $File,
    [ValidateRange(1, 100000)][int] $NumLines = 20,
    [switch] $Wait
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    if ([string]::IsNullOrWhiteSpace($File)) {
      $logPath = Get-PSFConfigValue -FullName PSFramework.Logging.FileSystem.LogPath
      $File = (Get-ChildItem -LiteralPath $logPath -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Log file was not found: '$File'." }
  }
  process {
    if ($PSCmdlet.ShouldProcess($File, "Read the newest $NumLines log lines")) { Get-Content -LiteralPath $File -Tail $NumLines -Wait:$Wait }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
