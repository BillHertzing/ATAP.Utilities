#Requires -Modules Pester

# Task 13.76.g — elevation broker contract.
#
# This broker runs as an administrator and takes its input from a folder an unelevated
# caller can write to, so most of these tests are adversarial by design: they assert
# that a malicious or malformed request is REFUSED. A regression here is a local
# privilege escalation, not a cosmetic defect.

BeforeAll {
  $script:Here = $PSScriptRoot
  $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:ResourceRoot = Join-Path $script:ModuleRoot 'Resources\ElevationBroker'
  $script:BrokerScript = Join-Path $script:ResourceRoot 'Invoke-ElevationBrokerRequest.ps1'
  $script:ClientScript = Join-Path $script:ModuleRoot 'public\Request-ElevatedInstall.ps1'
  $script:TaskXml = Join-Path $script:ResourceRoot 'ATAP-ElevatedInstallBroker.xml'
  $script:ConfigTemplate = Join-Path $script:ResourceRoot 'ElevationBroker-config.template.json'
  $script:Installer = Join-Path $script:ResourceRoot 'Install-ATAPModule-AllUsers.ps1'

  # The broker's main body throws when not elevated, so load only its function
  # definitions. This keeps the suite runnable unelevated while still exercising the
  # validation logic that carries the security weight.
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:BrokerScript, [ref]$null, [ref]$null)
  foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([scriptblock]::Create($fn.Extent.Text))
  }
  $script:ForbiddenWriteIdentities = @('Everyone', 'BUILTIN\Users', 'NT AUTHORITY\Authenticated Users', 'NT AUTHORITY\INTERACTIVE')
  $script:WriteRights = @(
    [System.Security.AccessControl.FileSystemRights]::Write,
    [System.Security.AccessControl.FileSystemRights]::WriteData,
    [System.Security.AccessControl.FileSystemRights]::CreateFiles,
    [System.Security.AccessControl.FileSystemRights]::Modify,
    [System.Security.AccessControl.FileSystemRights]::FullControl
  )

  $script:Config = Get-Content -LiteralPath $script:ConfigTemplate -Raw | ConvertFrom-Json
  $script:Allowed = ($script:Config.installers | Where-Object id -eq 'install-atap-module-allusers').allowedParameters
}

