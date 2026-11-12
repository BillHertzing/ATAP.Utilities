Describe 'Invoke-ParityIsolatedDesktopAuditTask on UTAT022' -Tag 'Unit' {
  BeforeAll {
    $original = Join-Path $PSScriptRoot '../Support/Invoke-ParityIsolatedDesktopAuditTask.ps1'
    $script:fakeRepo = if ($env:ATAP_ISOLATED_DESKTOP_AUDIT_TEST_ROOT) {
      Join-Path $env:ATAP_ISOLATED_DESKTOP_AUDIT_TEST_ROOT ([guid]::NewGuid().ToString('N'))
    } else {
      Join-Path $TestDrive 'Utilities150'
    }
    $support = Join-Path $script:fakeRepo 'src/ATAP.Utilities.SystemParityMonitor.PowerShell/tests/Support'
    $null = New-Item -ItemType Directory -Path $support -Force
    Copy-Item -LiteralPath $original -Destination $support
    . (Join-Path $support 'Invoke-ParityIsolatedDesktopAuditTask.ps1')

    $script:runId = [guid]::NewGuid().ToString('N')
    $script:owner = [guid]::NewGuid().ToString('N')
    $script:runRoot = Join-Path $script:fakeRepo '_generated/Sprint0017/17.6.a/StatePathFixtures' $script:runId
    $script:sid = 'S-1-5-21-100-200-300-1001'
    $script:profileKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$script:sid"
    $script:copilotKey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{43D3B0DD-4ABF-4CBA-80C7-2403679A3634}'
    $script:antigravityKey = "Registry::HKEY_USERS\$script:sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\FixtureAntigravity"
    $script:copilotPath = 'C:\Program Files\GitHub Copilot\github.exe'
    $script:antigravityPath = 'C:\Users\whertzing\AppData\Local\Programs\antigravity\Antigravity.exe'
  }

  BeforeEach {
    $caseId = [guid]::NewGuid().ToString('N')
    $script:casePath = Join-Path $script:runRoot $caseId
    $null = New-Item -ItemType Directory -Path $script:casePath -Force
    $script:markerPath = Join-Path $script:casePath '.owned-parity-fixture.json'
    $script:outputPath = Join-Path $script:casePath 'ParityIsolatedDesktopAuditResult.json'
    $marker = @{ RunId = $script:runId; CaseId = $caseId; OwnerToken = $script:owner } | ConvertTo-Json -Compress
    Set-Content -LiteralPath $script:markerPath -Value $marker -NoNewline
    $dirs = for ($dir = Get-Item -LiteralPath $script:casePath; $null -ne $dir; $dir = $dir.Parent) {
      [pscustomobject]@{ Path = $dir.FullName; CreationTicks = $dir.CreationTimeUtc.Ticks }
      if ($dir.FullName -eq $script:fakeRepo) { break }
    }
    [array]::Reverse($dirs)
    $script:registration = [pscustomobject]@{
      RepositoryRoot = $script:fakeRepo; RunId = $script:runId; CaseId = $caseId; OwnerToken = $script:owner
      Status = 'Active'; MarkerJson = $marker; Ancestors = $dirs
    }
    $script:inputArguments = @{
      StatePath = $script:casePath; RunId = $script:runId; CaseId = $caseId; OwnerToken = $script:owner
      AntigravityUserSid = $script:sid; AntigravityUninstallKeyName = 'FixtureAntigravity'
    }

    # The synthetic evidence root exceeds the native tag utility's path limit.
    # Use a cloud tag fixture while real junction detection stays active.
    Mock Get-IsolatedDesktopAuditReparseTag { '0x9000e01a' }

    Mock Get-IsolatedDesktopAuditFixtureRegistration { throw 'Unexpected fixture lookup.' }
    Mock Get-IsolatedDesktopAuditFixtureRegistration { $script:registration } -ParameterFilter { $CasePath -eq $script:casePath }

    # Every registration and executable lookup is synthetic. An unexpected
    # path fails through the unfiltered mock instead of reaching the workstation.
    Mock Get-ItemProperty { throw 'Unexpected registration lookup.' }
    Mock Get-ItemProperty { [pscustomobject]@{ ProfileImagePath = 'C:\Users\whertzing' } } -ParameterFilter { $LiteralPath -eq $script:profileKey }
    Mock Get-ItemProperty {
      [pscustomobject]@{ DisplayName = 'GitHub Copilot'; Publisher = 'GitHub Inc.'; DisplayVersion = '1.1.35' }
    } -ParameterFilter { $LiteralPath -eq $script:copilotKey }
    Mock Get-ItemProperty {
      [pscustomobject]@{ DisplayName = 'Antigravity 2.29.0'; Publisher = 'Google'; DisplayVersion = '2.29.0' }
    } -ParameterFilter { $LiteralPath -eq $script:antigravityKey }

    Mock Get-IsolatedDesktopAuditExecutable { throw 'Unexpected executable lookup.' }
    Mock Get-IsolatedDesktopAuditExecutable {
      [pscustomobject]@{ ProductName = 'GitHub Copilot'; ProductVersion = '1.1.35'; SHA256 = 'A' * 64 }
    } -ParameterFilter { $Path -eq $script:copilotPath }
    Mock Get-IsolatedDesktopAuditExecutable {
      [pscustomobject]@{ ProductName = 'Antigravity'; ProductVersion = '2.29.0.0'; SHA256 = 'B' * 64 }
    } -ParameterFilter { $Path -eq $script:antigravityPath }
  }

  It 'reads only the two pinned registrations and writes exactly one case-local result' {
    $invokeArguments = $script:inputArguments
    $result = Invoke-ParityIsolatedDesktopAuditTask @invokeArguments
    $result.Rows.Id -join ',' | Should -Be 'GitHubCopilotDesktop,GoogleAntigravityApp'
    $result.Rows.Scope -join ',' | Should -Be 'AllUsers,CurrentUser'
    @($result.Rows | Where-Object MatchesExpectedVersion) | Should -HaveCount 2

    $saved = Get-Content -LiteralPath $script:outputPath -Raw | ConvertFrom-Json
    $saved.HostName | Should -Be 'UTAT022'
    $saved.Rows.ExecutableSHA256 -join ',' | Should -Be (('A' * 64) + ',' + ('B' * 64))
    @(Get-ChildItem -LiteralPath $script:casePath -Force -File) | Should -HaveCount 2
    @(Get-ChildItem -LiteralPath $script:casePath -Filter '*.pending' -Force) | Should -HaveCount 0
    Should -Invoke Get-ItemProperty -Times 3 -Exactly -Scope It
    Should -Invoke Get-ItemProperty -Times 1 -Exactly -Scope It -ParameterFilter { $LiteralPath -eq $script:copilotKey }
    Should -Invoke Get-ItemProperty -Times 1 -Exactly -Scope It -ParameterFilter { $LiteralPath -eq $script:antigravityKey }
    Should -Invoke Get-IsolatedDesktopAuditExecutable -Times 2 -Exactly -Scope It
  }

  It 'cloud-family guard <Name>' -ForEach @(
    @{ Name = 'accepts the observed CLOUD_A tag'; ReparseTag = '0x9000a01a'; Refuse = $false }
    @{ Name = 'accepts the observed CLOUD_2 tag'; ReparseTag = '0x9000201a'; Refuse = $false }
    @{ Name = 'refuses the nearby unlisted tag'; ReparseTag = '0x9000a01b'; Refuse = $true }
    @{ Name = 'continues to refuse a non-cloud tag'; ReparseTag = '0x80000017'; Refuse = $true }
  ) {
    $item = Get-Item -LiteralPath $script:runRoot -Force
    Add-Member -InputObject $item -Force -NotePropertyName Attributes -NotePropertyValue (
      $item.Attributes -bor [IO.FileAttributes]::ReparsePoint
    )
    $script:syntheticReparseTag = $ReparseTag
    Mock Get-IsolatedDesktopAuditReparseTag {
      $Diagnostic.NativeExit = 0
      $script:syntheticReparseTag
    } -ParameterFilter { $Path -eq $script:runRoot }

    if ($Refuse) {
      { Assert-IsolatedDesktopAuditLocalItem -Item $item } | Should -Throw "*unsupported reparse points*fsutil exit=0*tag=$ReparseTag*"
    } else {
      { Assert-IsolatedDesktopAuditLocalItem -Item $item } | Should -Not -Throw
    }
    Should -Invoke Get-IsolatedDesktopAuditReparseTag -Times 1 -Exactly -Scope It -ParameterFilter { $Path -eq $script:runRoot }
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'cloud-family guard refuses <Name> from the tag reader' -ForEach @(
    @{ Name = 'zero emitted objects'; NoOutput = $true; ExpectedDiagnostic = '*fsutil exit=5*tag unavailable: Native query exited unsuccessfully before tag parsing*' }
    @{ Name = 'multiple emitted tags'; NoOutput = $false; ExpectedDiagnostic = '*fsutil exit=0*tag=*0x9000a01a*0x9000201a*' }
  ) {
    $item = Get-Item -LiteralPath $script:runRoot -Force
    Add-Member -InputObject $item -Force -NotePropertyName Attributes -NotePropertyValue (
      $item.Attributes -bor [IO.FileAttributes]::ReparsePoint
    )
    $script:emitNoTag = $NoOutput
    Mock Get-IsolatedDesktopAuditReparseTag {
      if ($script:emitNoTag) {
        $Diagnostic.NativeExit = 5
        $Diagnostic.AbsentTagReason = 'Native query exited unsuccessfully before tag parsing'
        return
      }
      $Diagnostic.NativeExit = 0
      '0x9000a01a'
      '0x9000201a'
    } -ParameterFilter { $Path -eq $script:runRoot }

    { Assert-IsolatedDesktopAuditLocalItem -Item $item } |
      Should -Throw "*unsupported reparse points*Path='$($item.FullName)'*Attributes=*$ExpectedDiagnostic"
    Should -Invoke Get-IsolatedDesktopAuditReparseTag -Times 1 -Exactly -Scope It -ParameterFilter { $Path -eq $script:runRoot }
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'rejects <Name> before any registration read or result write' -ForEach @(
    @{ Name = 'omitted StatePath'; Value = $null; Omit = $true; ExpectedError = '*explicit StatePath*' }
    @{ Name = 'empty StatePath'; Value = ''; Omit = $false; ExpectedError = '*explicit StatePath*' }
    @{ Name = 'whitespace StatePath'; Value = ' '; Omit = $false; ExpectedError = '*explicit StatePath*' }
    @{ Name = 'production default'; Value = 'C:\ProgramData\ATAP\ParityState'; Omit = $false; ExpectedError = '*exact owned run/case*' }
    @{ Name = 'peer UNC'; Value = '\\fixture.invalid\ParityState'; Omit = $false; ExpectedError = '*exact owned run/case*' }
    @{ Name = 'relative path'; Value = '.'; Omit = $false; ExpectedError = '*exact owned run/case*' }
  ) {
    $invokeArguments = $script:inputArguments.Clone()
    if ($Omit) { $invokeArguments.Remove('StatePath') } else { $invokeArguments.StatePath = $Value }

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw $ExpectedError
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'rejects a case missing its process ownership registration before collection' {
    $script:registration = $null
    $invokeArguments = $script:inputArguments
    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*not owned*'
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'rejects a changed marker before collection' {
    Set-Content -LiteralPath $script:markerPath -Value '{}' -NoNewline
    $invokeArguments = $script:inputArguments
    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*ownership marker changed*'
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'rejects a redirected case before following it or collecting' {
    $linkId = [guid]::NewGuid().ToString('N')
    $linkPath = Join-Path $script:runRoot $linkId
    $null = New-Item -ItemType Junction -Path $linkPath -Target $script:casePath
    $invokeArguments = $script:inputArguments.Clone()
    $invokeArguments.CaseId = $linkId
    $invokeArguments.StatePath = $linkPath
    $script:registration.CaseId = $linkId
    $script:casePath = $linkPath

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*refuses redirected paths*'
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'rejects an occupied result path before collection and preserves its bytes' {
    Set-Content -LiteralPath $script:outputPath -Value 'existing' -NoNewline
    $invokeArguments = $script:inputArguments

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*result path already exists*'
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Get-Content -LiteralPath $script:outputPath -Raw | Should -Be 'existing'
  }

  It 'rejects a registry key path fragment before collection' {
    $invokeArguments = $script:inputArguments.Clone()
    $invokeArguments.AntigravityUninstallKeyName = '..\Antigravity'

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*literal Antigravity uninstall key name*'
    Should -Invoke Get-ItemProperty -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'refuses <Lookalike> at the Copilot registration before reading any executable' -ForEach @(
    @{ Lookalike = 'GitHub Copilot CLI'; Publisher = 'GitHub Inc.' }
    @{ Lookalike = 'Copilot'; Publisher = 'Microsoft Corporation' }
  ) {
    $script:lookalike = [pscustomobject]@{ DisplayName = $Lookalike; Publisher = $Publisher; DisplayVersion = '1.0.103' }
    Mock Get-ItemProperty { $script:lookalike } -ParameterFilter { $LiteralPath -eq $script:copilotKey }
    $invokeArguments = $script:inputArguments

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*registration identity for GitHubCopilotDesktop*'
    Should -Invoke Get-IsolatedDesktopAuditExecutable -Times 0 -Exactly -Scope It
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'refuses Antigravity IDE and leaves no partial result' {
    Mock Get-ItemProperty {
      [pscustomobject]@{ DisplayName = 'Antigravity IDE (User)'; Publisher = 'Google'; DisplayVersion = '2.0.3' }
    } -ParameterFilter { $LiteralPath -eq $script:antigravityKey }
    $invokeArguments = $script:inputArguments

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments } | Should -Throw '*registration identity for GoogleAntigravityApp*'
    Should -Invoke Get-IsolatedDesktopAuditExecutable -Times 0 -Exactly -Scope It -ParameterFilter { $Path -eq $script:antigravityPath }
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
  }

  It 'terminates on a publication <Stage> failure without emitting a success or final receipt' -ForEach @(
    @{ Stage = 'open'; PendingCount = 0 }
    @{ Stage = 'write'; PendingCount = 1 }
    @{ Stage = 'flush'; PendingCount = 1 }
    @{ Stage = 'close'; PendingCount = 1 }
  ) {
    $script:publicationFault = $Stage
    Mock Open-IsolatedDesktopAuditStage {
      if ($script:publicationFault -eq 'open') {
        throw [IO.IOException]::new('Injected open failure.')
      }
      $writer = [pscustomobject]@{
        Stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        Fault = $script:publicationFault
      }
      $writer | Add-Member -MemberType ScriptMethod -Name Write -Value {
        param([byte[]] $Bytes, [int] $Offset, [int] $Count)
        if ($this.Fault -eq 'write') {
          $this.Stream.Write($Bytes, $Offset, 1)
          throw [IO.IOException]::new('Injected write failure.')
        }
        $this.Stream.Write($Bytes, $Offset, $Count)
      }
      $writer | Add-Member -MemberType ScriptMethod -Name Flush -Value {
        param([bool] $FlushToDisk)
        if ($this.Fault -eq 'flush') { throw [IO.IOException]::new('Injected flush failure.') }
        $this.Stream.Flush($FlushToDisk)
      }
      $writer | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        $this.Stream.Dispose()
        if ($this.Fault -eq 'close') { throw [IO.IOException]::new('Injected close failure.') }
      }
      $writer
    }
    $invokeArguments = $script:inputArguments
    $objects = [Collections.Generic.List[object]]::new()

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments -ErrorAction Continue |
        ForEach-Object { $objects.Add($_) } } | Should -Throw "*Injected $Stage failure*"

    $objects.Count | Should -Be 0
    Test-Path -LiteralPath $script:outputPath | Should -BeFalse
    $pending = @(Get-ChildItem -LiteralPath $script:casePath -Filter '*.pending' -Force -File)
    $pending | Should -HaveCount $PendingCount
    if ($Stage -eq 'write') { $pending[0].Length | Should -Be 1 }
  }

  It 'fails terminally and preserves a competing final receipt created after preflight' {
    Mock Get-IsolatedDesktopAuditExecutable {
      Set-Content -LiteralPath $script:outputPath -Value 'competing' -NoNewline
      [pscustomobject]@{ ProductName = 'Antigravity'; ProductVersion = '2.29.0.0'; SHA256 = 'B' * 64 }
    } -ParameterFilter { $Path -eq $script:antigravityPath }
    $invokeArguments = $script:inputArguments
    $objects = [Collections.Generic.List[object]]::new()

    { Invoke-ParityIsolatedDesktopAuditTask @invokeArguments -ErrorAction Continue |
        ForEach-Object { $objects.Add($_) } } | Should -Throw

    $objects.Count | Should -Be 0
    Get-Content -LiteralPath $script:outputPath -Raw | Should -Be 'competing'
    @(Get-ChildItem -LiteralPath $script:casePath -Filter '*.pending' -Force -File) | Should -HaveCount 1
  }
}
