#requires -Modules Pester

<#
  Mocked Pester suite for Invoke-RotateSecretsATAP (Sprint 0012 Task 12.55.d).

  This suite NEVER rotates a real secret, never prompts, never touches a real vault, and never
  writes a DPAPI file. Read-Host, Initialize-BWSAccessToken, and Get-BWSAccessToken are all
  mocked, and the "DPAPI files" are an in-memory hashtable.

  It must remain runnable non-interactively in CI (design decision D4.7).

  Signature drift guard: the real Get-BWSAccessToken / Initialize-BWSAccessToken definitions are
  dot-sourced from the BuildTooling *source* tree and promoted to global scope before mocking, so
  Pester builds each mock's parameter metadata from the real function. If -TokenPurpose is ever
  renamed or removed upstream, these tests fail at bind time rather than passing against a stub.
  The source tree is used because the version installed on PSModulePath predates -TokenPurpose
  (Sprint 0012 Tasks 12.50-12.53); that pin lands with Task 12.55.f.
#>

BeforeAll {
  $script:ModuleName = 'ATAP.Utilities.Security.Secrets.PowerShell'
  $script:ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).ProviderPath
  $script:ModulePath = Join-Path $script:ModuleRoot "$script:ModuleName.psd1"

  # Two syntactically valid, obviously fake bws access tokens. Distinct bodies and distinct
  # lengths, so a cross-slot write shows up in both the fingerprint and the length.
  $script:ReadOnlyToken = '0.11111111-1111-1111-1111-111111111111.AAAAAAAAAAAAAAAAAAAAAAAAAAread'
  $script:ReadWriteToken = '0.22222222-2222-2222-2222-222222222222.BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBwrite'

  $buildToolingPublic = Join-Path $script:ModuleRoot '..\ATAP.Utilities.BuildTooling.Secrets.PowerShell\public'
  . (Join-Path $buildToolingPublic 'Get-BWSAccessToken.ps1')
  . (Join-Path $buildToolingPublic 'Initialize-BWSAccessToken.ps1')
  ${function:global:Get-BWSAccessToken} = ${function:Get-BWSAccessToken}
  ${function:global:Initialize-BWSAccessToken} = ${function:Initialize-BWSAccessToken}

  Import-Module -Name $script:ModulePath -Force -ErrorAction Stop

  function New-TestSecureString {
    param([string]$Value)
    ConvertTo-SecureString -String $Value -AsPlainText -Force
  }

  # Fingerprint the same way the function does, so tests can assert on the value it will report
  # without ever reading it back out of a SecureString themselves.
  function Get-TestFingerprint {
    param([string]$Value, [int]$PrefixLength = 12)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $digest = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    ([System.BitConverter]::ToString($digest).Replace('-', '').ToLowerInvariant()).Substring(0, $PrefixLength)
  }
}

