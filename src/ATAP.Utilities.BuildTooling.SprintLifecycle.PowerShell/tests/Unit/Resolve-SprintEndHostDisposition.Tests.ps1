BeforeAll {
  Import-Module PSFramework -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/Resolve-SprintEndHostDisposition.ps1')

  function New-HostDispositionFixture {
    [PSCustomObject]@{
      SchemaVersion = 1
      DispositionId = 'Sprint0015-UTAT01-whertzing'
      HostName = 'UTAT01'
      Identity = 'UTAT01\whertzing'
      LoginTaskMode = 'ExpectedAbsent'
      PersonalVaultSessionScopes = @('User', 'Process')
    }
  }
}

Describe 'Resolve-SprintEndHostDisposition explicit contract' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Get-SprintEndHostContext {
      [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'UTAT01\whertzing'; IsElevated = $true }
    }
  }

  It 'returns strict defaults without reading actual host identity or elevation' {
    $result = Resolve-SprintEndHostDisposition

    $result.IsExplicit | Should -BeFalse
    $result.LoginTaskMode | Should -Be 'RetainedPair'
    $result.PersonalVaultSessionScopes.Count | Should -Be 0
    $result.Metadata | Should -BeNullOrEmpty
    $result.HostName | Should -BeNullOrEmpty
    $result.Identity | Should -BeNullOrEmpty
    $result.IsElevated | Should -BeFalse
    Should -Invoke Get-SprintEndHostContext -Times 0 -Exactly
  }

  It 'rejects explicit null instead of selecting strict defaults' {
    { Resolve-SprintEndHostDisposition -HostDisposition $null } | Should -Throw '*non-null six-field object*'
    Should -Invoke Get-SprintEndHostContext -Times 0 -Exactly
  }

  It 'accepts exact identity binding and produces detached six-field forwarding metadata' {
    $disposition = New-HostDispositionFixture

    $result = Resolve-SprintEndHostDisposition -HostDisposition $disposition

    $result.IsExplicit | Should -BeTrue
    $result.IsElevated | Should -BeTrue
    $result.PersonalVaultSessionScopes | Should -Be @('User', 'Process')
    @($result.Metadata.PSObject.Properties.Name) | Should -Be @('SchemaVersion', 'DispositionId', 'HostName', 'Identity', 'LoginTaskMode', 'PersonalVaultSessionScopes')
    $disposition.PersonalVaultSessionScopes[0] = 'Machine'
    $result.Metadata.PersonalVaultSessionScopes | Should -Be @('User', 'Process')
    $result.Metadata.PersonalVaultSessionScopes[0] = 'Machine'
    $result.PersonalVaultSessionScopes | Should -Be @('User', 'Process')
    Should -Invoke Get-SprintEndHostContext -Times 1 -Exactly
  }

  It 'normalizes case and scope order without treating domain aliases as equivalent' {
    $disposition = New-HostDispositionFixture
    $disposition.HostName = 'utat01'
    $disposition.Identity = 'utat01\WHERTZING'
    $disposition.LoginTaskMode = 'expectedabsent'
    $disposition.PersonalVaultSessionScopes = @('process', 'user')

    $result = Resolve-SprintEndHostDisposition -HostDisposition $disposition

    $result.HostName | Should -BeExactly 'UTAT01'
    $result.Identity | Should -BeExactly 'UTAT01\whertzing'
    $result.LoginTaskMode | Should -BeExactly 'ExpectedAbsent'
    $result.PersonalVaultSessionScopes | Should -Be @('User', 'Process')
  }

  It 'accepts a normal hashtable and integer JSON-style schema version' {
    $disposition = @{
      SchemaVersion = [long]1
      DispositionId = 'Explicit-RetainedPair'
      HostName = 'UTAT01'
      Identity = 'UTAT01\whertzing'
      LoginTaskMode = 'RetainedPair'
      PersonalVaultSessionScopes = @()
    }

    $result = Resolve-SprintEndHostDisposition -HostDisposition $disposition

    $result.LoginTaskMode | Should -Be 'RetainedPair'
    $result.PersonalVaultSessionScopes.Count | Should -Be 0
    $result.Metadata.SchemaVersion | Should -BeOfType ([int])
  }

  It 'reports actual unelevated context without inventing absence visibility' {
    Mock Get-SprintEndHostContext {
      [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'UTAT01\whertzing'; IsElevated = $false }
    }

    $result = Resolve-SprintEndHostDisposition -HostDisposition (New-HostDispositionFixture)

    $result.IsElevated | Should -BeFalse
    $result.Metadata.PSObject.Properties.Name | Should -Not -Contain 'IsElevated'
  }

  It 'rejects missing field <Field>' -ForEach @(
    @{ Field = 'SchemaVersion' }
    @{ Field = 'DispositionId' }
    @{ Field = 'HostName' }
    @{ Field = 'Identity' }
    @{ Field = 'LoginTaskMode' }
    @{ Field = 'PersonalVaultSessionScopes' }
  ) {
    $disposition = New-HostDispositionFixture
    $disposition.PSObject.Properties.Remove($Field)

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*exactly the six documented fields*'
  }

  It 'rejects arbitrary additional fields instead of carrying credential exceptions' {
    $disposition = New-HostDispositionFixture
    $disposition | Add-Member -NotePropertyName AllowedEnvironmentVariables -NotePropertyValue @('BWS_ACCESS_TOKEN')

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*exactly the six documented fields*'
  }

  It 'rejects duplicate case-insensitive dictionary fields' {
    $disposition = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($property in (New-HostDispositionFixture).PSObject.Properties) { $disposition.Add($property.Name, $property.Value) }
    $disposition.Add('hostname', 'UTAT01')

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*duplicate field*'
  }

  It 'rejects executable script properties without invoking their getters' {
    $disposition = New-HostDispositionFixture
    $disposition.PSObject.Properties.Remove('HostName')
    $disposition | Add-Member -MemberType ScriptProperty -Name HostName -Value { throw 'getter must never execute' }

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*note properties only*'
  }

  It 'rejects invalid schema <Case>' -ForEach @(
    @{ Case = 'boolean'; Value = $true }
    @{ Case = 'string'; Value = '1' }
    @{ Case = 'floating-point'; Value = 1.0 }
    @{ Case = 'future'; Value = 2 }
    @{ Case = 'null'; Value = $null }
  ) {
    $disposition = New-HostDispositionFixture
    $disposition.SchemaVersion = $Value

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*integer 1*'
  }

  It 'rejects malformed metadata <Case>' -ForEach @(
    @{ Case = 'blank-id'; Field = 'DispositionId'; Value = '' }
    @{ Case = 'id-injection'; Field = 'DispositionId'; Value = "id'; invoke-x" }
    @{ Case = 'long-id'; Field = 'DispositionId'; Value = ('a' * 81) }
    @{ Case = 'wildcard-host'; Field = 'HostName'; Value = 'UTAT*' }
    @{ Case = 'host-qualifier'; Field = 'HostName'; Value = 'UTAT01.example' }
    @{ Case = 'host-whitespace'; Field = 'HostName'; Value = ' UTAT01' }
    @{ Case = 'unqualified-identity'; Field = 'Identity'; Value = 'whertzing' }
    @{ Case = 'identity-wildcard'; Field = 'Identity'; Value = 'UTAT01\*' }
    @{ Case = 'identity-trailing-space'; Field = 'Identity'; Value = 'UTAT01\whertzing ' }
    @{ Case = 'identity-extra-domain'; Field = 'Identity'; Value = 'UTAT01\other\whertzing' }
    @{ Case = 'unknown-mode'; Field = 'LoginTaskMode'; Value = 'Auto' }
  ) {
    $disposition = New-HostDispositionFixture
    $disposition.$Field = $Value

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw
    Should -Invoke Get-SprintEndHostContext -Times 0 -Exactly
  }

  It 'rejects policy binding mismatch <Case>' -ForEach @(
    @{ Case = 'host'; Field = 'HostName'; Value = 'UTAT022' }
    @{ Case = 'domain'; Field = 'Identity'; Value = 'OTHER\whertzing' }
    @{ Case = 'user'; Field = 'Identity'; Value = 'UTAT01\other' }
  ) {
    $disposition = New-HostDispositionFixture
    $disposition.PersonalVaultSessionScopes = @()
    $disposition.$Field = $Value

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*does not match*'
  }

  It 'rejects unsupported personal-vault scope declaration <Case>' -ForEach @(
    @{ Case = 'scalar'; Value = 'User' }
    @{ Case = 'null'; Value = $null }
    @{ Case = 'machine'; Value = @('Machine') }
    @{ Case = 'duplicate'; Value = @('User', 'user') }
    @{ Case = 'automation'; Value = @('BWS_ACCESS_TOKEN') }
    @{ Case = 'nonstring'; Value = @(1) }
    @{ Case = 'padded'; Value = @(' User') }
  ) {
    $disposition = New-HostDispositionFixture
    $disposition.PersonalVaultSessionScopes = $Value

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*HostDisposition*'
  }

  It 'does not extend personal-vault allowance to a service identity' {
    $disposition = New-HostDispositionFixture
    $disposition.Identity = 'UTAT01\svcBuildMaster'
    Mock Get-SprintEndHostContext {
      [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'UTAT01\svcBuildMaster'; IsElevated = $true }
    }

    { Resolve-SprintEndHostDisposition -HostDisposition $disposition } | Should -Throw '*whertzing account*'
  }

  It 'allows a fully bound service disposition without personal-vault scopes' {
    $disposition = New-HostDispositionFixture
    $disposition.Identity = 'NT AUTHORITY\SYSTEM'
    $disposition.PersonalVaultSessionScopes = @()
    Mock Get-SprintEndHostContext {
      [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'NT AUTHORITY\SYSTEM'; IsElevated = $true }
    }

    $result = Resolve-SprintEndHostDisposition -HostDisposition $disposition

    $result.Identity | Should -Be 'NT AUTHORITY\SYSTEM'
    $result.PersonalVaultSessionScopes.Count | Should -Be 0
  }

  It 'fails when trusted context is unavailable' {
    Mock Get-SprintEndHostContext { throw 'context unavailable' }

    { Resolve-SprintEndHostDisposition -HostDisposition (New-HostDispositionFixture) } | Should -Throw '*context unavailable*'
  }

  It 'rejects unresolved or malformed runtime context <Case>' -ForEach @(
    @{ Case = 'null'; Context = $null }
    @{ Case = 'empty-host'; Context = [PSCustomObject]@{ HostName = ''; Identity = 'UTAT01\whertzing'; IsElevated = $true } }
    @{ Case = 'unqualified-identity'; Context = [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'whertzing'; IsElevated = $true } }
    @{ Case = 'missing-elevation'; Context = [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'UTAT01\whertzing' } }
    @{ Case = 'string-elevation'; Context = [PSCustomObject]@{ HostName = 'UTAT01'; Identity = 'UTAT01\whertzing'; IsElevated = 'true' } }
  ) {
    $script:badContext = $Context
    Mock Get-SprintEndHostContext { $script:badContext }

    { Resolve-SprintEndHostDisposition -HostDisposition (New-HostDispositionFixture) } | Should -Throw '*context could not be established*'
  }
}

Describe 'Test-SprintEndEnvironmentVariablePresent metadata contract' -Tag 'Unit' {
  It 'returns only false for an absent synthetic process name without mutation' {
    $result = @(Test-SprintEndEnvironmentVariablePresent -Name ('SPRINT_END_ABSENT_' + [Guid]::NewGuid().ToString('N')) -Scope Process)

    $result.Count | Should -Be 1
    $result[0] | Should -BeOfType ([bool])
    $result[0] | Should -BeFalse
  }

  It 'returns only boolean presence for existing nonsecret process metadata' {
    $result = @(Test-SprintEndEnvironmentVariablePresent -Name 'PSModulePath' -Scope Process)

    $result.Count | Should -Be 1
    $result[0] | Should -BeOfType ([bool])
    $result[0] | Should -BeTrue
  }

  It 'rejects unsupported scope before reading anything' {
    { Test-SprintEndEnvironmentVariablePresent -Name 'UNREAD' -Scope Registry } | Should -Throw
  }
}
