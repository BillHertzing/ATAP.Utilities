function Invoke-CoordQuartetCandidateRender {
  # Fixed installed consumer only; not a caller-supplied renderer callback.
  [CmdletBinding(SupportsShouldProcess = $true)]
  param([Parameter(Mandatory)][string]$TasksFilePath, [Parameter(Mandatory)][string]$OutputPath)
  begin {
    $fn = 'Invoke-CoordQuartetCandidateRender'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  }
  process {
    Import-Module -FullyQualifiedName @{
      ModuleName = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'; RequiredVersion = '0.1.61'
    } -ErrorAction Stop
    $commands = @(Get-Command -Name Convert-TasksMdToSprintBoard -FullyQualifiedModule @{
      ModuleName = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'; RequiredVersion = '0.1.61'
    } -ErrorAction Stop)
    if ($commands.Count -ne 1 -or $commands[0] -isnot [Management.Automation.FunctionInfo] -or
        $null -eq $commands[0].Module -or
        $commands[0].Module.Name -cne 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -or
        $commands[0].Module.Version -ne [version]'0.1.61') { throw 'RendererUnavailable' }
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Render staged candidate using installed SprintLifecycle0.1.61')) {
      & $commands[0] -TasksFilePath $TasksFilePath -OutputPath $OutputPath -Confirm:$false -ErrorAction Stop
    }
  }
  end {}
}

