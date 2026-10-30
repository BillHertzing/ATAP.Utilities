#Requires -Version 7.4

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  if (Get-Module -Name ProGetWriterLF341) { throw 'Dedicated fixture module already loaded.' }
  $publicDirectory = Join-Path $moduleRoot 'public'
  # Keep every mock in this fixture module so Pester's own commands stay native.
  $fixtureModule = New-Module -Name ProGetWriterLF341 -ArgumentList $publicDirectory -ScriptBlock {
    param([string]$PublicDirectory)
    . (Join-Path $PublicDirectory 'Register-ATAPParityScheduledTasks.ps1')
    . (Join-Path $PublicDirectory 'Register-ElevationBrokerTask.ps1')

    # Local fail-closed stubs prevent native executable or credential fallthrough.
    function schtasks { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Unmocked schtasks.' }
    function net { param([Parameter(ValueFromRemainingArguments)]$Arguments) throw 'Unmocked net.' }
    function Get-SecretATAP { param($SecretName) throw 'Unmocked secret read.' }
    function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }

    function ConvertTo-WriterTestPath {
      param([string]$Path)
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

    $script:runRoot = 'D:\ATAPArtifacts\Sprint0017\Task17.9.b\ProGetHarnessFix341\TestRuns\' + [guid]::NewGuid().ToString('N')
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

Describe 'Scheduled task new text writers' -Tag 'Unit' {
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
        [IO.Path]::Combine((ConvertTo-WriterTestPath $Path), [string]$ChildPath)
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
        if ([string]$LiteralPath -like 'C:\*') {
          if ($LiteralPath -eq 'C:\Program Files\ATAP\ParityDispatchers') { return $false }
          if ($LiteralPath -like 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell\*' -or
              $LiteralPath -like 'C:\ProgramData\ATAP\ParityState\Configuration\*' -or
              $LiteralPath -eq 'C:\Program Files\PowerShell\7\pwsh.exe') { return $true }
          throw "Unexpected external read: $LiteralPath"
        }
        Assert-WriterTestPath $LiteralPath
        $fixtureInstall = [IO.Path]::Combine($script:caseRoot, 'C-drive', 'Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell')
        $fixtureConfiguration = [IO.Path]::Combine($script:caseRoot, 'C-drive', 'ProgramData\ATAP\ParityState\Configuration')
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
      $folder | Add-Member ScriptMethod GetTask { param($Name) $this.Tasks[$Name] }
      $folder | Add-Member ScriptMethod RegisterTaskDefinition { throw 'Task registration must never occur.' }
      $script:scheduler = [pscustomobject]@{ Folder = $folder }
      $script:scheduler | Add-Member ScriptMethod Connect {}
      $script:scheduler | Add-Member ScriptMethod GetFolder { param($Path) if ($Path -ne '\ATAP') { throw 'Wrong folder.' }; $this.Folder }
      Mock -ModuleName ProGetWriterLF341 New-Object { $script:scheduler } -ParameterFilter { $ComObject -eq 'Schedule.Service' }

      $script:brokerRoot = [IO.Path]::Combine($script:caseRoot, 'broker')
      [void][IO.Directory]::CreateDirectory([IO.Path]::Combine($script:brokerRoot, 'bin'))
      [IO.File]::WriteAllText([IO.Path]::Combine($script:brokerRoot, 'bin', 'Invoke-ElevationBrokerRequest.ps1'), '# fixture' + [char]10)
      [IO.File]::WriteAllText([IO.Path]::Combine($script:brokerRoot, 'config.json'), '{}' + [char]10)
      $script:templatePath = [IO.Path]::Combine($script:caseRoot, 'template.xml')
      $script:templateXml = '<?xml version="1.0" encoding="UTF-16"?><Task><Actions><Exec><Command>__BROKER_SCRIPT__</Command></Exec></Actions><Principals><Principal><UserId>__SERVICE_ACCOUNT__</UserId></Principal></Principals></Task>'
      [IO.File]::WriteAllText($script:templatePath, $script:templateXml, [Text.UnicodeEncoding]::new($false, $true))
      $script:brokerArguments = @{
        TemplatePath = $script:templatePath; BrokerRoot = $script:brokerRoot
        ServiceAccount = 'FIXTURE\SvcAnsibleAdmin'; SecretName = 'Fixture.Secret'
        RequesterPrincipal = 'FIXTURE\Requester'; SkipPayloadDeployment = $true; Confirm = $false
      }
      $script:xmlLf = '<?xml version="1.0" encoding="UTF-16"?>' + [char]10 +
        '<Task><Actions><Exec><Arguments>-EncodedCommand QQAmAD0A &amp; literal</Arguments></Exec></Actions><Description>café λ</Description></Task>'
      $script:exportXml = @($script:xmlLf -split [char]10)
      $script:createdXml = $null
      $script:historicalPath = [IO.Path]::Combine($script:caseRoot, 'historical.xml')
      $script:historicalBytes = [byte[]]@(255, 254, 60, 0, 120, 0, 47, 0, 62, 0, 13, 0, 10, 0)
      [IO.File]::WriteAllBytes($script:historicalPath, $script:historicalBytes)
      Mock -ModuleName ProGetWriterLF341 net { 'Fixture service account exists.' }
      Mock -ModuleName ProGetWriterLF341 schtasks {
        param($Arguments)
        $global:LASTEXITCODE = 0
        if ($Arguments[0] -eq '/query' -and $Arguments -contains '/xml') { return $script:exportXml }
        if ($Arguments[0] -eq '/query' -and $Arguments -contains '/fo') { return 'Status: Ready' }
        if ($Arguments[0] -eq '/query') { return 'Existing fixture task' }
        if ($Arguments[0] -eq '/delete') { return }
        if ($Arguments[0] -eq '/create') {
          $xmlIndex = [array]::IndexOf($Arguments, '/xml')
          Assert-WriterTestPath $Arguments[$xmlIndex + 1]
          $script:createdXml = [IO.File]::ReadAllText($Arguments[$xmlIndex + 1])
          return
        }
        throw 'Unexpected schtasks arguments.'
      }
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
      $script:createdXml | Should -Be $expectedCreate
      Should -Invoke Test-ElevationBrokerAdministrator -ModuleName ProGetWriterLF341 -Times 1 -Exactly
      Should -Invoke Resolve-ElevationBrokerAccountSid -ModuleName ProGetWriterLF341 -Times 1 -Exactly -ParameterFilter { $ServiceAccount -eq 'FIXTURE\SvcAnsibleAdmin' }
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 1 -Exactly -ParameterFilter { $Arguments[0] -eq '/delete' }
    }
  }

  It 'does not export or register a broker task under WhatIf' {
    InModuleScope ProGetWriterLF341 {
      Register-ElevationBrokerTask @script:brokerArguments -WhatIf | Out-Null
      @([IO.Directory]::GetFiles($script:brokerRoot, '*.xml', [IO.SearchOption]::AllDirectories)).Count | Should -Be 0
      Should -Invoke schtasks -ModuleName ProGetWriterLF341 -Times 1 -Exactly -ParameterFilter { $Arguments -contains '/fo' }
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
