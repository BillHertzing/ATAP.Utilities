<#
.SYNOPSIS
  Formats a single key-value pair as an indented string.
.DESCRIPTION
  Renders a DictionaryEntry (or compatible key-value object) as an indented line,
  recursively expanding array and hashtable values using Write-ArrayIndented and
  Write-HashIndented. Intended for diagnostic display of configuration or settings.
.PARAMETER KVP
  The key-value pair (DictionaryEntry or object with .Key and .Value properties) to format.
.PARAMETER Indent
  The current indentation level in spaces.
.PARAMETER IndentIncrement
  The number of additional spaces to add at each nesting level. Defaults to 2.
.OUTPUTS
  [string] An indented string representation of the key-value pair.
.EXAMPLE
  $ht = @{Color='Red'; Count=3}
  $ht.GetEnumerator() | ForEach-Object { Write-KVPIndented -KVP $_ -Indent 0 -IndentIncrement 2 }
.NOTES
  Moved from AllUsersAllHostsV7CoreProfile.ps1 into the ATAP.Utilities.PowerShell
  module as part of SC-0183 (reduce profile loading times).
.LINK
  Write-ArrayIndented
.LINK
  Write-HashIndented
.LINK
  Write-EnvironmentVariablesIndented
#>
function Write-KVPIndented {
  [CmdletBinding()]
  param (
    [Parameter(Position = 0)]
    $KVP,
    [Parameter(Position = 1)]
    [int] $Indent = 0,
    [Parameter(Position = 2)]
    [int] $IndentIncrement = 2
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Starting Write-KVPIndented'
  }
  process {
    $outstr = ' ' * $Indent + $KVP.Key + ' = '
    switch ($KVP.Value) {
      ({ $PSItem -is [System.Boolean] }) {
        $outstr += $KVP.Value
        break
      }
      ({ $PSItem -is [System.String] }) {
        $outstr += $KVP.Value
        break
      }
      ({ $PSItem -is [System.Array] }) {
        $outstr += '(' + [Environment]::NewLine
        $outstr += Write-ArrayIndented -Array $KVP.Value -Indent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement
        $outstr += ' ' * $Indent + ')'
        break
      }
      ({ $PSItem -is [System.Collections.Hashtable] }) {
        $outstr += '{' + [Environment]::NewLine
        $outstr += Write-HashIndented -Hash $KVP.Value -InitialIndent ($Indent + $IndentIncrement) -IndentIncrement $IndentIncrement
        $outstr += ' ' * $Indent + '}'
        break
      }
    }
    $outstr += [Environment]::NewLine
    $outstr
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed Write-KVPIndented'
  }
}