Describe 'Elevation broker artifacts' {
  It '<Name> parses without syntax errors' -ForEach @(
    @{ Name = 'Invoke-ElevationBrokerRequest.ps1' }
    @{ Name = 'Request-ElevatedInstall.ps1' }
  ) {
    $errors = $null
    $artifactPath = if ($Name -eq 'Invoke-ElevationBrokerRequest.ps1') { $script:BrokerScript } else { $script:ClientScript }
    [void][System.Management.Automation.Language.Parser]::ParseFile(
      $artifactPath, [ref]$null, [ref]$errors)
    $errors.Count | Should -Be 0
  }

  It 'registers the scheduled task with highest privileges and a drain-and-exit action' {
    $xml = [xml](Get-Content -LiteralPath $script:TaskXml -Raw)
    $xml.Task.Principals.Principal.RunLevel | Should -Be 'HighestAvailable'
    $xml.Task.Triggers.BootTrigger.Enabled | Should -Be 'true'
    $xml.Task.Actions.Exec.Command | Should -Be 'pwsh.exe'
    # -Once matters: without it an elevated process would sit resident indefinitely.
    $xml.Task.Actions.Exec.Arguments | Should -Match '-Once'
    $xml.Task.Actions.Exec.Arguments | Should -Match '-NonInteractive'
  }

  It 'ships a module-kind entry pointing at the promoted installer' {
    # Task 13.76.c moved the installer into ATAP.Utilities.BuildTooling.ProGet.PowerShell,
    # so the template no longer pins a script hash. The module form's integrity control is
    # the trusted root plus the version floor, both of which must be present and sane.
    $config = Get-Content -LiteralPath $script:ConfigTemplate -Raw | ConvertFrom-Json
    $entry = $config.installers | Where-Object id -eq 'install-atap-module-allusers'

    $entry.commandType | Should -Be 'module'
    $entry.moduleName | Should -Be 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    $entry.commandName | Should -Be 'Install-ATAPModuleAllUsers'
    { [version]$entry.minimumModuleVersion } | Should -Not -Throw
    @($entry.trustedModuleRoots).Count | Should -BeGreaterThan 0
    # A trusted root must be admin-only. A user-writable root would defeat the whole control.
    foreach ($root in @($entry.trustedModuleRoots)) {
      $root | Should -Match '^[A-Za-z]:\\Program Files'
    }
    # No stale script pin left behind to imply an integrity check that no longer runs.
    $entry.PSObject.Properties.Name | Should -Not -Contain 'sha256'
  }

  It 'ships the parity-task installer with only an exact module-version request field' {
    $config = Get-Content -LiteralPath $script:ConfigTemplate -Raw | ConvertFrom-Json
    $entry = $config.installers | Where-Object id -eq 'register-atap-parity-tasks'

    $entry.commandType | Should -Be 'module'
    $entry.moduleName | Should -Be 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    $entry.commandName | Should -Be 'Register-ATAPParityScheduledTasks'
    $entry.minimumModuleVersion | Should -Be '0.1.15'
    @($entry.allowedParameters).Count | Should -Be 1
    $entry.allowedParameters[0].name | Should -Be 'ModuleVersion'
    $entry.allowedParameters[0].pattern | Should -Be '^\d+\.\d+\.\d+(\.\d+)?$'
  }

  It 'preserves every task field that is not the action, and drains output before waiting' {
    $installerPath = Join-Path $script:ModuleRoot 'public\Register-ATAPParityScheduledTasks.ps1'
    $installerText = Get-Content -LiteralPath $installerPath -Raw

    # Regression guard for 0.1.8: PowerShell does not use backslash as a string escape,
    # so "scripts\\$name" required two literal path separators and rejected every task.
    $installerText | Should -Not -Match [regex]::Escape('scripts\\$($policy.Script)')

    # The invariant set is the evidence that only the action moved. Dropping a field here
    # would let a widened principal or security descriptor pass as a clean action swap.
    $installerText | Should -Match ([regex]::Escape('$RegisteredTask.GetSecurityDescriptor(7)'))
    foreach ($field in 'Principal', 'Triggers', 'Settings', 'TaskVersion', 'ActionId', 'ActionWorkingDirectory', 'SecurityDescriptor') {
      $installerText | Should -Match "(?m)^\s+$field\s+="
    }
    $installerText | Should -Match 'Automatic action rollback ALSO FAILED'

    # R-34: both redirected streams must be draining before the wait, or a full buffer deadlocks.
    $installerText.IndexOf('$stdoutTask = $process.StandardOutput.ReadToEndAsync()') |
      Should -BeLessThan $installerText.IndexOf('$process.WaitForExitAsync($timeout.Token)')

    # stdin must be closed: schtasks PROMPTS for the run-as password on a Password-logon task,
    # and an open stdin turned that prompt into an indefinite broker hang on 2026-08-11.
    $installerText.IndexOf('$process.StandardInput.Close()') |
      Should -BeLessThan $installerText.IndexOf('$process.WaitForExitAsync($timeout.Token)')
  }

  Context 'parity installer host policy (Task 14.72.c)' {
    BeforeAll {
      $script:InstallerPath = Join-Path $script:ModuleRoot 'public\Register-ATAPParityScheduledTasks.ps1'
      . $script:InstallerPath

      # Drive the real command's BEGIN-block policy resolution without touching Task Scheduler.
      # -WhatIf stops before any write, so this exercises validation only.
      $script:InvokeForHost = {
        param([string] $HostName, [string] $Version = '0.1.14')
        $original = $env:COMPUTERNAME
        try {
          $env:COMPUTERNAME = $HostName
          Register-ATAPParityScheduledTasks -ModuleVersion $Version -WhatIf -ErrorAction Stop 2>&1
        }
        finally {
          $env:COMPUTERNAME = $original
        }
      }
    }

    It 'refuses a host with no approved parity policy' {
      { & $script:InvokeForHost -HostName 'SOMEOTHERHOST' } |
        Should -Throw -ExpectedMessage '*has no approved parity-task policy*'
    }

    It 'refuses a malformed semantic version before doing anything' {
      foreach ($bad in '0.1', 'latest', '0.1.14-beta', '../0.1.14', '0.1.14; whoami', '') {
        { Register-ATAPParityScheduledTasks -ModuleVersion $bad -WhatIf -ErrorAction Stop } | Should -Throw
      }
    }

    It 'refuses a version carrying traversal, UNC, or an alternate executable path' {
      foreach ($bad in '..\..\Windows\System32', '\\evil\share\0.1.14', 'C:\Temp\0.1.14', '0.1.14\..\..\0.1.1') {
        { Register-ATAPParityScheduledTasks -ModuleVersion $bad -WhatIf -ErrorAction Stop } | Should -Throw
      }
    }

    It 'accepts only the two approved task names, per host' {
      $text = Get-Content -LiteralPath $script:InstallerPath -Raw
      # utat01 is audit-only; utat022 additionally runs the compare task.
      $text | Should -Match "'utat01'\s*="
      $text | Should -Match "'utat022'\s*="
      $names = [regex]::Matches($text, "Name\s+=\s+'(ATAP-Parity\w+)'") | ForEach-Object { $_.Groups[1].Value }
      @($names | Sort-Object -Unique) | Should -Be @('ATAP-ParityAudit', 'ATAP-ParityCompare')
    }

    It 'binds each host to its approved logon type and run level' {
      $text = Get-Content -LiteralPath $script:InstallerPath -Raw
      # UTAT01 stays S4U/Limited and non-administrative; UTAT022 keeps Password/Highest for peer SMB.
      $text | Should -Match "LogonType\s+=\s+'S4U'"
      $text | Should -Match "RunLevel\s+=\s+'Limited'"
      $text | Should -Match "LogonType\s+=\s+'Password'"
      $text | Should -Match "RunLevel\s+=\s+'HighestAvailable'"
      # A principal mismatch must abort BEFORE any privileged mutation.
      $text | Should -Match 'policy requires'
    }
  }

  Context 'parity installer credential handling (Task 14.72.c)' {
    BeforeAll {
      $script:InstallerText = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'public\Register-ATAPParityScheduledTasks.ps1') -Raw
    }

    It 'never exposes the run-as credential as a broker-supplied parameter' {
      # TaskCredential exists for tests only. If it ever appears in allowedParameters, an
      # unelevated caller could hand the broker a password and choose the run-as identity.
      $entry = $script:Config.installers | Where-Object id -eq 'register-atap-parity-tasks'
      @($entry.allowedParameters).Count | Should -Be 1
      @($entry.allowedParameters.name) | Should -Not -Contain 'TaskCredential'
    }

    It 'resolves the credential only by canonical SecretName, never from a literal' {
      $script:InstallerText | Should -Match ([regex]::Escape('"SvcParityAudit.$ForHost"'))
      $script:InstallerText | Should -Match "Get-SecretATAP -SecretName \`$secretName -SecretStoreType 'BitwardenSecretsManager'"
      # No password may be written into source under any guise.
      $script:InstallerText | Should -Not -Match '(?i)(password|secret)\s*=\s*[''"][^''"$]{6,}[''"]'
    }

    It 'refuses to resolve a credential for any identity but the approved parity account' {
      $script:InstallerText | Should -Match 'is not the approved parity identity'
      $script:InstallerText | Should -Match ([regex]::Escape('$expectedAccount = "$($env:COMPUTERNAME)\SvcParityAudit"'))
    }

    It 'never returns or records the credential' {
      # The emitted record is the only thing that reaches the broker result file and transcript.
      $emitted = [regex]::Match($script:InstallerText, '(?s)\[pscustomobject\]@\{\s*TaskName.*?\}').Value
      $emitted | Should -Not -Match '(?i)credential|password|secret'
      $script:InstallerText | Should -Match ([regex]::Escape('$migrationCredential = $null'))
    }

    It 'resolves no credential at all for an S4U task' {
      # S4U carries no stored password, so the migration path for utat01 must not touch the vault.
      $script:InstallerText | Should -Match ([regex]::Escape("if (`$policy.LogonType -eq 'Password')"))
      $credentialCall = $script:InstallerText.IndexOf('$resolveTaskCredential -RegisteredTaskXml')
      $credentialCall | Should -BeGreaterThan 0
      # The only invocation sits inside the Password branch, after that guard.
      $credentialCall | Should -BeGreaterThan $script:InstallerText.IndexOf("if (`$policy.LogonType -eq 'Password')")
    }
  }

  Context 'parity installer dispatcher trust (Task 14.72.c)' {
    BeforeAll {
      $script:InstallerText = Get-Content -LiteralPath (Join-Path $script:ModuleRoot 'public\Register-ATAPParityScheduledTasks.ps1') -Raw
    }

    It 'keeps the dispatcher root version-independent' {
      # Putting the dispatcher under this module's versioned base would force a fresh privileged
      # task mutation on every broker release -- the exact failure this design removes.
      $script:InstallerText | Should -Match ([regex]::Escape("'C:\Program Files\ATAP\ParityDispatchers'"))
      $script:InstallerText | Should -Not -Match ([regex]::Escape("Join-Path `$brokerModuleRoot 'dispatchers'"))
    }

    It 'refuses to write a dispatcher into a directory an untrusted identity can write' {
      $script:InstallerText | Should -Match 'is writable by an untrusted identity'
      foreach ($identity in 'Everyone', 'BUILTIN\\Users', 'NT AUTHORITY\\Authenticated Users', 'NT AUTHORITY\\INTERACTIVE') {
        $script:InstallerText | Should -Match $identity
      }
      # AppendData and ChangePermissions are as good as write for this purpose.
      foreach ($right in 'AppendData', 'ChangePermissions', 'TakeOwnership') {
        $script:InstallerText | Should -Match $right
      }
    }

    It 'refuses a task whose action is not an approved parity action' {
      $script:InstallerText | Should -Match 'does not reference an approved parity action'
    }

    It 'launches the approved script with -File, never the call operator' {
      # The parity scripts end in an &-proof dual-purpose guard:
      #   if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&')
      # so `& $script` returns exit 0 having collected NOTHING. A dispatcher that used the
      # call operator would produce a permanently green task that never writes a snapshot.
      $script:InstallerText | Should -Match ([regex]::Escape("-ExecutionPolicy Bypass -File '`$(`$scriptPath -replace"))
      $script:InstallerText | Should -Not -Match ([regex]::Escape("`"& '`$(`$scriptPath -replace `"'`", `"''`")' `$quotedArguments`""))
    }

    It 'still guards every targetable parity script with the dual-purpose pattern' {
      # The guard first shipped in SystemParityMonitor 0.1.9. Versions below that are not
      # repoint targets, so only 0.1.9+ is asserted here; the boundary is recorded so a
      # future reader knows why the dispatcher must use -File rather than the call operator.
      $parityRoot = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.SystemParityMonitor.PowerShell'
      if (-not (Test-Path -LiteralPath $parityRoot)) {
        Set-ItResult -Skipped -Because 'SystemParityMonitor is not installed on this host.'
        return
      }
      $guardIntroduced = [version] '0.1.9'
      $targetable = @(Get-ChildItem -LiteralPath $parityRoot -Directory |
          Where-Object { ($_.Name -as [version]) -and ([version] $_.Name) -ge $guardIntroduced })
      if ($targetable.Count -eq 0) {
        Set-ItResult -Skipped -Because 'No SystemParityMonitor 0.1.9+ is installed on this host.'
        return
      }
      foreach ($versionDir in $targetable) {
        foreach ($leaf in 'Invoke-ParityScheduledAuditTask.ps1', 'Invoke-ParityScheduledCompareTask.ps1') {
          $parityScript = Join-Path $versionDir.FullName (Join-Path 'scripts' $leaf)
          if (-not (Test-Path -LiteralPath $parityScript -PathType Leaf)) { continue }
          (Get-Content -LiteralPath $parityScript -Raw) |
            Should -Match ([regex]::Escape('$MyInvocation.InvocationName -ne')) -Because "$($versionDir.Name)\$leaf must keep the &-proof guard"
        }
      }
    }

    It 'produces a task action within the schtasks /TR limit' {
      # The 261-character /TR limit blocked the direct-script action on 2026-08-11. Prove the
      # longest approved dispatcher action clears it with room to spare.
      $pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
      $dispatcher = 'C:\Program Files\ATAP\ParityDispatchers\ATAP-ParityCompare.ps1'
      $taskRun = "`"$pwshPath`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$dispatcher`""
      $taskRun.Length | Should -BeLessThan 261
    }
  }

  It 'never lets a request name what runs' {
    # The whole trust model: executables live only in the admin-owned config.
    $clientText = Get-Content -LiteralPath $script:ClientScript -Raw
    $clientText | Should -Not -Match '(?m)^\s*\[string\]\s*\$(ScriptPath|InstallerPath|Path)\b'
    $names = @($script:Config.installers | ForEach-Object { $_.allowedParameters.name })
    foreach ($forbidden in 'ScriptPath', 'Path', 'CommandName', 'ModulePath') {
      $names | Should -Not -Contain $forbidden
    }
  }

  It 'keeps the allowlist in step with the real cmdlet contract' {
    # Drift guard. The config and the cmdlet are edited independently, and a mismatch is not
    # caught by any unit test that mocks the command away: marking a MANDATORY parameter
    # optional lets the broker accept a request that then dies in parameter binding, and
    # naming a parameter the cmdlet does not have lets it die on an unknown argument. Both
    # happened on 2026-07-25 (FeedUrl and ExpectedSha256 were marked optional).
    #
    # Skipped, with a stated reason, when the promoted module is not installed on this host --
    # there is nothing to compare against then, and a silent pass would be misleading.
    $entry = $script:Config.installers | Where-Object id -eq 'install-atap-module-allusers'
    $module = Get-Module -ListAvailable -Name $entry.moduleName -ErrorAction SilentlyContinue |
      Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
      Set-ItResult -Skipped -Because "$($entry.moduleName) is not installed on this host, so the cmdlet contract cannot be read"
      return
    }

    Import-Module $module.Path -Force -ErrorAction Stop
    $cmd = Get-Command -Name $entry.commandName -Module $entry.moduleName -ErrorAction Stop

    $common = [System.Management.Automation.PSCmdlet]::CommonParameters + @('WhatIf', 'Confirm')
    $cmdParams = @($cmd.Parameters.Keys | Where-Object { $_ -notin $common })
    $mandatory = @(
      $cmdParams | Where-Object {
        @($cmd.Parameters[$_].Attributes |
          Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }).Count -gt 0
      }
    )
    $allowed = @($entry.allowedParameters)

    # Every allowlisted name must actually exist on the cmdlet.
    foreach ($p in $allowed) { $cmdParams | Should -Contain $p.name }

    # Every mandatory parameter must be allowlisted AND marked required, or the broker will
    # happily forward an incomplete request.
    foreach ($m in $mandatory) {
      $match = $allowed | Where-Object name -EQ $m
      $match | Should -Not -BeNullOrEmpty -Because "$m is mandatory on $($entry.commandName)"
      $match.required | Should -BeTrue -Because "$m is mandatory on $($entry.commandName)"
    }
  }

  It 'does not let a request choose where the broker writes' {
    # ModulesRoot decides where an ADMINISTRATOR writes modules; DeployRoot decides where the
    # audit trail lands. Both are real parameters of Install-ATAPModuleAllUsers, so the only
    # thing keeping them out of a caller's hands is their absence from this positive allowlist.
    $names = @($script:Config.installers[0].allowedParameters.name)
    $names | Should -Not -Contain 'ModulesRoot'
    $names | Should -Not -Contain 'DeployRoot'
  }
}

