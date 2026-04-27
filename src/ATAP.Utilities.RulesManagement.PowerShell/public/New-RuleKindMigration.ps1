<#
.SYNOPSIS
    Generates a Flyway migration SQL file that inserts a new PrimitiveLanguageKind.
.DESCRIPTION
    Scaffolds the next V{n}__Add_{KindName}Kind.sql migration by:
      1. Reading all existing V*.sql files in MigrationsPath to resolve the next
         version number.
      2. Building parameterised INSERT statements for ATAPUtilities.PrimitiveLanguageKind,
         ATAPUtilities.RulePrimitive, ATAPUtilities.RulePrimitiveComposition, and
         ATAPUtilities.RulePrimitiveInput.
      3. Wrapping everything in BEGIN TRANSACTION / COMMIT / ROLLBACK ON ERROR.

    Supports -WhatIf: when supplied, writes the SQL to stdout and returns the SQL
    string without touching the filesystem.

    The caller is responsible for running Test-FlywayMigrationDryRun before allowing
    the file to be committed, and for invoking 'flyway migrate' after human review.
.PARAMETER KindDefinition
    PSCustomObject produced by the agent with the following required properties:
      KindName (string), LanguageName (string), Description (string),
      GrammarFilePath (string), Primitives (PSCustomObject[]),
      Compositions (PSCustomObject[]), Inputs (PSCustomObject[]).
.PARAMETER MigrationsPath
    Path to the folder that holds the existing V*.sql migration files.
    The next version number is derived from the highest existing V{n} prefix + 1.
.OUTPUTS
    PSCustomObject with FilePath (string|null), Sql (string), VersionNumber (int).
    When -WhatIf is used FilePath is $null and Sql contains the full migration text.
.EXAMPLE
    New-RuleKindMigration -KindDefinition $def -MigrationsPath 'C:\repo\migrations'
