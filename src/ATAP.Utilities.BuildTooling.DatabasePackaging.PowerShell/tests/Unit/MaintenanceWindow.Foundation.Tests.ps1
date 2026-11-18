#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# DB-Runner-S1-Foundation unit tests. No SQL, no network: every database call is mocked or replaced by
# an in-memory DataTableReader. Run only in a child pwsh (-NonInteractive).

BeforeAll {
  $script:moduleRoot = (Join-Path $PSScriptRoot '..\..' | Resolve-Path).Path
  $script:moduleName = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
  Remove-Module $script:moduleName -Force -ErrorAction SilentlyContinue
  $script:module = Import-Module -Name (Join-Path $script:moduleRoot "$script:moduleName.psd1") -Force -PassThru -ErrorAction Stop

  $script:svcSid = 'S-1-5-21-670621561-2583097644-1836932750-1007'
  $script:dll = 'C:\Program Files\PowerShell\Modules\dbatools.library\2025.12.28\core\lib\Microsoft.Data.SqlClient.dll'
  $script:dllSha = 'FAFFA55E5DB0BF0503F31B54F65F5FB203412B77D1C38CE8AD0A0A45485DE90B'

  function New-TestBinding {
    param([string]$Tier = 'Development', [string]$Mode = 'PrecheckOnly', [hashtable]$Override = @{}, [string[]]$Remove = @())
    $instance = @{ Development = 'UTAT022\Devwhertzing'; Integration = 'UTAT022\Integration'; QA = 'UTAT022\QA'; Production = 'UTAT022\Production' }[$Tier]
    $now = [DateTimeOffset]::UtcNow
    $opFile = Join-Path $TestDrive ('op-' + [guid]::NewGuid().ToString('N') + '.sql')
    [IO.File]::WriteAllText($opFile, "SELECT 1 AS One;`n")
    $b = [ordered]@{
      SchemaVersion = 'DatabaseMaintenanceBinding-v1'; Tier = $Tier; Mode = $Mode; Attempt = 'A01'; BuildId = '21596'
      HostName = 'UTAT022'; AllowedDataSources = @($instance); PackageSha256 = ('51A7D624' + ('0' * 56)); SqlInstance = $instance; Catalog = 'ATAPUtilities'
      ExpectedLogin = 'UTAT022\SvcBuildmaster'; ExpectedSid = $script:svcSid
      MasterSecretName = "dbConnectionString.master.utat022.$Tier"; DatabaseSecretName = "dbConnectionString.ATAPUtilities.utat022.$Tier"
      CloneName = "ATAPUtilities_LF021Clone_${Tier}_A01"
      CloneDataPath = "C:\LocalDBs\$Tier\Data\ATAPUtilities_LF021Clone_${Tier}_A01.mdf"
      CloneLogPath = "C:\LocalDBs\$Tier\Log\ATAPUtilities_LF021Clone_${Tier}_A01_log.ldf"
      BackupPath = "D:\ATAPArtifacts\Sprint0017\DatabasePackage021\Window${Tier}A01\Backup\ATAPUtilities_${Tier}_LF021_BeforeMaintenance_A01.bak"
      EvidenceRoot = "D:\ATAPArtifacts\Sprint0017\DatabasePackage021\Window${Tier}A01"
      ApprovalReference = 'Test-Approval'; NotBeforeUtc = $now.AddMinutes(-5).ToString('o'); ExpiresUtc = $now.AddHours(1).ToString('o')
      DatabaseManagementVersion = '0.1.26'; SqlClient = [ordered]@{ Path = $script:dll; Sha256 = $script:dllSha }
      PauseList = @('BuildMaster releases', 'DAB MCP servers')
      OperationSet = [ordered]@{ Name = 'LF021'; Description = 'Line-ending repair for package 0.1.21' }
      Operations = @([ordered]@{ Name = 'BeforeSample'; Kind = 'Read'; Path = $opFile; Sha256 = (Get-FileHash -LiteralPath $opFile).Hash; Database = 'ATAPUtilities'; Secret = 'Database'; TimeoutSeconds = 60; TransactionAllowed = $true })
    }
    if ($Tier -eq 'Production') {
      $rec = Join-Path $TestDrive ('pause-' + [guid]::NewGuid().ToString('N') + '.json')
      [IO.File]::WriteAllText($rec, '{"paused":"Ace Outpost"}')
      $b.ProductionPauseRecord = [ordered]@{ Path = $rec; Sha256 = (Get-FileHash -LiteralPath $rec).Hash }
      $b.PauseList = @('BuildMaster releases', 'Ace Outpost writer')
    }
    # Override and remove by existing key, matched case-insensitively ([ordered] keys are case-sensitive).
    $resolveKey = { param($k) $hit = @($b.Keys | Where-Object { $_ -ieq $k }); if ($hit.Count) { $hit[0] } else { $k } }
    foreach ($k in $Override.Keys) { $b[(& $resolveKey $k)] = $Override[$k] }
    foreach ($k in $Remove) { $b.Remove((& $resolveKey $k)) }
    $path = Join-Path $TestDrive ('binding-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($path, ($b | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ Path = $path; Sha256 = (Get-FileHash -LiteralPath $path).Hash; Value = $b }
  }
}

AfterAll { Remove-Module $script:moduleName -Force -ErrorAction SilentlyContinue }

Describe 'Fixed tier map' -Tag 'Unit', 'MaintenanceWindow' {
  It 'covers exactly Development, Integration, QA and Production, never Experimental' {
    InModuleScope $script:moduleName { @((Get-MaintenanceWindowTierMap).Keys) } | Should -Be @('Development', 'Integration', 'QA', 'Production')
  }
  It 'uses the gate instance names and SecretNames' {
    $map = InModuleScope $script:moduleName { Get-MaintenanceWindowTierMap }
    $map.Development.SqlInstance | Should -BeExactly 'UTAT022\Devwhertzing'
    $map.Integration.SqlInstance | Should -BeExactly 'UTAT022\Integration'
    $map.QA.SqlInstance | Should -BeExactly 'UTAT022\QA'
    $map.Production.SqlInstance | Should -BeExactly 'UTAT022\Production'
    $map.Production.ConnectionSecretName | Should -BeExactly 'dbConnectionString.ATAPUtilities.localhost.Production'
    $map.Production.RequiresProductionPauseRecord | Should -BeTrue
    $map.QA.AllowedModes | Should -Not -Contain 'Full'
  }
  It 'pins the runner SID that the grant packet pins as hex' {
    $hex = '01050000000000051500000079DFF8272CF1F6998E5E7D6DEF030000'
    $bytes = [Convert]::FromHexString($hex)
    $sid = [Security.Principal.SecurityIdentifier]::new($bytes, 0).Value
    (InModuleScope $script:moduleName { (Get-MaintenanceWindowTierMap -Tier Development).RunnerSid }) | Should -BeExactly $sid
  }
  It 'pins the same SqlClient assembly as the Experimental packets' {
    $t = InModuleScope $script:moduleName { Get-MaintenanceWindowTierMap -Tier Integration }
    $t.SqlClientPath | Should -BeExactly $script:dll
    $t.SqlClientSha256 | Should -BeExactly $script:dllSha
  }
}

Describe 'Resource pins' -Tag 'Unit', 'MaintenanceWindow' {
  It 'pins every file under Resources\MaintenanceWindow that is not a script, and the binding schema' {
    $pins = InModuleScope $script:moduleName { Get-MaintenanceWindowResourcePins }
    $unsignable = @(Get-ChildItem -LiteralPath (Join-Path $script:moduleRoot 'Resources\MaintenanceWindow') -File | Where-Object Extension -ne '.ps1' |
      ForEach-Object { 'Resources\MaintenanceWindow\' + $_.Name })
    foreach ($f in $unsignable) { $pins.Keys | Should -Contain $f }
    $pins.Keys | Should -Contain 'schemas\database-maintenance-binding-v1.schema.json'
  }
  It 'passes against the module as shipped' {
    $verified = InModuleScope $script:moduleName { Assert-MaintenanceWindowResources }
    $verified.Count | Should -BeGreaterThan 1
  }
  It 'refuses a changed resource' {
    $copy = Join-Path $TestDrive 'modcopy'
    $null = New-Item -ItemType Directory -Path (Join-Path $copy 'Resources\MaintenanceWindow'), (Join-Path $copy 'schemas') -Force
    Copy-Item (Join-Path $script:moduleRoot 'schemas\database-maintenance-binding-v1.schema.json') (Join-Path $copy 'schemas')
    [IO.File]::WriteAllText((Join-Path $copy 'Resources\MaintenanceWindow\WindowPrecheck.sql'), 'SELECT 1;')
    { InModuleScope $script:moduleName -Parameters @{ r = $copy } { param($r) Assert-MaintenanceWindowResources -ModuleRoot $r } } | Should -Throw 'MaintenanceWindowResourceChanged|*WindowPrecheck.sql'
  }
  It 'refuses a missing resource' {
    $empty = Join-Path $TestDrive 'empty'; $null = New-Item -ItemType Directory -Path $empty -Force
    { InModuleScope $script:moduleName -Parameters @{ r = $empty } { param($r) Assert-MaintenanceWindowResources -ModuleRoot $r } } | Should -Throw 'MaintenanceWindowResourceMissing|*'
  }
  It 'keeps the precheck SQL read-only, ASCII and LF-only' {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $script:moduleRoot 'Resources\MaintenanceWindow\WindowPrecheck.sql'))
    $bytes | Should -Not -Contain ([byte]13)
    @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    $code = ([Text.Encoding]::ASCII.GetString($bytes) -split "`n" | Where-Object { $_ -notmatch '^\s*--' }) -join "`n"
    # String literals (for example N'CREATE ANY DATABASE' in HAS_PERMS_BY_NAME) are data, not statements.
    $code = [regex]::Replace($code, "N?'(?:[^']|'')*'", "''")
    foreach ($word in 'DROP', 'BACKUP', 'RESTORE', 'ALTER', 'CREATE', 'UPDATE', 'DELETE', 'MERGE', 'KILL', 'SINGLE_USER', 'GRANT', 'EXEC') {
      $code | Should -Not -Match ('\b' + $word + '\b')
    }
    # The only INSERT is into the table variable.
    @([regex]::Matches($code, '\bINSERT\s+INTO\s+(\S+)') | ForEach-Object { $_.Groups[1].Value }) | Should -Be @('@others')
  }
}

Describe 'Binding validation' -Tag 'Unit', 'MaintenanceWindow' {
  It 'accepts a valid Development binding' {
    $t = New-TestBinding
    $r = InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly }
    $r.BindingSha256 | Should -BeExactly $t.Sha256
    $r.RehearsalName | Should -BeExactly 'ATAPUtilities-rehearsal-21596-Development'
  }
  It 'accepts a valid Production binding with its pause record' {
    $t = New-TestBinding -Tier Production
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Production -Mode PrecheckOnly } } | Should -Not -Throw
  }
  It 'refuses <Case>' -ForEach @(
    @{ Case = 'a pin mismatch'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{}; Remove = @(); BadPin = $true; Code = 'MaintenanceWindowBindingPinMismatch' }
    @{ Case = 'an unknown property'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ extra = 1 }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingSchemaInvalid' }
    @{ Case = 'a missing required property'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{}; Remove = @('expectedSid'); BadPin = $false; Code = 'MaintenanceWindowBindingSchemaInvalid' }
    @{ Case = 'a tier mismatch'; Tier = 'Development'; CallTier = 'Integration'; CallMode = 'PrecheckOnly'; Override = @{}; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingTierMismatch' }
    @{ Case = 'a mode mismatch'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'Full'; Override = @{}; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingModeMismatch' }
    @{ Case = 'Full on QA'; Tier = 'QA'; CallTier = 'QA'; CallMode = 'Full'; Override = @{ mode = 'Full' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowTierHasNoSuchMode' }
    @{ Case = 'another instance'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ sqlInstance = 'UTAT022\Production' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingInstanceMismatch' }
    @{ Case = 'another runner SID'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ expectedSid = 'S-1-5-21-670621561-2583097644-1836932750-1001' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingRunnerMismatch' }
    @{ Case = 'another SqlClient'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ SqlClient = @{ Path = 'C:\Other\Microsoft.Data.SqlClient.dll'; Sha256 = ('A' * 64) } }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingSqlClientNotPinned' }
    @{ Case = 'a wrong clone name'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ cloneName = 'ATAPUtilities_LF021Clone_Development_A02' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingCloneNameInvalid' }
    @{ Case = 'a rehearsal path'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ cloneDataPath = 'C:\rehearsal\ATAPUtilities_LF021Clone_Development_A01.mdf' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingPathReserved' }
    @{ Case = 'a backup outside the artifact root'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ backupPath = 'C:\Dropbox\x\ATAPUtilities_Development_LF021_BeforeMaintenance_A01.bak' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingPathOutsideArtifactRoot' }
    @{ Case = 'a window longer than 6 hours'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ expiresUtc = [DateTimeOffset]::UtcNow.AddHours(7).ToString('o') }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingWindowInvalid' }
    @{ Case = 'an expired window'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ notBeforeUtc = [DateTimeOffset]::UtcNow.AddHours(-3).ToString('o'); expiresUtc = [DateTimeOffset]::UtcNow.AddHours(-1).ToString('o') }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingWindowClosed' }
    @{ Case = 'Production without a pause record'; Tier = 'Production'; CallTier = 'Production'; CallMode = 'PrecheckOnly'; Override = @{}; Remove = @('productionPauseRecord'); BadPin = $false; Code = 'MaintenanceWindowBindingSchemaInvalid' }
    @{ Case = 'another host'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ HostName = 'UTAT01' }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingHostMismatch' }
    @{ Case = 'a data source for another instance'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ AllowedDataSources = @('UTAT022\Devwhertzing', 'UTAT022\Production') }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingDataSourceMismatch' }
    @{ Case = 'data sources without the instance'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ AllowedDataSources = @('localhost\Devwhertzing') }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingDataSourceMismatch|SqlInstanceNotListed' }
    @{ Case = 'a clone named for another operation set'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ OperationSet = @{ Name = 'Fix22'; Description = 'other' } }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingCloneNameInvalid' }
    @{ Case = 'a Recover operation'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ Operations = @(@{ Name = 'R'; Kind = 'Recover'; Path = 'C:\x.sql'; Sha256 = ('A' * 64); Database = 'master'; Secret = 'Master'; TimeoutSeconds = 60; TransactionAllowed = $false; TemplatePath = 'C:\t.sql'; TemplateSha256 = ('A' * 64); FillPattern = 'x'; FillEmptyValue = '0' }) }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowOperationKindNotAllowed' }
    @{ Case = 'a Backup operation allowing a transaction'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ Operations = @(@{ Name = 'B'; Kind = 'Backup'; Path = 'C:\x.sql'; Sha256 = ('A' * 64); Database = 'ATAPUtilities'; Secret = 'Database'; TimeoutSeconds = 60; TransactionAllowed = $true }) }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowBindingSchemaInvalid' }
    @{ Case = 'an operation on another database'; Tier = 'Development'; CallTier = 'Development'; CallMode = 'PrecheckOnly'; Override = @{ Operations = @(@{ Name = 'D'; Kind = 'Read'; Path = 'C:\x.sql'; Sha256 = ('A' * 64); Database = 'msdb'; Secret = 'Master'; TimeoutSeconds = 60; TransactionAllowed = $true }) }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowOperationDatabaseNotAllowed' }
    @{ Case = 'Production whose pause list omits Ace Outpost'; Tier = 'Production'; CallTier = 'Production'; CallMode = 'PrecheckOnly'; Override = @{ pauseList = @('BuildMaster releases') }; Remove = @(); BadPin = $false; Code = 'MaintenanceWindowProductionPauseListLacksAceOutpost' }
  ) {
    $t = New-TestBinding -Tier $Tier -Override $Override -Remove $Remove
    $pin = if ($BadPin) { 'F' * 64 } else { $t.Sha256 }
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $pin; tr = $CallTier; md = $CallMode } { param($p, $h, $tr, $md) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier $tr -Mode $md } } |
      Should -Throw "$Code*"
  }
  It 'refuses a Production pause record whose bytes changed' {
    $t = New-TestBinding -Tier Production
    [IO.File]::AppendAllText([string]$t.Value.productionPauseRecord.path, ' ')
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Production -Mode PrecheckOnly } } |
      Should -Throw 'MaintenanceWindowProductionPauseRecordPinMismatch*'
  }
  It 'refuses an operation whose file changed after binding' {
    $t = New-TestBinding
    [IO.File]::AppendAllText([string]$t.Value.Operations[0].Path, '-- changed')
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } |
      Should -Throw 'MaintenanceWindowOperationPinMismatch|BeforeSample'
  }
  It 'accepts an LfLineEndingRepair operation with its pinned modules and repair targets' {
    $base = New-TestBinding
    $one = $base.Value.Operations[0]
    $repair = [ordered]@{ Name = 'LineEndingRepair'; Kind = 'LfLineEndingRepair'; Path = $one.Path; Sha256 = $one.Sha256; Database = 'ATAPUtilities_LF021Clone_Development_A01'; Secret = 'Database'; TimeoutSeconds = 600; TransactionAllowed = $true
      ModuleAlters = @([ordered]@{ Schema = 'Ace'; Name = 'CaptureAISupervisorAttempt'; Type = 'P'; ObjectId = 430624577; BeforeUtf16Sha256 = ('4B8DE4BB' + '0' * 56); LfCreateUtf16Sha256 = ('72B82965' + '0' * 56); PostAlterUtf16Sha256 = ('5A7E4199' + '0' * 56); PermissionMetadataSha256 = ('258965BD' + '0' * 56); AnsiNulls = $true; QuotedIdentifier = $true })
      FlywayRepairTargets = @([ordered]@{ Version = '00150'; OldChecksum = 910403273; NewChecksum = 155333537 }, [ordered]@{ Version = '00160'; OldChecksum = -421944029; NewChecksum = 1767772950 }) }
    $t = New-TestBinding -Override @{ Operations = @($one, $repair) }
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } | Should -Not -Throw
  }
  It 'refuses an LfLineEndingRepair operation <Case>' -ForEach @(
    @{ Case = 'on master'; Database = 'master'; Modules = 1; Targets = @('00150'); Code = 'MaintenanceWindowOperationDatabaseNotAllowed' }
    @{ Case = 'naming one module twice'; Database = 'ATAPUtilities'; Modules = 2; Targets = @('00150'); Code = 'MaintenanceWindowOperationModuleDuplicate' }
    @{ Case = 'naming one repair target twice'; Database = 'ATAPUtilities'; Modules = 1; Targets = @('00150', '00150'); Code = 'MaintenanceWindowOperationRepairTargetDuplicate' }
    @{ Case = 'without its module list'; Database = 'ATAPUtilities'; Modules = 0; Targets = @('00150'); Code = 'MaintenanceWindowBindingSchemaInvalid' }
  ) {
    $base = New-TestBinding
    $one = $base.Value.Operations[0]
    $alter = [ordered]@{ Schema = 'Ace'; Name = 'CaptureAISupervisorAttempt'; Type = 'P'; ObjectId = 1; BeforeUtf16Sha256 = ('A' * 64); LfCreateUtf16Sha256 = ('B' * 64); PostAlterUtf16Sha256 = ('C' * 64); PermissionMetadataSha256 = ('D' * 64); AnsiNulls = $true; QuotedIdentifier = $true }
    $repair = [ordered]@{ Name = 'LineEndingRepair'; Kind = 'LfLineEndingRepair'; Path = $one.Path; Sha256 = $one.Sha256; Database = $Database; Secret = 'Database'; TimeoutSeconds = 600; TransactionAllowed = $true
      FlywayRepairTargets = @(foreach ($v in $Targets) { [ordered]@{ Version = $v; OldChecksum = 1; NewChecksum = 2 } }) }
    if ($Modules -gt 0) { $repair.ModuleAlters = @(for ($i = 0; $i -lt $Modules; $i++) { $alter }) }
    $t = New-TestBinding -Override @{ Operations = @($repair) }
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } | Should -Throw "$Code*"
  }
  It 'refuses module and repair lists on any other kind' {
    $base = New-TestBinding
    $read = [ordered]@{} + $base.Value.Operations[0]
    $read.FlywayRepairTargets = @([ordered]@{ Version = '00150'; OldChecksum = 1; NewChecksum = 2 })
    $t = New-TestBinding -Override @{ Operations = @($read) }
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } | Should -Throw 'MaintenanceWindowBindingSchemaInvalid*'
  }
  It 'keeps OperationSet-specific values out of the code paths' {
    $code = @(Get-ChildItem (Join-Path $script:moduleRoot 'private'), (Join-Path $script:moduleRoot 'public') -Filter '*MaintenanceWindow*.ps1' -File) + @(Get-Item (Join-Path $script:moduleRoot 'private\Invoke-MaintenanceSqlDataSet.ps1')) +
      @(Get-ChildItem (Join-Path $script:moduleRoot 'Resources\MaintenanceWindow') -File)
    foreach ($f in $code) {
      # Comments and help may cite the first job as an example; executable text may not.
      $text = if ($f.Extension -eq '.ps1') {
        $tokens = $null; $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
        (@($tokens | Where-Object { $_.Kind -ne [Management.Automation.Language.TokenKind]::Comment }) | ForEach-Object { $_.Text }) -join ' '
      } else { ((Get-Content -LiteralPath $f.FullName) | Where-Object { $_ -notmatch '^\s*--' }) -join "`n" }
      $text | Should -Not -Match 'LF021|21596|0\.1\.21' -Because $f.Name
    }
  }
  It 'accepts an Experimental by-hand binding in the shared schema, but the runner refuses it' {
    $t = New-TestBinding -Override @{ Tier = 'Experimental'; SqlInstance = 'UTAT022\Expwhertzing'; AllowedDataSources = @('UTAT022\Expwhertzing', 'localhost\Expwhertzing', '.\Expwhertzing'); CloneName = 'ATAPUtilities_LF021Clone_A01'; FilledFromBindingSha256 = ('C' * 64); FilledValue = '00000000-0000-0000-0000-000000000000' }
    $schema = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'schemas\database-maintenance-binding-v1.schema.json') -Raw
    Test-Json -Json (Get-Content -LiteralPath $t.Path -Raw) -Schema $schema | Should -BeTrue
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } | Should -Throw 'MaintenanceWindowBindingTierMismatch|Experimental'
  }
  It 'requires the tier segment in a runner-tier clone name and forbids it for Experimental' {
    $schema = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'schemas\database-maintenance-binding-v1.schema.json') -Raw
    $dev = New-TestBinding -Override @{ CloneName = 'ATAPUtilities_LF021Clone_A01' }
    Test-Json -Json (Get-Content -LiteralPath $dev.Path -Raw) -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    $exp = New-TestBinding -Override @{ Tier = 'Experimental'; SqlInstance = 'UTAT022\Expwhertzing'; AllowedDataSources = @('UTAT022\Expwhertzing'); CloneName = 'ATAPUtilities_LF021Clone_Experimental_A01' }
    Test-Json -Json (Get-Content -LiteralPath $exp.Path -Raw) -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
  }
  It 'refuses an approval window that has not been filled yet' {
    $t = New-TestBinding -Override @{ NotBeforeUtc = $null; ExpiresUtc = $null }
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } | Should -Throw 'MaintenanceWindowBindingWindowNotFilled*'
  }
  It 'requires FillEmptyValue on a Recover operation' {
    $schema = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'schemas\database-maintenance-binding-v1.schema.json') -Raw
    $recover = [ordered]@{ Name = 'Recover'; Kind = 'Recover'; Path = $null; Sha256 = $null; Database = 'master'; Secret = 'Master'; TimeoutSeconds = 3600; TransactionAllowed = $false; TemplatePath = 'C:\t.sql'; TemplateSha256 = ('A' * 64); FillPattern = 'x' }
    $without = New-TestBinding -Override @{ Operations = @($recover) }
    Test-Json -Json (Get-Content -LiteralPath $without.Path -Raw) -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    $recover.FillEmptyValue = '00000000-0000-0000-0000-000000000000'
    $with = New-TestBinding -Override @{ Operations = @($recover) }
    Test-Json -Json (Get-Content -LiteralPath $with.Path -Raw) -Schema $schema | Should -BeTrue
  }
  It 'refuses duplicate operation names' {
    $op = New-TestBinding
    $one = $op.Value.Operations[0]
    $t = New-TestBinding -Override @{ Operations = @($one, $one) }
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } |
      Should -Throw 'MaintenanceWindowOperationNameDuplicate|BeforeSample'
  }
  It 'returns the operation-set clone prefix for the precheck name check' {
    $t = New-TestBinding
    $r = InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $t.Sha256 } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly }
    $r.ClonePrefix | Should -BeExactly 'ATAPUtilities_LF021Clone_'
  }
  It 'refuses a binding with a UTF-8 BOM' {
    $t = New-TestBinding
    $bytes = [byte[]](0xEF, 0xBB, 0xBF) + [IO.File]::ReadAllBytes($t.Path)
    [IO.File]::WriteAllBytes($t.Path, $bytes)
    $h = (Get-FileHash -LiteralPath $t.Path).Hash
    { InModuleScope $script:moduleName -Parameters @{ p = $t.Path; h = $h } { param($p, $h) Assert-MaintenanceWindowBinding -BindingPath $p -ExpectedSha256 $h -Tier Development -Mode PrecheckOnly } } |
      Should -Throw 'MaintenanceWindowBindingSchemaInvalid|BOM'
  }
}

