BeforeAll {
  $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/Update-CoordClaim.ps1')
  $script:stateSchema = Join-Path $PSScriptRoot '../../schemas/state-v1.schema.json'

  function ConvertTo-ClaimElement {
    param($Value, [switch]$Raw)
    $json = if ($Raw) { [string]$Value } else { ConvertTo-Json -InputObject $Value -Depth 100 -Compress }
    $document = [System.Text.Json.JsonDocument]::Parse($json)
    try { $document.RootElement.Clone() } finally { $document.Dispose() }
  }

  function New-ScopeBinding {
    param(
      [string]$RootId = 'root-u',
      [string]$Path = 'src/Owned.ps1',
      [string[]]$Segments = @('Synthetic', 'Utilities', 'src', 'Owned.ps1'),
      [string]$Comparison = 'OrdinalIgnoreCase'
    )
    $root = @($script:state.registeredRoots | Where-Object { $_.registeredRootId -ceq $RootId })[0]
    [ordered]@{
      registeredRootId = $RootId
      path = $Path
      registeredRootPath = $root.path
      identityDomain = 'volume-fixture'
      segments = $Segments
      comparison = $Comparison
    }
  }

  function Add-ActiveTestClaim {
    param(
      [string]$Id = 'C-active',
      [string]$TaskId = '17.26',
      [string]$Path = 'src/Other.ps1',
      [string[]]$Segments = @('Synthetic', 'Utilities', 'src', 'Other.ps1'),
      [string]$RootId = 'root-u',
      [string]$Comparison = 'OrdinalIgnoreCase'
    )
    $script:state.claims += [ordered]@{
      claimId = $Id
      resourceId = 'board-S17'
      taskId = $TaskId
      scope = @([ordered]@{ registeredRootId = $RootId; path = $Path })
      holder = [ordered]@{ holderId = 'Senior2'; sessionId = 'session-other' }
      generation = 'epoch-A'
      claimRequestId = 'R-' + $Id
    }
    $script:context.activeClaimScopeBindings += [ordered]@{
      claimId = $Id
      scopeBindings = @(New-ScopeBinding -RootId $RootId -Path $Path -Segments $Segments -Comparison $Comparison)
    }
  }

  function Set-ReleaseTestCase {
    Add-ActiveTestClaim -TaskId '17.25' -Path 'src/Owned.ps1' -Segments @('Synthetic', 'Utilities', 'src', 'Owned.ps1')
    $script:state.claims[0].holder = [ordered]@{ holderId = 'Senior1'; sessionId = 'session-A' }
    $script:request.category = 'Release'
    $script:request.requestId = 'R-release'
    $script:request.payload = [ordered]@{ claimId = 'C-active'; releaseReason = 'Source handoff; feature remains open.' }
  }

  function Invoke-TestClaimProposal {
    param([switch]$WithoutClaimId, [switch]$ForceClaimId, [string]$AssignedClaimId = 'C-explicit')
    $arguments = @{
      State = ConvertTo-ClaimElement $script:state
      Request = ConvertTo-ClaimElement $script:request
      Context = ConvertTo-ClaimElement $script:context
    }
    if (($script:request.category -ceq 'Claim' -and -not $WithoutClaimId) -or $ForceClaimId) {
      $arguments.ClaimId = $AssignedClaimId
    }
    Update-CoordClaim @arguments
  }
}