function New-CoordQuartetCandidate {
  <#
  .SYNOPSIS
    Constructs scratch-only quartet images from an accepted board preview.
  .DESCRIPTION
    Private candidate seam, not preparation or publication. Caller supplies the
    accepted New-CoordBoardChange object and existing stateQuartetImages JSON.
    Shape/hash checks do not prove preview provenance, current head or authority.
    No live file contents are read or written. Exact live paths and ancestors
    receive metadata checks only; links/unknown metadata refuse. This is not
    hostile-race protection, continuous custody or admission.
    ScratchRoot is an explicit fresh canonical descendant of D:/ATAPArtifacts.
    Existing finite Invoke-CoordOperationFileIo Stage/ReadBack operations write
    exact candidate Markdown/prior board scratch bytes and capture output. Installed SprintLifecycle0.1.61
    renders once; no replacement callback, retry or cleanup is provided.
    LF-only UTF8 without BOM is required for Markdown and rendered HTML; final
    newline presence is preserved, including the renderer's NoNewline output.
    Companion bytes are opaque and preserved exactly. WhatIf/unchanged paths
    perform no metadata/content/staging or renderer operations.
  .PARAMETER Preview
    Exact eleven-field ProposedNotPrepared object from New-CoordBoardChange.
  .PARAMETER BeforeImages
    Existing closed stateQuartetImages JsonElement, with canonical base64/SHA256.
  .PARAMETER ScratchRoot
    Fresh fully qualified D-only artifact directory, never overlapping live paths.
  .OUTPUTS
    Local CandidateNotPrepared Stage/Action, cloned BeforeOutputs and resulting
    AfterOutputs stateQuartetImages, plus ScratchRoot. WhatIf has null AfterOutputs.
    No operation ID, revision/head, Prepared/Applied or custody claim is returned.
  .NOTES
    Stage evidence remains on failure. Caller objects are never modified.
  .EXAMPLE
    New-CoordQuartetCandidate -Preview $preview -BeforeImages $images -ScratchRoot $freshPath -WhatIf
  .LINK
    New-CoordBoardChange.ps1
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Preview,
    [Parameter(Mandatory)][System.Text.Json.JsonElement]$BeforeImages,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScratchRoot
  )
  begin {
    $fn = 'New-CoordQuartetCandidate'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $slots = @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')
    if (-not (Get-Command Assert-CoordOrdinaryPath -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'CoordProducer.ps1')
    }
    function sameText([string]$Left, [string]$Right) {
      [string]::Equals($Left, $Right, [StringComparison]::Ordinal)
    }
    function sha([byte[]]$Bytes) {
      [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    }
    function closedObject([System.Text.Json.JsonElement]$Value, [string[]]$Names) {
      if ($Value.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'InvalidImages' }
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($property in $Value.EnumerateObject()) {
        if (-not $seen.Add($property.Name)) { throw 'InvalidImages' }
      }
      if ($seen.Count -ne $Names.Count) { throw 'InvalidImages' }
      foreach ($name in $Names) { if (-not $seen.Contains($name)) { throw 'InvalidImages' } }
    }
    function canonicalPath([string]$Path) {
      if ($Path -notmatch '\A[A-Za-z]:[\\/][^:\x00-\x1f<>"|?*~]+\z') { throw 'InvalidPaths' }
      $full = [IO.Path]::GetFullPath($Path)
      if (-not [string]::Equals($full, $Path.Replace('/', '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'InvalidPaths' }
      foreach ($part in $full.Substring(3).Split([char]92)) {
        if (-not $part -or $part -in @('.', '..') -or $part.EndsWith('.') -or $part.EndsWith(' ')) { throw 'InvalidPaths' }
        if ($part -match '\A(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?\z') { throw 'InvalidPaths' }
      }
      return $full
    }
    function inspectPath([string]$Path, [switch]$Directory) {
      $current = $Path; $isDirectory = [bool]$Directory
      while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        $link = $item.PSObject.Properties['LinkType']
        if ($null -eq $link -or $link.Value -or $item.PSProvider.Name -cne 'FileSystem' -or
            $item.PSIsContainer -isnot [bool] -or $item.PSIsContainer -ne $isDirectory -or
            $item.Attributes -isnot [IO.FileAttributes] -or
            -not [string]::Equals([IO.Path]::GetFullPath($item.FullName), $current, [StringComparison]::OrdinalIgnoreCase)) {
          throw 'UnsafePathMetadata'
        }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Assert-CoordCloudPlaceholder $current }
        $current = [IO.Path]::GetDirectoryName($current)
        $isDirectory = $true
      }
    }
    function lfText([byte[]]$Bytes, [switch]$AllowEmpty) {
      if (($Bytes.Length -eq 0 -and -not $AllowEmpty) -or ($Bytes -contains [byte]13) -or
          ($Bytes.Length -ge 3 -and $Bytes[0] -eq 239 -and $Bytes[1] -eq 187 -and $Bytes[2] -eq 191)) {
        throw 'UnsupportedTextEncoding'
      }
      return $utf8.GetString($Bytes)
    }
    function element($Value) {
      $document = [System.Text.Json.JsonDocument]::Parse((ConvertTo-Json -InputObject $Value -Depth 5 -Compress))
      try { return $document.RootElement.Clone() } finally { $document.Dispose() }
    }
  }
  process {
    $phase = 'Validation'; $created = $false; $root = $null
    try {
      $before = $BeforeImages.Clone()
      closedObject $before $slots
      $decoded = @{}; $paths = @{}; $after = [ordered]@{}
      $identities = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($slot in $slots) {
        $image = $before.GetProperty($slot)
        closedObject $image @('path', 'bytesBase64', 'digest')
        foreach ($key in @('path', 'bytesBase64', 'digest')) {
          if ($image.GetProperty($key).ValueKind -ne [System.Text.Json.JsonValueKind]::String) { throw 'InvalidImages' }
        }
        $path = $image.GetProperty('path').GetString()
        $paths[$slot] = canonicalPath $path
        if (-not $identities.Add($paths[$slot])) { throw 'InvalidPaths' }
        $base64 = $image.GetProperty('bytesBase64').GetString()
        [byte[]]$bytes = [Convert]::FromBase64String($base64)
        $digest = $image.GetProperty('digest').GetString()
        if (-not (sameText ([Convert]::ToBase64String($bytes)) $base64) -or
            $digest -cnotmatch '\A[0-9a-f]{64}\z' -or -not (sameText (sha $bytes) $digest)) { throw 'InvalidImages' }
        $decoded[$slot] = $bytes
        $after[$slot] = [ordered]@{ path = $path; bytesBase64 = $base64; digest = $digest }
      }
      $names = @('Stage', 'RequestId', 'TaskId', 'Generation', 'BaseRevision', 'BeforeSha256',
        'AfterSha256', 'BeforeBytes', 'AfterBytes', 'AfterText', 'Reservations')
      $properties = @($Preview.PSObject.Properties)
      if ($properties.Count -ne $names.Count) { throw 'InvalidPreview' }
      foreach ($property in $properties) {
        if ($property.MemberType -ne [Management.Automation.PSMemberTypes]::NoteProperty -or $property.Name -cnotin $names) { throw 'InvalidPreview' }
      }
      foreach ($name in @('Stage', 'RequestId', 'TaskId', 'Generation', 'BaseRevision', 'BeforeSha256', 'AfterSha256', 'AfterText')) {
        if ($Preview.$name -isnot [string] -or $Preview.$name.Length -eq 0) { throw 'InvalidPreview' }
      }
      if ($Preview.Stage -cne 'ProposedNotPrepared' -or $Preview.BeforeBytes -isnot [byte[]] -or
          $Preview.AfterBytes -isnot [byte[]] -or $Preview.Reservations -isnot [System.Text.Json.JsonElement] -or
          $Preview.Reservations.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) { throw 'InvalidPreview' }
      [byte[]]$previewBefore = $Preview.BeforeBytes.Clone()
      [byte[]]$previewAfter = $Preview.AfterBytes.Clone()
      if (-not (sameText (sha $previewBefore) $Preview.BeforeSha256) -or
          -not (sameText (sha $previewAfter) $Preview.AfterSha256) -or
          -not (sameText ([Convert]::ToBase64String($previewBefore)) $after.markdown.bytesBase64) -or
          -not (sameText $Preview.BeforeSha256 $after.markdown.digest) -or
          -not (sameText (lfText $previewAfter) $Preview.AfterText)) { throw 'PreviewBindingMismatch' }
      $null = lfText $previewBefore
      $null = lfText $decoded.boardHtml -AllowEmpty
      $root = canonicalPath $ScratchRoot
      if (-not $root.StartsWith('D:\ATAPArtifacts\', [StringComparison]::OrdinalIgnoreCase)) { throw 'InvalidScratchRoot' }
      foreach ($path in $paths.Values) {
        if ([string]::Equals($root, $path, [StringComparison]::OrdinalIgnoreCase) -or
            $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $root.StartsWith($path + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'ScratchOverlap' }
      }
      $markdownPath = Join-Path $root ([IO.Path]::GetFileName($paths.markdown))
      $boardPath = Join-Path $root ([IO.Path]::GetFileName($paths.boardHtml))
      if ([string]::Equals($markdownPath, $boardPath, [StringComparison]::OrdinalIgnoreCase)) { throw 'InvalidPaths' }
      if (sameText $Preview.BeforeSha256 $Preview.AfterSha256) {
        return [PSCustomObject]@{ Stage = 'CandidateNotPrepared'; Action = 'Unchanged'; BeforeOutputs = $before; AfterOutputs = $before.Clone(); ScratchRoot = $null }
      }
      if (-not $PSCmdlet.ShouldProcess($root, 'Construct staged quartet candidate without preparation or publication')) {
        return [PSCustomObject]@{ Stage = 'CandidateNotPrepared'; Action = 'ProposedOnly'; BeforeOutputs = $before; AfterOutputs = $null; ScratchRoot = $null }
      }
      $phase = 'ScratchValidation'
      foreach ($path in $paths.Values) { inspectPath $path }
      if (Test-Path -LiteralPath $root) { throw 'ScratchAlreadyExists' }
      $parent = [IO.Path]::GetDirectoryName($root)
      # Existing parent required; no silent creation of an unbound ancestor tree.
      inspectPath $parent -Directory
      $null = Get-Command Invoke-CoordOperationFileIo -ErrorAction Stop
      $null = New-Item -Path $root -ItemType Directory -ErrorAction Stop
      $created = $true
      inspectPath $root -Directory
      if ((Test-Path -LiteralPath $markdownPath) -or (Test-Path -LiteralPath $boardPath)) { throw 'ScratchAlreadyExists' }
      $phase = 'StageMarkdown'
      $null = Invoke-CoordOperationFileIo -Phase Stage -StatePath $markdownPath -StagePath $markdownPath -Bytes $previewAfter
      inspectPath $markdownPath
      $null = Invoke-CoordOperationFileIo -Phase Stage -StatePath $boardPath -StagePath $boardPath -Bytes $decoded.boardHtml
      inspectPath $boardPath
      $phase = 'Render'
      $summaries = @(Invoke-CoordQuartetCandidateRender -TasksFilePath $markdownPath -OutputPath $boardPath -Confirm:$false)
      if ($summaries.Count -ne 1 -or
          -not [string]::Equals($summaries[0].TasksFilePath, $markdownPath, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals($summaries[0].OutputPath, $boardPath, [StringComparison]::OrdinalIgnoreCase) -or
          $summaries[0].ReconciliationReportPath) { throw 'RendererOutputMismatch' }
      $phase = 'Capture'
      inspectPath $markdownPath
      inspectPath $boardPath
      [byte[]]$stagedMarkdown = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $markdownPath
      if (-not (sameText ([Convert]::ToBase64String($stagedMarkdown)) ([Convert]::ToBase64String($previewAfter)))) { throw 'RendererChangedMarkdown' }
      [byte[]]$html = Invoke-CoordOperationFileIo -Phase ReadBack -StatePath $boardPath
      $null = lfText $html
      $after.markdown.bytesBase64 = [Convert]::ToBase64String($previewAfter)
      $after.markdown.digest = sha $previewAfter
      $after.boardHtml.bytesBase64 = [Convert]::ToBase64String($html)
      $after.boardHtml.digest = sha $html
      [PSCustomObject]@{ Stage = 'CandidateNotPrepared'; Action = 'Rendered'; BeforeOutputs = $before; AfterOutputs = (element $after); ScratchRoot = $root }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Quartet candidate refused at $phase; no preparation or publication performed."
      $failure = [InvalidOperationException]::new("New-CoordQuartetCandidate: refused at $phase.")
      $failure.Data['Phase'] = $phase
      $failure.Data['ScratchRoot'] = if ($created) { $root } else { $null }
      throw $failure
    }
  }
  end {}
}
