#requires -Modules Pester

Describe 'Credential-file helpers' -Tag 'Unit' {
  BeforeAll {
    $script:ModuleName = 'ATAP.Utilities.Security.Secrets.PowerShell'
    $promotedManifest = [Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
    $script:ModulePath = if ([string]::IsNullOrWhiteSpace($promotedManifest)) {
      Join-Path $PSScriptRoot '..\..\ATAP.Utilities.Security.Secrets.PowerShell.psd1'
    } else {
      $promotedManifest
    }
    Import-Module -Name $script:ModulePath -Force -ErrorAction Stop
  }

  AfterAll {
    Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
  }

  It 'rejects a relative credential directory before prompting' {
    InModuleScope $script:ModuleName {
      Mock -CommandName Get-Credential { throw 'Credential prompt must not run.' }

      {
        Set-CredentialFile -SharedSecureCredentialDirectory 'relative\credentials' -Force -Confirm:$false
      } | Should -Throw '*must be absolute*'

      Should -Invoke -CommandName Get-Credential -Times 0 -Exactly
    }
  }

  It 'requires Force before creating a missing credential directory' {
    $directory = Join-Path $TestDrive 'missing-directory'

    InModuleScope $script:ModuleName -Parameters @{ Directory = $directory } {
      param($Directory)
      Mock -CommandName Get-Credential { throw 'Credential prompt must not run.' }

      {
        Set-CredentialFile -SharedSecureCredentialDirectory $Directory -Confirm:$false
      } | Should -Throw '*Use -Force to create it*'

      Test-Path -LiteralPath $Directory | Should -BeFalse
      Should -Invoke -CommandName Get-Credential -Times 0 -Exactly
    }
  }

  It 'creates a missing directory and exports a credential only with Force' {
    $directory = Join-Path $TestDrive 'new-directory'

    InModuleScope $script:ModuleName -Parameters @{ Directory = $directory } {
      param($Directory)
      Mock -CommandName Get-Credential {
        [pscredential]::new('unit-user', (ConvertTo-SecureString 'not-a-real-secret' -AsPlainText -Force))
      }
      Mock -CommandName Export-Clixml { }

      $result = Set-CredentialFile -SharedSecureCredentialDirectory $Directory -CredentialFilename 'unit.xml' -Force -Confirm:$false

      $result.Action | Should -Be 'Created'
      $result.CreatedDirectory | Should -BeTrue
      $result.CredentialFilePath | Should -Be (Join-Path $Directory 'unit.xml')
      Test-Path -LiteralPath $Directory -PathType Container | Should -BeTrue
      Should -Invoke -CommandName Get-Credential -Times 1 -Exactly
      Should -Invoke -CommandName Export-Clixml -Times 1 -Exactly -ParameterFilter {
        $LiteralPath -eq (Join-Path $Directory 'unit.xml')
      }
    }
  }

  It 'refuses to replace an existing credential file without Force' {
    $directory = Join-Path $TestDrive 'existing-file'
    $null = New-Item -ItemType Directory -Path $directory -Force
    $path = Join-Path $directory 'unit.xml'
    $null = New-Item -ItemType File -Path $path -Force

    InModuleScope $script:ModuleName -Parameters @{ Directory = $directory } {
      param($Directory)
      Mock -CommandName Get-Credential { throw 'Credential prompt must not run.' }

      {
        Set-CredentialFile -SharedSecureCredentialDirectory $Directory -CredentialFilename 'unit.xml' -Confirm:$false
      } | Should -Throw '*already exists*'

      Should -Invoke -CommandName Get-Credential -Times 0 -Exactly
    }
  }

  It 'replaces an existing credential file only with Force' {
    $directory = Join-Path $TestDrive 'replace-file'
    $null = New-Item -ItemType Directory -Path $directory -Force
    $path = Join-Path $directory 'unit.xml'
    $null = New-Item -ItemType File -Path $path -Force

    InModuleScope $script:ModuleName -Parameters @{ Directory = $directory } {
      param($Directory)
      Mock -CommandName Get-Credential {
        [pscredential]::new('unit-user', (ConvertTo-SecureString 'not-a-real-secret' -AsPlainText -Force))
      }
      Mock -CommandName Export-Clixml { }

      $result = Set-CredentialFile -SharedSecureCredentialDirectory $Directory -CredentialFilename 'unit.xml' -Force -Confirm:$false

      $result.Action | Should -Be 'Replaced'
      $result.CreatedDirectory | Should -BeFalse
      Should -Invoke -CommandName Export-Clixml -Times 1 -Exactly
    }
  }

  It 'honors WhatIf without creating directories or prompting for credentials' {
    $directory = Join-Path $TestDrive 'what-if-directory'

    InModuleScope $script:ModuleName -Parameters @{ Directory = $directory } {
      param($Directory)
      Mock -CommandName Get-Credential { throw 'Credential prompt must not run.' }
      Mock -CommandName Export-Clixml { throw 'Export must not run.' }

      $result = Set-CredentialFile -SharedSecureCredentialDirectory $Directory -CredentialFilename 'unit.xml' -Force -WhatIf

      $result.Action | Should -Be 'Skipped'
      Test-Path -LiteralPath $Directory | Should -BeFalse
      Should -Invoke -CommandName Get-Credential -Times 0 -Exactly
      Should -Invoke -CommandName Export-Clixml -Times 0 -Exactly
    }
  }

  It 'imports only an existing absolute credential file as PSCredential' {
    $path = Join-Path $TestDrive 'existing.xml'
    $null = New-Item -ItemType File -Path $path -Force

    InModuleScope $script:ModuleName -Parameters @{ Path = $path } {
      param($Path)
      Mock -CommandName Import-Clixml {
        [pscredential]::new('unit-user', (ConvertTo-SecureString 'not-a-real-secret' -AsPlainText -Force))
      }

      $result = Get-CredentialFile -Path $Path

      $result | Should -BeOfType [pscredential]
      Should -Invoke -CommandName Import-Clixml -Times 1 -Exactly -ParameterFilter { $LiteralPath -eq $Path }
    }
  }

  It 'rejects a credential file that does not deserialize to PSCredential' {
    $path = Join-Path $TestDrive 'wrong-type.xml'
    $null = New-Item -ItemType File -Path $path -Force

    InModuleScope $script:ModuleName -Parameters @{ Path = $path } {
      param($Path)
      Mock -CommandName Import-Clixml { 'not-a-credential' }

      { Get-CredentialFile -Path $Path } | Should -Throw '*did not deserialize to a PSCredential*'
    }
  }
}
