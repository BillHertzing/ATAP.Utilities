<#
.SYNOPSIS
Performs source-static validation of the RDB-510 reference-catalog migration.

.DESCRIPTION
Checks the assembled migration's fragment closure, gates, generated exact-source
metadata, and (when supplied) SQL Server 2022 ScriptDom parse result.  This
tool makes no SQL connection and never performs a database mutation.
#>
function Test-Rdb510SeedMigration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,

        [Parameter()]
        [string] $MigrationPath,

        [Parameter()]
        [string] $ScriptDomAssemblyPath
    )

    begin {
        $fn = 'Test-Rdb510SeedMigration'
        $mn = 'ATAP.Utilities.Database.Tools'
        if ([string]::IsNullOrWhiteSpace($MigrationPath)) {
            $MigrationPath = Join-Path $RepositoryRoot 'Database\Flyway\SQL\V00020__Seed_RRSBS_Reference_Catalog.sql'
        }
        $requiredFragments = @(
            'RDB-500A__CSharp.sql', 'RDB-500B__PowerShell.sql',
            'RDB-500C__SQL-MSBuild.sql', 'RDB-500D__Path.sql',
            'RDB-500E__OtterScript.sql', 'RDB-500F__AgentText.sql',
            'RDB-500H__Markdown.sql', 'RDB-500I__ManimScene.sql',
            'RDB-500O__ExpertiseDomain.sql', 'RDB-500P__AttributionMetadata.sql'
        )
    }

    process {
        try {
            if (-not (Test-Path -LiteralPath $MigrationPath -PathType Leaf)) {
                throw "RDB-510 migration is absent: $MigrationPath"
            }
            $text = Get-Content -LiteralPath $MigrationPath -Raw -ErrorAction Stop
            $issues = [Collections.Generic.List[string]]::new()
            foreach ($fragment in $requiredFragments) {
                $marker = "/* BEGIN INTEGRATED FRAGMENT: $fragment */"
                $count = [regex]::Matches($text, [regex]::Escape($marker)).Count
                if ($count -ne 1) {
                    $issues.Add("Integrated fragment marker '$fragment' expected once; found $count.")
                }
            }
            foreach ($forbidden in @('RDB-500G', 'BillOfMaterials', 'PKIArtifact', 'LegalEntityFiling', 'FinancialLedger', 'GPX')) {
                if ($forbidden -eq 'RDB-500G') {
                    if ($text -notmatch 'RDB-500G ContentSummary is allocation-blocked and must remain zero-row') {
                        $issues.Add('The explicit RDB-500G zero-row guard is absent.')
                    }
                    continue
                }
                if ($text -notmatch "RuleKindCode\] IN \('BillOfMaterials', 'PKIArtifact', 'LegalEntityFiling', 'FinancialLedger', 'GPX'\)") {
                    $issues.Add('The policy-gated RuleKind exclusion guard is absent.')
                    break
                }
            }
            foreach ($requiredLiteral in @(
                'RDB-510 EntityType catalog must contain exactly 43 rows.',
                'RDB-510 source-artifact prerequisite count failed.',
                'RDB-510 must not seed ContentSummary rows.',
                'RDB-510 source-artifact version collision.'
            )) {
                if ($text -notlike "*$requiredLiteral*") {
                    $issues.Add("Required fail-closed assertion is absent: $requiredLiteral")
                }
            }
            $sourceRows = [regex]::Matches(
                $text,
                "\(N'(?<path>SolutionDocumentation/(?:grammers/[^']+\.grammar\.ebnf|Rules Compendium\.[^']+\.md))', '(?<normalized>[0-9a-f]{64})', '(?<bytes>[0-9a-f]{64})', (?<count>\d+), [01], '(?:none|lf|crlf|cr|mixed)', [01]\)"
            )
            if ($sourceRows.Count -ne 18) {
                $issues.Add("Expected 18 source-artifact version rows; found $($sourceRows.Count).")
            }
            $sourcePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($row in $sourceRows) {
                $path = $row.Groups['path'].Value
                if (-not $sourcePaths.Add($path)) {
                    $issues.Add("Duplicate source-artifact path '$path'.")
                    continue
                }
                $literalPath = Join-Path $RepositoryRoot $path
                if (-not (Test-Path -LiteralPath $literalPath -PathType Leaf)) {
                    $issues.Add("Referenced source-artifact is absent: $literalPath")
                    continue
                }
                $actualHash = (Get-FileHash -LiteralPath $literalPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actualHash -ne $row.Groups['normalized'].Value -or $actualHash -ne $row.Groups['bytes'].Value) {
                    $issues.Add("Source-artifact hash drift: $path")
                }
                if ((Get-Item -LiteralPath $literalPath).Length -ne [int64]$row.Groups['count'].Value) {
                    $issues.Add("Source-artifact byte-count drift: $path")
                }
            }

            $parseSucceeded = $null
            $parseErrors = @()
            if (-not [string]::IsNullOrWhiteSpace($ScriptDomAssemblyPath)) {
                if (-not (Test-Path -LiteralPath $ScriptDomAssemblyPath -PathType Leaf)) {
                    $issues.Add("ScriptDom assembly is absent: $ScriptDomAssemblyPath")
                } else {
                    if (-not ('Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser' -as [type])) {
                        Add-Type -LiteralPath $ScriptDomAssemblyPath -ErrorAction Stop
                    }
                    $errors = [Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]]::new()
                    $reader = [IO.StringReader]::new($text)
                    try {
                        $parser = [Microsoft.SqlServer.TransactSql.ScriptDom.TSql160Parser]::new($true)
                        $null = $parser.Parse($reader, [ref]$errors)
                    } finally {
                        $reader.Dispose()
                    }
                    $parseErrors = @($errors | ForEach-Object { "line $($_.Line), column $($_.Column): $($_.Message)" })
                    $parseSucceeded = $parseErrors.Count -eq 0
                    foreach ($error in $parseErrors) { $issues.Add("ScriptDom parse error: $error") }
                }
            }
            return [pscustomobject]@{
                MigrationPath = (Resolve-Path -LiteralPath $MigrationPath).Path
                MigrationSha256 = (Get-FileHash -LiteralPath $MigrationPath -Algorithm SHA256).Hash.ToLowerInvariant()
                RequiredFragments = $requiredFragments.Count
                SourceArtifactVersions = $sourceRows.Count
                SourceArtifactPaths = $sourcePaths.Count
                ScriptDomParseSucceeded = $parseSucceeded
                Issues = @($issues)
                Passed = $issues.Count -eq 0
            }
        } catch {
            if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
            }
            throw
        }
    }

    end {
    }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
    Test-Rdb510SeedMigration @args
}
