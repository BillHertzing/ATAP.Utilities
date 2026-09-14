#Requires -Version 7.0

BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message, $Tag) }
    $script:CreatedWritePsfTestDouble = $true
  }
  if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
    function global:Get-PVal { throw 'Get-PVal test double was not configured.' }
    $script:CreatedGetPValTestDouble = $true
  }
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:helperPath = Join-Path $script:moduleRoot 'private\Set-CorpusFileSystemAcl.ps1'
  $script:functionPath = Join-Path $script:moduleRoot 'public\Initialize-CorpusStorageBoundary.ps1'
  . $script:helperPath
  . $script:functionPath
  $script:captureSid = 'S-1-5-19'
  $script:expirySid = 'S-1-5-20'
  $script:isAdministrator = if ($IsWindows) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal `
      -ArgumentList @($identity)
    $principal.IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)
  } else { $false }

  function New-BoundaryFixture {
    param([string]$Name, [switch]$CreateRoots)
    $parent = Join-Path $TestDrive "$Name-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $fixture = [pscustomobject]@{
      Parent = $parent
      Conversation = Join-Path $parent 'CorpusAIConversation'
      Gather = Join-Path $parent 'CorpusGatherRecords'
      Staging = Join-Path $parent 'CorpusGatherRecordsStaging'
    }
    if ($CreateRoots) {
      New-Item -ItemType Directory -Path $fixture.Conversation,$fixture.Gather,$fixture.Staging -Force | Out-Null
    }
    $fixture
  }

  function Invoke-Boundary {
    param($Fixture, [switch]$WhatIf)
    $arguments = @{
      CorpusAIConversationPath = $Fixture.Conversation
      CorpusGatherRecordsPath = $Fixture.Gather
      CorpusGatherRecordsStagingPath = $Fixture.Staging
      CaptureIdentity = $script:captureSid
      ExpiryIdentity = $script:expirySid
      Confirm = $false
    }
    if ($WhatIf) { $arguments.WhatIf = $true }
    Initialize-CorpusStorageBoundary @arguments
  }
}

AfterAll {
  if ($script:CreatedGetPValTestDouble) { Remove-Item Function:\Get-PVal -ErrorAction SilentlyContinue }
  if ($script:CreatedWritePsfTestDouble) { Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue }
}

Describe 'Initialize-CorpusStorageBoundary [public]' -Tag Unit {
  Context 'Command and load surface' {
    It 'defines only eponymous advanced functions with no top-level executable code' {
      foreach ($path in @($script:helperPath,$script:functionPath)) {
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
        $errors | Should -BeNullOrEmpty
        @($ast.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }) |
          Should -BeNullOrEmpty
      }
      $command = Get-Command Initialize-CorpusStorageBoundary -CommandType Function
      $command.Parameters.Keys | Should -Contain WhatIf
      $command.Parameters.Keys | Should -Contain Confirm
    }

    It 'uses protected ACLs, PSFramework, and no shell ACL utility' {
      $source = (Get-Content $script:helperPath -Raw) + (Get-Content $script:functionPath -Raw)
      $source | Should -Match 'SetAccessRuleProtection\(\$true, \$false\)'
      $source | Should -Match 'Write-PSFMessage'
      $source | Should -Not -Match 'icacls|cmd\.exe|Write-Host'
    }
  }

  Context 'Fail-closed planning' {
    It 'resolves only the three exact Get-PVal root keys under WhatIf without mutation' {
      $fixture = New-BoundaryFixture 'settings'
      Mock Get-PVal {
        param($ParameterName,$originalPSBoundParameters,$dottedPath)
        if ($ParameterName -ne $dottedPath) { throw 'key mismatch' }
        switch ($ParameterName) {
          CorpusAIConversationPath { $fixture.Conversation }
          CorpusGatherRecordsPath { $fixture.Gather }
          CorpusGatherRecordsStagingPath { $fixture.Staging }
          default { throw "unexpected $ParameterName" }
        }
      }
      $result = Initialize-CorpusStorageBoundary -CaptureIdentity $script:captureSid `
        -ExpiryIdentity $script:expirySid -WhatIf -Confirm:$false
      $result.Ok | Should -BeTrue
      $result.WhatIf | Should -BeTrue
      @($result.Roots).Count | Should -Be 3
      Test-Path $fixture.Conversation | Should -BeFalse
      Should -Invoke Get-PVal -Exactly 3
    }

    It 'does not fall back for explicitly bound null, blank, relative, or ambiguous roots' -ForEach @(
      @{ Value=$null; Match='absolute path' }, @{ Value=' '; Match='absolute path' },
      @{ Value='relative'; Match='absolute path' }, @{ Value=@('C:\a','C:\b'); Match='exactly one' }
    ) {
      $fixture = New-BoundaryFixture 'invalid'
      Mock Get-PVal { throw 'must not fall back' }
      $result = Initialize-CorpusStorageBoundary -CorpusAIConversationPath $Value `
        -CorpusGatherRecordsPath $fixture.Gather -CorpusGatherRecordsStagingPath $fixture.Staging `
        -CaptureIdentity $script:captureSid -ExpiryIdentity $script:expirySid -Confirm:$false
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match $Match
      Should -Invoke Get-PVal -Exactly 0
    }

    It 'rejects equal and ancestor-descendant root overlaps' -ForEach @(
      @{ Kind='equal' }, @{ Kind='descendant' }
    ) {
      $fixture = New-BoundaryFixture "overlap-$Kind"
      if ($Kind -eq 'equal') { $fixture.Staging = $fixture.Gather }
      else { $fixture.Staging = Join-Path $fixture.Gather 'staging' }
      $result = Invoke-Boundary $fixture -WhatIf
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'overlap'
    }

    It 'rejects any cross-volume root set before parent or filesystem probing' -ForEach @(
      @{ Conversation='C:\corpus-conversation'; Gather='Z:\corpus-gather'; Staging='Z:\corpus-staging' },
      @{ Conversation='C:\corpus-conversation'; Gather='C:\corpus-gather'; Staging='Z:\corpus-staging' }
    ) {
      Mock Test-Path { throw 'filesystem probing must not occur for a cross-volume plan' }
      $result = Initialize-CorpusStorageBoundary -CorpusAIConversationPath $Conversation `
        -CorpusGatherRecordsPath $Gather -CorpusGatherRecordsStagingPath $Staging `
        -CaptureIdentity $script:captureSid -ExpiryIdentity $script:expirySid -WhatIf -Confirm:$false
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'one volume.*atomic move'
      Should -Invoke Test-Path -Exactly 0
    }

    It 'rejects a reparse-point ancestor when symbolic links are available' {
      $fixture = New-BoundaryFixture 'reparse'
      $external = Join-Path $TestDrive "external-$([guid]::NewGuid().ToString('N'))"
      $link = Join-Path $fixture.Parent 'linked'
      New-Item -ItemType Directory $external | Out-Null
      try { New-Item -ItemType SymbolicLink -Path $link -Target $external -ErrorAction Stop | Out-Null }
      catch { Set-ItResult -Skipped -Because "symbolic links unavailable: $($_.Exception.Message)"; return }
      $fixture.Conversation = Join-Path $link 'CorpusAIConversation'
      $result = Invoke-Boundary $fixture -WhatIf
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'Reparse traversal'
    }

    It 'rejects a ready non-NTFS volume when one is available' {
      $drive = [IO.DriveInfo]::GetDrives() | Where-Object {
        $_.IsReady -and $_.DriveFormat -ne 'NTFS'
      } | Select-Object -First 1
      if ($null -eq $drive) {
        Set-ItResult -Skipped -Because 'no ready non-NTFS volume is attached'
        return
      }
      $fixture = [pscustomobject]@{
        Conversation = Join-Path $drive.RootDirectory.FullName 'codex-corpus-conversation'
        Gather = Join-Path $drive.RootDirectory.FullName 'codex-corpus-gather'
        Staging = Join-Path $drive.RootDirectory.FullName 'codex-corpus-staging'
      }
      $result = Invoke-Boundary $fixture -WhatIf
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'unsupported filesystem'
    }

    It 'rejects unsafe, unresolved, or identical identities' -ForEach @(
      @{ Capture='S-1-1-0'; Expiry='S-1-5-19'; Match='unsafe' },
      @{ Capture='unresolvable\missing-account'; Expiry='S-1-5-19'; Match='cannot be resolved' },
      @{ Capture='S-1-5-19'; Expiry='S-1-5-19'; Match='distinct' }
    ) {
      $fixture=New-BoundaryFixture 'identity'
      $result=Initialize-CorpusStorageBoundary -CorpusAIConversationPath $fixture.Conversation `
        -CorpusGatherRecordsPath $fixture.Gather -CorpusGatherRecordsStagingPath $fixture.Staging `
        -CaptureIdentity $Capture -ExpiryIdentity $Expiry -WhatIf -Confirm:$false
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match $Match
    }
  }

  Context 'ACL application and rollback' {
    It 'applies create-only immutable roots and mutable staging with protected recovery rules' -Skip:(-not $script:isAdministrator) {
      $fixture=New-BoundaryFixture 'apply'
      $result=Invoke-Boundary $fixture
      $result.Ok | Should -BeTrue
      @($result.Roots | Where-Object Verified).Count | Should -Be 3
      foreach($root in $result.Roots) { (Get-Acl $root.Path).AreAccessRulesProtected | Should -BeTrue }
      $immutableRules=@((Get-Acl $fixture.Gather).GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
      $captureImmutable=@($immutableRules | Where-Object IdentityReference -EQ ([Security.Principal.SecurityIdentifier]::new($script:captureSid)))
      @($captureImmutable | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) -ne 0 }).Count | Should -Be 0
      @($captureImmutable | Where-Object { ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::CreateFiles) -ne 0 }).Count | Should -BeGreaterThan 0
      $stagingRules=@((Get-Acl $fixture.Staging).GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
      @($stagingRules | Where-Object { $_.IdentityReference.Value -eq $script:captureSid -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Modify) -eq [Security.AccessControl.FileSystemRights]::Modify }).Count | Should -BeGreaterThan 0
      @($immutableRules | Where-Object { $_.IdentityReference.Value -eq $script:expirySid -and ($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq [Security.AccessControl.FileSystemRights]::FullControl }).Count | Should -BeGreaterThan 0
    }

    It 'restores an exact captured directory SDDL after a real ACL application' -Skip:(-not $script:isAdministrator) {
      $fixture=New-BoundaryFixture 'exact-restore' -CreateRoots
      $before=(Get-Acl -LiteralPath $fixture.Gather).Sddl
      $applied=Set-CorpusFileSystemAcl -Path $fixture.Gather -BoundaryKind ImmutableDirectory `
        -CaptureIdentity $script:captureSid -ExpiryIdentity $script:expirySid -Confirm:$false
      $restored=Set-CorpusFileSystemAcl -Path $fixture.Gather -RestoreSddl $before -Confirm:$false
      $applied.Verified | Should -BeTrue
      $restored.Verified | Should -BeTrue
      (Get-Acl -LiteralPath $fixture.Gather).Sddl | Should -Be $before
    }

    It 'restores exact SDDL under StrictMode without reading a nonexistent PSCmdlet property' -Skip:(-not $script:isAdministrator) {
      $fixture=New-BoundaryFixture 'strictmode-restore' -CreateRoots
      $before=(Get-Acl -LiteralPath $fixture.Gather).Sddl
      $null=Set-CorpusFileSystemAcl -Path $fixture.Gather -BoundaryKind ImmutableDirectory `
        -CaptureIdentity $script:captureSid -ExpiryIdentity $script:expirySid -Confirm:$false
      $restored = & {
        param($TargetPath,$CapturedSddl)
        Set-StrictMode -Version Latest
        Set-CorpusFileSystemAcl -Path $TargetPath -RestoreSddl $CapturedSddl -Confirm:$false
      } $fixture.Gather $before
      $restored.Applied | Should -BeTrue
      $restored.Verified | Should -BeTrue
      (Get-Acl -LiteralPath $fixture.Gather).Sddl | Should -Be $before
    }

    It 'accepts only kernel auto-inherited flag normalization for an inherited child descriptor' -Skip:(-not $IsWindows) {
      $fixture=New-BoundaryFixture 'normalized-restore' -CreateRoots
      $actualAcl=Get-Acl -LiteralPath $fixture.Gather
      @($actualAcl.Access | Where-Object IsInherited).Count | Should -BeGreaterThan 0
      $actual=[Security.AccessControl.RawSecurityDescriptor]::new($actualAcl.Sddl)
      $flags=[Security.AccessControl.ControlFlags]([uint32]$actual.ControlFlags -bxor
        [uint32][Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited)
      $normalized=[Security.AccessControl.RawSecurityDescriptor]::new(
        $flags,$actual.Owner,$actual.Group,$actual.SystemAcl,$actual.DiscretionaryAcl)
      Mock Set-Acl { }
      $result=Set-CorpusFileSystemAcl -Path $fixture.Gather `
        -RestoreSddl $normalized.GetSddlForm([Security.AccessControl.AccessControlSections]::All) `
        -Confirm:$false
      $result.Verified | Should -BeTrue
      Should -Invoke Set-Acl -Exactly 1
    }

    It 'rejects restore mismatches in ACE bytes, ACE order, or non-normalized control flags' -ForEach @(
      @{ Difference='ace' }, @{ Difference='order' }, @{ Difference='control' }
    ) -Skip:(-not $IsWindows) {
      $fixture=New-BoundaryFixture "descriptor-mismatch-$Difference" -CreateRoots
      $actual=[Security.AccessControl.RawSecurityDescriptor]::new((Get-Acl -LiteralPath $fixture.Gather).Sddl)
      $daclBytes=[byte[]]::new($actual.DiscretionaryAcl.BinaryLength)
      $actual.DiscretionaryAcl.GetBinaryForm($daclBytes,0)
      $dacl=[Security.AccessControl.RawAcl]::new($daclBytes,0)
      $flags=$actual.ControlFlags
      if($Difference -eq 'ace') {
        $knownAce=@($dacl | Where-Object { $_ -is [Security.AccessControl.KnownAce] })[0]
        $knownAce.AccessMask=$knownAce.AccessMask -bxor 1
      } elseif($Difference -eq 'order') {
        $dacl.Count | Should -BeGreaterThan 1
        $first=$dacl[0].Copy(); $second=$dacl[1].Copy()
        $dacl.RemoveAce(1); $dacl.RemoveAce(0)
        $dacl.InsertAce(0,$second); $dacl.InsertAce(1,$first)
      } else {
        $flags=[Security.AccessControl.ControlFlags]([uint32]$flags -bxor
          [uint32][Security.AccessControl.ControlFlags]::DiscretionaryAclProtected)
      }
      $mismatch=[Security.AccessControl.RawSecurityDescriptor]::new(
        $flags,$actual.Owner,$actual.Group,$actual.SystemAcl,$dacl)
      Mock Set-Acl { }
      { Set-CorpusFileSystemAcl -Path $fixture.Gather `
          -RestoreSddl $mismatch.GetSddlForm([Security.AccessControl.AccessControlSections]::All) `
          -Confirm:$false } | Should -Throw '*Exact SDDL restore verification failed*'
    }

    It 'restores exact SDDL after an injected mid-apply failure' {
      $fixture=New-BoundaryFixture 'rollback' -CreateRoots
      $before=@{}; foreach($path in @($fixture.Conversation,$fixture.Gather,$fixture.Staging)){ $before[$path]=(Get-Acl $path).Sddl }
      $script:applyCount=0
      Mock Set-CorpusFileSystemAcl {
        param($Path,$BoundaryKind,$CaptureIdentity,$ExpiryIdentity,$RestoreSddl,$PlanOnly,$Confirm)
        if ($PSBoundParameters.ContainsKey('RestoreSddl')) { return [pscustomobject]@{ Applied=$true; Verified=$true } }
        if ($PlanOnly) { return [pscustomobject]@{ DesiredSddl='planned' } }
        $script:applyCount++
        if ($script:applyCount -eq 2) { throw 'injected apply failure' }
        [pscustomobject]@{ Applied=$true; Verified=$true; AfterOwner='owner'; AfterSddl='after' }
      }
      $result=Invoke-Boundary $fixture
      $result.Ok | Should -BeFalse
      $result.Failure.Message | Should -Match 'injected apply failure'
      @($result.Rollback | Where-Object Restored).Count | Should -Be 2
    }

    It 'removes only newly created empty leaves after an injected failure' {
      $fixture=New-BoundaryFixture 'created-rollback'
      $script:applyCount=0
      Mock Set-CorpusFileSystemAcl {
        param($Path,$BoundaryKind,$CaptureIdentity,$ExpiryIdentity,$RestoreSddl,$PlanOnly,$Confirm)
        if ($PlanOnly) { return [pscustomobject]@{ DesiredSddl='planned' } }
        $script:applyCount++; if($script:applyCount -eq 2){ throw 'injected' }
        [pscustomobject]@{Applied=$true;Verified=$true;AfterOwner='owner';AfterSddl='after'}
      }
      $result=Invoke-Boundary $fixture
      $result.Ok | Should -BeFalse
      Test-Path $fixture.Conversation | Should -BeFalse
      Test-Path $fixture.Gather | Should -BeFalse
      Test-Path $fixture.Staging | Should -BeFalse
      @($result.Rollback | Where-Object RemovedCreatedEmpty).Count | Should -Be 2
    }
  }
}
