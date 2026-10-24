BeforeAll {
  $script:moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  foreach ($helper in @('Get-SprintEndActiveWorkspaceRoot', 'Invoke-SprintEndNativeCommand', 'Get-SprintWorktreeRecoveryState', 'Remove-SprintWorktreeResidual', 'Remove-SprintWorktreeRecoveryMetadata', 'Complete-SprintWorktreeNativeRemoval')) {
    . (Join-Path $script:moduleRoot "private/$helper.ps1")
  }
  . (Join-Path $script:moduleRoot 'public/Remove-SprintWorktreeSafely.ps1')
  $script:fixtureBase = Join-Path ([IO.Path]::GetFullPath((Join-Path $script:moduleRoot '../..'))) ('_generated/NativeMetadataCleanup/' + [guid]::NewGuid().ToString('N'))
  function New-NativeCleanupFixture {
    $root = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
    $owner = Join-Path $root 'owner'
    $target = Join-Path $root 'target'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    & git init --quiet $owner
    & git -C $owner -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty --quiet -m fixture
    & git -C $owner worktree add --quiet --detach $target HEAD
    if ($LASTEXITCODE) { throw 'Fixture initialization failed.' }
    $script:admin = Join-Path $owner '.git/worktrees/target'
    return @{ RepositoryPath=$owner; WorktreePath=$target; ReceiptPath=(Join-Path $root 'receipt.json'); Confirm=$false }
  }
  $script:nativeImplementation = ${function:Invoke-SprintEndNativeCommand}
}
Describe 'Exact native metadata cleanup recovery' -Tag Integration {
  BeforeEach {
    $script:afterNative = {}
    $script:nativeMessage = "error: failed to delete '.git/worktrees/target': Permission denied"
    Mock Get-SprintEndActiveWorkspaceRoot { @() }
    Mock Invoke-SprintEndNativeCommand {
      param($FilePath, $ArgumentList, $AllowNonZeroExitCode)
      if ($FilePath -eq 'git' -and $ArgumentList[2] -eq 'worktree' -and $ArgumentList[3] -eq 'remove') {
        foreach ($entry in @(Get-ChildItem -LiteralPath $script:admin -Force)) {
          if ($entry.LinkType) { throw 'Unexpected fixture link.' }
          if ($entry.PSIsContainer) {
            foreach ($file in @(Get-ChildItem -LiteralPath $entry.FullName -Force)) {
              if ($file.PSIsContainer -or $file.LinkType) { throw 'Unexpected nested fixture metadata.' }
              [IO.File]::Delete($file.FullName)
            }
            [IO.Directory]::Delete($entry.FullName, $false)
          } else { [IO.File]::Delete($entry.FullName) }
        }
        [IO.File]::Delete((Join-Path $ArgumentList[4] '.git'))
        $native = [pscustomobject]@{ FilePath=$FilePath; ArgumentList=$ArgumentList; Succeeded=$false; ExitCode=255; Output=@($script:nativeMessage) }
        & $script:afterNative
        return $native
      }
      & $script:nativeImplementation -FilePath $FilePath -ArgumentList $ArgumentList -AllowNonZeroExitCode:$AllowNonZeroExitCode
    }
  }
  It 'recovers the captured Git255 empty-slot failure shape without repeating native removal and validates resume' {
    $fixture = New-NativeCleanupFixture
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeTrue -Because ($result.Failures -join '; ')
    $receipt = Get-Content $fixture.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.NativeAttempts.Count | Should -Be 1
    $receipt.NativeAttempts[0].Result.ExitCode | Should -Be 255
    $receipt.NativeAttempts[0].Result.Succeeded | Should -BeFalse
    $receipt.NativeAttempts[0].MetadataCleanup.AdministrativePath | Should -Be $script:admin
    Test-Path $script:admin | Should -BeFalse
    (Remove-SprintWorktreeSafely @fixture).Ok | Should -BeTrue
    Should -Invoke Invoke-SprintEndNativeCommand -Times 1 -Exactly -ParameterFilter { $ArgumentList[2] -eq 'worktree' -and $ArgumentList[3] -eq 'remove' }
  }
  It 'bounds persistent delete-sharing denial and retains the failed native receipt' {
    $fixture = New-NativeCleanupFixture
    Mock Invoke-SprintWorktreeNativeDirectoryDelete { throw [UnauthorizedAccessException]::new('Controlled Windows access denial.') }
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    $receipt = Get-Content $fixture.ReceiptPath -Raw | ConvertFrom-Json
    $receipt.Deregistered | Should -BeFalse
    @($receipt.Events | Where-Object Event -eq BeforeNativeMetadataCleanup).Count | Should -Be 6
    $receipt.NativeAttempts.Count | Should -Be 1
    Test-Path $script:admin | Should -BeTrue
    Should -Invoke Invoke-SprintWorktreeNativeDirectoryDelete -Times 6 -Exactly
  }
  It 'retries only empty-slot deletion after transient access denial' {
    $fixture = New-NativeCleanupFixture
    $script:deleteCalls = 0
    Mock Invoke-SprintWorktreeNativeDirectoryDelete {
      param($LiteralPath)
      $script:deleteCalls++
      if ($script:deleteCalls -lt 3) { throw [UnauthorizedAccessException]::new('Controlled Windows access denial.') }
      [IO.Directory]::Delete($LiteralPath, $false)
    }
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeTrue -Because ($result.Failures -join '; ')
    Should -Invoke Invoke-SprintWorktreeNativeDirectoryDelete -Times 3 -Exactly
    Should -Invoke Invoke-SprintEndNativeCommand -Times 1 -Exactly -ParameterFilter { $ArgumentList[2] -eq 'worktree' -and $ArgumentList[3] -eq 'remove' }
  }
  It 'refuses a slot populated after native failure' {
    $fixture = New-NativeCleanupFixture
    $script:afterNative = { Set-Content -LiteralPath (Join-Path $script:admin 'unexpected') -Value 'retain' }
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'must be empty'
    Test-Path (Join-Path $script:admin 'unexpected') | Should -BeTrue
  }
  It 'refuses a replacement junction and preserves its target' {
    $fixture = New-NativeCleanupFixture
    $script:replacement = Join-Path (Split-Path $fixture.RepositoryPath) 'replacement'
    New-Item -ItemType Directory $script:replacement | Out-Null
    Set-Content (Join-Path $script:replacement 'retain') 'retain'
    $script:afterNative = {
      [IO.Directory]::Delete($script:admin, $false)
      New-Item -ItemType Junction -Path $script:admin -Target $script:replacement | Out-Null
    }
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'unsafe'
    Test-Path (Join-Path $script:replacement 'retain') | Should -BeTrue
  }
  It 'refuses a recreated worktree pointer' {
    $fixture = New-NativeCleanupFixture
    $script:target = $fixture.WorktreePath
    $script:afterNative = {
      New-Item -ItemType Directory -Path $script:target -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $script:target '.git') -Value 'retain'
    }
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'pointer remains or was recreated'
    Test-Path $script:admin | Should -BeTrue
  }
  It 'refuses a changed recovery reference' {
    $fixture = New-NativeCleanupFixture
    $script:owner = $fixture.RepositoryPath
    $script:afterNative = { & git -C $script:owner update-ref -d ('refs/archive/sprint-worktree-removal/' + (& git -C $script:owner rev-parse HEAD)) }
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    Test-Path $script:admin | Should -BeTrue
  }
  It 'keeps the uncertainty gate for an unrelated native failure' {
    $fixture = New-NativeCleanupFixture
    $script:nativeMessage = 'error: unknown native failure'
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'despite deregistration; explicit review required'
    Test-Path $script:admin | Should -BeTrue
  }
  It 'rejects resume evidence with missing cleanup completion' {
    $fixture = New-NativeCleanupFixture
    (Remove-SprintWorktreeSafely @fixture).Ok | Should -BeTrue
    $receipt = Get-Content $fixture.ReceiptPath -Raw | ConvertFrom-Json -AsHashtable
    $receipt.Events = @($receipt.Events | Where-Object Event -ne NativeMetadataCleanupComplete)
    $receipt | ConvertTo-Json -Depth 35 | Set-Content $fixture.ReceiptPath
    $result = Remove-SprintWorktreeSafely @fixture
    $result.Ok | Should -BeFalse
    $result.Failures -join ' ' | Should -Match 'exactly one successful native removal'
  }
}
