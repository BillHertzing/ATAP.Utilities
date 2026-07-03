<#
.SYNOPSIS
  Formats a hashtable as an indented string representation.
.DESCRIPTION
  Iterates over a hashtable's key-value pairs (sorted by key) and formats each
  as an indented string via Write-KVPIndented. Intended for diagnostic display of
  configuration or settings hashtables.
.PARAMETER Hash
  The hashtable to format.
.PARAMETER InitialIndent
  The starting indentation level in spaces. Defaults to 0.
.PARAMETER IndentIncrement
  The number of additional spaces to add at each nesting level. Defaults to 2.
.OUTPUTS
  [string] An indented string representation of the hashtable.
.EXAMPLE
  Write-HashIndented -Hash @{Alpha='a'; Beta=2} -InitialIndent 0 -IndentIncrement 2
  Returns key-value pairs sorted alphabetically, each on its own indented line.
.NOTES
  Moved from AllUsersAllHostsV7CoreProfile.ps1 into the ATAP.Utilities.PowerShell
  module as part of SC-0183 (reduce profile loading times).
.LINK
  Write-ArrayIndented
.LINK
  Write-KVPIndented
.LINK
  Write-EnvironmentVariablesIndented
#>
function Write-HashIndented {
  [CmdletBinding()]
  param (
    [Parameter(Position = 0)]
    [hashtable] $Hash,
    [Parameter(Position = 1)]
    [int] $InitialIndent = 0,
    [Parameter(Position = 2)]
    [int] $IndentIncrement = 2
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Starting Write-HashIndented'
  }
  process {
    $outstr = ''
    $Hash.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
      $outstr += Write-KVPIndented -KVP $_ -Indent $InitialIndent -IndentIncrement $IndentIncrement
    }
    $outstr
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed Write-HashIndented'
  }
}
