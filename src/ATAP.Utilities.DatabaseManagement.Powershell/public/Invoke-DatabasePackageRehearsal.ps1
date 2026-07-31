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

.PARAMETER LogPath
    Optional path where the rehearsal result summary is written as JSON.

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
    [string]$LogPath
  )

  begin {
    $fn = 'Invoke-DatabasePackageRehearsal'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
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

      $appName = $Application
      if ([string]::IsNullOrWhiteSpace($appName)) {
        $appName = if ($manifest.PSObject.Properties.Name -contains 'dbChangeUnit') {
          $manifest.dbChangeUnit
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
          SqlInstance                = $SqlInstance
          DatabaseHost               = $DatabaseHost
          BundlePath                 = $expandedPath
          FlywayBasePath             = $expandedPath
          FlywaySqlMigrationsPath    = $packageMigrationsPath
          FlywayDataPath             = $packageDataPath
          FlywayTomlPath             = $packageFlywayTomlPath
        }
        if (-not [string]::IsNullOrWhiteSpace($RehearsalDb))        { $rehearsalParams['RehearsalDb']        = $RehearsalDb }
        if (-not [string]::IsNullOrWhiteSpace($DBConnectionStringSecretName)) { $rehearsalParams['DBConnectionStringSecretName'] = $DBConnectionStringSecretName }
        if (-not [string]::IsNullOrWhiteSpace($LogPath))             { $rehearsalParams['LogPath']             = $LogPath }

        $result = Invoke-FlywayRehearsal @rehearsalParams

        $output = [PSCustomObject]@{
          Success        = $result.Success
          PackagePath    = $expandedPath
          ValidateOutput = $result.ValidateOutput
          MigrateOutput  = $result.MigrateOutput
          ElapsedSeconds = $result.ElapsedSeconds
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
