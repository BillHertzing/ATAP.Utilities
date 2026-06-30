#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = Join-Path $PSScriptRoot '..\..' | Resolve-Path
  $script:publicDir = Join-Path $script:moduleRoot 'public' | Resolve-Path
  $script:oldProcessBwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'Process')
  $script:oldUserBwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')

  function global:Write-PSFMessage {
    param(
      [string]$FunctionName,
      [string]$ModuleName,
      [string]$Level,
      [string]$Message,
      [string[]]$Tag
    )
    $script:loggedMessages.Add($Message) | Out-Null
  }

  function global:Set-PSFLoggingProvider {
    param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
  }

  function global:Get-BitWardenCredential {
    $loginSecure = ConvertTo-SecureString 'login-pass' -AsPlainText -Force
    $unlockSecure = ConvertTo-SecureString 'unlock-pass' -AsPlainText -Force
    @{
      LoginCredential = [pscredential]::new('user@example.test', $loginSecure)
      UnlockCredential = [pscredential]::new('unlock@example.test', $unlockSecure)
    }
  }

  . (Join-Path $script:publicDir 'Initialize-BitwardenSession.ps1')
}

AfterAll {
  if ($null -eq $script:oldProcessBwSession) {
    Remove-Item Env:BW_SESSION -ErrorAction SilentlyContinue
  } else {
    [System.Environment]::SetEnvironmentVariable('BW_SESSION', $script:oldProcessBwSession, 'Process')
  }
  [System.Environment]::SetEnvironmentVariable('BW_SESSION', $script:oldUserBwSession, 'User')

  foreach ($name in @('Write-PSFMessage', 'Set-PSFLoggingProvider', 'Get-BitWardenCredential', 'bw')) {
    Remove-Item -Path "Function:\$name" -Force -ErrorAction SilentlyContinue
  }
}

Describe 'Initialize-BitwardenSession' -Tag 'Unit' {
  BeforeEach {
    $script:loggedMessages = [System.Collections.Generic.List[string]]::new()
    $script:bwCalls = [System.Collections.Generic.List[string]]::new()
    $script:unlockPasswordSeen = $null
    Remove-Item Env:BW_SESSION -ErrorAction SilentlyContinue
    [System.Environment]::SetEnvironmentVariable('BW_SESSION', $null, 'User')
  }

  AfterEach {
    Remove-Item -Path 'Function:\bw' -Force -ErrorAction SilentlyContinue
  }

  It 'logs in when unauthenticated and stores BW_SESSION in Process and User scope' {
    function global:bw {
      $script:bwCalls.Add(($args -join ' ')) | Out-Null
      switch ($args[0]) {
        'status' {
          $global:LASTEXITCODE = 0
          '{"status":"unauthenticated"}'
        }
        'login' {
          $script:loginPasswordSeen = $env:BW_PASSWORD
          $global:LASTEXITCODE = 0
          'logged in'
        }
        'unlock' {
          $script:unlockPasswordSeen = $env:BW_PASSWORD
          $global:LASTEXITCODE = 0
          'session-token-value'
        }
        default {
          $global:LASTEXITCODE = 1
          "unexpected bw command: $($args -join ' ')"
        }
      }
    }

    $result = Initialize-BitwardenSession -Confirm:$false

    $result.Success | Should -BeTrue
    $env:BW_SESSION | Should -Be 'session-token-value'
    [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User') | Should -Be 'session-token-value'
    $script:loginPasswordSeen | Should -Be 'login-pass'
    $script:unlockPasswordSeen | Should -Be 'unlock-pass'
    $script:bwCalls | Should -Contain 'status'
    $script:bwCalls | Should -Contain 'login user@example.test --passwordenv BW_PASSWORD'
    $script:bwCalls | Should -Contain 'unlock --raw --passwordenv BW_PASSWORD'
  }

  It 'does not log the raw session token' {
    function global:bw {
      switch ($args[0]) {
        'status' {
          $global:LASTEXITCODE = 0
          '{"status":"locked"}'
        }
        'unlock' {
          $global:LASTEXITCODE = 0
          'very-sensitive-session-token'
        }
      }
    }

    $result = Initialize-BitwardenSession -Confirm:$false

    $result.Success | Should -BeTrue
    ($script:loggedMessages -join "`n") | Should -Not -Match 'very-sensitive-session-token'
  }
}
