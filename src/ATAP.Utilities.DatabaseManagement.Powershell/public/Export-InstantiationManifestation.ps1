#Requires -Version 7.0
function Export-InstantiationManifestation {
  <#
.SYNOPSIS
    Inspects or renders a corrected immutable InstantiationVersion graph.

.DESCRIPTION
    The CorrectedGraph parameter set traverses planned ManifestationArtifact rows,
    resolves their producing RuleInstantiationVersion, reconstructs exact bytes from
    ordered source lines, enforces descendant-only path safety, and optionally persists
    effective-dated RenderFromModel provenance. The LegacyInventory parameter set keeps
    the earlier SourceModule evidence export available for compatibility.
#>
  [CmdletBinding(DefaultParameterSetName = 'LegacyInventory', SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'LegacyInventory', ValueFromPipeline = $true)]
    [object[]]$SourceModule,

    [Parameter(Mandatory = $true, ParameterSetName = 'CorrectedGraph')]
    [ValidateNotNull()]
    [object]$InstantiationGraph,

    [Parameter(ParameterSetName = 'LegacyInventory')]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot = (Get-Location).Path,

    [Parameter(ParameterSetName = 'LegacyInventory')]
    [string]$OutputDirectory,

    [Parameter(ParameterSetName = 'LegacyInventory')]
    [string]$VersionLabel = 'v1-current-repository-state',

    [Parameter(ParameterSetName = 'LegacyInventory')]
    [string]$InstantiationName = 'ATAP Utilities',

    [Parameter(ParameterSetName = 'CorrectedGraph')]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRoot = 'C:\Dropbox\ATAP.org\_generated',

    [Parameter(ParameterSetName = 'CorrectedGraph')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'CorrectedGraph')]
    [switch]$PersistProvenance,

    [Parameter(ParameterSetName = 'CorrectedGraph')]
    [object]$SqlConnection,

    [Parameter(ParameterSetName = 'CorrectedGraph')]
    [scriptblock]$ProvenanceWriter
  )

  begin {
    $fn = 'Export-InstantiationManifestation'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    $legacyRows = [System.Collections.Generic.List[object]]::new()

    function Get-ExactBytes {
      param([Parameter(Mandatory = $true)][object]$RuleInstantiation)

      $bindingMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
      foreach ($binding in @($RuleInstantiation.Bindings)) {
        if ($bindingMap.ContainsKey([string]$binding.InputName)) {
          throw "Duplicate resolved binding '$($binding.InputName)' in RuleInstantiationVersion '$($RuleInstantiation.RuleInstantiationVersionPhiloteId)'."
        }
        $bindingMap[[string]$binding.InputName] = [string]$binding.InputValue
      }
      $encodingName = if ($bindingMap.ContainsKey('Encoding')) { $bindingMap['Encoding'] } else { 'utf8' }
      if ($encodingName -notin @('utf8', 'utf-8')) {
        throw "Unsupported exact-byte encoding '$encodingName'."
      }
      $bom = if ($bindingMap.ContainsKey('Bom')) { $bindingMap['Bom'] } else { 'none' }
      if ($bom -notin @('none', 'utf8')) {
        throw "Unsupported BOM policy '$bom'."
      }

      $builder = [System.Text.StringBuilder]::new()
      $lines = @($RuleInstantiation.SourceLines | Sort-Object { [int]$_.Ordinal })
      for ($index = 0; $index -lt $lines.Count; $index++) {
        if ([int]$lines[$index].Ordinal -ne ($index + 1)) {
          throw "Source-line ordinals are non-contiguous or duplicated for RuleInstantiationVersion '$($RuleInstantiation.RuleInstantiationVersionPhiloteId)'."
        }
        [void]$builder.Append([string]$lines[$index].LineText)
        switch ([string]$lines[$index].LineEnding) {
          'CRLF' { [void]$builder.Append("`r`n") }
          'LF' { [void]$builder.Append("`n") }
          'None' { }
          default { throw "Invalid line ending '$($lines[$index].LineEnding)' at ordinal $($lines[$index].Ordinal)." }
        }
      }

      if ($bindingMap.ContainsKey('FinalNewline')) {
        $hasFinalNewline = $lines.Count -gt 0 -and [string]$lines[-1].LineEnding -ne 'None'
        $expectedFinalNewline = [System.Convert]::ToBoolean($bindingMap['FinalNewline'])
        if ($hasFinalNewline -ne $expectedFinalNewline) {
          throw "FinalNewline binding does not match the last stored source-line terminator."
        }
      }

      $payload = [System.Text.UTF8Encoding]::new($false).GetBytes($builder.ToString())
      if ($bom -eq 'utf8') {
        $prefix = [System.Text.UTF8Encoding]::new($true).GetPreamble()
        $combined = [byte[]]::new($prefix.Length + $payload.Length)
        [Array]::Copy($prefix, 0, $combined, 0, $prefix.Length)
        [Array]::Copy($payload, 0, $combined, $prefix.Length, $payload.Length)
        return $combined
      }
      return $payload
    }

    function Get-ByteSha256 {
      param([Parameter(Mandatory = $true)][byte[]]$Bytes)
      return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes))
    }

    function Resolve-SafeArtifactPath {
      param(
        [Parameter(Mandatory = $true)][string]$CanonicalRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
      )

      if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Manifestation artifact path is blank.'
      }
      if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[A-Za-z]:' -or $RelativePath.Contains(':')) {
        throw "Manifestation artifact path '$RelativePath' is absolute or changes drive."
      }
      $segments = @($RelativePath -split '[\\/]+')
      if ($segments -contains '..') {
        throw "Manifestation artifact path '$RelativePath' contains parent traversal."
      }
      if ($segments -contains '.') {
        throw "Manifestation artifact path '$RelativePath' contains a non-canonical current-directory segment."
      }

      $fullPath = [System.IO.Path]::GetFullPath((Join-Path $CanonicalRoot $RelativePath))
      $rootPrefix = $CanonicalRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
      if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifestation artifact path '$RelativePath' escapes target root '$CanonicalRoot'."
      }
      return $fullPath
    }

    function Write-ArtifactProvenance {
      param(
        [Parameter(Mandatory = $true)][object]$Artifact,
        [Parameter(Mandatory = $true)][string]$ContentSha256
      )

      $record = [PSCustomObject]@{
        InstantiationVersionPhiloteId = [guid]$InstantiationGraph.InstantiationVersionPhiloteId
        ArtifactKind = [string]$Artifact.ArtifactKind
        RelativePath = [string]$Artifact.RelativePath
        ContentSha256 = $ContentSha256
        BuildSetVersionPhiloteId = [guid]$Artifact.BuildSetVersionPhiloteId
        ProducingRuleInstantiationPhiloteId = [guid]$Artifact.ProducingRuleInstantiationPhiloteId
        ProducingRuleInstantiationVersionPhiloteId = [guid]$Artifact.ProducingRuleInstantiationVersionPhiloteId
      }
      if ($null -ne $ProvenanceWriter) {
        return & $ProvenanceWriter $record
      }
      if ($null -eq $SqlConnection) {
        throw 'PersistProvenance requires SqlConnection or ProvenanceWriter.'
      }

      $sql = @'
/* Task13.80:PersistProvenance */
SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
  DECLARE @Now DATETIME2(7) = SYSUTCDATETIME();
  DECLARE @ArtifactId UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER,
    HASHBYTES('MD5', CONCAT(CONVERT(NVARCHAR(36), @InstantiationVersionPhiloteId), N'|', @RelativePath)));

  IF EXISTS (
    SELECT 1 FROM ATAPUtilities.ManifestationArtifact
    WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
      AND RelativePath = @RelativePath
      AND RenderPolicy = N'RenderFromModel'
      AND ISNULL(ContentSha256, N'') = ISNULL(@ContentSha256, N'')
      AND ProducingRuleInstantiationVersionPhiloteId = @ProducingRuleInstantiationVersionPhiloteId
      AND EffectiveTo IS NULL
  )
  BEGIN
    COMMIT;
    SELECT CAST(0 AS BIT) AS Created;
    RETURN;
  END;

  -- V00.02.000060's UQ_ManifestationArtifact_Path still covers all history,
  -- so V00.02.000100's filtered current-path index cannot support a close +
  -- successor insert. Promote the one planned row in place; exact repeats
  -- return above without another write.
  UPDATE ATAPUtilities.ManifestationArtifact
  SET ArtifactKind = @ArtifactKind,
      SourceObjectKind = N'RuleInstantiationVersion',
      SourceObjectPhiloteId = @ProducingRuleInstantiationVersionPhiloteId,
      ContentSha256 = @ContentSha256,
      RenderPolicy = N'RenderFromModel',
      SortOrder = @SortOrder,
      Notes = N'Observed exact-byte manifestation persisted by Task 13.80 renderer.',
      BuildSetVersionPhiloteId = @BuildSetVersionPhiloteId,
      ProducingRuleInstantiationPhiloteId = @ProducingRuleInstantiationPhiloteId,
      ProducingRuleInstantiationVersionPhiloteId = @ProducingRuleInstantiationVersionPhiloteId
  WHERE InstantiationVersionPhiloteId = @InstantiationVersionPhiloteId
    AND RelativePath = @RelativePath
    AND EffectiveTo IS NULL;

  IF @@ROWCOUNT = 0
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM ATAPUtilities.Philote WHERE PhiloteId = @ArtifactId)
      INSERT INTO ATAPUtilities.Philote (PhiloteId, EffectiveFrom) VALUES (@ArtifactId, @Now);
    INSERT INTO ATAPUtilities.ManifestationArtifact
      (ManifestationArtifactPhiloteId, InstantiationVersionPhiloteId, ArtifactKind,
       RelativePath, SourceObjectKind, SourceObjectPhiloteId, ContentSha256,
       RenderPolicy, SortOrder, Notes, BuildSetVersionPhiloteId,
       ProducingRuleInstantiationPhiloteId, ProducingRuleInstantiationVersionPhiloteId,
       EffectiveFrom)
    VALUES
      (@ArtifactId, @InstantiationVersionPhiloteId, @ArtifactKind, @RelativePath,
       N'RuleInstantiationVersion', @ProducingRuleInstantiationVersionPhiloteId,
       @ContentSha256, N'RenderFromModel', @SortOrder,
       N'Observed exact-byte manifestation persisted by Task 13.80 renderer.',
       @BuildSetVersionPhiloteId, @ProducingRuleInstantiationPhiloteId,
       @ProducingRuleInstantiationVersionPhiloteId, @Now);
  END;
  COMMIT;
  SELECT CAST(1 AS BIT) AS Created;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;
  THROW;
