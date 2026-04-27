<#
.SYNOPSIS
    Appends a new Kind entry to the Rules Compendium markdown document.
.DESCRIPTION
    Locates the HTML marker <!-- rule-compendium-end --> in the target Compendium
    file and inserts a fully-formatted Kind section immediately before it. If the
    marker is absent the function throws rather than appending blindly.

    Supports -WhatIf: when supplied, the formatted section is returned in the output
    object without modifying the file.
.PARAMETER KindDefinition
    PSCustomObject produced by the agent, requiring: KindName, LanguageName,
    Description, GrammarFilePath, Primitives[], Compositions[].
.PARAMETER CompendiumPath
    Full path to the Rules Compendium .md file to update.
    Defaults to the value at global settings RulesManagement.CompendiumPath.
.OUTPUTS
    PSCustomObject with FilePath (string), InsertedSection (string), MarkerLine (int).
.EXAMPLE
    Add-RuleKindToCompendium -KindDefinition $def -CompendiumPath 'C:\repo\docs\RulesCompendium.CSharp.md'
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Add-RuleKindToCompendium {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSCustomObject] $KindDefinition,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $CompendiumPath
    )

    BEGIN {
        $fn = 'Add-RuleKindToCompendium'
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

        $KindDefinition = Get-PVal -ParameterName 'KindDefinition' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.KindDefinition' -DefaultValue $KindDefinition
        $CompendiumPath = Get-PVal -ParameterName 'CompendiumPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.CompendiumPath' -DefaultValue $CompendiumPath

        foreach ($required in @('KindName','LanguageName','Description')) {
            if ([string]::IsNullOrWhiteSpace($KindDefinition.$required)) {
                throw "KindDefinition.$required is required and was not supplied"
            }
        }
        if ([string]::IsNullOrWhiteSpace($CompendiumPath)) {
            throw 'CompendiumPath must be provided or set in global settings at RulesManagement.CompendiumPath'
        }
        if (-not (Test-Path -Path $CompendiumPath -PathType Leaf)) {
            throw "CompendiumPath not found: $CompendiumPath"
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "CompendiumPath: $CompendiumPath"
    }

    PROCESS {
        try {
            $lines  = [System.IO.File]::ReadAllLines($CompendiumPath, [System.Text.Encoding]::UTF8)
            $marker = '<!-- rule-compendium-end -->'
            $markerLine = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].Trim() -eq $marker) { $markerLine = $i; break }
            }
            if ($markerLine -lt 0) {
                throw "Required marker '$marker' not found in $CompendiumPath. Add it at the end of the last Kind entry."
            }

            # Check that the Kind does not already exist
            $existingHeader = "## $($KindDefinition.KindName)"
            $alreadyExists = $lines | Where-Object { $_.Trim() -eq $existingHeader }
            if ($alreadyExists) {
                throw "Kind '$($KindDefinition.KindName)' already exists in $CompendiumPath. Use a migration UPDATE instead."
            }

            # Build the section
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("## $($KindDefinition.KindName)")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("| Property | Value |")
            [void]$sb.AppendLine('|---|---|')
            [void]$sb.AppendLine("| **Language** | $($KindDefinition.LanguageName) |")
            [void]$sb.AppendLine("| **Grammar file** | \`$($KindDefinition.GrammarFilePath)\` |")
            [void]$sb.AppendLine("| **Added** | $(Get-Date -Format 'yyyy-MM-dd') |")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine($KindDefinition.Description)
            [void]$sb.AppendLine('')

            if ($KindDefinition.Primitives -and $KindDefinition.Primitives.Count -gt 0) {
                [void]$sb.AppendLine('### Primitives')
                [void]$sb.AppendLine('')
                [void]$sb.AppendLine('| Primitive | BNF Symbol | DataType | Terminal |')
                [void]$sb.AppendLine('|---|---|---|---|')
                foreach ($prim in ($KindDefinition.Primitives | Sort-Object PrimitiveName)) {
                    $terminal = if ($prim.IsTerminal) { '✓' } else { '' }
                    [void]$sb.AppendLine("| $($prim.PrimitiveName) | \`$($prim.BNFSymbol)\` | $($prim.DataType) | $terminal |")
                }
                [void]$sb.AppendLine('')
            }

            if ($KindDefinition.Compositions -and $KindDefinition.Compositions.Count -gt 0) {
                [void]$sb.AppendLine('### Grammar (ordered composition)')
                [void]$sb.AppendLine('')
                [void]$sb.AppendLine('| Pos | Primitive | Cardinality | Optional |')
                [void]$sb.AppendLine('|---|---|---|---|')
                foreach ($comp in ($KindDefinition.Compositions | Sort-Object Position)) {
                    $opt = if ($comp.IsOptional) { '✓' } else { '' }
                    [void]$sb.AppendLine("| $($comp.Position) | $($comp.PrimitiveName) | $($comp.Cardinality) | $opt |")
                }
                [void]$sb.AppendLine('')
            }

            $section = $sb.ToString()

            if ($PSCmdlet.ShouldProcess($CompendiumPath, "Insert Kind '$($KindDefinition.KindName)' before marker at line $($markerLine + 1)")) {
                $newLines = [System.Collections.Generic.List[string]]::new($lines)
                $sectionLines = $section -split [System.Environment]::NewLine
                # Insert before marker (in reverse order to preserve indices)
                for ($idx = $sectionLines.Count - 1; $idx -ge 0; $idx--) {
                    $newLines.Insert($markerLine, $sectionLines[$idx])
                }
                [System.IO.File]::WriteAllLines($CompendiumPath, $newLines.ToArray(), [System.Text.Encoding]::UTF8)
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Compendium updated: '$($KindDefinition.KindName)' inserted at line $($markerLine + 1) in $CompendiumPath"
            }
            else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "WhatIf: would insert Kind '$($KindDefinition.KindName)' at line $($markerLine + 1)"
            }

            return [PSCustomObject]@{
                FilePath        = $CompendiumPath
                InsertedSection = $section
                MarkerLine      = $markerLine
            }
        }
        catch {
            $errorMessage = "Add-RuleKindToCompendium failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
