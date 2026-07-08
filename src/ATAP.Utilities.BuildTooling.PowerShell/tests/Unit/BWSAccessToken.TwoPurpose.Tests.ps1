BeforeAll {
  $script:publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $script:publicDir 'Get-BWSAccessToken.ps1')
  . (Join-Path $script:publicDir 'Initialize-BWSAccessToken.ps1')

  $script:psfMessages = [System.Collections.Generic.List[object]]::new()
  function global:Write-PSFMessage {
    param(
      [string]$FunctionName,
      [string]$ModuleName,
      [string]$Level,
      [string]$Message,
      [string[]]$Tag
    )
    [void]$script:psfMessages.Add([PSCustomObject]@{
        FunctionName = $FunctionName
        ModuleName   = $ModuleName
        Level        = $Level
        Message      = $Message
        Tag          = $Tag
      })
  }
}

AfterAll {
  Remove-Item Function:Write-PSFMessage -ErrorAction SilentlyContinue
}

Describe 'BWS access-token DPAPI helpers' -Tag 'Unit', 'BWS' {
  BeforeEach {
    $script:psfMessages.Clear()
    $script:credentialDirectory = Join-Path $TestDrive 'bws-token-slots'
    New-Item -ItemType Directory -Path $script:credentialDirectory -Force | Out-Null
    $script:currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
    $script:readOnlyTokenValue = 'task-12-52-readonly-token-value'
    $script:readWriteTokenValue = 'task-12-52-readwrite-token-value'
    $script:legacyTokenValue = 'task-12-52-legacy-token-value'
  }

  It 'writes ReadOnly and ReadWrite to distinct purpose-specific DPAPI paths' {
    $readOnlyResult = Initialize-BWSAccessToken `
      -AccessToken (ConvertTo-SecureString $script:readOnlyTokenValue -AsPlainText -Force) `
      -CredentialDirectory $script:credentialDirectory `
      -TokenPurpose ReadOnly `
      -Confirm:$false

    $readWriteResult = Initialize-BWSAccessToken `
      -AccessToken (ConvertTo-SecureString $script:readWriteTokenValue -AsPlainText -Force) `
      -CredentialDirectory $script:credentialDirectory `
      -TokenPurpose ReadWrite `
      -Confirm:$false

    $readOnlyResult.Path | Should -Match '_BWS_CommonCIForBitwardenReadOnly_AccessToken\.xml$'
    $readWriteResult.Path | Should -Match '_BWS_CommonCIForBitwardenReadWrite_AccessToken\.xml$'
    $readOnlyResult.Path | Should -Not -Be $readWriteResult.Path
    Test-Path -LiteralPath $readOnlyResult.Path | Should -BeTrue
    Test-Path -LiteralPath $readWriteResult.Path | Should -BeTrue
  }

  It 'backs up only the matching purpose slot when overwriting a token' {
    $readOnlyResult = Initialize-BWSAccessToken `
      -AccessToken (ConvertTo-SecureString $script:readOnlyTokenValue -AsPlainText -Force) `
      -CredentialDirectory $script:credentialDirectory `
      -TokenPurpose ReadOnly `
      -Confirm:$false
    $readWriteResult = Initialize-BWSAccessToken `
      -AccessToken (ConvertTo-SecureString $script:readWriteTokenValue -AsPlainText -Force) `
      -CredentialDirectory $script:credentialDirectory `
      -TokenPurpose ReadWrite `
      -Confirm:$false

    Start-Sleep -Milliseconds 1100
    Initialize-BWSAccessToken `
      -AccessToken (ConvertTo-SecureString 'task-12-52-readonly-token-value-updated' -AsPlainText -Force) `
      -CredentialDirectory $script:credentialDirectory `
      -TokenPurpose ReadOnly `
      -Confirm:$false | Out-Null

    @(Get-ChildItem -LiteralPath $script:credentialDirectory -Filter '*CommonCIForBitwardenReadOnly*.bak').Count | Should -Be 1
    @(Get-ChildItem -LiteralPath $script:credentialDirectory -Filter '*CommonCIForBitwardenReadWrite*.bak').Count | Should -Be 0
    Test-Path -LiteralPath $readWriteResult.Path | Should -BeTrue
    $readOnlyResult.Path | Should -Not -Be $readWriteResult.Path
  }

  It 'allows the legacy single-slot file only for ReadOnly migration fallback' {
    $legacyPath = Join-Path $script:credentialDirectory "$env:COMPUTERNAME`_$script:currentSamName`_BWS_AccessToken.xml"
    [System.Management.Automation.PSCredential]::new(
      'BWS_ACCESS_TOKEN',
      (ConvertTo-SecureString $script:legacyTokenValue -AsPlainText -Force)
    ) | Export-Clixml -LiteralPath $legacyPath

    $credential = Get-BWSAccessToken -CredentialDirectory $script:credentialDirectory -TokenPurpose ReadOnly

    $credential.UserName | Should -Be 'BWS_ACCESS_TOKEN'
    $credential.GetNetworkCredential().Password | Should -Be $script:legacyTokenValue
    @($script:psfMessages | Where-Object { $_.Level -eq 'Warning' -and $_.Message -match 'legacy BWS ReadOnly' }).Count | Should -Be 1
  }

  It 'does not allow ReadWrite to fall back to the legacy single-slot file' {
    $legacyPath = Join-Path $script:credentialDirectory "$env:COMPUTERNAME`_$script:currentSamName`_BWS_AccessToken.xml"
    [System.Management.Automation.PSCredential]::new(
      'BWS_ACCESS_TOKEN',
      (ConvertTo-SecureString $script:legacyTokenValue -AsPlainText -Force)
    ) | Export-Clixml -LiteralPath $legacyPath

    { Get-BWSAccessToken -CredentialDirectory $script:credentialDirectory -TokenPurpose ReadWrite } |
      Should -Throw '*CommonCIForBitwardenReadWrite*'
  }

  It 'does not include token values in PSFramework messages or thrown messages' {
    Initialize-BWSAccessToken `
      -AccessToken (ConvertTo-SecureString $script:readOnlyTokenValue -AsPlainText -Force) `
      -CredentialDirectory $script:credentialDirectory `
      -TokenPurpose ReadOnly `
      -Confirm:$false | Out-Null

    $thrownMessage = $null
    try {
      Get-BWSAccessToken -CredentialDirectory $script:credentialDirectory -TokenPurpose ReadWrite | Out-Null
    } catch {
      $thrownMessage = $_.Exception.Message
    }

    $messages = ($script:psfMessages | ForEach-Object { $_.Message }) -join "`n"
    $messages | Should -Not -Match [regex]::Escape($script:readOnlyTokenValue)
    $messages | Should -Not -Match [regex]::Escape($script:readWriteTokenValue)
    $messages | Should -Not -Match [regex]::Escape($script:legacyTokenValue)
    $thrownMessage | Should -Not -Match [regex]::Escape($script:readOnlyTokenValue)
    $thrownMessage | Should -Not -Match [regex]::Escape($script:readWriteTokenValue)
    $thrownMessage | Should -Not -Match [regex]::Escape($script:legacyTokenValue)
  }
}
