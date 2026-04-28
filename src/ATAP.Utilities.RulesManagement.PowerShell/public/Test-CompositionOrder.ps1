<#
.SYNOPSIS
    Validates a proposed set of RulePrimitiveComposition rows before any DB write.
.DESCRIPTION
    Performs structural validation of a proposed composition — contiguous Positions
    starting at 1, no duplicate Positions, all required primitives present, and
    valid Cardinality values. Optionally checks against a reference GrammarModel
    (from Get-GrammarForKind) to warn when the proposed structure diverges
    significantly from the template Kind.

    This is the CRITICAL gate in the new-rule-kind workflow. An invalid ordering
    passes all FK constraints silently and only manifests as incorrect code generation
    at runtime.
.PARAMETER ProposedCompositions
    Array of PSCustomObjects representing the proposed rows, each with:
    PrimitiveName (string), Position (int), IsOptional (bool), Cardinality (string).
.PARAMETER ReferenceGrammarModel
    Optional. A GrammarModel returned by Get-GrammarForKind used for structural
    comparison warnings.
.OUTPUTS
    PSCustomObject with IsValid (bool), Errors (string[]), Warnings (string[]).
.EXAMPLE
    $result = Test-CompositionOrder -ProposedCompositions $rows -ReferenceGrammarModel $model
    if (-not $result.IsValid) { $result.Errors | ForEach-Object { Write-Host $_ } }
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Test-CompositionOrder {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject[]] $ProposedCompositions,

        [Parameter(Mandatory = $false, Position = 1)]
        [PSCustomObject] $ReferenceGrammarModel
    )

    BEGIN {
        $fn = 'Test-CompositionOrder'
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

        $ProposedCompositions  = Get-PVal -ParameterName 'ProposedCompositions'  -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.ProposedCompositions'  -DefaultValue $ProposedCompositions
        $ReferenceGrammarModel = Get-PVal -ParameterName 'ReferenceGrammarModel' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.ReferenceGrammarModel' -DefaultValue $ReferenceGrammarModel -AllowMissing:$true

        $validCardinalities = @('1', '?', '*', '+')
    }

    PROCESS {
        try {
            $errors   = [System.Collections.Generic.List[string]]::new()
            $warnings = [System.Collections.Generic.List[string]]::new()

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Validating $($ProposedCompositions.Count) proposed composition rows"

            # Rule 1: Must have at least one row
            if ($ProposedCompositions.Count -eq 0) {
                $errors.Add('ProposedCompositions is empty — at least one row is required')
            }

            # Rule 2: Positions must start at 1
            $positions = $ProposedCompositions | Select-Object -ExpandProperty Position | Sort-Object
            if ($positions[0] -ne 1) {
                $errors.Add("First Position must be 1; found $($positions[0])")
            }

            # Rule 3: Positions must be contiguous with no gaps
            for ($i = 0; $i -lt $positions.Count; $i++) {
                $expected = $i + 1
                if ($positions[$i] -ne $expected) {
                    $errors.Add("Position gap detected: expected $expected but found $($positions[$i]). Positions must be contiguous integers starting at 1.")
                    break
                }
            }

            # Rule 4: No duplicate Positions
            $duplicates = $positions | Group-Object | Where-Object { $_.Count -gt 1 }
            foreach ($dup in $duplicates) {
                $errors.Add("Duplicate Position value: $($dup.Name) appears $($dup.Count) times")
            }

            # Rule 5: Cardinality must be valid enum value
            foreach ($row in $ProposedCompositions) {
                if ($row.Cardinality -notin $validCardinalities) {
                    $errors.Add("Row at Position $($row.Position) (Primitive: $($row.PrimitiveName)) has invalid Cardinality '$($row.Cardinality)'. Must be one of: $($validCardinalities -join ', ')")
                }
            }

            # Rule 6: Position 1 must not be optional (every grammar must have a required anchor)
            $firstRow = $ProposedCompositions | Where-Object { $_.Position -eq 1 }
            if ($firstRow -and ($firstRow.IsOptional -eq $true -or $firstRow.Cardinality -in @('?', '*'))) {
                $errors.Add("Position 1 ($($firstRow.PrimitiveName)) must not be optional — every grammar must have a required anchor at position 1")
            }

            # Warning checks against reference model
            if ($ReferenceGrammarModel -and $ReferenceGrammarModel.Compositions) {
                $refCount  = $ReferenceGrammarModel.Compositions.Count
                $propCount = $ProposedCompositions.Count
                $delta = [Math]::Abs($propCount - $refCount)
                if ($delta -gt [Math]::Ceiling($refCount * 0.5)) {
                    $warnings.Add("Proposed composition ($propCount rows) differs from reference Kind ($refCount rows) by more than 50%. Verify this is intentional.")
                }

                $propNames = $ProposedCompositions | Select-Object -ExpandProperty PrimitiveName | Sort-Object
                $refNames  = $ReferenceGrammarModel.Compositions | Select-Object -ExpandProperty PrimitiveName | Sort-Object
                $newInProp = $propNames | Where-Object { $_ -notin $refNames }
                if ($newInProp) {
                    $warnings.Add("New primitives not present in reference Kind: $($newInProp -join ', '). Confirm these are intentional additions.")
                }
            }

            $isValid = $errors.Count -eq 0
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Validation complete. IsValid: $isValid | Errors: $($errors.Count) | Warnings: $($warnings.Count)"

            return [PSCustomObject]@{
                IsValid  = $isValid
                Errors   = $errors.ToArray()
                Warnings = $warnings.ToArray()
            }
        }
        catch {
            $errorMessage = "Test-CompositionOrder failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
