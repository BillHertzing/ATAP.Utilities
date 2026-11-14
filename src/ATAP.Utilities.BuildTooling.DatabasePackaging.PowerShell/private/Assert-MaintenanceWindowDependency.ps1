function Assert-MaintenanceWindowDependency {
  <#
  .SYNOPSIS
    Refuses unless exactly one ATAP.Utilities.DatabaseManagement.Powershell is loaded, from its pinned AllUsers folder.
  .DESCRIPTION
    The runner calls DatabaseManagement's exported primitives (Invoke-Flyway, Get-FlywaySchemaVersion,
    Resolve-DatabaseSqlConnection and the principal audits). It never uses Import-BuildToolingDatabaseResolver,
    whose fallback imports source trees. This check requires:
      - exactly one loaded copy of the module;
      - its Version equal to ExpectedVersion;
      - its ModuleBase equal to <modules root>\ATAP.Utilities.DatabaseManagement.Powershell\<ExpectedVersion>;
      - Resolve-DatabaseSqlConnection and Invoke-Flyway resolving to functions of that same module.
    Throws 'MaintenanceWindowDependencyNotPinned|<detail>'.
  .PARAMETER ExpectedVersion
    The binding's databaseManagementVersion.
  .OUTPUTS
    PSCustomObject with Name, Version, ModuleBase.
  .EXAMPLE
    Assert-MaintenanceWindowDependency -ExpectedVersion '0.1.26'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Get-MaintenanceWindowModulesRoot
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param([Parameter(Mandatory)][ValidatePattern('\A\d+\.\d+\.\d+\z')][string]$ExpectedVersion)
  begin {
    $fn = 'Assert-MaintenanceWindowDependency'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    $name = 'ATAP.Utilities.DatabaseManagement.Powershell'
  }
  process {
    $refuse = { param($detail) Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Dependency not pinned: $detail"; throw ('MaintenanceWindowDependencyNotPinned|' + $detail) }
    $expectedBase = [IO.Path]::GetFullPath((Join-Path (Get-MaintenanceWindowModulesRoot) (Join-Path $name $ExpectedVersion))).TrimEnd('\')
    $loaded = @(Get-Module -Name $name -All)
    if ($loaded.Count -ne 1) { & $refuse ('LoadedCopies=' + $loaded.Count) }
    $module = $loaded[0]
    if ([string]$module.Version -cne $ExpectedVersion) { & $refuse ('Version=' + [string]$module.Version) }
    if (-not [string]::Equals([IO.Path]::GetFullPath([string]$module.ModuleBase).TrimEnd('\'), $expectedBase, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'ModuleBase' }
    foreach ($command in @('Resolve-DatabaseSqlConnection', 'Invoke-Flyway')) {
      $found = @(Get-Command -Name $command -CommandType Function -ErrorAction SilentlyContinue)
      if ($found.Count -ne 1 -or $null -eq $found[0].Module -or
          -not [string]::Equals([IO.Path]::GetFullPath([string]$found[0].Module.ModuleBase).TrimEnd('\'), $expectedBase, [StringComparison]::OrdinalIgnoreCase)) { & $refuse ('Command=' + $command) }
    }
    [pscustomobject]@{ Name = $name; Version = [string]$module.Version; ModuleBase = $expectedBase }
  }
  end {}
}
