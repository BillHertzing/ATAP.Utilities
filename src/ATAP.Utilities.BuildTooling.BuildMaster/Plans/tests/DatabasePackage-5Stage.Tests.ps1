# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ static-contract tests for V4-E08 / DBA2-T03: the
# DatabaseChangePackage-5Stage OtterScript plan must be a thin runner plan,
# and the runner script must preserve the contracts the plan depends on.

BeforeAll {
    $script:PlansDir   = Join-Path $PSScriptRoot '..'
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
        $script:PlanText | Should -Match '-NoProfile\s+-File\s+"\$InvokeDatabasePackageStageScript"'
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
            function global:Invoke-DatabasePackageRehearsal {
                param([Parameter(ValueFromRemainingArguments)]$a)
                $null = $a
                [PSCustomObject]@{ Success = $false; ValidateOutput = 'boom' }
            }
            { Invoke-DatabasePackageTierRehearsal -NupkgPath $script:FakeNupkg `
                -Application 'ATAPUtilities' -Tier 'Development' -BuildId '123' `
                -ConnectionStringSecretName 'dbConnectionString-x' } | Should -Throw '*rehearsal FAILED*'
            Remove-Item Function:\Invoke-DatabasePackageRehearsal -ErrorAction SilentlyContinue
        }

        It 'returns the result (allows promotion) when the rehearsal reports Success=$true' {
            function global:Invoke-DatabasePackageRehearsal {
                param([Parameter(ValueFromRemainingArguments)]$a)
                $null = $a
                [PSCustomObject]@{ Success = $true; ElapsedSeconds = 1 }
            }
            $r = Invoke-DatabasePackageTierRehearsal -NupkgPath $script:FakeNupkg `
                -Application 'ATAPUtilities' -Tier 'Development' -BuildId '123' `
                -ConnectionStringSecretName 'dbConnectionString-x'
            $r.Success | Should -BeTrue
            Remove-Item Function:\Invoke-DatabasePackageRehearsal -ErrorAction SilentlyContinue
        }
    }
}