AfterAll {
  Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
  Remove-Item -Path 'Function:\global:Get-BWSAccessToken' -ErrorAction SilentlyContinue
  Remove-Item -Path 'Function:\global:Initialize-BWSAccessToken' -ErrorAction SilentlyContinue
  Remove-Variable -Name 'RotateTestState' -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Invoke-RotateSecretsATAP' {

  BeforeEach {
    # Shared mutable state for the mocks. Global because Pester mock bodies execute in the
    # module's session state, not the test file's.
    $global:RotateTestState = [PSCustomObject]@{
      PromptedLabels = [System.Collections.ArrayList]@()
      PasteQueue     = [System.Collections.Queue]::new()
      Store          = @{}   # TokenPurpose -> plaintext, standing in for the DPAPI files
      WriteOrder     = [System.Collections.ArrayList]@()
      FailWriteFor   = $null # TokenPurpose whose Initialize-BWSAccessToken should report failure
      CrossSlotWrite = $false
    }

    Mock -ModuleName $script:ModuleName -CommandName 'Test-RotationSessionIsInteractive' -MockWith { $true }

    Mock -ModuleName $script:ModuleName -CommandName 'Read-Host' -MockWith {
      [void]$global:RotateTestState.PromptedLabels.Add($Prompt)
      $next = $global:RotateTestState.PasteQueue.Dequeue()
      # Read-Host -AsSecureString returns an empty SecureString when the operator presses Enter
      # without typing, and at EOF. ConvertTo-SecureString rejects '', so model that case directly.
      if ([string]::IsNullOrEmpty($next)) { return [System.Security.SecureString]::new() }
      ConvertTo-SecureString -String $next -AsPlainText -Force
    }

    Mock -ModuleName $script:ModuleName -CommandName 'Initialize-BWSAccessToken' -MockWith {
      [void]$global:RotateTestState.WriteOrder.Add($TokenPurpose)
      $plain = [System.Net.NetworkCredential]::new('', $AccessToken).Password

      if ($global:RotateTestState.FailWriteFor -eq $TokenPurpose) {
        return [PSCustomObject]@{ Success = $false; Path = 'T:\fake'; TokenPurpose = $TokenPurpose; TokenLabel = 'x'; Message = 'simulated write failure' }
      }

      # Simulate a DPAPI/cross-slot defect: the bytes land in the other slot.
      $slot = if ($global:RotateTestState.CrossSlotWrite) {
        if ($TokenPurpose -eq 'ReadOnly') { 'ReadWrite' } else { 'ReadOnly' }
      } else { $TokenPurpose }
      $global:RotateTestState.Store[$slot] = $plain

      [PSCustomObject]@{
        Success      = $true
        Path         = "T:\fake\$TokenPurpose.xml"
        TokenPurpose = $TokenPurpose
        TokenLabel   = "CommonCIForBitwarden$TokenPurpose"
        Message      = 'BWS access token stored'
      }
    }

    Mock -ModuleName $script:ModuleName -CommandName 'Get-BWSAccessToken' -MockWith {
      $plain = $global:RotateTestState.Store[$TokenPurpose]
      if ($null -eq $plain) { $plain = 'nothing-was-written' }
      [System.Management.Automation.PSCredential]::new(
        'BWS_ACCESS_TOKEN', (ConvertTo-SecureString -String $plain -AsPlainText -Force))
    }
  }

  Context 'Rotation set (design decision D2 -- closed at exactly two tokens)' {

    It 'plans exactly two rotations, and only the two machine-account tokens' {
      $plan = Invoke-RotateSecretsATAP -WhatIf 4>$null
      $plan.Count | Should -Be 2
      $plan.TokenLabel | Should -Be @('CommonCIForBitwardenReadOnly', 'CommonCIForBitwardenReadWrite')
    }

    It 'rejects any TokenLabel outside the closed set at parameter-binding time' {
      { Invoke-RotateSecretsATAP -TokenLabel 'ProGet.Admin.ApiKey' -WhatIf } |
        Should -Throw -ExpectedMessage '*ProGet.Admin.ApiKey*'
    }

    It 'rotates only the requested subset when -TokenLabel is narrowed' {
      $plan = @(Invoke-RotateSecretsATAP -TokenLabel 'CommonCIForBitwardenReadOnly' -WhatIf 4>$null)
      $plan.Count | Should -Be 1
      $plan[0].TokenPurpose | Should -Be 'ReadOnly'
    }
  }

  Context '-WhatIf dry run (design decision D4.6)' {

    It 'writes nothing' {
      $null = Invoke-RotateSecretsATAP -WhatIf 4>$null
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Initialize-BWSAccessToken' -Times 0 -Exactly
    }

    It 'prompts for nothing' {
      $null = Invoke-RotateSecretsATAP -WhatIf 4>$null
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Read-Host' -Times 0 -Exactly
    }

    It 'does not require an interactive session, so the transcript runs from any shell' {
      Mock -ModuleName $script:ModuleName -CommandName 'Test-RotationSessionIsInteractive' -MockWith { $false }
      { Invoke-RotateSecretsATAP -WhatIf 4>$null } | Should -Not -Throw
    }

    It 'reports the plan without a length or a fingerprint, because nothing was read' {
      $plan = Invoke-RotateSecretsATAP -WhatIf 4>$null
      $plan | ForEach-Object {
        $_.Action | Should -Be 'WouldRotate'
        $_.TokenLength | Should -BeNullOrEmpty
        $_.Fingerprint | Should -BeNullOrEmpty
        $_.Verified | Should -BeFalse
        $_.TokenPath | Should -Match 'BWS_CommonCIForBitwarden(ReadOnly|ReadWrite)_AccessToken\.xml$'
      }
    }
  }

  Context 'Non-interactive live invocation (design decisions D4.1, D4.2 -- the SC-0251 failure mode)' {

    BeforeEach {
      Mock -ModuleName $script:ModuleName -CommandName 'Test-RotationSessionIsInteractive' -MockWith { $false }
    }

    It 'throws one terminating error rather than half-rotating' {
      $err = { Invoke-RotateSecretsATAP -Confirm:$false } | Should -Throw -PassThru
      $err.FullyQualifiedErrorId | Should -BeLike 'NonInteractiveSessionCannotRotate*'
    }

    It 'writes no token file before failing' {
      try { Invoke-RotateSecretsATAP -Confirm:$false } catch { }
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Initialize-BWSAccessToken' -Times 0 -Exactly
    }

    It 'never reaches a prompt, so it can never fall through to an empty value' {
      try { Invoke-RotateSecretsATAP -Confirm:$false } catch { }
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Read-Host' -Times 0 -Exactly
    }

    It 'names the token it could not prompt for and says nothing was written' {
      $err = { Invoke-RotateSecretsATAP -Confirm:$false } | Should -Throw -PassThru
      $err.Exception.Message | Should -Match 'CommonCIForBitwardenReadOnly'
      $err.Exception.Message | Should -Match 'No token file was written'
    }
  }

  Context 'Live rotation, fully mocked' {

    BeforeEach {
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadOnlyToken)
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadWriteToken)
    }

    It 'rotates ReadOnly first and ReadWrite last (design decision D5, self-eviction sequencing)' {
      $null = Invoke-RotateSecretsATAP -Confirm:$false 6>$null
      $global:RotateTestState.WriteOrder | Should -Be @('ReadOnly', 'ReadWrite')
    }

    It 'prompts once per token, each prompt naming its machine account' {
      $null = Invoke-RotateSecretsATAP -Confirm:$false 6>$null
      $global:RotateTestState.PromptedLabels.Count | Should -Be 2
      $global:RotateTestState.PromptedLabels[0] | Should -Match 'CommonCIForBitwardenReadOnly'
      $global:RotateTestState.PromptedLabels[1] | Should -Match 'CommonCIForBitwardenReadWrite'
    }

    It 'reports each pasted value by length and SHA-256 prefix, and verifies the read-back' {
      $results = @(Invoke-RotateSecretsATAP -Confirm:$false 6>$null)
      $results.Count | Should -Be 2

      $results[0].Action | Should -Be 'Rotated'
      $results[0].Verified | Should -BeTrue
      $results[0].TokenLength | Should -Be $script:ReadOnlyToken.Length
      $results[0].Fingerprint | Should -Be (Get-TestFingerprint -Value $script:ReadOnlyToken)

      $results[1].TokenLength | Should -Be $script:ReadWriteToken.Length
      $results[1].Fingerprint | Should -Be (Get-TestFingerprint -Value $script:ReadWriteToken)
    }

    It 'writes each pasted value into the slot it was typed for' {
      $null = Invoke-RotateSecretsATAP -Confirm:$false 6>$null
      $global:RotateTestState.Store['ReadOnly'] | Should -Be $script:ReadOnlyToken
      $global:RotateTestState.Store['ReadWrite'] | Should -Be $script:ReadWriteToken
    }

    It 'routes the read and mutate paths to their own token purposes (design decision D6)' {
      $null = Invoke-RotateSecretsATAP -Confirm:$false 6>$null
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Initialize-BWSAccessToken' -Times 1 -Exactly `
        -ParameterFilter { $TokenPurpose -eq 'ReadWrite' }
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Get-BWSAccessToken' -Times 1 -Exactly `
        -ParameterFilter { $TokenPurpose -eq 'ReadWrite' }
    }
  }

  Context 'Mis-paste guards' {

    It 'refuses an empty paste and writes nothing' {
      $global:RotateTestState.PasteQueue.Enqueue('')
      $err = { Invoke-RotateSecretsATAP -Confirm:$false 6>$null } | Should -Throw -PassThru
      $err.FullyQualifiedErrorId | Should -BeLike 'EmptyTokenValuePasted*'
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Initialize-BWSAccessToken' -Times 0 -Exactly
    }

    It 'refuses a value that is not shaped like a bws access token, and writes nothing' {
      $global:RotateTestState.PasteQueue.Enqueue('CommonCIForBitwardenReadOnly')  # the NAME, not the value
      $err = { Invoke-RotateSecretsATAP -Confirm:$false 6>$null } | Should -Throw -PassThru
      $err.FullyQualifiedErrorId | Should -BeLike 'PastedTokenFailedFormatValidation*'
      Should -Invoke -ModuleName $script:ModuleName -CommandName 'Initialize-BWSAccessToken' -Times 0 -Exactly
    }

    It 'accepts an unrecognized shape when -SkipTokenFormatValidation is passed' {
      $global:RotateTestState.PasteQueue.Enqueue('1.some-future-bitwarden-token-format')
      { Invoke-RotateSecretsATAP -TokenLabel 'CommonCIForBitwardenReadOnly' -SkipTokenFormatValidation -Confirm:$false 6>$null } |
        Should -Not -Throw
    }

    It 'fails the read-back check when the value lands in the wrong slot' {
      # A swapped or cross-written token authenticates on first touch, so it must be caught at
      # write time rather than surfacing later as a confusing permissions error.
      $global:RotateTestState.CrossSlotWrite = $true
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadOnlyToken)
      $err = { Invoke-RotateSecretsATAP -TokenLabel 'CommonCIForBitwardenReadOnly' -Confirm:$false 6>$null } |
        Should -Throw -PassThru
      $err.FullyQualifiedErrorId | Should -BeLike 'TokenReadBackVerificationFailed*'
    }
  }

  Context 'Mid-rotation failure reports actionable state' {

    It 'stops at the failing token and leaves the already-rotated one reported as Rotated' {
      $global:RotateTestState.FailWriteFor = 'ReadWrite'
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadOnlyToken)
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadWriteToken)

      $err = { $null = Invoke-RotateSecretsATAP -Confirm:$false 6>$null } | Should -Throw -PassThru

      $err.FullyQualifiedErrorId | Should -BeLike 'TokenFileWriteFailed*'
      $err.Exception.Message | Should -Match 'CommonCIForBitwardenReadWrite'
      # ReadOnly was written and verified before the failure; ReadWrite was not.
      $global:RotateTestState.Store.ContainsKey('ReadOnly') | Should -BeTrue
      $global:RotateTestState.Store.ContainsKey('ReadWrite') | Should -BeFalse
    }
  }

  Context 'No token value ever leaves the function (design decision D4.4)' {

    It 'never puts a token value in a PSFramework message' {
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadOnlyToken)
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadWriteToken)
      $null = Invoke-RotateSecretsATAP -Confirm:$false 6>$null

      $messages = (Get-PSFMessage | Where-Object { $_.FunctionName -eq 'Invoke-RotateSecretsATAP' }).Message -join "`n"
      $messages | Should -Not -BeNullOrEmpty -Because 'the function must log something to be worth checking'
      $messages | Should -Not -Match ([regex]::Escape($script:ReadOnlyToken))
      $messages | Should -Not -Match ([regex]::Escape($script:ReadWriteToken))
      # The secret body, independent of the 0.<uuid>. prefix.
      $messages | Should -Not -Match 'AAAAAAAAAAAAAAAAAAAAAAAAAAread'
      $messages | Should -Not -Match 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBwrite'
    }

    It 'never puts a token value in an error message' {
      $global:RotateTestState.CrossSlotWrite = $true
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadOnlyToken)
      $err = { Invoke-RotateSecretsATAP -TokenLabel 'CommonCIForBitwardenReadOnly' -Confirm:$false 6>$null } |
        Should -Throw -PassThru
      $err.Exception.Message | Should -Not -Match ([regex]::Escape($script:ReadOnlyToken))
      $err.Exception.Message | Should -Not -Match 'AAAAAAAAAAAAAAAAAAAAAAAAAAread'
    }

    It 'never puts a token value in the returned object' {
      $global:RotateTestState.PasteQueue.Enqueue($script:ReadOnlyToken)
      $results = @(Invoke-RotateSecretsATAP -TokenLabel 'CommonCIForBitwardenReadOnly' -Confirm:$false 6>$null)
      ($results | Out-String) | Should -Not -Match 'AAAAAAAAAAAAAAAAAAAAAAAAAAread'
    }
  }
}