Describe 'DatabaseManagement dependency pin' -Tag 'Unit', 'MaintenanceWindow' {
  BeforeEach {
    $script:root = Join-Path $TestDrive 'Modules'
    $script:base = Join-Path $script:root 'ATAP.Utilities.DatabaseManagement.Powershell\0.1.26'
  }
  It 'passes for one copy at the pinned folder whose commands resolve there' {
    InModuleScope $script:moduleName -Parameters @{ root = $script:root; base = $script:base } {
      param($root, $base)
      Mock Get-MaintenanceWindowModulesRoot { $root }
      $fake = [pscustomobject]@{ Version = [version]'0.1.26'; ModuleBase = $base }
      Mock Get-Module { , $fake } -ParameterFilter { $Name -eq 'ATAP.Utilities.DatabaseManagement.Powershell' }
      Mock Get-Command { [pscustomobject]@{ Module = $fake } } -ParameterFilter { $Name -in @('Resolve-DatabaseSqlConnection', 'Invoke-Flyway') }
      (Assert-MaintenanceWindowDependency -ExpectedVersion '0.1.26').ModuleBase | Should -BeExactly $base
    }
  }
  It 'refuses <Case>' -ForEach @(
    @{ Case = 'no loaded copy'; Copies = 0; Version = '0.1.26'; Sub = '0.1.26'; CommandElsewhere = $false; Detail = 'LoadedCopies=0' }
    @{ Case = 'two loaded copies'; Copies = 2; Version = '0.1.26'; Sub = '0.1.26'; CommandElsewhere = $false; Detail = 'LoadedCopies=2' }
    @{ Case = 'another version'; Copies = 1; Version = '0.1.25'; Sub = '0.1.25'; CommandElsewhere = $false; Detail = 'Version=0.1.25' }
    @{ Case = 'another folder'; Copies = 1; Version = '0.1.26'; Sub = 'elsewhere'; CommandElsewhere = $false; Detail = 'ModuleBase' }
    @{ Case = 'a command from another copy'; Copies = 1; Version = '0.1.26'; Sub = '0.1.26'; CommandElsewhere = $true; Detail = 'Command=Resolve-DatabaseSqlConnection' }
  ) {
    InModuleScope $script:moduleName -Parameters @{ root = $script:root; copies = $Copies; v = $Version; sub = $Sub; elsewhere = $CommandElsewhere; detail = $Detail } {
      param($root, $copies, $v, $sub, $elsewhere, $detail)
      Mock Get-MaintenanceWindowModulesRoot { $root }
      $fake = [pscustomobject]@{ Version = [version]$v; ModuleBase = (Join-Path $root "ATAP.Utilities.DatabaseManagement.Powershell\$sub") }
      $other = [pscustomobject]@{ Version = [version]$v; ModuleBase = 'C:\Dropbox\src\ATAP.Utilities.DatabaseManagement.Powershell' }
      $list = @(for ($i = 0; $i -lt $copies; $i++) { $fake })
      Mock Get-Module { $list } -ParameterFilter { $Name -eq 'ATAP.Utilities.DatabaseManagement.Powershell' }
      $cmdModule = if ($elsewhere) { $other } else { $fake }
      Mock Get-Command { [pscustomobject]@{ Module = $cmdModule } } -ParameterFilter { $Name -in @('Resolve-DatabaseSqlConnection', 'Invoke-Flyway') }
      { Assert-MaintenanceWindowDependency -ExpectedVersion '0.1.26' } | Should -Throw "MaintenanceWindowDependencyNotPinned|$detail"
    }
  }
}

