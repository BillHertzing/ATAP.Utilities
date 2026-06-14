<#
.SYNOPSIS
  Drives a single BuildMaster stage of a database change package 5-tier pipeline.

.DESCRIPTION
  Eponymous entry-point script for the database change package pipeline.
  Mirrors the C# package runner pattern (Invoke-CSharpPackageBuildMasterStage):
  the OtterScript plan stays tiny and this script owns stage/context branching,
  per-tier idempotent completion markers, run-context JSON, ProGet API-key
  resolution, ceiling-clamp enforcement, and the publish/promote loop.

  For Experimental the script calls Get-DatabasePackageBuildContext to resolve
  the canonical Database/<App>/ source folder, then calls
  New-DatabaseChangePackage to produce the .nupkg and
  Publish-DatabaseChangePackageToProGet to push it to the
  database-experimental feed.

  For Development/Integration/QA/Production it promotes the captured immutable
  version from the previous tier's feed to the destination feed via
  Promote-DatabaseChangePackage with feed-direction enforcement and ceiling
  policy. Completion markers make reruns within a single BuildMaster build id
  idempotent.

  Designed to be invoked from an OtterScript plan via 'Exec pwsh -File'.

.PARAMETER BuildToolingModulePath
  Path to the ATAP.Utilities.BuildTooling.PowerShell module manifest or folder.

.PARAMETER SourcePath
  Working copy / repository root. _generated/buildmaster lives beneath this.

.PARAMETER BuildMasterBuildId
  BuildMaster build id used as the per-build run-context folder name.

.PARAMETER BuildNumber
  Optional BuildMaster build number for traceability.

.PARAMETER ExecutionId
  Optional BuildMaster execution identifier for traceability.

.PARAMETER ApplicationName
  The BuildMaster application name, e.g. ATAPUtilitiesDatabase.

.PARAMETER DatabaseApplication
  The source application name used to locate Database/<DatabaseApplication>/.
  E.g. 'ATAPUtilities' or 'AceCommander'.

.PARAMETER DatabaseStream
  Optional database stream name. Empty for a single-stream package id
  '<DatabaseApplication>.Database'. When supplied, the package id becomes
  '<DatabaseApplication>.<DatabaseStream>.Database'.

.PARAMETER Branch
  Optional source-branch label.

.PARAMETER Stage
  BuildMaster pipeline stage name; one of Experimental, Development,
  Integration, QA, Production.

.PARAMETER ProGetUrl
  Base URL of the ProGet server hosting the database feeds.

.PARAMETER ExperimentalFeed
.PARAMETER DevelopmentFeed
.PARAMETER IntegrationFeed
.PARAMETER QAFeed
.PARAMETER ProductionFeed
  Database feed names per tier.

.PARAMETER ExperimentalDatabaseDBConnectionStringSecretName
.PARAMETER DevelopmentDatabaseDBConnectionStringSecretName
.PARAMETER IntegrationDatabaseDBConnectionStringSecretName
.PARAMETER QADatabaseDBConnectionStringSecretName
.PARAMETER ProductionDatabaseDBConnectionStringSecretName
  Per-tier Bitwarden secret names whose values are SQL connection strings for
  that tier's database. Supplied by the BuildMaster Application as variables
  (see SprintInfrastructure-Naming.md section 4, e.g.
  'dbConnectionString-ATAPUtilities-localhost-Integration'). When a tier's
  secret name is supplied, the runner enforces a Flyway rehearsal before
  promoting into that tier and applies the package to that tier's real
  database after the stage's promotion/publish. The secret value is never
  accepted as a parameter and never echoed; Invoke-FlywayRehearsal /
  Invoke-Flyway resolve it from Bitwarden by name.

.PARAMETER SkipRehearsal
  Bypasses the rehearsal-before-promotion gate even when a tier connection
  secret name is supplied. Intended for disaster recovery and audited manual
  promotions only; logged as a warning.

.PARAMETER SkipApply
  Bypasses the per-tier apply (Flyway migrate against the real tier database)
  even when a tier connection secret name is supplied. The promotion still
  happens; the database is not migrated. Logged as a warning.

.OUTPUTS
  None. Side effects: New-DatabaseChangePackage, ProGet publish/promote,
  per-tier Flyway rehearsal (before promotion) and apply/migrate (after
  promotion/publish) against the tier database, run-context JSON / state
  files / completion markers under
  _generated/buildmaster/<BuildMasterBuildId>.

.EXAMPLE
  pwsh -File Invoke-DatabasePackageBuildMasterStage.ps1 `
    -BuildToolingModulePath C:\src\repo\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 `
    -SourcePath C:\src\repo `
    -BuildMasterBuildId 12345 `
    -ApplicationName ATAPUtilitiesDatabase `
    -DatabaseApplication ATAPUtilities `
    -DatabaseStream '' `
    -Stage Experimental `
    -ProGetUrl http://localhost:50000

.NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  Task: TASKS_V4-DBA2.md DBA2-T03 / V4-E08.

.LINK
  BuildMasterRunContext.Common.ps1

.LINK
  Invoke-CSharpPackageBuildMasterStage.ps1
#>