Describe 'Update-CoordClaim pure proposal boundary (synthetic caller-validated inputs only)' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    $digest = '0' * 64
    $manifest = [ordered]@{}
    foreach ($name in @('markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml')) {
      $manifest[$name] = [ordered]@{ path = 'fixture/' + $name; digest = $digest }
    }
    # These are synthetic unit inputs, not authentic custody receipts or live grants.
    # Full schema/authority/retry/causality/containment admission is an upstream precondition.
    $script:state = [ordered]@{
      schemaVersion = 'Coordination-state-v1'
      resourceId = 'board-S17'
      lineageId = 'lineage-A'
      registeredRoots = @(
        [ordered]@{ registeredRootId = 'root-u'; path = 'C:\Synthetic\Utilities' },
        [ordered]@{ registeredRootId = 'root-alias'; path = 'C:\Synthetic\Alias' }
      )
      generation = 'epoch-A'
      committedRevision = 'head-A'
      committedOutputManifest = $manifest
      custodyEvidence = [ordered]@{ reference = 'synthetic-custody'; digest = $digest }
      compatibilityEvidence = [ordered]@{ reference = 'synthetic-compatibility'; digest = $digest }
      admissionEvidence = @([ordered]@{ reference = 'synthetic-admission'; digest = $digest })
      requests = @()
      claims = @()
      reservations = @()
      preparedOperations = @()
      commitReceipts = @()
      mutationAdmission = [ordered]@{ status = 'Admitted'; reason = 'synthetic prevalidated caller boundary'; observedOutputs = @() }
    }
    $script:request = [ordered]@{
      protocolVersion = 'Coordination-v1'
      resourceId = 'board-S17'
      sprintId = '0017'
      requestId = 'R-claim'
      category = 'Claim'
      taskId = '17.25'
      scope = @([ordered]@{ registeredRootId = 'root-u'; path = 'src/Owned.ps1' })
      holder = [ordered]@{ holderId = 'Senior1'; sessionId = 'session-A' }
      authorizationReference = 'synthetic-exact-binding'
      generation = 'epoch-A'
      expectedRevision = 'head-A'
      predecessors = @()
      payload = [ordered]@{}
    }
    $script:context = [ordered]@{
      coordinatorId = 'coordinator-fixture'
      resourceId = 'board-S17'
      lineageId = 'lineage-A'
      sprintId = '0017'
      generation = 'epoch-A'
      committedRevision = 'head-A'
      taskId = '17.25'
      holder = [ordered]@{ holderId = 'Senior1'; sessionId = 'session-A' }
      authorizationReference = 'synthetic-exact-binding'
      existingTasks = @(
        [ordered]@{ taskId = '17.25'; ancestorTaskIds = @() },
        [ordered]@{ taskId = '17.25.a'; ancestorTaskIds = @('17.25') },
        [ordered]@{ taskId = '17.26'; ancestorTaskIds = @() },
        [ordered]@{ taskId = '17.2'; ancestorTaskIds = @() },
        [ordered]@{ taskId = '17.20'; ancestorTaskIds = @() }
      )
      requestScopeBindings = @(New-ScopeBinding)
      activeClaimScopeBindings = @()
    }
  }

  It 'uses explicit distinct claim identity, preserves wire shape and returns a schema-shaped clone only' {
    $inputState = ConvertTo-ClaimElement $script:state
    $before = $inputState.GetRawText()
    $proposal = Update-CoordClaim -State $inputState -Request (ConvertTo-ClaimElement $script:request) -Context (ConvertTo-ClaimElement $script:context) -ClaimId 'C-assigned'
    $proposal.Stage | Should -BeExactly 'ProposedNotApplied'
    $proposal.Category | Should -BeExactly 'Claim'
    $proposal.ClaimId | Should -BeExactly 'C-assigned'
    $claim = $proposal.ProposedState.GetProperty('claims')[0]
    $claim.GetProperty('claimId').GetString() | Should -BeExactly 'C-assigned'
    $claim.GetProperty('claimRequestId').GetString() | Should -BeExactly 'R-claim'
    $claim.GetProperty('scope').GetRawText() | Should -BeExactly ((ConvertTo-ClaimElement $script:request).GetProperty('scope').GetRawText())
    $inputState.GetRawText() | Should -BeExactly $before
    $inputState.GetProperty('claims').GetArrayLength() | Should -Be 0
    Test-Json -Json $proposal.ProposedState.GetRawText() -SchemaFile $script:stateSchema -ErrorAction Stop | Should -BeTrue
    foreach ($property in $inputState.EnumerateObject()) {
      if ($property.Name -cne 'claims') {
        $proposal.ProposedState.GetProperty($property.Name).GetRawText() | Should -BeExactly $property.Value.GetRawText()
      }
    }
  }

  It 'never derives a missing claim ID from request ID or adds a wire payload field' {
    { Invoke-TestClaimProposal -WithoutClaimId } | Should -Throw '*MissingClaimId*'
    $script:request.payload.Count | Should -Be 0
    $script:state.claims.Count | Should -Be 0
  }

  It 'rejects duplicate active claim ID even with unrelated task and disjoint scope' {
    Add-ActiveTestClaim -Id 'C-explicit'
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'rejects a second active claim created from the same request identity' {
    Add-ActiveTestClaim
    $script:state.claims[0].claimRequestId = 'R-claim'
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'rejects exact <Key> authority binding changes before proposing' -ForEach @(
    @{ Key = 'resourceId' }, @{ Key = 'generation' }, @{ Key = 'sprintId' },
    @{ Key = 'authorizationReference' }
  ) {
    $script:request[$Key] = if ($Key -ceq 'sprintId') { '0018' } else { ([string]$script:request[$Key]).ToUpperInvariant() }
    { Invoke-TestClaimProposal } | Should -Throw '*AuthorityConflict*'
    $script:state.claims.Count | Should -Be 0
  }

  It 'rejects wrong <Key> in the bound holder/session' -ForEach @(
    @{ Key = 'holderId' }, @{ Key = 'sessionId' }
  ) {
    $script:request.holder[$Key] += '-other'
    { Invoke-TestClaimProposal } | Should -Throw '*AuthorityConflict*'
  }

  It 'rejects wrong lineage and does not use a supplied coordinator name as a grant' {
    $script:context.lineageId = 'unrelated-lineage'
    { Invoke-TestClaimProposal } | Should -Throw '*AuthorityConflict*'
  }

  It 'compares Unicode identity scalars ordinally without normalization or ignorable-character folding' {
    $script:request.authorizationReference = [string][char]0xE9
    $script:context.authorizationReference = 'e' + [char]0x301
    { Invoke-TestClaimProposal } | Should -Throw '*AuthorityConflict*'
    $script:request.authorizationReference = $script:context.authorizationReference
    $script:request.category = 'Claim' + [char]0x200D
    { Invoke-TestClaimProposal } | Should -Throw '*InvalidInput*'
  }

  It 'requires ordinal original scope strings even when physical resolution could be the same' {
    $script:request.scope[0].path = 'src/caf' + [char]0xE9 + '.ps1'
    $script:context.requestScopeBindings[0].path = 'src/cafe' + [char]0x301 + '.ps1'
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'prioritizes an epoch mismatch over a simultaneously stale revision at this boundary' {
    $script:request.generation = 'epoch-retired'
    $script:request.expectedRevision = 'head-old'
    { Invoke-TestClaimProposal } | Should -Throw '*AuthorityConflict*'
  }

  It 'rejects stale request or context revision without rebasing' -ForEach @(
    @{ Side = 'Request' }, @{ Side = 'Context' }
  ) {
    if ($Side -ceq 'Request') { $script:request.expectedRevision = 'head-old' }
    else { $script:context.committedRevision = 'head-old' }
    { Invoke-TestClaimProposal } | Should -Throw '*RevisionConflict*'
    $script:state.committedRevision | Should -BeExactly 'head-A'
  }

  It 'rejects unknown exact task ID without allocating a task' {
    $script:request.taskId = '17.250'
    $script:context.taskId = '17.250'
    { Invoke-TestClaimProposal } | Should -Throw '*UnknownTask*'
    $script:context.existingTasks.Count | Should -Be 5
  }

  It 'rejects a context bound to another task' {
    $script:context.taskId = '17.26'
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'rejects same-task or caller-bound ancestor claims even when paths are disjoint' -ForEach @(
    @{ ActiveTask = '17.25'; RequestedTask = '17.25' },
    @{ ActiveTask = '17.25'; RequestedTask = '17.25.a' },
    @{ ActiveTask = '17.25.a'; RequestedTask = '17.25' }
  ) {
    Add-ActiveTestClaim -TaskId $ActiveTask
    $script:request.taskId = $RequestedTask
    $script:context.taskId = $RequestedTask
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'does not infer ancestry from an opaque task ID prefix' {
    Add-ActiveTestClaim -TaskId '17.2'
    $script:request.taskId = '17.20'
    $script:context.taskId = '17.20'
    (Invoke-TestClaimProposal).ProposedState.GetProperty('claims').GetArrayLength() | Should -Be 2
  }

  It 'rejects resolved exact, ancestor and descendant scope overlap' -ForEach @(
    @{ Segments = @('Synthetic', 'Utilities', 'src', 'Owned.ps1') },
    @{ Segments = @('Synthetic', 'Utilities', 'src') },
    @{ Segments = @('Synthetic', 'Utilities', 'src', 'Owned.ps1', 'child') }
  ) {
    Add-ActiveTestClaim -Segments $Segments
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'allows resolved sibling delimiter edges rather than lexical path prefix conflict' {
    $script:context.requestScopeBindings[0].segments = @('Synthetic', 'Utilities', 'src', 'A')
    Add-ActiveTestClaim -Segments @('Synthetic', 'Utilities', 'src', 'AB')
    (Invoke-TestClaimProposal).ProposedState.GetProperty('claims').GetArrayLength() | Should -Be 2
  }

  It 'recognizes alias overlap across different registered roots using global physical segments' {
    Add-ActiveTestClaim -RootId 'root-alias' -Path 'alias/Owned.ps1' -Segments @('Synthetic', 'Utilities', 'src', 'Owned.ps1')
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'uses explicit case policy <Policy> for resolved components' -ForEach @(
    @{ Policy = 'OrdinalIgnoreCase'; Conflicts = $true },
    @{ Policy = 'Ordinal'; Conflicts = $false }
  ) {
    $script:context.requestScopeBindings[0].comparison = $Policy
    Add-ActiveTestClaim -Segments @('Synthetic', 'Utilities', 'src', 'owned.ps1') -Comparison $Policy
    if ($Conflicts) { { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*' }
    else { (Invoke-TestClaimProposal).Stage | Should -BeExactly 'ProposedNotApplied' }
  }

  It 'rejects inconsistent comparison policy within the same physical namespace' {
    Add-ActiveTestClaim -Comparison 'Ordinal'
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'requires exact original path, registered root ID and registered root path binding' -ForEach @(
    @{ Field = 'path'; Value = 'src/owned.ps1' },
    @{ Field = 'registeredRootId'; Value = 'root-alias' },
    @{ Field = 'registeredRootPath'; Value = 'C:\Unrelated' }
  ) {
    $script:context.requestScopeBindings[0][$Field] = $Value
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'rejects missing, duplicate and extra active claim scope bindings' -ForEach @(
    @{ Variant = 'missing' }, @{ Variant = 'duplicate' }, @{ Variant = 'extra' }
  ) {
    Add-ActiveTestClaim
    switch ($Variant) {
      'missing' { $script:context.activeClaimScopeBindings = @() }
      'duplicate' { $script:context.activeClaimScopeBindings += $script:context.activeClaimScopeBindings[0] }
      'extra' { $script:context.activeClaimScopeBindings += [ordered]@{ claimId = 'C-extra'; scopeBindings = @(New-ScopeBinding) } }
    }
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'rejects missing or extra private context members rather than guessing defaults' -ForEach @(
    @{ Variant = 'missing' }, @{ Variant = 'extra' }
  ) {
    if ($Variant -ceq 'missing') { $script:context.Remove('coordinatorId') }
    else { $script:context['grant'] = $true }
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'rejects unresolved dot segments or missing resolved components' -ForEach @(
    @{ Segments = @() }, @{ Segments = @('Synthetic', '..', 'Owned.ps1') }
  ) {
    $script:context.requestScopeBindings[0].segments = $Segments
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'rejects self/cyclic or incomplete transitive task ancestry bindings' -ForEach @(
    @{ Variant = 'self' }, @{ Variant = 'cycle' }, @{ Variant = 'missing-ancestor' },
    @{ Variant = 'incomplete-transitive' }
  ) {
    switch ($Variant) {
      'self' { $script:context.existingTasks[0].ancestorTaskIds = @('17.25') }
      'cycle' { $script:context.existingTasks[0].ancestorTaskIds = @('17.25.a') }
      'missing-ancestor' { $script:context.existingTasks[0].ancestorTaskIds = @('17.999') }
      'incomplete-transitive' { $script:context.existingTasks[2].ancestorTaskIds = @('17.25.a') }
    }
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'does not grant through a recorded hold or recovery observation' -ForEach @(
    @{ Status = 'Held' }, @{ Status = 'NeedsRecovery' }
  ) {
    $script:state.mutationAdmission.status = $Status
    { Invoke-TestClaimProposal } | Should -Throw '*ResourceHeld*'
  }

  It 'holds a proposed transition when an incomplete preparation remains' -ForEach @(
    @{ Status = 'Prepared' }, @{ Status = 'NeedsRecovery' }
  ) {
    # Deliberately partial observation is sufficient to deny, never to admit.
    $script:state.preparedOperations = @([ordered]@{ status = $Status })
    { Invoke-TestClaimProposal } | Should -Throw '*ResourceHeld*'
  }

  It 'does not acquire an expired-looking claim or accept an expiry takeover context' {
    Add-ActiveTestClaim -Segments @('Synthetic', 'Utilities', 'src', 'Owned.ps1')
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
    $script:context['expiredHolders'] = @('Senior2')
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'refuses an old-epoch active claim rather than implicitly rebinding it' {
    Add-ActiveTestClaim
    $script:state.claims[0].generation = 'epoch-retired'
    { Invoke-TestClaimProposal } | Should -Throw '*AuthorityConflict*'
    $script:state.claims[0].generation | Should -BeExactly 'epoch-retired'
  }

  It 'releases only the matching active claim without completion or unrelated state changes' {
    Set-ReleaseTestCase
    Add-ActiveTestClaim -Id 'C-unrelated'
    $before = ConvertTo-ClaimElement $script:state
    $proposal = Invoke-TestClaimProposal
    $proposal.Category | Should -BeExactly 'Release'
    $proposal.Stage | Should -BeExactly 'ProposedNotApplied'
    $proposal.ProposedState.GetProperty('claims').GetArrayLength() | Should -Be 1
    $proposal.ProposedState.GetProperty('claims')[0].GetProperty('claimId').GetString() | Should -BeExactly 'C-unrelated'
    $script:state.claims.Count | Should -Be 2
    foreach ($property in $before.EnumerateObject()) {
      if ($property.Name -cne 'claims') {
        $proposal.ProposedState.GetProperty($property.Name).GetRawText() | Should -BeExactly $property.Value.GetRawText()
      }
    }
  }

  It 'rejects release of missing/already released claim under a new request' {
    Set-ReleaseTestCase
    $proposal = Invoke-TestClaimProposal
    $script:state = ConvertFrom-Json -InputObject $proposal.ProposedState.GetRawText() -AsHashtable
    $script:context.activeClaimScopeBindings = @()
    $script:request.requestId = 'R-new-release'
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'rejects wrong active holder/session/task for release' -ForEach @(
    @{ Field = 'holderId' }, @{ Field = 'sessionId' }, @{ Field = 'taskId' }
  ) {
    Set-ReleaseTestCase
    if ($Field -ceq 'taskId') { $script:state.claims[0].taskId = '17.26' }
    else { $script:state.claims[0].holder[$Field] += '-other' }
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'requires release scope strings and order to match active custody exactly' {
    Set-ReleaseTestCase
    $second = [ordered]@{ registeredRootId = 'root-u'; path = 'src/Other.ps1' }
    $script:state.claims[0].scope += $second
    $script:context.activeClaimScopeBindings[0].scopeBindings += (New-ScopeBinding -Path 'src/Other.ps1' -Segments @('Synthetic', 'Utilities', 'src', 'Other.ps1'))
    $script:request.scope = @($second, $script:request.scope[0])
    $script:context.requestScopeBindings = @(
      (New-ScopeBinding -Path 'src/Other.ps1' -Segments @('Synthetic', 'Utilities', 'src', 'Other.ps1')),
      (New-ScopeBinding)
    )
    { Invoke-TestClaimProposal } | Should -Throw '*ClaimConflict*'
  }

  It 'forbids private ClaimId on Release and refuses a new wire Claim payload field' {
    Set-ReleaseTestCase
    { Invoke-TestClaimProposal -ForceClaimId } | Should -Throw '*InvalidInput*'
    $script:request.category = 'Claim'
    $script:request.payload = [ordered]@{ claimId = 'invented-wire-field' }
    { Invoke-TestClaimProposal } | Should -Throw '*BindingConflict*'
  }

  It 'rejects unsupported category without a feature/parent status change' {
    $script:request.category = 'AcceptChange'
    { Invoke-TestClaimProposal } | Should -Throw '*InvalidInput*'
    $script:state.claims.Count | Should -Be 0
  }

  It 'preserves historical rejected JSON values and original request text without numeric coercion' {
    $script:state.requests = @([ordered]@{
      request = [ordered]@{ resourceId = 'board-S17'; requestId = 'historical-R'; unknownNumber = '__BIGINT__' }
      digest = '0' * 64
      originalRequestJson = '{"resourceId":"board-S17","requestId":"historical-R","unknownNumber":9223372036854775808123456789}'
      queueOrdinal = '999999999999999999999999999999'
      status = 'Rejected'
      terminalEvidence = [ordered]@{
        resourceId = 'board-S17'; requestId = 'historical-R'; digest = '0' * 64
        status = 'Rejected'; reason = 'InvalidRequest'
        receipt = [ordered]@{ reference = 'synthetic-rejected'; digest = '0' * 64 }
      }
    })
    $json = (ConvertTo-Json -InputObject $script:state -Depth 100 -Compress).Replace('"__BIGINT__"', '9223372036854775808123456789')
    $inputState = ConvertTo-ClaimElement $json -Raw
    $proposal = Update-CoordClaim -State $inputState -Request (ConvertTo-ClaimElement $script:request) -Context (ConvertTo-ClaimElement $script:context) -ClaimId 'C-explicit'
    $proposal.ProposedState.GetProperty('requests').GetRawText() | Should -BeExactly $inputState.GetProperty('requests').GetRawText()
    $proposal.ProposedState.GetProperty('requests')[0].GetProperty('request').GetProperty('unknownNumber').GetRawText() | Should -BeExactly '9223372036854775808123456789'
  }
}