Describe 'Pinned SqlClient' -Tag 'Unit', 'MaintenanceWindow' {
  It 'refuses any path but the pinned one' {
    { InModuleScope $script:moduleName { Import-MaintenanceWindowSqlClient -Path 'C:\Temp\Microsoft.Data.SqlClient.dll' -ExpectedSha256 ('A' * 64) } } | Should -Throw 'MaintenanceWindowSqlClientNotPinned|Path'
  }
  It 'refuses the pinned path with another expected hash' {
    { InModuleScope $script:moduleName -Parameters @{ p = $script:dll } { param($p) Import-MaintenanceWindowSqlClient -Path $p -ExpectedSha256 ('A' * 64) } } | Should -Throw 'MaintenanceWindowSqlClientNotPinned|ExpectedHash'
  }
  It 'loads the pinned assembly and resolves the type to it' -Skip:(-not (Test-Path -LiteralPath 'C:\Program Files\PowerShell\Modules\dbatools.library\2025.12.28\core\lib\Microsoft.Data.SqlClient.dll')) {
    $r = InModuleScope $script:moduleName -Parameters @{ p = $script:dll; h = $script:dllSha } { param($p, $h) Import-MaintenanceWindowSqlClient -Path $p -ExpectedSha256 $h }
    $r.Sha256 | Should -BeExactly $script:dllSha
    ('Microsoft.Data.SqlClient.SqlConnection' -as [type]).Assembly.Location | Should -Be $script:dll
  }
}

