# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Populates $global:configRootKeys by invoking each ConfigRootKeys section function in a fixed order.

.DESCRIPTION
Bootstraps $global:configRootKeys by calling an EXPLICIT, ordered list of section
functions. There is no directory scan and no fragment-discovery step: every set of
ConfigRootKeys that the module contributes is named here and invoked by name. Adding a
new section means adding a new Set-*ConfigRootKeys function to public/ and adding one
line to the ordered invocation list below.

Invocation order (each step depends on the hashtable created by the first):

  1. Set-CoreConfigRootKeys            — creates $global:configRootKeys and registers
                                         the core / non-domain key constants. Must run
                                         first.
  2. Add-DatabasesConfigRootKeys       — adds database connection key constants and
                                         invokes the per-database section functions
                                         (Set-DatabasesATAPUtilitiesConfigRootKeys,
                                         Set-DatabasesAceCommanderConfigRootKeys).
  3. Set-SqlInstanceTopologyConfigRootKeys — SQL host/instance topology schema keys.
  4. Set-SystemParityMonitorConfigRootKeys — SystemParityMonitor section, schema, and
                                         identity-explicit package-profile keys.
  5. Set-BuildMasterConfigRootKeys     — BuildMaster automation-path / endpoint keys.
  6. Set-RulesManagementConfigRootKeys — Rules-Management framework keys.
  7. Add-PackageRepositoriesConfigRootKeys — single source of truth for ProGet / NuGet /
                                         PowerShellGet feed key constants.

In-module sibling resolution (development-from-source guard)
------------------------------------------------------------
When this orchestrator runs FROM SOURCE (its .ps1 dot-sourced individually, e.g. by the
PowerShell profile or a Pester test rather than imported as a built module), calling a
sibling function would otherwise trigger PowerShell command autoloading. Autoloading
resolves the FIRST matching command on $env:PSModulePath — which may be an INSTALLED,
production-grade copy of this module — silently shadowing the in-development code in the
sprint worktree. To guarantee that the sibling versions that ship in THIS folder win,
the begin block dot-sources each required sibling from its co-located source file (the
-Path directory, default $PSScriptRoot) when that file is present. In a BUILT/installed
module the individual .ps1 files have been merged into the .psm1, so the files are
absent and the already-loaded module-scoped functions are used instead. This is the
canonical pattern for "a higher-level function calling a lower-level function in the
same module under development"; see the module INDEX.md.

.PARAMETER Path
Directory containing the co-located section-function source files. When omitted, defaults
to $PSScriptRoot (the public/ folder this orchestrator lives in). Supplying -Path lets a
test or an alternate layout resolve the sibling sources from a different directory.

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-GlobalConfigRootKeys

Creates and fully populates $global:configRootKeys from the co-located section functions.

.EXAMPLE
Set-GlobalConfigRootKeys -WhatIf

Shows which section functions would run without modifying $global:configRootKeys.

.EXAMPLE
Set-GlobalConfigRootKeys -Path 'D:\AltRepo\src\ATAP.Utilities.ConfigRootKeys.Powershell\public'

Resolves the section-function sources from an alternate directory.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-GlobalConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $false)]
    [string] $Path
  )

  begin {
    $fn = 'Set-GlobalConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Entering function $fn" }

    # Default -Path to the directory this orchestrator was loaded from. $PSScriptRoot
    # resolves to the public/ folder regardless of the caller's working directory.
    if ([string]::IsNullOrEmpty($Path)) {
      $Path = $PSScriptRoot
    }

    # The EXPLICIT, ordered list of section functions to invoke. Order matters: step 1
    # creates the hashtable, every later step appends to it. A function-local variable
    # is shared across the begin/process/end blocks of this same invocation.
    $configRootKeySectionFunctions = @(
      'Set-CoreConfigRootKeys'
      'Add-DatabasesConfigRootKeys'
      'Set-SqlInstanceTopologyConfigRootKeys'
      'Set-SystemParityMonitorConfigRootKeys'
      'Set-BuildMasterConfigRootKeys'
      'Set-RulesManagementConfigRootKeys'
      'Add-PackageRepositoriesConfigRootKeys'
    )

    # In-module sibling resolution (see comment-based help above).
    foreach ($sectionFunction in $configRootKeySectionFunctions) {
      $siblingPath = Join-Path -Path $Path -ChildPath "$sectionFunction.ps1"
      if (Test-Path -LiteralPath $siblingPath -PathType Leaf) {
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing co-located sibling '$siblingPath'" -Tag 'ConfigRootKeys' }
        . $siblingPath
      } elseif (-not (Get-Command -Name $sectionFunction -CommandType Function -ErrorAction SilentlyContinue)) {
        $errorMessage = "Section function '$sectionFunction' is not defined and its source file was not found at '$siblingPath'."
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage }
        throw $errorMessage
      } else {
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using already-loaded module-scoped '$sectionFunction' (built module; no co-located source)." -Tag 'ConfigRootKeys' }
      }
    }
  }

  process {
    try {
      foreach ($sectionFunction in $configRootKeySectionFunctions) {
        if ($PSCmdlet.ShouldProcess('$global:configRootKeys', "Invoke $sectionFunction")) {
          if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking '$sectionFunction'" -Tag 'ConfigRootKeys' }
          & $sectionFunction
          if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "$sectionFunction completed." }
        }
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage }
      throw
    } finally {
      if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn" }
    }
  }

  end {
    if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn" }
  }
}
