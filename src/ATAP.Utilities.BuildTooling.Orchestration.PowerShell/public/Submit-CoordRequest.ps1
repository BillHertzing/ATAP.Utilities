function Submit-CoordRequest {
  <#
  .SYNOPSIS
    Durably queues an authorized request under protected resource custody.
  .DESCRIPTION
    Established configured custody is required; this function never bootstraps.
    Registered chat roles are cooperative and bound to the actual Windows account.
    Durable Pending means queued, not granted/applied or feature completion.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][byte[]]$EnvelopeBytes,
    [Parameter(Mandatory)][string]$HolderId, [Parameter(Mandatory)][string]$SessionId)
  begin {
    $fn = 'Submit-CoordRequest'; $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    if (-not (Get-Command Read-CoordProducerContext -ErrorAction SilentlyContinue)) {
      foreach ($name in @('CoordProducerJson', 'Enter-CoordResourceLease', 'CoordProducer', 'Test-CoordRequest', 'Test-CoordRequestCausality')) {
        . (Join-Path $PSScriptRoot "../private/$name.ps1")
      }
    }
  }
  process {
    if (-not $PSCmdlet.ShouldProcess($HolderId, 'Durably submit to configured coordination resource')) {
      return [pscustomobject]@{ Status = 'ProposedOnly'; Durable = $false }
    }
    $context = $null
    try {
      $context = Read-CoordProducerContext -HolderId $HolderId -SessionId $SessionId
      $classified = Test-CoordRequest -EnvelopeBytes $EnvelopeBytes -MaxRequestBytes $context.Limits.MaxRequestBytes -ExpectedResourceId $context.Record.resourceId -RetainedRecords $context.State.GetProperty('requests')
      $canonical = $classified.CanonicalRequest
      if ($canonical -and $context.Actor.role -cne 'Coordinator' -and
          ($canonical.Request.GetProperty('holder').GetProperty('holderId').GetString() -cne $HolderId -or
           $canonical.Request.GetProperty('holder').GetProperty('sessionId').GetString() -cne $SessionId)) { throw 'HolderConflict' }
      if ($classified.Decision -eq 'Retained') {
        return [pscustomobject]@{ Status = $classified.RetainedStatus; Decision = 'Retained'; Durable = $true; Record = $classified.RetainedRecord.Clone() }
      }
      if ($classified.Decision -ne 'NewRequestNeedsFurtherValidation') {
        return [pscustomobject]@{ Status = $classified.Decision; Decision = $classified.Decision; Durable = $false; Record = $null }
      }
      if (-not $canonical.DigestMatches) { return [pscustomobject]@{ Status = 'DigestMismatch'; Durable = $false } }
      $request = $canonical.Request
      $null = Get-CoordRequestGrant $context $request $canonical.Digest
      Assert-CoordPublishedHead $context
      if ($request.GetProperty('sprintId').GetString() -cne $context.Record.sprintId -or
          $request.GetProperty('generation').GetString() -cne $context.Record.generation -or
          $request.GetProperty('expectedRevision').GetString() -cne $context.State.GetProperty('committedRevision').GetString()) { throw 'RevisionConflict' }
      $null = Resolve-CoordScopeBindings $context.State $request.GetProperty('scope')
      $boardPath = $context.State.GetProperty('committedOutputManifest').GetProperty('markdown').GetProperty('path').GetString()
      $board = Read-CoordBoard -PlanningRoot ([IO.Path]::GetDirectoryName($boardPath)) -SprintNumber ([int]$request.GetProperty('sprintId').GetString())
      if ($board.Path -ine $boardPath -or @($board.Tasks | Where-Object { $_.Id -ceq $request.GetProperty('taskId').GetString() }).Count -ne 1) { throw 'UnknownTask' }
      $maxOrdinal = [long]-1
      $ordinals = [Collections.Generic.HashSet[long]]::new()
      foreach ($retained in $context.State.GetProperty('requests').EnumerateArray()) {
        $ordinal = [long]::Parse($retained.GetProperty('queueOrdinal').GetString(), [Globalization.CultureInfo]::InvariantCulture)
        if ($ordinal -lt 0 -or -not $ordinals.Add($ordinal)) { throw 'InvalidQueueOrdinal' }
        if ($ordinal -gt $maxOrdinal) { $maxOrdinal = $ordinal }
      }
      if ($maxOrdinal -eq [long]::MaxValue) { throw 'QueueOrdinalExhausted' }
      $nextOrdinal = $maxOrdinal + [long]1
      $record = [ordered]@{ request = $request.Clone(); digest = $canonical.Digest
        originalRequestJson = $request.GetRawText(); queueOrdinal = $nextOrdinal.ToString([Globalization.CultureInfo]::InvariantCulture)
        status = 'Pending'; pendingEvidence = [ordered]@{ reason = 'Eligible' } }
      $state = Get-CoordMembers $context.State
      $state.requests = @($context.State.GetProperty('requests').EnumerateArray() | ForEach-Object { $_.Clone() }) + @($record)
      Save-CoordProducerState $context (ConvertTo-CoordElement $state)
      return [pscustomobject]@{ Status = 'Pending'; Decision = 'Queued'; Durable = $true; QueueOrdinal = $record.queueOrdinal; Record = ConvertTo-CoordElement $record }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Coordination submission refused; no acceptance asserted'
      throw
    } finally {
      if ($context) { $context.BoardLease.Dispose(); $context.Lease.Dispose() }
    }
  }
  end {}
}