Describe 'Result-set capture shape' -Tag 'Unit', 'MaintenanceWindow' {
  BeforeAll {
    $script:ds = [System.Data.DataSet]::new()
    $t1 = $script:ds.Tables.Add('a'); $null = $t1.Columns.Add('EvidenceSet', [string]); $null = $t1.Columns.Add('OtherSessionCount', [int]); $null = $t1.Columns.Add('Note', [string])
    $null = $t1.Rows.Add('WindowOpen', 0, [DBNull]::Value)
    $t2 = $script:ds.Tables.Add('b'); $null = $t2.Columns.Add('EvidenceSet', [string]); $null = $t2.Columns.Add('session_id', [int])
    $t3 = $script:ds.Tables.Add('c'); $null = $t3.Columns.Add('EvidenceSet', [string]); $null = $t3.Columns.Add('name', [string])
    $null = $t3.Rows.Add('NameCheck', 'x'); $null = $t3.Rows.Add('NameCheck', 'y')
  }
  It 'reads every set in order, keeps empty sets, and maps DBNull to null' {
    $sets = [System.Collections.Generic.List[object]]::new()
    $reader = $script:ds.CreateDataReader()
    try { InModuleScope $script:moduleName -Parameters @{ r = $reader; s = $sets } { param($r, $s) ConvertFrom-MaintenanceWindowDataReader -Reader $r -ResultSets $s } } finally { $reader.Dispose() }
    $sets.Count | Should -Be 3
    $sets[0][0]['EvidenceSet'] | Should -BeExactly 'WindowOpen'
    $sets[0][0]['Note'] | Should -BeNullOrEmpty
    $sets[0][0].Contains('Note') | Should -BeTrue
    $sets[1].Count | Should -Be 0
    $sets[2].Count | Should -Be 2
  }
  It 'serializes byte-identically to the reviewed reader (Invoke-ReadOnlyBeforeSample lines 186-197)' {
    # Reference: the reviewed reader's loop and serialization, verbatim in behaviour.
    $reader = $script:ds.CreateDataReader()
    try {
      $refSets = @()
      do { $rows = @(); while ($reader.Read()) { $row = [ordered]@{}; for ($i = 0; $i -lt $reader.FieldCount; $i++) { $row[$reader.GetName($i)] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) } }; $rows += $row }; $refSets += , @($rows) } while ($reader.NextResult())
    } finally { $reader.Dispose() }
    $reference = ([ordered]@{ ResultSets = $refSets } | ConvertTo-Json -Depth 24).Replace("`r`n", "`n")

    $sets = [System.Collections.Generic.List[object]]::new()
    $reader2 = $script:ds.CreateDataReader()
    try { InModuleScope $script:moduleName -Parameters @{ r = $reader2; s = $sets } { param($r, $s) ConvertFrom-MaintenanceWindowDataReader -Reader $r -ResultSets $s } } finally { $reader2.Dispose() }
    $ours = InModuleScope $script:moduleName -Parameters @{ s = $sets } { param($s) ConvertTo-MaintenanceWindowCaptureJson -Document ([ordered]@{ ResultSets = $s }) }
    $ours | Should -BeExactly $reference
    $ours | Should -Not -Match "`r"
  }
  It 'refuses a document without ResultSets' {
    { InModuleScope $script:moduleName { ConvertTo-MaintenanceWindowCaptureJson -Document ([ordered]@{ x = 1 }) } } | Should -Throw 'MaintenanceWindowCaptureShapeInvalid|ResultSets'
  }
}