Describe 'Invoke-RotateSecretsATAP private helpers' {

  Context 'Get-SecureStringFingerprint' {

    It 'returns the character length and a SHA-256 prefix of the requested width' {
      InModuleScope -ModuleName $script:ModuleName -Parameters @{ Token = $script:ReadOnlyToken } {
        $fp = Get-SecureStringFingerprint -SecureValue (ConvertTo-SecureString $Token -AsPlainText -Force) -PrefixLength 12
        $fp.Length | Should -Be $Token.Length
        $fp.Fingerprint.Length | Should -Be 12
        $fp.Fingerprint | Should -Match '^[0-9a-f]{12}$'
      }
    }

    It 'gives different fingerprints to the two tokens, which is what makes a swap detectable' {
      InModuleScope -ModuleName $script:ModuleName -Parameters @{ A = $script:ReadOnlyToken; B = $script:ReadWriteToken } {
        $fpA = Get-SecureStringFingerprint -SecureValue (ConvertTo-SecureString $A -AsPlainText -Force)
        $fpB = Get-SecureStringFingerprint -SecureValue (ConvertTo-SecureString $B -AsPlainText -Force)
        $fpA.Fingerprint | Should -Not -Be $fpB.Fingerprint
      }
    }

    It 'reports an empty SecureString as length 0 with no fingerprint' {
      InModuleScope -ModuleName $script:ModuleName {
        $fp = Get-SecureStringFingerprint -SecureValue ([System.Security.SecureString]::new())
        $fp.Length | Should -Be 0
        $fp.Fingerprint | Should -BeNullOrEmpty
      }
    }
  }

  Context 'Test-BWSAccessTokenFormat' {

    It 'accepts a well-formed bws token' {
      InModuleScope -ModuleName $script:ModuleName -Parameters @{ Token = $script:ReadOnlyToken } {
        Test-BWSAccessTokenFormat -SecureValue (ConvertTo-SecureString $Token -AsPlainText -Force) | Should -BeTrue
      }
    }

    It 'rejects <Description>' -ForEach @(
      @{ Description = 'an empty value'; Value = '' }
      @{ Description = 'a secret name pasted instead of a value'; Value = 'CommonCIForBitwardenReadOnly' }
      @{ Description = 'a bare uuid'; Value = '11111111-1111-1111-1111-111111111111' }
      @{ Description = 'a token truncated before the secret body'; Value = '0.11111111-1111-1111-1111-111111111111.' }
      @{ Description = 'a token with a malformed uuid'; Value = '0.not-a-uuid.body' }
    ) {
      InModuleScope -ModuleName $script:ModuleName -Parameters @{ Value = $Value } {
        $secure = if ([string]::IsNullOrEmpty($Value)) {
          [System.Security.SecureString]::new()
        } else {
          ConvertTo-SecureString $Value -AsPlainText -Force
        }
        Test-BWSAccessTokenFormat -SecureValue $secure | Should -BeFalse
      }
    }
  }

  Context 'Test-RotationSessionIsInteractive' {

    # This helper reads real console state, which differs between a hand-typed Invoke-Pester in a
    # terminal (interactive) and a CI or agent shell (redirected stdin). The suite therefore
    # asserts only what is true in both, and the behaviour that depends on it is exercised through
    # a mock in the Invoke-RotateSecretsATAP contexts above.

    It 'returns a boolean, whatever console it finds' {
      InModuleScope -ModuleName $script:ModuleName {
        Test-RotationSessionIsInteractive | Should -BeOfType [bool]
      }
    }

    It 'agrees with the console state this suite is actually running under' {
      InModuleScope -ModuleName $script:ModuleName {
        $expected = [System.Environment]::UserInteractive -and -not [System.Console]::IsInputRedirected
        Test-RotationSessionIsInteractive | Should -Be $expected
      }
    }
  }
}