#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$BuildToolingModulePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$SourcePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$BuildMasterBuildId,

  [AllowEmptyString()]
  [string]$BuildNumber = '',

  [AllowEmptyString()]
  [string]$ExecutionId = '',

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ApplicationName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$DatabaseApplication,

  [AllowEmptyString()]
  [string]$DatabaseStream = '',

  [AllowEmptyString()]
  [string]$Branch = '',

  [Parameter(Mandatory)]
  [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
  [string]$Stage,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ProGetUrl,

  [string]$ExperimentalFeed = 'database-experimental',
  [string]$DevelopmentFeed = 'database-development',
  [string]$IntegrationFeed = 'database-integration',
  [string]$QAFeed = 'database-qa',
  [string]$ProductionFeed = 'database-stable',

  [AllowEmptyString()]
  [string]$ExperimentalDatabaseDBConnectionStringSecretName = '',

  [AllowEmptyString()]
  [string]$DevelopmentDatabaseDBConnectionStringSecretName = '',

  [AllowEmptyString()]
  [string]$IntegrationDatabaseDBConnectionStringSecretName = '',

  [AllowEmptyString()]
  [string]$QADatabaseDBConnectionStringSecretName = '',

  [AllowEmptyString()]
  [string]$ProductionDatabaseDBConnectionStringSecretName = '',

  [switch]$SkipRehearsal,

  [switch]$SkipApply
)

$ErrorActionPreference = 'Stop'
# BuildMaster invokes this runner non-interactively via 'pwsh -NoProfile -File'.
# A High-impact ShouldProcess would otherwise block the pipeline waiting for a
# confirmation that can never be answered. Suppress confirmation here; the
# rehearsal/apply gates still fail loud (throw) on real errors, which is the
# safety mechanism that matters for an unattended pipeline.
$ConfirmPreference = 'None'

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

. (Join-Path -Path $PSScriptRoot -ChildPath 'BuildMasterRunContext.Common.ps1')