Describe 'Once-only evidence files' -Tag 'Unit', 'MaintenanceWindow' {
  It 'writes UTF-8 without BOM, returns the hash of the bytes, and refuses to overwrite' {
    $p = Join-Path $TestDrive 'e.json'
    $r = InModuleScope $script:moduleName -Parameters @{ p = $p } { param($p) Write-MaintenanceWindowEvidenceFile -Path $p -Text "{`"a`":1}`n" -Confirm:$false }
    $r.Sha256 | Should -BeExactly (Get-FileHash -LiteralPath $p).Hash
    [IO.File]::ReadAllBytes($p)[0] | Should -Be ([byte][char]'{')
    { InModuleScope $script:moduleName -Parameters @{ p = $p } { param($p) Write-MaintenanceWindowEvidenceFile -Path $p -Text 'x' -Confirm:$false } } | Should -Throw 'MaintenanceWindowEvidenceExists|*'
  }
}

Describe 'Precheck verdict' -Tag 'Unit', 'MaintenanceWindow' {
  BeforeAll {
    function New-Capture {
      param([string]$Status = 'Completed', [int]$Others = 0, [int]$CreateAny = 1, [string[]]$Names = @(), [int]$ClonePaths = 0)
      $sets = [System.Collections.Generic.List[object]]::new()
      $sets.Add(@([ordered]@{ EvidenceSet = 'WindowOpen'; OtherSessionCount = $Others; state_desc = 'ONLINE'; user_access_desc = 'MULTI_USER'; is_read_only = $false }))
      $sets.Add(@(for ($i = 0; $i -lt $Others; $i++) { [ordered]@{ EvidenceSet = 'OtherSessions'; session_id = 60 + $i } }))
      $sets.Add(@([ordered]@{ EvidenceSet = 'RunnerRights'; IsSysadmin = 0; ViewServerState = 1; CreateAnyDatabase = $CreateAny; MsdbBackupsetSelect = 1; MsdbRestoreHistorySelect = 1; CatalogControl = 1 }))
      $sets.Add(@([ordered]@{ EvidenceSet = 'SourceFiles'; type_desc = 'ROWS'; LogicalName = 'd'; SizePages = 12800 }, [ordered]@{ EvidenceSet = 'SourceFiles'; type_desc = 'LOG'; LogicalName = 'l'; SizePages = 1280 }))
      $sets.Add(@(foreach ($n in $Names) { [ordered]@{ EvidenceSet = 'NameCheck'; name = $n } }))
      $sets.Add(@(for ($i = 0; $i -lt $ClonePaths; $i++) { [ordered]@{ EvidenceSet = 'ClonePathCheck'; database_id = 9 } }))
      [pscustomobject]@{ Status = $Status; ResultSets = $sets; SqlErrorNumber = $(if ($Status -eq 'SqlFailed') { 63061 } else { $null }) }
    }
    $script:binding = [pscustomobject]@{ cloneName = 'ATAPUtilities_LF021Clone_Development_A01'; backupPath = 'D:\a\b.bak'; cloneDataPath = 'C:\d\x.mdf'; cloneLogPath = 'C:\d\x_log.ldf' }
  }
  It 'passes a clean capture with enough disk' {
    $v = InModuleScope $script:moduleName -Parameters @{ c = (New-Capture); b = $script:binding } { param($c, $b) Mock Get-MaintenanceWindowDriveFreeBytes { 100GB }; Test-MaintenanceWindowPrecheckResult -Capture $c -Binding $b -RehearsalName 'ATAPUtilities-rehearsal-21596-Development' }
    $v.Status | Should -BeExactly 'Passed'
    $v.SourceDataBytes | Should -Be (12800 * 8192)
  }
  It 'fails <Case>' -ForEach @(
    @{ Case = 'on another session'; CaptureArgs =@{ Others = 1 }; Free = 100GB; Expect = 'WindowOpen' }
    @{ Case = 'on a missing CREATE ANY DATABASE right'; CaptureArgs =@{ CreateAny = 0 }; Free = 100GB; Expect = 'RunnerRights' }
    @{ Case = 'on a clone name collision'; CaptureArgs =@{ Names = @('ATAPUtilities_LF021Clone_Development_A01') }; Free = 100GB; Expect = 'NoNameCollision' }
    @{ Case = 'on a rehearsal name collision'; CaptureArgs =@{ Names = @('ATAPUtilities-rehearsal-21596-Development') }; Free = 100GB; Expect = 'NoNameCollision' }
    @{ Case = 'on a clone path in use'; CaptureArgs =@{ ClonePaths = 1 }; Free = 100GB; Expect = 'NoClonePathInUse' }
    @{ Case = 'on low disk space'; CaptureArgs =@{}; Free = 1MB; Expect = 'DiskSpace' }
    @{ Case = 'on a SQL refusal'; CaptureArgs =@{ Status = 'SqlFailed' }; Free = 100GB; Expect = 'SqlCompleted' }
  ) {
    $c = New-Capture @CaptureArgs
    $v = InModuleScope $script:moduleName -Parameters @{ c = $c; b = $script:binding; f = $Free } { param($c, $b, $f) Mock Get-MaintenanceWindowDriveFreeBytes { $f }; Test-MaintenanceWindowPrecheckResult -Capture $c -Binding $b -RehearsalName 'ATAPUtilities-rehearsal-21596-Development' }
    $v.Status | Should -BeExactly 'Failed'
    $v.FailedChecks | Should -Contain $Expect
  }
}

Describe 'Invoke-DatabaseMaintenanceWindow (PrecheckOnly)' -Tag 'Unit', 'MaintenanceWindow' {
  It 'is exported, and listed in both the psd1 and the psm1' {
    $script:module.ExportedFunctions.Keys | Should -Contain 'Invoke-DatabaseMaintenanceWindow'
    (Import-PowerShellDataFile (Join-Path $script:moduleRoot "$script:moduleName.psd1")).FunctionsToExport | Should -Contain 'Invoke-DatabaseMaintenanceWindow'
    (Get-Content -LiteralPath (Join-Path $script:moduleRoot "$script:moduleName.psm1") -Raw) | Should -Match "'Invoke-DatabaseMaintenanceWindow'"
  }
  It 'refuses every mode but PrecheckOnly before reading the binding' {
    foreach ($m in 'BackupOnly', 'Full', 'DropClone') {
      { Invoke-DatabaseMaintenanceWindow -Tier Development -Mode $m -BindingPath 'C:\nope.json' -ExpectedBindingSha256 ('A' * 64) } | Should -Throw "MaintenanceWindowModeNotImplemented|$m"
    }
  }
  It 'refuses when the process is not the binding runner, before any SQL' {
    # The binding names the well-known Nobody SID (S-1-0-0), which is never a process token user.
    # A real binding must name SvcBuildmaster, and BuildMaster runs these tests as SvcBuildmaster,
    # so a New-TestBinding binding would match the runner there (Release-DatabasePackaging-G7, build 21628).
    InModuleScope $script:moduleName {
      $binding = [pscustomobject]@{ attempt = 'A01'; expectedSid = 'S-1-0-0'; evidenceRoot = 'unused'; databaseManagementVersion = '0.1.26' }
      Mock Assert-MaintenanceWindowBinding { [pscustomobject]@{ Binding = $binding; BindingSha256 = ('B' * 64); TierMap = (Get-MaintenanceWindowTierMap -Tier Development); RehearsalName = 'r' } }
      Mock Assert-MaintenanceWindowDependency { [pscustomobject]@{ ModuleBase = 'X' } }
      Mock Invoke-MaintenanceSqlDataSet { throw 'must not run' }
      { Invoke-DatabaseMaintenanceWindow -Tier Development -Mode PrecheckOnly -BindingPath 'unused' -ExpectedBindingSha256 ('B' * 64) } | Should -Throw 'MaintenanceWindowRunnerIdentityMismatch|*'
      Should -Invoke Invoke-MaintenanceSqlDataSet -Times 0 -Exactly
    }
  }
  It 'writes the capture and verdict once and returns Passed for a clean precheck' {
    $evidenceRoot = Join-Path $TestDrive 'evidence'
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    InModuleScope $script:moduleName -Parameters @{ root = $evidenceRoot; me = $me } {
      param($root, $me)
      $binding = [pscustomobject]@{ attempt = 'A01'; expectedSid = $me; expectedLogin = 'UTAT022\whertzing'; evidenceRoot = $root; databaseManagementVersion = '0.1.26'
        cloneName = 'ATAPUtilities_LF021Clone_Development_A01'; cloneDataPath = 'C:\d\x.mdf'; cloneLogPath = 'C:\d\x_log.ldf'; backupPath = 'D:\a\b.bak'
        buildId = '21596'; packageSha256 = ('0' * 64); sqlClient = [pscustomobject]@{ path = 'p'; sha256 = ('A' * 64) } }
      Mock Assert-MaintenanceWindowBinding { [pscustomobject]@{ Binding = $binding; BindingSha256 = ('B' * 64); TierMap = (Get-MaintenanceWindowTierMap -Tier Development); RehearsalName = 'ATAPUtilities-rehearsal-21596-Development'; ClonePrefix = 'ATAPUtilities_LF021Clone_' } }
      Mock Assert-MaintenanceWindowDependency { [pscustomobject]@{ ModuleBase = 'C:\Program Files\PowerShell\Modules\ATAP.Utilities.DatabaseManagement.Powershell\0.1.26' } }
      Mock Get-MaintenanceWindowDriveFreeBytes { 100GB }
      Mock Invoke-MaintenanceSqlDataSet {
        $sets = [System.Collections.Generic.List[object]]::new()
        $sets.Add(@([ordered]@{ EvidenceSet = 'WindowOpen'; OtherSessionCount = 0; state_desc = 'ONLINE'; user_access_desc = 'MULTI_USER'; is_read_only = $false }))
        $sets.Add(@())
        $sets.Add(@([ordered]@{ EvidenceSet = 'RunnerRights'; IsSysadmin = 0; ViewServerState = 1; CreateAnyDatabase = 1; MsdbBackupsetSelect = 1; MsdbRestoreHistorySelect = 1; CatalogControl = 1 }))
        $sets.Add(@([ordered]@{ EvidenceSet = 'SourceFiles'; type_desc = 'ROWS'; LogicalName = 'd'; SizePages = 100 }, [ordered]@{ EvidenceSet = 'SourceFiles'; type_desc = 'LOG'; LogicalName = 'l'; SizePages = 10 }))
        $sets.Add(@()); $sets.Add(@())
        [pscustomobject]@{ Status = 'Completed'; ResultSets = $sets; SqlErrorNumber = $null; SqlErrors = @() }
      }
      $r = Invoke-DatabaseMaintenanceWindow -Tier Development -Mode PrecheckOnly -BindingPath 'unused' -ExpectedBindingSha256 ('B' * 64) -Confirm:$false
      $r.Status | Should -BeExactly 'Passed'
      (Get-FileHash -LiteralPath $r.CapturePath).Hash | Should -BeExactly $r.CaptureSha256
      (Get-FileHash -LiteralPath $r.VerdictPath).Hash | Should -BeExactly $r.VerdictSha256
      $capture = Get-Content -LiteralPath $r.CapturePath -Raw | ConvertFrom-Json -AsHashtable
      $capture.ResultSets.Count | Should -Be 6
      $capture.Kind | Should -BeExactly 'Coordination-database-maintenance-capture-v1'
      $capture.SQLWrites | Should -Be 0
      $verdict = Get-Content -LiteralPath $r.VerdictPath -Raw | ConvertFrom-Json
      $verdict.CaptureSha256 | Should -BeExactly $r.CaptureSha256
      Should -Invoke Invoke-MaintenanceSqlDataSet -Times 1 -Exactly -ParameterFilter { $Database -ceq 'master' -and $SqlInstance -ceq 'UTAT022\Devwhertzing' -and $Parameters['ExpectedSid'] -is [byte[]] -and $Parameters['ClonePrefix'] -ceq 'ATAPUtilities_LF021Clone_' }
    }
  }
  It 'writes nothing and runs no SQL under -WhatIf' {
    $evidenceRoot = Join-Path $TestDrive 'whatif'
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    InModuleScope $script:moduleName -Parameters @{ root = $evidenceRoot; me = $me } {
      param($root, $me)
      $binding = [pscustomobject]@{ attempt = 'A01'; expectedSid = $me; evidenceRoot = $root; databaseManagementVersion = '0.1.26' }
      Mock Assert-MaintenanceWindowBinding { [pscustomobject]@{ Binding = $binding; BindingSha256 = ('B' * 64); TierMap = (Get-MaintenanceWindowTierMap -Tier Development); RehearsalName = 'r' } }
      Mock Assert-MaintenanceWindowDependency { [pscustomobject]@{ ModuleBase = 'X' } }
      Mock Invoke-MaintenanceSqlDataSet { throw 'must not run' }
      $r = Invoke-DatabaseMaintenanceWindow -Tier Development -Mode PrecheckOnly -BindingPath 'unused' -ExpectedBindingSha256 ('B' * 64) -WhatIf
      $r.Status | Should -BeExactly 'ProposedOnly'
      Test-Path -LiteralPath $root | Should -BeFalse
      Should -Invoke Invoke-MaintenanceSqlDataSet -Times 0 -Exactly
    }
  }
}
