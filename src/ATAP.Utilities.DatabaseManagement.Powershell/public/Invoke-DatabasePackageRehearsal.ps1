#Requires -Version 7.0
function Invoke-DatabasePackageRehearsal {
  <#
.SYNOPSIS
    Expands a database change package and runs a full Flyway validate + migrate
    rehearsal against a scratch database.

.DESCRIPTION
    Wraps Expand-DatabaseChangePackage and Invoke-FlywayRehearsal to provide a
    single, package-aware rehearsal entry point.  The caller passes either a
    `.nupkg` path or an already-expanded package folder; the cmdlet:

      1. Expands the package if a `.nupkg` path was supplied (cleans up on exit).
      2. Derives Flyway parameters from the manifest inside the package.
      3. Calls Invoke-FlywayRehearsal, capturing validate and migrate output.
      4. Returns a structured result object.

    This is the rehearsal step of the V4-E database package pipeline.  Running it
    successfully before promoting beyond Experimental is enforced by
    Invoke-DatabasePackageBuildMasterStage.

.PARAMETER NupkgPath
    Path to a `.nupkg` database change package.

.PARAMETER PackagePath
    Path to an already-expanded database change package folder.  Use this when
    you have already called Expand-DatabaseChangePackage separately.

.PARAMETER Application
    Application name passed to Invoke-FlywayRehearsal for naming the rehearsal
    database.  When omitted the cmdlet uses the `dbChangeUnit` field from the
    manifest.

.PARAMETER BuildId
    Build / pipeline-run identifier used by Invoke-FlywayRehearsal to name the
    ephemeral rehearsal database.  Defaults to the BUILDMASTER_BUILD_NUMBER or
    BUILD_BUILDID environment variables, then falls back to a timestamp.

.PARAMETER RehearsalDb
    Optional explicit rehearsal database name override.

.PARAMETER SqlInstance
    SQL Server named instance for the rehearsal database.
    Defaults to EXPWHERTZING.

.PARAMETER DatabaseHost
    SQL Server host.  Defaults to localhost.

.PARAMETER DBConnectionStringSecretName
    Bitwarden secure-note name whose password is a SQL connection string.
    Passed directly to Invoke-FlywayRehearsal.

.PARAMETER FlywayAdditionalArgs
    Optional ordered Flyway arguments forwarded unchanged to the rehearsal.

.PARAMETER ExpectedSourceDatabaseName
    Optional explicit source catalog expectation forwarded to Invoke-FlywayRehearsal
    only when bound. The helper validates the resolved source; this grants no authority.

.PARAMETER LogPath
    Optional path where the rehearsal result summary is written as JSON.

.PARAMETER LoginFixturePath
    Explicit Login verifier path; requires DecryptFixturePath, an explicitly bound
    ExpectedSourceDatabaseName and both exact package expectations. Forwarded unchanged.

.PARAMETER DecryptFixturePath
    Explicit Decrypt verifier path paired with LoginFixturePath.

.PARAMETER OrganizationFixturePath
    Explicit V170-to-V210 verifier. Selected only by the immutable manifest's
    target00210 and exact four organization migration names; older boundaries
    retain the paired Login/Decrypt flow. No new package is built here.

.PARAMETER ExpectedPackageName
    Actual nonempty trim-exact string expected in raw manifest dbChangeUnit.
    Required only for fixture opt-in; compared Ordinal before invoking the helper.

.PARAMETER ExpectedPackageVersion
    Actual nonempty trim-exact string expected in raw manifest appVersion.
    No version is inferred or normalized for fixture opt-in.

.OUTPUTS
    [PSCustomObject] @{
        Success        = [bool]
        PackagePath    = [string]   # expanded folder used
        ValidateOutput = [string]
        MigrateOutput  = [string]
        ElapsedSeconds = [double]
    }

.EXAMPLE
    Invoke-DatabasePackageRehearsal -NupkgPath 'C:\feeds\ATAPUtilities.Database.1.5.0.nupkg'

.EXAMPLE
    Invoke-DatabasePackageRehearsal -PackagePath 'C:\pkg\ATAPUtilities.Database.1.5.0' `
        -RehearsalDb 'ATAPUtilities-rehearsal-local'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T04 / V4-E07.
#>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'PackagePath')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'NupkgPath')]
    [ValidateNotNullOrEmpty()]
    [string]$NupkgPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'PackagePath')]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePath,

    [Parameter(Mandatory = $false)]
    [string]$Application,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BuildId = $(
      if ($env:BUILDMASTER_BUILD_NUMBER) { $env:BUILDMASTER_BUILD_NUMBER }
      elseif ($env:BUILD_BUILDID) { $env:BUILD_BUILDID }
      else { [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') }
    ),

    [Parameter(Mandatory = $false)]
    [string]$RehearsalDb,

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = 'EXPWHERTZING',

    [Parameter(Mandatory = $false)]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false)]
    [Alias('DBConnectionStringSecret', 'SecretName', 'BitwardenSecretName', 'BitwardenSecret')]
    [string]$DBConnectionStringSecretName,

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [string[]]$FlywayAdditionalArgs,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedSourceDatabaseName,

    [string]$LoginFixturePath,
    [string]$DecryptFixturePath,
    [string]$OrganizationFixturePath,
    [object]$ExpectedPackageName,
    [object]$ExpectedPackageVersion
  )

  begin {
    $fn = 'Invoke-DatabasePackageRehearsal'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    $fixtureRequested = $PSBoundParameters.ContainsKey('LoginFixturePath') -or
      $PSBoundParameters.ContainsKey('DecryptFixturePath') -or
      $PSBoundParameters.ContainsKey('OrganizationFixturePath') -or
      $PSBoundParameters.ContainsKey('ExpectedPackageName') -or
      $PSBoundParameters.ContainsKey('ExpectedPackageVersion')
    if ($fixtureRequested) {
      foreach ($fixtureParameter in @('LoginFixturePath', 'DecryptFixturePath', 'ExpectedSourceDatabaseName', 'ExpectedPackageName', 'ExpectedPackageVersion')) {
        $fixtureValue = $PSBoundParameters[$fixtureParameter]
        if (-not $PSBoundParameters.ContainsKey($fixtureParameter) -or $fixtureValue -isnot [string] -or
            [string]::IsNullOrWhiteSpace($fixtureValue) -or
            -not [string]::Equals($fixtureValue, $fixtureValue.Trim(), [StringComparison]::Ordinal)) {
          throw "Fixture rehearsal requires explicit nonempty trim-exact '$fixtureParameter'."
        }
      }
    }
  }

  process {
    $ownedExpanded  = $false
    $expandedPath   = $null

    # Expand nupkg if needed
    if ($PSCmdlet.ParameterSetName -eq 'NupkgPath') {
      if (-not (Test-Path $NupkgPath)) {
        $PSCmdlet.ThrowTerminatingError(
          [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileNotFoundException]::new("nupkg not found: '$NupkgPath'"),
            'NupkgNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $NupkgPath
          )
        )
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Expanding '$NupkgPath'" -Tag 'Rehearsal'
      $expandedPath  = Expand-DatabaseChangePackage -NupkgPath $NupkgPath
      $ownedExpanded = $true
    } else {
      $expandedPath = $PackagePath
    }

    try {
      # Read manifest to derive Application name if not supplied
      $manifest = Get-DatabasePackageManifest -PackagePath $expandedPath

      if ($fixtureRequested) {
        foreach ($identityField in @('dbChangeUnit', 'appVersion')) {
          if ($null -eq $manifest -or $manifest.PSObject.Properties.Name -notcontains $identityField) {
            throw "Fixture package manifest is missing '$identityField'."
          }
          $identityValue = $manifest.$identityField
          if ($identityValue -isnot [string] -or [string]::IsNullOrWhiteSpace($identityValue) -or
              -not [string]::Equals($identityValue, $identityValue.Trim(), [StringComparison]::Ordinal)) {
            throw "Fixture package manifest '$identityField' must be an actual nonempty trim-exact string."
          }
        }
        if (-not [string]::Equals($manifest.dbChangeUnit, $ExpectedPackageName, [StringComparison]::Ordinal) -or
            -not [string]::Equals($manifest.appVersion, $ExpectedPackageVersion, [StringComparison]::Ordinal)) {
          throw 'Fixture package manifest identity does not match the explicit expectations.'
        }
      }

      $organizationRequested = $false
      if ($fixtureRequested -and ($PSBoundParameters.ContainsKey('OrganizationFixturePath') -or
          $manifest.PSObject.Properties.Name -contains 'flywayTargetVersion')) {
        $target = [string]$manifest.flywayTargetVersion
        if ($target -ceq '00210') {
          if ($ExpectedPackageName -cne 'ATAPUtilities.Database' -or $ExpectedSourceDatabaseName -cne 'ATAPUtilities' -or
              [string]::IsNullOrWhiteSpace($OrganizationFixturePath) -or
              -not [IO.Path]::IsPathFullyQualified($OrganizationFixturePath)) {
            throw 'Organization rehearsal requires its exact package/catalog and absolute verifier path.'
          }
          $expectedNew = @('V00180__Create_Organization_Eligibility_Schema.sql',
            'V00190__Create_ReadOrganizationEligibility_Procedure.sql',
            'V00200__Create_Organization_Bootstrap.sql', 'V00210__Create_ReadOrganizationProject_Procedure.sql')
          $migrationNames = @($manifest.files | Where-Object kind -EQ 'migration' | ForEach-Object { [IO.Path]::GetFileName($_.path) })
          $newNames = @($migrationNames | Where-Object { $_ -cmatch '^V00(180|190|200|210)__' } | Sort-Object)
          if ($migrationNames.Count -ne 20 -or ($newNames -join '|') -cne ($expectedNew -join '|')) {
            throw 'Organization rehearsal requires the sixteen predecessors and exact four V180-V210 migrations.'
          }
          $organizationRequested = $true
        }
        elseif ($target -cnotin @('00160', '00170')) {
          throw 'Selected fixture rehearsal does not support this manifest migration boundary.'
        }
      }

      $appName = $Application
      if ([string]::IsNullOrWhiteSpace($appName)) {
        $appName = if ($manifest.PSObject.Properties.Name -contains 'dbChangeUnit') {
          ([string]$manifest.dbChangeUnit -replace '\.Database$', '')
        } else {
          [System.IO.Path]::GetFileName($expandedPath)
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Starting rehearsal for Application='$appName' BuildId='$BuildId'" -Tag 'Rehearsal'

      if ($PSCmdlet.ShouldProcess("$appName (BuildId=$BuildId)", 'Run Flyway rehearsal')) {
        $packageMigrationsPath = Join-Path $expandedPath 'db\migrations'
        $packageDataPath = Join-Path $expandedPath 'db\seeds'
        $packageFlywayTomlPath = Join-Path $expandedPath 'flyway.toml'
        foreach ($requiredPath in @($packageMigrationsPath, $packageDataPath, $packageFlywayTomlPath)) {
          if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Database package is not deployable: required path '$requiredPath' is missing."
          }
        }

        $rehearsalParams = @{
          Application                 = $appName
          BuildId                    = $BuildId
          SourceDatabaseName          = $appName
          BundlePath                 = $expandedPath
          FlywayBasePath             = $expandedPath
          FlywaySqlMigrationsPath    = $packageMigrationsPath
          FlywayDataPath             = $packageDataPath
          FlywayTomlPath             = $packageFlywayTomlPath
        }
        if (-not [string]::IsNullOrWhiteSpace($RehearsalDb))        { $rehearsalParams['RehearsalDb']        = $RehearsalDb }
        if (-not [string]::IsNullOrWhiteSpace($DBConnectionStringSecretName)) {
          $rehearsalParams['DBConnectionStringSecretName'] = $DBConnectionStringSecretName
        }
        else {
          $rehearsalParams['SqlInstance'] = $SqlInstance
          $rehearsalParams['DatabaseHost'] = $DatabaseHost
        }
        if (-not [string]::IsNullOrWhiteSpace($LogPath))             { $rehearsalParams['LogPath']             = $LogPath }

        if ($PSBoundParameters.ContainsKey('FlywayAdditionalArgs')) { $rehearsalParams['FlywayAdditionalArgs'] = $FlywayAdditionalArgs }
        if ($PSBoundParameters.ContainsKey('ExpectedSourceDatabaseName')) { $rehearsalParams['ExpectedSourceDatabaseName'] = $ExpectedSourceDatabaseName }
        if ($fixtureRequested) {
          if ($organizationRequested) {
            $rehearsalParams['OrganizationFixturePath'] = $OrganizationFixturePath
          }
          else {
            $rehearsalParams['LoginFixturePath'] = $LoginFixturePath
            $rehearsalParams['DecryptFixturePath'] = $DecryptFixturePath
          }
          $rehearsalParams['PackageName'] = $manifest.dbChangeUnit
          $rehearsalParams['PackageVersion'] = $manifest.appVersion
        }

        $rehearsalStarted = [datetime]::UtcNow
        $result = Invoke-FlywayRehearsal @rehearsalParams
        $elapsedSeconds = ([datetime]::UtcNow - $rehearsalStarted).TotalSeconds
        $validateOutput = if ($result.PSObject.Properties.Name -contains 'ValidateOutput') {
          $result.ValidateOutput
        }
        else {
          $null
        }
        $migrateOutput = if ($result.PSObject.Properties.Name -contains 'MigrateOutput') {
          $result.MigrateOutput
        }
        elseif ($result.PSObject.Properties.Name -contains 'FlywayResult') {
          $result.FlywayResult
        }
        else {
          $null
        }
        if ($result.PSObject.Properties.Name -contains 'ElapsedSeconds') {
          $elapsedSeconds = [double]$result.ElapsedSeconds
        }

        $output = [PSCustomObject]@{
          Success        = $result.Success
          PackagePath    = $expandedPath
          ValidateOutput = $validateOutput
          MigrateOutput  = $migrateOutput
          ElapsedSeconds = $elapsedSeconds
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Rehearsal complete: Success=$($output.Success)  Elapsed=$($output.ElapsedSeconds)s" -Tag 'Rehearsal'

        Write-Output $output
      }
    } finally {
      if ($ownedExpanded -and $expandedPath -and (Test-Path $expandedPath)) {
        Remove-Item -Recurse -Force $expandedPath -ErrorAction SilentlyContinue
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
