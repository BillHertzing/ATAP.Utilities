function Invoke-FlywayManifest {
  <#
  .SYNOPSIS
  Generates Flyway manifest placeholder environment variables, then runs flyway migrate.

  .DESCRIPTION
  Computes SHA256 hashes for specified migration/repeatable SQL files under -SqlDir, builds a comma‑separated
  (VALUES …) list for insertion (ManifestValues), and exports these plus package / git metadata into environment
  variables using Flyway's placeholder naming convention (FLYWAY_PLACEHOLDERS_*). After exporting, it invokes
  'flyway migrate' (unless -NoMigrate is specified). This replaces earlier behavior that executed a SQL template.

  Exported environment variables:
    FLYWAY_PLACEHOLDERS_MANIFESTVALUES
    FLYWAY_PLACEHOLDERS_PACKAGENAME
    FLYWAY_PLACEHOLDERS_PACKAGEVERSION
    FLYWAY_PLACEHOLDERS_GITTAG
    FLYWAY_PLACEHOLDERS_GITCOMMIT

  .PARAMETER SqlDir
  Directory containing Flyway SQL scripts (default .\sql).

  .PARAMETER Files
  File names (relative to -SqlDir) to include in the manifest values list.

  .PARAMETER PackageName
  Logical package/component name.

  .PARAMETER PackageVersion
  Version string for the package.

  .PARAMETER ConfigPath
  Path to flyway.conf (used for flyway -configFiles argument only; not parsed here).

  .PARAMETER GitTag
  Optional explicit Git tag (otherwise discovered).

  .PARAMETER GitCommit
  Optional explicit Git commit (otherwise discovered).

  .PARAMETER FlywayPath
  Executable or path for the flyway CLI (default 'flyway').

  .PARAMETER FlywayAdditionalArgs
  Additional raw arguments passed to flyway before the 'migrate' verb (e.g. '-X').

  .PARAMETER NoMigrate
  If set, only sets environment variables; does not invoke flyway.

  .OUTPUTS
  PSCustomObject summarizing placeholders and (optionally) flyway execution result.

  .EXAMPLE
  Invoke-FlywayManifest -PackageName BuildSets.Functions -PackageVersion 0.0.00008 -Files (Get-ChildItem .\sql -Filter 'V*__*.sql').Name

  .EXAMPLE
  Invoke-FlywayManifest -PackageName BuildSets.Functions -PackageVersion 0.0.00008 -Files V00.01.000010__Init.sql -NoMigrate

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param(
    [string]$SqlDir = '.\sql',
    [Parameter(Mandatory = $true)] [string[]]$Files,
    [Parameter(Mandatory = $true)] [string]$PackageName,
    [Parameter(Mandatory = $true)] [string]$PackageVersion,
    [string]$ConfigPath = '.\flyway.toml',
    [string]$GitTag,
    [string]$GitCommit,
    [string]$FlywayPath = 'flyway',
    [string[]]$FlywayAdditionalArgs,
    [switch]$NoMigrate
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Entering function Invoke-FlywayManifest'
    $script:errors = [System.Collections.Generic.List[string]]::new()
    $script:success = $false

    function _Get-GitMeta {
      param([string]$StartDir)
      $git = Get-Command git -ErrorAction SilentlyContinue
      if (-not $git) { return @{ Tag = '(no-git)'; Commit = '(no-git)' } }
      $tag = $null; try { $tag = (git -C $StartDir describe --tags --abbrev=0 2>$null).Trim() } catch {}
      if (-not $tag) { $tag = '(untagged)' }
      $commit = (git -C $StartDir rev-parse --short HEAD 2>$null).Trim(); if (-not $commit) { $commit = '(no-commit)' }
      @{ Tag = $tag; Commit = $commit }
    }
  }

  PROCESS {
    # Validate inputs
    try {
      if (-not (Test-Path $SqlDir)) { throw "SqlDir not found: $SqlDir" }
      if ($Files.Count -eq 0) { throw 'At least one -Files entry is required.' }
      if (-not (Test-Path $ConfigPath)) { throw "ConfigPath not found: $ConfigPath" }
    }
    catch {
      $msg = "Input validation failure. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $msg
      $script:errors.Add($msg) | Out-Null
      throw
    }

    # Git metadata
    try {
      $gitMeta = _Get-GitMeta -StartDir (Resolve-Path .)
      if (-not $GitTag) { $GitTag = $gitMeta.Tag }
      if (-not $GitCommit) { $GitCommit = $gitMeta.Commit }
    }
    catch {
      $msg = "Failed obtaining git metadata. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Warning -Message $msg
      $script:errors.Add($msg) | Out-Null
    }

    # Build manifest values list
    $values = @()
    try {
      foreach ($name in $Files) {
        $full = Join-Path $SqlDir $name
        if (-not (Test-Path $full)) { throw "File not found: $full" }
        $sha = (Get-FileHash -Path $full -Algorithm SHA256).Hash.ToLower()
        $type = if ($name -like 'R__*') { 'R' } elseif ($name -like 'V*__*') { 'V' } else { 'R' }
        $fileNameSql = ($name -replace "'", "''")
        $values += "(N'$fileNameSql', '$type', N'$sha')"
      }
    }
    catch {
      $msg = "Failed hashing files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $msg
      $script:errors.Add($msg) | Out-Null
      throw
    }
    $valuesList = ($values -join ',')

    # Export environment variables (Flyway placeholder form)
    Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Exporting Flyway placeholder environment variables'
    $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES = $valuesList
    $env:FLYWAY_PLACEHOLDERS_PACKAGENAME = $PackageName
    $env:FLYWAY_PLACEHOLDERS_PACKAGEVERSION = $PackageVersion
    $env:FLYWAY_PLACEHOLDERS_GITTAG = $GitTag
    $env:FLYWAY_PLACEHOLDERS_GITCOMMIT = $GitCommit

    Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Important -Message "Prepared placeholders for Package=$PackageName Version=$PackageVersion Tag=$GitTag Commit=$GitCommit Files=$($Files.Count)"

    if ($NoMigrate) {
      Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Verbose -Message 'Skipping flyway migrate due to -NoMigrate'
      $script:success = ($script:errors.Count -eq 0)
      return
    }

    $flywayParams = @("-configFiles=$ConfigPath")
    if ($FlywayAdditionalArgs) { $flywayParams += $FlywayAdditionalArgs }
    $flywayParams += 'migrate'

    if ($PSCmdlet.ShouldProcess($ConfigPath, 'flyway migrate')) {
      try {
        Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "Calling flyway with args: $($flywayParams -join ' ')"
        & $FlywayPath @flywayParams
        $exit = $LASTEXITCODE
        if ($exit -ne 0) { throw "flyway exited with code $exit" }
        Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Successfully returned from flyway migrate'
        $script:success = $true
      }
      catch {
        $msg = "flyway migrate failed. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message $msg
        if ($_.Exception.StackTrace) { Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message "StackTrace: $($_.Exception.StackTrace)" }
        $script:errors.Add($msg) | Out-Null
        throw
      }
      finally {
        Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Finished flyway migrate attempt'
      }
    }
  }

  END {
    $summary = [PSCustomObject]@{
      PackageName    = $PackageName
      PackageVersion = $PackageVersion
      GitTag         = $GitTag
      GitCommit      = $GitCommit
      FileCount      = $Files.Count
      ManifestValues = $env:FLYWAY_PLACEHOLDERS_MANIFESTVALUES
      Success        = ($script:errors.Count -eq 0 -and $script:success)
      Errors         = $script:errors.ToArray()
      RanMigrate     = (-not $NoMigrate.IsPresent)
      TimestampUTC   = (Get-Date).ToUniversalTime()
    }
    $level = if ($summary.Success) { 'Important' } else { 'Error' }
    Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level $level -Message ("Manifest variables generation {0}" -f ($(if ($summary.Success) { 'succeeded' } else { 'failed' })))
    if (-not $summary.Success) { Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Error -Message ("Errors:`n" + ($summary.Errors -join [Environment]::NewLine)) }
    Write-PSFMessage -FunctionName 'Invoke-FlywayManifest' -ModuleName 'ATAP.Utilities.Databases' -Level Debug -Message 'Leaving function Invoke-FlywayManifest'
    return $summary
  }
}
