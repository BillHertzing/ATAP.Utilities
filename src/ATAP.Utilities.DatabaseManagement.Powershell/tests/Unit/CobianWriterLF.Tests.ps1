param(
  [string] $FixtureRoot = 'D:/ATAPArtifacts/Sprint0017/Task17.9.b/CobianWritersLF331/Fixtures'
)

# Genuine source functions; only the administrator seam and external command
# boundaries are mocked. This does not prove elevation or native Cobian parsing.
BeforeAll {
  $script:fixtureRoot = [IO.Path]::GetFullPath($FixtureRoot)
  if (-not $script:fixtureRoot.StartsWith('D:\ATAPArtifacts\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Cobian fixtures must remain under D:/ATAPArtifacts.'
  }
  [IO.Directory]::CreateDirectory($script:fixtureRoot) | Out-Null

  $public = Join-Path $PSScriptRoot '../../public'
  . (Join-Path $public 'New-CobianAppJobs.ps1')
  . (Join-Path $public 'New-CobianSqlJobs.ps1')

  # Local command boundaries prevent autoload or calls to host configuration/logging.
  function Write-PSFMessage {
    param($FunctionName, $ModuleName, $Level, $Message, $Tag)
  }
  function Get-PVal {
    param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
    $DefaultValue
  }

  function New-CobianListFixture {
    param([string] $Writer, [string] $Ending, [string] $EncodingName)
    $folder = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $path = Join-Path $folder 'MainList.lst'
    $rootGuid = '11111111-1111-1111-1111-111111111111'
    $taskGuid = '22222222-2222-2222-2222-222222222222'
    $taskId = '33333333-3333-3333-3333-333333333333'
    $existingName = if ($Writer -eq 'App') { 'App - ProGet - Full' } else { 'SQL - ProGet - Full' }
    $existingSection = @(
      "<§- $taskGuid -§>"
      '§DuplicatedKeys:True'
      "TaskId=$taskId"
      "TaskName=$existingName"
      'TaskEnabled=False'
      'TaskCustomSetting=café λ  '
      "TaskUnicodeForms=$([char]0x00e9) / e$([char]0x0301)"
      "<§§- $taskGuid -§§>"
    ) -join "`n"
    $logical = (@(
      "<§- $rootGuid -§>"
      '§DuplicatedKeys:True'
      '§CaseSensitive:False'
      '§PairSeparator:='
      'UnownedSetting=keep me  '
      "BackupTask={ *§* $taskGuid *§* }"
      "<§§- $rootGuid -§§>"
      $existingSection
    ) -join "`n") # Deliberately no final newline on the input.
    $inputText = switch ($Ending) {
      'LF' { $logical }
      'CRLF' { $logical.Replace("`n", "`r`n") }
      'CR' { $logical.Replace("`n", "`r") }
      'Mixed' { $logical.Replace("`n", "`r`n").Replace("TaskId=$taskId`r`n", "TaskId=$taskId`r") }
    }
    $encoding = switch ($EncodingName) {
      'Utf8' { [Text.UTF8Encoding]::new($false) }
      'Utf8Bom' { [Text.UTF8Encoding]::new($true) }
      'Utf16LE' { [Text.UnicodeEncoding]::new($false, $true) }
      'Utf16BE' { [Text.UnicodeEncoding]::new($true, $true) }
    }
    [IO.File]::WriteAllText($path, $inputText, $encoding)
    [pscustomobject]@{
      Path = $path; Folder = $folder; Encoding = $encoding
      InputBytes = [IO.File]::ReadAllBytes($path)
      ExistingSection = $existingSection; ExistingName = $existingName
    }
  }

  function Invoke-CobianFixtureWriter {
    param([string] $Writer, [string] $Path, [switch] $Preview)
    $arguments = @{ ListPath = $Path; BackupRoot = (Join-Path ([IO.Path]::GetDirectoryName($Path)) 'Backups'); Confirm = $false }
    if ($Writer -eq 'App') {
      New-CobianAppJobs @arguments -ProGetDataPath 'fixture-proget' -BuildMasterDataPath 'fixture-buildmaster' -Force -WhatIf:$Preview
    } else {
      New-CobianSqlJobs @arguments -ScriptPath 'fixture-backup.ps1' -PwshExe 'fixture-pwsh.exe'
    }
  }
}

Describe 'Cobian native list CRLF writers: <Writer>' -Tag 'Unit' -ForEach @(
  @{ Writer = 'App'; ExpectedTasks = 5; ExpectedNewSchedules = 4 }
  @{ Writer = 'Sql'; ExpectedTasks = 4; ExpectedNewSchedules = 3 }
) {
  BeforeEach {
    # Fake all external boundaries. The only filesystem I/O is .NET against
    # explicitly D-bound disposable list/backup fixtures.
    Mock Test-CobianAppJobsAdministrator { $true }
    Mock Test-CobianSqlJobsAdministrator { $true }
    Mock Get-Service { @() }
    Mock Stop-Service { throw 'Service control is forbidden in a unit test.' }
    Mock Start-Service { throw 'Service control is forbidden in a unit test.' }
    Mock Test-Path { $true }
    Mock New-Item { throw 'Unexpected directory creation outside fixture setup.' }
    Mock Read-Host { '' }
    Mock Write-Host {}
    Mock Write-Warning {}
    Mock Write-PSFMessage {}
    Mock Get-PVal { $DefaultValue }
    Mock Copy-Item {
      param($Path, $Destination)
      $source = [IO.Path]::GetFullPath($Path)
      $target = [IO.Path]::GetFullPath($Destination)
      if (-not $source.StartsWith($script:fixtureRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        -not $target.StartsWith($source + '.bak_', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Backup escaped its disposable fixture.'
      }
      [IO.File]::WriteAllBytes($target, [IO.File]::ReadAllBytes($source))
    }
  }

  It 'rejects a non-administrator before any external operation' {
    Mock Test-CobianAppJobsAdministrator { $false }
    Mock Test-CobianSqlJobsAdministrator { $false }
    $fixture = New-CobianListFixture -Writer $Writer -Ending CRLF -EncodingName Utf16LE
    { Invoke-CobianFixtureWriter -Writer $Writer -Path $fixture.Path } | Should -Throw '*must be run from an elevated PowerShell session*'
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($fixture.Path)) | Should -BeExactly ([Convert]::ToBase64String($fixture.InputBytes))
    Should -Invoke Get-Service -Times 0 -Exactly
    Should -Invoke Copy-Item -Times 0 -Exactly
    Should -Invoke Get-PVal -Times 0 -Exactly
  }

  It 'writes native CRLF with preserved <EncodingName> encoding from <Ending> input and preserves task/reference semantics' -ForEach @(
    @{ Ending = 'LF'; EncodingName = 'Utf8' }
    @{ Ending = 'CRLF'; EncodingName = 'Utf8' }
    @{ Ending = 'CR'; EncodingName = 'Utf8' }
    @{ Ending = 'Mixed'; EncodingName = 'Utf8' }
    @{ Ending = 'LF'; EncodingName = 'Utf8Bom' }
    @{ Ending = 'CRLF'; EncodingName = 'Utf8Bom' }
    @{ Ending = 'CR'; EncodingName = 'Utf8Bom' }
    @{ Ending = 'Mixed'; EncodingName = 'Utf8Bom' }
    @{ Ending = 'LF'; EncodingName = 'Utf16LE' }
    @{ Ending = 'CRLF'; EncodingName = 'Utf16LE' }
    @{ Ending = 'CR'; EncodingName = 'Utf16LE' }
    @{ Ending = 'Mixed'; EncodingName = 'Utf16LE' }
    @{ Ending = 'LF'; EncodingName = 'Utf16BE' }
    @{ Ending = 'CRLF'; EncodingName = 'Utf16BE' }
    @{ Ending = 'CR'; EncodingName = 'Utf16BE' }
    @{ Ending = 'Mixed'; EncodingName = 'Utf16BE' }
  ) {
    $fixture = New-CobianListFixture -Writer $Writer -Ending $Ending -EncodingName $EncodingName
    Invoke-CobianFixtureWriter -Writer $Writer -Path $fixture.Path
    $bytes = [IO.File]::ReadAllBytes($fixture.Path)
    $preamble = $fixture.Encoding.GetPreamble()
    $expectedBom = [Convert]::ToBase64String($preamble)
    if ($preamble.Length) {
      [Convert]::ToBase64String($bytes[0..($preamble.Length - 1)]) | Should -BeExactly $expectedBom
    } else {
      [Convert]::ToBase64String($bytes[0..2]) | Should -Not -Be '77u/'
    }
    $text = $fixture.Encoding.GetString($bytes, $preamble.Length, $bytes.Length - $preamble.Length)
    $text | Should -Not -Match '\r(?!\n)|(?<!\r)\n'
    $text.EndsWith("`r`n", [StringComparison]::Ordinal) | Should -BeTrue
    # Establish native CRLF first; use LF only for the unchanged semantic oracles.
    $logicalText = $text.Replace("`r`n", "`n")
    $logicalText.Contains($fixture.ExistingSection, [StringComparison]::Ordinal) | Should -BeTrue
    $logicalText.Contains('UnownedSetting=keep me  ', [StringComparison]::Ordinal) | Should -BeTrue
    @([regex]::Matches($logicalText, '(?m)^TaskId=')).Count | Should -Be $ExpectedTasks
    @([regex]::Matches($logicalText, '(?m)^BackupTask=')).Count | Should -Be $ExpectedTasks
    @([regex]::Matches($logicalText, '(?m)^SchSchedule=2$')).Count | Should -Be $ExpectedNewSchedules
    @([regex]::Matches($logicalText, '(?m)^TaskName=' + [regex]::Escape($fixture.ExistingName) + '$')).Count | Should -Be 1
    $sections = @([regex]::Matches($logicalText, '(?m)^<§- ([0-9a-f-]{36}) -§>$') | ForEach-Object { $_.Groups[1].Value })
    $sections.Count | Should -Be (@($sections | Sort-Object -Unique).Count)
    foreach ($reference in [regex]::Matches($logicalText, '\{ \*§\* ([0-9a-f-]{36}) \*§\* \}')) {
      $sections | Should -Contain $reference.Groups[1].Value
    }
    foreach ($schedule in [regex]::Matches($logicalText, '(?s)SchSchedule=2\n.*?SchUseOrdinaryDaysOfWeek=False')) {
      $days = @([regex]::Matches($schedule.Value, '(?m)^SchDaysOfWeek=(\d)$') | ForEach-Object { [int]$_.Groups[1].Value })
      @('0', '1,2,3,4,5,6') | Should -Contain ($days -join ',')
      $schedule.Value | Should -Match 'SchDateAndTime=\d{4}-\d{2}-\d{2} (03:00|03:30|03:50|01:50|02:20):00:'
    }
    $backup = @([IO.Directory]::GetFiles($fixture.Folder, 'MainList.lst.bak_*'))
    $backup.Count | Should -Be 1
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($backup[0])) | Should -BeExactly ([Convert]::ToBase64String($fixture.InputBytes))

    # Existing names must remain recognized after lone-CR normalization, and no
    # second-run GUIDs/references/settings may be introduced.
    Invoke-CobianFixtureWriter -Writer $Writer -Path $fixture.Path
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($fixture.Path)) | Should -BeExactly ([Convert]::ToBase64String($bytes))
    Should -Invoke Stop-Service -Times 0 -Exactly
    Should -Invoke Start-Service -Times 0 -Exactly
    Should -Invoke New-Item -Times 0 -Exactly
  }
}

