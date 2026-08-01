<#
.SYNOPSIS
Resolves the machine-state root directory used for Register-ProfiledRemotingEndpoint's
local idempotency/runtime marker files.

.DESCRIPTION
Registration-hash and runtime marker files must never live inside a Git worktree --
doing so pollutes the tree, defeats clean-tree gates, and (for the local case) makes
Register-ProfiledRemotingEndpoint idempotency incorrectly follow whichever worktree
happens to be checked out. This helper resolves a stable, machine-scoped root under
ProgramData for that purpose.

Resolution order:
  1. $env:ProgramData (Process scope, then Machine scope via
     Resolve-ATAPMachineEnvironmentVariable -- an agent-spawned shell may not inherit
     Process-scope ProgramData even though it is set at Machine scope).
  2. Derived from the resolved 'windir' environment variable (Process scope, then
     Machine scope): ProgramData is conventionally a sibling directory of %windir% on
     the same system drive (e.g. C:\Windows and C:\ProgramData), so the drive
     qualifier of a resolved windir value is used to build 'C:\ProgramData' as a
     last-resort anchor when ProgramData itself is unresolved in both scopes.
  3. Neither resolves: throws rather than silently falling back to a path under the
     current working directory, which could be a Git worktree.

.OUTPUTS
System.String -- '<ProgramData>\ATAP\RemotingEndpoints', not created on disk by this
function; callers are responsible for creating the directory before writing into it.

.EXAMPLE
Get-ProfiledRemotingMachineStateRoot

Returns 'C:\ProgramData\ATAP\RemotingEndpoints' on a normal workstation, even from an
agent shell whose Process-scope environment omits ProgramData and windir.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
Private helper for Register-ProfiledRemotingEndpoint / Unregister-ProfiledRemotingEndpoint.
Not exported. Implements Sprint 0013 Task 13.20.e.

.LINK
Register-ProfiledRemotingEndpoint
#>
function Get-ProfiledRemotingMachineStateRoot {
  [CmdletBinding()]
  [OutputType([string])]
  param()

  $fn = 'Get-ProfiledRemotingMachineStateRoot'
  $mn = 'ATAP.Utilities.PowerShell'

  if (-not (Get-Command -Name 'Resolve-ATAPMachineEnvironmentVariable' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'Resolve-ATAPMachineEnvironmentVariable.ps1')
  }

  $programData = Resolve-ATAPMachineEnvironmentVariable -Name 'ProgramData' -FunctionName $fn -ModuleName $mn
  if (-not [string]::IsNullOrWhiteSpace($programData)) {
    return (Join-Path $programData 'ATAP\RemotingEndpoints')
  }

  $windir = Resolve-ATAPMachineEnvironmentVariable -Name 'windir' -FunctionName $fn -ModuleName $mn
  if (-not [string]::IsNullOrWhiteSpace($windir)) {
    $driveRoot = [System.IO.Path]::GetPathRoot($windir)
    if (-not [string]::IsNullOrWhiteSpace($driveRoot)) {
      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "ProgramData was unresolved in Process and Machine scope; deriving the machine-state root from windir ('$windir') instead." `
          -Tag 'EnvironmentResolution'
      }
      return (Join-Path (Join-Path $driveRoot 'ProgramData') 'ATAP\RemotingEndpoints')
    }
  }

  throw 'Get-ProfiledRemotingMachineStateRoot: unable to resolve a machine-state root -- both ProgramData and windir were unresolved in Process and Machine scope. Refusing to fall back to a path that could resolve inside a Git worktree.'
}
