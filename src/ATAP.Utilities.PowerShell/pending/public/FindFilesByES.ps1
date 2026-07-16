function FindFilesByES {
  <#
  .SYNOPSIS
    Searches the Everything index from PowerShell.
  .DESCRIPTION
    Invokes the Everything command-line client with a literal string or regular expression.
  .PARAMETER SearchString
    Literal Everything search expression.
  .PARAMETER SearchRegex
    Regular expression passed with Everything's regex prefix.
  .OUTPUTS
    String paths returned by Everything.
  .EXAMPLE
    FindFilesByES -SearchString 'conflicted'
  .NOTES
    Moved from CurrentUserAllHostsV7CoreProfile.ps1 in Task 12.49.e.
  .LINK
    https://www.voidtools.com/support/everything/command_line_interface/
  #>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'String')]
  [OutputType([string])]
  param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'String')]
    [ValidateNotNullOrEmpty()]
    [string] $SearchString,
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Regex')]
    [regex] $SearchRegex
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn"
    $esCommand = Get-Command -Name 'es.exe' -ErrorAction Stop
  }
  process {
    $query = if ($PSCmdlet.ParameterSetName -eq 'Regex') { "regex:$($SearchRegex.ToString())" } else { $SearchString }
    if ($PSCmdlet.ShouldProcess($query, 'Search the Everything index')) { & $esCommand.Source $query }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" }
}
