#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeAll {
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  # Definitions only; its finite Stage/ReadBack helper is mocked below.
  . (Join-Path $PSScriptRoot '../../private/Save-CoordOperation.ps1')
  . (Join-Path $PSScriptRoot '../../private/New-CoordQuartetCandidate.ps1')
  $script:utf8570 = [Text.UTF8Encoding]::new($false, $true)
  function Get-SinglePath590($Value) {
    $values = @($Value)
    if ($values.Count -ne 1 -or $values[0] -isnot [string]) { throw 'InvalidMockPath590' }
    return $values[0]
  }
  function Get-Hash570([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
  }
  function Convert-Element570($Value) {
    $doc = [System.Text.Json.JsonDocument]::Parse((ConvertTo-Json -InputObject $Value -Depth 6 -Compress))
    try { $doc.RootElement.Clone() } finally { $doc.Dispose() }
  }
  function Set-PreviewAfter570([byte[]]$Bytes) {
    $script:preview570.AfterBytes = $Bytes
    $script:preview570.AfterSha256 = Get-Hash570 $Bytes
    $script:preview570.AfterText = $script:utf8570.GetString($Bytes)
  }
  function Invoke-Candidate570([switch]$PreviewOnly) {
    $images = Convert-Element570 $script:images570
    $script:originalImages570 = $images.GetRawText()
    $script:originalPreviewBefore570 = [Convert]::ToBase64String($script:preview570.BeforeBytes)
    $script:originalPreviewAfter570 = [Convert]::ToBase64String($script:preview570.AfterBytes)
    $result = New-CoordQuartetCandidate -Preview $script:preview570 -BeforeImages $images -ScratchRoot $script:scratch570 -WhatIf:$PreviewOnly -Confirm:$false
    $images.GetRawText() | Should -BeExactly $script:originalImages570
    return $result
  }
  $script:foreignCommand570 = Get-Command Get-Date
  $script:rendererBody570 = (Get-Command Invoke-CoordQuartetCandidateRender -CommandType Function).ScriptBlock
}

