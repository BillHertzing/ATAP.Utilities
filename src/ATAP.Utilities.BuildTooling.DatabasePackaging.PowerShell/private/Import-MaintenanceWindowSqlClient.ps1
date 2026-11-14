function Import-MaintenanceWindowSqlClient {
  <#
  .SYNOPSIS
    Loads the one pinned Microsoft.Data.SqlClient assembly, and refuses any other copy.
  .DESCRIPTION
    The same pin as the Experimental packets (clerk2-clone-maint-r4 Invoke-AlterWithGuard.ps1):
    C:\Program Files\PowerShell\Modules\dbatools.library\2025.12.28\core\lib\Microsoft.Data.SqlClient.dll,
    SHA-256 FAFFA55E5DB0BF0503F31B54F65F5FB203412B77D1C38CE8AD0A0A45485DE90B (assembly 6.0.0.0).
    Refuses (MaintenanceWindowSqlClientNotPinned):
      - a path other than the tier map's;
      - a file whose hash differs;
      - any already-loaded Microsoft.Data.SqlClient whose file is not the pinned one.
    It never resolves the newest copy.
  .PARAMETER Path
    Assembly path (from the binding; must equal the tier map's).
  .PARAMETER ExpectedSha256
    Assembly SHA-256 (from the binding; must equal the tier map's).
  .OUTPUTS
    PSCustomObject with Path, Sha256, Version.
  .EXAMPLE
    Import-MaintenanceWindowSqlClient -Path $p -ExpectedSha256 $h
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines. DB-Runner-S1-Foundation.
  .LINK
    Invoke-MaintenanceSqlDataSet
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidatePattern('\A[0-9a-fA-F]{64}\z')][string]$ExpectedSha256
  )
  begin {
    $fn = 'Import-MaintenanceWindowSqlClient'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }
  process {
    $refuse = { param($detail) Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "SqlClient not pinned: $detail"; throw ('MaintenanceWindowSqlClientNotPinned|' + $detail) }
    $first = (Get-MaintenanceWindowTierMap).Values | Select-Object -First 1
    if (-not [string]::Equals([IO.Path]::GetFullPath($Path), [IO.Path]::GetFullPath($first.SqlClientPath), [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'Path' }
    if (-not [string]::Equals($ExpectedSha256, $first.SqlClientSha256, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'ExpectedHash' }
    if (-not [IO.File]::Exists($Path)) { & $refuse 'Missing' }
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path)))
    if (-not [string]::Equals($hash, $ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'FileHash' }
    foreach ($asm in @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -ceq 'Microsoft.Data.SqlClient' })) {
      if ($asm.IsDynamic -or [string]::IsNullOrEmpty($asm.Location)) { continue }
      if (-not [string]::Equals([IO.Path]::GetFullPath($asm.Location), [IO.Path]::GetFullPath($Path), [StringComparison]::OrdinalIgnoreCase)) { & $refuse ('AlreadyLoaded=' + $asm.Location) }
    }
    if (-not ('Microsoft.Data.SqlClient.SqlConnection' -as [type])) { Add-Type -LiteralPath $Path }
    $type = 'Microsoft.Data.SqlClient.SqlConnection' -as [type]
    if ($null -eq $type -or -not [string]::Equals([IO.Path]::GetFullPath($type.Assembly.Location), [IO.Path]::GetFullPath($Path), [StringComparison]::OrdinalIgnoreCase)) { & $refuse 'TypeResolvesElsewhere' }
    [pscustomobject]@{ Path = $Path; Sha256 = $hash; Version = [string]$type.Assembly.GetName().Version }
  }
  end {}
}
