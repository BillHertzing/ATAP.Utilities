function Get-LinksFromDrafts {
  <#
  .SYNOPSIS
    Extracts subject and URL pairs from a Gmail Drafts mbox export.
  .DESCRIPTION
    Streams an mbox file with read/write sharing and pairs the latest Subject header with the next HTTP URL line.
  .PARAMETER Path
    Drafts mbox file path.
  .OUTPUTS
    PSCustomObject records with FullPath, Title, and URL.
  .EXAMPLE
    Get-LinksFromDrafts -Path C:\Exports\Drafts.mbox
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    https://datatracker.ietf.org/doc/html/rfc4155
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param([Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string] $Path)
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    $subjectRegex = [regex]'^Subject:\s*(?<Subject>.*?)$'
    $urlRegex = [regex]'(?i)^(?<URL>https?://.+)'
  }
  process {
    if (-not $PSCmdlet.ShouldProcess($Path, 'Read links from the mbox export')) { return }
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    $subject = $null
    try {
      while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        $match = $subjectRegex.Match($line)
        if ($match.Success) { $subject = $match.Groups['Subject'].Value; continue }
        $match = $urlRegex.Match($line)
        if ($subject -and $match.Success) {
          [PSCustomObject]@{ FullPath = $Path; Title = $subject; URL = $match.Groups['URL'].Value }
          $subject = $null
        }
      }
    } finally { $reader.Dispose(); $stream.Dispose() }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
