#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
# AI assisted using Powershell.instructions.md as guidelines
# Pester 6.2+ static-contract tests for V4-E08 / DBA2-T03: the
# DatabaseChangePackage-5Stage OtterScript plan must be a thin runner plan,
# and the runner script must preserve the contracts the plan depends on.

BeforeAll {
    $script:PlansDir   = Join-Path $PSScriptRoot '..'
    $script:fixtureSource631 = [IO.Path]::GetFullPath((Join-Path $script:PlansDir '../../..'))
    $script:PlanPath   = Join-Path $script:PlansDir 'DatabaseChangePackage-5Stage.otter'
    $script:RunnerPath = Join-Path $script:PlansDir 'Invoke-DatabasePackageBuildMasterStage.ps1'
    $script:PlanText   = Get-Content -LiteralPath $script:PlanPath -Raw
    $script:RunnerText = Get-Content -LiteralPath $script:RunnerPath -Raw
}

Describe 'V4-E08 plan shape: DatabaseChangePackage-5Stage.otter is a thin runner plan' {

    It 'plan and runner files both exist' {
        $script:PlanPath   | Should -Exist
        $script:RunnerPath | Should -Exist
    }

    It 'plan contains no Stage blocks (runner owns stage branching)' {
        $script:PlanText | Should -Not -Match '(?im)^\s*stage\s+\w+\s*\{'
    }

    It 'plan contains exactly one Exec block' {
        $execMatches = [regex]::Matches($script:PlanText, '(?im)^\s*Exec\s*\(')
        $execMatches.Count | Should -Be 1
    }

    It 'the single Exec invokes pwsh -File with the runner script' {
        $script:PlanText | Should -Match 'FileName:\s*pwsh'
        $script:PlanText | Should -Match '-File\s+"\$InvokeDatabasePackageStageScript"'
    }

    It 'plan enables normal PowerShell profiles' {
        $script:PlanText | Should -Not -Match '(?i)-NoProfile\b'
    }

    It 'plan contains no inline pwsh -Command blocks' {
        $script:PlanText | Should -Not -Match '(?i)-NoProfile\s+-Command\s'
    }

    It 'plan does not pass any ApiKey on the command line' {
        $script:PlanText | Should -Not -Match '(?i)-ProGetApiKey\b'
        $script:PlanText | Should -Not -Match '(?i)-ApiKey\s+["\$]'
    }

    It 'plan does not contain a $Decrypt( call' {
        $script:PlanText | Should -Not -Match '\$Decrypt\('
    }

    It 'plan does not assign $env:PROGET_* inside an Arguments block' {
        $script:PlanText | Should -Not -Match '\$\$env:PROGET_[A-Z_]+\s*=\s*[''"]'
    }

    It 'plan does not embed a literal Database application name' {
        # Plan must read $DatabaseApplication from BuildMaster Application
        # Variables, not hard-code names like ATAPUtilities or AceCommander.
        $script:PlanText | Should -Not -Match '(?i)Database\\(ATAPUtilities|AceCommander)\b'
        $script:PlanText | Should -Match '-DatabaseApplication\s+"\$DatabaseApplication"'
    }

    It 'plan passes the BuildMaster stage name explicitly via $PipelineStageName' {
        $script:PlanText | Should -Match '-Stage\s+"\$PipelineStageName"'
    }

    It 'plan passes the required runner parameters' {
        $script:PlanText | Should -Match '-BuildMasterBuildId\s+"\$BuildMasterBuildId"'
        $script:PlanText | Should -Match '-ApplicationName\s+"\$ApplicationName"'
        $script:PlanText | Should -Match '-DatabaseStream\s+"\$DatabaseStream"'
        $script:PlanText | Should -Match '-ProGetUrl\s+"\$ProGetBaseUrl"'
    }

    It 'plan passes the per-tier connection-string secret NAMES (not values) for apply/rehearsal' {
        $script:PlanText | Should -Match '-ExperimentalDatabaseDBConnectionStringSecretName\s+"\$ExperimentalDatabaseDBConnectionStringSecretName"'
        $script:PlanText | Should -Match '-DevelopmentDatabaseDBConnectionStringSecretName\s+"\$DevelopmentDatabaseDBConnectionStringSecretName"'
        $script:PlanText | Should -Match '-IntegrationDatabaseDBConnectionStringSecretName\s+"\$IntegrationDatabaseDBConnectionStringSecretName"'
        $script:PlanText | Should -Match '-QADatabaseDBConnectionStringSecretName\s+"\$QADatabaseDBConnectionStringSecretName"'
        $script:PlanText | Should -Match '-ProductionDatabaseDBConnectionStringSecretName\s+"\$ProductionDatabaseDBConnectionStringSecretName"'
    }

    It 'plan passes the explicit deployment-principal audit policy without credentials' {
        foreach ($name in @(
            'ExperimentalDatabaseDeploymentSqlInstance',
            'DevelopmentDatabaseDeploymentSqlInstance',
            'IntegrationDatabaseDeploymentSqlInstance',
            'QADatabaseDeploymentSqlInstance',
            'ProductionDatabaseDeploymentSqlInstance',
            'DatabaseDeploymentExpectedHostName',
            'DatabaseDeploymentServiceAccount',
            'DatabaseDeploymentExpectedAccountSid',
            'DatabaseDeploymentAllowedInstanceNames',
            'DatabaseDeploymentApprovedDatabaseNames'
        )) {
            $script:PlanText | Should -Match ('-{0}\s+"\${0}"' -f $name)
        }
        $script:PlanText | Should -Not -Match '-DatabaseDeploymentSqlInstance\s'
    }

    It 'plan references the runner script via $BuildMasterPlanScriptDir + Invoke-DatabasePackageBuildMasterStage.ps1' {
        $script:PlanText | Should -Match 'set\s+\$BuildMasterPlanScriptDir\s*=\s*\$PathCombine'
        $script:PlanText | Should -Match 'Invoke-DatabasePackageBuildMasterStage\.ps1'
    }
}

