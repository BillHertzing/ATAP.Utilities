<#
.SYNOPSIS
Compresses a PowerShell module's generated test-results, coverage, and
packages folders into three .7z archives under artifacts/.

.DESCRIPTION
Given an OutputRoot (typically '<RepoRoot>/_generated/psmodules/<Module>/'
returned by Resolve-PSModuleMetadata), this cmdlet ensures the artifacts
subfolder exists, then for each of the three expected source directories
(test-results, coverage, packages) it calls '7z a -t7z <archive> <source>/*'.
Missing or empty source directories are skipped with a warning and their
slot in the return object is set to $null.

.PARAMETER OutputRoot
Root of the module's _generated tree. Must exist. Typically produced by
Resolve-PSModuleMetadata.

.OUTPUTS
[PSCustomObject] with fields:
  - TestResultsArchive    : Absolute path to TestResults.7z, or $null if
                            test-results was missing/empty.
  - CoverageReportArchive : Absolute path to CoverageReport.7z, or $null.
  - PackagesArchive       : Absolute path to Packages.7z, or $null.

.EXAMPLE
$meta = Resolve-PSModuleMetadata
Compress-PSModuleArtifacts -OutputRoot $meta.OutputRoot

Produces (when all three source folders are populated)
  $meta.OutputRoot/artifacts/TestResults.7z
  $meta.OutputRoot/artifacts/CoverageReport.7z
  $meta.OutputRoot/artifacts/Packages.7z

.NOTES
AI assisted using Powershell.instructions.md as guidelines

Tier: T1 (Phase 1, task T-1A). Requires 7z.exe on PATH
(`choco install 7zip`).
#>
function Compress-PSModuleArtifacts {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [string]$OutputRoot
  )

  begin {
    $fn = 'Compress-PSModuleArtifacts'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    # Check and populate simple parameter: OutputRoot
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
      $msg = "Parameter 'OutputRoot' is null or empty."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with OutputRoot='$OutputRoot'" -Tag 'Trace'
  }

  process {
    if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
      $msg = "OutputRoot does not exist or is not a directory: '$OutputRoot'"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    # 1. Resolve 7z.exe.
    $sevenZipCmd = Get-Command -Name '7z.exe' -ErrorAction SilentlyContinue
    if ($null -eq $sevenZipCmd) {
      $msg = "7z.exe was not found on PATH. Install it with 'choco install 7zip' (or equivalent) and retry."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }
    $sevenZipPath = $sevenZipCmd.Source
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Using 7z.exe at '$sevenZipPath'"

    # Normalize OutputRoot.
    $resolvedOutputRoot = (Resolve-Path -LiteralPath $OutputRoot).ProviderPath -replace '\\', '/'
    $resolvedOutputRoot = $resolvedOutputRoot.TrimEnd('/')

    # 2. Ensure artifacts folder exists.
    $artifactsDir = "$resolvedOutputRoot/artifacts"
    if (-not (Test-Path -LiteralPath $artifactsDir -PathType Container)) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating artifacts directory '$artifactsDir'"
      New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
    }

    # 3. For each source -> archive pair, compress when the source is non-empty.
    $pairs = @(
      [PSCustomObject]@{ Key = 'TestResultsArchive'; Source = "$resolvedOutputRoot/test-results"; Archive = "$artifactsDir/TestResults.7z" }
      [PSCustomObject]@{ Key = 'CoverageReportArchive'; Source = "$resolvedOutputRoot/coverage"; Archive = "$artifactsDir/CoverageReport.7z" }
      [PSCustomObject]@{ Key = 'PackagesArchive'; Source = "$resolvedOutputRoot/packages"; Archive = "$artifactsDir/Packages.7z" }
    )

    $result = [ordered]@{
      TestResultsArchive    = $null
      CoverageReportArchive = $null
      PackagesArchive       = $null
    }

    foreach ($pair in $pairs) {
      $src = $pair.Source
      $archive = $pair.Archive
      $key = $pair.Key

      if (-not (Test-Path -LiteralPath $src -PathType Container)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Source directory missing; skipping archive for '$key': '$src'"
        continue
      }
      $srcItems = @(Get-ChildItem -LiteralPath $src -Force -ErrorAction SilentlyContinue)
      if ($srcItems.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Source directory is empty; skipping archive for '$key': '$src'"
        continue
      }

      # Remove a stale archive so 7z does not append to it.
      if (Test-Path -LiteralPath $archive -PathType Leaf) {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
      }

      $glob = "$src/*"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking 7z.exe a -t7z '$archive' '$glob'"
      try {
        & $sevenZipPath a -t7z $archive $glob | Out-Null
        $exit = $LASTEXITCODE
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "7z.exe returned exit code $exit for '$archive'"
        if ($exit -ne 0) {
          $msg = "7z.exe failed with exit code $exit creating '$archive' from '$src'."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
          throw $msg
        }
        $result[$key] = $archive
      } catch {
        $msg = "Error creating archive '$archive' from '$src': $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
    }

    [PSCustomObject]$result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}
