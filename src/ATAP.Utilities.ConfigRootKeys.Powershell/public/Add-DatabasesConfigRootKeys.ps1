# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Adds database-related key constants to $global:configRootKeys.

.DESCRIPTION
Appends the standard set of database configuration key constants to the
$global:configRootKeys hashtable, then invokes the EXPLICIT, ordered list of
per-database section functions. There is no directory scan: each per-database
section is named here and invoked by name. Adding a new database means adding a
new Set-Databases<Name>ConfigRootKeys function to public/ and adding one line to
the ordered invocation list below.

Per-database section functions invoked (in order):
  Set-DatabasesATAPUtilitiesConfigRootKeys — ATAPUtilities database-name key
  Set-DatabasesAceCommanderConfigRootKeys  — AceCommander database-name key

In-module sibling resolution (development-from-source guard)
------------------------------------------------------------
When this function runs FROM SOURCE (dot-sourced rather than imported as a built
module), calling a per-database section function would otherwise trigger PowerShell
autoloading, which may resolve an INSTALLED production copy of this module and shadow
the in-development sprint-worktree code. To guarantee the co-located versions win, the
begin block dot-sources each per-database section from its co-located source file (the
-Path directory, default $PSScriptRoot) when present. In a built/installed module those
files are merged into the .psm1, so the already-loaded module-scoped functions are used
instead. See Set-GlobalConfigRootKeys and the module INDEX.md for the canonical pattern.

Requires $global:configRootKeys to already exist (initialized by Set-CoreConfigRootKeys
via Set-GlobalConfigRootKeys).

.PARAMETER Path
Directory containing the co-located per-database section-function source files. When
omitted, defaults to $PSScriptRoot (the public/ folder this function lives in).

.OUTPUTS
None. Populates $global:configRootKeys as a side effect.

.EXAMPLE
Add-DatabasesConfigRootKeys

Adds all standard database key constants and invokes every per-database section function.

.EXAMPLE
Add-DatabasesConfigRootKeys -WhatIf

Shows which operations would be performed without modifying $global:configRootKeys.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Add-DatabasesConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $false)]
    [string] $Path
  )

  begin {
    $fn = 'Add-DatabasesConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn" }

    if ($null -eq $global:configRootKeys) {
      $errorMessage = '$global:configRootKeys is not initialized. Run Set-GlobalConfigRootKeys (which loads Set-CoreConfigRootKeys first).'
      if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage }
      throw $errorMessage
    }

    # Default -Path to the directory this function was loaded from.
    if ([string]::IsNullOrEmpty($Path)) {
      $Path = $PSScriptRoot
    }

    # The EXPLICIT, ordered list of per-database section functions to invoke.
    $perDatabaseSectionFunctions = @(
      'Set-DatabasesATAPUtilitiesConfigRootKeys'
      'Set-DatabasesAceCommanderConfigRootKeys'
    )

    # In-module sibling resolution (see comment-based help above).
    foreach ($sectionFunction in $perDatabaseSectionFunctions) {
      $siblingPath = Join-Path -Path $Path -ChildPath "$sectionFunction.ps1"
      if (Test-Path -LiteralPath $siblingPath -PathType Leaf) {
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourcing co-located sibling '$siblingPath'" -Tag 'ConfigRootKeys' }
        . $siblingPath
      } elseif (-not (Get-Command -Name $sectionFunction -CommandType Function -ErrorAction SilentlyContinue)) {
        $errorMessage = "Per-database section function '$sectionFunction' is not defined and its source file was not found at '$siblingPath'."
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage }
        throw $errorMessage
      } else {
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using already-loaded module-scoped '$sectionFunction' (built module; no co-located source)." -Tag 'ConfigRootKeys' }
      }
    }
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Add database key constants')) {
        $global:configRootKeys.Add('DatabaseHostConfigRootKey', 'DatabaseHost')
        $global:configRootKeys.Add('ConnectionMethodConfigRootKey', 'ConnectionMethod')
        $global:configRootKeys.Add('SqlInstanceConfigRootKey', 'SqlInstance')
        $global:configRootKeys.Add('DatabasePathConfigRootKey', 'DatabasePath')
        $global:configRootKeys.Add('ProvisioningScriptsPathConfigRootKey', 'ProvisioningScriptsPath')
        $global:configRootKeys.Add('FlywayBasePathConfigRootKey', 'FlywayBasePath')
        $global:configRootKeys.Add('FlywaySqlMigrationsPathConfigRootKey', 'FlywaySqlMigrationsPath')
        $global:configRootKeys.Add('FlywaySharedSqlMigrationsPathConfigRootKey', 'FlywaySharedSqlMigrationsPath')
        $global:configRootKeys.Add('FlywayTomlPathConfigRootKey', 'FlywayTomlPath')
        $global:configRootKeys.Add('UseNamedLoginConfigRootKey', 'UseNamedLogin')
        $global:configRootKeys.Add('DBConnectionStringMasterSecretNameConfigRootKey', 'DBConnectionStringMasterSecretName')
        $global:configRootKeys.Add('DBConnectionStringDBSecretNameConfigRootKey', 'DBConnectionStringDBSecretName')
        $global:configRootKeys.Add('LoginPasswordCredentialsKeyConfigRootKey', 'LoginPasswordCredentialsKey')
        $global:configRootKeys.Add('DatabasesCollectionConfigRootKey', 'DatabasesCollection')
        if (Get-Module -Name PSFramework) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Added core database key constants.' }
      }

      # Invoke each per-database section function explicitly, in order.
      foreach ($sectionFunction in $perDatabaseSectionFunctions) {
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
