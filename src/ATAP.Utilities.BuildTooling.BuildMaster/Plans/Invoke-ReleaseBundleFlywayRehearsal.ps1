<#
.SYNOPSIS
  Runs Flyway rehearsal for the Integration stage of the Release Bundle
  pipeline against the previous-production database backup.

.DESCRIPTION
  Eponymous entry-point script for the Integration-stage Flyway rehearsal
  step of ReleaseBundle-6Stage.otter. Reads the per-build bundle path
  marker written by New-ReleaseBundleBuildMasterPackage.ps1, validates
  that the BuildMaster application supplied an
  IntegrationDatabaseBitwardenSecretName, ensures the rehearsal log
  directory exists, and calls Invoke-FlywayRehearsal from
  ATAP.Utilities.DatabaseManagement.PowerShell. The connection string is
  resolved by Invoke-FlywayRehearsal from Bitwarden using the supplied
  secret name; this script never accepts secret values in command-line
  arguments (SEC-T1 / BLOCKER-8).

  Designed to be invoked from ReleaseBundle-6Stage.otter via
  Exec FileName: pwsh, Arguments: -NoProfile -File.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest.

.PARAMETER DatabaseManagementModulePath
  Path to the ATAP.Utilities.DatabaseManagement.PowerShell module manifest.

.PARAMETER SourcePath
  Working copy / repository root used as the rehearsal working directory.

.PARAMETER ProductName
  The product/application this rehearsal targets.

.PARAMETER ReleaseBundlePathFile
  Marker file containing the absolute path to the immutable .upack bundle.

.PARAMETER BackupPath
  Absolute path to the previous-production .bak captured for traceability.

.PARAMETER IntegrationDatabaseBitwardenSecretName
  Bitwarden item name for the Integration-tier database connection string.

.PARAMETER LogPath
  Optional rehearsal log path; defaults to _generated/flyway/flyway-rehearsal.log
  beneath $SourcePath.

.OUTPUTS
  None. Side effects: Flyway rehearsal run; log/artifacts under _generated/flyway/.

.EXAMPLE
  pwsh -NoProfile -File Invoke-ReleaseBundleFlywayRehearsal.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 `
    -DatabaseManagementModulePath C:\src\repo\src\ATAP.Utilities.DatabaseManagement.Powershell\ATAP.Utilities.DatabaseManagement.Powershell.psd1 `
    -SourcePath C:\src\repo `
    -ProductName AceCommander `
    -ReleaseBundlePathFile C:\src\repo\_generated\buildmaster\12345\releasebundle_path.tmp `
    -BackupPath D:\backups\AceCommander-Production-2026-05-23.bak `
    -IntegrationDatabaseBitwardenSecretName dbConnectionString-AceCommander-utat022-Integration

.NOTES
  AI assisted using Powershell.instructions.md as guidelines

.LINK
  ReleaseBundle-6Stage.otter
#>

#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$BuildToolingModulePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$DatabaseManagementModulePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$SourcePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProductName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseBundlePathFile,

  [AllowEmptyString()]
  [string]$BackupPath = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$IntegrationDatabaseBitwardenSecretName,

  [AllowEmptyString()]
  [string]$LogPath = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name Write-PSFMessage -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
  function Write-PSFMessage {
    param(
      [string]$FunctionName,
      [string]$ModuleName,
      [string]$Level,
      [string]$Message,
      [string[]]$Tag
    )
    if ($Level -in @('Important', 'Warning', 'Error')) {
      Write-Output "$Level [$FunctionName] $Message"
    }
  }
}

function Invoke-ReleaseBundleFlywayRehearsal {
  <#
  .SYNOPSIS
    Eponymous worker that performs the Integration Flyway rehearsal.
  .OUTPUTS
    None.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$DatabaseManagementModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$ProductName,
    [Parameter(Mandatory)][string]$ReleaseBundlePathFile,
    [AllowEmptyString()][string]$BackupPath = '',
    [Parameter(Mandatory)][string]$IntegrationDatabaseBitwardenSecretName,
    [AllowEmptyString()][string]$LogPath = ''
  )

  BEGIN {
    $fn = 'Invoke-ReleaseBundleFlywayRehearsal'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for Product='$ProductName'"

    try {
      Import-Module $BuildToolingModulePath -Force
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to import BuildTooling module from '$BuildToolingModulePath'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BuildTooling module import attempt complete."
    }

    try {
      Import-Module $DatabaseManagementModulePath -Force
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to import DatabaseManagement module from '$DatabaseManagementModulePath'. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "DatabaseManagement module import attempt complete."
    }
  }

  PROCESS {
    try {
      if ([string]::IsNullOrWhiteSpace($IntegrationDatabaseBitwardenSecretName)) {
        throw 'BuildMaster Application variable IntegrationDatabaseBitwardenSecretName is required for Integration Flyway rehearsal.'
      }

      if (-not (Test-Path -LiteralPath $ReleaseBundlePathFile -PathType Leaf)) {
        throw "ReleaseBundle path marker '$ReleaseBundlePathFile' is missing. Run the Experimental stage first."
      }
      $bundlePath = (Get-Content -LiteralPath $ReleaseBundlePathFile -Raw).Trim()
      if ([string]::IsNullOrWhiteSpace($bundlePath)) {
        throw "ReleaseBundle path marker '$ReleaseBundlePathFile' is empty."
      }

      if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $LogPath = Join-Path -Path $SourcePath -ChildPath '_generated/flyway/flyway-rehearsal.log'
      }
      $logDirectory = Split-Path -Parent $LogPath
      if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
      }

      $rehearsalParameters = @{
        Application          = $ProductName
        BundlePath           = $bundlePath
        BitwardenSecretName  = $IntegrationDatabaseBitwardenSecretName
        LogPath              = $LogPath
      }
      if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
        $rehearsalParameters['BackupPath'] = $BackupPath
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running Invoke-FlywayRehearsal for product '$ProductName' against bundle '$bundlePath' (log='$LogPath')."

      if ($PSCmdlet.ShouldProcess($bundlePath, 'Invoke-FlywayRehearsal')) {
        try {
          Invoke-FlywayRehearsal @rehearsalParameters
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Invoke-FlywayRehearsal failed for bundle '$bundlePath'. Exception: $($_.Exception.Message)"
          throw
        }
        finally {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoke-FlywayRehearsal call complete."
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed in $fn. Exception: $($_.Exception.Message)"
      throw
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn"
  }
}

Invoke-ReleaseBundleFlywayRehearsal `
  -BuildToolingModulePath $BuildToolingModulePath `
  -DatabaseManagementModulePath $DatabaseManagementModulePath `
  -SourcePath $SourcePath `
  -ProductName $ProductName `
  -ReleaseBundlePathFile $ReleaseBundlePathFile `
  -BackupPath $BackupPath `
  -IntegrationDatabaseBitwardenSecretName $IntegrationDatabaseBitwardenSecretName `
  -LogPath $LogPath | Out-Null