Describe 'Cobian application list preview' -Tag 'Unit' {
  BeforeEach {
    Mock Test-CobianAppJobsAdministrator { $true }
    Mock Get-Service { @() }
    Mock Stop-Service { throw 'Forbidden service control.' }
    Mock Start-Service { throw 'Forbidden service control.' }
    Mock Test-Path { $true }
    Mock New-Item { throw 'Forbidden directory creation.' }
    Mock Copy-Item { throw 'WhatIf attempted a backup.' }
    Mock Read-Host { throw 'Unexpected prompt.' }
    Mock Write-PSFMessage {}
    Mock Get-PVal { $DefaultValue }
  }

  It 'leaves the entire legacy list and backup set untouched under WhatIf' {
    $fixture = New-CobianListFixture -Writer App -Ending Mixed -EncodingName Utf16LE
    $beforeTime = [IO.File]::GetLastWriteTimeUtc($fixture.Path)
    Invoke-CobianFixtureWriter -Writer App -Path $fixture.Path -Preview
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($fixture.Path)) | Should -BeExactly ([Convert]::ToBase64String($fixture.InputBytes))
    [IO.File]::GetLastWriteTimeUtc($fixture.Path) | Should -Be $beforeTime
    @([IO.Directory]::GetFiles($fixture.Folder)).Count | Should -Be 1
    Should -Invoke Copy-Item -Times 0 -Exactly
    Should -Invoke Stop-Service -Times 0 -Exactly
    Should -Invoke Start-Service -Times 0 -Exactly
  }
}
