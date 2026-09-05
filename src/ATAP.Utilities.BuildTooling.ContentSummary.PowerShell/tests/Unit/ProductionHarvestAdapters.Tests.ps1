Describe 'ContentSummary production harvest adapters' -Tag 'Unit','Task15.60.c-f' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $manifestPath = Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psd1'
    Import-Module $manifestPath -Force
    $script:repositoryRoot = (Resolve-Path (Join-Path $script:moduleRoot '..\..')).Path
    $script:originUri = 'https://github.com/BillHertzing/ATAP.Utilities.git'
    $script:newInventory = {
      param([string]$Path)
      $inventory = [ordered]@{
        schemaVersion = 1
        inventoryId = '10000000-0000-0000-0000-000000000001'
        recordedAtUtc = '2026-09-05T12:00:00.0000000+00:00'
        repositories = @([ordered]@{
          repositoryId = '10000000-0000-0000-0000-000000000002'
          repositoryRootRegistrationId = '10000000-0000-0000-0000-000000000003'
          canonicalRepositoryName = 'ATAP.Utilities'
          originUri = $script:originUri
          originEvidence = [ordered]@{ kind='git-remote'; remoteName='origin'; observedUri=$script:originUri; observedAtUtc='2026-09-05T12:00:00.0000000+00:00' }
          canonicalRoot = $script:repositoryRoot
          rootKindCode = 'sprint'
          organizationId = '10000000-0000-0000-0000-000000000004'
          classificationPolicyId = '10000000-0000-0000-0000-000000000005'
          principalId = '10000000-0000-0000-0000-000000000006'
          evidenceEntityId = '10000000-0000-0000-0000-000000000007'
          recordedAtUtc = '2026-09-05T12:00:00.0000000+00:00'
          authorizations = @([ordered]@{
            authorizationId = '10000000-0000-0000-0000-000000000008'
            databasePrincipalName = 'ATAPContentSummaryMcpReader'
            instanceCode = 'exp'
            sourceReference = 'Sprint0015/Task15.60/ratified-inventory'
            recordedAtUtc = '2026-09-05T12:00:00.0000000+00:00'
          })
        })
      }
      [IO.File]::WriteAllText($Path, ($inventory | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
      (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }

  It 'exports the minimal production surface at immutable version 0.1.6' {
    (Get-Module ATAP.Utilities.BuildTooling.ContentSummary.PowerShell).Version.ToString() | Should -Be '0.1.6'
    foreach ($name in @('New-ContentSummarySqlAdapterSet','Read-ContentSummaryRepositoryInventory','Invoke-ContentSummaryRepositoryInventory','New-ContentSummaryDeterministicSafeSummaryGenerator')) {
      Get-Command $name -Module ATAP.Utilities.BuildTooling.ContentSummary.PowerShell | Should -Not -BeNullOrEmpty
    }
  }

  It 'derives the same Unicode-safe bounded output only from safe input' {
    $generator = New-ContentSummaryDeterministicSafeSummaryGenerator -MaximumCharacters 4
    $context = [pscustomobject]@{repositoryId='id';repoRelativePath='a.md';sourceArtifactVersionId='version';byteSha256='a';normalizedContentSha256='b';classificationCode='admitted'}
    $first = & $generator -SafeContent "  ab😀cd  " -Context $context
    $second = & $generator -SafeContent "  ab😀cd  " -Context $context
    $first.SafeSummaryText | Should -Be 'ab😀c'
    $first.SafeSummaryText | Should -BeExactly $second.SafeSummaryText
    $first.SafeLocator | Should -BeNullOrEmpty
  }

  It 'fails closed instead of fabricating empty summary content' {
    $generator = New-ContentSummaryDeterministicSafeSummaryGenerator
    $context = [pscustomobject]@{repositoryId='id';repoRelativePath='a.md';sourceArtifactVersionId='version';byteSha256='a';normalizedContentSha256='b';classificationCode='admitted'}
    { & $generator -SafeContent '  ' -Context $context } | Should -Throw '*CS-SUMMARY-001*'
  }

  It 'validates approved inventory bytes and preserves caller identities' {
    $path = Join-Path $TestDrive 'inventory.json'
    $sha = & $script:newInventory $path
    $actual = Read-ContentSummaryRepositoryInventory -Path $path -ExpectedSha256 $sha
    $actual.InventorySha256 | Should -BeExactly $sha
    $actual.Repositories[0].repositoryId | Should -BeExactly '10000000-0000-0000-0000-000000000002'
  }

  It 'rejects changed inventory bytes before parsing them' {
    $path = Join-Path $TestDrive 'inventory-tampered.json'
    $sha = & $script:newInventory $path
    [IO.File]::AppendAllText($path, ' ')
    { Read-ContentSummaryRepositoryInventory -Path $path -ExpectedSha256 $sha } | Should -Throw '*approved SHA-256*'
  }

  It 'rejects fabricated empty durable identities' {
    $path = Join-Path $TestDrive 'inventory-empty-id.json'
    $sha = & $script:newInventory $path
    $content = [IO.File]::ReadAllText($path).Replace('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000')
    [IO.File]::WriteAllText($path,$content,[Text.UTF8Encoding]::new($false))
    $sha = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
    { Read-ContentSummaryRepositoryInventory -Path $path -ExpectedSha256 $sha } | Should -Throw '*non-empty lowercase D-format GUID*'
  }

  It 'rejects credential-bearing origin evidence' {
    $path = Join-Path $TestDrive 'inventory-origin.json'
    $sha = & $script:newInventory $path
    $content = [IO.File]::ReadAllText($path).Replace($script:originUri,'https://user:secret@github.com/BillHertzing/ATAP.Utilities.git')
    [IO.File]::WriteAllText($path,$content,[Text.UTF8Encoding]::new($false))
    $sha = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
    { Read-ContentSummaryRepositoryInventory -Path $path -ExpectedSha256 $sha } | Should -Throw '*credential-free*'
  }

  It 'plans inventory actions under WhatIf without invoking adapters' {
    $path = Join-Path $TestDrive 'inventory-whatif.json'
    $sha = & $script:newInventory $path
    $adapterSet = [pscustomobject][ordered]@{
      SchemaVersion=1; Capture={throw 'not expected'}; ProvisionRepository={throw 'not expected'};
      AssignContentSummaryVersionTag={throw 'not expected'}; AuthorizeRepository={throw 'not expected'}
    }
    $result = Invoke-ContentSummaryRepositoryInventory -Path $path -ExpectedSha256 $sha -AdapterSet $adapterSet -WhatIf
    $result.Status | Should -Be 'WhatIf'
    $result.RepositoryResultCount | Should -Be 0
    $result.AuthorizationResultCount | Should -Be 0
    $result.PlannedRepositoryCount | Should -Be 1
    $result.PlannedAuthorizationCount | Should -Be 1
  }

  It 'binds only the frozen controlled procedures and no direct DML' {
    $adapterText = Get-Content -Raw -LiteralPath (Join-Path $script:moduleRoot 'public\New-ContentSummarySqlAdapterSet.ps1')
    foreach ($procedure in @('CaptureContentSummaryObservationV1','ProvisionContentSummaryRepositoryV1','AssignContentSummaryVersionTagV1','AuthorizeContentSummaryDatabasePrincipalRepositoryV1')) {
      $adapterText | Should -Match ([regex]::Escape($procedure))
    }
    $adapterText | Should -Not -Match '(?im)\b(INSERT|UPDATE|DELETE|MERGE)\b'
  }
}

Describe 'ContentSummary private SQL conversion contracts' -Tag 'Unit','Task15.60.c-f' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psd1') -Force
    $script:module = Get-Module ATAP.Utilities.BuildTooling.ContentSummary.PowerShell
  }

  It 'builds the exact frozen ContentSummaryDependencyInput TVP columns' {
    $dependency = [pscustomobject][ordered]@{DependencyOrdinal=0;DependencyKindCode='source-artifact-version';SourceArtifactVersionId=[guid]'20000000-0000-0000-0000-000000000001';ExternalReferenceKindCode=$null;ExternalReferenceSha256=$null;EvidenceEntityId=[guid]'20000000-0000-0000-0000-000000000002'}
    $table = & $script:module { param($rows) ConvertTo-ContentSummaryDependencyDataTable -Dependencies $rows } @($dependency)
    @($table.Columns.ColumnName) -join ',' | Should -BeExactly 'DependencyOrdinal,DependencyKindCode,SourceArtifactVersionId,ExternalReferenceKindCode,ExternalReferenceSha256,EvidenceEntityId'
    $table.Rows.Count | Should -Be 1
  }

  It 'converts UTC DateTimeOffset values to DateTime2-compatible UTC DateTime values' {
    $values=[ordered]@{AuthorizationId=[guid]'20000000-0000-0000-0000-000000000003';DatabasePrincipalName='ATAPContentSummaryMcpReader';InstanceCode='exp';RepositoryId=[guid]'20000000-0000-0000-0000-000000000004';SourceReference='evidence';RecordedAtUtc=[datetimeoffset]'2026-09-05T12:00:00+00:00'}
    $definitions = & $script:module { param($inputValues) ConvertTo-ContentSummarySqlParameterDefinitions -Contract AuthorizeRepository -Values $inputValues } $values
    $definitions.RecordedAtUtc.Value.GetType().FullName | Should -BeExactly 'System.DateTime'
    $definitions.RecordedAtUtc.Value.Kind | Should -Be ([DateTimeKind]::Utc)
  }
}

