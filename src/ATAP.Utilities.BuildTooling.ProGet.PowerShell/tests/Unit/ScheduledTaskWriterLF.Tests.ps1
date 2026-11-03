#Requires -Version 7.4

Describe 'Scheduled task new text writers' -Tag 'Unit' {
BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $repositoryRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
  if (Get-Module -Name ProGetWriterLF341) { throw 'Dedicated fixture module already loaded.' }
  $publicDirectory = Join-Path $moduleRoot 'public'
  # Keep every mock in this fixture module so Pester's own commands stay native.
  $fixtureModule = New-Module -Name ProGetWriterLF341 -ArgumentList $publicDirectory, $repositoryRoot -ScriptBlock {
    param([string]$PublicDirectory, [string]$RepositoryRoot)
    . (Join-Path $PublicDirectory 'Register-ATAPParityScheduledTasks.ps1')
    . (Join-Path $PublicDirectory 'Register-ElevationBrokerTask.ps1')

    # Local fail-closed stubs prevent native executable or credential fallthrough.
    function schtasks { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Unmocked schtasks.' }
    function net { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Unmocked net.' }
    function Get-SecretATAP { param($SecretName) throw 'Unmocked secret read.' }
    function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }

    function ConvertTo-WriterTestPath {
      param([string]$Path)
      $fullPath = [IO.Path]::GetFullPath($Path)
      $fullCaseRoot = [IO.Path]::GetFullPath($script:caseRoot)
      if ($fullPath -eq $fullCaseRoot -or $fullPath.StartsWith($fullCaseRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath
      }
      if ($Path.StartsWith('C:\', [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::Combine($script:caseRoot, 'C-drive', $Path.Substring(3))
      }
      return $Path
    }

    function Assert-WriterTestPath {
      param([string]$Path)
      $full = [IO.Path]::GetFullPath($Path)
      if (-not $full.StartsWith($script:caseRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
          $full -ne $script:caseRoot) { throw "Filesystem escape: $Path" }
    }

    $script:runRoot = Join-Path $RepositoryRoot ('_generated\Sprint0017\Task17.9.b\ProGetHarnessFix341\TestRuns\' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($script:runRoot)
    $script:originalComputerName = $env:COMPUTERNAME
    Export-ModuleMember -Function @() -Alias @() -Variable @()
  }
  Import-Module $fixtureModule -ErrorAction Stop
}

AfterAll {
  if (Get-Module -Name ProGetWriterLF341) {
    InModuleScope ProGetWriterLF341 {
      $env:COMPUTERNAME = $script:originalComputerName
      # Retain disposable fixtures beneath the run GUID for root verification.
    }
    Remove-Module -Name ProGetWriterLF341 -ErrorAction Stop
  }
}


  BeforeEach {
    InModuleScope ProGetWriterLF341 {
      $script:caseRoot = [IO.Path]::Combine($script:runRoot, [guid]::NewGuid().ToString('N'))
      [void][IO.Directory]::CreateDirectory($script:caseRoot)
      $env:COMPUTERNAME = 'UTAT01'

      Mock -ModuleName ProGetWriterLF341 Write-PSFMessage {}
      Mock -ModuleName ProGetWriterLF341 Get-SecretATAP { 'synthetic-test-password' }
      Mock -ModuleName ProGetWriterLF341 Test-ElevationBrokerAdministrator { $true }
      Mock -ModuleName ProGetWriterLF341 Resolve-ElevationBrokerAccountSid { 'S-1-5-21-111-222-333-444' }
      Mock -ModuleName ProGetWriterLF341 Get-Acl { [pscustomobject]@{ Access = @() } }
      Mock -ModuleName ProGetWriterLF341 Set-Acl { throw 'Unexpected ACL mutation.' }
      Mock -ModuleName ProGetWriterLF341 Copy-Item { throw 'Unexpected payload copy.' }
      Mock -ModuleName ProGetWriterLF341 Invoke-RestMethod { throw 'Unexpected network call.' }
      Mock -ModuleName ProGetWriterLF341 Invoke-WebRequest { throw 'Unexpected network call.' }
      Mock -ModuleName ProGetWriterLF341 New-Object { throw 'Unexpected object or COM construction.' }

      Mock -ModuleName ProGetWriterLF341 Join-Path {
        param($Path, $ChildPath)
        # Includes the broker's static GetTempPath call: its actual writer stays genuine.
        if ([string]$Path -eq [IO.Path]::GetTempPath()) { $Path = $script:caseRoot }
        $parent = ConvertTo-WriterTestPath $Path
        [IO.Path]::Combine($parent, [string]$ChildPath)
      }
      Mock -ModuleName ProGetWriterLF341 New-Item {
        param($Path, $ItemType, $Force)
        $target = ConvertTo-WriterTestPath $Path
        Assert-WriterTestPath $target
        if ($ItemType -ne 'Directory') { throw 'Unexpected filesystem creation.' }
        [IO.Directory]::CreateDirectory($target)
      }
      Mock -ModuleName ProGetWriterLF341 Test-Path {
        param($LiteralPath, $PathType)
        $fullLiteralPath = [IO.Path]::GetFullPath([string]$LiteralPath)
        $fullCaseRoot = [IO.Path]::GetFullPath($script:caseRoot)
        $fixtureInstall = [IO.Path]::Combine($script:caseRoot, 'C-drive', 'Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell')
        $fixtureConfiguration = [IO.Path]::Combine($script:caseRoot, 'C-drive', 'ProgramData\ATAP\ParityState\Configuration')
        if ($fullLiteralPath -eq $fullCaseRoot -or $fullLiteralPath.StartsWith($fullCaseRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
          Assert-WriterTestPath $fullLiteralPath
          if ([string]$LiteralPath -like "$fixtureInstall\*" -or [string]$LiteralPath -like "$fixtureConfiguration\*") { return $true }
          if ($PathType -eq 'Container') { return [IO.Directory]::Exists($fullLiteralPath) }
          if ($PathType -eq 'Leaf') { return [IO.File]::Exists($fullLiteralPath) }
          return [IO.File]::Exists($fullLiteralPath) -or [IO.Directory]::Exists($fullLiteralPath)
        }
        if ([string]$LiteralPath -like 'C:\*') {
          if ($LiteralPath -eq 'C:\Program Files\ATAP\ParityDispatchers') { return $false }
          if ($LiteralPath -like 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell\*' -or
              $LiteralPath -like 'C:\ProgramData\ATAP\ParityState\Configuration\*' -or
              $LiteralPath -eq 'C:\Program Files\PowerShell\7\pwsh.exe') { return $true }
          throw "Unexpected external read: $LiteralPath"
        }
        Assert-WriterTestPath $LiteralPath
        if ([string]$LiteralPath -like "$fixtureInstall\*" -or [string]$LiteralPath -like "$fixtureConfiguration\*") { return $true }
        if ($PathType -eq 'Container') { return [IO.Directory]::Exists($LiteralPath) }
        return [IO.File]::Exists($LiteralPath) -or [IO.Directory]::Exists($LiteralPath)
      }
      Mock -ModuleName ProGetWriterLF341 Remove-Item {
        param($LiteralPath)
        Assert-WriterTestPath $LiteralPath
        [IO.File]::Delete($LiteralPath)
      }

      $script:taskMap = @{}
      $folder = [pscustomobject]@{ Tasks = $script:taskMap }
      $folder | Add-Member ScriptMethod GetTask {
        param($Name)
        if ($Name -eq 'ATAP-ElevatedInstallBroker') {
          if (-not $script:brokerTask) {
            $script:brokerTask = [pscustomobject]@{ Xml = ($script:exportXml -join [char]10); Enabled = $true }
            $script:brokerTask | Add-Member ScriptMethod GetSecurityDescriptor { param($Flags) 'fixture-dacl' }
          }
          return $script:brokerTask
        }
        $this.Tasks[$Name]
      }
      $folder | Add-Member ScriptMethod RegisterTask {
        param($Name, $Xml, $Flags, $User, $Password, $Logon, $Sddl)
        if ($Name -ne 'ATAP-ElevatedInstallBroker' -or $Flags -ne 4 -or $Logon -ne 1) { throw 'Unexpected broker API tuple.' }
        $script:createdXml = $Xml
        $script:brokerTask.Xml = $Xml
        $script:brokerTask.Enabled = [bool]::Parse(([xml]$Xml).Task.Settings.Enabled)
      }
      $folder | Add-Member ScriptMethod RegisterTaskDefinition { throw 'Task registration must never occur.' }
      $script:scheduler = [pscustomobject]@{ Folder = $folder }
      $script:scheduler | Add-Member ScriptMethod Connect {}
      $script:scheduler | Add-Member ScriptMethod GetFolder { param($Path) if ($Path -notin @('\ATAP', '\ATAP-Broker')) { throw 'Wrong folder.' }; $this.Folder }
      Mock -ModuleName ProGetWriterLF341 New-Object { $script:scheduler } -ParameterFilter { $ComObject -eq 'Schedule.Service' }

      $script:brokerRoot = [IO.Path]::Combine($script:caseRoot, 'broker')
      [void][IO.Directory]::CreateDirectory([IO.Path]::Combine($script:brokerRoot, 'bin'))
      [IO.File]::WriteAllText([IO.Path]::Combine($script:brokerRoot, 'bin', 'Invoke-ElevationBrokerRequest.ps1'), '# fixture' + [char]10)
      [IO.File]::WriteAllText([IO.Path]::Combine($script:brokerRoot, 'config.json'), '{}' + [char]10)
      $script:templatePath = [IO.Path]::Combine($script:caseRoot, 'template.xml')
      $script:templateXml = '<?xml version="1.0" encoding="UTF-16"?><Task><Actions><Exec><Command>__BROKER_SCRIPT__</Command></Exec></Actions><Principals><Principal><UserId>__SERVICE_ACCOUNT__</UserId><LogonType>Password</LogonType></Principal></Principals><Settings><Enabled>false</Enabled></Settings><Triggers><BootTrigger><Enabled>false</Enabled></BootTrigger></Triggers></Task>'
      [IO.File]::WriteAllText($script:templatePath, $script:templateXml, [Text.UnicodeEncoding]::new($false, $true))
      $script:brokerArguments = @{
        TemplatePath = $script:templatePath; BrokerRoot = $script:brokerRoot
        ServiceAccount = 'FIXTURE\SvcAnsibleAdmin'; SecretName = 'Fixture.Secret'
        RequesterPrincipal = 'FIXTURE\Requester'; SkipPayloadDeployment = $true; Confirm = $false
      }
      $script:xmlLf = '<?xml version="1.0" encoding="UTF-16"?>' + [char]10 +
        '<Task><Actions><Exec><Arguments>-EncodedCommand QQAmAD0A &amp; literal</Arguments></Exec></Actions><Description>café λ</Description><Principals><Principal><UserId>FIXTURE\SvcAnsibleAdmin</UserId><LogonType>Password</LogonType></Principal></Principals><Settings><Enabled>true</Enabled></Settings></Task>'
      $script:exportXml = @($script:xmlLf -split [char]10)
      $script:createdXml = $null
      $script:brokerTask = $null
      $script:historicalPath = [IO.Path]::Combine($script:caseRoot, 'historical.xml')
      $script:historicalBytes = [byte[]]@(255, 254, 60, 0, 120, 0, 47, 0, 62, 0, 13, 0, 10, 0)
      [IO.File]::WriteAllBytes($script:historicalPath, $script:historicalBytes)
      Mock -ModuleName ProGetWriterLF341 net { 'Fixture service account exists.' }
      Mock -ModuleName ProGetWriterLF341 schtasks { throw 'Native scheduler command forbidden.' }
    }
  }

  It 'writes LF UTF8 dispatchers for <HostName>, WhatIf=<Preview>' -ForEach @(
    @{ HostName = 'utat01'; Preview = $false; ExpectedCount = 1 }
    @{ HostName = 'utat022'; Preview = $false; ExpectedCount = 2 }
    @{ HostName = 'utat01'; Preview = $true; ExpectedCount = 1 }
    @{ HostName = 'utat022'; Preview = $true; ExpectedCount = 2 }
  ) {
    InModuleScope ProGetWriterLF341 -Parameters @{ HostName = $HostName; Preview = $Preview; ExpectedCount = $ExpectedCount } {
      param($HostName, $Preview, $ExpectedCount)
      $env:COMPUTERNAME = $HostName.ToUpperInvariant()
      $names = if ($ExpectedCount -eq 2) { @('ATAP-ParityAudit', 'ATAP-ParityCompare') } else { @('ATAP-ParityAudit') }
      foreach ($name in $names) {
        $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Program Files\ATAP\ParityDispatchers\' + $name + '.ps1"'
        # Join-Path is redirected; use the matching logical action from the fake scheduler.
        $mappedDispatcher = [IO.Path]::Combine($script:caseRoot, 'C-drive', 'Program Files\ATAP\ParityDispatchers', "$name.ps1")
        $arguments = $arguments.Replace("C:\Program Files\ATAP\ParityDispatchers\$name.ps1", $mappedDispatcher)
        $runLevel = if ($HostName -eq 'utat022') { 'HighestAvailable' } else { 'Limited' }
        $taskXml = '<Task version="1.2"><Principals><Principal><UserId>fixture</UserId><LogonType>Password</LogonType><RunLevel>' + $runLevel +
          '</RunLevel></Principal></Principals>' + "`r`n" + '<Triggers/><Settings/><Actions><Exec><Command>C:\Program Files\PowerShell\7\pwsh.exe</Command><Arguments>' + $arguments + '</Arguments></Exec></Actions></Task>'
        $task = [pscustomobject]@{ Name = $name; Xml = $taskXml }
        $task | Add-Member ScriptMethod GetSecurityDescriptor { param($Flags) 'fixture-dacl' }
        $script:taskMap[$name] = $task
      }

      $result = @(Register-ATAPParityScheduledTasks -ModuleVersion '9.8.7' -WhatIf:$Preview -Confirm:$false)
      $result.Count | Should -Be $ExpectedCount
      foreach ($item in $result) {
        Assert-WriterTestPath $item.DispatcherPath
        [IO.File]::Exists($item.DispatcherPath) | Should -Be (-not $Preview)
        if (-not $Preview) {
          $bytes = [IO.File]::ReadAllBytes($item.DispatcherPath)
          $bytes | Should -Not -Contain 13
          $bytes[-1] | Should -Be 10
          [Convert]::ToHexString($bytes[0..2]) | Should -Not -Be 'EFBBBF'
          $body = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
          $body | Should -Match '9\.8\.7'
          $body | Should -Match '\-NoProfile -NonInteractive -ExecutionPolicy Bypass -File'
          $body | Should -Match 'exit \$LASTEXITCODE\n\z'
          if ($item.TaskName -eq 'ATAP-ParityAudit') {
            $body | Should -Match ([regex]::Escape("-HostName '$HostName'")) -Because 'audit identity arguments must survive'
          }
          if ($item.TaskName -eq 'ATAP-ParityCompare') {
            $body | Should -Match ([regex]::Escape("-RightStatePath '\\utat01\ParityState'"))
          }
        }
        # The existing task preimage writer still honors the inherited WhatIf preference.
        if ($Preview) { [IO.File]::Exists($item.BackupPath) | Should -BeFalse }
        else { [IO.File]::ReadAllText($item.BackupPath) | Should -Match "`r`n" }
      }
      Should -Invoke Get-SecretATAP -ModuleName ProGetWriterLF341 -Times 0 -Exactly
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 0 -Exactly
    }
  }

  It 'exports UTF16 XML with LF for <Shape>' -ForEach @(
    @{ Shape = 'native output lines' }
    @{ Shape = 'one CRLF string' }
    @{ Shape = 'mixed CR and LF with existing final LF' }
  ) {
    InModuleScope ProGetWriterLF341 -Parameters @{ Shape = $Shape } {
      param($Shape)
      if ($Shape -eq 'one CRLF string') { $script:exportXml = $script:xmlLf.Replace("`n", "`r`n") }
      if ($Shape -eq 'mixed CR and LF with existing final LF') { $script:exportXml = $script:xmlLf.Replace("`n", "`r") + "`n" }
      Register-ElevationBrokerTask @script:brokerArguments | Out-Null
      $files = @([IO.Directory]::GetFiles($script:brokerRoot, '*.xml', [IO.SearchOption]::AllDirectories))
      $files.Count | Should -Be 1
      $bytes = [IO.File]::ReadAllBytes($files[0])
      [Convert]::ToHexString($bytes[0..1]) | Should -Be 'FFFE'
      $decoded = [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
      $decoded | Should -Not -Match '\r'
      $decoded.EndsWith("`n") | Should -BeTrue
      $decoded | Should -Be ($script:xmlLf + "`n")
      ([xml]$decoded).Task.Actions.Exec.Arguments | Should -Be '-EncodedCommand QQAmAD0A & literal'
      ([xml]$decoded).Task.Description | Should -Be 'café λ'
      [Convert]::ToHexString([IO.File]::ReadAllBytes($script:historicalPath)) | Should -Be ([Convert]::ToHexString($script:historicalBytes))
      $expectedCreate = $script:templateXml.Replace('__BROKER_SCRIPT__', [IO.Path]::Combine($script:brokerRoot, 'bin\Invoke-ElevationBrokerRequest.ps1')).Replace('__SERVICE_ACCOUNT__', 'FIXTURE\SvcAnsibleAdmin')
      $expectedUpdate = [xml]$expectedCreate
      $expectedUpdate.Task.Settings.Enabled = 'true'
      $templateTriggers = $expectedUpdate.Task.SelectSingleNode("./*[local-name()='Triggers']")
      [void]$expectedUpdate.Task.RemoveChild($templateTriggers)
      $script:createdXml | Should -Be $expectedUpdate.OuterXml
      Should -Invoke Test-ElevationBrokerAdministrator -ModuleName ProGetWriterLF341 -Times 1 -Exactly
      Should -Invoke Resolve-ElevationBrokerAccountSid -ModuleName ProGetWriterLF341 -Times 1 -Exactly -ParameterFilter { $ServiceAccount -eq 'FIXTURE\SvcAnsibleAdmin' }
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 0 -Exactly
    }
  }

  It 'does not export or register a broker task under WhatIf' {
    InModuleScope ProGetWriterLF341 {
      Register-ElevationBrokerTask @script:brokerArguments -WhatIf | Out-Null
      @([IO.Directory]::GetFiles($script:brokerRoot, '*.xml', [IO.SearchOption]::AllDirectories)).Count | Should -Be 0
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 0 -Exactly
      Should -Invoke Get-SecretATAP -ModuleName ProGetWriterLF341 -Times 0 -Exactly
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 0 -Exactly -ParameterFilter { $Arguments -contains '/xml' -or $Arguments[0] -in @('/create', '/delete') }
    }
  }

  It 'retains the elevation refusal before account or task operations' {
    InModuleScope ProGetWriterLF341 {
      Mock -ModuleName ProGetWriterLF341 Test-ElevationBrokerAdministrator { $false }
      { Register-ElevationBrokerTask @script:brokerArguments } | Should -Throw '*Must run ELEVATED*'
      Should -Invoke net -ModuleName ProGetWriterLF341 -Times 0 -Exactly
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 0 -Exactly
    }
  }

  It 'retains account resolution failure before any task mutation' {
    InModuleScope ProGetWriterLF341 {
      Mock -ModuleName ProGetWriterLF341 Resolve-ElevationBrokerAccountSid { throw 'Synthetic SID resolution failure.' }
      { Register-ElevationBrokerTask @script:brokerArguments } | Should -Throw '*does not resolve to a SID*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetWriterLF341 -Times 0 -Exactly
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 0 -Exactly
    }
  }
}

Describe 'Registrar credential transport and state preservation' -Tag 'RegistrarCredentialTransport1437' {
  BeforeAll {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $source = Join-Path $moduleRoot 'public\Register-ElevationBrokerTask.ps1'
    $repository = Split-Path -Parent (Split-Path -Parent $moduleRoot)
    $artifactRoot = Join-Path $repository '_generated\Sprint0017\Task17.12.b\R1441'
    $runRoot = Join-Path $artifactRoot ('MockRuns\' + [guid]::NewGuid().ToString('N'))
    $fixture = New-Module -Name ProGetRegistrarCredential1437 -ArgumentList $source, $runRoot -ScriptBlock {
      param($Source, $RunRoot)
      . $Source
      $script:runRoot = $RunRoot
      $script:sentinel = 'SYNTHETIC_CREDENTIAL_SENTINEL_1437'
      function net { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Unmocked native account query.' }
      function schtasks { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Native scheduler forbidden.' }
      function Get-SecretATAP { param($SecretName) throw 'Unmocked secret resolution.' }
      function New-Object { param($ComObject, $TypeName, $ArgumentList) throw 'Unmocked object/COM construction.' }
      function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) throw 'Unmocked PSFramework logging.' }
      Export-ModuleMember -Function @() -Alias @() -Variable @()
    }
    Import-Module $fixture -ErrorAction Stop
  }
  AfterAll {
    Remove-Module ProGetRegistrarCredential1437 -ErrorAction Stop
  }
  BeforeEach {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:caseRoot = Join-Path $script:runRoot ([guid]::NewGuid().ToString('N'))
      $script:brokerRoot = Join-Path $script:caseRoot 'broker'
      $null = [IO.Directory]::CreateDirectory((Join-Path $script:brokerRoot 'bin'))
      [IO.File]::WriteAllText((Join-Path $script:brokerRoot 'bin\Invoke-ElevationBrokerRequest.ps1'), '# inert fixture')
      [IO.File]::WriteAllText((Join-Path $script:brokerRoot 'config.json'), '{}')
      $script:templatePath = Join-Path $script:caseRoot 'template.xml'
      $script:template = '<Task><Principals><Principal><UserId>__SERVICE_ACCOUNT__</UserId><LogonType>Password</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals><Settings><Enabled>false</Enabled><MultipleInstancesPolicy>Queue</MultipleInstancesPolicy></Settings><Triggers><BootTrigger><Enabled>false</Enabled></BootTrigger></Triggers><Actions><Exec><Command>__BROKER_SCRIPT__</Command></Exec></Actions></Task>'
      [IO.File]::WriteAllText($script:templatePath, $script:template)
      $oldXml = $script:template.Replace('__SERVICE_ACCOUNT__', 'FIXTURE\SvcAnsibleAdmin').Replace('__BROKER_SCRIPT__', (Join-Path $script:brokerRoot 'bin\Invoke-ElevationBrokerRequest.ps1')).Replace('<Enabled>false</Enabled>', '<Enabled>true</Enabled>')
      $script:state = @{
        Exists = $true; GetCalls = 0; Attempts = 0; Calls = [Collections.Generic.List[object]]::new()
        Messages = [Collections.Generic.List[string]]::new(); Sddl = 'O:SYG:SYD:(A;;FA;;;SY)'
        LookupFails = $false; FolderFails = $false; BackupFails = $false
        RegisterFails = $false; PartialChange = $false; ReadbackFails = $false; ChangePreimage = $false; AppearOnRegister = $false; DisappearOnRegister = $false
      }
      $task = [pscustomobject]@{ Xml = $oldXml; Enabled = $true; State = $script:state }
      $task | Add-Member ScriptMethod GetSecurityDescriptor {
        param($Flags)
        if ($Flags -ne 7) { throw 'Unexpected security scope.' }
        if ($this.State.BackupFails) { throw 'Synthetic preimage failure.' }
        $this.State.Sddl
      }
      $script:state.Task = $task
      $folder = [pscustomobject]@{ State = $script:state }
      $folder | Add-Member ScriptMethod GetTask {
        param($Name)
        if ($Name -ne 'ATAP-ElevatedInstallBroker') { throw 'Wrong exact task.' }
        $this.State.GetCalls++
        if ($this.State.LookupFails) { throw [UnauthorizedAccessException]::new('Synthetic lookup denial.') }
        if ($this.State.Attempts -gt 0 -and $this.State.ReadbackFails) { throw 'Synthetic readback failure.' }
        if (-not $this.State.Exists) { throw [IO.FileNotFoundException]::new('Synthetic exact task absent.') }
        if ($this.State.GetCalls -eq 2 -and $this.State.ChangePreimage) { $this.State.Task.Xml += '<!-- changed -->' }
        $this.State.Task
      }
      $folder | Add-Member ScriptMethod RegisterTask {
        param($Name, $Xml, $Flags, $User, $Password, $Logon, $Sddl)
        $this.State.Attempts++
        $this.State.Calls.Add(@{ Name = $Name; Xml = $Xml; Flags = $Flags; User = $User; Password = $Password; Logon = $Logon; Sddl = $Sddl })
        # Model the OS CREATE/UPDATE preconditions at the API boundary, including
        # a race after the source's final currentness observation.
        if ($this.State.AppearOnRegister) {
          $this.State.Exists = $true
          $this.State.Task.Xml += '<!-- appeared after protected absence -->'
        }
        if ($this.State.DisappearOnRegister) { $this.State.Exists = $false }
        if ($Flags -notin @(2, 4)) { throw 'Unconditional upsert forbidden.' }
        if ($Flags -eq 2 -and $this.State.Exists) { throw 'Synthetic create found existing task.' }
        if ($Flags -eq 4 -and -not $this.State.Exists) { throw [IO.FileNotFoundException]::new('Synthetic update found no task.') }
        if ($this.State.RegisterFails) {
          if ($this.State.PartialChange) { $this.State.Task.Xml += '<!-- partial registration -->' }
          throw 'SYNTHETIC_CREDENTIAL_SENTINEL_1437 scheduler failure'
        }
        $this.State.Exists = $true
        $this.State.Task.Xml = $Xml
        $this.State.Task.Enabled = [bool]::Parse(([xml]$Xml).Task.Settings.Enabled)
        $this.State.Task
      }
      $script:scheduler = [pscustomobject]@{ Folder = $folder; State = $script:state }
      $script:scheduler | Add-Member ScriptMethod Connect {}
      $script:scheduler | Add-Member ScriptMethod GetFolder {
        param($Path)
        if ($Path -ne '\ATAP-Broker') { throw 'Wrong exact folder.' }
        if ($this.State.FolderFails) { throw [IO.DirectoryNotFoundException]::new('Synthetic exact folder absent.') }
        $this.Folder
      }
      $script:arguments = @{
        TemplatePath = $script:templatePath; BrokerRoot = $script:brokerRoot
        ServiceAccount = 'FIXTURE\SvcAnsibleAdmin'; SecretName = 'Fixture.Secret'
        RequesterPrincipal = 'FIXTURE\Requester'; SkipPayloadDeployment = $true; Confirm = $false
      }
      Mock -ModuleName ProGetRegistrarCredential1437 Test-ElevationBrokerAdministrator { $true }
      Mock -ModuleName ProGetRegistrarCredential1437 Resolve-ElevationBrokerAccountSid { 'S-1-5-21-111-222-333-444' }
      Mock -ModuleName ProGetRegistrarCredential1437 net { 'Synthetic account exists.' }
      Mock -ModuleName ProGetRegistrarCredential1437 schtasks { throw 'Native scheduler forbidden.' }
      Mock -ModuleName ProGetRegistrarCredential1437 Get-SecretATAP { $script:sentinel }
      Mock -ModuleName ProGetRegistrarCredential1437 Write-PSFMessage { param($Message) $script:state.Messages.Add([string]$Message) }
      Mock -ModuleName ProGetRegistrarCredential1437 New-Object {
        param($ComObject)
        if ($ComObject -ne 'Schedule.Service') { throw 'Unapproved object construction.' }
        $script:scheduler
      }
      Mock -ModuleName ProGetRegistrarCredential1437 Copy-Item { throw 'Payload mutation forbidden.' }
      Mock -ModuleName ProGetRegistrarCredential1437 Get-Acl { throw 'Live ACL access forbidden.' }
      Mock -ModuleName ProGetRegistrarCredential1437 Set-Acl { throw 'ACL mutation forbidden.' }
    }
  }
  AfterEach {
    InModuleScope ProGetRegistrarCredential1437 {
      Should -Invoke schtasks -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke Copy-Item -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke Get-Acl -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke Set-Acl -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      ($script:state.Messages -join ';') | Should -Not -Match ([regex]::Escape($script:sentinel))
      foreach ($file in [IO.Directory]::GetFiles($script:caseRoot, '*', [IO.SearchOption]::AllDirectories)) {
        [IO.File]::ReadAllText($file) | Should -Not -Match ([regex]::Escape($script:sentinel))
      }
    }
  }

  It 'declines registration under explicit WhatIf without secret or COM even with payload enabled' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:arguments.SkipPayloadDeployment = $false
      $result = Register-ElevationBrokerTask @script:arguments -WhatIf
      $result.Registered | Should -BeFalse
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke New-Object -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'declines registration through inherited WhatIfPreference without secret or COM' {
    InModuleScope ProGetRegistrarCredential1437 {
      $WhatIfPreference = $true
      try { $result = Register-ElevationBrokerTask @script:arguments }
      finally { $WhatIfPreference = $false }
      $result.Registered | Should -BeFalse
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke New-Object -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
    }
  }
  It 'refuses a nonadministrator before account, secret or COM calls' {
    InModuleScope ProGetRegistrarCredential1437 {
      Mock -ModuleName ProGetRegistrarCredential1437 Test-ElevationBrokerAdministrator { $false }
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Must run ELEVATED*'
      Should -Invoke net -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke New-Object -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
    }
  }
  It 'refuses a SID resolution error before secret or COM calls' {
    InModuleScope ProGetRegistrarCredential1437 {
      Mock -ModuleName ProGetRegistrarCredential1437 Resolve-ElevationBrokerAccountSid { throw 'Synthetic SID failure.' }
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*does not resolve to a SID*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke New-Object -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
    }
  }
  It 'refuses invalid resolved principal XML before secret or COM calls' {
    InModuleScope ProGetRegistrarCredential1437 {
      [IO.File]::WriteAllText($script:templatePath, $script:template.Replace('<LogonType>Password</LogonType>', '<LogonType>S4U</LogonType>'))
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*TemplatePrincipalInvalid*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke New-Object -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
    }
  }
  It 'refuses a nonleaf task name before credential or COM operations' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:arguments.TaskName = '..\OtherTask'
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*BrokerTaskTargetInvalid*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      Should -Invoke New-Object -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
    }
  }
  It 'creates the exact task through one memory-credential API call with CREATE2/logon1' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.Exists = $false
      $result = Register-ElevationBrokerTask @script:arguments
      $result.Registered | Should -BeTrue
      $script:state.Attempts | Should -Be 1
      $call = $script:state.Calls[0]
      $call.Name | Should -BeExactly 'ATAP-ElevatedInstallBroker'
      $call.Flags | Should -Be 2
      $call.Logon | Should -Be 1
      $call.User | Should -BeExactly 'FIXTURE\SvcAnsibleAdmin'
      $call.Password | Should -BeExactly $script:sentinel
      $call.Sddl | Should -BeNullOrEmpty
      $registeredXml = [xml]$call.Xml
      $registeredXml.Task.Settings.Enabled | Should -BeExactly 'false'
      $registeredXml.Task.Triggers.BootTrigger.Enabled | Should -BeExactly 'false'
      $registeredXml.Task.Actions.Exec.Command | Should -BeExactly (Join-Path $script:brokerRoot 'bin\Invoke-ElevationBrokerRequest.ps1')
      $call.Xml | Should -Not -Match '__BROKER_(ROOT|SCRIPT)__|__SERVICE_ACCOUNT__'
      $script:state.Task.Enabled | Should -BeFalse
      $result.BackupPath | Should -BeNullOrEmpty
      ($result | ConvertTo-Json) | Should -Not -Match ([regex]::Escape($script:sentinel))
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 1 -Exactly -ParameterFilter { $SecretName -eq 'Fixture.Secret' }
    }
  }
  It 'updates only after immutable XML/state/SDDL preimages and preserves enabled state' {
    InModuleScope ProGetRegistrarCredential1437 {
      $before = $script:state.Task.Xml
      Mock -ModuleName ProGetRegistrarCredential1437 Get-SecretATAP {
        @([IO.Directory]::GetFiles($script:brokerRoot, '*.state.json', [IO.SearchOption]::AllDirectories)).Count | Should -Be 1
        $script:state.Attempts | Should -Be 0
        $script:sentinel
      }
      $result = Register-ElevationBrokerTask @script:arguments
      $result.Registered | Should -BeTrue
      $state = Get-Content -LiteralPath $result.StatePath -Raw | ConvertFrom-Json
      $state.Xml | Should -BeExactly $before
      $state.Sddl | Should -BeExactly $script:state.Sddl
      $state.Enabled | Should -BeTrue
      $script:state.Calls[0].Sddl | Should -BeExactly $script:state.Sddl
      $script:state.Calls[0].Flags | Should -Be 4
      $script:state.Attempts | Should -Be 1
    }
  }
  It 'preserves an existing disabled task and its enabled BootTrigger on update' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.Task.Enabled = $false
      $script:state.Task.Xml = $script:state.Task.Xml.Replace('<Settings><Enabled>true</Enabled>', '<Settings><Enabled>false</Enabled>')
      $result = Register-ElevationBrokerTask @script:arguments
      $result.Registered | Should -BeTrue
      $script:state.Task.Enabled | Should -BeFalse
      ([xml]$script:state.Calls[0].Xml).Task.Settings.Enabled | Should -BeExactly 'false'
      ([xml]$script:state.Calls[0].Xml).Task.Triggers.BootTrigger.Enabled | Should -BeExactly 'true'
    }
  }
  It 'preserves an existing enabled task with a disabled BootTrigger on update' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.Task.Xml = $script:state.Task.Xml.Replace('<BootTrigger><Enabled>true</Enabled>', '<BootTrigger><Enabled>false</Enabled>')
      $result = Register-ElevationBrokerTask @script:arguments
      $result.Registered | Should -BeTrue
      ([xml]$script:state.Calls[0].Xml).Task.Settings.Enabled | Should -BeExactly 'true'
      ([xml]$script:state.Calls[0].Xml).Task.Triggers.BootTrigger.Enabled | Should -BeExactly 'false'
      $script:state.Task.Enabled | Should -BeTrue
    }
  }
  It 'does not add a BootTrigger when updating a task with no triggers' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.Task.Xml = $script:state.Task.Xml.Replace('<Triggers><BootTrigger><Enabled>true</Enabled></BootTrigger></Triggers>', '')
      $result = Register-ElevationBrokerTask @script:arguments
      $result.Registered | Should -BeTrue
      ([xml]$script:state.Calls[0].Xml).Task.SelectSingleNode("./*[local-name()='Triggers']") | Should -BeNullOrEmpty
      $script:state.Task.Enabled | Should -BeTrue
    }
  }
  It 'preserves enabled BootTrigger semantics without adding a policy flag or starting a task' {
    InModuleScope ProGetRegistrarCredential1437 {
      $result = Register-ElevationBrokerTask @script:arguments
      $result.Registered | Should -BeTrue
      ([xml]$script:state.Calls[0].Xml).Task.Triggers.BootTrigger.Enabled | Should -BeExactly 'true'
      ([xml]$script:state.Calls[0].Xml).Task.Settings.Enabled | Should -BeExactly 'true'
      # The inert fake has no Run/Enable/Delete methods; none may be requested.
      $script:state.Attempts | Should -Be 1
    }
  }
  It 'refuses an unknown lookup failure without secret resolution or registration' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.LookupFails = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=TaskLookup*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'refuses missing folder provisioning without guessing a different folder or reading secret' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.FolderFails = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=TaskFolder*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'refuses an unavailable task preimage before credential resolution' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.BackupFails = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=TaskPreimage*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'refuses concurrent preimage change before credential resolution' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.ChangePreimage = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=TaskPreimageCurrent*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'refuses a foreign existing principal before credential resolution' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.Task.Xml = $script:state.Task.Xml.Replace('FIXTURE\SvcAnsibleAdmin', 'FIXTURE\OtherAccount')
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=TaskPreimage*'
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 0 -Exactly
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'refuses an empty secret with no registration attempt' {
    InModuleScope ProGetRegistrarCredential1437 {
      Mock -ModuleName ProGetRegistrarCredential1437 Get-SecretATAP { '' }
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=Credential*'
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'redacts a throwing getter from public errors and PSFramework messages' {
    InModuleScope ProGetRegistrarCredential1437 {
      Mock -ModuleName ProGetRegistrarCredential1437 Get-SecretATAP { throw "$script:sentinel provider failure" }
      $caught = $null
      try { Register-ElevationBrokerTask @script:arguments } catch { $caught = $_ }
      $caught | Should -Not -BeNullOrEmpty
      $caught.Exception.Message | Should -Match 'Stage=Credential'
      $caught.Exception.Message | Should -Not -Match ([regex]::Escape($script:sentinel))
      $caught.Exception.InnerException | Should -BeNullOrEmpty
      $script:state.Attempts | Should -Be 0
    }
  }
  It 'preserves partial registration evidence without retry or automatic restoration' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.RegisterFails = $true
      $script:state.PartialChange = $true
      $before = $script:state.Task.Xml
      $caught = $null
      try { Register-ElevationBrokerTask @script:arguments } catch { $caught = $_ }
      $caught.Exception.Message | Should -Match 'Stage=Register'
      $caught.Exception.Message | Should -Match 'PartialStatePossible=True'
      $caught.Exception.Message | Should -Not -Match ([regex]::Escape($script:sentinel))
      $script:state.Attempts | Should -Be 1
      $script:state.Task.Xml | Should -Match 'partial registration'
      $snapshots = @([IO.Directory]::GetFiles($script:brokerRoot, '*.state.json', [IO.SearchOption]::AllDirectories))
      $snapshots.Count | Should -Be 1
      (Get-Content $snapshots[0] -Raw | ConvertFrom-Json).Xml | Should -BeExactly $before
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 1 -Exactly
    }
  }
  It 'reports a postregistration readback failure as partial unverified outcome' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.ReadbackFails = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=TaskReadback*'
      $script:state.Attempts | Should -Be 1
      @([IO.Directory]::GetFiles($script:brokerRoot, '*.state.json', [IO.SearchOption]::AllDirectories)).Count | Should -Be 1
    }
  }
  It 'fails CREATE2 if a task appears after protected absence without overwriting it' {
    InModuleScope ProGetRegistrarCredential1437 {
      $script:state.Exists = $false
      $script:state.AppearOnRegister = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=Register*'
      $script:state.Attempts | Should -Be 1
      $script:state.Calls[0].Flags | Should -Be 2
      $script:state.Exists | Should -BeTrue
      $script:state.Task.Xml | Should -Match 'appeared after protected absence'
      @([IO.Directory]::GetFiles($script:brokerRoot, '*.state.json', [IO.SearchOption]::AllDirectories)).Count | Should -Be 0
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 1 -Exactly
    }
  }
  It 'fails UPDATE4 if a protected task disappears without recreating it' {
    InModuleScope ProGetRegistrarCredential1437 {
      $before = $script:state.Task.Xml
      $script:state.DisappearOnRegister = $true
      { Register-ElevationBrokerTask @script:arguments } | Should -Throw '*Stage=Register*'
      $script:state.Attempts | Should -Be 1
      $script:state.Calls[0].Flags | Should -Be 4
      $script:state.Exists | Should -BeFalse
      $snapshots = @([IO.Directory]::GetFiles($script:brokerRoot, '*.state.json', [IO.SearchOption]::AllDirectories))
      $snapshots.Count | Should -Be 1
      (Get-Content $snapshots[0] -Raw | ConvertFrom-Json).Xml | Should -BeExactly $before
      Should -Invoke Get-SecretATAP -ModuleName ProGetRegistrarCredential1437 -Times 1 -Exactly
    }
  }
}