Describe 'Scratch-only quartet candidate construction' -Tag 'Unit' {
  BeforeEach {
    $script:scratch570 = 'D:\ATAPArtifacts\Sprint0017\Task17.30.a\QuartetCandidate570\Scratch-570'
    $script:markdown570 = Join-Path $script:scratch570 'Tasks.Sprint0017.md'
    $script:html570 = Join-Path $script:scratch570 'Tasks.Sprint0017.html'
    $script:rootMade570 = $false; $script:alreadyExists570 = $false
    $script:renderFailure570 = ''; $script:metadataFailure570 = ''
    $script:io570 = @{}
    $script:ioPaths570 = [Collections.Generic.List[string]]::new()
    $script:metadata570 = @{}
    $script:images570 = [ordered]@{}
    $before = $script:utf8570.GetBytes("# Current Sprint: fixture`n`n## Goal`nPreserve.`n`n## Stream C - fixture`n- [ ] **Task 17.30** [ATAP.Utilities] - Fixture`n  - Status: Planned.`n")
    $after = $script:utf8570.GetBytes($script:utf8570.GetString($before).Replace('Planned.', 'CLAIMED.'))
    $slotPaths = [ordered]@{
      markdown = 'C:\Synthetic\Tasks.Sprint0017.md'
      boardHtml = 'C:\Synthetic\Tasks.Sprint0017.html'
      proceduralDetailsHtml = 'C:\Synthetic\Tasks.Sprint0017.ProceduralDetails.html'
      accomplishedHtml = 'C:\Synthetic\Tasks.Sprint0017.Accomplished.html'
    }
    foreach ($slot in $slotPaths.Keys) {
      $fixtureBytes = @{
        markdown = $before; boardHtml = $script:utf8570.GetBytes('old board')
        proceduralDetailsHtml = [byte[]]@(239, 187, 191, 13, 10, 0, 255)
        accomplishedHtml = [byte[]]@()
      }
      [byte[]]$bytes = $fixtureBytes[$slot]
      $script:images570[$slot] = [ordered]@{
        path = $slotPaths[$slot]; bytesBase64 = [Convert]::ToBase64String($bytes); digest = Get-Hash570 $bytes
      }
    }
    $script:preview570 = [PSCustomObject]@{
      Stage = 'ProposedNotPrepared'; RequestId = 'synthetic-request'; TaskId = '17.30'
      Generation = 'synthetic-epoch'; BaseRevision = 'synthetic-head'
      BeforeSha256 = Get-Hash570 $before; AfterSha256 = Get-Hash570 $after
      BeforeBytes = $before.Clone(); AfterBytes = $after.Clone()
      AfterText = $script:utf8570.GetString($after); Reservations = (Convert-Element570 @())
    }
    $script:renderBytes570 = $script:utf8570.GetBytes('<html>candidate</html>')
    $script:originalPreviewBefore570 = [Convert]::ToBase64String($script:preview570.BeforeBytes)
    $script:originalPreviewAfter570 = [Convert]::ToBase64String($script:preview570.AfterBytes)
    $script:originalMap570 = ConvertTo-Json -InputObject $script:images570 -Compress -Depth 6
    foreach ($leaf in @($slotPaths.Values) + @($script:markdown570, $script:html570, $script:scratch570)) {
      $current = $leaf
      $container = $leaf -eq $script:scratch570
      while ($current) {
        if (-not $script:metadata570.ContainsKey($current)) {
          $script:metadata570[$current] = [PSCustomObject]@{
            FullName = $current; PSIsContainer = [bool]$container; LinkType = $null
            Attributes = $(if ($container) { [IO.FileAttributes]::Directory } else { [IO.FileAttributes]::Normal })
            PSProvider = [PSCustomObject]@{ Name = 'FileSystem' }
          }
        }
        $current = [IO.Path]::GetDirectoryName($current); $container = $true
      }
    }
    $script:adapterTrace602 = [Collections.Generic.List[string]]::new()
    Mock Import-Module {
      if ($FullyQualifiedName.Count -ne 1 -or
          $FullyQualifiedName[0].Name -cne 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -or
          $FullyQualifiedName[0].RequiredVersion -ne [version]'0.1.61' -or $Force -or $PassThru) {
        throw 'UnexpectedModuleImport602'
      }
      $script:adapterTrace602.Add('import')
    }
    Mock Write-PSFMessage {}
    Mock Test-Path {
      $LiteralPath = Get-SinglePath590 $LiteralPath
      if ($LiteralPath -eq $script:scratch570) { return ($script:alreadyExists570 -or $script:rootMade570) }
      if ($LiteralPath -in @($script:markdown570, $script:html570)) { return $script:io570.ContainsKey($LiteralPath) }
      throw 'UnexpectedExistenceProbe570'
    }
    Mock Get-Item {
      $LiteralPath = Get-SinglePath590 $LiteralPath
      if (-not $script:metadata570.ContainsKey($LiteralPath)) { throw 'UnknownMetadata570' }
      if ($LiteralPath -eq $script:html570 -and -not $script:io570.ContainsKey($LiteralPath)) { throw 'MissingRenderedFile570' }
      return $script:metadata570[$LiteralPath]
    }
    Mock New-Item {
      $Path = Get-SinglePath590 $Path
      if ($Path -ne $script:scratch570 -or $ItemType -ne 'Directory' -or $Force) { throw 'UnexpectedDirectoryCreation570' }
      $script:rootMade570 = $true
    }
    Mock Invoke-CoordOperationFileIo {
      if ($StatePath -notin @($script:markdown570, $script:html570)) { throw 'ForbiddenLiveContentAccess570' }
      $script:ioPaths570.Add($Phase + ':' + $StatePath)
      switch ($Phase) {
        Stage {
          if ($StagePath -notin @($script:markdown570, $script:html570) -or $StatePath -ne $StagePath -or $script:io570.ContainsKey($StatePath)) { throw 'UnexpectedStage570' }
          [object]::ReferenceEquals($Bytes, $script:preview570.AfterBytes) | Should -BeFalse
          $script:io570[$StatePath] = $Bytes.Clone()
        }
        ReadBack {
          if (-not $script:io570.ContainsKey($StatePath)) { throw 'MissingScratchContent570' }
          return ,([byte[]]$script:io570[$StatePath].Clone())
        }
        default { throw 'ForbiddenPublicationPhase570' }
      }
    }
    Mock Invoke-CoordQuartetCandidateRender {
      if ($TasksFilePath -ne $script:markdown570 -or $OutputPath -ne $script:html570) { throw 'UnexpectedRendererPath570' }
      if ($script:renderFailure570 -eq 'throw') { throw 'SyntheticRendererFailure570' }
      $script:io570[$OutputPath] = $script:renderBytes570.Clone()
      if ($script:renderFailure570 -eq 'markdown mutation') {
        $script:io570[$TasksFilePath] = $script:utf8570.GetBytes("changed`n")
      }
      [PSCustomObject]@{
        TasksFilePath = $TasksFilePath
        OutputPath = $(if ($script:renderFailure570 -eq 'wrong output') { 'C:\Live\board.html' } else { $OutputPath })
        ReconciliationReportPath = $(if ($script:renderFailure570 -eq 'report') { Join-Path $script:scratch570 '_generated/report.json' } else { $null })
      }
    }
  }
  AfterEach {
    [Convert]::ToBase64String($script:preview570.BeforeBytes) | Should -BeExactly $script:originalPreviewBefore570
    [Convert]::ToBase64String($script:preview570.AfterBytes) | Should -BeExactly $script:originalPreviewAfter570
    # Tests that deliberately change the map refresh this independent pre-call oracle.
    (ConvertTo-Json -InputObject $script:images570 -Compress -Depth 6) | Should -BeExactly $script:originalMap570
  }

  It 'renders once from exact staged preview bytes and preserves both opaque companions' {
    $result = Invoke-Candidate570
    $result.Stage | Should -BeExactly 'CandidateNotPrepared'
    $result.Action | Should -BeExactly 'Rendered'
    $result.ScratchRoot | Should -BeExactly $script:scratch570
    foreach ($slot in @('proceduralDetailsHtml', 'accomplishedHtml')) {
      $result.AfterOutputs.GetProperty($slot).GetProperty('bytesBase64').GetString() | Should -BeExactly $script:images570[$slot].bytesBase64
      $result.AfterOutputs.GetProperty($slot).GetProperty('digest').GetString() | Should -BeExactly $script:images570[$slot].digest
    }
    $result.AfterOutputs.GetProperty('markdown').GetProperty('bytesBase64').GetString() | Should -BeExactly ([Convert]::ToBase64String($script:preview570.AfterBytes))
    $result.AfterOutputs.GetProperty('boardHtml').GetProperty('bytesBase64').GetString() | Should -BeExactly ([Convert]::ToBase64String($script:renderBytes570))
    foreach ($slot in $script:images570.Keys) {
      $result.AfterOutputs.GetProperty($slot).GetProperty('path').GetString() | Should -BeExactly $script:images570[$slot].path
    }
    $result.BeforeOutputs.GetRawText() | Should -BeExactly (Convert-Element570 $script:images570).GetRawText()
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 1 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 2 -Exactly -Scope It -ParameterFilter { $Phase -eq 'Stage' }
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It -ParameterFilter { $Phase -eq 'Replace' }
  }

  It 'returns unchanged images without renderer, content, metadata or staging calls' {
    Set-PreviewAfter570 $script:preview570.BeforeBytes.Clone()
    $result = Invoke-Candidate570
    $result.Action | Should -BeExactly 'Unchanged'
    $result.AfterOutputs.GetRawText() | Should -BeExactly $result.BeforeOutputs.GetRawText()
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It
    Should -Invoke Get-Item -Times 0 -Exactly -Scope It
    Should -Invoke New-Item -Times 0 -Exactly -Scope It
  }

  It 'WhatIf has no candidate after-images or renderer/IO/metadata effects' {
    $result = Invoke-Candidate570 -PreviewOnly
    $result.Action | Should -BeExactly 'ProposedOnly'
    $result.AfterOutputs | Should -BeNullOrEmpty
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It
    Should -Invoke Get-Item -Times 0 -Exactly -Scope It
    Should -Invoke New-Item -Times 0 -Exactly -Scope It
    Should -Invoke Import-Module -Times 0 -Exactly -Scope It
  }

  It 'rejects malformed image or path <Fault> before renderer and IO' -ForEach @(
    @{ Fault = 'missing companion' }; @{ Fault = 'extra member' }; @{ Fault = 'base64 whitespace' }
    @{ Fault = 'base64 pad bits' }; @{ Fault = 'wrong digest' }; @{ Fault = 'case alias' }
    @{ Fault = 'parent alias' }; @{ Fault = 'short alias' }; @{ Fault = 'UNC path' }; @{ Fault = 'device alias' }
  ) {
    switch ($Fault) {
      'missing companion' { $script:images570.Remove('accomplishedHtml') }
      'extra member' { $script:images570.markdown.extra = 'unbound' }
      'base64 whitespace' { $script:images570.boardHtml.bytesBase64 += ' ' }
      'base64 pad bits' { $script:images570.boardHtml.bytesBase64 = 'Zh=='; $script:images570.boardHtml.digest = Get-Hash570 ([byte[]]@(102)) }
      'wrong digest' { $script:images570.markdown.digest = '0' * 64 }
      'case alias' { $script:images570.boardHtml.path = $script:images570.markdown.path.ToLowerInvariant() }
      'parent alias' { $script:images570.boardHtml.path = 'C:\Synthetic\child\..\Tasks.html' }
      'short alias' { $script:images570.boardHtml.path = 'C:\Synthe~1\Tasks.html' }
      'UNC path' { $script:images570.boardHtml.path = '\\server\share\Tasks.html' }
      'device alias' { $script:images570.boardHtml.path = 'C:\Synthetic\NUL.html' }
    }
    $script:originalMap570 = ConvertTo-Json -InputObject $script:images570 -Compress -Depth 6
    { Invoke-Candidate570 } | Should -Throw '*refused at Validation*'
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It
  }

  It 'rejects unbound preview <Fault> before staging' -ForEach @(
    @{ Fault = 'stage' }; @{ Fault = 'before digest' }; @{ Fault = 'after digest' }
    @{ Fault = 'after text' }; @{ Fault = 'CR after bytes' }; @{ Fault = 'BOM after bytes' }
  ) {
    switch ($Fault) {
      'stage' { $script:preview570.Stage = 'Prepared' }
      'before digest' { $script:preview570.BeforeSha256 = '0' * 64 }
      'after digest' { $script:preview570.AfterSha256 = '0' * 64 }
      'after text' { $script:preview570.AfterText += 'unbound' }
      'CR after bytes' { Set-PreviewAfter570 $script:utf8570.GetBytes("wrong`r`n") }
      'BOM after bytes' { Set-PreviewAfter570 ([byte[]](@(239, 187, 191) + $script:preview570.AfterBytes)) }
    }
    { Invoke-Candidate570 } | Should -Throw '*refused at Validation*'
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
    Should -Invoke New-Item -Times 0 -Exactly -Scope It
  }

  It 'rejects preview property getters without invoking them' {
    $script:getterCalls570 = 0
    $script:preview570.PSObject.Properties.Remove('AfterText')
    $script:preview570 | Add-Member -MemberType ScriptProperty -Name AfterText -Value { $script:getterCalls570++; 'unbound' }
    { Invoke-Candidate570 } | Should -Throw '*refused at Validation*'
    $script:getterCalls570 | Should -Be 0
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
  }

  It 'rejects scratch <Fault> without renderer or content access' -ForEach @(
    @{ Fault = 'existing' }; @{ Fault = 'outside D' }; @{ Fault = 'live overlap' }
  ) {
    switch ($Fault) {
      'existing' { $script:alreadyExists570 = $true }
      'outside D' { $script:scratch570 = 'C:\Synthetic\fresh' }
      'live overlap' { $script:images570.markdown.path = $script:markdown570 }
    }
    $script:originalMap570 = ConvertTo-Json -InputObject $script:images570 -Compress -Depth 6
    { Invoke-Candidate570 } | Should -Throw '*refused at*'
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It
  }

  It 'refuses exact path metadata <Fault> before staging' -ForEach @(
    @{ Fault = 'hard link' }; @{ Fault = 'ancestor reparse' }; @{ Fault = 'unknown link metadata' }; @{ Fault = 'missing live file' }
  ) {
    $live = $script:images570.markdown.path
    switch ($Fault) {
      'hard link' { $script:metadata570[$live].LinkType = 'HardLink' }
      'ancestor reparse' { $script:metadata570['C:\Synthetic'].Attributes = [IO.FileAttributes]::ReparsePoint }
      'unknown link metadata' { $script:metadata570[$live].PSObject.Properties.Remove('LinkType') }
      'missing live file' { $script:metadata570.Remove($live) }
    }
    { Invoke-Candidate570 } | Should -Throw '*refused at ScratchValidation*'
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 0 -Exactly -Scope It
    Should -Invoke Invoke-CoordOperationFileIo -Times 0 -Exactly -Scope It
  }

  It 'retains scratch evidence and refuses renderer/capture failure <Fault>' -ForEach @(
    @{ Fault = 'throw' }; @{ Fault = 'wrong output' }; @{ Fault = 'report' }
    @{ Fault = 'markdown mutation' }; @{ Fault = 'CR output' }; @{ Fault = 'invalid UTF8 output' }
  ) {
    if ($Fault -eq 'CR output') { $script:renderBytes570 = $script:utf8570.GetBytes("<html>`r`n</html>") }
    elseif ($Fault -eq 'invalid UTF8 output') { $script:renderBytes570 = [byte[]]@(255) }
    else { $script:renderFailure570 = $Fault }
    $caught = $null
    try { Invoke-Candidate570 } catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $expectedPhase = if ($Fault -in @('throw', 'wrong output', 'report')) { 'Render' } else { 'Capture' }
    $caught.Exception.Data['Phase'] | Should -BeExactly $expectedPhase
    $caught.Exception.Data['ScratchRoot'] | Should -BeExactly $script:scratch570
    $script:rootMade570 | Should -BeTrue
    $script:io570.ContainsKey($script:markdown570) | Should -BeTrue
    Should -Invoke Invoke-CoordQuartetCandidateRender -Times 1 -Exactly -Scope It
    Should -Invoke New-Item -Times 1 -Exactly -Scope It
  }

  It 'refuses unrecognized renderer metadata through the fixed installed lookup' {
    Mock Get-Command {
      $script:adapterTrace602.Add('lookup')
      $script:foreignCommand570
    } -ParameterFilter { $Name -eq 'Convert-TasksMdToSprintBoard' }
    { & $script:rendererBody570 -TasksFilePath $script:markdown570 -OutputPath $script:html570 -Confirm:$false } |
      Should -Throw '*RendererUnavailable*'
    ($script:adapterTrace602 -join '|') | Should -BeExactly 'import|lookup'
    Should -Invoke Import-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $FullyQualifiedName.Count -eq 1 -and
      $FullyQualifiedName[0].Name -eq 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -and
      $FullyQualifiedName[0].RequiredVersion -eq [version]'0.1.61' -and -not $Force -and -not $PassThru
    }
    Should -Invoke Get-Command -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'Convert-TasksMdToSprintBoard' -and
      $FullyQualifiedModule[0].Name -eq 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -and
      $FullyQualifiedModule[0].RequiredVersion -eq [version]'0.1.61'
    }
  }

  It 'stops before lookup when the pinned module import fails' {
    Mock Import-Module { throw 'SyntheticPinnedImportFailure602' }
    Mock Get-Command { throw 'Lookup must not occur after failed import' } -ParameterFilter { $Name -eq 'Convert-TasksMdToSprintBoard' }
    { & $script:rendererBody570 -TasksFilePath $script:markdown570 -OutputPath $script:html570 -Confirm:$false } |
      Should -Throw '*SyntheticPinnedImportFailure602*'
    Should -Invoke Import-Module -Times 1 -Exactly -Scope It
    Should -Invoke Get-Command -Times 0 -Exactly -Scope It -ParameterFilter { $Name -eq 'Convert-TasksMdToSprintBoard' }
  }

  It 'declares a single pinned import before the original strict command lookup' {
    $tokens602 = $null; $errors602 = $null
    $ast602 = [Management.Automation.Language.Parser]::ParseInput($script:rendererBody570.ToString(), [ref]$tokens602, [ref]$errors602)
    $errors602.Count | Should -Be 0
    $imports602 = @($ast602.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Import-Module' }, $true))
    $lookups602 = @($ast602.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Get-Command' }, $true))
    $imports602.Count | Should -Be 1
    $lookups602.Count | Should -Be 1
    $imports602[0].Extent.StartOffset | Should -BeLessThan $lookups602[0].Extent.StartOffset
    @($imports602[0].CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'FullyQualifiedName' }).Count | Should -Be 1
    @($imports602[0].CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -in @('Force','PassThru') }).Count | Should -Be 0
  }
}