.EXAMPLE
    New-RuleKindMigration -KindDefinition $def -MigrationsPath 'C:\repo\migrations' -WhatIf
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function New-RuleKindMigration {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSCustomObject] $KindDefinition,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $MigrationsPath
    )

    BEGIN {
        $fn = 'New-RuleKindMigration'
        $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        try {
            if (-not (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue)) {
                . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
            }
        }
        catch {
            $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }

        $KindDefinition  = Get-PVal -ParameterName 'KindDefinition'  -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.KindDefinition'  -DefaultValue $KindDefinition
        $MigrationsPath  = Get-PVal -ParameterName 'MigrationsPath'  -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.MigrationsPath'  -DefaultValue $MigrationsPath

        foreach ($required in @('KindName','LanguageName','Description','GrammarFilePath')) {
            if ([string]::IsNullOrWhiteSpace($KindDefinition.$required)) {
                throw "KindDefinition.$required is required and was not supplied"
            }
        }
        if (-not (Test-Path -Path $MigrationsPath -PathType Container)) {
            throw "MigrationsPath not found or is not a directory: $MigrationsPath"
        }
    }

    PROCESS {
        try {
            # Resolve next version number
            $existingVersions = Get-ChildItem -Path $MigrationsPath -Filter 'V*.sql' |
                ForEach-Object {
                    if ($_.Name -match '^V(\d+)__') { [int]$Matches[1] }
                } | Sort-Object
            $nextVersion = if ($existingVersions.Count -gt 0) { ($existingVersions[-1]) + 1 } else { 1 }
            $fileName    = "V${nextVersion}__Add_$($KindDefinition.KindName)Kind.sql"
            $outputPath  = Join-Path $MigrationsPath $fileName

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Next version: $nextVersion | Output: $outputPath"

            # ── Build SQL ────────────────────────────────────────────────────
            $sb = [System.Text.StringBuilder]::new()
            $nl = [System.Environment]::NewLine

            $kindName        = $KindDefinition.KindName.Replace("'","''")
            $languageName    = $KindDefinition.LanguageName.Replace("'","''")
            $description     = $KindDefinition.Description.Replace("'","''")
            $grammarFilePath = $KindDefinition.GrammarFilePath.Replace("'","''")

            [void]$sb.AppendLine("-- Migration: $fileName")
            [void]$sb.AppendLine("-- Generated by New-RuleKindMigration")
            [void]$sb.AppendLine("-- DO NOT EDIT — regenerate via the new-rule-kind skill if changes are needed")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('BEGIN TRANSACTION;')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('BEGIN TRY')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('    -- 1. Insert the Kind')
            [void]$sb.AppendLine("    INSERT INTO ATAPUtilities.PrimitiveLanguageKind (KindName, LanguageName, Description, GrammarFilePath)")
            [void]$sb.AppendLine("    VALUES ('$kindName', '$languageName', '$description', '$grammarFilePath');")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("    DECLARE @KindId INT = SCOPE_IDENTITY();")
            [void]$sb.AppendLine('')

            # 2. Primitives
            if ($KindDefinition.Primitives -and $KindDefinition.Primitives.Count -gt 0) {
                [void]$sb.AppendLine('    -- 2. Insert Primitives')
                foreach ($prim in $KindDefinition.Primitives) {
                    $pname    = $prim.PrimitiveName.Replace("'","''")
                    $symbol   = $prim.BNFSymbol.Replace("'","''")
                    $dtype    = $prim.DataType.Replace("'","''")
                    $terminal = if ($prim.IsTerminal) { '1' } else { '0' }
                    [void]$sb.AppendLine("    INSERT INTO ATAPUtilities.RulePrimitive (KindId, PrimitiveName, BNFSymbol, DataType, IsTerminal)")
                    [void]$sb.AppendLine("    VALUES (@KindId, '$pname', '$symbol', '$dtype', $terminal);")
                    [void]$sb.AppendLine("    DECLARE @Prim_$($prim.PrimitiveName -replace '[^A-Za-z0-9]','_') INT = SCOPE_IDENTITY();")
                }
                [void]$sb.AppendLine('')
            }

            # 3. Compositions
            if ($KindDefinition.Compositions -and $KindDefinition.Compositions.Count -gt 0) {
                [void]$sb.AppendLine('    -- 3. Insert Compositions (ordered by Position)')
                $sortedComps = $KindDefinition.Compositions | Sort-Object Position
                foreach ($comp in $sortedComps) {
                    $primVarName = "@Prim_$($comp.PrimitiveName -replace '[^A-Za-z0-9]','_')"
                    $cardinality = $comp.Cardinality.Replace("'","''")
                    $isOptional  = if ($comp.IsOptional) { '1' } else { '0' }
                    [void]$sb.AppendLine("    INSERT INTO ATAPUtilities.RulePrimitiveComposition (KindId, PrimitiveId, Position, IsOptional, Cardinality)")
                    [void]$sb.AppendLine("    VALUES (@KindId, $primVarName, $($comp.Position), $isOptional, '$cardinality');")
                }
                [void]$sb.AppendLine('')
            }

            # 4. Inputs
            if ($KindDefinition.Inputs -and $KindDefinition.Inputs.Count -gt 0) {
                [void]$sb.AppendLine('    -- 4. Insert RulePrimitiveInputs')
                foreach ($inp in $KindDefinition.Inputs) {
                    $primVarName = "@Prim_$($inp.PrimitiveName -replace '[^A-Za-z0-9]','_')"
                    $inputName   = $inp.InputName.Replace("'","''")
                    $inputType   = $inp.InputType.Replace("'","''")
                    $isRequired  = if ($inp.IsRequired) { '1' } else { '0' }
                    $defaultVal  = if ($null -eq $inp.DefaultValue) { 'NULL' } else { "'$($inp.DefaultValue.Replace("'","''"))'" }
                    [void]$sb.AppendLine("    INSERT INTO ATAPUtilities.RulePrimitiveInput (PrimitiveId, InputName, InputType, IsRequired, DefaultValue)")
                    [void]$sb.AppendLine("    VALUES ($primVarName, '$inputName', '$inputType', $isRequired, $defaultVal);")
                }
                [void]$sb.AppendLine('')
            }

            [void]$sb.AppendLine('    COMMIT TRANSACTION;')
            [void]$sb.AppendLine('END TRY')
            [void]$sb.AppendLine('BEGIN CATCH')
            [void]$sb.AppendLine('    ROLLBACK TRANSACTION;')
            [void]$sb.AppendLine('    THROW;')
            [void]$sb.AppendLine('END CATCH;')

            $sql = $sb.ToString()
            # ── End SQL build ────────────────────────────────────────────────

            if ($PSCmdlet.ShouldProcess($outputPath, 'Write Flyway migration file')) {
                [System.IO.File]::WriteAllText($outputPath, $sql, [System.Text.Encoding]::UTF8)
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Migration written: $outputPath"

                return [PSCustomObject]@{
                    FilePath      = $outputPath
                    Sql           = $sql
                    VersionNumber = $nextVersion
                }
            }
            else {
                # -WhatIf path: return SQL only, no file written
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "WhatIf: would write $outputPath ($($sql.Length) chars)"
                return [PSCustomObject]@{
                    FilePath      = $null
                    Sql           = $sql
                    VersionNumber = $nextVersion
                }
            }
        }
        catch {
            $errorMessage = "New-RuleKindMigration failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
