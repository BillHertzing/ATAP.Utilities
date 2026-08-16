function Get-AICoreInstructionBody {
  <#
.SYNOPSIS
    Produces the shared AI core instruction body for a carrier directly from canonical.

.DESCRIPTION
    Task 14.60. Historically the per-repository combiners could only build AGENTS.md and
    CLAUDE.md by first requiring Render-AIAdapters to materialize AGENTS-base.md and
    CLAUDE-base.md at the SharedVSCode root, then reading those files back. That made two
    intermediate artifacts a hard prerequisite of every combine: if a base file was stale,
    missing, or edited by hand, the combined file silently inherited it, and the combiner
    threw rather than composing from the source of truth it already had access to.

    This function removes that dependency by generating the core body in memory from the
    canonical source named in the instruction manifest.

    It deliberately does NOT reimplement the wrapper header. It dot-sources the renderer
    and calls the renderer's own New-AIAdapterContent, so the emitted bytes are produced by
    exactly one implementation. Duplicating the header here would be a second copy of a
    format (SourceId / Source / SourceSha256 / Materialization) that must stay in lockstep
    with the drift checks, and it would drift the moment either side changed.

    Carrier shapes, both verified byte-identical to the corresponding legacy base file.
    Each comes from its manifest target's 'composedMaterialization' (Task 15.72), not from
    an assumption made here:
      AGENTS - title line, generated-wrapper header, canonical body.
      CLAUDE - canonical body verbatim ('copy', so the renderer returns the source
               unchanged).

    The legacy base file remains supported as a FALLBACK only, for a worktree that has no
    .ai tree (older sprints, fixtures, a downstream repo rendered from a pinned bundle).
    Callers get back which path was taken so they can report it.

.PARAMETER SharedVSCodeRoot
    Root of the SharedVSCode worktree holding .ai/manifests and .ai/tools.

.PARAMETER Carrier
    AGENTS or CLAUDE - which carrier's core body to produce.

.PARAMETER FallbackBaseFilePath
    Optional legacy <Carrier>-base.md. Used only when the canonical path is unavailable.

.OUTPUTS
    PSCustomObject with Content, Origin ('canonical' | 'legacy-base'), SourcePath,
    SourceSha256, and RecordId.

.EXAMPLE
    Get-AICoreInstructionBody -SharedVSCodeRoot $shared -Carrier AGENTS
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [string] $SharedVSCodeRoot,

    [Parameter(Mandatory = $true)]
    [ValidateSet('AGENTS', 'CLAUDE')]
    [string] $Carrier,

    [string] $FallbackBaseFilePath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $recordId = 'ai.core.main-instructions.v1'
    $rendererPath = Join-Path $SharedVSCodeRoot '.ai/tools/Render-AIAdapters.ps1'
    $manifestPath = Join-Path $SharedVSCodeRoot '.ai/manifests/instruction-map.json'

    $useFallback = $false
    $fallbackReason = $null
    if (-not (Test-Path -LiteralPath $rendererPath -PathType Leaf)) {
      $useFallback = $true
      $fallbackReason = "renderer not found at '$rendererPath'"
    }
    elseif (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
      $useFallback = $true
      $fallbackReason = "instruction manifest not found at '$manifestPath'"
    }

    if ($useFallback) {
      if ([string]::IsNullOrWhiteSpace($FallbackBaseFilePath) -or
        -not (Test-Path -LiteralPath $FallbackBaseFilePath -PathType Leaf)) {
        throw ("Cannot build the $Carrier core body: $fallbackReason, and no usable " +
          "legacy base file was supplied. Render the canonical sources into " +
          "'$SharedVSCodeRoot' first, or pass -FallbackBaseFilePath.")
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
        "Composing $Carrier core from the LEGACY base file because $fallbackReason. " +
        "This path is deprecated by Task 14.60; the base file is not guaranteed to match canonical.")
      $legacyHash = (Get-FileHash -LiteralPath $FallbackBaseFilePath -Algorithm SHA256).Hash.ToLowerInvariant()
      return [PSCustomObject]@{
        Content = (Get-Content -LiteralPath $FallbackBaseFilePath -Raw -ErrorAction Stop)
        Origin = 'legacy-base'
        SourcePath = $FallbackBaseFilePath
        SourceSha256 = $legacyHash
        RecordId = $recordId
      }
    }

    # Dot-source into THIS function's scope: the renderer's helpers stay local to the call
    # and do not leak into the caller's session.
    . $rendererPath

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop |
      ConvertFrom-Json -Depth 100
    $record = @($manifest.records | Where-Object { $_.id -eq $recordId })
    if ($record.Count -ne 1) {
      throw "Expected exactly one '$recordId' record in '$manifestPath'; found $($record.Count)."
    }
    $record = $record[0]

    $canonicalRelative = [string]$record.source.path
    $canonicalFullPath = Join-Path $SharedVSCodeRoot $canonicalRelative
    if (-not (Test-Path -LiteralPath $canonicalFullPath -PathType Leaf)) {
      throw "Canonical core instructions '$canonicalRelative' not found at '$canonicalFullPath'."
    }

    # Match the carrier to its manifest target so the body shape comes from the manifest
    # rather than being assumed here.
    #
    # Task 15.72: the lookup key is the carrier file itself ('CLAUDE.md' / 'AGENTS.md').
    # Task 14.60 stopped READING <Carrier>-base.md but still looked its manifest target up
    # BY NAME to fetch a materialization, which kept two retired filenames load-bearing:
    # deleting the targets threw here and broke both combiners, so the manifest could not
    # be cleaned up without breaking composition.
    #
    # The targets are now 'composer-owner' -- the value that tells Render-AIAdapters this
    # combiner owns the write. That displaced the 'copy' / 'generated-wrapper' value that
    # used to carry the BODY SHAPE, so the shape moved to its own field rather than being
    # hard-coded per carrier here. Hard-coding it would put a second copy of the
    # provenance-header format in this module, which is the duplication this function
    # avoids by dot-sourcing the renderer's own New-AIAdapterContent.
    $targetCarrierName = "$Carrier.md"
    $manifestTarget = @($record.targets | Where-Object { [string]$_.path -eq $targetCarrierName })
    if ($manifestTarget.Count -ne 1) {
      throw ("Expected exactly one '$targetCarrierName' target on '$recordId'; found " +
        "$($manifestTarget.Count). The $Carrier carrier cannot be composed from canonical.")
    }

    $composedProperty = $manifestTarget[0].PSObject.Properties['composedMaterialization']
    if (-not $composedProperty -or [string]::IsNullOrWhiteSpace([string]$composedProperty.Value)) {
      throw ("Target '$targetCarrierName' on '$recordId' declares no 'composedMaterialization'. " +
        "A composer-owned carrier must state the body shape it expects ('copy' or " +
        "'generated-wrapper'); without it the emitted bytes would be a guess.")
    }
    $materialization = [string]$composedProperty.Value

    $sourceContent = Get-Content -LiteralPath $canonicalFullPath -Raw -ErrorAction Stop
    $sourceHash = Get-AIAdapterFileHash -Path $canonicalFullPath -NormalizeNewlines

    $syntheticTarget = [PSCustomObject]@{
      tool = [string]$manifestTarget[0].tool
      path = "$Carrier.md"
      materialization = $materialization
    }

    $content = New-AIAdapterContent `
      -Record $record `
      -Target $syntheticTarget `
      -SourceContent $sourceContent `
      -SourceFullPath $canonicalFullPath `
      -TargetFullPath (Join-Path $SharedVSCodeRoot "$Carrier.md") `
      -SourceHash $sourceHash

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message (
      "Composed $Carrier core body from canonical '$canonicalRelative' " +
      "(materialization=$materialization, sha256=$($sourceHash.sha256)).")

    [PSCustomObject]@{
      Content = $content
      Origin = 'canonical'
      SourcePath = $canonicalFullPath
      SourceSha256 = $sourceHash.sha256
      RecordId = $recordId
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