Describe 'Get-BrokerConfig' {
  It 'rejects a config whose installer pin is not a SHA-256' {
    $p = Join-Path $TestDrive 'bad-hash.json'
    '{"installers":[{"id":"x","path":"C:\\x.ps1","sha256":"nothex","allowedParameters":[]}]}' |
      Set-Content -LiteralPath $p
    { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage '*malformed sha256*'
  }

  It 'rejects a config whose installer omits a required field' {
    $p = Join-Path $TestDrive 'missing-field.json'
    '{"installers":[{"id":"x","path":"C:\\x.ps1","allowedParameters":[]}]}' | Set-Content -LiteralPath $p
    { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage "*missing 'sha256'*"
  }

  It 'rejects a config that declares no installers' {
    $p = Join-Path $TestDrive 'empty.json'
    '{"installers":[]}' | Set-Content -LiteralPath $p
    { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage '*no installers*'
  }

  It 'rejects an absent config rather than defaulting to permissive' {
    { Get-BrokerConfig -Path (Join-Path $TestDrive 'nope.json') } |
      Should -Throw -ExpectedMessage '*not found*'
  }

  It 'accepts the shipped template' {
    $p = Join-Path $TestDrive 'good.json'
    Copy-Item -LiteralPath $script:ConfigTemplate -Destination $p
    $config = Get-BrokerConfig -Path $p
    @($config.installers).Count | Should -Be 2
    @($config.installers.id) | Should -Contain 'install-atap-module-allusers'
  }

  Context 'module-kind entries (Task 13.76.c)' {
    BeforeAll {
      function script:New-ModuleConfig {
        param([hashtable] $Override = @{})
        $entry = [ordered]@{
          id                   = 'm'
          commandType          = 'module'
          moduleName           = 'Some.Module'
          commandName          = 'Install-Thing'
          minimumModuleVersion = '1.0.0'
          trustedModuleRoots   = @('C:\Program Files\PowerShell\Modules')
          allowedParameters    = @()
        }
        foreach ($k in $Override.Keys) {
          if ($null -eq $Override[$k]) { $entry.Remove($k) } else { $entry[$k] = $Override[$k] }
        }
        $p = Join-Path $TestDrive "mod-$([guid]::NewGuid().ToString('N')).json"
        (@{ installers = @($entry) } | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $p
        return $p
      }
    }

    It 'accepts a well-formed module entry' {
      $config = Get-BrokerConfig -Path (script:New-ModuleConfig)
      $config.installers[0].commandName | Should -Be 'Install-Thing'
    }

    It 'infers module kind from moduleName even without commandType' {
      Get-BrokerInstallerKind -Installer ([pscustomobject]@{ moduleName = 'X' }) | Should -Be 'module'
    }

    It 'still treats a bare path entry as script kind' {
      Get-BrokerInstallerKind -Installer ([pscustomobject]@{ path = 'C:\x.ps1' }) | Should -Be 'script'
    }

    It 'rejects a module entry missing <Missing>' -ForEach @(
      @{ Missing = 'moduleName' }
      @{ Missing = 'commandName' }
      @{ Missing = 'minimumModuleVersion' }
      @{ Missing = 'trustedModuleRoots' }
    ) {
      # A half-converted entry must fail at LOAD, not after a request has been claimed.
      $p = script:New-ModuleConfig -Override @{ $Missing = $null; commandType = 'module' }
      { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage "*missing '$Missing'*"
    }

    It 'rejects a module entry with an empty trusted-root list' {
      # Empty means "trust anywhere", which is exactly the hole the list exists to close.
      $p = script:New-ModuleConfig -Override @{ trustedModuleRoots = @() }
      { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage '*no trustedModuleRoots*'
    }

    It 'rejects a malformed minimumModuleVersion' {
      $p = script:New-ModuleConfig -Override @{ minimumModuleVersion = 'latest' }
      { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage '*malformed minimumModuleVersion*'
    }

    It 'rejects an unknown commandType rather than guessing' {
      $p = script:New-ModuleConfig -Override @{ commandType = 'binary' }
      { Get-BrokerConfig -Path $p } | Should -Throw -ExpectedMessage '*unknown commandType*'
    }
  }
}

Describe 'Resolve-BrokerModuleCommand' {
  BeforeAll {
    # Stand up two fake installs of the same module: one under a "trusted" root, one under a
    # user-writable root, so the trusted-root filter can be proven rather than assumed.
    $script:TrustedRoot = Join-Path $TestDrive 'TrustedRoot'
    $script:UntrustedRoot = Join-Path $TestDrive 'UserWritable'
    $script:FakeName = 'Fake.Broker.Module'

    function script:New-FakeModule {
      param([string] $Root, [string] $Version, [string] $Marker)
      $base = Join-Path (Join-Path $Root $script:FakeName) $Version
      New-Item -ItemType Directory -Path $base -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $base "$script:FakeName.psm1") `
        -Value "function Install-Thing { [CmdletBinding()] param([string]`$Whatever) return '$Marker' }"
      $manifest = @"
@{
  ModuleVersion = '$Version'
  RootModule = '$script:FakeName.psm1'
  GUID = '$([guid]::NewGuid())'
  Author = 'test'
  FunctionsToExport = @('Install-Thing')
}
"@
      Set-Content -LiteralPath (Join-Path $base "$script:FakeName.psd1") -Value $manifest
      return $base
    }

    $script:TrustedBase = script:New-FakeModule -Root $script:TrustedRoot -Version '1.2.0' -Marker 'trusted'
    $script:OldTrustedBase = script:New-FakeModule -Root $script:TrustedRoot -Version '0.9.0' -Marker 'old-trusted'
    $script:EvilBase = script:New-FakeModule -Root $script:UntrustedRoot -Version '9.9.9' -Marker 'evil'

    $script:SavedModulePath = $env:PSModulePath
    # The untrusted root is FIRST, exactly as a PSModulePath hijack would arrange it.
    $env:PSModulePath = "$script:UntrustedRoot;$script:TrustedRoot;$script:SavedModulePath"

    function script:New-Installer {
      param([string] $MinVersion = '1.0.0', [string[]] $Roots = @($script:TrustedRoot))
      [pscustomobject]@{
        id                   = 'fake'
        commandType          = 'module'
        moduleName           = $script:FakeName
        commandName          = 'Install-Thing'
        minimumModuleVersion = $MinVersion
        trustedModuleRoots   = $Roots
      }
    }
  }

  AfterAll {
    $env:PSModulePath = $script:SavedModulePath
    Remove-Module $script:FakeName -Force -ErrorAction SilentlyContinue
  }

  It 'resolves the highest version under a trusted root' {
    $r = Resolve-BrokerModuleCommand -Installer (script:New-Installer)
    $r.ModuleVersion | Should -Be '1.2.0'
    ([IO.Path]::GetFullPath($r.ModuleBase)).TrimEnd('\') | Should -Be ([IO.Path]::GetFullPath($script:TrustedBase)).TrimEnd('\')
  }

  It 'ignores a higher version sitting under an untrusted root' {
    # This is the PSModulePath-hijack case: 9.9.9 is newer AND earlier on the path, and must
    # still lose to 1.2.0 because only the trusted root counts.
    $r = Resolve-BrokerModuleCommand -Installer (script:New-Installer)
    $r.ModuleVersion | Should -Not -Be '9.9.9'
    $r.ModuleBase | Should -Not -Match 'UserWritable'
  }

  It 'refuses when only an untrusted copy exists' {
    $r = script:New-Installer -Roots @((Join-Path $TestDrive 'NoSuchRoot'))
    { Resolve-BrokerModuleCommand -Installer $r } |
      Should -Throw -ExpectedMessage '*under a trusted root*'
  }

  It 'refuses when the trusted copy is below the version floor' {
    # A stale copy that predates a security fix must not be selected merely because it exists.
    { Resolve-BrokerModuleCommand -Installer (script:New-Installer -MinVersion '5.0.0') } |
      Should -Throw -ExpectedMessage '*under a trusted root*'
  }

  It 'refuses when the resolved module does not export the command' {
    $installer = script:New-Installer
    $installer.commandName = 'Not-Exported'
    { Resolve-BrokerModuleCommand -Installer $installer } |
      Should -Throw -ExpectedMessage '*does not export*'
  }

  It 'returns an invocable command from the trusted copy' {
    $r = Resolve-BrokerModuleCommand -Installer (script:New-Installer)
    (& $r.Command) | Should -Be 'trusted'
  }
}

Describe 'Test-BrokerRequestParameters' {
  Context 'accepts legitimate requests' {
    It 'accepts the minimum required set' {
      # All five are required: Install-ATAPModuleAllUsers makes FeedUrl and ExpectedSha256
      # mandatory, because an unpinned install is not a validated install.
      $r = Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
          ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell'
          RequiredVersion = '0.1.71'
          Repository = 'powershellget-stable'
          FeedUrl = 'https://utat022:50000/nuget/powershellget-stable'
          ExpectedSha256 = '8D97C6C46CD2282DD3DE78548BBE07E1617DFCD45994C681CFF831AA4BAC50A1'
        })
      $r.Count | Should -Be 5
      $r.ModuleName | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
    }

    It 'refuses a request that omits the now-required FeedUrl' {
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = '1.0.0'; Repository = 'powershellget-stable'
            ExpectedSha256 = ('B' * 64) }) } |
        Should -Throw -ExpectedMessage "*Required parameter 'FeedUrl' was not supplied*"
    }

    It 'refuses a request that omits the now-required ExpectedSha256' {
      # Refusing here is strictly better than letting the cmdlet's parameter binding fail:
      # the broker names the missing value, the binder just says the command cannot process.
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = '1.0.0'; Repository = 'powershellget-stable'
            FeedUrl = 'https://utat022:50000/nuget/powershellget-stable' }) } |
        Should -Throw -ExpectedMessage "*Required parameter 'ExpectedSha256' was not supplied*"
    }

    It 'accepts every optional parameter when well formed' {
      $r = Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
          ModuleName = 'ATAP.Utilities.PowerShell'
          RequiredVersion = '0.1.10'
          Repository = 'powershellget-stable'
          FeedUrl = 'https://utat022:50000/nuget/powershellget-stable'
          ExpectedSha256 = '8D97C6C46CD2282DD3DE78548BBE07E1617DFCD45994C681CFF831AA4BAC50A1'
        })
      $r.Count | Should -Be 5
    }

    It 'accepts a prerelease version' {
      $r = Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
          ModuleName = 'A'; RequiredVersion = '1.2.3-beta.1'; Repository = 'powershellget-experimental'
          FeedUrl = 'https://utat022:50000/nuget/powershellget-experimental'
          ExpectedSha256 = ('C' * 64) })
      $r.RequiredVersion | Should -Be '1.2.3-beta.1'
    }
  }

  Context 'refuses privilege-escalation attempts' {
    It 'refuses a parameter that is not on the allowlist' {
      # The primary escape hatch: smuggling in a parameter the installer author never
      # meant a caller to control.
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = '1.0.0'; Repository = 'powershellget-stable'
            ScriptPath = 'C:\evil.ps1' }) } |
        Should -Throw -ExpectedMessage "*'ScriptPath' is not on this installer's allowlist*"
    }

    It 'refuses ModuleName <Value>' -ForEach @(
      @{ Value = '..\..\evil'; Why = 'path traversal' }
      @{ Value = 'A\B'; Why = 'backslash separator' }
      @{ Value = 'A/B'; Why = 'forward separator' }
      @{ Value = 'A;whoami'; Why = 'command separator' }
      @{ Value = 'A$(whoami)'; Why = 'subexpression' }
      @{ Value = 'A B'; Why = 'argument split' }
      @{ Value = 'A"B'; Why = 'quote injection' }
      @{ Value = ''; Why = 'empty' }
    ) {
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = $Value; RequiredVersion = '1.0.0'; Repository = 'powershellget-stable' }) } |
        Should -Throw -ExpectedMessage '*does not match its required pattern*'
    }

    It 'refuses RequiredVersion <Value>' -ForEach @(
      @{ Value = '..' }
      @{ Value = '1.0' }
      @{ Value = 'latest' }
      @{ Value = '*' }
      @{ Value = '1.0.0; rm -rf' }
    ) {
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = $Value; Repository = 'powershellget-stable' }) } |
        Should -Throw -ExpectedMessage '*does not match its required pattern*'
    }

    It 'refuses a Repository outside the known ATAP tier feeds' {
      # An open Repository would let a request pull the package from a feed the attacker
      # controls, defeating the package-hash pin further down.
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = '1.0.0'; Repository = 'evil-feed' }) } |
        Should -Throw -ExpectedMessage '*does not match its required pattern*'
    }

    It 'refuses a FeedUrl pointing off the known ATAP hosts' {
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = '1.0.0'; Repository = 'powershellget-stable'
            FeedUrl = 'http://evil.example.com/nuget/x' }) } |
        Should -Throw -ExpectedMessage '*does not match its required pattern*'
    }

    It 'refuses a malformed ExpectedSha256' {
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A'; RequiredVersion = '1.0.0'; Repository = 'powershellget-stable'
            ExpectedSha256 = 'nothex' }) } |
        Should -Throw -ExpectedMessage '*does not match its required pattern*'
    }

    It 'refuses a request that omits a required parameter' {
      { Test-BrokerRequestParameters -AllowedParameters $script:Allowed -RequestParameters ([pscustomobject]@{
            ModuleName = 'A' }) } |
        Should -Throw -ExpectedMessage "*Required parameter 'RequiredVersion' was not supplied*"
    }
  }
}

