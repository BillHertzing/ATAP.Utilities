Describe 'Add-NetworkShareAsLocalDriveLetter' {
  BeforeAll {
    . (Join-Path $PSScriptRoot '..\public\Add-NetworkShareAsLocalDriveLetter.ps1')
  }

  BeforeEach {
    Mock -CommandName New-PSDrive -MockWith { [pscustomobject]@{ Name = $Name; Root = $Root } }
    Mock -CommandName Remove-PSDrive -MockWith { }
  }

  It 'maps the share with FileSystem provider, Global scope, and Persist' {
    Mock -CommandName Get-PSDrive -MockWith { $null }

    $result = Add-NetworkShareAsLocalDriveLetter -Name 'Z' -Root '\\ncat016\dropbox'

    $result.Name | Should -Be 'Z'
    Should -Invoke New-PSDrive -Times 1 -Exactly -ParameterFilter {
      $Name -eq 'Z' -and $Root -eq '\\ncat016\dropbox' -and
      $PSProvider -eq 'FileSystem' -and $Scope -eq 'Global' -and $Persist
    }
  }

  It 'passes the supplied credential through to New-PSDrive' {
    Mock -CommandName Get-PSDrive -MockWith { $null }
    $password = ConvertTo-SecureString 'unit-test-only' -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new('unitTestUser', $password)

    Add-NetworkShareAsLocalDriveLetter -Name 'Z' -Root '\\ncat016\dropbox' -Credential $credential | Out-Null

    Should -Invoke New-PSDrive -Times 1 -Exactly -ParameterFilter {
      $Credential -and $Credential.UserName -eq 'unitTestUser'
    }
  }

  It 'throws when the drive name is already in use and -Force is absent' {
    Mock -CommandName Get-PSDrive -MockWith { [pscustomobject]@{ Name = 'Z'; Root = '\\other\share' } }

    { Add-NetworkShareAsLocalDriveLetter -Name 'Z' -Root '\\ncat016\dropbox' } |
      Should -Throw "*already mapped*"
    Should -Invoke New-PSDrive -Times 0 -Exactly
  }

  It 'replaces an existing mapping when -Force is supplied' {
    Mock -CommandName Get-PSDrive -MockWith { [pscustomobject]@{ Name = 'Z'; Root = '\\other\share' } }

    Add-NetworkShareAsLocalDriveLetter -Name 'Z' -Root '\\ncat016\dropbox' -Force | Out-Null

    Should -Invoke Remove-PSDrive -Times 1 -Exactly
    Should -Invoke New-PSDrive -Times 1 -Exactly
  }

  It 'rejects an invalid drive name and a non-UNC root' {
    { Add-NetworkShareAsLocalDriveLetter -Name 'ZZ' -Root '\\ncat016\dropbox' } | Should -Throw
    { Add-NetworkShareAsLocalDriveLetter -Name 'Z' -Root 'C:\NotAShare' } | Should -Throw
  }
}
