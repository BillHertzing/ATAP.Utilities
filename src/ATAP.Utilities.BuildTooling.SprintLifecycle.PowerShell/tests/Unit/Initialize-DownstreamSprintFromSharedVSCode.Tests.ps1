# Focused wrapper source tests: real workspace helpers; closed context-writer double.
BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $srcRoot = Split-Path -Parent $moduleRoot
  function script:Resolve-FamilyScript {
    param([string]$FileName, [ValidateSet('public', 'private')][string]$Folder = 'public')
    $found = Get-ChildItem -LiteralPath $srcRoot -Directory |
      Where-Object Name -Like 'ATAP.Utilities.BuildTooling.*' |
      ForEach-Object { Join-Path $_.FullName "$Folder/$FileName" } |
      Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (!$found) { throw "Required family helper unavailable: $FileName" }
    return $found
  }
  . (Resolve-FamilyScript 'Get-WorkspaceJson.ps1')
  . (Resolve-FamilyScript 'Save-WorkspaceJson.ps1' 'private')
  . (Resolve-FamilyScript 'Resolve-WorkspaceFiles.ps1')
  . (Resolve-FamilyScript 'Set-WorkspaceSharedVSCodeReference.ps1')
  . (Join-Path $moduleRoot 'public/Initialize-DownstreamSprintFromSharedVSCode.ps1')
  $script:referenceImplementation = ${function:Set-WorkspaceSharedVSCodeReference}
  function Write-PSFMessage {
    [CmdletBinding()]
    param($FunctionName, $ModuleName, $Level, $Message, $Tag)
  }
  # A missing mock must fail closed instead of reaching an installed writer.
  function Set-DownstreamSharedVSCodeContext {
    [CmdletBinding()]
    param($WorkspaceFiles, $GitRoot, $SharedVSCodeRepoName, $SharedHooksSubPath, $CommitTemplateRelativePath)
    throw 'Unmocked context writer is forbidden in this wrapper suite.'
  }
  $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')
  if (!$artifactRoot) { $artifactRoot = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
  if (!$artifactRoot) { throw 'ARTIFACTS_PATH is required.' }
  $script:fixtureRoot = [IO.Path]::GetFullPath((Join-Path $artifactRoot ('Sprint0017/Task17.66.c/InitializeRollback25/Fixtures/' + [guid]::NewGuid().ToString('N'))))
  [IO.Directory]::CreateDirectory($script:fixtureRoot) | Out-Null
  function script:Write-FixtureWorkspace {
    param([string]$Path, [string]$Ref = 'main')
    $full = [IO.Path]::GetFullPath($Path)
    if (!$full.StartsWith($script:fixtureRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped owning root.' }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $text = '{"folders":[{"path":"."}],"settings":{"atap.sharedVSCode.templateRef":"' + $Ref + '","atap.sharedVSCode.profile":"default","fixture.keep":"unchanged"},"fixtureTop":17}'
    [IO.File]::WriteAllText($full, $text, [Text.UTF8Encoding]::new($false))
    return $full
  }
  function script:Invoke-FixtureInitialize {
    param([string[]]$Files = @($script:wsFile), [switch]$DefaultProfile)
    $options = @{ WorkspaceFiles = $Files; TemplateRef = $script:sprintRef; GitRoot = $script:caseRoot }
    if (!$DefaultProfile) { $options.Profile = 'sprint-fixture' }
    Initialize-DownstreamSprintFromSharedVSCode @options
  }
}
Describe 'Initialize-DownstreamSprintFromSharedVSCode bounded workspace recovery' {
  BeforeEach {
    $script:caseRoot = Join-Path $script:fixtureRoot ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $script:wsFile = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Test.code-workspace')
    $script:sprintRef = 'SharedVSCode-wt-fixture'
    Mock Set-DownstreamSharedVSCodeContext { }
  }
  It 'preserves successful reference/profile alias behavior and unrelated workspace keys' {
    Invoke-FixtureInitialize
    $json = Get-WorkspaceJson -WorkspaceFile $script:wsFile
    $json.settings.'atap.sharedVSCode.templateRef' | Should -BeExactly $script:sprintRef
    $json.settings.'atap.sharedVSCode.profile' | Should -BeExactly 'sprint-fixture'
    $json.settings.'fixture.keep' | Should -BeExactly 'unchanged'
    $json.fixtureTop | Should -Be 17
    $json.folders[0].path | Should -BeExactly '.'
  }
  It 'delegates each reference update to the existing helper' {
    Mock Set-WorkspaceSharedVSCodeReference {
      & $script:referenceImplementation -WorkspaceFiles $WorkspaceFiles -TemplateRef $TemplateRef -ProfileName $ProfileName -ErrorAction Stop
    }
    Invoke-FixtureInitialize
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 1 -Exactly -ParameterFilter {
      $WorkspaceFiles.Count -eq 1 -and $WorkspaceFiles[0] -eq $script:wsFile -and $TemplateRef -eq $script:sprintRef
    }
  }
  It 'delegates context once with the complete pinned group and existing options' {
    $second = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Second.code-workspace')
    Invoke-FixtureInitialize @($script:wsFile, $second)
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 1 -Exactly -ParameterFilter {
      $WorkspaceFiles.Count -eq 2 -and $GitRoot -eq $script:caseRoot -and $SharedVSCodeRepoName -eq 'SharedVSCode' -and $SharedHooksSubPath -eq '.githooks'
    }
    (Get-WorkspaceJson $second).settings.'atap.sharedVSCode.templateRef' | Should -BeExactly $script:sprintRef
  }
  It 'defaults ProfileName to default when omitted' {
    Invoke-FixtureInitialize -DefaultProfile
    (Get-WorkspaceJson $script:wsFile).settings.'atap.sharedVSCode.profile' | Should -BeExactly 'default'
  }
  It 'restores exact BOM and original whitespace bytes when the setter refuses' {
    $original = [byte[]](0xEF, 0xBB, 0xBF) + [IO.File]::ReadAllBytes($script:wsFile) + [Text.Encoding]::UTF8.GetBytes("`r`n  `r`n")
    [IO.File]::WriteAllBytes($script:wsFile, $original)
    $before = (Get-FileHash -LiteralPath $script:wsFile).Hash
    Mock Set-DownstreamSharedVSCodeContext { throw 'InjectedSetterRefusal' }
    { Invoke-FixtureInitialize } | Should -Throw '*InjectedSetterRefusal*'
    (Get-FileHash -LiteralPath $script:wsFile).Hash | Should -BeExactly $before
  }
  It 'preserves peer-diverged workspace bytes and explicitly holds recovery' {
    Mock Set-DownstreamSharedVSCodeContext {
      [IO.File]::WriteAllText($script:wsFile, 'peer workspace bytes')
      throw 'InjectedSetterRefusal'
    }
    { Invoke-FixtureInitialize } | Should -Throw '*SharedVSCodeInitialize.HeldRecovery: WorkspaceDiverged*'
    [IO.File]::ReadAllText($script:wsFile) | Should -BeExactly 'peer workspace bytes'
  }
  It 'restores all compatible workspace preimages on later setter refusal' {
    $second = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Second.code-workspace')
    $before = @((Get-FileHash -LiteralPath $script:wsFile).Hash, (Get-FileHash -LiteralPath $second).Hash)
    Mock Set-DownstreamSharedVSCodeContext { throw 'InjectedSetterRefusal' }
    { Invoke-FixtureInitialize @($script:wsFile, $second) } | Should -Throw '*InjectedSetterRefusal*'
    @((Get-FileHash -LiteralPath $script:wsFile).Hash, (Get-FileHash -LiteralPath $second).Hash) | Should -Be $before
  }
  It 'preflights the full recovery group before restoring any member' {
    $script:secondFile = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Second.code-workspace')
    Mock Set-DownstreamSharedVSCodeContext {
      [IO.File]::WriteAllText($script:secondFile, 'second peer bytes')
      throw 'InjectedSetterRefusal'
    }
    { Invoke-FixtureInitialize @($script:wsFile, $script:secondFile) } | Should -Throw '*HeldRecovery*'
    [IO.File]::ReadAllText($script:secondFile) | Should -BeExactly 'second peer bytes'
    (Get-WorkspaceJson $script:wsFile).settings.'atap.sharedVSCode.templateRef' | Should -BeExactly $script:sprintRef
  }
  It 'rejects malformed later JSON before changing any workspace' {
    $bad = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Bad.code-workspace')
    [IO.File]::WriteAllText($bad, '{')
    $before = (Get-FileHash -LiteralPath $script:wsFile).Hash
    Mock Set-WorkspaceSharedVSCodeReference { throw 'Unexpected reference effect' }
    { Invoke-FixtureInitialize @($script:wsFile, $bad) } | Should -Throw
    (Get-FileHash -LiteralPath $script:wsFile).Hash | Should -BeExactly $before
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'rejects cross-root groups before reference effects' {
    $other = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Other/Other.code-workspace')
    Mock Set-WorkspaceSharedVSCodeReference { throw 'Unexpected reference effect' }
    { Invoke-FixtureInitialize @($script:wsFile, $other) } | Should -Throw '*WorkspaceConflict*'
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'rejects incompatible original contexts before reference effects' {
    $other = Write-FixtureWorkspace (Join-Path $script:caseRoot 'Other.code-workspace') 'SharedVSCode-other'
    Mock Set-WorkspaceSharedVSCodeReference { throw 'Unexpected reference effect' }
    { Invoke-FixtureInitialize @($script:wsFile, $other) } | Should -Throw '*WorkspaceConflict*'
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 0 -Exactly
  }
  It 'deduplicates compatible workspace paths before both delegates' {
    Mock Set-WorkspaceSharedVSCodeReference {
      & $script:referenceImplementation -WorkspaceFiles $WorkspaceFiles -TemplateRef $TemplateRef -ProfileName $ProfileName -ErrorAction Stop
    }
    Invoke-FixtureInitialize @($script:wsFile, $script:wsFile)
    Should -Invoke Set-WorkspaceSharedVSCodeReference -Times 1 -Exactly
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 1 -Exactly -ParameterFilter { $WorkspaceFiles.Count -eq 1 }
  }
  It 'restores a known full postimage even when the reference helper then throws' {
    $before = (Get-FileHash -LiteralPath $script:wsFile).Hash
    Mock Set-WorkspaceSharedVSCodeReference {
      & $script:referenceImplementation -WorkspaceFiles $WorkspaceFiles -TemplateRef $TemplateRef -ProfileName $ProfileName -ErrorAction Stop
      throw 'InjectedAfterReferenceWrite'
    }
    { Invoke-FixtureInitialize } | Should -Throw '*InjectedAfterReferenceWrite*'
    (Get-FileHash -LiteralPath $script:wsFile).Hash | Should -BeExactly $before
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'does not adopt an unexpected reference-helper postimage as owned' {
    Mock Set-WorkspaceSharedVSCodeReference { [IO.File]::WriteAllText($script:wsFile, 'unexpected peer-shaped postimage') }
    { Invoke-FixtureInitialize } | Should -Throw '*HeldRecovery: WorkspaceDiverged*'
    [IO.File]::ReadAllText($script:wsFile) | Should -BeExactly 'unexpected peer-shaped postimage'
    Should -Invoke Set-DownstreamSharedVSCodeContext -Times 0 -Exactly
  }
  It 'preserves references and writer-owned outputs when the writer holds recovery' {
    $script:writerOutput = Join-Path $script:caseRoot '.gitconfig.shared'
    Mock Set-DownstreamSharedVSCodeContext {
      [IO.File]::WriteAllText($script:writerOutput, 'held writer output')
      throw [InvalidOperationException]::new('SharedVSCodeWriter.HeldRecovery')
    }
    { Invoke-FixtureInitialize } | Should -Throw '*HeldRecovery: WriterHeldRecovery*'
    (Get-WorkspaceJson $script:wsFile).settings.'atap.sharedVSCode.templateRef' | Should -BeExactly $script:sprintRef
    [IO.File]::ReadAllText($script:writerOutput) | Should -BeExactly 'held writer output'
  }
}
