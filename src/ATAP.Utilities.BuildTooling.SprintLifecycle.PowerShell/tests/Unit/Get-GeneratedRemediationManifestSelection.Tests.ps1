BeforeAll {
  . "$PSScriptRoot/../../private/Get-GeneratedRemediationManifestSelection.ps1"
  function Get-SelectionFixture {
    $hash = 'A' * 64
    $stable = 'C:/Repos/Repo'
    $sprint = 'C:/Repos/Repo-wt-1-Sprint-0016-work-items'
    $source = [ordered]@{ repositoryIdentity = 'repo'; root = $stable; relativePath = '_generated/Sprint0015/a.txt'; bytes = 3; sha256 = $hash; tracked = $true; streams = @(); streamInventoryComplete = $true }
    $candidate = [ordered]@{ repositoryIdentity = 'repo'; root = $sprint; relativePath = '_generated/Sprint0015/a.txt'; bytes = 3; sha256 = $hash; tracked = $false; streams = @(); streamInventoryComplete = $true }
    [ordered]@{
      schemaVersion = 1; runId = 'fixture'; capturedUtc = '2026-10-17T12:00:00Z'; host = 'fixture-host'
      operation = 'SprintDuplicateSelection'; approved = $false
      repository = [ordered]@{ identity = 'repo'; commonGitDir = 'C:/Repos/Repo/.git'; stableRoot = $stable; sprintRoot = $sprint }
      worktrees = @(
        [ordered]@{ role = 'Stable'; root = $stable; head = 'a' * 40; indexSHA256 = $hash; stagedSHA256 = $hash; unstagedSHA256 = $hash; untrackedSHA256 = $hash; inventoryComplete = $true },
        [ordered]@{ role = 'Sprint'; root = $sprint; head = 'b' * 40; indexSHA256 = $hash; stagedSHA256 = $hash; unstagedSHA256 = $hash; untrackedSHA256 = $hash; inventoryComplete = $true }
      )
      baseline = [ordered]@{ origin = 'VerifiedArchive'; manifestSHA256 = $hash; custodyReceiptSHA256 = $hash }
      rows = @([ordered]@{ id = 'row1'; kind = 'File'; baselineRowSHA256 = $hash; source = $source; candidate = $candidate; pathClassification = 'Regular'; protectionReasons = @(); proposedAction = 'Preserve'; approved = $false })
    }
  }
  function Invoke-SelectionFixture {
    param($Fixture)
    Get-GeneratedRemediationManifestSelection -ManifestJson ($Fixture | ConvertTo-Json -Depth 20 -Compress) -CurrentSprintNumber 16
  }
}