END CATCH;
'@
      $result = @(Invoke-DatabaseSqlQuery -SqlConnection $SqlConnection -CommandText $sql -Parameters @{
          InstantiationVersionPhiloteId = $record.InstantiationVersionPhiloteId
          ArtifactKind = $record.ArtifactKind
          RelativePath = $record.RelativePath
          ContentSha256 = $record.ContentSha256
          SortOrder = [int]$Artifact.SortOrder
          BuildSetVersionPhiloteId = $record.BuildSetVersionPhiloteId
          ProducingRuleInstantiationPhiloteId = $record.ProducingRuleInstantiationPhiloteId
          ProducingRuleInstantiationVersionPhiloteId = $record.ProducingRuleInstantiationVersionPhiloteId
        })
      return $result | Select-Object -First 1
    }
  }

  process {
    if ($PSCmdlet.ParameterSetName -eq 'LegacyInventory') {
      foreach ($row in $SourceModule) { $legacyRows.Add($row) }
    }
  }

  end {
    try {
      if ($PSCmdlet.ParameterSetName -eq 'LegacyInventory') {
        $root = (Get-Item -LiteralPath $RepositoryRoot -ErrorAction Stop).FullName
        if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
          $OutputDirectory = Join-Path $root '_generated\Instantiation'
        }
        if (-not $PSCmdlet.ShouldProcess($OutputDirectory, "Render legacy inventory '$VersionLabel'")) { return }
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        $slug = (($VersionLabel -replace '[^A-Za-z0-9._-]+', '-').Trim('-'))
        if ([string]::IsNullOrWhiteSpace($slug)) { $slug = 'manifestation' }
        $modelPath = Join-Path $OutputDirectory "$slug.source-modules.json"
        $sourceFilesPath = Join-Path $OutputDirectory "$slug.source-files.json"
        $folderTreePath = Join-Path $OutputDirectory "$slug.folder-tree.txt"
        $reportPath = Join-Path $OutputDirectory "$slug.report.md"
        $summaryPath = Join-Path $OutputDirectory "$slug.summary.json"
        $orderedRows = @($legacyRows | Sort-Object ModuleName)
        $sourceFiles = @($orderedRows | Where-Object { -not $_.IsPlanned } | ForEach-Object {
            $module = $_
            $path = Join-Path $root $module.SourceRootRelativePath
            if (Test-Path -LiteralPath $path) {
              Get-ChildItem -LiteralPath $path -File -Recurse | Sort-Object FullName | ForEach-Object {
                [PSCustomObject]@{ ModuleName = $module.ModuleName; RelativePath = [IO.Path]::GetRelativePath($root, $_.FullName); Length = $_.Length }
              }
            }
          })
        $folderTree = @($orderedRows | ForEach-Object { $_.ManifestationArtifacts } |
            Where-Object ArtifactKind -in @('Directory', 'ModuleSource') |
            Select-Object -ExpandProperty RelativePath -Unique | Sort-Object)
        $orderedRows | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $modelPath -Encoding utf8
        $sourceFiles | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sourceFilesPath -Encoding utf8
        $folderTree | Set-Content -LiteralPath $folderTreePath -Encoding utf8
        @("# $InstantiationName - $VersionLabel", '', '## Source Modules', '') +
          @($orderedRows | ForEach-Object { "- ``$($_.ModuleName)`` ($($_.ModuleKind)$(if ($_.IsPlanned) { ' planned' }))" }) |
          Set-Content -LiteralPath $reportPath -Encoding utf8
        $summary = [PSCustomObject]@{
          SourceModuleCount = $orderedRows.Count
          SourceFileCount = $sourceFiles.Count
          MissingExpectedCount = 0
          SourceModulesPath = $modelPath
          SourceFilesPath = $sourceFilesPath
          FolderTreePath = $folderTreePath
          ReportPath = $reportPath
          SummaryPath = $summaryPath
        }
        $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8
        return $summary
      }

      $canonicalRoot = [System.IO.Path]::GetFullPath($TargetRoot).TrimEnd('\', '/')
      $artifacts = @($InstantiationGraph.ManifestationArtifacts | Sort-Object { [int]$_.SortOrder }, RelativePath)
      if ($artifacts.Count -eq 0) { throw 'InstantiationGraph contains no ManifestationArtifacts.' }

      $exactPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
      $foldedPaths = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      $plan = [System.Collections.Generic.List[object]]::new()
      foreach ($artifact in $artifacts) {
        $relativePath = [string]$artifact.RelativePath
        if (-not $exactPaths.Add($relativePath)) {
          throw "Duplicate manifestation output '$relativePath'."
        }
        if ($foldedPaths.ContainsKey($relativePath) -and $foldedPaths[$relativePath] -cne $relativePath) {
          throw "Case-colliding manifestation outputs '$($foldedPaths[$relativePath])' and '$relativePath'."
        }
        $foldedPaths[$relativePath] = $relativePath
        $fullPath = Resolve-SafeArtifactPath -CanonicalRoot $canonicalRoot -RelativePath $relativePath
        $isDirectory = [string]$artifact.ArtifactKind -eq 'Directory'
        $bytes = $null
        $actualHash = $null
        if (-not $isDirectory) {
          $producerId = ([guid]$artifact.ProducingRuleInstantiationVersionPhiloteId).ToString()
          $producer = @($InstantiationGraph.RuleInstantiations | Where-Object {
              ([guid]$_.RuleInstantiationVersionPhiloteId).ToString() -eq $producerId
            })
          if ($producer.Count -ne 1) {
            throw "Artifact '$relativePath' does not resolve to exactly one producing RuleInstantiationVersion '$producerId'."
          }
          $bytes = Get-ExactBytes -RuleInstantiation $producer[0]
          $actualHash = Get-ByteSha256 -Bytes $bytes
          if (-not [string]::IsNullOrWhiteSpace([string]$artifact.ContentSha256) -and
              $actualHash -cne ([string]$artifact.ContentSha256).ToUpperInvariant()) {
            throw "Exact-byte SHA-256 mismatch for '$relativePath': expected '$($artifact.ContentSha256)', actual '$actualHash'."
          }
        }
        $plan.Add([PSCustomObject]@{
            Artifact = $artifact
            ArtifactKind = [string]$artifact.ArtifactKind
            RelativePath = $relativePath
            FullPath = $fullPath
            ContentSha256 = $actualHash
            ByteCount = if ($null -eq $bytes) { 0 } else { $bytes.Length }
            Bytes = $bytes
            Action = if ($isDirectory) { 'EnsureDirectory' } else { 'WriteExactBytes' }
          })
      }

      if ($DryRun) {
        return [PSCustomObject]@{
          InstantiationVersionPhiloteId = [guid]$InstantiationGraph.InstantiationVersionPhiloteId
          TargetRoot = $canonicalRoot
          DryRun = $true
          WroteFileSystem = $false
          Artifacts = @($plan | Select-Object ArtifactKind, RelativePath, FullPath, ContentSha256, ByteCount, Action)
        }
      }

      if (-not $PSCmdlet.ShouldProcess($canonicalRoot, "Render InstantiationVersion '$($InstantiationGraph.InstantiationVersionPhiloteId)'")) {
        return
      }
      foreach ($item in $plan) {
        if ($item.ArtifactKind -eq 'Directory') {
          New-Item -ItemType Directory -Path $item.FullPath -Force | Out-Null
          continue
        }
        $parent = Split-Path -Parent $item.FullPath
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $unchanged = $false
        if (Test-Path -LiteralPath $item.FullPath -PathType Leaf) {
          $existingBytes = [System.IO.File]::ReadAllBytes($item.FullPath)
          $unchanged = (Get-ByteSha256 -Bytes $existingBytes) -ceq $item.ContentSha256
        }
        if (-not $unchanged) {
          [System.IO.File]::WriteAllBytes($item.FullPath, $item.Bytes)
        }
        $item.Action = if ($unchanged) { 'Unchanged' } else { 'Written' }
        if ($PersistProvenance) {
          $item | Add-Member -NotePropertyName ProvenanceResult -NotePropertyValue (Write-ArtifactProvenance -Artifact $item.Artifact -ContentSha256 $item.ContentSha256)
        }
      }

      [PSCustomObject]@{
        InstantiationVersionPhiloteId = [guid]$InstantiationGraph.InstantiationVersionPhiloteId
        TargetRoot = $canonicalRoot
        DryRun = $false
        WroteFileSystem = $true
        Artifacts = @($plan | Select-Object ArtifactKind, RelativePath, FullPath, ContentSha256, ByteCount, Action, ProvenanceResult)
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message -Tag 'Error'
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
    }
  }
}
