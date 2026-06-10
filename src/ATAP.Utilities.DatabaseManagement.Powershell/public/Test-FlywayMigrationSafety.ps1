#Requires -Version 7.0
function Test-FlywayMigrationSafety {
  <#
.SYNOPSIS
    Classifies Flyway migrations in a database change package by destructive-change kind
    and blocks promotion if required evidence files are missing.

.DESCRIPTION
    Reads the manifest from a database change package (expanded folder or .nupkg) via
    Get-DatabasePackageManifest and iterates the `migrations` array.  Each migration
    entry that carries a non-empty `destructiveChangeKind` value is flagged.

    Destructive kinds that always require approval evidence:
      ColumnDrop, TableDrop, ColumnRename, TableRename, DataLoss, ConstraintDrop

    For each destructive migration the cmdlet checks whether a sibling
    `<script-basename>.evidence.json` file exists in the package folder.  If the
    evidence file is missing the migration is added to `MissingEvidence`.

    Returns a result object.  When `IsSafe = $false`, the list of destructive
    migrations and the list of migrations with missing evidence are populated so
    the caller can emit a human-readable error.

.PARAMETER PackagePath
    Path to an expanded database change package folder.

.PARAMETER NupkgPath
    Path to a `.nupkg` database change package file.  The cmdlet expands it
    to a temp folder automatically and cleans up on exit.

.OUTPUTS
    [PSCustomObject] @{
        IsSafe               = [bool]
        DestructiveMigrations = [string[]]   # script names with destructive kinds
        MissingEvidence      = [string[]]    # script names whose evidence file is absent
    }

.EXAMPLE
    Test-FlywayMigrationSafety -PackagePath 'C:\pkg\ATAPUtilities.Database.1.5.0'

.EXAMPLE
    Test-FlywayMigrationSafety -NupkgPath 'C:\feeds\ATAPUtilities.Database.1.5.0.nupkg'

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Task: TASKS_V4-DBA1.md DBA1-T04 / V4-E07.
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'PackagePath')]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'NupkgPath')]
    [ValidateNotNullOrEmpty()]
    [string]$NupkgPath
  )

  begin {
    $fn = 'Test-FlywayMigrationSafety'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
  }

  process {
    $destructiveKinds = @(
      'ColumnDrop', 'TableDrop', 'ColumnRename', 'TableRename',
      'DataLoss', 'ConstraintDrop'
    )

    # Resolve package path, expanding nupkg if necessary
    $expandedPath = $null
    $cleanupExpanded = $false

    if ($PSCmdlet.ParameterSetName -eq 'NupkgPath') {
      $expandedPath = Expand-DatabaseChangePackage -NupkgPath $NupkgPath
      $cleanupExpanded = $true
    } else {
      $expandedPath = $PackagePath
    }

    try {
      # Get the manifest
      $manifest = Get-DatabasePackageManifest -PackagePath $expandedPath

      $destructiveMigrations = [System.Collections.Generic.List[string]]::new()
      $missingEvidence       = [System.Collections.Generic.List[string]]::new()

      $migrations = @()
      if ($manifest.PSObject.Properties.Name -contains 'migrations' -and $null -ne $manifest.migrations) {
        $migrations = @($manifest.migrations)
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Evaluating $($migrations.Count) migration entries for destructive kinds" -Tag 'Flyway'

      foreach ($migration in $migrations) {
        $kind   = [string]($migration.destructiveChangeKind)
        $script = [string]($migration.script)

        if ([string]::IsNullOrWhiteSpace($kind) -or $kind -eq 'None') {
          continue
        }

        if ($kind -in $destructiveKinds) {
          $destructiveMigrations.Add($script)
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "Destructive migration detected: script='$script' kind='$kind'" -Tag 'Flyway'

          # Look for evidence file: <script-basename>.evidence.json
          $scriptBaseName    = [System.IO.Path]::GetFileNameWithoutExtension($script)
          $evidenceFile      = Join-Path $expandedPath "$scriptBaseName.evidence.json"

          if (-not (Test-Path $evidenceFile)) {
            $missingEvidence.Add($script)
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Missing evidence file for '$script': expected '$evidenceFile'" -Tag 'Flyway'
          }
        }
      }

      $isSafe = ($missingEvidence.Count -eq 0)

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "IsSafe=$isSafe  Destructive=$($destructiveMigrations.Count)  MissingEvidence=$($missingEvidence.Count)" `
        -Tag 'Flyway'

      Write-Output ([PSCustomObject]@{
          IsSafe                = $isSafe
          DestructiveMigrations = $destructiveMigrations.ToArray()
          MissingEvidence       = $missingEvidence.ToArray()
        })
    } finally {
      if ($cleanupExpanded -and $expandedPath -and (Test-Path $expandedPath)) {
        Remove-Item -Recurse -Force $expandedPath -ErrorAction SilentlyContinue
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
