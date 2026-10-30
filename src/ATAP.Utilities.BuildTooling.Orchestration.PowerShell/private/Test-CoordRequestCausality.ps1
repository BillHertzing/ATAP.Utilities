function Test-CoordRequestCausality {
  <#
  .SYNOPSIS
    Observes candidate-reachable S3 predecessor errors without admitting work.
  .DESCRIPTION
    Caller supplies a strictly validated NEW request, registered-resource permission,
    and authenticated retained-record snapshot. Identity/retry and earlier S3 checks
    belong to the caller. This helper checks neither grants nor full import integrity.

    Only branches reachable from the candidate's direct predecessor IDs are walked.
    Authentic Rejected records are terminal evidence: their historical bad/self/missing
    edges are never traversed. The candidate's own ID is a cycle even when not retained.
    Cycles precede missing targets, which precede foreign targets; direct Rejected
    predecessors precede waiting on Pending/Prepared/NeedsRecovery.

    PredecessorIds contains DIRECTLY DECLARED candidate predecessor IDs whose reachable
    branch has the winning-priority error, sorted ordinally. It does not expose internal
    graph paths or foreign records. Input arrays and records are unchanged.

    WaitingForPredecessor is only a graph observation, not durable Pending. Still-open
    order8 category/claim compatibility can override it. All-Applied/empty dependencies
    need further validation, never Eligible. No timestamps, filenames, rebase, queue,
    revision, custody, persistence or automatic state transitions are involved.
  .PARAMETER Request
    Strictly validated new request JsonElement.
  .PARAMETER ExpectedResourceId
    Exact registered resource identity already authorized by the caller.
  .PARAMETER RetainedRecords
    Caller-validated JsonElement array of records with request identity and status.
  .OUTPUTS
    PSCustomObject: Stage=CausalityCheckedNotAdmitted, Decision, PredecessorIds,
    Boundary. Decisions are local graph observations, never retained wire outcomes.
  .EXAMPLE
    Test-CoordRequestCausality -Request $request -ExpectedResourceId $resourceId -RetainedRecords $records
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [System.Text.Json.JsonElement]$Request,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedResourceId,

    [Parameter(Mandatory)]
    [System.Text.Json.JsonElement]$RetainedRecords
  )

  begin {
    $fn = 'Test-CoordRequestCausality'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Checking predecessor graph without admission'
  }

  process {
    $result = [PSCustomObject]@{
      Stage = 'CausalityCheckedNotAdmitted'
      Decision = 'InvalidInput'
      PredecessorIds = [string[]]@()
      Boundary = 'Graph observation only; category/claim compatibility and remaining S3 authority/revision/admission checks are not performed.'
    }
    try {
      $resourceId = $Request.GetProperty('resourceId').GetString()
      $requestId = $Request.GetProperty('requestId').GetString()
      $predecessors = $Request.GetProperty('predecessors')
      if ([string]::IsNullOrEmpty($resourceId) -or [string]::IsNullOrEmpty($requestId) -or
          $predecessors.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'Invalid candidate identity or predecessors.' }
      $roots = [Collections.Generic.List[string]]::new()
      $uniqueRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($item in $predecessors.EnumerateArray()) {
        $id = $item.GetString()
        if ([string]::IsNullOrEmpty($id) -or -not $uniqueRoots.Add($id)) { throw 'Invalid predecessor IDs.' }
        $roots.Add($id)
      }
    } catch {
      return $result
    }
    if (-not [string]::Equals($resourceId, $ExpectedResourceId, [StringComparison]::Ordinal)) {
      $result.Decision = 'ResourceMismatch'
      return $result
    }

    try {
      if ($RetainedRecords.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'Records array required.' }
      $snapshot = $RetainedRecords.Clone()
      $local = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
      $foreign = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($record in $snapshot.EnumerateArray()) {
        $retainedRequest = $record.GetProperty('request')
        $retainedResource = $retainedRequest.GetProperty('resourceId').GetString()
        $retainedId = $retainedRequest.GetProperty('requestId').GetString()
        if ([string]::IsNullOrEmpty($retainedResource) -or [string]::IsNullOrEmpty($retainedId)) { throw 'Ambiguous retained identity.' }
        if ([string]::Equals($retainedResource, $ExpectedResourceId, [StringComparison]::Ordinal)) {
          if (-not $local.ContainsKey($retainedId)) { $local.Add($retainedId, [Collections.Generic.List[Text.Json.JsonElement]]::new()) }
          $local[$retainedId].Add($record)
        } else {
          $null = $foreign.Add($retainedId)
        }
      }
      $issues = [ordered]@{}
      foreach ($decision in @('CausalCycle', 'MissingPredecessor', 'ForeignPredecessor', 'PredecessorFailed', 'WaitingForPredecessor')) {
        $issues[$decision] = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      }
      foreach ($rootId in $roots) {
        $visiting = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $stack = [Collections.Generic.Stack[object]]::new()
        $stack.Push([PSCustomObject]@{ Id = $rootId; Exit = $false })
        while ($stack.Count -gt 0) {
          $frame = $stack.Pop()
          $id = $frame.Id
          if ($frame.Exit) {
            $null = $visiting.Remove($id)
            $null = $visited.Add($id)
            continue
          }
          if ([string]::Equals($id, $requestId, [StringComparison]::Ordinal)) {
            $null = $issues.CausalCycle.Add($rootId)
            break
          }
          if (-not $local.ContainsKey($id)) {
            if ($foreign.Contains($id)) { $null = $issues.ForeignPredecessor.Add($rootId) } else { $null = $issues.MissingPredecessor.Add($rootId) }
            continue
          }
          $entries = $local[$id]
          if ($entries.Count -ne 1) { throw 'Ambiguous reachable retained identity.' }
          $record = $entries[0]
          $status = $record.GetProperty('status').GetString()
          if ($status -cnotin @('Pending', 'Prepared', 'Applied', 'Rejected', 'NeedsRecovery')) { throw 'Unsupported reachable status.' }
          if ([string]::Equals($id, $rootId, [StringComparison]::Ordinal)) {
            if ($status -ceq 'Rejected') { $null = $issues.PredecessorFailed.Add($rootId) }
            if ($status -cin @('Pending', 'Prepared', 'NeedsRecovery')) { $null = $issues.WaitingForPredecessor.Add($rootId) }
          }
          # Rejected references are preserved evidence, never outgoing graph edges.
          if ($status -ceq 'Rejected') { continue }
          if ($visiting.Contains($id)) {
            $null = $issues.CausalCycle.Add($rootId)
            break
          }
          if ($visited.Contains($id)) { continue }
          $null = $visiting.Add($id)
          $stack.Push([PSCustomObject]@{ Id = $id; Exit = $true })
          $edges = $record.GetProperty('request').GetProperty('predecessors')
          if ($edges.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'Invalid reachable edges.' }
          $uniqueEdges = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
          for ($i = $edges.GetArrayLength() - 1; $i -ge 0; $i--) {
            $childId = $edges[$i].GetString()
            if ([string]::IsNullOrEmpty($childId) -or -not $uniqueEdges.Add($childId)) { throw 'Invalid reachable edge ID.' }
            $stack.Push([PSCustomObject]@{ Id = $childId; Exit = $false })
          }
        }
      }
      foreach ($decision in $issues.Keys) {
        if ($issues[$decision].Count -eq 0) { continue }
        [string[]]$orderedIds = @($issues[$decision])
        [Array]::Sort($orderedIds, [StringComparer]::Ordinal)
        $result.Decision = $decision
        $result.PredecessorIds = $orderedIds
        return $result
      }
      $result.Decision = 'NeedsFurtherValidation'
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Reachable predecessor graph requires recovery'
      $result.Decision = 'NeedsRecovery'
    }
    $result
  }

  end {}
}