Describe 'Test-BrokerRequestFolderAcl' {
  It 'reports no offenders for a folder with default inherited permissions' {
    $d = Join-Path $TestDrive 'acl-clean'
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    # TestDrive lives under the user profile, so the default ACL grants the owner, not
    # Everyone/Users. This asserts the guard does not fire on an ordinary folder.
    @(Test-BrokerRequestFolderAcl -Path $d) | Should -Not -Contain 'Everyone'
  }

  It 'detects an Everyone-writable requests folder' {
    # This is the condition under which any local account could reach an administrator
    # context through the broker, so it must be caught before the broker starts.
    $d = Join-Path $TestDrive 'acl-open'
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $acl = Get-Acl -LiteralPath $d
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
        'Everyone', 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    Set-Acl -LiteralPath $d -AclObject $acl

    @(Test-BrokerRequestFolderAcl -Path $d) | Should -Contain 'Everyone'
  }

  It 'detects a BUILTIN\Users-writable requests folder' {
    $d = Join-Path $TestDrive 'acl-users'
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $acl = Get-Acl -LiteralPath $d
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
        'BUILTIN\Users', 'Write', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    Set-Acl -LiteralPath $d -AclObject $acl

    @(Test-BrokerRequestFolderAcl -Path $d) | Should -Contain 'BUILTIN\Users'
  }

  It 'ignores a Deny rule for a forbidden identity' {
    # A Deny entry restricts rather than grants, so treating it as an offender would
    # block a correctly hardened folder.
    $d = Join-Path $TestDrive 'acl-deny'
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    $denyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
      'Everyone', 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Deny')
    $acl = Get-Acl -LiteralPath $d
    $acl.AddAccessRule($denyRule)
    Set-Acl -LiteralPath $d -AclObject $acl

    try {
      @(Test-BrokerRequestFolderAcl -Path $d) | Should -Not -Contain 'Everyone'
    }
    finally {
      # A Deny-Everyone rule also denies Pester's TestDrive cleanup, which fails the
      # whole container after the assertions pass. Remove it before leaving the test.
      $acl = Get-Acl -LiteralPath $d
      $acl.RemoveAccessRuleAll($denyRule)
      Set-Acl -LiteralPath $d -AclObject $acl
    }
  }
}
