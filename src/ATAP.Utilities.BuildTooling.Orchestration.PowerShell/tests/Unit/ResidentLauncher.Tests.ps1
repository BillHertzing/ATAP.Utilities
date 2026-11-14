#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

# Slice 7 (0.1.17): stable resident launcher. TestDrive only: fixture module versions are
# built under TestDrive with real inventory pins, the slice 6 readers come from copies of the
# real host, and Assert-CoordPackageInventory is the real private function. Authenticode and
# the final host call are mocked; nothing is installed, registered or written to Program Files.

BeforeAll {
  $script:moduleSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $script:launcherPath = Join-Path $script:moduleSource 'Resources\Resident\Start-CoordClerkResident.ps1'
  $script:hostSource = Join-Path $script:moduleSource 'Resources\Resident\Invoke-CoordClerkResident.ps1'
  $script:name = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
  $script:signer = 'A' * 40
  . $script:hostSource
  . $script:launcherPath

  function Write-FixtureJson([string]$Path, $Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20)) }

  function Get-FixturePins([string]$VersionRoot) {
    @(Get-ChildItem -LiteralPath $VersionRoot -File -Recurse | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1', '.json') } | Sort-Object FullName | ForEach-Object {
      [ordered]@{ path = [IO.Path]::GetRelativePath($VersionRoot, $_.FullName).Replace('\', '/'); digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($_.FullName))).ToLowerInvariant() } })
  }

  function New-FixtureVersion([string]$ModulesRoot, [string]$Version) {
    $root = Join-Path $ModulesRoot (Join-Path $script:name $Version)
    $null = New-Item -ItemType Directory -Path (Join-Path $root 'Resources\Resident'), (Join-Path $root 'schemas') -Force
    [IO.File]::WriteAllText((Join-Path $root ($script:name + '.psd1')), "@{ ModuleVersion = '$Version'; RootModule = '$($script:name).psm1'; FunctionsToExport = @() }")
    $private = Join-Path $script:moduleSource 'private'
    [IO.File]::WriteAllText((Join-Path $root ($script:name + '.psm1')), ". '$(Join-Path $private 'CoordProducer.ps1')'`n. '$(Join-Path $private 'CoordProducerJson.ps1')'`n")
    Copy-Item -LiteralPath $script:hostSource -Destination (Join-Path $root 'Resources\Resident\Invoke-CoordClerkResident.ps1')
    # The bundled launcher; the running (source) launcher must byte-equal the admitted copy.
    Copy-Item -LiteralPath $script:launcherPath -Destination (Join-Path $root 'Resources\Resident\Start-CoordClerkResident.ps1')
    Copy-Item -LiteralPath (Join-Path $script:moduleSource 'Resources\Resident\ResidentStartup.schema.json') -Destination (Join-Path $root 'Resources\Resident\ResidentStartup.schema.json')
    Copy-Item -LiteralPath (Join-Path $script:moduleSource 'schemas\activation-record-v1.schema.json') -Destination (Join-Path $root 'schemas\activation-record-v1.schema.json')
    $root
  }

  function Set-CustodyPackage($F, [string]$Version, $Files = $null) {
    $b = $F.Binding
    $pins = if ($null -ne $Files) { $Files } elseif ($F.Versions.Contains($Version)) { Get-FixturePins $F.Versions[$Version] } else { @() }
    Write-FixtureJson $b.custodyPath ([ordered]@{ admissionMode = 'Established'; custodianSid = $b.windowsSid; resourceId = $b.resourceId; lineageId = $b.lineageId; generation = 'epoch-a'
      package = [ordered]@{ moduleVersion = $Version; files = @($pins) }; boardLockPath = Join-Path $F.Root 'board.lock'
      actors = @([ordered]@{ holderId = $b.holderId; sessionId = $b.sessionId; windowsSid = $b.windowsSid; role = 'Coordinator' }) })
  }

  function Write-FixtureActivation($F, [int]$StartMinutes = -1, [int]$EndMinutes = 5) {
    Write-FixtureJson $F.Binding.activationPath ([ordered]@{ schemaVersion = 'Coordination-activation-v1'; descriptorSha256 = $F.Digest; approvalReference = 'synthetic-approval'
      notBeforeUtc = [DateTimeOffset]::UtcNow.AddMinutes($StartMinutes).ToString('r'); notAfterUtc = [DateTimeOffset]::UtcNow.AddMinutes($EndMinutes).ToString('r'); maximumDrains = 0 })
  }

  function New-LauncherFixture {
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $modules = Join-Path $root 'Modules'
    foreach ($dir in @('State', 'Custody', 'Control', 'Activation', 'Modules')) { $null = New-Item -ItemType Directory -Path (Join-Path $root $dir) -Force }
    $versions = [ordered]@{ '0.1.17' = New-FixtureVersion $modules '0.1.17'; '0.1.18' = New-FixtureVersion $modules '0.1.18' }
    $identity = Get-CoordResidentIdentity
    $binding = [ordered]@{
      schemaVersion = 'CoordResidentStartup-v2'; mode = 'Active'; hostName = $identity.HostName; windowsSid = $identity.WindowsSid
      holderId = 'FixtureCoordinator'; sessionId = 'fixture-session'; resourceId = 'fixture-resource'; lineageId = 'fixture-lineage'
      statePath = Join-Path $root 'State\state.json'; custodyPath = Join-Path $root 'Custody\custody.json'
      leasePath = Join-Path $root 'Control\resident.lock'; stopPath = Join-Path $root 'Control\stop'; activationPath = Join-Path $root 'Activation\activation.json'
    }
    [IO.File]::WriteAllBytes($binding.leasePath, [byte[]]@())
    $path = Join-Path $root 'binding.json'
    Write-FixtureJson $path $binding
    $f = @{ Root = $root; Modules = $modules; Versions = $versions; Binding = $binding; Path = $path; Digest = (Get-FileHash -LiteralPath $path).Hash }
    Write-FixtureJson $binding.statePath ([ordered]@{ resourceId = $binding.resourceId; lineageId = $binding.lineageId; generation = 'epoch-a'; mutationAdmission = @{ status = 'Admitted' } })
    Set-CustodyPackage $f '0.1.17'
    Write-FixtureActivation $f
    $global:configRootKeys = @{ OrchestrationStateRootPathConfigRootKey = 'fixture-state'; OrchestrationCustodyRecordPathConfigRootKey = 'fixture-custody' }
    $global:settings = @{ 'fixture-state' = Split-Path $binding.statePath -Parent; 'fixture-custody' = $binding.custodyPath }
    $f
  }

  function Get-LaunchArguments($F) {
    # The task action's arguments: identical for every release by construction.
    @{ BindingPath = $F.Path; ExpectedBindingSha256 = $F.Digest; CustodyPath = $F.Binding.custodyPath; SignerThumbprint = $script:signer; ModulesRoot = $F.Modules }
  }

  function Get-TreeImage([string]$Root) {
    @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName | ForEach-Object { $_.FullName + '=' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
  }
}

Describe 'Stable resident launcher' -Tag 'Unit' {
  BeforeEach {
    $priorKeys = Get-Variable configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorSettings = Get-Variable settings -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    $priorModulePath = $env:PSModulePath
    # Each task start is a fresh process: unload any copy an earlier test file imported.
    Get-Module -Name $script:name -All | Remove-Module -Force -ErrorAction SilentlyContinue
    $f = New-LauncherFixture
    $env:PSModulePath = $f.Modules
    Mock Get-AuthenticodeSignature { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } }
    Mock Invoke-CoordLauncherTarget { [pscustomobject]@{ Status = 'HostFixture'; HostPath = $TargetHostPath; BindingPath = $TargetBindingPath; Digest = $TargetDigest; Signer = $TargetSignerThumbprint } }
    Mock Write-PSFMessage {}
  }
  AfterEach {
    Get-Module -Name $script:name -All | Remove-Module -Force -ErrorAction SilentlyContinue
    $env:PSModulePath = $priorModulePath
    $global:configRootKeys = $priorKeys; $global:settings = $priorSettings
  }

  It 'resolves the custody-admitted version, not the highest installed one' {
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Status | Should -BeExactly 'Launched'
    $r.PackageVersion | Should -BeExactly '0.1.17'
    $r.HostPath | Should -BeExactly (Join-Path $f.Versions['0.1.17'] 'Resources\Resident\Invoke-CoordClerkResident.ps1')
    $r.HostResult.BindingPath | Should -BeExactly $f.Path
    $r.HostResult.Digest | Should -BeExactly $f.Digest
    # The pin travels to the host (M3).
    $r.SignerThumbprint | Should -BeExactly $script:signer
    $r.HostResult.Signer | Should -BeExactly $script:signer
    Should -Invoke Invoke-CoordLauncherTarget -Times 1 -Exactly
    Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter { $Level -ceq 'Important' }
  }

  Context 'Unadmitted code never runs (H2)' {
    BeforeEach {
      $canary = Join-Path $f.Root 'canary'
      $null = New-Item -ItemType Directory -Path $canary -Force
      $line = { param($tag) "[IO.File]::WriteAllText('" + (Join-Path $canary $tag) + "', 'ran')`n" }
      # The higher, signed, installed but unadmitted version: its host and root module both leave
      # a file the moment any of their code runs. Its host also tries to neutralise the launcher.
      $v18 = $f.Versions['0.1.18']
      $hostFile = Join-Path $v18 'Resources\Resident\Invoke-CoordClerkResident.ps1'
      [IO.File]::WriteAllText($hostFile, (& $line 'host-0.1.18') + "function Test-CoordLauncherSigner { `$true }`nfunction Test-CoordLauncherSelfAdmitted { `$true }`n" + [IO.File]::ReadAllText($hostFile))
      $psm1 = Join-Path $v18 ($script:name + '.psm1')
      [IO.File]::WriteAllText($psm1, (& $line 'psm1-0.1.18') + [IO.File]::ReadAllText($psm1))
    }

    It 'launches the admitted 0.1.17 with no code from the higher signed 0.1.18 executed' {
      $a = Get-LaunchArguments $f
      $r = Start-CoordClerkResident @a
      $r.Status | Should -BeExactly 'Launched'
      $r.PackageVersion | Should -BeExactly '0.1.17'
      @(Get-ChildItem -LiteralPath $canary).Count | Should -Be 0
      @(Get-Module -Name $script:name -All | Where-Object { $_.Version -eq [version]'0.1.18' }).Count | Should -Be 0
    }

    It 'a refusal (signer mismatch on the admitted version) still runs no unadmitted code' {
      Mock Get-AuthenticodeSignature { if ($LiteralPath -like '*0.1.17*') { @{ Status = 'NotSigned'; SignerCertificate = $null } } else { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } } }
      $a = Get-LaunchArguments $f
      (Start-CoordClerkResident @a).Reason | Should -BeExactly 'LauncherSignerRejected'
      @(Get-ChildItem -LiteralPath $canary).Count | Should -Be 0
    }

    It 'custody admitting 0.1.18 whose host changed after admission refuses before loading it' {
      # Re-pin as admitted, then tamper: the digest no longer matches custody's inventory.
      $hostFile = Join-Path $f.Versions['0.1.18'] 'Resources\Resident\Invoke-CoordClerkResident.ps1'
      $original = [IO.File]::ReadAllText($hostFile)
      [IO.File]::WriteAllText($hostFile, $original.Replace((Join-Path $canary 'host-0.1.18'), (Join-Path $canary 'never')))
      Set-CustodyPackage $f '0.1.18'
      [IO.File]::WriteAllText($hostFile, $original)
      $a = Get-LaunchArguments $f
      $r = Start-CoordClerkResident @a
      $r.Reason | Should -BeExactly 'LauncherInventoryRejected'
      $r.InnerReason | Should -BeExactly 'InventoryDigestMismatch:Resources/Resident/Invoke-CoordClerkResident.ps1'
      @(Get-ChildItem -LiteralPath $canary).Count | Should -Be 0
    }

    It 'an unpinned loadable file in the admitted version is refused before import' {
      [IO.File]::WriteAllText((Join-Path $f.Versions['0.1.17'] 'Extra.ps1xml'), '<Types />')
      $a = Get-LaunchArguments $f
      $r = Start-CoordClerkResident @a
      $r.Reason | Should -BeExactly 'LauncherInventoryRejected'
      $r.InnerReason | Should -BeExactly 'InventoryUnpinnedFile:Extra.ps1xml'
      @(Get-Module -Name $script:name -All).Count | Should -Be 0
    }

    It 'an unpinned non-loadable file is tolerated under the v1 rule but refused under v2' {
      [IO.File]::WriteAllText((Join-Path $f.Versions['0.1.17'] 'README.md'), 'notes')
      $a = Get-LaunchArguments $f
      (Start-CoordClerkResident @a).Status | Should -BeExactly 'Launched'
      Get-Module -Name $script:name -All | Remove-Module -Force
      $w = Get-Content -LiteralPath $f.Binding.custodyPath -Raw | ConvertFrom-Json -AsHashtable
      $w.package['inventoryRule'] = 'v2'
      Write-FixtureJson $f.Binding.custodyPath $w
      (Start-CoordClerkResident @a).InnerReason | Should -BeExactly 'InventoryUnpinnedFile:README.md'
    }

    It 'refuses a custody inventory that omits the host, manifest or root module' {
      $pins = @(Get-FixturePins $f.Versions['0.1.17'] | Where-Object { $_.path -cne 'Resources/Resident/Invoke-CoordClerkResident.ps1' })
      Set-CustodyPackage $f '0.1.17' $pins
      $a = Get-LaunchArguments $f
      $r = Start-CoordClerkResident @a
      $r.Reason | Should -BeExactly 'LauncherInventoryRejected'
      $r.InnerReason | Should -BeExactly 'InventoryMissingPin:Resources/Resident/Invoke-CoordClerkResident.ps1'
    }

    It 'the resolver itself never dot-sources or imports anything (static)' {
      $tokens = $null; $errors = $null
      $ast = [Management.Automation.Language.Parser]::ParseFile($script:launcherPath, [ref]$tokens, [ref]$errors)
      foreach ($fnName in @('Resolve-CoordLauncherPackage', 'Read-CoordLauncherDescriptor', 'Read-CoordLauncherCustody', 'Assert-CoordLauncherInventory')) {
        $fnAst = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $fnName }, $true)
        $calls = @($fnAst.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true))
        @($calls | Where-Object { $_.InvocationOperator -eq 'Dot' }).Count | Should -Be 0 -Because $fnName
        @($calls | Where-Object { $_.GetCommandName() -in @('Import-Module', 'Test-Json') }).Count | Should -Be 0 -Because $fnName
      }
      $check = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Invoke-CoordLauncherAdmittedCheck' }, $true)
      @($check.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq 'Dot' }, $true)).Count | Should -Be 1
    }
  }

  Context 'Custody policy signer (M3)' {
    BeforeEach {
      function Set-Policy([string]$Signer) {
        $w = Get-Content -LiteralPath $f.Binding.custodyPath -Raw | ConvertFrom-Json -AsHashtable
        $w['autoPackageAdmission'] = [ordered]@{ enabled = $true; signer = $Signer; minVersion = '0.1.17'; schemaHashes = @{}; semanticRevision = 'r1' }
        Write-FixtureJson $f.Binding.custodyPath $w
      }
    }

    It 'launches when the task pin equals custody''s policy signer' {
      Set-Policy ('a' * 40)
      $a = Get-LaunchArguments $f
      (Start-CoordClerkResident @a).Status | Should -BeExactly 'Launched'
    }

    It 'refuses when the task pin differs from custody''s policy signer' {
      Set-Policy ('B' * 40)
      $a = Get-LaunchArguments $f
      (Start-CoordClerkResident @a).Reason | Should -BeExactly 'LauncherSignerPolicyMismatch'
      Should -Invoke Invoke-CoordLauncherTarget -Times 0
    }

    It 'refuses a malformed custody policy signer' {
      Set-Policy (('A' * 40) + "`n")
      $a = Get-LaunchArguments $f
      $r = Start-CoordClerkResident @a
      $r.Reason | Should -BeExactly 'LauncherCustodyUnreadable'
      $r.InnerReason | Should -BeExactly 'CustodyPolicyInvalid'
    }
  }

  It 'logs a refusal through PSFramework (L3)' {
    Set-CustodyPackage $f '0.1.19' @()
    $a = Get-LaunchArguments $f
    (Start-CoordClerkResident @a).Status | Should -BeExactly 'Refused'
    Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter { $Level -ceq 'Error' -and $Message -like '*LauncherPackageNotInstalled*' }
  }

  It 'still refuses cleanly when logging itself fails' {
    Mock Write-PSFMessage { throw 'log sink down' }
    Set-CustodyPackage $f '0.1.19' @()
    $a = Get-LaunchArguments $f
    (Start-CoordClerkResident @a).Reason | Should -BeExactly 'LauncherPackageNotInstalled'
  }

  It 'after a custody package change picks up the new version with the same task action' {
    $a = Get-LaunchArguments $f
    $before = ($a.GetEnumerator() | Sort-Object Key | ForEach-Object { $_.Key + '=' + $_.Value }) -join ';'
    (Start-CoordClerkResident @a).PackageVersion | Should -BeExactly '0.1.17'
    # Each task start is a fresh process; unload the previous version as a new process would.
    Get-Module -Name $script:name -All | Remove-Module -Force
    Set-CustodyPackage $f '0.1.18'
    $after = ($a.GetEnumerator() | Sort-Object Key | ForEach-Object { $_.Key + '=' + $_.Value }) -join ';'
    $r = Start-CoordClerkResident @a
    $r.Status | Should -BeExactly 'Launched'
    $r.PackageVersion | Should -BeExactly '0.1.18'
    $r.HostPath | Should -BeExactly (Join-Path $f.Versions['0.1.18'] 'Resources\Resident\Invoke-CoordClerkResident.ps1')
    $after | Should -BeExactly $before
    (Get-FileHash -LiteralPath $f.Path).Hash | Should -BeExactly $f.Digest
  }

  It 'refuses an installed version whose inventory custody does not admit' {
    [IO.File]::AppendAllText((Join-Path $f.Versions['0.1.17'] 'schemas\activation-record-v1.schema.json'), ' ')
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Status | Should -BeExactly 'Refused'
    $r.Reason | Should -BeExactly 'LauncherInventoryRejected'
    # Caught by the launcher's own pre-import hash check, before the module's.
    $r.InnerReason | Should -BeExactly 'InventoryDigestMismatch:schemas/activation-record-v1.schema.json'
    @(Get-Module -Name $script:name -All).Count | Should -Be 0
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'refuses a custody-admitted version that is not installed' {
    Set-CustodyPackage $f '0.1.19' @()
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherPackageNotInstalled'
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'refuses a signer mismatch on the admitted version before importing it' {
    Mock Get-AuthenticodeSignature { if ($LiteralPath -like '*0.1.17*.psm1') { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'B' * 40 } } } else { @{ Status = 'Valid'; SignerCertificate = @{ Thumbprint = 'A' * 40 } } } }
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherSignerRejected'
    @(Get-Module -Name $script:name -All).Count | Should -Be 0
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'reads custody without any signed installed host: an unsigned install refuses on its own signer' {
    Mock Get-AuthenticodeSignature { @{ Status = 'NotSigned'; SignerCertificate = $null } }
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherSignerRejected'
    $r.InnerReason | Should -BeExactly 'Invoke-CoordClerkResident.ps1'
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'refuses more than one install candidate for the admitted version' {
    $other = Join-Path $f.Root 'OtherModules'
    $null = New-FixtureVersion $other '0.1.17'
    $env:PSModulePath = $f.Modules + [IO.Path]::PathSeparator + $other
    $a = Get-LaunchArguments $f
    (Start-CoordClerkResident @a).Reason | Should -BeExactly 'LauncherAmbiguousPackage'
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'admits itself when its bytes equal the admitted package''s bundled launcher' {
    $pins = @(Get-FixturePins $f.Versions['0.1.17'] | Where-Object { $_.path -ceq 'Resources/Resident/Start-CoordClerkResident.ps1' })
    $pins.Count | Should -Be 1
    $pins[0].digest | Should -BeExactly ((Get-FileHash -LiteralPath $script:launcherPath).Hash.ToLowerInvariant())
    Test-CoordLauncherSelfAdmitted -Package @{ moduleVersion = '0.1.17'; files = $pins } | Should -BeTrue
    $a = Get-LaunchArguments $f
    (Start-CoordClerkResident @a).Status | Should -BeExactly 'Launched'
  }

  It 'refuses with LauncherSelfNotAdmitted when the admitted package bundles a different launcher' {
    [IO.File]::AppendAllText((Join-Path $f.Versions['0.1.18'] 'Resources\Resident\Start-CoordClerkResident.ps1'), "`n# changed in 0.1.18`n")
    Set-CustodyPackage $f '0.1.18'
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Status | Should -BeExactly 'Refused'
    $r.Reason | Should -BeExactly 'LauncherSelfNotAdmitted'
    $r.InnerReason | Should -BeExactly '0.1.18'
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'refuses with LauncherSelfNotAdmitted when custody''s inventory has no launcher entry' {
    @(Get-FixturePins $f.Versions['0.1.17'] | Where-Object { $_.path -cne 'Resources/Resident/Start-CoordClerkResident.ps1' }).Count | Should -BeGreaterThan 0
    Test-CoordLauncherSelfAdmitted -Package @{ moduleVersion = '0.1.17'; files = @(Get-FixturePins $f.Versions['0.1.17'] | Where-Object { $_.path -cne 'Resources/Resident/Start-CoordClerkResident.ps1' }) } | Should -BeFalse
  }

  It 'refuses when another copy of the module is already loaded in the process' {
    $null = Import-Module -Name (Join-Path $f.Versions['0.1.18'] ($script:name + '.psd1')) -PassThru
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherImportMismatch'
    $r.InnerReason | Should -BeExactly 'ConflictingLoadedModule'
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'refuses when custody cannot be read' {
    Remove-Item -LiteralPath $f.Binding.custodyPath
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherCustodyUnreadable'
    Should -Invoke Invoke-CoordLauncherTarget -Times 0
  }

  It 'refuses an expired activation with its own code' {
    Write-FixtureActivation $f -StartMinutes -10 -EndMinutes -5
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherActivationRefused'
    $r.InnerReason | Should -BeExactly 'ResidentActivationExpiredOrNotStarted'
  }

  It 'refuses a custody path parameter that differs from the descriptor' {
    $a = Get-LaunchArguments $f
    $a.CustodyPath = Join-Path $f.Root 'Custody\other.json'
    (Start-CoordClerkResident @a).Reason | Should -BeExactly 'LauncherCustodyPathMismatch'
  }

  It 'refuses a changed descriptor through the slice 6 reader' {
    [IO.File]::AppendAllText($f.Path, ' ')
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherDescriptorRejected'
    $r.InnerReason | Should -BeExactly 'DescriptorBindingChanged'
  }

  It 'refuses a v1 descriptor with its own code' {
    $identity = Get-CoordResidentIdentity
    Write-FixtureJson $f.Path ([ordered]@{ schemaVersion = 'CoordResidentStartup-v1'; mode = 'Active'; hostName = $identity.HostName; windowsSid = $identity.WindowsSid; custodyPath = $f.Binding.custodyPath })
    $a = Get-LaunchArguments $f
    $a.ExpectedBindingSha256 = (Get-FileHash -LiteralPath $f.Path).Hash
    (Start-CoordClerkResident @a).Reason | Should -BeExactly 'LauncherDescriptorV2Required'
  }

  It 'refuses a descriptor digest with a trailing newline' {
    $a = Get-LaunchArguments $f
    $a.ExpectedBindingSha256 = $f.Digest + "`n"
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherDescriptorRejected'
    $r.InnerReason | Should -BeExactly 'DescriptorPinRequired'
  }

  It 'refuses an activation window longer than 12 hours through the admitted host (L5)' {
    Write-FixtureActivation $f -StartMinutes -1 -EndMinutes 800
    $a = Get-LaunchArguments $f
    $r = Start-CoordClerkResident @a
    $r.Reason | Should -BeExactly 'LauncherActivationRefused'
    $r.InnerReason | Should -BeExactly 'ResidentActivationWindowTooLong'
  }

  It 'writes nothing when it refuses' {
    [IO.File]::AppendAllText((Join-Path $f.Versions['0.1.17'] 'schemas\activation-record-v1.schema.json'), ' ')
    $image = Get-TreeImage $f.Root
    $a = Get-LaunchArguments $f
    (Start-CoordClerkResident @a).Status | Should -BeExactly 'Refused'
    Get-TreeImage $f.Root | Should -BeExactly $image
  }
}

Describe 'Launcher upgrade compatibility (M1)' -Tag 'Unit' {
  BeforeAll {
    $script:installed = Join-Path $TestDrive 'Installed\Start-CoordClerkResident.ps1'
    $null = New-Item -ItemType Directory -Path (Split-Path $script:installed) -Force
    Copy-Item -LiteralPath $script:launcherPath -Destination $script:installed
    $script:same = (Get-FileHash -LiteralPath $script:launcherPath).Hash
    $script:other = 'f' * 64
  }

  It '<Name>' -ForEach @(
    @{ Name = 'unchanged launcher (attestation shape) is compatible'; Files = { @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:same.ToLowerInvariant(); size = 1 }) }; Planned = $false; Status = 'Compatible'; Reason = 'LauncherUnchanged' }
    @{ Name = 'unchanged launcher (custody shape) is compatible'; Files = { @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; digest = $script:same }) }; Planned = $false; Status = 'Compatible'; Reason = 'LauncherUnchanged' }
    @{ Name = 'changed launcher without a re-install is refused'; Files = { @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:other }) }; Planned = $false; Status = 'Refused'; Reason = 'LauncherChangeRequiresReinstall' }
    @{ Name = 'changed launcher with a planned re-install is compatible'; Files = { @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:other }) }; Planned = $true; Status = 'Compatible'; Reason = 'LauncherReinstallPlanned' }
    @{ Name = 'a candidate without a launcher pin is refused'; Files = { @(@{ path = 'other.ps1'; sha256 = $script:other }) }; Planned = $true; Status = 'Refused'; Reason = 'CandidateLauncherPinMissing' }
    @{ Name = 'a duplicated launcher pin is refused'; Files = { @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:same }, @{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:same }) }; Planned = $false; Status = 'Refused'; Reason = 'CandidateLauncherPinMissing' }
    @{ Name = 'a pin with a trailing newline is refused'; Files = { @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:same + "`n" }) }; Planned = $false; Status = 'Refused'; Reason = 'CandidateLauncherPinMissing' }
  ) {
    $r = Test-CoordLauncherUpgradeCompatibility -CandidateFiles (& $Files) -InstalledLauncherPath $script:installed -LauncherReinstallPlanned:$Planned
    $r.Status | Should -BeExactly $Status
    $r.Reason | Should -BeExactly $Reason
  }

  It 'reports both digests and refuses when no launcher is installed and no re-install is planned' {
    $files = @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:same })
    $missing = Join-Path $TestDrive 'absent\Start-CoordClerkResident.ps1'
    (Test-CoordLauncherUpgradeCompatibility -CandidateFiles $files -InstalledLauncherPath $missing).Reason | Should -BeExactly 'InstalledLauncherMissing'
    (Test-CoordLauncherUpgradeCompatibility -CandidateFiles $files -InstalledLauncherPath $missing -LauncherReinstallPlanned).Status | Should -BeExactly 'Compatible'
    $r = Test-CoordLauncherUpgradeCompatibility -CandidateFiles @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:other }) -InstalledLauncherPath $script:installed
    $r.CandidateSha256 | Should -BeExactly $script:other.ToUpperInvariant()
    $r.InstalledSha256 | Should -BeExactly $script:same
  }

  It 'writes nothing' {
    $before = (Get-Item -LiteralPath $script:installed).LastWriteTimeUtc
    $null = Test-CoordLauncherUpgradeCompatibility -CandidateFiles @(@{ path = 'Resources/Resident/Start-CoordClerkResident.ps1'; sha256 = $script:other }) -InstalledLauncherPath $script:installed -LauncherReinstallPlanned
    (Get-Item -LiteralPath $script:installed).LastWriteTimeUtc | Should -Be $before
    (Get-FileHash -LiteralPath $script:installed).Hash | Should -BeExactly $script:same
  }
}

