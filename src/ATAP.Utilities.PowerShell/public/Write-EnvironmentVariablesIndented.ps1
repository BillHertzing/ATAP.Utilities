<#
.SYNOPSIS
  Formats all environment variables from Machine, User, and Process scopes as an indented string.
.DESCRIPTION
  Iterates over the Machine, User, and Process environment variable scopes in order,
  sorting keys alphabetically within each scope. PATH entries are split on the path
  separator and printed one per indented line. All other variables are printed as
  `key = value  [scope]`. Intended for diagnostic startup output in the AllUsersAllHosts
  profile and debug scripts.
.PARAMETER InitialIndent
  The starting indentation level in spaces. Defaults to 0.
.PARAMETER IndentIncrement
  The number of additional spaces to add for PATH sub-entries. Defaults to 2.
.OUTPUTS
  [string] A multi-line indented string listing all environment variables by scope.
.EXAMPLE
  Write-EnvironmentVariablesIndented
  Outputs all environment variables from all three scopes with default indentation.
.EXAMPLE
  Write-EnvironmentVariablesIndented -InitialIndent 4 -IndentIncrement 4
  Outputs all environment variables indented by 4 spaces, PATH sub-entries by 8.
.NOTES
  Moved from AllUsersAllHostsV7CoreProfile.ps1 into the ATAP.Utilities.PowerShell
  module as part of SC-0183 (reduce profile loading times).
.LINK
  Write-ArrayIndented
.LINK
  Write-HashIndented
.LINK
  Write-KVPIndented
#>
function Write-EnvironmentVariablesIndented {
  [CmdletBinding()]
  param (
    [Parameter(Position = 0)]
    [int] $InitialIndent = 0,
    [Parameter(Position = 1)]
    [int] $IndentIncrement = 2
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Starting Write-EnvironmentVariablesIndented'
  }
  process {
    $outstr = ''
    ('Machine', 'User', 'Process') | ForEach-Object {
      $scope = $_
      [System.Environment]::GetEnvironmentVariables($scope) | ForEach-Object {
        $envVarHashTable = $_
        $envVarHashTable.Keys | Sort-Object | ForEach-Object {
          $key = $_
          if ($key -eq 'path') {
            $outstr += ' ' * $InitialIndent + $key + ' (' + $scope + ') = ' + [Environment]::NewLine + ' ' * ($InitialIndent + $IndentIncrement) + `
            $($($($envVarHashTable[$key] -split [IO.Path]::PathSeparator) | Sort-Object) -join $([Environment]::NewLine + ' ' * ($InitialIndent + $IndentIncrement))) + [Environment]::NewLine
          } else {
            $outstr += ' ' * $InitialIndent + $key + ' = ' + $envVarHashTable[$key] + '  [' + $scope + ']' + [Environment]::NewLine
          }
        }
      }
    }
    $outstr
  }
  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed Write-EnvironmentVariablesIndented'
  }
}
