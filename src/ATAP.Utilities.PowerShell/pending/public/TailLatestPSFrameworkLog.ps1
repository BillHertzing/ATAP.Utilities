function TailLatestPSFrameworkLog {
  <#
  .SYNOPSIS
    Returns entries from the newest PSFramework file-system logs.
  .DESCRIPTION
    Reads newest-first log files until the requested line count is available,
    parses the CSV records, and optionally filters their Tags field.
  .PARAMETER Lines
    Maximum number of newest log lines to return.
  .PARAMETER IncludeTags
    Tags of which at least one must match.
  .PARAMETER ExcludeTags
    Tags that exclude a record when matched.
  .PARAMETER LogPath
    PSFramework file-system log directory.
  .OUTPUTS
    PSCustomObject log records.
  .EXAMPLE
    TailLatestPSFrameworkLog -Lines 50 -IncludeTags RestCall
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    Get-PSFConfigValue
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [ValidateRange(1, 100000)]
    [int] $Lines = 100,
    [string[]] $IncludeTags,
    [string[]] $ExcludeTags,
    [string] $LogPath = (Join-Path $env:APPDATA 'PowerShell\PSFramework\Logs')
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    $headers = @('HostName', 'Timestamp', 'LogLevel', 'Message', 'Category', 'ScriptName', 'FunctionName', 'FilePath', 'LineNumber', 'Tags', 'Unused1', 'Unused2', 'CorrelationId')
  }
  process {
    if (-not (Test-Path -LiteralPath $LogPath -PathType Container)) {
      throw "PSFramework log directory was not found: '$LogPath'."
    }
    if (-not $PSCmdlet.ShouldProcess($LogPath, "Read the newest $Lines PSFramework log lines")) { return }
    $content = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $LogPath -File | Sort-Object LastWriteTime -Descending)) {
      $fileContent = @(Get-Content -LiteralPath $file.FullName -ErrorAction Stop)
      $content.InsertRange(0, [string[]]$fileContent)
      if ($content.Count -ge $Lines) { break }
    }
    $records = @($content | Select-Object -Last $Lines | ConvertFrom-Csv -Header $headers)
    if ($IncludeTags) { $records = @($records | Where-Object { $tagText = [string]$_.Tags; @($IncludeTags | Where-Object { $tagText -match [regex]::Escape($_) }).Count -gt 0 }) }
    if ($ExcludeTags) { $records = @($records | Where-Object { $tagText = [string]$_.Tags; @($ExcludeTags | Where-Object { $tagText -match [regex]::Escape($_) }).Count -eq 0 }) }
    $records
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
