#Requires -Version 7.0
function Export-InstantiationManifestation {
  <#
.SYNOPSIS
    Renders an instantiation source-module model into manifestation evidence files.

.DESCRIPTION
    Consumes SourceModule-shaped rows, such as rows returned by
    Get-InstantiationSourceModuleInventory, and writes deterministic
    manifestation artifacts: model JSON, source-file locations, folder tree,
    and a markdown report. Output defaults under _generated/Instantiation so
    generated evidence stays inside the repository-approved folder.

.PARAMETER SourceModule
    SourceModule-shaped rows to render.

.PARAMETER RepositoryRoot
    Repository root used to resolve relative source paths.

.PARAMETER OutputDirectory
    Output directory for manifestation evidence files. Defaults to
    <RepositoryRoot>/_generated/Instantiation.

.PARAMETER VersionLabel
    Instantiation version label used in output file names and report content.

.PARAMETER InstantiationName
    Human-readable instantiation name.

.PARAMETER OrganizationCode
    Organization code rendered into the report.

.PARAMETER UserKey
    Non-PII user key rendered into the report.

.PARAMETER ComputerName
    Computer names rendered into the report.

.PARAMETER RepositoryName
    Repository name rendered into the report.

.OUTPUTS
    PSCustomObject summary with paths to rendered artifacts and verification counts.

.EXAMPLE
    $rows = Get-InstantiationSourceModuleInventory -RepositoryRoot $repo -IncludeCSharp
    Export-InstantiationManifestation -RepositoryRoot $repo -SourceModule $rows -VersionLabel 'v1-current-repository-state'
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNull()]
    [object[]]$SourceModule,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot = (Get-Location).Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$VersionLabel = 'v1-current-repository-state',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$InstantiationName = 'ATAP Utilities Sprint 0012',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OrganizationCode = 'ATAP',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UserKey = 'primary-developer',

    [Parameter()]
    [ValidateNotNull()]
    [string[]]$ComputerName = @('utat022', 'UTAT01'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryName = 'ATAP.Utilities'
  )

  begin {
    $fn = 'Export-InstantiationManifestation'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'

    $allSourceModules = [System.Collections.Generic.List[object]]::new()

    function ConvertTo-InstantiationSlug {
      param(
        [Parameter(Mandatory = $true)]
        [string]$Value
      )

      $slug = ($Value -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
      if ([string]::IsNullOrWhiteSpace($slug)) {
        return 'manifestation'
      }

      return $slug
    }

    function ConvertTo-InstantiationRelativePath {
      param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$Path
      )

      return [System.IO.Path]::GetRelativePath($BasePath, $Path)
    }

    function Test-InstantiationPathExactCase {
      param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
      )

      if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return $false
      }

      $currentItem = Get-Item -LiteralPath $BasePath -ErrorAction SilentlyContinue
      if (-not $currentItem) {
        return $false
      }

      $segments = $RelativePath -split '[\\/]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
      foreach ($segment in $segments) {
        $nextItem = Get-ChildItem -LiteralPath $currentItem.FullName -Force -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -ceq $segment } |
          Select-Object -First 1

        if (-not $nextItem) {
          return $false
        }

        $currentItem = $nextItem
      }

      return $true
    }

    function Get-InstantiationSourceFiles {
      param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRootPath,

        [Parameter(Mandatory = $true)]
        [object]$ModuleRow
      )

      $moduleRoot = Join-Path $RepositoryRootPath $ModuleRow.SourceRootRelativePath
      if (-not (Test-InstantiationPathExactCase -BasePath $RepositoryRootPath -RelativePath $ModuleRow.SourceRootRelativePath)) {
        return @()
      }

      $extensions = @('.ps1', '.psm1', '.psd1')
      if ($ModuleRow.ModuleKind -eq 'CSharp') {
        $extensions = @('.cs', '.csproj')
      }

      @(Get-ChildItem -LiteralPath $moduleRoot -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $extensions -contains $_.Extension } |
          Sort-Object -Property FullName |
          ForEach-Object {
            [PSCustomObject]@{
              ModuleName      = $ModuleRow.ModuleName
              ModuleKind      = $ModuleRow.ModuleKind
              RelativePath    = ConvertTo-InstantiationRelativePath -BasePath $RepositoryRootPath -Path $_.FullName
              Length          = $_.Length
              LastWriteTimeUtc = $_.LastWriteTimeUtc.ToString('o')
            }
          })
    }
  }

  process {
    foreach ($moduleRow in $SourceModule) {
      $allSourceModules.Add($moduleRow)
    }
  }

  end {
    try {
      $repositoryRootItem = Get-Item -LiteralPath $RepositoryRoot -ErrorAction Stop
      $resolvedRepositoryRoot = $repositoryRootItem.FullName
      if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path $resolvedRepositoryRoot '_generated\Instantiation'
      }

      if (-not $PSCmdlet.ShouldProcess($OutputDirectory, "Render instantiation manifestation '$VersionLabel'")) {
        return
      }

      New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

      $slug = ConvertTo-InstantiationSlug -Value $VersionLabel
      $modelPath = Join-Path $OutputDirectory "$slug.source-modules.json"
      $sourceFilesPath = Join-Path $OutputDirectory "$slug.source-files.json"
      $folderTreePath = Join-Path $OutputDirectory "$slug.folder-tree.txt"
      $reportPath = Join-Path $OutputDirectory "$slug.report.md"
      $summaryPath = Join-Path $OutputDirectory "$slug.summary.json"

      $sourceModules = @($allSourceModules | Sort-Object -Property ModuleName)
      $fileLocations = [System.Collections.Generic.List[object]]::new()
      $sourceFiles = [System.Collections.Generic.List[object]]::new()
      $folderPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      $missingExpectedPaths = [System.Collections.Generic.List[object]]::new()

      foreach ($moduleRow in $sourceModules) {
        $pathsToCheck = @(
          @{ Kind = 'SourceRoot'; Path = $moduleRow.SourceRootRelativePath },
          @{ Kind = 'Manifest'; Path = $moduleRow.ManifestRelativePath },
          @{ Kind = 'PublicFunctions'; Path = $moduleRow.PublicFunctionsRelativePath },
          @{ Kind = 'PrivateFunctions'; Path = $moduleRow.PrivateFunctionsRelativePath }
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Path) }

        foreach ($pathToCheck in $pathsToCheck) {
          $absolutePath = Join-Path $resolvedRepositoryRoot $pathToCheck.Path
          $exists = Test-InstantiationPathExactCase -BasePath $resolvedRepositoryRoot -RelativePath $pathToCheck.Path
          $fileLocations.Add([PSCustomObject]@{
              ModuleName   = $moduleRow.ModuleName
              ModuleKind   = $moduleRow.ModuleKind
              LocationKind = $pathToCheck.Kind
              RelativePath = $pathToCheck.Path
              Exists       = $exists
              IsPlanned    = [bool]$moduleRow.IsPlanned
            })

          if ($pathToCheck.Kind -ne 'Manifest') {
            [void] $folderPaths.Add($pathToCheck.Path)
          }

          if (-not $exists -and -not [bool]$moduleRow.IsPlanned) {
            $missingExpectedPaths.Add([PSCustomObject]@{
                ModuleName   = $moduleRow.ModuleName
                LocationKind = $pathToCheck.Kind
                RelativePath = $pathToCheck.Path
              })
          }
        }

        foreach ($artifact in @($moduleRow.ManifestationArtifacts)) {
          if ($artifact.ArtifactKind -eq 'Directory' -or $artifact.ArtifactKind -eq 'ModuleSource') {
            [void] $folderPaths.Add($artifact.RelativePath)
          }
        }

        foreach ($sourceFile in @(Get-InstantiationSourceFiles -RepositoryRootPath $resolvedRepositoryRoot -ModuleRow $moduleRow)) {
          $sourceFiles.Add($sourceFile)
        }
      }

      $folderTree = @($folderPaths | Sort-Object | ForEach-Object { $_ })
      $renderedModel = [PSCustomObject]@{
        InstantiationName = $InstantiationName
        VersionLabel      = $VersionLabel
        OrganizationCode  = $OrganizationCode
        UserKey           = $UserKey
        ComputerName      = @($ComputerName)
        RepositoryName    = $RepositoryName
        SourceModules     = @($sourceModules)
        FileLocations     = @($fileLocations)
        FolderTree        = @($folderTree)
      }

      $summary = [PSCustomObject]@{
        InstantiationName      = $InstantiationName
        VersionLabel           = $VersionLabel
        OrganizationCode       = $OrganizationCode
        UserKey                = $UserKey
        ComputerName           = @($ComputerName)
        RepositoryName         = $RepositoryName
        SourceModuleCount      = $sourceModules.Count
        SourceFileCount        = $sourceFiles.Count
        FolderPathCount        = $folderTree.Count
        MissingExpectedCount   = $missingExpectedPaths.Count
        MissingExpectedPaths   = @($missingExpectedPaths)
        SourceModulesPath      = $modelPath
        SourceFilesPath        = $sourceFilesPath
        FolderTreePath         = $folderTreePath
        ReportPath             = $reportPath
        SummaryPath            = $summaryPath
      }

      $renderedModel | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $modelPath -Encoding utf8
      @($sourceFiles) | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceFilesPath -Encoding utf8
      $folderTree | Set-Content -LiteralPath $folderTreePath -Encoding utf8

      $reportLines = [System.Collections.Generic.List[string]]::new()
      $reportLines.Add("# $InstantiationName - $VersionLabel")
      $reportLines.Add('')
      $reportLines.Add(('- Organization: ``{0}``' -f $OrganizationCode))
      $reportLines.Add(('- User: ``{0}``' -f $UserKey))
      $reportLines.Add(('- Computers: ``{0}``' -f ($ComputerName -join '`, `')))
      $reportLines.Add(('- Repository: ``{0}``' -f $RepositoryName))
      $reportLines.Add("- Source modules: $($sourceModules.Count)")
      $reportLines.Add("- Source files: $($sourceFiles.Count)")
      $reportLines.Add("- Folder paths: $($folderTree.Count)")
      $reportLines.Add("- Missing expected paths: $($missingExpectedPaths.Count)")
      $reportLines.Add('')
      $reportLines.Add('## Source Modules')
      $reportLines.Add('')
      foreach ($moduleRow in $sourceModules) {
        $plannedLabel = if ([bool]$moduleRow.IsPlanned) { ' planned' } else { '' }
        $reportLines.Add(('- ``{0}`` ({1}{2}) -> ``{3}``' -f $moduleRow.ModuleName, $moduleRow.ModuleKind, $plannedLabel, $moduleRow.SourceRootRelativePath))
      }
      $reportLines.Add('')
      $reportLines.Add('## Folder Tree')
      $reportLines.Add('')
      foreach ($folderPath in $folderTree) {
        $reportLines.Add(('- ``{0}``' -f $folderPath))
      }
      $reportLines.Add('')
      $reportLines.Add('## Source Files')
      $reportLines.Add('')
      foreach ($sourceFile in @($sourceFiles | Sort-Object -Property RelativePath)) {
        $reportLines.Add(('- ``{0}``' -f $sourceFile.RelativePath))
      }
      if ($missingExpectedPaths.Count -gt 0) {
        $reportLines.Add('')
        $reportLines.Add('## Missing Expected Paths')
        $reportLines.Add('')
        foreach ($missing in $missingExpectedPaths) {
          $reportLines.Add(('- ``{0}`` {1}: ``{2}``' -f $missing.ModuleName, $missing.LocationKind, $missing.RelativePath))
        }
      }

      $reportLines | Set-Content -LiteralPath $reportPath -Encoding utf8
      $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8

      $summary
    } catch {
      $msg = "Failed to render instantiation manifestation '$VersionLabel': $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
    }
  }
}