Describe 'V4-E08 runner shape: Invoke-DatabasePackageBuildMasterStage.ps1 contract' {

    It 'runner declares the parameters the plan supplies' {
        foreach ($param in @(
            'BuildToolingModulePath',
            'SourcePath',
            'BuildMasterBuildId',
            'BuildNumber',
            'ExecutionId',
            'ApplicationName',
            'DatabaseApplication',
            'DatabaseStream',
            'ExcludedMigrationFileNames',
            'Branch',
            'Stage',
            'ProGetUrl',
            'ProGetApiKeySecretName'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'runner carries only the canonical BuildMaster SecretName' {
        $script:RunnerText | Should -Match "ProGetApiKeySecretName\s*=\s*'ProGet\.BuildMaster\.API\.Key'"
        $script:RunnerText | Should -Not -Match 'PROGET_(?:BUILDMASTER|ADMIN)_API_KEY'
        $script:RunnerText | Should -Not -Match '\$ProGetApiKey\b'
    }

    It 'runner invokes Publish-DatabaseChangePackageToProGet (no inline dotnet nuget push)' {
        $script:RunnerText | Should -Match 'Publish-DatabaseChangePackageToProGet'
        $script:RunnerText | Should -Match '-ProGetBaseUrl\s+\$ProGetUrl'
        $script:RunnerText | Should -Not -Match 'dotnet\s+nuget\s+push'
    }

    It 'runner always binds the source-tree ProGet database commands' {
        $script:RunnerText | Should -Match "\.\s+\(Resolve-BuildToolingFunctionFile[^\r\n]+Publish-DatabaseChangePackageToProGet\.ps1'\)"
        $script:RunnerText | Should -Match "\.\s+\(Resolve-BuildToolingFunctionFile[^\r\n]+Promote-DatabaseChangePackage\.ps1'\)"
    }

    It 'runner invokes Promote-DatabaseChangePackage for non-Experimental tiers' {
        $script:RunnerText | Should -Match 'Promote-DatabaseChangePackage'
    }

    It 'runner invokes New-DatabaseChangePackage during the Experimental stage' {
        $script:RunnerText | Should -Match 'New-DatabaseChangePackage'
    }

    It 'runner always binds every canonical source-tree database-management command' {
        $script:RunnerText | Should -Match 'foreach\s+\(\$commandName\s+in\s+\$databaseManagementFunctionFiles\.Keys\)'
        $script:RunnerText | Should -Match '\.\s+\$candidate'
        $script:RunnerText | Should -Match 'Required database-management cmdlet'
    }

    It 'runner loads Microsoft.Data.SqlClient before binding typed database-management commands' {
        $typeGuardIdx = $script:RunnerText.IndexOf("'Microsoft.Data.SqlClient.SqlConnection' -as [type]")
        $dbatoolsIdx = $script:RunnerText.IndexOf('Import-Module -Name dbatools')
        $bindingLoopIdx = $script:RunnerText.IndexOf('foreach ($commandName in $databaseManagementFunctionFiles.Keys)')

        $typeGuardIdx | Should -BeGreaterThan 0
        $dbatoolsIdx | Should -BeGreaterThan $typeGuardIdx
        $bindingLoopIdx | Should -BeGreaterThan $dbatoolsIdx
        $script:RunnerText | Should -Match 'Microsoft\.Data\.SqlClient\.SqlConnection remains unavailable after importing dbatools'
    }

    It 'plan passes the exact migration exclusion application variable to the runner' {
        $script:PlanText | Should -Match '-ExcludedMigrationFileNames\s+"\$ExcludedMigrationFileNames"'
    }

    It 'runner parses, validates, records, and forwards exact migration exclusions' {
        $script:RunnerText | Should -Match '\$ExcludedMigrationFileNames\s+-split\s+'';'''
        $script:RunnerText | Should -Match 'GetFileName\(\$excludedMigration\)'
        $script:RunnerText | Should -Match 'ExcludedMigrationFileName''\]\s*=\s*\$excludedMigrations'
        $script:RunnerText | Should -Match 'ExcludedMigrations\s*=\s*\$excludedMigrations'
    }

    It 'runner invokes Get-DatabasePackageBuildContext' {
        $script:RunnerText | Should -Match 'Get-DatabasePackageBuildContext'
    }

    It 'runner uses the canonical per-build run-context directory' {
        $script:RunnerText | Should -Match 'Initialize-BuildMasterRunContextDirectory'
        $script:RunnerText | Should -Match "Join-Path[^\r\n]*PSScriptRoot[^\r\n]*BuildMasterRunContext\.Common\.ps1"
    }

    It 'runner writes per-package per-tier completion markers' {
        $script:RunnerText | Should -Match 'Set-DatabasePackageStageCompleted'
        $script:RunnerText | Should -Match 'Test-DatabasePackageStageCompleted'
        $script:RunnerText | Should -Match '\$databasePackageId\.\$Tier\.completed\.tmp'
    }

    It 'runner enforces the version.json ceiling clamp' {
        $script:RunnerText | Should -Match 'Get-BuildMasterAllowDecisions'
        $script:RunnerText | Should -Match 'exceeds version ceiling'
    }

    It 'runner uses the canonical database feed names' {
        $script:RunnerText | Should -Match "ExperimentalFeed\s*=\s*'database-experimental'"
        $script:RunnerText | Should -Match "DevelopmentFeed\s*=\s*'database-development'"
        $script:RunnerText | Should -Match "IntegrationFeed\s*=\s*'database-integration'"
        $script:RunnerText | Should -Match "QAFeed\s*=\s*'database-qa'"
        $script:RunnerText | Should -Match "ProductionFeed\s*=\s*'database-stable'"
    }

    It 'runner is invocable from PowerShell (parser succeeds with no errors)' {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:RunnerPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'Task 9.10 runner contract: per-tier apply + rehearsal-before-promotion are wired' {

    It 'runner declares the per-tier connection-string secret-name parameters' {
        foreach ($param in @(
            'ExperimentalDatabaseDBConnectionStringSecretName',
            'DevelopmentDatabaseDBConnectionStringSecretName',
            'IntegrationDatabaseDBConnectionStringSecretName',
            'QADatabaseDBConnectionStringSecretName',
            'ProductionDatabaseDBConnectionStringSecretName'
        )) {
            $script:RunnerText | Should -Match "\[string\]\$\b$param\b"
        }
    }

    It 'runner exposes -SkipRehearsal and -SkipApply switches' {
        $script:RunnerText | Should -Match '\[switch\]\$SkipRehearsal'
        $script:RunnerText | Should -Match '\[switch\]\$SkipApply'
    }

    It 'runner fails before publish or promotion when the tier database target is absent or apply is bypassed' {
        $script:RunnerText | Should -Match "cannot publish, promote, or complete package '.+': the corresponding connection-string secret name is not configured"
        $script:RunnerText | Should -Match "cannot publish, promote, or complete package '.+' while -SkipApply is supplied"
    }

    It 'runner enforces rehearsal BEFORE promotion (rehearsal call precedes the Promote call)' {
        $rehearsalIdx = $script:RunnerText.IndexOf('Invoke-DatabasePackageTierRehearsal `')
        $promoteIdx   = $script:RunnerText.IndexOf('$promotionResult = Promote-DatabaseChangePackage')
        $rehearsalIdx | Should -BeGreaterThan 0
        $promoteIdx   | Should -BeGreaterThan 0
        $rehearsalIdx | Should -BeLessThan $promoteIdx
    }

    It 'runner blocks the stage action when the rehearsal fails (throws on non-Success)' {
        $script:RunnerText | Should -Match 'rehearsal FAILED'
        $script:RunnerText | Should -Match 'stage action blocked'
    }

    It 'runner applies the package to the tier database via Invoke-Flyway migrate' {
        $script:RunnerText | Should -Match "FlywayCommand\s*=\s*'migrate'"
        $script:RunnerText | Should -Match 'Invoke-Flyway @flywayParameters'
    }

    It 'publishes and rehearses Experimental before applying the exact package to ExpDeveloper' {
        $publishIdx = $script:RunnerText.IndexOf('$publishResult = Publish-DatabaseChangePackageToProGet')
        $rehearsalIdx = $script:RunnerText.IndexOf('$rehearsalResult = Invoke-DatabasePackageTierRehearsal `', $publishIdx)
        $applyIdx   = $script:RunnerText.IndexOf('Invoke-DatabasePackageStageApply `', $rehearsalIdx)
        $publishIdx | Should -BeGreaterThan 0
        $rehearsalIdx | Should -BeGreaterThan $publishIdx
        $applyIdx   | Should -BeGreaterThan $rehearsalIdx
    }

    It 'runner fails closed through a read-only principal audit before any package action' {
        $script:RunnerText | Should -Match 'function\s+Assert-DatabasePackageDeploymentPrincipal'
        $script:RunnerText | Should -Match 'Get-SqlServiceLoginGrantTarget'
        $script:RunnerText | Should -Not -Match 'Set-SqlDatabasePackageDeploymentPrincipal'
        $auditIdx = $script:RunnerText.IndexOf('$principalAudit = Assert-DatabasePackageDeploymentPrincipal')
        $stageActionIdx = $script:RunnerText.IndexOf("if (`$Stage -eq 'Experimental')", $auditIdx)
        $auditIdx | Should -BeGreaterThan 0
        $stageActionIdx | Should -BeGreaterThan $auditIdx
    }

    It 'reuses the captured immutable Experimental package after publish succeeds but apply fails' {
        $resumeIdx = $script:RunnerText.IndexOf("Resume exact published package '")
        $retryRehearsalIdx = $script:RunnerText.IndexOf('$rehearsalResult = Invoke-DatabasePackageTierRehearsal `', $resumeIdx)
        $retryApplyIdx = $script:RunnerText.IndexOf('Invoke-DatabasePackageStageApply `', $retryRehearsalIdx)
        $buildIdx = $script:RunnerText.IndexOf('$nupkgPath = New-DatabaseChangePackage')

        $resumeIdx | Should -BeGreaterThan 0
        $retryRehearsalIdx | Should -BeGreaterThan $resumeIdx
        $retryApplyIdx | Should -BeGreaterThan $retryRehearsalIdx
        $retryRehearsalIdx | Should -BeLessThan $buildIdx
        $buildIdx | Should -BeGreaterThan $resumeIdx
        $script:RunnerText | Should -Match 'Experimental retry package drift'
        $script:RunnerText | Should -Match 'build and publish skipped'
        $script:RunnerText | Should -Match 'Get-FileHash\s+-LiteralPath\s+\$capturedNupkgPath\s+-Algorithm\s+SHA256'
    }

    It 'fails closed on Experimental -SkipRehearsal before build or publish' {
        $guardIdx = $script:RunnerText.IndexOf("if (`$Stage -eq 'Experimental' -and `$SkipRehearsal)")
        $buildIdx = $script:RunnerText.IndexOf('$nupkgPath = New-DatabaseChangePackage')
        $publishIdx = $script:RunnerText.IndexOf('$publishResult = Publish-DatabaseChangePackageToProGet')

        $guardIdx | Should -BeGreaterThan 0
        $guardIdx | Should -BeLessThan $buildIdx
        $guardIdx | Should -BeLessThan $publishIdx
        $script:RunnerText | Should -Match "cannot build, publish, rehearse, apply, or complete package '.+' while -SkipRehearsal is supplied"
    }

    It 'passes the exact Experimental package and configured target to both rehearsal paths' {
        $script:RunnerText | Should -Match '(?s)Rehearsing exact captured package.+?-NupkgPath\s+\$capturedNupkgPath.+?-Application\s+\$DatabaseApplication.+?-Tier\s+\$Stage.+?-BuildId\s+\$BuildMasterBuildId.+?-ConnectionStringSecretName\s+\$tierConnectionSecretName'
        $script:RunnerText | Should -Match '(?s)Rehearsing exact published package.+?-NupkgPath\s+\$nupkgPath.+?-Application\s+\$DatabaseApplication.+?-Tier\s+\$Stage.+?-BuildId\s+\$BuildMasterBuildId.+?-ConnectionStringSecretName\s+\$tierConnectionSecretName'
    }

    It 'promotes each later ProGet tier before applying the exact package to its database' {
        $promoteIdx = $script:RunnerText.IndexOf('$promotionResult = Promote-DatabaseChangePackage')
        $applyIdx   = $script:RunnerText.IndexOf('Invoke-DatabasePackageStageApply `', $promoteIdx)
        $promoteIdx | Should -BeGreaterThan 0
        $applyIdx   | Should -BeGreaterThan $promoteIdx
    }

    It 'writes stage completion only after the corresponding database apply' {
        $promoteIdx  = $script:RunnerText.IndexOf('$promotionResult = Promote-DatabaseChangePackage')
        $applyIdx    = $script:RunnerText.IndexOf('Invoke-DatabasePackageStageApply `', $promoteIdx)
        $completeIdx = $script:RunnerText.IndexOf('Set-DatabasePackageStageCompleted ', $applyIdx)
        $completeIdx | Should -BeGreaterThan $applyIdx
    }

    It 'runner takes a pre-migration snapshot for permanent tiers' {
        $script:RunnerText | Should -Match "permanentTiers\s*=\s*@\('Integration',\s*'QA',\s*'Production'\)"
        $script:RunnerText | Should -Match 'New-DatabasePreMigrationSnapshot'
    }

    It 'runner maps Integration and QA tiers to the Testing Flyway environment' {
        $script:RunnerText | Should -Match "'Integration'\s*\{\s*return 'Testing'"
        $script:RunnerText | Should -Match "'QA'\s*\{\s*return 'Testing'"
    }

    It 'runner writes a per-tier apply completion marker' {
        $script:RunnerText | Should -Match '\$DatabasePackageId\.\$Tier\.applied\.tmp'
        $script:RunnerText | Should -Match 'Get-DatabasePackageApplyMarkerPath'
    }

    It 'runner never passes a connection string or secret VALUE on a command line' {
        $script:RunnerText | Should -Not -Match '(?i)Server\s*=\s*[^;]+;\s*Database\s*='
        # The migrate path uses DBConnectionStringSecretName (a name), never an inline value.
        $script:RunnerText | Should -Match 'DBConnectionStringSecretName\s*=\s*\$ConnectionStringSecretName'
    }
}

Describe 'V4-E08 runner SEC-T1: no secret in command-line arguments or trace output' {

    It 'runner never spawns dotnet with an --api-key argument' {
        $script:RunnerText | Should -Not -Match '--api-key'
    }

    It 'runner does not contain a literal connection-string pattern' {
        $script:RunnerText | Should -Not -Match '(?i)Server\s*=\s*[^;]+;\s*Database\s*='
        $script:RunnerText | Should -Not -Match '(?i)Password\s*=\s*[''"]\w'
    }

    It 'runner never echoes $script:resolvedProGetApiKey into a string' {
        # The API key may appear in env-var assignments but not in interpolated log/trace lines.
        $patterns = @(
            'Write-PSFMessage[^\r\n]*\$script:resolvedProGetApiKey',
            'Add-DatabasePackagePublishTrace[^\r\n]*\$script:resolvedProGetApiKey',
            'Write-Output[^\r\n]*\$script:resolvedProGetApiKey'
        )
        foreach ($pattern in $patterns) {
            $script:RunnerText | Should -Not -Match $pattern
        }
    }
}

Describe 'V4-E08 skip-marker logic: completion marker prevents double-execution' {

    BeforeAll {
        $script:TempContextDir = Join-Path ([System.IO.Path]::GetTempPath()) (
            'DBA2-T03-' + [Guid]::NewGuid().ToString('N')
        )
        New-Item -ItemType Directory -Path $script:TempContextDir -Force | Out-Null

        # Load only the runner's function definitions. Dot-sourcing the whole
        # file would evaluate the mandatory script param block.
        $parseTokens = $null
        $parseErrors = $null
        $runnerAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:RunnerPath,
            [ref] $parseTokens,
            [ref] $parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            throw "Failed to parse runner: $($parseErrors[0].Message)"
        }
        $helperScript = (
            $runnerAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true) | ForEach-Object { $_.Extent.Text }
        ) -join [Environment]::NewLine

        # Stub Write-PSFMessage so dot-sourcing in a profile-less Pester run
        # does not depend on PSFramework.
        if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
            function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$args) }
        }

        # Stub the BuildMasterRunContext.Common.ps1 dependencies; we only care
        # about the marker helpers in this Describe.
        function global:Initialize-BuildMasterRunContextDirectory { param($SourcePath, $BuildMasterBuildId) return $script:TempContextDir }
        function global:Read-BuildMasterRunContextJson { param($ContextDirectory) return $null }
        function global:Get-BuildMasterAllowDecisions { param($CeilingTier) return @{ Experimental = $true; Development = $true; Integration = $true; QA = $true; Production = $true } }
        function global:Write-BuildMasterRunStateFiles { param($StateFiles, $Values) }
        function global:Write-BuildMasterRunContextJson { param([Parameter(ValueFromRemainingArguments)]$args) }

        Invoke-Expression $helperScript
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:TempContextDir) {
            Remove-Item -LiteralPath $script:TempContextDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -Path Function:\Initialize-BuildMasterRunContextDirectory -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Read-BuildMasterRunContextJson -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Get-BuildMasterAllowDecisions -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Write-BuildMasterRunStateFiles -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Write-BuildMasterRunContextJson -ErrorAction SilentlyContinue
    }

    It 'Test-DatabasePackageStageCompleted returns $false before the marker exists' {
        (Test-DatabasePackageStageCompleted `
            -ContextDirectory $script:TempContextDir `
            -DatabasePackageId 'ATAPUtilities.Database' `
            -Tier 'Experimental') | Should -BeFalse
    }

    It 'Set-DatabasePackageStageCompleted writes a marker file at the expected path' {
        Set-DatabasePackageStageCompleted `
            -ContextDirectory $script:TempContextDir `
            -DatabasePackageId 'ATAPUtilities.Database' `
            -Tier 'Experimental' `
            -PackageVersion '1.0.0-experimental.42'

        $expectedPath = Join-Path $script:TempContextDir 'ATAPUtilities.Database.Experimental.completed.tmp'
        Test-Path -LiteralPath $expectedPath -PathType Leaf | Should -BeTrue
    }

    It 'Test-DatabasePackageStageCompleted returns $true after the marker exists' {
        (Test-DatabasePackageStageCompleted `
            -ContextDirectory $script:TempContextDir `
            -DatabasePackageId 'ATAPUtilities.Database' `
            -Tier 'Experimental') | Should -BeTrue
    }
}