Describe 'Stable resident launcher shape' -Tag 'Unit' {
  BeforeAll {
    $tokens = $null; $errors = $null
    $script:ast = [Management.Automation.Language.Parser]::ParseFile($script:launcherPath, [ref]$tokens, [ref]$errors)
    $script:parseErrors = $errors
  }

  It 'parses cleanly' { @($script:parseErrors).Count | Should -Be 0 }

  It 'has no top-level code beyond functions and the documented dual-purpose guard' {
    $statements = @($script:ast.EndBlock.Statements)
    $other = @($statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] })
    $other.Count | Should -Be 1
    $other[0].Extent.Text | Should -BeLike "if (`$MyInvocation.InvocationName -ne '.' -and `$MyInvocation.InvocationName -ne '&')*"
    $script:ast.BeginBlock | Should -BeNullOrEmpty
    $script:ast.ProcessBlock | Should -BeNullOrEmpty
  }

  It 'dot-sources the admitted host and never invokes it with &' {
    $target = $script:ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Invoke-CoordLauncherTarget' }, $true)
    $calls = @($target.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true))
    @($calls | Where-Object { $_.InvocationOperator -eq 'Dot' }).Count | Should -Be 1
    @($calls | Where-Object { $_.InvocationOperator -eq 'Ampersand' }).Count | Should -Be 0
    @($calls | Where-Object { $_.GetCommandName() -ceq 'Invoke-CoordClerkResident' }).Count | Should -Be 1
  }

  It 'under pwsh -File refuses with a distinct code, JSON and exit code 3' {
    $output = & pwsh -NoLogo -File $script:launcherPath -BindingPath (Join-Path $TestDrive 'none.json') -ExpectedBindingSha256 ('A' * 64) -CustodyPath (Join-Path $TestDrive 'custody.json') -SignerThumbprint 'not-a-thumbprint' 2>&1
    $LASTEXITCODE | Should -Be 3
    ((@($output) | Where-Object { $_ -is [string] -and $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json).Reason | Should -BeExactly 'LauncherSignerPinRequired'
  }
}
