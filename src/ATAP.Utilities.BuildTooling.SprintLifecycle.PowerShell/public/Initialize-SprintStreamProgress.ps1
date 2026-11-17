function Initialize-SprintStreamProgress {
  <#
  .SYNOPSIS
    Initializes durable stream-progress inputs after the sprint board quartet exists.
  .DESCRIPTION
    Creates a separate derived page. Never edits the quartet or orchestration state.
    InitialModelPath imports an explicitly reviewed display baseline, not task authority.
  .EXAMPLE
    Initialize-SprintStreamProgress -PlanningRoot 'C:\Planning-wt-44' -SprintNumber 17 -StartDate '2026-10-24' -EndDate '2026-11-23' -TimeZoneId 'America/Denver' -ObservedAt '2026-11-16T18:00:00Z' -ManualWriterReference 'operator-owned manual refresh' -WhatIf
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][string]$PlanningRoot,
    [Parameter(Mandatory)][ValidateRange(1, 9999)][int]$SprintNumber,
    [Parameter(Mandatory)][string]$StartDate,
    [Parameter(Mandatory)][string]$EndDate,
    [Parameter(Mandatory)][string]$TimeZoneId,
    [Parameter(Mandatory)][DateTimeOffset]$ObservedAt,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ManualWriterReference,
    [string]$InitialModelPath,
    [string]$ReviewReference,
    [hashtable]$TaskStreamOverrides = @{},
    [hashtable]$SourceBinding = @{}
  )
  begin {
    $fn = 'Initialize-SprintStreamProgress'; $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    if (-not (Get-Command Read-StreamProgressManifest -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '../private/StreamProgress.Helpers.ps1') }
    if (-not (Get-Command Update-SprintStreamProgress -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Update-SprintStreamProgress.ps1') }
  }
  process {
    try {
      if (-not [IO.Path]::IsPathFullyQualified($PlanningRoot) -or -not [IO.Directory]::Exists($PlanningRoot)) { throw 'ProgressRootInvalid' }
      $root = [IO.Path]::GetFullPath($PlanningRoot)
      $start = [DateOnly]::ParseExact($StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $end = [DateOnly]::ParseExact($EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      if ($end -lt $start -or $end.DayNumber - $start.DayNumber -gt 366) { throw 'ProgressDateRangeInvalid' }
      $null = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
      $directory = Join-Path $root ('InformationForTheFuture/Sprint{0:D4}/StreamProgress' -f $SprintNumber)
      $manifestPath = Join-Path $directory 'StreamProgress.manifest.json'
      $config = @{
        schemaVersion = 1; sprintNumber = $SprintNumber; planningRoot = $root
        outputPath = Join-Path $root ('Tasks.Sprint{0:D4}.StreamProgress.html' -f $SprintNumber)
        activityPath = Join-Path $directory 'StreamProgress.activity.json'
        policyPath = Join-Path $directory 'StreamProgress.policy.json'
        startDate = $StartDate; endDate = $EndDate; timeZoneId = $TimeZoneId
        observedAt = $ObservedAt.ToUniversalTime().ToString('o'); sourceBinding = $SourceBinding
        taskStreamOverrides = @{} + $TaskStreamOverrides
      }
      $null = Assert-StreamProgressPath $manifestPath $root
      $bindings = Get-StreamProgressBindings $config; $hashes = @{}
      foreach ($slot in $bindings.Keys) {
        $null = Assert-StreamProgressPath $bindings[$slot] $root
        $hashes[$slot] = (Get-FileHash -LiteralPath $bindings[$slot] -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
      }
      $initial = $null; $mapping = @{} + $TaskStreamOverrides
      if ($InitialModelPath) {
        if (-not $ReviewReference) { throw 'ProgressBaselineReviewRequired' }
        $initial = Read-StreamProgressJson $InitialModelPath
        if ($initial.records -isnot [array]) { throw 'ProgressBaselineInvalid' }
        foreach ($id in $initial.progress.tasks.Keys) { if (-not $mapping.ContainsKey($id)) { $mapping[$id] = $initial.progress.tasks[$id].stream } }
      }
      $board = Read-StreamProgressBoardModel $bindings.markdown $mapping
      foreach ($item in $board.tasks.Values) { if ($item.streamMappedBy -ceq 'Override') { $config.taskStreamOverrides[$item.id] = $item.stream } }
      $activity = @{ schemaVersion = 1; records = @(); codexAudit = $null; claudeAudit = $null; reviewReference = $ReviewReference }
      $policy = @{ schemaVersion = 1; tasks = @{}; method = 'Explicit reviewed per-leaf work-point estimates; unknown tasks earn no completion credit. Parent tasks are not counted twice.' }
      if ($InitialModelPath) {
        $activity.records = $initial.records; $activity.codexAudit = $initial.codexAudit; $activity.claudeAudit = $initial.claudeAudit
        foreach ($task in $board.tasks.Values) {
          $old = $initial.progress.tasks[$task.id]
          if ($old) {
            $policy.tasks[$task.id] = @{
              taskSha256 = $task.taskSha256; state = $old.state; weight = $old.weight; fraction = $old.fraction
              deferred = [bool]$old.deferred; ready = $false; prerequisitesSatisfied = $false; selected = -not $old.deferred
              basis = [string]$old.basis + ' Imported display assessment; readiness prerequisites not independently verified.'
              reviewReference = $ReviewReference
            }
          }
        }
      }
      $null = New-StreamProgressModel $config $board $activity $policy $config.observedAt
      if ([IO.File]::Exists($manifestPath)) {
        $existing = Read-StreamProgressManifest $manifestPath
        if ((ConvertTo-StreamProgressJson $existing) -cne (ConvertTo-StreamProgressJson $config)) { throw 'ProgressExistingConfigurationConflict' }
        return Update-SprintStreamProgress -InputManifestPath $manifestPath -ExpectedBoardHashes $hashes -ManualWriterReference $ManualWriterReference -WhatIf:$WhatIfPreference -Confirm:$false
      }
      if (-not $PSCmdlet.ShouldProcess($config.outputPath, 'Initialize durable inputs and stream progress page')) {
        return [pscustomobject]@{ Status = 'WouldInitialize'; ManifestPath = $manifestPath; OutputPath = $config.outputPath }
      }
      $null = [IO.Directory]::CreateDirectory($directory)
      foreach ($entry in @(@{path = $config.activityPath; value = $activity}, @{path = $config.policyPath; value = $policy}, @{path = $manifestPath; value = $config})) {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-StreamProgressJson $entry.value))
        if ([IO.File]::Exists($entry.path)) {
          if ((Get-StreamProgressHash ([IO.File]::ReadAllBytes($entry.path))) -cne (Get-StreamProgressHash $bytes)) { throw 'ProgressPartialInitializationConflict' }
        } else {
          $file = [IO.File]::Open($entry.path, 'CreateNew', 'Write', 'None')
          try { $file.Write($bytes); $file.Flush($true) } finally { $file.Dispose() }
        }
      }
      $result = Update-SprintStreamProgress -InputManifestPath $manifestPath -ExpectedBoardHashes $hashes -ManualWriterReference $ManualWriterReference -Confirm:$false
      $result.Status = 'Created'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Initialized separate stream progress page'
      return $result
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message ('Initialization refused: ' + $_.Exception.Message)
      throw
    }
  }
}