Describe 'Pure generated remediation manifest selection' {
  It 'returns one unapproved result and recomputes the action without changing raw input' {
    $raw = Get-SelectionFixture | ConvertTo-Json -Depth 20 -Compress
    $before = $raw
    $result = @(Get-GeneratedRemediationManifestSelection $raw -CurrentSprintNumber 16)
    $result.Count | Should -Be 1
    $result[0].Valid | Should -BeTrue
    $result[0].Rows[0].Action | Should -Be 'EligibleCandidate'
    $result[0].Approved | Should -BeFalse
    $result[0].Rows[0].Approved | Should -BeFalse
    $result[0].Verification | Should -Match 'Snapshot-only'
    $raw | Should -BeExactly $before
  }
  It 'accepts a complete empty census and zero-byte equality' {
    $f = Get-SelectionFixture
    $f.rows[0].source.bytes = 0; $f.rows[0].candidate.bytes = 0
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'EligibleCandidate'
    $f.rows = @()
    $r = Invoke-SelectionFixture $f
    $r.Valid | Should -BeTrue
    @($r.Rows).Count | Should -Be 0
  }
  It 'preserves equal content at a different path or repository and differing bytes' {
    foreach ($variant in @('path', 'repository', 'hash', 'size')) {
      $f = Get-SelectionFixture
      switch ($variant) {
        path { $f.rows[0].candidate.relativePath = '_generated/Sprint0015/b.txt' }
        repository { $f.rows[0].candidate.repositoryIdentity = 'another-repo' }
        hash { $f.rows[0].candidate.sha256 = 'B' * 64 }
        size { $f.rows[0].candidate.bytes = 4 }
      }
      $r = Invoke-SelectionFixture $f
      $r.Valid | Should -BeTrue
      $r.Rows[0].Action | Should -Be 'Preserve'
    }
  }
  It 'protects every nested current/future sprint segment and explicit reasons before equality' {
    foreach ($path in @('_generated/Sprint0015/Sprint0016/a.txt', '_generated/Sprint0015/SprintEnd0017/a.txt', '_generated/sprint-end-0016/a.txt', '_generated/Sprint0015/Sprint0016SettingsLinkFollowup/a.txt')) {
      $f = Get-SelectionFixture
      $f.rows[0].source.relativePath = $path; $f.rows[0].candidate.relativePath = $path
      (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'Hold'
    }
    $f = Get-SelectionFixture
    $f.rows[0].protectionReasons = @('Future input', 'Index drift')
    $f.rows[0].candidate.sha256 = 'B' * 64
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'Hold'
  }
  It 'holds redirecting links, nested repos, unknown paths and incomplete ADS' {
    foreach ($classification in @('RedirectingLink', 'NestedRepository', 'Unknown')) {
      $f = Get-SelectionFixture; $f.rows[0].pathClassification = $classification
      (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'Hold'
    }
    $f = Get-SelectionFixture; $f.rows[0].candidate.streamInventoryComplete = $false
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'Hold'
  }
  It 'allows readable placeholder records and recorded stream differences only with supplied custody' {
    $f = Get-SelectionFixture
    $f.rows[0].pathClassification = 'ReadableCloudPlaceholder'
    $f.rows[0].candidate.streams = @([ordered]@{ name = 'com.dropbox.attrs'; bytes = 2; sha256 = 'B' * 64; archiveMember = '__ntfs_streams__/row1/stream'; restoreVerified = $true })
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'EligibleCandidate'
    $f.rows[0].candidate.streams[0].restoreVerified = $false
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'Hold'
  }
  It 'rejects malformed, null, empty and non-object JSON with no eligible rows' {
    foreach ($raw in @($null, '', ' ', '{', 'null', '[]', 'true', '42', '{}')) {
      $r = Get-GeneratedRemediationManifestSelection -ManifestJson $raw -CurrentSprintNumber 16
      $r.Valid | Should -BeFalse
      @($r.Rows).Count | Should -Be 0
      @($r.Errors).Count | Should -BeGreaterThan 0
    }
  }
  It 'rejects raw duplicate and case-alias properties before conversion, including nested properties' {
    $raw = Get-SelectionFixture | ConvertTo-Json -Depth 20 -Compress
    foreach ($bad in @($raw.Replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1'), $raw.Replace('"bytes":3', '"bytes":3,"Bytes":3'), $raw.Replace('"id":"row1"', '"id":"row1","id":"row2"'))) {
      $r = Get-GeneratedRemediationManifestSelection -ManifestJson $bad -CurrentSprintNumber 16
      $r.Valid | Should -BeFalse
      @($r.Rows).Count | Should -Be 0
      ($r.Errors -join ' ') | Should -Match 'duplicate|alias'
    }
  }
  It 'rejects numeric and boolean coercion, null fields, unsupported modes and unknown fields' {
    $raw = Get-SelectionFixture | ConvertTo-Json -Depth 20 -Compress
    foreach ($replacement in @('"3"', '3.0', '3e0', '-1', 'null', 'true', '9223372036854775808')) {
      (Get-GeneratedRemediationManifestSelection -ManifestJson ($raw.Replace('"bytes":3', '"bytes":' + $replacement)) -CurrentSprintNumber 16).Valid | Should -BeFalse
    }
    foreach ($variant in @('extra', 'missing', 'operation', 'kind', 'enum', 'approval', 'bool', 'hash', 'date')) {
      $f = Get-SelectionFixture
      switch ($variant) {
        extra { $f.unknown = 1 }
        missing { $f.Remove('baseline') }
        operation { $f.operation = 'StableRemovalPlanning' }
        kind { $f.rows[0].kind = 'Directory' }
        enum { $f.rows[0].proposedAction = 'Delete' }
        approval { $f.approved = $true }
        bool { $f.rows[0].approved = 'false' }
        hash { $f.baseline.manifestSHA256 = 'bad' }
        date { $f.capturedUtc = '2026-99-99T00:00:00Z' }
      }
      $r = Invoke-SelectionFixture $f
      $r.Valid | Should -BeFalse
      @($r.Rows).Count | Should -Be 0
    }
  }
  It 'rejects role collisions, root binding errors and failed inventories' {
    foreach ($variant in @('role', 'root', 'nested', 'inventory', 'sourceRoot', 'common')) {
      $f = Get-SelectionFixture
      switch ($variant) {
        role { $f.worktrees[1].role = 'Stable' }
        root { $f.worktrees[1].root = 'C:/Other' }
        nested { $f.repository.sprintRoot = 'C:/Repos/Repo/nested' }
        inventory { $f.worktrees[0].inventoryComplete = $false }
        sourceRoot { $f.rows[0].source.root = 'C:/Other' }
        common { $f.repository.commonGitDir = 'C:/Repos/../Other/.git' }
      }
      (Invoke-SelectionFixture $f).Valid | Should -BeFalse
    }
  }
  It 'rejects unsafe paths and Windows alias collisions' {
    foreach ($path in @('_generated/../outside', '_generated/a:stream', 'C:/outside', '//server/share/a', '_generated/NUL.txt', '_generated/a.', '_generated//a', '_generated/a/./b', '_generated/COM1', '_generated/aux/x')) {
      $f = Get-SelectionFixture; $f.rows[0].candidate.relativePath = $path
      (Invoke-SelectionFixture $f).Valid | Should -BeFalse
    }
    $f = Get-SelectionFixture; $f.rows[0].candidate.relativePath = '_generated/Sprint0015/A.txt'
    (Invoke-SelectionFixture $f).Valid | Should -BeFalse
    $f = Get-SelectionFixture; $f.rows += $f.rows[0]
    $r = Invoke-SelectionFixture $f
    $r.Valid | Should -BeFalse
    @($r.Rows).Count | Should -Be 0
  }
  It 'invalidates earlier eligible rows when a later row is invalid' {
    $f = Get-SelectionFixture
    $second = (Get-SelectionFixture).rows[0]
    $second.id = 'row2'; $second.source.relativePath = '_generated/b.txt'; $second.candidate.relativePath = '_generated/../b.txt'
    $f.rows += $second
    $r = Invoke-SelectionFixture $f
    $r.Valid | Should -BeFalse
    @($r.Rows).Count | Should -Be 0
  }
  It 'accepts literal Unicode filenames and rejects missing explicit protection context' {
    $f = Get-SelectionFixture
    $f.rows[0].source.relativePath = ('_generated/' + [char]0x96ea + '.txt'); $f.rows[0].candidate.relativePath = ('_generated/' + [char]0x96ea + '.txt')
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'EligibleCandidate'
    (Get-GeneratedRemediationManifestSelection -ManifestJson ($f | ConvertTo-Json -Depth 20)).Valid | Should -BeFalse
  }
  It 'rejects stream aliases and unsafe archive mappings without emitting eligible rows' {
    foreach ($variant in @('name', 'member', 'duplicate', 'missingHash')) {
      $f = Get-SelectionFixture
      $stream = [ordered]@{ name = 'metadata'; bytes = 0; sha256 = 'A' * 64; archiveMember = '__ntfs_streams__/a'; restoreVerified = $true }
      $f.rows[0].candidate.streams = @($stream)
      switch ($variant) {
        name { $stream.name = 'x:stream' }
        member { $stream.archiveMember = '../outside' }
        duplicate { $f.rows[0].candidate.streams += $stream }
        missingHash { $stream.Remove('sha256') }
      }
      $r = @(Invoke-SelectionFixture $f)
      $r.Count | Should -Be 1
      $r[0].Valid | Should -BeFalse
      @($r[0].Rows).Count | Should -Be 0
    }
  }
  It 'holds obvious Git metadata paths even when the supplied classification says regular' {
    $f = Get-SelectionFixture
    $f.rows[0].source.relativePath = '_generated/fixture/.git/config'
    $f.rows[0].candidate.relativePath = '_generated/fixture/.git/config'
    (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'Hold'
  }
  It 'does not treat raw escaping or case variants as separate JSON property names' {
    $raw = Get-SelectionFixture | ConvertTo-Json -Depth 20 -Compress
    $raw = $raw.Replace('"id":"row1"', '"id":"row1","\u0069d":"row1"')
    (Get-GeneratedRemediationManifestSelection $raw -CurrentSprintNumber 16).Valid | Should -BeFalse
  }
  It 'returns identical serialized results across calls for the same snapshot' {
    $raw = Get-SelectionFixture | ConvertTo-Json -Depth 20 -Compress
    $first = Get-GeneratedRemediationManifestSelection $raw -CurrentSprintNumber 16 | ConvertTo-Json -Depth 10 -Compress
    $second = Get-GeneratedRemediationManifestSelection $raw -CurrentSprintNumber 16 | ConvertTo-Json -Depth 10 -Compress
    $second | Should -BeExactly $first
  }
  It 'protects complete variable-width sprint numbers without truncation' {
    foreach ($segment in @('Sprint16', 'Sprint00016', 'Sprint17', 'Sprint0000017', 'SprintEnd16', 'sprint_end_00016', 'sprint-end-17', 'Sprint16000', 'Sprint16Settings', 'Sprint9999999999999999999999999999', 'Sprint1e6', 'Sprint1.6')) {
      $f = Get-SelectionFixture
      $path = "_generated/Sprint0015/$segment/a.txt"
      $f.rows[0].source.relativePath = $path; $f.rows[0].candidate.relativePath = $path
      $r = Invoke-SelectionFixture $f
      $r.Valid | Should -BeTrue
      $r.Rows[0].Action | Should -Be 'Hold'
    }
    foreach ($segment in @('Sprint15', 'Sprint00015', 'SprintEnd000015', 'sprint_end_1')) {
      $f = Get-SelectionFixture
      $path = "_generated/$segment/a.txt"
      $f.rows[0].source.relativePath = $path; $f.rows[0].candidate.relativePath = $path
      (Invoke-SelectionFixture $f).Rows[0].Action | Should -Be 'EligibleCandidate'
    }
  }
  It 'rejects mixed separators on either or both sides and archive members' {
    foreach ($side in @('source', 'candidate', 'both')) {
      $f = Get-SelectionFixture
      if ($side -in @('source', 'both')) { $f.rows[0].source.relativePath = '_generated/Sprint0015/child\a.txt' }
      if ($side -in @('candidate', 'both')) { $f.rows[0].candidate.relativePath = '_generated/Sprint0015/child\a.txt' }
      $r = Invoke-SelectionFixture $f
      $r.Valid | Should -BeFalse
      @($r.Rows).Count | Should -Be 0
    }
    $f = Get-SelectionFixture
    $f.rows[0].candidate.streams = @([ordered]@{ name = 'metadata'; bytes = 0; sha256 = 'A' * 64; archiveMember = '__ntfs_streams__/child\a'; restoreVerified = $true })
    (Invoke-SelectionFixture $f).Valid | Should -BeFalse
    $f = Get-SelectionFixture
    $second = (Get-SelectionFixture).rows[0]; $second.id = 'row2'
    $second.source.relativePath = '_generated\Sprint0015\a.txt'
    $second.candidate.relativePath = '_generated\Sprint0015\a.txt'
    $f.rows += $second
    $r = Invoke-SelectionFixture $f
    $r.Valid | Should -BeFalse
    @($r.Rows).Count | Should -Be 0
  }
}
