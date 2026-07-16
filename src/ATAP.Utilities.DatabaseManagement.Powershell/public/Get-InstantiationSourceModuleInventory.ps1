#Requires -Version 7.0
function Get-InstantiationSourceModuleInventory {
  <#
.SYNOPSIS
    Scans repository PowerShell module folders into the Instantiation SourceModule model.

.DESCRIPTION
    Reads a repository source tree and returns database-shaped SourceModule inventory rows
    for PowerShell modules. The returned objects align with the Sprint 0012
    ATAPUtilities.SourceModule table and include manifestation artifact hints that later
    renderers can compare with the real repository state.

    This cmdlet is read-only. It does not connect to SQL Server and does not write files.

.PARAMETER RepositoryRoot
    Repository root to scan. Defaults to the current location.

.PARAMETER SourceRootRelativePath
    Source folder path relative to RepositoryRoot. Defaults to src.

.PARAMETER RepositoryName
    Logical repository name carried into each returned model row.

.PARAMETER RepositoryPhiloteId
    Optional repository Philote identifier copied into each returned model row.

.PARAMETER PlannedPowerShellModuleName
    Planned PowerShell module names that do not yet exist on disk. Each becomes a
    PlannedPowerShell SourceModule row unless a discovered module already has that name.

.PARAMETER IncludeCSharp
    Include C# project folders that contain a .csproj file. This is useful for
    v1/v2 manifestation verification because the initial Sprint 0012 seed also
    includes the ATAP.Utilities.Secrets C# module.

.OUTPUTS
    PSCustomObject rows shaped for ATAPUtilities.SourceModule ingestion.

.EXAMPLE
    Get-InstantiationSourceModuleInventory -RepositoryRoot 'C:\src\ATAP.Utilities'

.EXAMPLE
    Get-InstantiationSourceModuleInventory -RepositoryRoot 'C:\src\ATAP.Utilities' -PlannedPowerShellModuleName 'ATAP.Utilities.Secrets.PowerShell'
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot = (Get-Location).Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceRootRelativePath = 'src',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryName = 'ATAP.Utilities',

    [Parameter()]
    [guid]$RepositoryPhiloteId,

    [Parameter()]
    [ValidateNotNull()]
    [string[]]$PlannedPowerShellModuleName = @(),

    [Parameter()]
    [switch]$IncludeCSharp
  )

  begin {
    $fn = 'Get-InstantiationSourceModuleInventory'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    function ConvertTo-InstantiationRelativePath {
      param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$Path
      )

      $relativePath = [System.IO.Path]::GetRelativePath($BasePath, $Path)
      return $relativePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    }

    function New-InstantiationStableGuid {
      param(
        [Parameter(Mandatory = $true)]
        [string]$NaturalKey
      )

      $sha256 = [System.Security.Cryptography.SHA256]::Create()
      try {
        $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($NaturalKey.ToLowerInvariant()))
      } finally {
        $sha256.Dispose()
      }

      $guidBytes = [byte[]]::new(16)
      [Array]::Copy($hash, $guidBytes, 16)
      $guidBytes[7] = ($guidBytes[7] -band 0x0f) -bor 0x50
      $guidBytes[8] = ($guidBytes[8] -band 0x3f) -bor 0x80
      return [guid]::new($guidBytes)
    }

    function New-InstantiationArtifact {
      param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactKind,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter()]
        [string]$SourceModulePhiloteId,

        [Parameter()]
        [string]$RenderPolicy = 'InspectOnly',

        [Parameter()]
        [int]$SortOrder = 0
      )

      return [PSCustomObject]@{
        EntityKind                = 'ManifestationArtifact'
        ArtifactKind              = $ArtifactKind
        RelativePath              = $RelativePath
        SourceObjectKind          = 'SourceModule'
        SourceObjectPhiloteId     = $SourceModulePhiloteId
        RenderPolicy              = $RenderPolicy
        SortOrder                 = $SortOrder
      }
    }
  }

  process {
    try {
      $repositoryRootItem = Get-Item -LiteralPath $RepositoryRoot -ErrorAction Stop
      $resolvedRepositoryRoot = $repositoryRootItem.FullName
      $sourceRoot = Join-Path $resolvedRepositoryRoot $SourceRootRelativePath

      if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        $msg = "Source root not found: '$sourceRoot'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
        throw $msg
      }

      if (-not $PSCmdlet.ShouldProcess($sourceRoot, 'Scan PowerShell source modules into SourceModule model rows')) {
        return
      }

      $repositoryPhiloteIdValue = $null
      if ($PSBoundParameters.ContainsKey('RepositoryPhiloteId')) {
        $repositoryPhiloteIdValue = $RepositoryPhiloteId
      }

      $moduleRows = [System.Collections.Generic.List[object]]::new()
      $moduleDirectories = Get-ChildItem -LiteralPath $sourceRoot -Directory -ErrorAction Stop |
        Sort-Object -Property Name

      foreach ($moduleDirectory in $moduleDirectories) {
        $manifestFiles = @(Get-ChildItem -LiteralPath $moduleDirectory.FullName -Filter '*.psd1' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)
        $manifest = $manifestFiles |
          Where-Object { $_.BaseName -eq $moduleDirectory.Name } |
          Select-Object -First 1

        if (-not $manifest) {
          $manifest = $manifestFiles | Select-Object -First 1
        }

        $publicPath = Join-Path $moduleDirectory.FullName 'public'
        $privatePath = Join-Path $moduleDirectory.FullName 'private'
        $publicFunctionFiles = @(if (Test-Path -LiteralPath $publicPath -PathType Container) { Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue })
        $privateFunctionFiles = @(if (Test-Path -LiteralPath $privatePath -PathType Container) { Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1' -File -ErrorAction SilentlyContinue })
        $csharpProjectFiles = @(Get-ChildItem -LiteralPath $moduleDirectory.FullName -Filter '*.csproj' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)

        if (-not $manifest -and $publicFunctionFiles.Count -eq 0 -and $privateFunctionFiles.Count -eq 0 -and (-not $IncludeCSharp -or $csharpProjectFiles.Count -eq 0)) {
          continue
        }

        $isCSharpProject = -not $manifest -and $publicFunctionFiles.Count -eq 0 -and $privateFunctionFiles.Count -eq 0 -and $csharpProjectFiles.Count -gt 0
        $moduleName = if ($manifest) { $manifest.BaseName } elseif ($isCSharpProject) { $csharpProjectFiles[0].BaseName } else { $moduleDirectory.Name }
        $moduleKind = if ($isCSharpProject) { 'CSharp' } else { 'PowerShell' }
        $sourceRootRelativePathValue = ConvertTo-InstantiationRelativePath -BasePath $resolvedRepositoryRoot -Path $moduleDirectory.FullName
        $sourceModulePhiloteId = New-InstantiationStableGuid -NaturalKey "$RepositoryName|SourceModule|$moduleName"
        $artifactSortOrder = 0
        $artifacts = [System.Collections.Generic.List[object]]::new()
        $artifactSortOrder += 10
        $artifacts.Add((New-InstantiationArtifact -ArtifactKind 'Directory' -RelativePath $sourceRootRelativePathValue -SourceModulePhiloteId $sourceModulePhiloteId.ToString() -SortOrder $artifactSortOrder))

        $manifestRelativePath = $null
        if ($manifest) {
          $manifestRelativePath = ConvertTo-InstantiationRelativePath -BasePath $resolvedRepositoryRoot -Path $manifest.FullName
          $artifactSortOrder += 10
          $artifacts.Add((New-InstantiationArtifact -ArtifactKind 'ModuleManifest' -RelativePath $manifestRelativePath -SourceModulePhiloteId $sourceModulePhiloteId.ToString() -SortOrder $artifactSortOrder))
        }

        $publicFunctionsRelativePath = $null
        if ($publicFunctionFiles.Count -gt 0) {
          $publicFunctionsRelativePath = ConvertTo-InstantiationRelativePath -BasePath $resolvedRepositoryRoot -Path $publicPath
          $artifactSortOrder += 10
          $artifacts.Add((New-InstantiationArtifact -ArtifactKind 'Directory' -RelativePath $publicFunctionsRelativePath -SourceModulePhiloteId $sourceModulePhiloteId.ToString() -SortOrder $artifactSortOrder))
        }

        $privateFunctionsRelativePath = $null
        if ($privateFunctionFiles.Count -gt 0) {
          $privateFunctionsRelativePath = ConvertTo-InstantiationRelativePath -BasePath $resolvedRepositoryRoot -Path $privatePath
          $artifactSortOrder += 10
          $artifacts.Add((New-InstantiationArtifact -ArtifactKind 'Directory' -RelativePath $privateFunctionsRelativePath -SourceModulePhiloteId $sourceModulePhiloteId.ToString() -SortOrder $artifactSortOrder))
        }

        $moduleRows.Add([PSCustomObject]@{
            EntityKind                    = 'SourceModule'
            RepositoryName                = $RepositoryName
            RepositoryPhiloteId           = $repositoryPhiloteIdValue
            SourceModulePhiloteId         = $sourceModulePhiloteId
            ModuleName                    = $moduleName
            ModuleKind                    = $moduleKind
            SourceRootRelativePath        = $sourceRootRelativePathValue
            ManifestRelativePath          = $manifestRelativePath
            PublicFunctionsRelativePath   = $publicFunctionsRelativePath
            PrivateFunctionsRelativePath  = $privateFunctionsRelativePath
            PublicFunctionCount           = $publicFunctionFiles.Count
            PrivateFunctionCount          = $privateFunctionFiles.Count
            IsPlanned                     = $false
            Notes                         = if ($isCSharpProject) { 'Discovered from repository C# project source.' } else { 'Discovered from repository PowerShell source.' }
            ManifestationArtifacts        = @($artifacts)
          })
      }

      $discoveredNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      foreach ($moduleRow in $moduleRows) {
        [void] $discoveredNames.Add($moduleRow.ModuleName)
      }

      foreach ($plannedModuleName in ($PlannedPowerShellModuleName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)) {
        if ($discoveredNames.Contains($plannedModuleName)) {
          continue
        }

        $sourceModulePhiloteId = New-InstantiationStableGuid -NaturalKey "$RepositoryName|SourceModule|$plannedModuleName"
        $plannedRootRelativePath = Join-Path $SourceRootRelativePath $plannedModuleName
        $moduleRows.Add([PSCustomObject]@{
            EntityKind                    = 'SourceModule'
            RepositoryName                = $RepositoryName
            RepositoryPhiloteId           = $repositoryPhiloteIdValue
            SourceModulePhiloteId         = $sourceModulePhiloteId
            ModuleName                    = $plannedModuleName
            ModuleKind                    = 'PlannedPowerShell'
            SourceRootRelativePath        = $plannedRootRelativePath
            ManifestRelativePath          = $null
            PublicFunctionsRelativePath   = $null
            PrivateFunctionsRelativePath  = $null
            PublicFunctionCount           = 0
            PrivateFunctionCount          = 0
            IsPlanned                     = $true
            Notes                         = 'Planned module supplied by caller; not discovered on disk.'
            ManifestationArtifacts        = @(
              New-InstantiationArtifact -ArtifactKind 'ModuleSource' -RelativePath $plannedRootRelativePath -SourceModulePhiloteId $sourceModulePhiloteId.ToString() -RenderPolicy 'Planned' -SortOrder 10
            )
          })
      }

      $moduleRows | Sort-Object -Property ModuleName
    } catch {
      $msg = "Failed to scan SourceModule inventory from '$RepositoryRoot': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
