#Requires -Version 7.0
<#
.SYNOPSIS
    Compares two canonical ReleaseBundle manifest-v2 records.
.DESCRIPTION
    Reports deterministic changes in application provenance, library package pins,
    application payload evidence, and the separate database-package reference.
    Ordinary schema-v1 and embedded-database manifests are rejected.
.PARAMETER Old
    Earlier manifest object or path.
.PARAMETER New
    Later manifest object or path.
.OUTPUTS
    PSCustomObject containing normalized added, removed, and changed records.
#>
function Compare-ReleaseManifest {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNull()][object]$Old,
    [Parameter(Mandatory)][ValidateNotNull()][object]$New
  )

  begin {
    $fn = 'Compare-ReleaseManifest'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    if (-not (Get-Command -Name Get-DeployedReleaseManifest -CommandType Function -ErrorAction SilentlyContinue)) {
      $readerPath = Join-Path $PSScriptRoot 'Get-DeployedReleaseManifest.ps1'
      if (-not (Test-Path -LiteralPath $readerPath -PathType Leaf)) {
        throw "Compare-ReleaseManifest needs Get-DeployedReleaseManifest, but '$readerPath' was not found."
      }
      . $readerPath
    }

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $srcRoot = Split-Path -Parent $moduleRoot
    $repoRoot = Split-Path -Parent $srcRoot
    $schemaPath = Join-Path $repoRoot 'SolutionDocumentation\schemas\manifest.schema.json'

    $resolveManifest = {
      param([object]$InputObject,[string]$Name)
      if ($InputObject -is [string]) { $manifest = Get-DeployedReleaseManifest -Path $InputObject }
      elseif ($InputObject -is [IO.FileInfo]) { $manifest = Get-DeployedReleaseManifest -Path $InputObject.FullName }
      elseif ($InputObject -is [Collections.IDictionary]) { $manifest = [pscustomobject]$InputObject }
      elseif ($InputObject -is [pscustomobject]) { $manifest = $InputObject }
      else { throw "Compare-ReleaseManifest -$Name expects a manifest object or a path to manifest.json. Received '$($InputObject.GetType().FullName)'." }

      if (($manifest.schemaVersion -isnot [int] -and $manifest.schemaVersion -isnot [long]) -or [long]$manifest.schemaVersion -ne 2) {
        throw "ATAPBUILD014: $Name manifest must use numeric schemaVersion 2; ordinary v1 is rejected."
      }
      foreach ($legacy in @('databasePackageIncluded','dbChangeUnit','flywayTargetVersion','migrationFiles','seedDataFiles','checksums')) {
        if ($manifest.PSObject.Properties.Name -contains $legacy) {
          throw "ATAPBUILD015: $Name manifest contains forbidden legacy database field '$legacy'."
        }
      }
      try {
        $manifestJson = $manifest | ConvertTo-Json -Depth 20
        if (-not (Test-Json -Json $manifestJson -SchemaFile $schemaPath -ErrorAction Stop)) {
          throw 'Test-Json returned false.'
        }
      } catch {
        throw "ATAPBUILD014: $Name manifest failed canonical v2 schema validation. $($_.Exception.Message)"
      }
      return $manifest
    }

    $toMap = {
      param([object[]]$Items,[string]$KeyName,[string]$Kind)
      $map = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($item in @($Items)) {
        $key = [string]$item.$KeyName
        if ([string]::IsNullOrWhiteSpace($key) -or $map.ContainsKey($key)) {
          throw "ATAPBUILD014: $Kind contains a missing or duplicate ordinal key '$key'."
        }
        $map.Add($key,$item)
      }
      return $map
    }

    $canonical = {
      param([object]$Value)
      $Value | ConvertTo-Json -Depth 10 -Compress
    }
  }

  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    $oldManifest = & $resolveManifest $Old 'Old'
    $newManifest = & $resolveManifest $New 'New'

    $oldPackages = & $toMap @($oldManifest.includedLibraryPackages) 'id' 'includedLibraryPackages'
    $newPackages = & $toMap @($newManifest.includedLibraryPackages) 'id' 'includedLibraryPackages'
    $addedPackages = @($newPackages.Keys | Where-Object { -not $oldPackages.ContainsKey($_) } | Sort-Object | ForEach-Object { $newPackages[$_] })
    $removedPackages = @($oldPackages.Keys | Where-Object { -not $newPackages.ContainsKey($_) } | Sort-Object | ForEach-Object { $oldPackages[$_] })
    $changedPackages = @($oldPackages.Keys | Where-Object { $newPackages.ContainsKey($_) -and $oldPackages[$_].version -cne $newPackages[$_].version } | Sort-Object | ForEach-Object {
      [pscustomobject]@{Id=$_;OldVersion=$oldPackages[$_].version;NewVersion=$newPackages[$_].version}
    })

    $oldPayload = & $toMap @($oldManifest.payloadFiles) 'path' 'payloadFiles'
    $newPayload = & $toMap @($newManifest.payloadFiles) 'path' 'payloadFiles'
    $addedPayload = @($newPayload.Keys | Where-Object { -not $oldPayload.ContainsKey($_) } | Sort-Object | ForEach-Object { $newPayload[$_] })
    $removedPayload = @($oldPayload.Keys | Where-Object { -not $newPayload.ContainsKey($_) } | Sort-Object | ForEach-Object { $oldPayload[$_] })
    $changedPayload = @($oldPayload.Keys | Where-Object { $newPayload.ContainsKey($_) -and ((& $canonical $oldPayload[$_]) -cne (& $canonical $newPayload[$_])) } | Sort-Object | ForEach-Object {
      [pscustomobject]@{Path=$_;OldChecksum=$oldPayload[$_].checksumSha256;NewChecksum=$newPayload[$_].checksumSha256;OldSizeBytes=$oldPayload[$_].sizeBytes;NewSizeBytes=$newPayload[$_].sizeBytes}
    })

    $oldComponents = & $toMap (@($oldManifest.applicationProvenance.root)+@($oldManifest.applicationProvenance.components)) 'projectPath' 'applicationProvenance'
    $newComponents = & $toMap (@($newManifest.applicationProvenance.root)+@($newManifest.applicationProvenance.components)) 'projectPath' 'applicationProvenance'
    $addedComponents = @($newComponents.Keys | Where-Object { -not $oldComponents.ContainsKey($_) } | Sort-Object | ForEach-Object { $newComponents[$_] })
    $removedComponents = @($oldComponents.Keys | Where-Object { -not $newComponents.ContainsKey($_) } | Sort-Object | ForEach-Object { $oldComponents[$_] })
    $changedComponents = @($oldComponents.Keys | Where-Object { $newComponents.ContainsKey($_) -and ((& $canonical $oldComponents[$_]) -cne (& $canonical $newComponents[$_])) } | Sort-Object | ForEach-Object {
      [pscustomobject]@{ProjectPath=$_;Old=$oldComponents[$_];New=$newComponents[$_]}
    })

    $oldDatabase = $oldManifest.databasePackageReference
    $newDatabase = $newManifest.databasePackageReference
    $databaseChanged = (& $canonical $oldDatabase) -cne (& $canonical $newDatabase)
    $differenceCount = $addedPackages.Count+$removedPackages.Count+$changedPackages.Count+$addedPayload.Count+$removedPayload.Count+$changedPayload.Count+$addedComponents.Count+$removedComponents.Count+$changedComponents.Count+[int]$databaseChanged
    $summary = "Compared v2 release '$($oldManifest.releaseVersion)' to '$($newManifest.releaseVersion)': libraries +$($addedPackages.Count) -$($removedPackages.Count) ~$($changedPackages.Count); payload +$($addedPayload.Count) -$($removedPayload.Count) ~$($changedPayload.Count); components +$($addedComponents.Count) -$($removedComponents.Count) ~$($changedComponents.Count); database reference changed=$databaseChanged."
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary

    return [pscustomobject]@{
      OperationName='Compare-ReleaseManifest';OldReleaseVersion=[string]$oldManifest.releaseVersion;NewReleaseVersion=[string]$newManifest.releaseVersion
      HasDifferences=($differenceCount -gt 0)
      AddedLibraryPackages=$addedPackages;RemovedLibraryPackages=$removedPackages;ChangedLibraryPackages=$changedPackages
      AddedPayloadFiles=$addedPayload;RemovedPayloadFiles=$removedPayload;ChangedPayloadFiles=$changedPayload
      AddedApplicationComponents=$addedComponents;RemovedApplicationComponents=$removedComponents;ChangedApplicationComponents=$changedComponents
      DatabasePackageReferenceChanged=$databaseChanged;OldDatabasePackageReference=$oldDatabase;NewDatabasePackageReference=$newDatabase
      ResponseSummary=$summary
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
  }
}