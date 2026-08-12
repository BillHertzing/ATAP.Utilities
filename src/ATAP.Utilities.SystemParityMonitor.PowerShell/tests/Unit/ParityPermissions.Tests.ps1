BeforeAll {
  $scriptPath = Join-Path $PSScriptRoot '..\..\scripts\Set-ParityAuditReadAccess.ps1'
  . $scriptPath
  $script:grantParityWmiFunction = ${function:Grant-ParityWmiCimv2ReadAccess}

  if (-not (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue)) {
    function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  }

  $script:validParameters = @{
    ComputerName       = [System.Environment]::MachineName.ToLowerInvariant()
    AccountName        = 'ATAP\SvcParityAudit'
    UserName           = 'whertzing'
    SqlInstanceNames   = @('Production', 'QA', 'Integration', 'Devwhertzing', 'Expwhertzing')
    ChocolateyPath     = 'C:\ProgramData\chocolatey'
    LocalDatabasesPath = 'C:\LocalDBs'
    PackageManagerProfiles = @()
    Confirm            = $false
  }
}

Describe 'Set-ParityAuditReadAccess safety contract' {
  BeforeEach {
    Mock Write-PSFMessage {}
    Mock Invoke-ParityPermissionNativeCommand {
      if ($FilePath -eq 'icacls.exe') {
        return [pscustomobject]@{ ExitCode = 0; Output = @('ATAP\SvcParityAudit:(OI)(CI)(RX)', 'ATAP\SvcParityAudit:(OI)(CI)(R)') }
      }
      [pscustomobject]@{ ExitCode = 0; Output = @() }
    }
    Mock Grant-ParityWmiCimv2ReadAccess {
      [pscustomobject]@{
        Surface = 'WMI'; Target = 'utat022\root\cimv2'; Account = 'ATAP\SvcParityAudit'
        Access = 'Enable,RemoteEnable'; Compliant = $true; Changed = $false
      }
    }
  }

  It 'performs no native or WMI mutation under WhatIf and returns the complete plan' {
    $result = @(Set-ParityAuditReadAccess @validParameters -EnableWmiGrant -WhatIf)

    $result | Should -HaveCount 8
    @($result | Where-Object Surface -eq 'FileSystem') | Should -HaveCount 2
    @($result | Where-Object Surface -eq 'SQL') | Should -HaveCount 5
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 1 -Exactly -ParameterFilter { $WhatIf }
  }

  It 'rejects a mismatched computer before ShouldProcess, native, or WMI work' {
    $parameters = $validParameters.Clone()
    $parameters.ComputerName = 'definitely-not-the-local-host'

    { Set-ParityAuditReadAccess @parameters -EnableWmiGrant -WhatIf } |
      Should -Throw '*must exactly match the local machine name*'
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 0 -Exactly
  }

  It 'accepts the exact local machine name case-insensitively' {
    $parameters = $validParameters.Clone()
    $parameters.ComputerName = [System.Environment]::MachineName.ToUpperInvariant()

    $result = @(Set-ParityAuditReadAccess @parameters -WhatIf)

    @($result | Where-Object Surface -eq 'SQL') | Should -HaveCount 5
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'plans inherited read for each distinct configured package-manager path' {
    $parameters = $validParameters.Clone()
    $parameters.PackageManagerProfiles = @(
      [pscustomobject]@{
        Identity = 'Interactive'
        PipPath = 'C:\Users\whertzing\AppData\Roaming\Python\Scripts\pip.exe'
        NpmPrefix = 'C:\Users\whertzing\AppData\Roaming\npm'
        NuGetToolPath = 'C:\Users\whertzing\.dotnet\tools\nuget.exe'
      },
      [pscustomobject]@{
        Identity = 'Secondary'
        PipPath = 'C:\Users\whertzing\AppData\Roaming\Python\Scripts\pip.exe'
        NpmPrefix = ''
        NuGetToolPath = $null
      }
    )

    $result = @(Set-ParityAuditReadAccess @parameters -WhatIf)

    $profileResults = @($result | Where-Object Surface -eq 'PackageManagerProfile')
    $profileResults | Should -HaveCount 3
    @($profileResults.Access | Sort-Object -Unique) | Should -Be @('(OI)(CI)(RX)')
    @($profileResults.Target | Sort-Object) | Should -Be @(
      'C:\Users\whertzing\.dotnet\tools\nuget.exe',
      'C:\Users\whertzing\AppData\Roaming\npm',
      'C:\Users\whertzing\AppData\Roaming\Python\Scripts\pip.exe'
    )
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'plans non-inheriting attribute-read and traversal access on validated user-profile ancestors' {
    $parameters = $validParameters.Clone()
    $parameters.PackageManagerProfiles = @(
      [pscustomobject]@{
        Identity = 'Interactive'
        PipPath = 'C:\Users\whertzing\AppData\Roaming\Python\Python311\site-packages'
        NpmPrefix = ''
        NuGetToolPath = ''
      }
    )

    $result = @(Set-ParityAuditReadAccess @parameters -WhatIf)

    $ancestorResults = @($result | Where-Object Surface -eq 'PackageManagerProfileAncestor')
    @($ancestorResults.Target | Sort-Object) | Should -Be @(
      'C:\Users\whertzing',
      'C:\Users\whertzing\AppData',
      'C:\Users\whertzing\AppData\Roaming',
      'C:\Users\whertzing\AppData\Roaming\Python',
      'C:\Users\whertzing\AppData\Roaming\Python\Python311'
    )
    @($ancestorResults.Access | Sort-Object -Unique) | Should -Be @('(RA,X)')
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'rejects duplicate package-manager identities before native or WMI work' {
    $parameters = $validParameters.Clone()
    $parameters.PackageManagerProfiles = @(
      @{ Identity = 'Same'; PipPath = ''; NpmPrefix = ''; NuGetToolPath = '' },
      @{ Identity = 'same'; PipPath = ''; NpmPrefix = ''; NuGetToolPath = '' }
    )

    { Set-ParityAuditReadAccess @parameters -EnableWmiGrant } | Should -Throw '*Identity values must be non-empty and unique*'
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 0 -Exactly
  }

  It 'accepts explicitly empty package-manager path fields without adding grants' {
    $parameters = $validParameters.Clone()
    $parameters.PackageManagerProfiles = @(
      @{ Identity = 'NoRegisteredPaths'; PipPath = ''; NpmPrefix = $null; NuGetToolPath = '   ' }
    )

    $result = @(Set-ParityAuditReadAccess @parameters -WhatIf)

    @($result | Where-Object Surface -eq 'PackageManagerProfile') | Should -HaveCount 0
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'accepts exact Program Files nodejs only as NpmPrefix with inherited read and traverse' {
    $parameters = $validParameters.Clone()
    $parameters.PackageManagerProfiles = @(
      @{ Identity = 'MachineNpm'; PipPath = ''; NpmPrefix = 'C:\Program Files\nodejs'; NuGetToolPath = '' }
    )

    $result = @(Set-ParityAuditReadAccess @parameters -WhatIf)

    $profileResult = @($result | Where-Object Surface -eq 'PackageManagerProfile')
    $profileResult | Should -HaveCount 1
    $profileResult[0].Target | Should -Be 'C:\Program Files\nodejs'
    $profileResult[0].Access | Should -Be '(OI)(CI)(RX)'
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'rejects Program Files nodejs for PipPath or NuGetToolPath with zero calls' {
    foreach ($fieldName in @('PipPath', 'NuGetToolPath')) {
      $profile = @{ Identity = "Invalid$fieldName"; PipPath = ''; NpmPrefix = ''; NuGetToolPath = '' }
      $profile[$fieldName] = 'C:\Program Files\nodejs'
      $parameters = $validParameters.Clone()
      $parameters.PackageManagerProfiles = @($profile)

      { Set-ParityAuditReadAccess @parameters -EnableWmiGrant } | Should -Throw "*PackageManagerProfiles $fieldName*"
    }
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 0 -Exactly
  }

  It 'rejects sibling and descendant Program Files npm paths with zero calls' {
    foreach ($invalidPath in @('C:\Program Files\nodejs-other', 'C:\Program Files\nodejs\child')) {
      $parameters = $validParameters.Clone()
      $parameters.PackageManagerProfiles = @(
        @{ Identity = 'InvalidMachineNpm'; PipPath = ''; NpmPrefix = $invalidPath; NuGetToolPath = '' }
      )

      { Set-ParityAuditReadAccess @parameters -EnableWmiGrant } | Should -Throw '*NpmPrefix alone may instead equal*'
    }
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 0 -Exactly
  }

  It 'rejects traversal, another user, UNC, environment variables, and other drives with zero calls' {
    $invalidPaths = @(
      'C:\Users\whertzing\AppData\..\..\other-user\tool.exe',
      'C:\Users\someone-else\tool.exe',
      '\\server\share\tool.exe',
      '%USERPROFILE%\tool.exe',
      '$env:USERPROFILE\tool.exe',
      'D:\Users\whertzing\tool.exe'
    )
    foreach ($invalidPath in $invalidPaths) {
      $parameters = $validParameters.Clone()
      $parameters.PackageManagerProfiles = @(
        @{ Identity = 'Invalid'; PipPath = $invalidPath; NpmPrefix = ''; NuGetToolPath = '' }
      )
      { Set-ParityAuditReadAccess @parameters -EnableWmiGrant } | Should -Throw
    }
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 0 -Exactly
  }

  It 'rejects profiles missing any collector contract field with zero calls' {
    $parameters = $validParameters.Clone()
    $parameters.PackageManagerProfiles = @(
      @{ Identity = 'Incomplete'; PipPath = ''; NpmPrefix = '' }
    )

    { Set-ParityAuditReadAccess @parameters } | Should -Throw '*missing required field*NuGetToolPath*'
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'emits only the exact approved additive filesystem and SQL grants' {
    $script:nativeCalls = [System.Collections.Generic.List[object]]::new()
    Mock Invoke-ParityPermissionNativeCommand {
      $script:nativeCalls.Add([pscustomobject]@{ FilePath = $FilePath; Arguments = @($ArgumentList) })
      if ($FilePath -eq 'icacls.exe') {
        return [pscustomobject]@{ ExitCode = 0; Output = @('ATAP\SvcParityAudit:(OI)(CI)(RX)', 'ATAP\SvcParityAudit:(OI)(CI)(R)') }
      }
      [pscustomobject]@{ ExitCode = 0; Output = @() }
    }

    $result = @(Set-ParityAuditReadAccess @validParameters)

    @($result | Where-Object Surface -eq 'FileSystem').Access | Should -Be @('(OI)(CI)(RX)', '(OI)(CI)(R)')
    $grantCalls = @($script:nativeCalls | Where-Object { $_.FilePath -eq 'icacls.exe' -and $_.Arguments -contains '/grant' })
    $grantCalls | Should -HaveCount 2
    ($grantCalls[0].Arguments -join ' ') | Should -Not -Match '/grant:r|\(F\)|\(M\)|\(W\)'
    ($grantCalls[1].Arguments -join ' ') | Should -Not -Match '/grant:r|\(F\)|\(M\)|\(W\)'

    $sqlCalls = @($script:nativeCalls | Where-Object FilePath -eq 'sqlcmd.exe')
    $sqlCalls | Should -HaveCount 5
    @($sqlCalls | ForEach-Object { $_.Arguments[1] }) | Should -Be @(
      'utat022\Production', 'utat022\QA', 'utat022\Integration', 'utat022\Devwhertzing', 'utat022\Expwhertzing'
    )
    foreach ($call in $sqlCalls) {
      $batch = $call.Arguments[5]
      @([regex]::Matches($batch, '(?im)^GRANT\s+')).Count | Should -Be 2
      $batch | Should -Match 'GRANT VIEW ANY DEFINITION TO \[ATAP\\SvcParityAudit\]'
      $batch | Should -Match 'GRANT VIEW SERVER STATE TO \[ATAP\\SvcParityAudit\]'
      $batch | Should -Match 'ALTER ROLE \[SQLAgentReaderRole\] ADD MEMBER'
      $batch | Should -Match "IS_SRVROLEMEMBER\(N'sysadmin'"
      $batch | Should -Match "permission_name LIKE N'%ALTER%'"
      $batch | Should -Not -Match '(?im)^GRANT\s+(ALTER|CONTROL|IMPERSONATE|UPDATE|INSERT|DELETE|WRITE|TAKE OWNERSHIP)'
    }
  }

  It 'uses conditional additive statements so repeated runs are idempotent' {
    $source = Get-Content -LiteralPath $scriptPath -Raw

    $source | Should -Match "IF SUSER_ID\(N'"
    $source | Should -Match 'IF USER_ID\(N'''
    $source | Should -Match 'IF NOT EXISTS \('
    $source | Should -Match '/grant'''
    $source | Should -Not -Match '/grant:r'
    $source | Should -Match '\$existingAce.Count -eq 0'
  }

  It 'aggregates a partial SQL failure after attempting every approved instance' {
    Mock Invoke-ParityPermissionNativeCommand {
      if ($FilePath -eq 'icacls.exe') {
        return [pscustomobject]@{ ExitCode = 0; Output = @('ATAP\SvcParityAudit:(OI)(CI)(RX)', 'ATAP\SvcParityAudit:(OI)(CI)(R)') }
      }
      if ($ArgumentList[1] -eq 'utat022\QA') {
        return [pscustomobject]@{ ExitCode = 1; Output = @('metadata-only simulated failure') }
      }
      [pscustomobject]@{ ExitCode = 0; Output = @() }
    }

    { Set-ParityAuditReadAccess @validParameters } | Should -Throw '*SQL*utat022\QA*'
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 5 -Exactly -ParameterFilter { $FilePath -eq 'sqlcmd.exe' }
  }

  It 'rejects missing, extra, or substituted instances before native execution' {
    foreach ($instances in @(
        @('Production', 'QA', 'Integration', 'Devwhertzing'),
        @('Production', 'QA', 'Integration', 'Devwhertzing', 'Expwhertzing', 'Other'),
        @('Production', 'QA', 'Integration', 'DevOther', 'Expwhertzing')
      )) {
      $parameters = $validParameters.Clone()
      $parameters.SqlInstanceNames = $instances
      { Set-ParityAuditReadAccess @parameters } | Should -Throw '*must contain exactly*'
    }
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'rejects weird accounts, hostnames, usernames, and paths before native execution' {
    $variants = @(
      @{ Name = 'AccountName'; Value = 'ATAP\svc;whoami' },
      @{ Name = 'ComputerName'; Value = 'utat022\other' },
      @{ Name = 'UserName'; Value = 'name;drop' },
      @{ Name = 'ChocolateyPath'; Value = 'C:\ProgramData\chocolatey\..\Temp' },
      @{ Name = 'LocalDatabasesPath'; Value = 'C:\LocalDBs-Writeable' }
    )
    foreach ($variant in $variants) {
      $parameters = $validParameters.Clone()
      $parameters[$variant.Name] = $variant.Value
      { Set-ParityAuditReadAccess @parameters } | Should -Throw
    }
    Assert-MockCalled Invoke-ParityPermissionNativeCommand -Times 0 -Exactly
  }

  It 'keeps WMI mutation separately gated and limits its ACE to enable plus remote-enable' {
    Set-ParityAuditReadAccess @validParameters | Out-Null
    Assert-MockCalled Grant-ParityWmiCimv2ReadAccess -Times 0 -Exactly

    $source = Get-Content -LiteralPath $scriptPath -Raw
    $source | Should -Match 'if \(\$EnableWmiGrant\)'
    $source | Should -Match '\$requiredAccessMask = 0x21'
    $source | Should -Match 'Namespace \$namespace -ClassName ''__SystemSecurity'''
    $source | Should -Match "MethodName 'SetSecurityDescriptor'"
    $source | Should -Match "MethodName 'GetSecurityDescriptor'"
  }

  It 'constructs every Win32_ACE numeric property as UInt32 for CIM schema compatibility' {
    $script:setDescriptor = $null
    $script:acePropertyTypes = $null
    $script:securityCimInstance = New-CimInstance -ClientOnly -Namespace 'root\cimv2' -ClassName '__SystemSecurity'
    Mock Get-CimInstance { $script:securityCimInstance }
    Mock New-CimInstance {
      if ($ClassName -eq 'Win32_Trustee') {
        return [pscustomobject] $Property
      }
      if ($ClassName -eq 'Win32_ACE') {
        $script:acePropertyTypes = [pscustomobject]@{
          AccessMask = $Property.AccessMask.GetType()
          AceFlags   = $Property.AceFlags.GetType()
          AceType    = $Property.AceType.GetType()
        }
        return [pscustomobject] $Property
      }
    }
    Mock Invoke-CimMethod {
      if ($MethodName -eq 'SetSecurityDescriptor') {
        $script:setDescriptor = $Arguments.Descriptor
        return [pscustomobject]@{ ReturnValue = 0 }
      }
      $descriptor = if ($null -eq $script:setDescriptor) {
        [pscustomobject]@{ DACL = @() }
      }
      else {
        $script:setDescriptor
      }
      [pscustomobject]@{ ReturnValue = 0; Descriptor = $descriptor }
    }

    $result = & $script:grantParityWmiFunction `
      -ComputerName ([Environment]::MachineName) `
      -AccountName ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
      -Confirm:$false

    $result.Compliant | Should -BeTrue
    $script:acePropertyTypes.AccessMask | Should -Be ([uint32])
    $script:acePropertyTypes.AceFlags | Should -Be ([uint32])
    $script:acePropertyTypes.AceType | Should -Be ([uint32])
    Assert-MockCalled Invoke-CimMethod -Times 1 -Exactly -ParameterFilter { $MethodName -eq 'SetSecurityDescriptor' }
  }

  It 'contains only function definitions at script load' {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref] $tokens, [ref] $errors)

    @($errors) | Should -HaveCount 0
    @($ast.EndBlock.Statements) | Should -HaveCount 3
    @($ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }) |
      Should -HaveCount 0
  }
}