function Get-DatabaseFeedForTier {
  <#
  .SYNOPSIS
    Returns the canonical database-* feed name for a tier.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$Tier,
    [Parameter(Mandatory)][string]$ExperimentalFeed,
    [Parameter(Mandatory)][string]$DevelopmentFeed,
    [Parameter(Mandatory)][string]$IntegrationFeed,
    [Parameter(Mandatory)][string]$QAFeed,
    [Parameter(Mandatory)][string]$ProductionFeed
  )

  BEGIN {
    $fn = 'Get-DatabaseFeedForTier'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    switch ($Tier) {
      'Experimental' { return $ExperimentalFeed }
      'Development'  { return $DevelopmentFeed }
      'Integration'  { return $IntegrationFeed }
      'QA'           { return $QAFeed }
      'Production'   { return $ProductionFeed }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-DatabasePackageStageCompletionMarkerPath {
  <#
  .SYNOPSIS
    Returns the per-package, per-tier completion marker file path for a database package.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Get-DatabasePackageStageCompletionMarkerPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    return (Join-Path -Path $ContextDirectory -ChildPath "$DatabasePackageId.$Tier.completed.tmp")
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Set-DatabasePackageStageCompleted {
  <#
  .SYNOPSIS
    Writes a completion marker JSON for a given database package/tier/version.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion
  )

  BEGIN {
    $fn = 'Set-DatabasePackageStageCompleted'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Tier='$Tier'; Version='$PackageVersion')"
  }

  PROCESS {
    $markerPath = Get-DatabasePackageStageCompletionMarkerPath -ContextDirectory $ContextDirectory -DatabasePackageId $DatabasePackageId -Tier $Tier
    $payload = [ordered]@{
      Tier              = $Tier
      DatabasePackageId = $DatabasePackageId
      PackageVersion    = $PackageVersion
      CompletedUtc      = [datetime]::UtcNow.ToString('o')
    }
    if ($PSCmdlet.ShouldProcess($markerPath, 'Write stage completion marker')) {
      $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding utf8
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Test-DatabasePackageStageCompleted {
  <#
  .SYNOPSIS
    Returns $true if the completion marker for a database package/tier exists.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([bool])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Test-DatabasePackageStageCompleted'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    $markerPath = Get-DatabasePackageStageCompletionMarkerPath -ContextDirectory $ContextDirectory -DatabasePackageId $DatabasePackageId -Tier $Tier
    return (Test-Path -LiteralPath $markerPath -PathType Leaf)
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-PreviousDatabaseTier {
  <#
  .SYNOPSIS
    Returns the tier immediately preceding $Tier in the canonical tier order.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Development', 'Integration', 'QA', 'Production')]
    [string]$Tier
  )

  BEGIN {
    $fn = 'Get-PreviousDatabaseTier'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    $tierOrder = @('Experimental', 'Development', 'Integration', 'QA', 'Production')
    $tierIndex = $tierOrder.IndexOf($Tier)
    if ($tierIndex -le 0) {
      throw "Database tier '$Tier' does not have a previous promotion tier."
    }
    return $tierOrder[$tierIndex - 1]
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Add-DatabasePackagePublishTrace {
  <#
  .SYNOPSIS
    Appends a UTC-timestamped line to a per-tier publish/promote trace file.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message
  )

  BEGIN {
    $fn = 'Add-DatabasePackagePublishTrace'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    $line = '{0:u} {1}' -f [datetime]::UtcNow, $Message
    Add-Content -LiteralPath $Path -Value $line -Encoding utf8
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-DatabaseTierEnvironment {
  <#
  .SYNOPSIS
    Maps a BuildMaster pipeline stage/tier name to the Flyway Environment name
    that Invoke-Flyway / Invoke-FlywayRehearsal understand.
  .DESCRIPTION
    The Flyway wrapper accepts only Production, Testing, Development, and
    Experimental as Environment values. The pipeline's QA and Integration
    tiers both map to the 'Testing' Flyway environment; Production maps to
    'Production'; Development and Experimental map to themselves.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$Tier
  )

  BEGIN {
    $fn = 'Get-DatabaseTierEnvironment'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    switch ($Tier) {
      'Experimental' { return 'Experimental' }
      'Development'  { return 'Development' }
      'Integration'  { return 'Testing' }
      'QA'           { return 'Testing' }
      'Production'   { return 'Production' }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Resolve-DatabaseTierConnectionSecretName {
  <#
  .SYNOPSIS
    Returns the Bitwarden connection-string secret name configured for a tier,
    or an empty string when the tier has no secret name configured.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$Tier,
    [AllowEmptyString()][string]$ExperimentalSecretName = '',
    [AllowEmptyString()][string]$DevelopmentSecretName = '',
    [AllowEmptyString()][string]$IntegrationSecretName = '',
    [AllowEmptyString()][string]$QASecretName = '',
    [AllowEmptyString()][string]$ProductionSecretName = ''
  )

  BEGIN {
    $fn = 'Resolve-DatabaseTierConnectionSecretName'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    $name = switch ($Tier) {
      'Experimental' { $ExperimentalSecretName }
      'Development'  { $DevelopmentSecretName }
      'Integration'  { $IntegrationSecretName }
      'QA'           { $QASecretName }
      'Production'   { $ProductionSecretName }
    }
    if ([string]::IsNullOrWhiteSpace($name)) { return '' }
    return $name.Trim()
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Get-DatabasePackageApplyMarkerPath {
  <#
  .SYNOPSIS
    Returns the per-package, per-tier apply completion marker path.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier
  )

  BEGIN {
    $fn = 'Get-DatabasePackageApplyMarkerPath'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn"
  }

  PROCESS {
    return (Join-Path -Path $ContextDirectory -ChildPath "$DatabasePackageId.$Tier.applied.tmp")
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Invoke-DatabasePackageTierRehearsal {
  <#
  .SYNOPSIS
    Runs the package-aware Flyway rehearsal that must pass before a database
    package is promoted into a tier.
  .DESCRIPTION
    Wraps Invoke-DatabasePackageRehearsal so the BuildMaster stage runner can
    enforce rehearsal-before-promotion in code. Throws when the rehearsal does
    not report Success, so the caller aborts before calling
    Promote-DatabaseChangePackage.
  .OUTPUTS
    [PSCustomObject] the rehearsal result (Success/PackagePath/...).
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Application,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tier,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BuildId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ConnectionStringSecretName,
    [AllowEmptyString()][string]$LogPath = ''
  )

  BEGIN {
    $fn = 'Invoke-DatabasePackageTierRehearsal'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) {
      throw "Cannot rehearse '$Application' for tier '$Tier': package '$NupkgPath' not found."
    }

    $rehearsalParameters = @{
      NupkgPath                    = $NupkgPath
      Application                  = $Application
      BuildId                      = ('{0}-{1}' -f $BuildId, $Tier)
      DBConnectionStringSecretName = $ConnectionStringSecretName
    }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
      $rehearsalParameters['LogPath'] = $LogPath
    }

    if ($PSCmdlet.ShouldProcess("$Application ($Tier)", 'Invoke-DatabasePackageRehearsal')) {
      $result = Invoke-DatabasePackageRehearsal @rehearsalParameters
      if ($null -eq $result -or -not [bool]$result.Success) {
        $summary = if ($null -ne $result) { $result.ValidateOutput } else { '<no result>' }
        throw "Pre-promotion Flyway rehearsal FAILED for '$Application' tier '$Tier'; promotion blocked. Detail: $summary"
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Pre-promotion rehearsal PASSED for '$Application' tier '$Tier'."
      return $result
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Invoke-DatabasePackageTierApply {
  <#
  .SYNOPSIS
    Applies a database change package to a tier's real database via Flyway
    migrate, after that tier's promotion/publish has succeeded.
  .DESCRIPTION
    Expands the immutable .nupkg, derives Flyway parameters from the package
    manifest, takes a pre-migration snapshot for permanent tiers
    (Integration/QA/Production) when New-DatabasePreMigrationSnapshot is
    available, then runs Invoke-Flyway -FlywayCommand migrate against the
    tier database resolved from -ConnectionStringSecretName. Throws when the
    migrate does not succeed so the stage fails loud.
  .OUTPUTS
    [PSCustomObject] @{ Tier; Environment; Applied; SnapshotPath; FlywayResult }
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Application,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion,
    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$Tier,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ConnectionStringSecretName
  )

  BEGIN {
    $fn = 'Invoke-DatabasePackageTierApply'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn (Tier='$Tier'; Version='$PackageVersion')"
  }

  PROCESS {
    if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) {
      throw "Cannot apply '$DatabasePackageId' to tier '$Tier': package '$NupkgPath' not found."
    }

    $environment = Get-DatabaseTierEnvironment -Tier $Tier
    $permanentTiers = @('Integration', 'QA', 'Production')
    $snapshotPath = $null
    $applied = $false
    $flywayResult = $null
    $expandedPath = $null

    try {
      $expandedPath = Expand-DatabaseChangePackage -NupkgPath $NupkgPath
      $manifest = Get-DatabasePackageManifest -PackagePath $expandedPath

      $applicationName = $Application
      if ($manifest.PSObject.Properties.Name -contains 'dbChangeUnit' -and
        -not [string]::IsNullOrWhiteSpace([string]$manifest.dbChangeUnit)) {
        $applicationName = [string]$manifest.dbChangeUnit
      }

      # Pre-migration snapshot for permanent tiers (rollback point; see
      # Database-Change-Unit-and-Flyway-Promotion.md section 17). Best-effort: a
      # missing snapshot cmdlet must not block the apply on ephemeral tiers,
      # but for permanent tiers a failure is surfaced.
      if ($Tier -in $permanentTiers -and
        (Get-Command -Name New-DatabasePreMigrationSnapshot -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess("$applicationName ($Tier)", 'New-DatabasePreMigrationSnapshot')) {
          try {
            $snapshot = New-DatabasePreMigrationSnapshot `
              -DBConnectionStringSecretName $ConnectionStringSecretName `
              -Application $applicationName `
              -Tier $Tier
            $snapshotPath = if ($null -ne $snapshot) { [string]$snapshot.SnapshotPath } else { $null }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Pre-migration snapshot taken for '$applicationName' tier '$Tier'."
          }
          catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
              -Message "Pre-migration snapshot FAILED for '$applicationName' tier '$Tier': $($_.Exception.Message)"
            throw
          }
        }
      }

      $flywayParameters = @{
        DatabaseName                 = $applicationName
        Environment                  = $environment
        FlywayCommand                = 'migrate'
        DBConnectionStringSecretName = $ConnectionStringSecretName
        FlywayBasePath               = $expandedPath
        PackageName                  = $DatabasePackageId
        PackageVersion               = $PackageVersion
      }

      if ($PSCmdlet.ShouldProcess("$applicationName ($Tier / $environment)", 'Invoke-Flyway migrate')) {
        $flywayResult = Invoke-Flyway @flywayParameters
        if ($null -ne $flywayResult -and $flywayResult.PSObject.Properties.Name -contains 'Success' -and
          -not [bool]$flywayResult.Success) {
          throw "Flyway migrate FAILED applying '$DatabasePackageId' '$PackageVersion' to tier '$Tier' (environment '$environment')."
        }
        $applied = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Applied '$DatabasePackageId' '$PackageVersion' to tier '$Tier' (environment '$environment')."
      }
    }
    finally {
      if ($expandedPath -and (Test-Path -LiteralPath $expandedPath -PathType Container)) {
        Remove-Item -LiteralPath $expandedPath -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    return [PSCustomObject]@{
      Tier         = $Tier
      Environment  = $environment
      Applied      = $applied
      SnapshotPath = $snapshotPath
      FlywayResult = $flywayResult
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Invoke-DatabasePackageStageApply {
  <#
  .SYNOPSIS
    Stage-level orchestration of the per-tier apply: decides whether to apply,
    writes the apply completion marker, and traces the outcome.
  .DESCRIPTION
    Centralizes the skip/enforce policy so the Experimental and promotion
    branches of the runner share one code path:
      * No connection-string secret name configured  -> skip (apply not wired
        for this tier; logged at Verbose, not a failure).
      * -SkipApply supplied                           -> skip (logged Warning).
      * Already applied in this build                 -> skip (idempotent).
      * Otherwise                                     -> Invoke-DatabasePackageTierApply
        and write the .applied.tmp marker on success.
  .OUTPUTS
    None.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ContextDirectory,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabasePackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DatabaseApplication,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion,
    [Parameter(Mandatory)]
    [ValidateSet('Experimental', 'Development', 'Integration', 'QA', 'Production')]
    [string]$Tier,
    [AllowEmptyString()][AllowNull()][string]$NupkgPath = '',
    [AllowEmptyString()][string]$ConnectionStringSecretName = '',
    [switch]$SkipApply,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TracePath
  )

  BEGIN {
    $fn = 'Invoke-DatabasePackageStageApply'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Starting $fn (Tier='$Tier')"
  }

  PROCESS {
    if ([string]::IsNullOrWhiteSpace($ConnectionStringSecretName)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "No connection-string secret name configured for tier '$Tier'; per-tier apply skipped for '$DatabasePackageId'."
      Add-DatabasePackagePublishTrace -Path $TracePath -Message "Apply skipped for tier '$Tier' (no connection secret configured)."
      return
    }

    if ($SkipApply) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
        -Message "Per-tier apply BYPASSED (-SkipApply) for '$DatabasePackageId' tier '$Tier'."
      Add-DatabasePackagePublishTrace -Path $TracePath -Message "Apply bypassed (-SkipApply) for tier '$Tier'."
      return
    }

    $applyMarker = Get-DatabasePackageApplyMarkerPath -ContextDirectory $ContextDirectory -DatabasePackageId $DatabasePackageId -Tier $Tier
    if (Test-Path -LiteralPath $applyMarker -PathType Leaf) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Per-tier apply already completed for '$DatabasePackageId' tier '$Tier' in this build; skipping (idempotent)."
      return
    }

    if ([string]::IsNullOrWhiteSpace($NupkgPath) -or -not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) {
      throw "Per-tier apply cannot run for '$DatabasePackageId' tier '$Tier': the build's immutable .nupkg was not found (NupkgPath='$NupkgPath')."
    }

    Add-DatabasePackagePublishTrace -Path $TracePath -Message "Applying '$DatabasePackageId' '$PackageVersion' to tier '$Tier' database."
    $applyResult = Invoke-DatabasePackageTierApply `
      -NupkgPath $NupkgPath `
      -Application $DatabaseApplication `
      -DatabasePackageId $DatabasePackageId `
      -PackageVersion $PackageVersion `
      -Tier $Tier `
      -ConnectionStringSecretName $ConnectionStringSecretName

    if ($null -ne $applyResult -and [bool]$applyResult.Applied) {
      $payload = [ordered]@{
        Tier              = $Tier
        Environment       = $applyResult.Environment
        DatabasePackageId = $DatabasePackageId
        PackageVersion    = $PackageVersion
        SnapshotPath      = $applyResult.SnapshotPath
        AppliedUtc        = [datetime]::UtcNow.ToString('o')
      }
      if ($PSCmdlet.ShouldProcess($applyMarker, 'Write apply completion marker')) {
        $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $applyMarker -Encoding utf8
      }
      Add-DatabasePackagePublishTrace -Path $TracePath -Message "Apply complete for tier '$Tier' (environment '$($applyResult.Environment)')."
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Finished $fn"
  }
}

function Invoke-DatabasePackageBuildMasterStage {
  <#
  .SYNOPSIS
    Eponymous worker that drives one BuildMaster stage of the 5-tier database
    change package pipeline.
  .DESCRIPTION
    Implements the per-stage run loop. Experimental builds and publishes the
    .nupkg; Development/Integration/QA/Production promote the immutable
    package between consecutive database-* feeds with ceiling enforcement.
  .OUTPUTS
    None.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)][string]$BuildToolingModulePath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$BuildMasterBuildId,
    [AllowEmptyString()][string]$BuildNumber = '',
    [AllowEmptyString()][string]$ExecutionId = '',
    [Parameter(Mandatory)][string]$ApplicationName,
    [Parameter(Mandatory)][string]$DatabaseApplication,
    [AllowEmptyString()][string]$DatabaseStream = '',
    [AllowEmptyString()][string]$Branch = '',
    [Parameter(Mandatory)][string]$Stage,
    [Parameter(Mandatory)][string]$ProGetUrl,
    [string]$ExperimentalFeed = 'database-experimental',
    [string]$DevelopmentFeed = 'database-development',
    [string]$IntegrationFeed = 'database-integration',
    [string]$QAFeed = 'database-qa',
    [string]$ProductionFeed = 'database-stable',
    [AllowEmptyString()][string]$ExperimentalDatabaseDBConnectionStringSecretName = '',
    [AllowEmptyString()][string]$DevelopmentDatabaseDBConnectionStringSecretName = '',
    [AllowEmptyString()][string]$IntegrationDatabaseDBConnectionStringSecretName = '',
    [AllowEmptyString()][string]$QADatabaseDBConnectionStringSecretName = '',
    [AllowEmptyString()][string]$ProductionDatabaseDBConnectionStringSecretName = '',
    [switch]$SkipRehearsal,
    [switch]$SkipApply
  )

  BEGIN {
    $fn = 'Invoke-DatabasePackageBuildMasterStage'
    $mn = 'ATAP.Utilities.BuildTooling.BuildMaster'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting $fn for BuildId='$BuildMasterBuildId'; Application='$DatabaseApplication'; Stream='$DatabaseStream'; Stage='$Stage'"

    # Resolve API key from User-scope environment (R-10): try BuildMaster key
    # first, then the admin key. Never accept the key as a parameter and never
    # echo it.
    $userBuildmasterKey = [System.Environment]::GetEnvironmentVariable('PROGET_BUILDMASTER_API_KEY', 'User')
    $userAdminKey = [System.Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')

    $script:resolvedProGetApiKey = if (-not [string]::IsNullOrWhiteSpace($env:PROGET_BUILDMASTER_API_KEY)) {
      $env:PROGET_BUILDMASTER_API_KEY
    }
    elseif (-not [string]::IsNullOrWhiteSpace($userBuildmasterKey)) {
      $userBuildmasterKey
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:PROGET_ADMIN_API_KEY)) {
      $env:PROGET_ADMIN_API_KEY
    }
    elseif (-not [string]::IsNullOrWhiteSpace($userAdminKey)) {
      $userAdminKey
    }
    else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Unable to resolve ProGet API key.'
      throw 'Unable to resolve ProGet API key. Set PROGET_BUILDMASTER_API_KEY or PROGET_ADMIN_API_KEY in the BuildMaster service-account User-scope environment.'
    }
    $env:PROGET_BUILDMASTER_API_KEY = $script:resolvedProGetApiKey
    $env:PROGET_ADMIN_API_KEY = $script:resolvedProGetApiKey

    $script:buildToolingRoot = Split-Path -Parent $BuildToolingModulePath
  }

  PROCESS {
    function Resolve-BuildToolingFunctionFile {
      [CmdletBinding()]
      [OutputType([string])]
      param([Parameter(Mandatory)][string]$RelativePath)
      BEGIN { $f = 'Resolve-BuildToolingFunctionFile'; $m = 'ATAP.Utilities.BuildTooling.BuildMaster' }
      PROCESS {
        $path = Join-Path -Path $script:buildToolingRoot -ChildPath $RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
          Write-PSFMessage -FunctionName $f -ModuleName $m -Level Error -Message "Required BuildTooling function file not found: $path"
          throw "Required BuildTooling function file not found: $path"
        }
        return $path
      }
      END {}
    }

    # Dot-source the BuildTooling cmdlets the runner depends on. Test runs
    # can stub these by defining functions of the same name in scope first.
    if (-not (Get-Command -Name Get-DatabasePackageBuildContext -ErrorAction SilentlyContinue)) {
      . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Get-DatabasePackageBuildContext.ps1')
    }
    if (-not (Get-Command -Name Publish-DatabaseChangePackageToProGet -ErrorAction SilentlyContinue)) {
      . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Publish-DatabaseChangePackageToProGet.ps1')
    }
    if (-not (Get-Command -Name Promote-DatabaseChangePackage -ErrorAction SilentlyContinue)) {
      . (Resolve-BuildToolingFunctionFile -RelativePath 'public/Promote-DatabaseChangePackage.ps1')
    }

    # New-DatabaseChangePackage and the rehearsal/apply cmdlets live in the
    # DatabaseManagement.Powershell module. Dot-source from source so the
    # runner works from a worktree without the module installed. Test runs
    # can stub any of these by defining functions of the same name in scope.
    $dbModulePublic = Join-Path -Path $SourcePath -ChildPath 'src/ATAP.Utilities.DatabaseManagement.Powershell/public'
    $databaseManagementFunctionFiles = [ordered]@{
      'New-DatabaseChangePackage'      = 'New-DatabaseChangePackage.ps1'
      'Invoke-DatabasePackageRehearsal' = 'Invoke-DatabasePackageRehearsal.ps1'
      'Expand-DatabaseChangePackage'   = 'Expand-DatabaseChangePackage.ps1'
      'Get-DatabasePackageManifest'    = 'Get-DatabasePackageManifest.ps1'
      'Invoke-FlywayRehearsal'         = 'Invoke-FlywayRehearsal.ps1'
      'Invoke-Flyway'                  = 'Invoke-Flyway.ps1'
    }
    foreach ($commandName in $databaseManagementFunctionFiles.Keys) {
      if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
        $candidate = Join-Path -Path $dbModulePublic -ChildPath $databaseManagementFunctionFiles[$commandName]
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
          . $candidate
        }
        elseif ($commandName -eq 'New-DatabaseChangePackage') {
          throw "Required cmdlet New-DatabaseChangePackage not found at '$candidate'."
        }
      }
    }

    $contextDirectory = Initialize-BuildMasterRunContextDirectory -SourcePath $SourcePath -BuildMasterBuildId $BuildMasterBuildId

    # Resolve database build context (this validates that Database/<App>/version.json exists).
    $contextParameters = @{
      Application = $DatabaseApplication
      RepoRoot    = $SourcePath
      Stage       = $Stage
    }
    if (-not [string]::IsNullOrWhiteSpace($DatabaseStream)) {
      $contextParameters['Stream'] = $DatabaseStream
    }
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
      $contextParameters['Branch'] = $Branch
    }
    else {
      $contextParameters['Branch'] = 'main'
    }

    $context = Get-DatabasePackageBuildContext @contextParameters

    $databasePackageId = [string]$context.DatabasePackageId
    $databasePackageSourcePath = [string]$context.DatabasePackageSourcePath
    $resolvedVersion = [string]$context.ResolvedPackageVersion
    $prereleaseLabel = [string]$context.PrereleaseLabel
    $effectiveCeilingTier = [string]$context.CeilingTier

    if ([string]::IsNullOrWhiteSpace($effectiveCeilingTier)) {
      $effectiveCeilingTier = 'Production'
    }

    $existingContext = Read-BuildMasterRunContextJson -ContextDirectory $contextDirectory
    if ($Stage -ne 'Experimental') {
      if ($null -eq $existingContext -or [string]::IsNullOrWhiteSpace([string]$existingContext.ResolvedVersion)) {
        throw "BuildMaster run context '$contextDirectory' is missing a captured ResolvedVersion for build id '$BuildMasterBuildId'. Run the Experimental stage first or transfer the build-id context folder."
      }
      if (-not [string]::IsNullOrWhiteSpace([string]$existingContext.ResolvedVersion)) {
        $resolvedVersion = [string]$existingContext.ResolvedVersion
      }
      if (-not [string]::IsNullOrWhiteSpace([string]$existingContext.CeilingTier)) {
        $effectiveCeilingTier = [string]$existingContext.CeilingTier
      }
      if (-not [string]::IsNullOrWhiteSpace([string]$existingContext.PrereleaseLabel)) {
        $prereleaseLabel = [string]$existingContext.PrereleaseLabel
      }
    }

    $allowDecisions = Get-BuildMasterAllowDecisions -CeilingTier $effectiveCeilingTier

    if (-not [bool]$allowDecisions[$Stage]) {
      throw "Database stage '$Stage' exceeds version ceiling '$effectiveCeilingTier' for package '$databasePackageId'."
    }

    # Resolve this tier's connection-string secret name once. Apply and
    # rehearsal are enforced only when the tier has a secret name configured.
    $tierConnectionSecretName = Resolve-DatabaseTierConnectionSecretName -Tier $Stage `
      -ExperimentalSecretName $ExperimentalDatabaseDBConnectionStringSecretName `
      -DevelopmentSecretName $DevelopmentDatabaseDBConnectionStringSecretName `
      -IntegrationSecretName $IntegrationDatabaseDBConnectionStringSecretName `
      -QASecretName $QADatabaseDBConnectionStringSecretName `
      -ProductionSecretName $ProductionDatabaseDBConnectionStringSecretName

    $stateFiles = [ordered]@{
      CeilingTier       = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.ceiling-tier.tmp"
      CurrentTier       = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.current-tier.tmp"
      ResolvedVersion   = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.resolved-version.tmp"
      PrereleaseLabel   = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.prerelease-label.tmp"
      AllowExperimental = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.allow-experimental.tmp"
      AllowDevelopment  = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.allow-development.tmp"
      AllowIntegration  = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.allow-integration.tmp"
      AllowQA           = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.allow-qa.tmp"
      AllowProduction   = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.allow-production.tmp"
    }

    Write-BuildMasterRunStateFiles -StateFiles $stateFiles -Values @{
      CeilingTier       = $effectiveCeilingTier
      CurrentTier       = $Stage
      ResolvedVersion   = $resolvedVersion
      PrereleaseLabel   = $prereleaseLabel
      AllowExperimental = $allowDecisions['Experimental'].ToString().ToLowerInvariant()
      AllowDevelopment  = $allowDecisions['Development'].ToString().ToLowerInvariant()
      AllowIntegration  = $allowDecisions['Integration'].ToString().ToLowerInvariant()
      AllowQA           = $allowDecisions['QA'].ToString().ToLowerInvariant()
      AllowProduction   = $allowDecisions['Production'].ToString().ToLowerInvariant()
    }

    Write-BuildMasterRunContextJson `
      -ContextDirectory $contextDirectory `
      -BuildMasterBuildId $BuildMasterBuildId `
      -BuildNumber $BuildNumber `
      -ExecutionId $ExecutionId `
      -ApplicationName $ApplicationName `
      -Branch $Branch `
      -SourcePath $SourcePath `
      -ProjectPath $databasePackageSourcePath `
      -CurrentTier $Stage `
      -CeilingTier $effectiveCeilingTier `
      -ResolvedVersion $resolvedVersion `
      -PrereleaseLabel $prereleaseLabel `
      -AllowDecisions $allowDecisions `
      -StateFiles $stateFiles `
      -AdditionalData @{
        PipelineKind        = 'DatabaseChangePackage'
        DatabaseApplication = $DatabaseApplication
        DatabaseStream      = $DatabaseStream
        DatabasePackageId   = $databasePackageId
      } | Out-Null

    if (Test-DatabasePackageStageCompleted -ContextDirectory $contextDirectory -DatabasePackageId $databasePackageId -Tier $Stage) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Database stage '$Stage' for '$databasePackageId' already completed in build '$BuildMasterBuildId'; skipping (idempotent rerun)."
      return
    }

    $tracePath = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.$($Stage.ToLowerInvariant()).log"

    if ($Stage -eq 'Experimental') {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Database stage 'Experimental' building and publishing '$databasePackageId' from '$databasePackageSourcePath'."
      Add-DatabasePackagePublishTrace -Path $tracePath -Message "Build and publish '$databasePackageId' version '$resolvedVersion' to '$ExperimentalFeed'."

      $newPackageParameters = @{
        Application    = $DatabaseApplication
        RepositoryRoot = $SourcePath
        PackageVersion = $resolvedVersion
      }
      if (-not [string]::IsNullOrWhiteSpace($DatabaseStream)) {
        $newPackageParameters['Stream'] = $DatabaseStream
      }

      $nupkgPath = New-DatabaseChangePackage @newPackageParameters
      if ([string]::IsNullOrWhiteSpace($nupkgPath) -or -not (Test-Path -LiteralPath $nupkgPath -PathType Leaf)) {
        throw "New-DatabaseChangePackage did not return a valid .nupkg path for '$databasePackageId'."
      }
      Add-DatabasePackagePublishTrace -Path $tracePath -Message "Produced .nupkg '$nupkgPath'."

      $publishResult = Publish-DatabaseChangePackageToProGet `
        -NupkgPath $nupkgPath `
        -Feed $ExperimentalFeed
      Add-DatabasePackagePublishTrace -Path $tracePath -Message $publishResult.ResponseSummary

      if (-not [bool]$publishResult.Published) {
        throw "Publish-DatabaseChangePackageToProGet failed: $($publishResult.ResponseSummary)"
      }

      $nupkgFileName = [System.IO.Path]::GetFileNameWithoutExtension($nupkgPath)
      $resolvedFromArtifact = $nupkgFileName.Substring($databasePackageId.Length + 1)
      if (-not [string]::IsNullOrWhiteSpace($resolvedFromArtifact)) {
        $resolvedVersion = $resolvedFromArtifact
      }

      Write-BuildMasterRunContextJson `
        -ContextDirectory $contextDirectory `
        -BuildMasterBuildId $BuildMasterBuildId `
        -BuildNumber $BuildNumber `
        -ExecutionId $ExecutionId `
        -ApplicationName $ApplicationName `
        -Branch $Branch `
        -SourcePath $SourcePath `
        -ProjectPath $databasePackageSourcePath `
        -CurrentTier $Stage `
        -CeilingTier $effectiveCeilingTier `
        -ResolvedVersion $resolvedVersion `
        -PrereleaseLabel $prereleaseLabel `
        -AllowDecisions $allowDecisions `
        -StateFiles $stateFiles `
        -AdditionalData @{
          PipelineKind        = 'DatabaseChangePackage'
          DatabaseApplication = $DatabaseApplication
          DatabaseStream      = $DatabaseStream
          DatabasePackageId   = $databasePackageId
          NupkgPath           = $nupkgPath
          PackageVersion      = $resolvedVersion
        } | Out-Null

      # Apply the freshly built package to the Experimental tier database
      # (Database-Change-Unit-and-Flyway-Promotion.md section 5: "Apply migrations
      # against the empty Experimental SQL Server instance"). Enforced only
      # when an Experimental connection-string secret name is configured.
      Invoke-DatabasePackageStageApply `
        -ContextDirectory $contextDirectory `
        -DatabasePackageId $databasePackageId `
        -DatabaseApplication $DatabaseApplication `
        -PackageVersion $resolvedVersion `
        -Tier $Stage `
        -NupkgPath $nupkgPath `
        -ConnectionStringSecretName $tierConnectionSecretName `
        -SkipApply:$SkipApply `
        -TracePath $tracePath

      Set-DatabasePackageStageCompleted -ContextDirectory $contextDirectory -DatabasePackageId $databasePackageId -Tier $Stage -PackageVersion $resolvedVersion
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Published '$databasePackageId' '$resolvedVersion' to '$ExperimentalFeed'."
      return
    }

    # Promotion tier: Development / Integration / QA / Production.
    $previousTier = Get-PreviousDatabaseTier -Tier $Stage
    $fromFeed = Get-DatabaseFeedForTier -Tier $previousTier `
      -ExperimentalFeed $ExperimentalFeed -DevelopmentFeed $DevelopmentFeed `
      -IntegrationFeed $IntegrationFeed -QAFeed $QAFeed -ProductionFeed $ProductionFeed
    $toFeed = Get-DatabaseFeedForTier -Tier $Stage `
      -ExperimentalFeed $ExperimentalFeed -DevelopmentFeed $DevelopmentFeed `
      -IntegrationFeed $IntegrationFeed -QAFeed $QAFeed -ProductionFeed $ProductionFeed

    # Resolve the immutable .nupkg for this build (captured by the Experimental
    # stage in the shared build-id run-context folder). Needed by both the
    # pre-promotion rehearsal and the post-promotion apply.
    $stageNupkgPath = $null
    if ($null -ne $existingContext -and
      $existingContext.PSObject.Properties.Name -contains 'NupkgPath') {
      $stageNupkgPath = [string]$existingContext.NupkgPath
    }

    # Rehearsal-before-promotion, enforced in code (closes the gap flagged in
    # BuildMaster-Pipeline-Topology.md section 10 / Database-Change-Unit-and-Flyway-
    # Promotion.md section 5). Runs only when this tier has a connection-string secret
    # name configured and -SkipRehearsal was not supplied.
    if (-not [string]::IsNullOrWhiteSpace($tierConnectionSecretName)) {
      if ($SkipRehearsal) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
          -Message "Pre-promotion rehearsal BYPASSED (-SkipRehearsal) for '$databasePackageId' tier '$Stage'."
        Add-DatabasePackagePublishTrace -Path $tracePath -Message "Rehearsal bypassed (-SkipRehearsal) for tier '$Stage'."
      }
      elseif ([string]::IsNullOrWhiteSpace($stageNupkgPath) -or -not (Test-Path -LiteralPath $stageNupkgPath -PathType Leaf)) {
        throw "Pre-promotion rehearsal cannot run for '$databasePackageId' tier '$Stage': the build's immutable .nupkg was not found (captured NupkgPath='$stageNupkgPath'). Run the Experimental stage in the same workspace or transfer the build-id context folder."
      }
      else {
        $rehearsalLogPath = Join-Path -Path $contextDirectory -ChildPath "$databasePackageId.$($Stage.ToLowerInvariant()).rehearsal.json"
        Add-DatabasePackagePublishTrace -Path $tracePath -Message "Rehearsing '$databasePackageId' '$resolvedVersion' before promotion to tier '$Stage'."
        $rehearsalResult = Invoke-DatabasePackageTierRehearsal `
          -NupkgPath $stageNupkgPath `
          -Application $DatabaseApplication `
          -Tier $Stage `
          -BuildId $BuildMasterBuildId `
          -ConnectionStringSecretName $tierConnectionSecretName `
          -LogPath $rehearsalLogPath
        Add-DatabasePackagePublishTrace -Path $tracePath -Message "Rehearsal passed for tier '$Stage' (elapsed=$($rehearsalResult.ElapsedSeconds)s)."
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Database stage '$Stage' promoting '$databasePackageId' '$resolvedVersion' from '$fromFeed' to '$toFeed' (ceiling='$effectiveCeilingTier')."
    Add-DatabasePackagePublishTrace -Path $tracePath -Message "Promote '$databasePackageId' '$resolvedVersion' from '$fromFeed' to '$toFeed'."

    $promotionResult = Promote-DatabaseChangePackage `
      -PackageId $databasePackageId `
      -Version $resolvedVersion `
      -FromFeed $fromFeed `
      -ToFeed $toFeed `
      -Reason "$Stage gate for $ApplicationName $resolvedVersion on $Branch" `
      -Application $DatabaseApplication `
      -CeilingTier $effectiveCeilingTier
    Add-DatabasePackagePublishTrace -Path $tracePath -Message $promotionResult.ResponseSummary

    if (-not [bool]$promotionResult.Succeeded) {
      throw "Promote-DatabaseChangePackage failed: $($promotionResult.ResponseSummary)"
    }

    # Per-tier apply: the promotion only moved the immutable artifact between
    # feeds. Now migrate the tier's real database from that same artifact.
    Invoke-DatabasePackageStageApply `
      -ContextDirectory $contextDirectory `
      -DatabasePackageId $databasePackageId `
      -DatabaseApplication $DatabaseApplication `
      -PackageVersion $resolvedVersion `
      -Tier $Stage `
      -NupkgPath $stageNupkgPath `
      -ConnectionStringSecretName $tierConnectionSecretName `
      -SkipApply:$SkipApply `
      -TracePath $tracePath

    Set-DatabasePackageStageCompleted -ContextDirectory $contextDirectory -DatabasePackageId $databasePackageId -Tier $Stage -PackageVersion $resolvedVersion
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Promoted '$databasePackageId' '$resolvedVersion' to '$toFeed'. Ceiling='$effectiveCeilingTier'."
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Finished $fn for BuildId='$BuildMasterBuildId'."
  }
}

Invoke-DatabasePackageBuildMasterStage `
  -BuildToolingModulePath $BuildToolingModulePath `
  -SourcePath $SourcePath `
  -BuildMasterBuildId $BuildMasterBuildId `
  -BuildNumber $BuildNumber `
  -ExecutionId $ExecutionId `
  -ApplicationName $ApplicationName `
  -DatabaseApplication $DatabaseApplication `
  -DatabaseStream $DatabaseStream `
  -Branch $Branch `
  -Stage $Stage `
  -ProGetUrl $ProGetUrl `
  -ExperimentalFeed $ExperimentalFeed `
  -DevelopmentFeed $DevelopmentFeed `
  -IntegrationFeed $IntegrationFeed `
  -QAFeed $QAFeed `
  -ProductionFeed $ProductionFeed `
  -ExperimentalDatabaseDBConnectionStringSecretName $ExperimentalDatabaseDBConnectionStringSecretName `
  -DevelopmentDatabaseDBConnectionStringSecretName $DevelopmentDatabaseDBConnectionStringSecretName `
  -IntegrationDatabaseDBConnectionStringSecretName $IntegrationDatabaseDBConnectionStringSecretName `
  -QADatabaseDBConnectionStringSecretName $QADatabaseDBConnectionStringSecretName `
  -ProductionDatabaseDBConnectionStringSecretName $ProductionDatabaseDBConnectionStringSecretName `
  -SkipRehearsal:$SkipRehearsal `
  -SkipApply:$SkipApply