Describe 'Task 9.10 behavior: per-tier apply + rehearsal helpers' {

    BeforeAll {
        $script:RunnerPath = Join-Path (Join-Path $PSScriptRoot '..') 'Invoke-DatabasePackageBuildMasterStage.ps1'

        # Load only the runner's function definitions (parsing the file would
        # evaluate the mandatory script param block + bottom invocation).
        $parseTokens = $null
        $parseErrors = $null
        $runnerAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:RunnerPath, [ref] $parseTokens, [ref] $parseErrors)
        if ($parseErrors.Count -gt 0) { throw "Failed to parse runner: $($parseErrors[0].Message)" }
        $helperScript = (
            $runnerAst.FindAll({
                param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true) | ForEach-Object { $_.Extent.Text }
        ) -join [Environment]::NewLine

        if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
            function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$args) }
        }

        Invoke-Expression $helperScript

        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('DBA-T9_10-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        $script:TracePath = Join-Path $script:TempDir 'trace.log'
        # A real on-disk file standing in for the immutable nupkg.
        $script:FakeNupkg = Join-Path $script:TempDir 'ATAPUtilities.Database.1.0.0.nupkg'
        Set-Content -LiteralPath $script:FakeNupkg -Value 'fake' -Encoding utf8
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:TempDir) {
            Remove-Item -LiteralPath $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Get-DatabaseTierEnvironment maps tiers to Flyway environments' {
        It '<Tier> -> <Expected>' -ForEach @(
            @{ Tier = 'Experimental'; Expected = 'Experimental' }
            @{ Tier = 'Development';  Expected = 'Development' }
            @{ Tier = 'Integration'; Expected = 'Testing' }
            @{ Tier = 'QA';          Expected = 'Testing' }
            @{ Tier = 'Production';  Expected = 'Production' }
        ) {
            (Get-DatabaseTierEnvironment -Tier $Tier) | Should -BeExactly $Expected
        }
    }

    Context 'Resolve-DatabaseTierConnectionSecretName' {
        It 'returns the configured name for the matching tier' {
            (Resolve-DatabaseTierConnectionSecretName -Tier 'Integration' `
                -IntegrationSecretName 'dbConnectionString-ATAPUtilities-localhost-Integration') |
                Should -BeExactly 'dbConnectionString-ATAPUtilities-localhost-Integration'
        }
        It 'returns empty string when the tier has no name configured' {
            (Resolve-DatabaseTierConnectionSecretName -Tier 'QA') | Should -BeExactly ''
        }
    }

    Context 'Resolve-DatabaseTierDeploymentSqlInstance' {
        It '<Tier> selects <Expected>' -ForEach @(
            @{ Tier = 'Experimental'; Expected = 'UTAT022\Expwhertzing' }
            @{ Tier = 'Development';  Expected = 'UTAT022\Devwhertzing' }
            @{ Tier = 'Integration';  Expected = 'UTAT022\Integration' }
            @{ Tier = 'QA';           Expected = 'UTAT022\QA' }
            @{ Tier = 'Production';   Expected = 'UTAT022\Production' }
        ) {
            (Resolve-DatabaseTierDeploymentSqlInstance -Tier $Tier `
                -ExperimentalSqlInstance 'UTAT022\Expwhertzing' `
                -DevelopmentSqlInstance 'UTAT022\Devwhertzing' `
                -IntegrationSqlInstance 'UTAT022\Integration' `
                -QASqlInstance 'UTAT022\QA' `
                -ProductionSqlInstance 'UTAT022\Production') | Should -BeExactly $Expected
        }

        It 'returns empty when the selected stage variable is not configured' {
            (Resolve-DatabaseTierDeploymentSqlInstance -Tier 'QA' `
                -IntegrationSqlInstance 'UTAT022\Integration') | Should -BeExactly ''
        }
    }

    Context 'Assert-DatabasePackageDeploymentPrincipal' {
        BeforeEach {
            function global:Get-SqlServiceLoginGrantTarget {
                param([Parameter(ValueFromRemainingArguments)]$a)
                $null = $a
                [PSCustomObject]@{
                    DatabaseName = 'ATAPUtilities'
                    Include = $true
                    IsCompliant = $true
                    ExclusionReason = $null
                    DriftReason = $null
                }
            }
        }

        AfterEach {
            Remove-Item Function:\Get-SqlServiceLoginGrantTarget -ErrorAction SilentlyContinue
        }

        It 'returns the one compliant explicitly admitted package target' {
            $result = Assert-DatabasePackageDeploymentPrincipal `
                -SqlInstance 'UTAT022\Integration' -ExpectedHostName 'UTAT022' `
                -ServiceAccount 'UTAT022\SvcBuildMaster' `
                -ExpectedAccountSid 'S-1-5-21-1-2-3-1001' `
                -AllowedInstanceName @('Integration') `
                -ApprovedDatabaseName @('ATAPUtilities') `
                -DatabaseApplication 'ATAPUtilities'
            $result.IsCompliant | Should -BeTrue
        }

        It 'rejects a package target absent from the explicit admission list before querying SQL' {
            { Assert-DatabasePackageDeploymentPrincipal `
                -SqlInstance 'UTAT022\Integration' -ExpectedHostName 'UTAT022' `
                -ServiceAccount 'UTAT022\SvcBuildMaster' `
                -ExpectedAccountSid 'S-1-5-21-1-2-3-1001' `
                -AllowedInstanceName @('Integration') `
                -ApprovedDatabaseName @('SomeOtherDatabase') `
                -DatabaseApplication 'ATAPUtilities' } |
                Should -Throw '*not explicitly admitted*'
        }

        It 'blocks deployment when the database role audit reports drift' {
            Remove-Item Function:\Get-SqlServiceLoginGrantTarget -ErrorAction SilentlyContinue
            function global:Get-SqlServiceLoginGrantTarget {
                param([Parameter(ValueFromRemainingArguments)]$a)
                $null = $a
                [PSCustomObject]@{
                    DatabaseName = 'ATAPUtilities'
                    Include = $true
                    IsCompliant = $false
                    ExclusionReason = $null
                    DriftReason = 'MissingDbOwnerMembership'
                }
            }
            { Assert-DatabasePackageDeploymentPrincipal `
                -SqlInstance 'UTAT022\Integration' -ExpectedHostName 'UTAT022' `
                -ServiceAccount 'UTAT022\SvcBuildMaster' `
                -ExpectedAccountSid 'S-1-5-21-1-2-3-1001' `
                -AllowedInstanceName @('Integration') `
                -ApprovedDatabaseName @('ATAPUtilities') `
                -DatabaseApplication 'ATAPUtilities' } |
                Should -Throw '*audit FAILED*MissingDbOwnerMembership*'
        }
    }

    Context 'Invoke-DatabasePackageStageApply policy' {
        It 'fails closed when no connection secret is configured' {
            { Invoke-DatabasePackageStageApply -ContextDirectory $script:TempDir `
                -DatabasePackageId 'ATAPUtilities.Database' -DatabaseApplication 'ATAPUtilities' `
                -PackageVersion '1.0.0' -Tier 'Development' -NupkgPath $script:FakeNupkg `
                -ConnectionStringSecretName '' -TracePath $script:TracePath } |
                Should -Throw '*connection-string secret name is not configured*'
        }

        It 'fails closed when -SkipApply is set even with a secret configured' {
            { Invoke-DatabasePackageStageApply -ContextDirectory $script:TempDir `
                -DatabasePackageId 'ATAPUtilities.Database' -DatabaseApplication 'ATAPUtilities' `
                -PackageVersion '1.0.0' -Tier 'Development' -NupkgPath $script:FakeNupkg `
                -ConnectionStringSecretName 'dbConnectionString-x' -SkipApply -TracePath $script:TracePath } |
                Should -Throw '*-SkipApply cannot be used in a passing BuildMaster stage*'
        }

        It 'applies and writes the .applied marker when a secret is configured' {
            Mock Invoke-DatabasePackageTierApply {
                [PSCustomObject]@{ Applied = $true; Environment = 'Development'; SnapshotPath = $null }
            }
            Invoke-DatabasePackageStageApply -ContextDirectory $script:TempDir `
                -DatabasePackageId 'ATAPUtilities.Database' -DatabaseApplication 'ATAPUtilities' `
                -PackageVersion '1.0.0' -Tier 'Development' -NupkgPath $script:FakeNupkg `
                -ConnectionStringSecretName 'dbConnectionString-x' -TracePath $script:TracePath
            $marker = Join-Path $script:TempDir 'ATAPUtilities.Database.Development.applied.tmp'
            Test-Path -LiteralPath $marker -PathType Leaf | Should -BeTrue
            Should -Invoke Invoke-DatabasePackageTierApply -Times 1 -Exactly
        }

        It 'is idempotent: a second apply with an existing marker does not re-invoke the apply worker' {
            Mock Invoke-DatabasePackageTierApply {
                [PSCustomObject]@{ Applied = $true; Environment = 'Development'; SnapshotPath = $null }
            }
            # Marker from the previous test already exists for Development.
            Invoke-DatabasePackageStageApply -ContextDirectory $script:TempDir `
                -DatabasePackageId 'ATAPUtilities.Database' -DatabaseApplication 'ATAPUtilities' `
                -PackageVersion '1.0.0' -Tier 'Development' -NupkgPath $script:FakeNupkg `
                -ConnectionStringSecretName 'dbConnectionString-x' -TracePath $script:TracePath
            Should -Invoke Invoke-DatabasePackageTierApply -Times 0 -Exactly
        }
    }

    Context 'Invoke-DatabasePackageTierRehearsal enforcement' {
        It 'throws (blocks Experimental apply or later promotion) when rehearsal reports Success=$false' {
            # Mock the resolved wrapper binding; a global stub is shadowed by BeforeAll's source definition.
            Mock Invoke-DatabasePackageRehearsal {
                [PSCustomObject]@{ Success = $false; ValidateOutput = 'boom' }
            }
            Mock Expand-DatabaseChangePackage { throw 'Unexpected package expansion in rehearsal-result unit test' }
            { Invoke-DatabasePackageTierRehearsal -NupkgPath $script:FakeNupkg `
                -Application 'ATAPUtilities' -Tier 'Development' -BuildId '123' `
                -ConnectionStringSecretName 'dbConnectionString-x' } | Should -Throw '*rehearsal FAILED*'
            Should -Invoke Invoke-DatabasePackageRehearsal -Times 1 -Exactly -Scope It
            Should -Invoke Expand-DatabaseChangePackage -Times 0 -Exactly -Scope It
        }

        It 'returns the result (allows promotion) when the rehearsal reports Success=$true' {
            Mock Invoke-DatabasePackageRehearsal {
                [PSCustomObject]@{ Success = $true; ElapsedSeconds = 1 }
            }
            Mock Expand-DatabaseChangePackage { throw 'Unexpected package expansion in rehearsal-result unit test' }
            $r = Invoke-DatabasePackageTierRehearsal -NupkgPath $script:FakeNupkg `
                -Application 'ATAPUtilities' -Tier 'Development' -BuildId '123' `
                -ConnectionStringSecretName 'dbConnectionString-x'
            @($r).Count | Should -Be 1
            $r.Success | Should -BeTrue
            Should -Invoke Invoke-DatabasePackageRehearsal -Times 1 -Exactly -Scope It
            Should -Invoke Expand-DatabaseChangePackage -Times 0 -Exactly -Scope It
        }
    }
}

# Helper-only tests: compile named AST function definitions, never the stage entry script.
BeforeAll {
    $tokens580 = $null; $errors580 = $null
    $ast580 = [Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$tokens580, [ref]$errors580)
    if ($errors580.Count) { throw 'Stage source parse failed' }
    foreach ($name580 in @('Get-DatabasePackageExpectedCatalogParameters', 'Get-DatabasePackageFixtureRehearsalParameters', 'Invoke-DatabasePackageTierRehearsal',
        'Invoke-DatabasePackageTierApply', 'Invoke-DatabasePackageStageApply',
        'Get-DatabaseTierEnvironment', 'Get-DatabasePackageApplyMarkerPath', 'Add-DatabasePackagePublishTrace')) {
        $nodes580 = @($ast580.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name580 }, $true))
        if ($nodes580.Count -ne 1) { throw 'Expected exactly one helper definition' }
        . ([scriptblock]::Create($nodes580[0].Extent.Text))
    }
    $db580 = Join-Path $script:PlansDir '../../ATAP.Utilities.DatabaseManagement.Powershell/public'
    foreach ($file580 in @('Invoke-DatabasePackageRehearsal.ps1', 'Invoke-Flyway.ps1',
        'Expand-DatabaseChangePackage.ps1', 'Get-DatabasePackageManifest.ps1')) {
        $astDependency580 = [Management.Automation.Language.Parser]::ParseFile((Join-Path $db580 $file580), [ref]$tokens580, [ref]$errors580)
        if ($errors580.Count -or @($astDependency580.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count) {
            throw 'Unexpected executable dependency source'
        }
        foreach ($definition580 in $astDependency580.EndBlock.Statements) { . ([scriptblock]::Create($definition580.Extent.Text)) }
    }
    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
        function Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }
}

Describe 'Selected immutable database catalog maps (580)' -Tag 'Unit' {
    BeforeEach {
        $script:seen580 = $null
        Mock Write-PSFMessage {}
        Mock Test-Path { $true }
        Mock Expand-DatabaseChangePackage { 'D:/ATAPArtifacts/mock580-expanded' }
        Mock Get-DatabasePackageManifest { [pscustomobject]@{ dbChangeUnit = 'ATAPUtilities.Database'; appVersion = 'fixture' } }
        Mock Remove-Item {}
        Mock Set-Content { throw 'Unexpected marker write' }
        Mock Add-DatabasePackagePublishTrace {}
        Mock Invoke-DatabasePackageRehearsal {
            $script:seen580 = @{} + $PesterBoundParameters
            [pscustomobject]@{ Success = $true }
        }
        Mock Invoke-Flyway {
            $script:seen580 = @{} + $PesterBoundParameters
            [pscustomobject]@{ Success = $true }
        }
    }

    It 'selects the exact tuple on first capture and matching resume' -ForEach @(
        @{ Captured = $null }
        @{ Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = '' } }
    ) {
        $map = Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication ATAPUtilities -DatabasePackageId ATAPUtilities.Database -CapturedContext $Captured
        $map.Count | Should -Be 1
        $map.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities'
    }

    It 'omits bindings for unrelated tuple <Label>' -ForEach @(
        @{ Label = 'application'; App = 'Other'; Id = 'Other.Database'; Stream = '' }
        @{ Label = 'stream'; App = 'ATAPUtilities'; Id = 'ATAPUtilities.Other.Database'; Stream = 'Other' }
        @{ Label = 'case'; App = 'ataputilities'; Id = 'ATAPUtilities.Database'; Stream = '' }
        @{ Label = 'other package'; App = 'ATAPUtilities'; Id = 'Other.Database'; Stream = '' }
    ) {
        (Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication $App -DatabasePackageId $Id -DatabaseStream $Stream).Count | Should -Be 0
    }

    It 'refuses incomplete or changed selected captured identity' -ForEach @(
        @{ Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database' } }
        @{ Captured = [pscustomobject]@{ DatabaseApplication = 'Other'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = '' } }
    ) {
        { Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication ATAPUtilities -DatabasePackageId ATAPUtilities.Database -CapturedContext $Captured } | Should -Throw '*Captured database identity*'
    }

    It 'cannot turn a selected capture into an unrelated tuple' {
        $capture = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = '' }
        { Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication Other -DatabasePackageId Other.Database -CapturedContext $capture } | Should -Throw '*identity changed*'
    }

    It 'binds rehearsal target and exact ordered history' {
        Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 580 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion fixture -Confirm:$false | Out-Null
        $script:seen580.ExpectedSourceDatabaseName | Should -BeExactly 'ATAPUtilities'
        ($script:seen580.FlywayAdditionalArgs -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history'
    }

    It 'keeps generic rehearsal keys omitted' {
        Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application Other -Tier Experimental -BuildId 580 -ConnectionStringSecretName Test.Secret -Confirm:$false | Out-Null
        $script:seen580.ContainsKey('ExpectedSourceDatabaseName') | Should -BeFalse
        $script:seen580.ContainsKey('FlywayAdditionalArgs') | Should -BeFalse
    }

    It 'binds apply target history and empty shared location' {
        Invoke-DatabasePackageTierApply -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application ATAPUtilities -DatabasePackageId ATAPUtilities.Database -PackageVersion fixture -Tier Experimental -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -Confirm:$false | Out-Null
        $script:seen580.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities'
        ($script:seen580.FlywayAdditionalArgs -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history'
        $script:seen580.ContainsKey('FlywaySharedSqlMigrationsPath') | Should -BeTrue
        $script:seen580.FlywaySharedSqlMigrationsPath | Should -BeExactly ''
    }

    It 'keeps generic apply keys omitted' {
        Invoke-DatabasePackageTierApply -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application Other -DatabasePackageId Other.Database -PackageVersion fixture -Tier Experimental -ConnectionStringSecretName Test.Secret -Confirm:$false | Out-Null
        foreach ($key in @('ExpectedDatabaseName', 'FlywayAdditionalArgs', 'FlywaySharedSqlMigrationsPath')) { $script:seen580.ContainsKey($key) | Should -BeFalse }
    }

    It 'refuses wrong expected application before rehearsal or apply effects' {
        { Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application Other -Tier Experimental -BuildId 580 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -Confirm:$false } | Should -Throw '*Expected rehearsal catalog*'
        { Invoke-DatabasePackageTierApply -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application Other -DatabasePackageId Other.Database -PackageVersion fixture -Tier Experimental -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -Confirm:$false } | Should -Throw '*Expected apply catalog*'
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
        Should -Invoke Expand-DatabaseChangePackage -Times 0 -Exactly -Scope It
        Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
    }

    It 'does not invoke rehearsal or native helper under WhatIf' {
        Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 580 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion fixture -WhatIf
        Invoke-DatabasePackageTierApply -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -Application ATAPUtilities -DatabasePackageId ATAPUtilities.Database -PackageVersion fixture -Tier Experimental -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -WhatIf
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
        Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
    }

    It 'refuses mismatched stage expectation even when marker already exists' {
        { Invoke-DatabasePackageStageApply -ContextDirectory 'D:/ATAPArtifacts/mock580' -DatabasePackageId Other.Database -DatabaseApplication Other -PackageVersion fixture -Tier Experimental -NupkgPath 'D:/ATAPArtifacts/mock580.nupkg' -ConnectionStringSecretName Test.Secret -TracePath 'D:/ATAPArtifacts/mock580/trace.log' -ExpectedDatabaseName ATAPUtilities -Confirm:$false } | Should -Throw '*Expected stage catalog*'
        Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
        Should -Invoke Set-Content -Times 0 -Exactly -Scope It
    }
}

Describe 'Stage apply internal binding bridge (580)' -Tag 'Unit' {
    BeforeEach {
        $script:bridge580 = $null
        Mock Write-PSFMessage {}
        Mock Test-Path { $LiteralPath -like '*.nupkg' }
        Mock Add-DatabasePackagePublishTrace {}
        Mock Set-Content { throw 'Unexpected marker write' }
        Mock Invoke-DatabasePackageTierApply {
            $script:bridge580 = @{} + $PesterBoundParameters
            [pscustomobject]@{ Applied = $false }
        }
    }
    It 'forwards bound expectation only for selected bridge <Selected>' -ForEach @(
        @{ Selected = $true }; @{ Selected = $false }
    ) {
        $params580 = @{
            ContextDirectory = 'D:/ATAPArtifacts/mock580'
            DatabasePackageId = 'ATAPUtilities.Database'; DatabaseApplication = 'ATAPUtilities'
            PackageVersion = 'fixture'; Tier = 'Experimental'
            NupkgPath = 'D:/ATAPArtifacts/mock580.nupkg'; ConnectionStringSecretName = 'Test.Secret'
            TracePath = 'D:/ATAPArtifacts/mock580/trace.log'
        }
        if ($Selected) { $params580.ExpectedDatabaseName = 'ATAPUtilities' }
        Invoke-DatabasePackageStageApply @params580 -Confirm:$false
        $script:bridge580.ContainsKey('ExpectedDatabaseName') | Should -Be $Selected
        if ($Selected) { $script:bridge580.ExpectedDatabaseName | Should -BeExactly 'ATAPUtilities' }
        Should -Invoke Invoke-DatabasePackageTierApply -Times 1 -Exactly -Scope It
        Should -Invoke Set-Content -Times 0 -Exactly -Scope It
    }
}

Describe 'Resume identity refusal before generic fallback (591)' -Tag 'Unit' {
    It 'refuses malformed captured stream for current tuple <Label>' -ForEach @(
        @{ Label = 'missing/space'; Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database' }; App = 'ATAPUtilities'; Id = 'ATAPUtilities.Database'; Stream = ' ' }
        @{ Label = 'null/space'; Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = $null }; App = 'ATAPUtilities'; Id = 'ATAPUtilities.Database'; Stream = ' ' }
        @{ Label = 'missing/changed'; Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database' }; App = 'Other'; Id = 'Other.Database'; Stream = '' }
        @{ Label = 'null/changed'; Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = $null }; App = 'Other'; Id = 'Other.Database'; Stream = '' }
        @{ Label = 'unrelated/null'; Captured = [pscustomobject]@{ DatabaseApplication = 'Other'; DatabasePackageId = 'Other.Database'; DatabaseStream = $null }; App = 'Other'; Id = 'Other.Database'; Stream = '' }
        @{ Label = 'unrelated/nonstring'; Captured = [pscustomobject]@{ DatabaseApplication = 'Other'; DatabasePackageId = 'Other.Database'; DatabaseStream = 0 }; App = 'Other'; Id = 'Other.Database'; Stream = '' }
    ) {
        { Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication $App -DatabasePackageId $Id -DatabaseStream $Stream -CapturedContext $Captured } |
            Should -Throw '*Captured database identity is incomplete*'
    }

    It 'refuses whitespace-only selected stream before fallback <Label>' -ForEach @(
        @{ Label = 'first/space'; Stream = ' '; Captured = $null }
        @{ Label = 'resume/tab'; Stream = [string][char]9; Captured = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = '' } }
    ) {
        { Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication ATAPUtilities -DatabasePackageId ATAPUtilities.Database -DatabaseStream $Stream -CapturedContext $Captured } |
            Should -Throw '*whitespace-only stream*'
    }

    It 'refuses another missing captured field even for unrelated current tuple' -ForEach @(
        @{ Captured = [pscustomobject]@{ DatabasePackageId = 'Other.Database'; DatabaseStream = '' } }
        @{ Captured = [pscustomobject]@{ DatabaseApplication = 'Other'; DatabaseStream = '' } }
    ) {
        { Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication Other -DatabasePackageId Other.Database -CapturedContext $Captured } |
            Should -Throw '*Captured database identity is incomplete*'
    }

    It 'keeps a valid unrelated captured tuple omitted' {
        $capture591 = [pscustomobject]@{ DatabaseApplication = 'Other'; DatabasePackageId = 'Other.Database'; DatabaseStream = '' }
        (Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication Other -DatabasePackageId Other.Database -CapturedContext $capture591).Count | Should -Be 0
    }

    It 'keeps true first-run null capture supported for unrelated tuple' {
        (Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication Other -DatabasePackageId Other.Database -CapturedContext $null).Count | Should -Be 0
    }

    It 'places identity refusal before context writes audit package and marker commands' {
        $tokens591 = $null; $errors591 = $null
        $ast591 = [Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$tokens591, [ref]$errors591)
        $errors591.Count | Should -Be 0
        $main591 = @($ast591.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Invoke-DatabasePackageBuildMasterStage' }, $true))
        $main591.Count | Should -Be 1
        $selection591 = @($main591[0].FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -ceq 'Get-DatabasePackageExpectedCatalogParameters' }, $true))
        $selection591.Count | Should -Be 1
        $later591 = @($main591[0].FindAll({ param($n)
            $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @(
                'Write-BuildMasterRunContextJson', 'Assert-DatabasePackageDeploymentPrincipal',
                'New-DatabaseChangePackage', 'Set-DatabasePackageStageCompleted', 'Invoke-DatabasePackageStageApply')
        }, $true))
        $later591.Count | Should -BeGreaterThan 0
        foreach ($command591 in $later591) { $command591.Extent.StartOffset | Should -BeGreaterThan $selection591[0].Extent.StartOffset }
    }
}

Describe 'Captured selected whitespace alias (591)' -Tag 'Unit' {
    It 'refuses captured whitespace even with current tuple <App>' -ForEach @(
        @{ App = 'Other'; Id = 'Other.Database' }
        @{ App = 'ATAPUtilities'; Id = 'ATAPUtilities.Database' }
    ) {
        $capture591 = [pscustomobject]@{ DatabaseApplication = 'ATAPUtilities'; DatabasePackageId = 'ATAPUtilities.Database'; DatabaseStream = ' ' }
        { Get-DatabasePackageExpectedCatalogParameters -DatabaseApplication $App -DatabasePackageId $Id -CapturedContext $capture591 } |
            Should -Throw '*Captured database identity*whitespace-only stream*'
    }
}

Describe 'Selected stage fixture forwarding (631)' -Tag 'Unit' {
    BeforeEach {
        $script:seen631 = $null
        Mock Write-PSFMessage {}
        Mock Test-Path { $true }
        Mock Invoke-DatabasePackageRehearsal {
            $script:seen631 = @{} + $PesterBoundParameters
            [pscustomobject]@{ Success = $true }
        }
        Mock Invoke-Flyway { throw 'Unexpected native path' }
        Mock Expand-DatabaseChangePackage { throw 'Unexpected package expansion' }
        Mock Set-Content { throw 'Unexpected state write' }
    }

    It 'forwards exact source fixture pair and identity for <Label>' -ForEach @(
        @{ Label = 'Experimental fresh'; Tier631 = 'Experimental'; Build631 = 'fresh631' }
        @{ Label = 'Experimental resume'; Tier631 = 'Experimental'; Build631 = 'resume631' }
        @{ Label = 'promotion'; Tier631 = 'Development'; Build631 = 'promote631' }
    ) {
        Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application ATAPUtilities -Tier $Tier631 -BuildId $Build631 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion '1.2.3-immutable631' -Confirm:$false | Out-Null
        $script:seen631.LoginFixturePath | Should -BeExactly (Join-Path $script:fixtureSource631 'Database/Verify/AceCommander/Verify_Login_V00160_ExactCatalog.sql')
        $script:seen631.DecryptFixturePath | Should -BeExactly (Join-Path $script:fixtureSource631 'Database/Verify/AceCommander/Verify_Decrypt_V00170_ExactCatalog.sql')
        $script:seen631.ExpectedPackageName | Should -BeExactly 'ATAPUtilities.Database'
        $script:seen631.ExpectedPackageVersion | Should -BeExactly '1.2.3-immutable631'
        $script:seen631.ExpectedSourceDatabaseName | Should -BeExactly 'ATAPUtilities'
        $script:seen631.BuildId | Should -BeExactly ($Build631 + '-' + $Tier631)
        ($script:seen631.FlywayAdditionalArgs -join '|') | Should -BeExactly '-defaultSchema=dbo|-table=flyway_schema_history'
        $script:seen631.ContainsKey('SourcePath') | Should -BeFalse
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 1 -Exactly -Scope It
        Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
    }

    It 'keeps all fixture keys omitted for generic rehearsal' {
        Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application Other -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret -Confirm:$false | Out-Null
        foreach ($key631 in @('ExpectedSourceDatabaseName', 'LoginFixturePath', 'DecryptFixturePath', 'ExpectedPackageName', 'ExpectedPackageVersion', 'FlywayAdditionalArgs')) {
            $script:seen631.ContainsKey($key631) | Should -BeFalse
        }
    }

    It 'refuses raw package version <Label> before effects' -ForEach @(
        @{ Label = 'missing'; RawVersion = $null }
        @{ Label = 'numeric'; RawVersion = 631 }
        @{ Label = 'false'; RawVersion = $false }
        @{ Label = 'array'; RawVersion = @('fixture') }
        @{ Label = 'empty'; RawVersion = '' }
        @{ Label = 'padded'; RawVersion = 'fixture ' }
    ) {
        { Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion $RawVersion -Confirm:$false } | Should -Throw '*actual nonempty trim-exact package version*'
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
        Should -Invoke Test-Path -Times 0 -Exactly -Scope It
        Should -Invoke Invoke-Flyway -Times 0 -Exactly -Scope It
        Should -Invoke Set-Content -Times 0 -Exactly -Scope It
    }

    It 'refuses invalid source root <Label>' -ForEach @(
        @{ Label = 'missing'; Root631 = '' }
        @{ Label = 'relative'; Root631 = 'relative631' }
        @{ Label = 'padded'; Root631 = ' D:/ATAPArtifacts/mock631' }
    ) {
        { Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $Root631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion fixture -Confirm:$false } | Should -Throw '*absolute trim-exact SourcePath*'
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
        Should -Invoke Test-Path -Times 0 -Exactly -Scope It
    }

    It 'refuses fixture-only metadata without catalog selection <Key631>' -ForEach @(
        @{ Key631 = 'SourcePath'; Value631 = 'D:/ATAPArtifacts/mock631' }
        @{ Key631 = 'ExpectedPackageName'; Value631 = 'ATAPUtilities.Database' }
        @{ Key631 = 'ExpectedPackageVersion'; Value631 = 'fixture' }
    ) {
        $extra631 = @{}; $extra631[$Key631] = $Value631
        { Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application Other -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret @extra631 -Confirm:$false } | Should -Throw '*requires explicit ExpectedDatabaseName*'
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
        Should -Invoke Test-Path -Times 0 -Exactly -Scope It
    }

    It 'refuses selected missing or changed package identity <Identity631>' -ForEach @(
        @{ Identity631 = $null }; @{ Identity631 = 'Other.Database' }; @{ Identity631 = 'ataputilities.Database' }
    ) {
        { Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName $Identity631 -ExpectedPackageVersion fixture -Confirm:$false } | Should -Throw '*exact existing package identity*'
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
    }

    It 'does not bind private source or call wrapper under selected WhatIf' {
        Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion fixture -WhatIf
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
        Should -Invoke Test-Path -Times 1 -Exactly -Scope It
    }

    It 'requires explicit same-root private definition binding before wrapper' {
        Mock Test-Path { $LiteralPath -like '*.nupkg' }
        { Invoke-DatabasePackageTierRehearsal -NupkgPath 'D:/ATAPArtifacts/mock631.nupkg' -Application ATAPUtilities -Tier Experimental -BuildId 631 -ConnectionStringSecretName Test.Secret -ExpectedDatabaseName ATAPUtilities -SourcePath $script:fixtureSource631 -ExpectedPackageName ATAPUtilities.Database -ExpectedPackageVersion fixture -Confirm:$false } | Should -Throw '*source helper is missing*'
        Should -Invoke Invoke-DatabasePackageRehearsal -Times 0 -Exactly -Scope It
    }

    It 'wires fixture splat only to all3 main rehearsal calls while preserving7 catalog splats' {
        $tokens631 = $null; $errors631 = $null
        $ast631 = [Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$tokens631, [ref]$errors631)
        $errors631.Count | Should -Be 0
        $calls631 = @($ast631.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Invoke-DatabasePackageTierRehearsal', 'Invoke-DatabasePackageStageApply', 'Invoke-DatabasePackageTierApply') }, $true))
        $calls631.Count | Should -Be 7
        foreach ($call631 in $calls631) {
            @($call631.CommandElements | Where-Object { $_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.Splatted -and $_.VariablePath.UserPath -ceq 'expectedCatalogParameters' }).Count | Should -Be 1
            $fixtureCount631 = @($call631.CommandElements | Where-Object { $_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.Splatted -and $_.VariablePath.UserPath -ceq 'fixtureRehearsalParameters' }).Count
            if ($call631.GetCommandName() -ceq 'Invoke-DatabasePackageTierRehearsal') { $fixtureCount631 | Should -Be 1 }
            else { $fixtureCount631 | Should -Be 0 }
        }
    }

    It 'validates raw context version before its cast and audit or package actions' {
        $tokens631 = $null; $errors631 = $null
        $ast631 = [Management.Automation.Language.Parser]::ParseFile($script:RunnerPath, [ref]$tokens631, [ref]$errors631)
        $main631 = @($ast631.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Invoke-DatabasePackageBuildMasterStage' }, $true))[0]
        $guards631 = @($main631.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -ceq 'Get-DatabasePackageFixtureRehearsalParameters' }, $true))
        $guards631.Count | Should -Be 2
        $guards631[0].Extent.Text | Should -Match '-ExpectedPackageVersion\s+\$context\.ResolvedPackageVersion'
        $guards631[1].Extent.Text | Should -Match '-ExpectedPackageVersion\s+\$existingContext\.ResolvedVersion'
        $cast631 = @($main631.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Extent.Text -ceq '$resolvedVersion = [string]$context.ResolvedPackageVersion' }, $true))[0]
        $guards631[0].Extent.StartOffset | Should -BeLessThan $cast631.Extent.StartOffset
        $effects631 = @($main631.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Assert-DatabasePackageDeploymentPrincipal', 'Write-BuildMasterRunContextJson', 'New-DatabaseChangePackage', 'Invoke-DatabasePackageTierRehearsal', 'Invoke-DatabasePackageStageApply') }, $true))
        foreach ($effect631 in $effects631) { $effect631.Extent.StartOffset | Should -BeGreaterThan $guards631[1].Extent.StartOffset }
    }
}
