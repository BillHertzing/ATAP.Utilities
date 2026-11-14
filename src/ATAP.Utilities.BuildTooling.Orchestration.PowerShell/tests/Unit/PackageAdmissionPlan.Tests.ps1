#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Pure in-memory fixtures only: no files, no ProgramData, no host state. TestDrive is not needed.

BeforeDiscovery {
  $script:moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $loaded = @(Get-Module -Name $script:moduleName)
  if ($loaded.Count -eq 0) {
    $null = Import-Module -Name (Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.Orchestration.PowerShell.psd1') -Force -PassThru -ErrorAction Stop
  } elseif ($loaded.Count -ne 1) {
    throw 'Ambiguous PackageAdmissionPlan test fixture: exactly one loaded module identity is required.'
  }
}

InModuleScope -ModuleName 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell' {
Describe 'New-CoordPackageAdmissionPlan' -Tag 'Unit', 'PackageAdmissionPlan' {
  BeforeAll {
    $script:schemaBytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '..\..\schemas\state-v1.schema.json'))
    $script:schemaHash = Get-CoordHash $script:schemaBytes
    $script:sid = 'S-1-5-21-1-2-3-1001'
    $script:opId = '11111111-2222-3333-4444-555555555555'
    $script:when = '2026-11-13T12:00:00.0000000Z'
    $script:requestHash = ('a' * 64)
    $script:resultHash = ('b' * 64)
    $script:thumb = '3B5E16C03B5E16C03B5E16C03B5E16C03B5E16C0'

    function New-Fixture {
      $manifest = [ordered]@{}
      foreach ($slot in 'markdown', 'boardHtml', 'proceduralDetailsHtml', 'accomplishedHtml') {
        $manifest[$slot] = [ordered]@{ path = "C:/fixture/$slot.bin"; digest = ('0' * 64) }
      }
      $reference = [ordered]@{ reference = 'disposable-reference'; digest = ('0' * 64) }
      $state = [ordered]@{
        schemaVersion = 'Coordination-state-v1'; resourceId = 'fixture'; lineageId = 'lineage-fixture'
        registeredRoots = @([ordered]@{ registeredRootId = 'fixture'; path = 'C:/fixture' }); generation = 'epoch-before'
        committedRevision = 'head-1'; committedOutputManifest = $manifest; custodyEvidence = $reference
        compatibilityEvidence = $reference; admissionEvidence = @($reference)
        requests = @(); claims = @(); reservations = @(); preparedOperations = @(); commitReceipts = @()
        mutationAdmission = [ordered]@{ status = 'Admitted'; reason = 'Disposable'; observedOutputs = @() }
      }
      $oldPackage = [ordered]@{ moduleVersion = '0.1.16'; files = @([ordered]@{ path = 'schemas/state-v1.schema.json'; digest = $script:schemaHash }, [ordered]@{ path = 'old.psm1'; digest = ('c' * 64) }) }
      $witness = [ordered]@{
        schemaVersion = 'Coordination-custody-v1'; admissionMode = 'Established'; custodianSid = $script:sid
        resourceId = 'fixture'; lineageId = 'lineage-fixture'; generation = 'epoch-before'; sprintId = '0017'; coordinatorId = 'Coordinator'
        statePath = 'C:/fixture/state.json'; stateSha256 = ''; pendingWrite = $null; boardLockPath = 'C:/fixture/board.lock'
        actors = @([ordered]@{ holderId = 'Coordinator'; sessionId = 'c1'; windowsSid = $script:sid; role = 'Coordinator' })
        retiredActors = @(); authorizations = @(); existingTasks = @(); package = $oldPackage
        autoPackageAdmission = [ordered]@{
          enabled = $true; signer = $script:thumb; minVersion = '0.1.17'
          schemaHashes = [ordered]@{ state = $script:schemaHash; request = $script:requestHash; result = $script:resultHash }
          semanticRevision = 'sem-1'
        }
        future = [ordered]@{ text = 'preserved'; number = 1 }
      }
      $attestation = [ordered]@{
        kind = 'Coordination-package-attestation-v1'; moduleName = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
        moduleVersion = '0.1.17'; archiveSha256 = ('D' * 64); signerThumbprint = $script:thumb.ToLowerInvariant()
        stateSchemaSha256 = $script:schemaHash.ToUpperInvariant(); requestSchemaSha256 = $script:requestHash; resultSchemaSha256 = $script:resultHash
        coordinationSemanticRevision = 'sem-1'; buildId = 'build-1'; executionIds = @('exec-1'); createdUtc = '2026-11-13T11:00:00.0000000Z'
        finalProductionTestReceiptSha256 = ('e' * 64); tierReceiptSha256 = [ordered]@{ Production = ('f' * 64) }
        files = @([ordered]@{ path = 'schemas/state-v1.schema.json'; sha256 = $script:schemaHash.ToUpperInvariant(); size = 10 }, [ordered]@{ path = 'new.psm1'; sha256 = ('f' * 64); size = 20 })
      }
      @{ State = $state; Witness = $witness; Attestation = $attestation }
    }

    function Invoke-Plan($Fixture) {
      $stateBytes = ConvertTo-SuccessorPlanBytes $Fixture.State
      $Fixture.Witness.stateSha256 = Get-CoordHash $stateBytes
      $witnessBytes = ConvertTo-SuccessorPlanBytes $Fixture.Witness
      New-CoordPackageAdmissionPlan -StateBytes $stateBytes -WitnessBytes $witnessBytes -StateSchemaBytes $script:schemaBytes `
        -Attestation $Fixture.Attestation -ObservedSid $script:sid -OperationId $script:opId -AdmittedAtUtc $script:when
    }
    function Read-Members([byte[]]$Bytes) { Get-CoordMembers (Read-CoordJsonBytes $Bytes) }
  }

  It 'plans a package-only change: package and history change, everything else is byte-identical' {
    $fixture = New-Fixture
    $before = Read-Members (ConvertTo-SuccessorPlanBytes $fixture.Witness)
    $plan = Invoke-Plan $fixture
    $plan.Status | Should -Be 'PlannedOnly'
    $plan.StateChanged | Should -BeFalse
    $plan.GenerationChanged | Should -BeFalse
    $target = Read-Members $plan.TargetWitness
    foreach ($name in $before.Keys) {
      if ($name -in 'package', 'stateSha256') { continue }
      $target.Contains($name) | Should -BeTrue
      $target[$name].GetRawText() | Should -BeExactly $before[$name].GetRawText()
    }
    $newKeys = @($target.Keys | Where-Object { -not $before.Contains($_) })
    $newKeys | Should -Be @('history')
    (Read-CoordJsonBytes $plan.TargetWitness).GetProperty('package').GetProperty('moduleVersion').GetString() | Should -BeExactly '0.1.17'
    $history = (Read-CoordJsonBytes $plan.TargetWitness).GetProperty('history')
    $history.GetArrayLength() | Should -Be 1
    $history[0].GetProperty('fromVersion').GetString() | Should -BeExactly '0.1.16'
    $history[0].GetProperty('toVersion').GetString() | Should -BeExactly '0.1.17'
    $history[0].GetProperty('operationId').GetString() | Should -BeExactly $script:opId
    # custody inventory uses lowercase digests even when the attestation carried uppercase hex
    (Read-CoordJsonBytes $plan.TargetWitness).GetProperty('package').GetProperty('files')[0].GetProperty('digest').GetString() | Should -BeExactly $script:schemaHash
    $plan.Pairs.Before.State | Should -BeExactly $plan.Pairs.Target.State
    $plan.Pairs.Before.State | Should -BeExactly $plan.Pairs.Fenced.State
    $plan.Pairs.Target.Witness | Should -Not -BeExactly $plan.Pairs.Before.Witness
  }

  It 'is deterministic and ignores attestation key order' {
    $one = Invoke-Plan (New-Fixture)
    $reordered = New-Fixture
    $shuffled = [ordered]@{}
    foreach ($key in @($reordered.Attestation.Keys | Sort-Object -Descending)) { $shuffled[$key] = $reordered.Attestation[$key] }
    $reordered.Attestation = $shuffled
    $two = Invoke-Plan $reordered
    $two.Pairs.Target.Witness | Should -BeExactly $one.Pairs.Target.Witness
    $two.AttestationSha256 | Should -BeExactly $one.AttestationSha256
    (Get-CoordHash $two.FencedWitness) | Should -BeExactly (Get-CoordHash $one.FencedWitness)
  }

  It 'appends to an existing history rather than replacing it' {
    $fixture = New-Fixture
    $fixture.Witness.history = @([ordered]@{ kind = 'Earlier'; note = 'kept' })
    $history = (Read-CoordJsonBytes (Invoke-Plan $fixture).TargetWitness).GetProperty('history')
    $history.GetArrayLength() | Should -Be 2
    $history[0].GetProperty('kind').GetString() | Should -BeExactly 'Earlier'
    $history[1].GetProperty('kind').GetString() | Should -BeExactly 'PackageAdmission-v1'
  }

  It 'allows settled claims and reservations, and leaves them untouched' {
    $fixture = New-Fixture
    $scope = @([ordered]@{ registeredRootId = 'fixture'; path = 'a.md' })
    $fixture.State.claims = @([ordered]@{ claimId = 'cl1'; resourceId = 'fixture'; taskId = '17.1'; scope = $scope
        holder = [ordered]@{ holderId = 'Worker'; sessionId = 's1' }; generation = 'epoch-before'; claimRequestId = 'rq1' })
    $fixture.State.reservations = @([ordered]@{ reservationId = 'rs1'; resourceId = 'fixture'; requestId = 'rq2'; taskId = '17.2'
        scope = $scope; generation = 'epoch-before' })
    $plan = Invoke-Plan $fixture
    $plan.Status | Should -Be 'PlannedOnly'
    $plan.Pairs.Target.State | Should -BeExactly (Get-CoordHash (ConvertTo-SuccessorPlanBytes $fixture.State))
  }

  Context 'refusals' {
    It 'refuses when pendingWrite is non-null' {
      $fixture = New-Fixture
      $fixture.Witness.pendingWrite = [ordered]@{ kind = 'SuccessorCustody' }
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PendingWritePresent'
    }

    It 'refuses a Prepared operation' {
      Mock Test-Json { $true }
      $fixture = New-Fixture
      $fixture.State.preparedOperations = @([ordered]@{ operationId = 'op1'; status = 'Prepared' })
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'OperationInFlight'
    }

    It 'refuses a NeedsRecovery request' {
      Mock Test-Json { $true }
      $fixture = New-Fixture
      $fixture.State.requests = @([ordered]@{ status = 'NeedsRecovery' })
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'OperationInFlight'
    }

    It 'refuses when mutation admission is Held or NeedsRecovery' {
      foreach ($status in 'Held', 'NeedsRecovery') {
        $fixture = New-Fixture
        $fixture.State.mutationAdmission.status = $status
        { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'MutationNotAdmitted'
      }
    }
    It 'refuses when a schema hash differs' {
      foreach ($member in 'requestSchemaSha256', 'resultSchemaSha256') {
        $fixture = New-Fixture
        $fixture.Attestation[$member] = ('9' * 64)
        { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'SchemaHashMismatch'
      }
      $fixture = New-Fixture
      $fixture.Attestation.stateSchemaSha256 = ('9' * 64)
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'SchemaHashMismatch'
    }

    It 'refuses when the semantic revision differs' {
      $fixture = New-Fixture
      $fixture.Attestation.coordinationSemanticRevision = 'sem-2'
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'SemanticRevisionMismatch'
    }

    It 'refuses a downgrade' {
      $fixture = New-Fixture
      $fixture.Attestation.moduleVersion = '0.1.15'
      $fixture.Witness.autoPackageAdmission.minVersion = '0.1.10'
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PackageNotNewer'
    }

    It 'refuses a version equal to the current one' {
      $fixture = New-Fixture
      $fixture.Attestation.moduleVersion = '0.1.16'
      $fixture.Witness.autoPackageAdmission.minVersion = '0.1.10'
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PackageNotNewer'
    }

    It 'refuses a version below the policy minimum' {
      $fixture = New-Fixture
      $fixture.Witness.autoPackageAdmission.minVersion = '0.1.18'
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PackageBelowMinVersion'
    }

    It 'refuses when the policy is absent' {
      $fixture = New-Fixture
      $fixture.Witness.Remove('autoPackageAdmission')
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PackagePolicyAbsent'
    }

    It 'refuses when the policy is disabled' {
      $fixture = New-Fixture
      $fixture.Witness.autoPackageAdmission.enabled = $false
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PackagePolicyDisabled'
    }

    It 'refuses a signer that differs from the policy' {
      $fixture = New-Fixture
      $fixture.Attestation.signerThumbprint = ('A' * 40)
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'PackageSignerMismatch'
    }

    It 'refuses a malformed attestation' {
      $fixture = New-Fixture
      $fixture.Attestation.Remove('buildId')
      { Invoke-Plan $fixture } | Should -Throw -ExpectedMessage 'InvalidPackageAttestation'
    }
  }
}
}



