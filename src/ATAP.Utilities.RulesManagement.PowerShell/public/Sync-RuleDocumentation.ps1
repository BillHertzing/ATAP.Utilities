<#
.SYNOPSIS
    Updates cross-reference entries for a new Kind across all affected .md files.
.DESCRIPTION
    Searches DocsRoot recursively for any .md file containing the HTML comment
    marker <!-- rule-index --> and inserts or updates a single-line cross-reference
    entry for the new Kind. Also finds files containing a Kinds table bounded by
    <!-- rule-table-start --> / <!-- rule-table-end --> and adds a row.

    Supports -WhatIf: when supplied, returns the list of files that would be modified
    and the proposed diff text without writing anything.
.PARAMETER KindName
    The PascalCase name of the new Kind.
.PARAMETER LanguageName
    The language the Kind belongs to (e.g. 'CSharp', 'SQL').
.PARAMETER Description
    One-sentence description used in the inline cross-reference.
.PARAMETER CompendiumRelativePath
    Relative path from DocsRoot to the Compendium .md file, used to build the
    cross-reference hyperlink. E.g. 'Rules\RulesCompendium.CSharp.md'.
.PARAMETER DocsRoot
    Root folder to search recursively for affected .md files.
    Defaults to the value at global settings RulesManagement.DocsRoot.
.OUTPUTS
    PSCustomObject with ModifiedFiles (string[]), Diffs (hashtable of path→diff string), WhatIf (bool).
.EXAMPLE
    Sync-RuleDocumentation -KindName 'InterfaceDeclaration' -LanguageName 'CSharp' -Description 'Represents a C# interface declaration.' -CompendiumRelativePath 'Rules\RulesCompendium.CSharp.md' -DocsRoot 'C:\repo\docs'
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Sync-RuleDocumentation {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $KindName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $LanguageName,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [Parameter(Mandatory = $true, Position = 3, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $CompendiumRelativePath,

        [Parameter(Mandatory = $false, Position = 4)]
        [string] $DocsRoot
    )

    BEGIN {
        $fn = 'Sync-RuleDocumentation'
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

        $KindName                = Get-PVal -ParameterName 'KindName'                -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.KindName'                -DefaultValue $KindName
        $LanguageName            = Get-PVal -ParameterName 'LanguageName'            -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.LanguageName'            -DefaultValue $LanguageName
        $Description             = Get-PVal -ParameterName 'Description'             -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.Description'             -DefaultValue $Description
        $CompendiumRelativePath  = Get-PVal -ParameterName 'CompendiumRelativePath'  -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.CompendiumRelativePath'  -DefaultValue $CompendiumRelativePath
        $DocsRoot                = Get-PVal -ParameterName 'DocsRoot'                -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.DocsRoot'                -DefaultValue $DocsRoot

        if ([string]::IsNullOrWhiteSpace($DocsRoot)) {
            throw 'DocsRoot must be provided or set in global settings at RulesManagement.DocsRoot'
        }
        if (-not (Test-Path -Path $DocsRoot -PathType Container)) {
            throw "DocsRoot not found: $DocsRoot"
        }

        $indexMarker      = '<!-- rule-index -->'
        $tableStartMarker = '<!-- rule-table-start -->'
        $tableEndMarker   = '<!-- rule-table-end -->'

        # The inline cross-reference line inserted after <!-- rule-index -->
        $crossRefLine = "- [$KindName]($CompendiumRelativePath#$KindName) ($LanguageName) — $Description"

        # A table row for files with a rule table
        $tableRow = "| [$KindName]($CompendiumRelativePath#$KindName) | $LanguageName | $Description |"

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "DocsRoot: $DocsRoot | KindName: $KindName"
    }

    PROCESS {
        try {
            $modifiedFiles = [System.Collections.Generic.List[string]]::new()
            $diffs         = @{}

            $allMdFiles = Get-ChildItem -Path $DocsRoot -Filter '*.md' -Recurse -File
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Scanning $($allMdFiles.Count) .md file(s) under $DocsRoot"

            foreach ($mdFile in $allMdFiles) {
                $content = [System.IO.File]::ReadAllLines($mdFile.FullName, [System.Text.Encoding]::UTF8)
                $modified = $false
                $diffLines = [System.Collections.Generic.List[string]]::new()

                # ── index marker: insert cross-ref line immediately after it ──
                $indexLine = -1
                for ($i = 0; $i -lt $content.Count; $i++) {
                    if ($content[$i].Trim() -eq $indexMarker) { $indexLine = $i; break }
                }
                if ($indexLine -ge 0) {
                    # Guard: don't insert if the kind is already referenced
                    $alreadyReferenced = $content | Where-Object { $_ -match "\[$KindName\]" }
                    if (-not $alreadyReferenced) {
                        $diffLines.Add("  + [line $($indexLine + 2)] $crossRefLine")
                        if ($PSCmdlet.ShouldProcess($mdFile.FullName, "Insert rule-index cross-reference for '$KindName'")) {
                            $newContent = [System.Collections.Generic.List[string]]::new($content)
                            $newContent.Insert($indexLine + 1, $crossRefLine)
                            $content = $newContent.ToArray()
                            $modified = $true
                        }
                    }
                    else {
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "$($mdFile.Name): '$KindName' already referenced — skipping index insert"
                    }
                }

                # ── table markers: insert row before table-end marker ──
                $tableEndLine = -1
                for ($i = 0; $i -lt $content.Count; $i++) {
                    if ($content[$i].Trim() -eq $tableEndMarker) { $tableEndLine = $i; break }
                }
                if ($tableEndLine -ge 0) {
                    $alreadyInTable = $content | Where-Object { $_ -match "\[$KindName\]" }
                    if (-not $alreadyInTable) {
                        $diffLines.Add("  + [line $($tableEndLine + 1)] $tableRow")
                        if ($PSCmdlet.ShouldProcess($mdFile.FullName, "Insert rule-table row for '$KindName'")) {
                            $newContent = [System.Collections.Generic.List[string]]::new($content)
                            $newContent.Insert($tableEndLine, $tableRow)
                            $content = $newContent.ToArray()
                            $modified = $true
                        }
                    }
                }

                if ($modified) {
                    [System.IO.File]::WriteAllLines($mdFile.FullName, $content, [System.Text.Encoding]::UTF8)
                    $modifiedFiles.Add($mdFile.FullName)
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Updated: $($mdFile.FullName)"
                }
                if ($diffLines.Count -gt 0) {
                    $diffs[$mdFile.FullName] = $diffLines -join [System.Environment]::NewLine
                }
            }

            $isWhatIf = -not $PSCmdlet.ShouldProcess('dummy', 'dummy')  # check WhatIf state
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Sync complete. Files modified: $($modifiedFiles.Count)"

            return [PSCustomObject]@{
                ModifiedFiles = $modifiedFiles.ToArray()
                Diffs         = $diffs
                WhatIf        = $WhatIfPreference -eq [System.Management.Automation.ActionPreference]::Continue
            }
        }
        catch {
            $errorMessage = "Sync-RuleDocumentation failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
