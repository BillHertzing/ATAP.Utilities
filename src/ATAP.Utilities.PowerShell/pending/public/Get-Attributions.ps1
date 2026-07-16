function Get-Attributions {
  <#
  .SYNOPSIS
    Extracts Markdown links from source and documentation files.
  .DESCRIPTION
    Reads matching files with read/write sharing and returns each Markdown link with its source path.
  .PARAMETER Path
    File or wildcard path to scan.
  .PARAMETER Include
    File patterns included in the scan.
  .PARAMETER Recurse
    Recurse below Path.
  .OUTPUTS
    PSCustomObject records with FullPath, Title, and URL.
  .EXAMPLE
    Get-Attributions -Path C:\Repos\Project -Include '*.md' -Recurse
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    about_Regular_Expressions
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [string] $Path = (Get-Location).Path,
    [string[]] $Include = @('*.ps1', '*.md'),
    [switch] $Recurse
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    $findRegex = [regex]'\[\s*(?<Title>.*?)\s*\]\s*\(\s*(?<URL>.*?)\s*\)'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
  }
  process {
    if (-not $PSCmdlet.ShouldProcess($Path, 'Scan files for Markdown links')) { return }
    foreach ($file in @(Get-ChildItem -Path $Path -File -Include $Include -Recurse:$Recurse -ErrorAction Stop)) {
      $stream = [IO.FileStream]::new($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
      $reader = [IO.StreamReader]::new($stream)
      try {
        while (-not $reader.EndOfStream) {
          foreach ($match in $findRegex.Matches($reader.ReadLine())) {
            [PSCustomObject]@{ FullPath = $file.FullName; Title = $match.Groups['Title'].Value; URL = $match.Groups['URL'].Value }
          }
        }
      } finally { $reader.Dispose(); $stream.Dispose() }
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
