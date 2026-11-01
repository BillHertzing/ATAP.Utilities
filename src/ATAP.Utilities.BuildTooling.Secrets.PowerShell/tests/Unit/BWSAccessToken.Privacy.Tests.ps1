# Source/fake-only tests; coordinator separately admits execution.
# No module import, filesystem credential read, DPAPI operation or token lookup.
BeforeAll {
  . (Join-Path $PSScriptRoot '../../public/Get-BWSAccessToken.ps1')

  function Write-PSFMessage {
    param($FunctionName, $ModuleName, $Level, $Message, $ErrorRecord, $Tag)
    throw 'Unmocked token-test logging route'
  }
  function Join-Path {
    param($Path, $ChildPath)
    throw 'Unmocked token-test path route'
  }
  function Test-Path {
    param($LiteralPath)
    throw 'Unmocked token-test existence route'
  }
  function Import-Clixml {
    [CmdletBinding()]
    param($LiteralPath)
    throw 'Unmocked token-test credential route'
  }

  function Assert-TokenPublicFailure {
    param([scriptblock]$Action, [string]$Stage, [string]$Purpose = 'ReadOnly')
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_ }
    $caught | Should -Not -BeNullOrEmpty
    $caught.Exception.Message | Should -BeExactly "BWS CommonCIForBitwarden$Purpose access-token read failed [ATAP.SecretRead.Token.$Stage]."
    $caught.Exception.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    $caught.ToString() | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    $caught.TargetObject | Should -BeNullOrEmpty
    $caught.Exception.InnerException | Should -BeNullOrEmpty
    if ($null -ne $caught.ErrorDetails) {
      $caught.ErrorDetails.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    }
    @($script:tokenPrivacyLogs | Where-Object Level -EQ 'Error').Count | Should -Be 1
    foreach ($entry in $script:tokenPrivacyLogs) {
      $entry.Message | Should -Not -Match 'SYNTHETIC_PRIVATE_'
      if ($null -ne $entry.ErrorRecord) {
        $entry.ErrorRecord.Exception.Message | Should -BeExactly $caught.Exception.Message
        $entry.ErrorRecord.TargetObject | Should -BeNullOrEmpty
        $entry.ErrorRecord.Exception.InnerException | Should -BeNullOrEmpty
      }
    }
    return $caught
  }
}

