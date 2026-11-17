function Update-SprintStreamProgress {
  <#
  .SYNOPSIS
    Publishes the separate stream progress view from pinned board and reviewed inputs.
  .DESCRIPTION
    Locks source files for a coherent local read and publishes one HTML file with
    a compare-before-replace check. No request, custody or quartet mutation occurs.
    Committed mode is a future adapter contract; no orchestrator hook is installed.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Manual')]
  param(
    [Parameter(Mandatory)][string]$InputManifestPath,
    [Parameter(Mandatory, ParameterSetName = 'Manual')][hashtable]$ExpectedBoardHashes,
    [Parameter(Mandatory, ParameterSetName = 'Manual')][ValidateNotNullOrEmpty()][string]$ManualWriterReference,
    [Parameter(Mandatory, ParameterSetName = 'Committed')][string]$CommittedSnapshotPath,
    [Parameter(Mandatory, ParameterSetName = 'Committed')][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSnapshotSha256,
    [ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedOutputSha256
  )
  begin {
    $fn = 'Update-SprintStreamProgress'; $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    if (-not (Get-Command Read-StreamProgressManifest -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '../private/StreamProgress.Helpers.ps1') }
  }
  process {
    $handles = [Collections.Generic.List[IO.FileStream]]::new(); $lease = $null; $candidate = $null
    try {
      $config = Read-StreamProgressManifest $InputManifestPath
      $bindings = Get-StreamProgressBindings $config
      if ($PSCmdlet.ParameterSetName -eq 'Manual') { $ExpectedBoardHashes = @{} + $ExpectedBoardHashes }
      $observedAt = [string]$config.observedAt; $revision = ''; $identity = 'manual'
      if ($config.sourceBinding.Count) { $identity = ConvertTo-StreamProgressJson $config.sourceBinding }
      if ($PSCmdlet.ParameterSetName -eq 'Committed') {
        $snapshotBytes = [IO.File]::ReadAllBytes($CommittedSnapshotPath)
        if ((Get-StreamProgressHash $snapshotBytes) -ine $ExpectedSnapshotSha256) { throw 'ProgressSnapshotHashMismatch' }
        $snapshotParameters = @{ InputObject = [Text.Encoding]::UTF8.GetString($snapshotBytes); AsHashtable = $true; Depth = 100; ErrorAction = 'Stop' }
        if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $snapshotParameters.DateKind = 'String' }
        $snapshot = ConvertFrom-Json @snapshotParameters
        if ($snapshot.schemaVersion -ne 1 -or $snapshot.status -cne 'Applied' -or $snapshot.sprintNumber -ne $config.sprintNumber -or -not $snapshot.committedRevision -or -not $snapshot.commitReceiptId) { throw 'ProgressSnapshotNotApplied' }
        foreach ($field in @('resourceId', 'lineageId', 'generation')) {
          if (-not $config.sourceBinding.ContainsKey($field) -or $snapshot[$field] -cne $config.sourceBinding[$field]) { throw 'ProgressSnapshotIdentityMismatch' }
        }
        $ExpectedBoardHashes = @{}
        foreach ($slot in $bindings.Keys) {
          if ($snapshot.quartet[$slot].path -ine $bindings[$slot]) { throw 'ProgressSnapshotPathMismatch' }
          $ExpectedBoardHashes[$slot] = $snapshot.quartet[$slot].sha256
        }
        $revision = $snapshot.committedRevision; $identity = ConvertTo-StreamProgressJson $config.sourceBinding
        $observedAt = $snapshot.observedAt
      }
      if ($ExpectedBoardHashes.Count -ne 4) { throw 'ProgressQuartetBindingsRequired' }
      foreach ($slot in $bindings.Keys) {
        if ([string]$ExpectedBoardHashes[$slot] -notmatch '^[a-fA-F0-9]{64}$') { throw 'ProgressQuartetDigestInvalid' }
        $ExpectedBoardHashes[$slot] = ([string]$ExpectedBoardHashes[$slot]).ToLowerInvariant()
        $null = Assert-StreamProgressPath $bindings[$slot] $config.planningRoot
      }
      $observed = [DateTimeOffset]::Parse($observedAt, [Globalization.CultureInfo]::InvariantCulture)
      $observedAt = $observed.ToUniversalTime().ToString('o')
      $output = $config.outputPath
      if (-not $PSCmdlet.ShouldProcess($output, 'Refresh separate stream progress page from pinned inputs')) {
        return [pscustomobject]@{ Status = 'WouldUpdate'; OutputPath = $output }
      }
      $scratch = Join-Path $config.planningRoot ('_generated/Sprint{0:D4}/StreamProgress' -f [int]$config.sprintNumber)
      $null = Assert-StreamProgressPath (Join-Path $scratch 'writer.lock') $config.planningRoot
      $null = [IO.Directory]::CreateDirectory($scratch)
      $lease = [IO.File]::Open((Join-Path $scratch 'writer.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
      $oldBytes = if ([IO.File]::Exists($output)) { [IO.File]::ReadAllBytes($output) } else { $null }
      $oldHash = if ($null -ne $oldBytes) { Get-StreamProgressHash $oldBytes } else { $null }
      if ($ExpectedOutputSha256 -and $oldHash -ine $ExpectedOutputSha256) { throw 'ProgressOutputConflict' }
      $oldStamp = $null
      if ($null -ne $oldBytes) {
        $text = [Text.Encoding]::UTF8.GetString($oldBytes)
        if ($text -notmatch '\A<!-- StreamProgress:v1:([A-Za-z0-9+/=]+) -->') { throw 'ProgressUnownedOutputRefused' }
        $oldStamp = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Matches[1])) | ConvertFrom-Json -AsHashtable
        if ($oldStamp.identity -cne $identity) { throw 'ProgressOutputIdentityMismatch' }
        if ($PSCmdlet.ParameterSetName -eq 'Committed' -and $oldStamp.revision -cne $revision -and $oldStamp.revision -cne $snapshot.previousRevision) { throw 'ProgressRevisionConflict' }
        if ([DateTimeOffset]::Parse($oldStamp.observedAt) -gt $observed) { throw 'ProgressOlderObservationRefused' }
      }
      # Shared-read handles deny local source writes/deletion throughout comparison/publication.
      # This is local file exclusion, never a claim that Dropbox replicas are fenced.
      foreach ($path in @($InputManifestPath, $config.activityPath, $config.policyPath) + @($bindings.Values)) {
        $file = [IO.File]::Open($path, 'Open', 'Read', 'Read'); $handles.Add($file)
      }
      if ((ConvertTo-StreamProgressJson (Read-StreamProgressManifest $InputManifestPath)) -cne (ConvertTo-StreamProgressJson $config)) { throw 'ProgressManifestChanged' }
      foreach ($slot in $bindings.Keys) {
        $actual = (Get-FileHash -LiteralPath $bindings[$slot] -Algorithm SHA256).Hash
        if ($actual -ine $ExpectedBoardHashes[$slot]) { throw 'ProgressBoardSnapshotChanged' }
      }
      if ((Get-StreamProgressBoard $config.planningRoot ([int]$config.sprintNumber)) -ine $bindings.markdown) { throw 'ProgressBoardSelectionChanged' }
      $board = Read-StreamProgressBoardModel $bindings.markdown $config.taskStreamOverrides
      $activity = Read-StreamProgressJson $config.activityPath
      $policy = Read-StreamProgressJson $config.policyPath
      if ($activity.schemaVersion -ne 1 -or $policy.schemaVersion -ne 1 -or $activity.records -isnot [array] -or $policy.tasks -isnot [Collections.IDictionary]) { throw 'ProgressReviewedInputsInvalid' }
      $model = New-StreamProgressModel $config $board $activity $policy $observedAt
      $templatePath = Join-Path (Get-StreamProgressModuleRoot) 'Resources/StreamProgress/template.html'
      $template = [IO.File]::ReadAllText($templatePath)
      if ([regex]::Matches($template, [regex]::Escape('/*DATA*/{}')).Count -ne 1) { throw 'ProgressTemplateInvalid' }
      if (-not $revision) { $revision = 'manual-' + (Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes((ConvertTo-StreamProgressJson $ExpectedBoardHashes)))) }
      $inputs = @{
        model = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes((ConvertTo-StreamProgressJson $model)))
        rendererVersion = 'stream-progress-v1'
        manifest = Get-StreamProgressHash ([IO.File]::ReadAllBytes($InputManifestPath))
        activity = Get-StreamProgressHash ([IO.File]::ReadAllBytes($config.activityPath))
        policy = Get-StreamProgressHash ([IO.File]::ReadAllBytes($config.policyPath))
        template = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes($template))
        quartet = $ExpectedBoardHashes; observedAt = $observedAt; sourceRevision = $revision; identity = $identity
      }
      $key = Get-StreamProgressHash ([Text.Encoding]::UTF8.GetBytes((ConvertTo-StreamProgressJson $inputs)))
      if ($oldStamp -and $oldStamp.inputKey -ceq $key) { return [pscustomobject]@{ Status = 'Unchanged'; OutputPath = $output; OutputSha256 = $oldHash; SourceRevision = $revision; InputKey = $key } }
      $json = (ConvertTo-StreamProgressJson $model).Replace('<', '\u003c').Replace('>', '\u003e').Replace('&', '\u0026').Replace([string][char]0x2028, '\u2028').Replace([string][char]0x2029, '\u2029')
      $stamp = ConvertTo-StreamProgressJson @{ identity = $identity; revision = $revision; observedAt = $observedAt; inputKey = $key; sprintNumber = $config.sprintNumber; source = $inputs }
      $html = '<!-- StreamProgress:v1:' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($stamp)) + " -->`n" + $template.Replace('/*DATA*/{}', $json)
      $candidate = Join-Path $scratch ('candidate-' + [guid]::NewGuid().ToString('N') + '.html')
      [IO.File]::WriteAllText($candidate, $html, [Text.UTF8Encoding]::new($false))
      $newHash = Get-StreamProgressHash ([IO.File]::ReadAllBytes($candidate))
      $currentHash = if ([IO.File]::Exists($output)) { Get-StreamProgressHash ([IO.File]::ReadAllBytes($output)) } else { $null }
      if ($currentHash -cne $oldHash) { throw 'ProgressOutputConflict' }
      if ((Get-StreamProgressBoard $config.planningRoot ([int]$config.sprintNumber)) -ine $bindings.markdown) { throw 'ProgressBoardSelectionChanged' }
      if ($null -eq $oldHash) { [IO.File]::Move($candidate, $output) }
      else { [IO.File]::Replace($candidate, $output, (Join-Path $scratch ('previous-' + $oldHash + '.html'))) }
      if ((Get-StreamProgressHash ([IO.File]::ReadAllBytes($output))) -cne $newHash) { throw 'ProgressOutputReadbackFailed' }
      $receiptPath = Join-Path $scratch ('refresh-' + [guid]::NewGuid().ToString('N') + '.json')
      $receipt = @{ status = 'Updated'; sourceRevision = $revision; inputKey = $key; outputSha256 = $newHash; attemptUtc = [DateTimeOffset]::UtcNow.ToString('o'); quartet = $ExpectedBoardHashes }
      [IO.File]::WriteAllText($receiptPath, (ConvertTo-StreamProgressJson $receipt), [Text.UTF8Encoding]::new($false))
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Published separate stream progress page'
      [pscustomobject]@{ Status = 'Updated'; OutputPath = $output; OutputSha256 = $newHash; SourceRevision = $revision; InputKey = $key; ReceiptPath = $receiptPath }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ('Progress refresh failed: ' + $_.Exception.Message)
      throw
    } finally {
      foreach ($handle in $handles) { $handle.Dispose() }
      if ($lease) { $lease.Dispose() }
    }
  }
}