Describe 'ContentSummary adapter review corrections' -Tag 'Unit','Task15.60.c-f' {
  BeforeAll {
    $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psd1') -Force
    $script:module = Get-Module ATAP.Utilities.BuildTooling.ContentSummary.PowerShell
  }

  It 'rejects malformed UTF-8 bytes before JSON validation' {
    $path = Join-Path $TestDrive 'malformed-utf8.json'
    $bytes = [byte[]](0x7b,0x22,0x78,0x22,0x3a,0x22,0xc3,0x28,0x22,0x7d)
    [IO.File]::WriteAllBytes($path,$bytes)
    $sha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    { Read-ContentSummaryRepositoryInventory -Path $path -ExpectedSha256 $sha } | Should -Throw '*not well-formed UTF-8 JSON*'
  }

  It 'rejects every wrong nonempty Capture identity on replay' {
    $expected = [ordered]@{
      IdempotencyKey = [guid]'30000000-0000-0000-0000-000000000001'
      SourceArtifactId = [guid]'30000000-0000-0000-0000-000000000002'
      SourceArtifactVersionId = [guid]'30000000-0000-0000-0000-000000000003'
      ContentSummaryId = [guid]'30000000-0000-0000-0000-000000000004'
      ContentSummaryVersionId = [guid]'30000000-0000-0000-0000-000000000005'
    }
    foreach ($propertyName in $expected.Keys) {
      $result = [pscustomobject][ordered]@{
        ReplayStatus='Replayed';IdempotencyKey=$expected.IdempotencyKey;SourceArtifactId=$expected.SourceArtifactId;
        SourceArtifactVersionId=$expected.SourceArtifactVersionId;ContentSummaryId=$expected.ContentSummaryId;
        ContentSummaryVersionId=$expected.ContentSummaryVersionId;SourceArtifactVersionSequence=1L;
        ContentSummaryVersionSequence=1L;LifecycleCode='summarized';ErrorCode=$null
      }
      $result.$propertyName = [guid]'3fffffff-ffff-ffff-ffff-ffffffffffff'
      { & $script:module {
          param($actual,$identities)
          Assert-ContentSummaryCaptureAcknowledgement -Result $actual -IdempotencyKey $identities.IdempotencyKey -SourceArtifactId $identities.SourceArtifactId -SourceArtifactVersionId $identities.SourceArtifactVersionId -ContentSummaryId $identities.ContentSummaryId -ContentSummaryVersionId $identities.ContentSummaryVersionId
        } $result $expected } | Should -Throw '*capture acknowledgement identities do not match*'
    }
  }
}