Describe 'BWS token-reader handled-error privacy' -Tag 'Unit', 'FakeOnly' {
  BeforeEach {
    $script:tokenPrivacyLogs = [Collections.Generic.List[object]]::new()
    $script:primaryPresent = $true
    $script:legacyPresent = $false
    $script:importFailure = $null
    $script:pathFailure = $false
    $script:directory = 'C:\SYNTHETIC_PRIVATE_DIRECTORY'
    $secure = ConvertTo-SecureString 'SYNTHETIC_PRIVATE_CREDENTIAL' -AsPlainText -Force
    $script:fakeCredential = [Management.Automation.PSCredential]::new('BWS_ACCESS_TOKEN', $secure)

    Mock Write-PSFMessage {
      $script:tokenPrivacyLogs.Add([pscustomobject]@{
        Level = [string]$Level; Message = [string]$Message; ErrorRecord = $ErrorRecord
      })
    }
    Mock Join-Path {
      if ($script:pathFailure) { throw 'SYNTHETIC_PRIVATE_PATH_EXCEPTION' }
      # Lexical construction only: never consult the filesystem/provider.
      [IO.Path]::Combine([string]$Path, [string]$ChildPath)
    }
    Mock Test-Path {
      if ($LiteralPath -match '_BWS_CommonCIForBitwardenRead(?:Only|Write)_AccessToken\.xml$') {
        return $script:primaryPresent
      }
      if ($LiteralPath -match '_BWS_AccessToken\.xml$') { return $script:legacyPresent }
      throw 'Unexpected token-test path'
    }
    Mock Import-Clixml {
      if ($null -ne $script:importFailure) {
        Write-Error -ErrorRecord $script:importFailure -ErrorAction Stop
      }
      return $script:fakeCredential
    }
  }

  It 'returns the same synthetic credential for default ReadOnly without logging its value or path' {
    $credential = Get-BWSAccessToken -CredentialDirectory $script:directory
    [object]::ReferenceEquals($credential, $script:fakeCredential) | Should -BeTrue
    ($script:tokenPrivacyLogs.Message -join '|') | Should -Not -Match 'SYNTHETIC_PRIVATE_'
    Should -Invoke Import-Clixml -Exactly -Times 1 -Scope It -ParameterFilter {
      $LiteralPath -match '_BWS_CommonCIForBitwardenReadOnly_AccessToken\.xml$'
    }
    Should -Invoke Test-Path -Exactly -Times 1 -Scope It
  }

  It 'preserves the ReadWrite purpose-specific path' {
    $credential = Get-BWSAccessToken -CredentialDirectory $script:directory -TokenPurpose ReadWrite
    [object]::ReferenceEquals($credential, $script:fakeCredential) | Should -BeTrue
    Should -Invoke Import-Clixml -Exactly -Times 1 -Scope It -ParameterFilter {
      $LiteralPath -match '_BWS_CommonCIForBitwardenReadWrite_AccessToken\.xml$'
    }
    Should -Invoke Test-Path -Exactly -Times 0 -Scope It -ParameterFilter {
      $LiteralPath -match '_BWS_AccessToken\.xml$'
    }
  }

  It 'preserves the default account credential directory when no directory is supplied' {
    $credential = Get-BWSAccessToken
    [object]::ReferenceEquals($credential, $script:fakeCredential) | Should -BeTrue
    Should -Invoke Join-Path -Exactly -Times 2 -Scope It -ParameterFilter {
      $Path -like 'C:\ProgramData\ATAP\BitwardenCredentials\*'
    }
  }

  It 'uses the legacy file only for ReadOnly and keeps the migration warning bounded' {
    $script:primaryPresent = $false
    $script:legacyPresent = $true
    $credential = Get-BWSAccessToken -CredentialDirectory $script:directory -TokenPurpose ReadOnly
    [object]::ReferenceEquals($credential, $script:fakeCredential) | Should -BeTrue
    Should -Invoke Import-Clixml -Exactly -Times 1 -Scope It -ParameterFilter {
      $LiteralPath -match '_BWS_AccessToken\.xml$'
    }
    @($script:tokenPrivacyLogs | Where-Object Level -EQ 'Warning').Count | Should -Be 1
    ($script:tokenPrivacyLogs.Message -join '|') | Should -Not -Match 'SYNTHETIC_PRIVATE_'
  }

  It 'refuses ReadWrite legacy fallback without any credential import' {
    $script:primaryPresent = $false
    $script:legacyPresent = $true
    $null = Assert-TokenPublicFailure -Stage LocateCredential -Purpose ReadWrite -Action {
      Get-BWSAccessToken -CredentialDirectory $script:directory -TokenPurpose ReadWrite
    }
    Should -Invoke Import-Clixml -Exactly -Times 0 -Scope It
    Should -Invoke Test-Path -Exactly -Times 0 -Scope It -ParameterFilter {
      $LiteralPath -match '_BWS_AccessToken\.xml$'
    }
  }

  It 'reports absent ReadOnly credentials with a fixed error and no directory disclosure' {
    $script:primaryPresent = $false
    $script:legacyPresent = $false
    $null = Assert-TokenPublicFailure -Stage LocateCredential -Action {
      Get-BWSAccessToken -CredentialDirectory $script:directory
    }
    Should -Invoke Test-Path -Exactly -Times 2 -Scope It
    Should -Invoke Import-Clixml -Exactly -Times 0 -Scope It
  }

  It 'sanitizes path-construction failure before existence checks' {
    $script:pathFailure = $true
    $null = Assert-TokenPublicFailure -Stage ResolvePath -Action {
      Get-BWSAccessToken -CredentialDirectory $script:directory
    }
    Should -Invoke Test-Path -Exactly -Times 0 -Scope It
    Should -Invoke Import-Clixml -Exactly -Times 0 -Scope It
  }

  It 'binds each pipeline record to its own directory and purpose and emits its own credential' {
    $sam = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    $firstPath = [IO.Path]::Combine('C:\FAKE_FIRST', "$env:COMPUTERNAME`_${sam}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml")
    $secondPath = [IO.Path]::Combine('C:\FAKE_SECOND', "$env:COMPUTERNAME`_${sam}_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml")
    $secondCredential = [Management.Automation.PSCredential]::new('SECOND_FAKE', (ConvertTo-SecureString 'SECOND_FAKE_VALUE' -AsPlainText -Force))
    $script:pipelinePaths = [Collections.Generic.List[string]]::new()
    $script:pipelineFirstPath = $firstPath
    $script:pipelineSecondPath = $secondPath
    $script:pipelineSecondCredential = $secondCredential
    Mock Import-Clixml {
      $script:pipelinePaths.Add([string]$LiteralPath)
      if ($LiteralPath -ceq $script:pipelineFirstPath) { return $script:fakeCredential }
      if ($LiteralPath -ceq $script:pipelineSecondPath) { return $script:pipelineSecondCredential }
      throw 'Unexpected pipeline credential path'
    }
    $records = @(
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_FIRST'; TokenPurpose = 'ReadOnly' }
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_SECOND'; TokenPurpose = 'ReadWrite' }
    )
    $results = @($records | Get-BWSAccessToken)
    $results.Count | Should -Be 2
    [object]::ReferenceEquals($results[0], $script:fakeCredential) | Should -BeTrue
    [object]::ReferenceEquals($results[1], $secondCredential) | Should -BeTrue
    $script:pipelinePaths.Count | Should -Be 2
    $script:pipelinePaths[0] | Should -BeExactly $firstPath
    $script:pipelinePaths[1] | Should -BeExactly $secondPath
    Should -Invoke Import-Clixml -Exactly -Times 2 -Scope It
  }

  It 'resolves each missing, null, or whitespace directory independently after an explicit record' {
    $sam = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    $fileName = "$env:COMPUTERNAME`_${sam}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml"
    $firstPath = [IO.Path]::Combine('C:\FAKE_PRIOR', $fileName)
    $defaultPath = [IO.Path]::Combine("C:\ProgramData\ATAP\BitwardenCredentials\$sam", $fileName)
    $script:pipelinePaths = [Collections.Generic.List[string]]::new()
    $script:allowedPipelinePaths = @($firstPath, $defaultPath)
    Mock Import-Clixml {
      if ($LiteralPath -cnotin $script:allowedPipelinePaths) { throw 'Unexpected pipeline credential path' }
      $script:pipelinePaths.Add([string]$LiteralPath)
      return $script:fakeCredential
    }
    $records = @(
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_PRIOR'; TokenPurpose = 'ReadOnly' }
      [pscustomobject]@{ TokenPurpose = 'ReadOnly' }
      [pscustomobject]@{ CredentialDirectory = $null; TokenPurpose = 'ReadOnly' }
      [pscustomobject]@{ CredentialDirectory = '   '; TokenPurpose = 'ReadOnly' }
    )
    $results = @($records | Get-BWSAccessToken)
    $results.Count | Should -Be 4
    foreach ($result in $results) { [object]::ReferenceEquals($result, $script:fakeCredential) | Should -BeTrue }
    $script:pipelinePaths.Count | Should -Be 4
    $script:pipelinePaths[0] | Should -BeExactly $firstPath
    foreach ($index in 1..3) { $script:pipelinePaths[$index] | Should -BeExactly $defaultPath }
    Should -Invoke Import-Clixml -Exactly -Times 4 -Scope It
  }

  It 'uses an explicit directory while binding each pipeline purpose' {
    $sam = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    $firstPath = [IO.Path]::Combine('C:\FAKE_OVERRIDE', "$env:COMPUTERNAME`_${sam}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml")
    $secondPath = [IO.Path]::Combine('C:\FAKE_OVERRIDE', "$env:COMPUTERNAME`_${sam}_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml")
    $secondCredential = [Management.Automation.PSCredential]::new('SECOND_FAKE', (ConvertTo-SecureString 'SECOND_FAKE_VALUE' -AsPlainText -Force))
    $script:pipelinePaths = [Collections.Generic.List[string]]::new()
    $script:pipelineFirstPath = $firstPath
    $script:pipelineSecondPath = $secondPath
    $script:pipelineSecondCredential = $secondCredential
    Mock Import-Clixml {
      $script:pipelinePaths.Add([string]$LiteralPath)
      if ($LiteralPath -ceq $script:pipelineFirstPath) { return $script:fakeCredential }
      if ($LiteralPath -ceq $script:pipelineSecondPath) { return $script:pipelineSecondCredential }
      throw 'Unexpected pipeline credential path'
    }
    $records = @(
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_IGNORED_ONE'; TokenPurpose = 'ReadOnly' }
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_IGNORED_TWO'; TokenPurpose = 'ReadWrite' }
    )
    $results = @($records | Get-BWSAccessToken -CredentialDirectory 'C:\FAKE_OVERRIDE')
    $results.Count | Should -Be 2
    [object]::ReferenceEquals($results[0], $script:fakeCredential) | Should -BeTrue
    [object]::ReferenceEquals($results[1], $secondCredential) | Should -BeTrue
    $script:pipelinePaths.Count | Should -Be 2
    $script:pipelinePaths[0] | Should -BeExactly $firstPath
    $script:pipelinePaths[1] | Should -BeExactly $secondPath
    Should -Invoke Import-Clixml -Exactly -Times 2 -Scope It
  }

  It 'uses an explicit purpose while binding each pipeline directory' {
    $sam = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\') | Select-Object -Last 1
    $fileName = "$env:COMPUTERNAME`_${sam}_BWS_CommonCIForBitwardenReadWrite_AccessToken.xml"
    $firstPath = [IO.Path]::Combine('C:\FAKE_FIRST', $fileName)
    $secondPath = [IO.Path]::Combine('C:\FAKE_SECOND', $fileName)
    $secondCredential = [Management.Automation.PSCredential]::new('SECOND_FAKE', (ConvertTo-SecureString 'SECOND_FAKE_VALUE' -AsPlainText -Force))
    $script:pipelinePaths = [Collections.Generic.List[string]]::new()
    $script:pipelineFirstPath = $firstPath
    $script:pipelineSecondPath = $secondPath
    $script:pipelineSecondCredential = $secondCredential
    Mock Import-Clixml {
      $script:pipelinePaths.Add([string]$LiteralPath)
      if ($LiteralPath -ceq $script:pipelineFirstPath) { return $script:fakeCredential }
      if ($LiteralPath -ceq $script:pipelineSecondPath) { return $script:pipelineSecondCredential }
      throw 'Unexpected pipeline credential path'
    }
    $records = @(
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_FIRST'; TokenPurpose = 'ReadOnly' }
      [pscustomobject]@{ CredentialDirectory = 'C:\FAKE_SECOND'; TokenPurpose = 'ReadOnly' }
    )
    $results = @($records | Get-BWSAccessToken -TokenPurpose ReadWrite)
    $results.Count | Should -Be 2
    [object]::ReferenceEquals($results[0], $script:fakeCredential) | Should -BeTrue
    [object]::ReferenceEquals($results[1], $secondCredential) | Should -BeTrue
    $script:pipelinePaths.Count | Should -Be 2
    $script:pipelinePaths[0] | Should -BeExactly $firstPath
    $script:pipelinePaths[1] | Should -BeExactly $secondPath
    Should -Invoke Import-Clixml -Exactly -Times 2 -Scope It
  }
  It 'does not forward an Import-Clixml <Variant> marker' -ForEach @(
    @{ Variant = 'message' }, @{ Variant = 'target' }, @{ Variant = 'inner exception' }
  ) {
    $message = if ($Variant -eq 'message') { 'SYNTHETIC_PRIVATE_IMPORT_MESSAGE' } else { 'Fake credential import failure' }
    $target = if ($Variant -eq 'target') { 'SYNTHETIC_PRIVATE_IMPORT_TARGET' } else { $null }
    $exception = if ($Variant -eq 'inner exception') {
      [InvalidOperationException]::new($message, [Exception]::new('SYNTHETIC_PRIVATE_IMPORT_INNER'))
    } else { [InvalidOperationException]::new($message) }
    $script:importFailure = [Management.Automation.ErrorRecord]::new(
      $exception, 'FakeImportFailure', [Management.Automation.ErrorCategory]::InvalidData, $target)
    $null = Assert-TokenPublicFailure -Stage ReadCredential -Action {
      Get-BWSAccessToken -CredentialDirectory $script:directory
    }
    Should -Invoke Import-Clixml -Exactly -Times 1 -Scope It
  }
}
