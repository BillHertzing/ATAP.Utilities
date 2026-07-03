<#
.SYNOPSIS
  Formats an array as an indented string representation.
.DESCRIPTION
  Recursively converts an array to a multi-line indented string, expanding nested
  arrays and hashtables at each level. Intended for diagnostic display of complex
  data structures (e.g., inside the AllUsersAllHosts profile or diagnostic scripts).
.PARAMETER Array
  The array to format.
.PARAMETER Indent
  The current indentation level in spaces.
.PARAMETER IndentIncrement
  The number of additional spaces to add at each nesting level. Defaults to 2.
.OUTPUTS
  [string] An indented string representation of the array.
.EXAMPLE
  Write-ArrayIndented -Array @('a', 'b', @{x=1}) -Indent 0 -IndentIncrement 2
  Returns a multi-line string showing the array contents with nested structures indented.
.NOTES
  Moved from AllUsersAllHostsV7CoreProfile.ps1 into the ATAP.Utilities.PowerShell
  module as part of SC-0183 (reduce profile loading times).
.LINK
  Write-HashIndented
.LINK
  Write-KVPIndented
.LINK
  Write-EnvironmentVariablesIndented
#>
function Write-ArrayIndented {
  [CmdletBinding()]
  param (
    [Parameter(Position = 0)]
    $Array,
    [Parameter(Position = 1)]
    [int] $Indent = 0,
    [Parameter(Position = 2)]
    [int] $IndentIncrement = 2
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Starting Write-ArrayIndented'
  }
  process {
    $outstr = ''
    foreach ($item in $Array) {
      if ($null -eq $item) {
        $outstr += ' ' * $Indent + '(null)' + [Environment]::NewLine
      }
      elseif ($item -is [System.Boolean]) {
        $outstr += ' ' * $Indent + [string]$item + [Environment]::NewLine
      }
      elseif ($item -is [System.String]) {
        $outstr += ' ' * $Indent + $item + [Environment]::NewLine
      }
      elseif ($item -is [System.Array]) {
        $outstr += ' ' * $Indent + '(' + [Environment]::NewLine
        $outstr += Write-ArrayIndented -Array $item -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement
        $outstr += ' ' * $Indent + ')' + [Environment]::NewLine
      }
      elseif ($item -is [System.Collections.Hashtable]) {
        $outstr += ' ' * $Indent + '{' + [Environment]::NewLine
        $outstr += Write-HashIndented -Hash $item -InitialIndent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement
        $outstr += ' ' * $Indent + '}' + [Environment]::NewLine
      }
      else {
        $outstr += ' ' * $Indent + [string]$item + [Environment]::NewLine
      }
    }
    $outstr
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed Write-ArrayIndented'
  }
}
