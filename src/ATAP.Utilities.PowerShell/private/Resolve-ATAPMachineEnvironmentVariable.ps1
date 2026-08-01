<#
.SYNOPSIS
Resolves a named environment variable, falling back from Process scope to Machine
scope when an agent-spawned shell does not inherit it.

.DESCRIPTION
Agent-spawned shells (Claude Code, Codex, and similar automation) frequently do not
inherit the interactive user session's Process-scope environment, so well-known
machine variables such as 'windir' or 'ProgramData' can read as empty even though
they are correctly set at Machine scope. Resolve-ATAPMachineEnvironmentVariable
checks Process scope first (so an explicit override in the current process always
wins), then falls back to Machine scope, and finally to -DefaultValue.

.PARAMETER Name
The environment variable name to resolve, for example 'windir' or 'ProgramData'.

.PARAMETER DefaultValue
Value returned when the variable is unresolved (empty/whitespace) in both scopes.
Defaults to $null.

.PARAMETER FunctionName
Caller name used for Write-PSFMessage attribution. Defaults to this function's own
name so a direct call still logs correctly.

.PARAMETER ModuleName
Caller module name used for Write-PSFMessage attribution.

.OUTPUTS
System.String -- the resolved value, or -DefaultValue when unresolved in either scope.

.EXAMPLE
Resolve-ATAPMachineEnvironmentVariable -Name 'windir'

Returns 'C:\Windows' even when $env:windir is empty in the current (agent) process,
by falling back to the Machine-scope value.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
Private helper. Not exported. Implements Sprint 0013 Task 13.20.e.

.LINK
Register-ProfiledRemotingEndpoint
#>
function Resolve-ATAPMachineEnvironmentVariable {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [Parameter()]
    [AllowNull()]
    [string] $DefaultValue,

    [Parameter()]
    [string] $FunctionName = 'Resolve-ATAPMachineEnvironmentVariable',

    [Parameter()]
    [string] $ModuleName = 'ATAP.Utilities.PowerShell'
  )

  foreach ($scope in @('Process', 'Machine')) {
    $value = [System.Environment]::GetEnvironmentVariable($Name, $scope)
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      if ($scope -eq 'Machine' -and (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
        Write-PSFMessage -FunctionName $FunctionName -ModuleName $ModuleName -Level Debug `
          -Message "Environment variable '$Name' was empty in Process scope (agent-shell inheritance gap); resolved from Machine scope instead." `
          -Tag 'EnvironmentResolution'
      }
      return $value
    }
  }

  return $DefaultValue
}

function Get-ATAPWindowsSpecialFolderRoot {
  <#
  .SYNOPSIS
  Resolves the operating system's Windows directory without relying on
  windir/SystemRoot environment-variable expansion.

  .DESCRIPTION
  Machine-scope windir is commonly stored as `%SystemRoot%`. If an agent shell
  is missing both process aliases and Machine SystemRoot is absent, the .NET
  Machine-scope environment API cannot expand windir. The Windows special-folder
  API remains independent of those aliases. This helper accepts its result only
  when it names an existing directory; otherwise it returns null so callers fail
  closed.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param()

  $windowsRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
  if ([string]::IsNullOrWhiteSpace($windowsRoot)) {
    return $null
  }
  if (-not (Test-Path -LiteralPath $windowsRoot -PathType Container)) {
    return $null
  }
  return [IO.Path]::GetFullPath($windowsRoot)
}
