Set-StrictMode -Version Latest

BeforeAll {
    $fixturePath = Join-Path $PSScriptRoot 'Fixtures\RPRRSBSI-V4-RatifiedAcceptanceFixtures.json'
    $fixtureText = Get-Content -LiteralPath $fixturePath -Raw
    $fixture = $fixtureText | ConvertFrom-Json -Depth 20
    $canonicalGuidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    $identityProperties = @('ruleId', 'ruleVariantId', 'inputDefinitionId', 'outputDefinitionId')
}

Describe 'RPRRSBSI V4 ratified GUID acceptance fixture' {
    It 'accepts only lowercase dashed D-format values at the CSV or API boundary' {
        @($fixture.guidContract.canonicalBoundaryValues).Count | Should -Be 2
        foreach ($value in $fixture.guidContract.canonicalBoundaryValues) {
            ($value -cmatch $canonicalGuidPattern) | Should -BeTrue
            ([guid] $value).ToString('D') | Should -BeExactly $value
        }

        @($fixture.guidContract.rejectedBoundaryValues).Count | Should -Be 5
        foreach ($value in $fixture.guidContract.rejectedBoundaryValues) {
            { [guid]::Parse($value.Trim()) } | Should -Not -Throw
            ($value -cnotmatch $canonicalGuidPattern) | Should -BeTrue
        }
    }

    It 'compares parsed GUID identity as a native value independently of boundary spelling' {
        @($fixture.guidContract.nativeValueComparisons).Count | Should -Be 3
        foreach ($comparison in $fixture.guidContract.nativeValueComparisons) {
            $actual = ([guid] $comparison.left) -eq ([guid] $comparison.right)
            $actual | Should -Be $comparison.equivalent
        }
    }
}

Describe 'RPRRSBSI V4 ratified identity-change acceptance fixture' {
    It 'contains exactly four material cases and two non-material controls' {
        @($fixture.identityChangeScenarios).Count | Should -Be 6
        @($fixture.identityChangeScenarios | Where-Object classification -EQ 'material').Count | Should -Be 4
        @($fixture.identityChangeScenarios | Where-Object classification -EQ 'non-material-control').Count | Should -Be 2
        @($fixture.identityChangeScenarios.name) | Should -Be @(
            'rule-kind-change',
            'scalar-to-different-scalar-input',
            'scalar-to-heap-object-output',
            'heap-object-type-change-input',
            'default-value-only-change',
            'display-only-text-change'
        )
    }

    It 'allocates or retains each identity exactly as declared by the ratified matrix' {
        foreach ($scenario in $fixture.identityChangeScenarios) {
            foreach ($property in $identityProperties) {
                $before = $scenario.before.$property
                $after = $scenario.after.$property
                $expected = $scenario.expectedTransitions.$property

                ($before -cmatch $canonicalGuidPattern) | Should -BeTrue
                ($after -cmatch $canonicalGuidPattern) | Should -BeTrue
                $expected | Should -BeIn @('new', 'retained')
                if ($expected -eq 'new') {
                    $after | Should -Not -BeExactly $before
                }
                else {
                    $after | Should -BeExactly $before
                }
            }
        }
    }

    It 'preserves prior history and rejects in-place mutation in every case' {
        foreach ($scenario in $fixture.identityChangeScenarios) {
            $scenario.priorHistoryPreserved | Should -BeTrue
            $scenario.inPlaceMutationRejected | Should -BeTrue
            $scenario.historyMechanism | Should -Not -BeNullOrEmpty
        }
        @($fixture.identityChangeScenarios | Where-Object classification -EQ 'material').prohibitedMutation |
            Should -Be @(
                'reuse-existing-semantic-identity',
                'reuse-existing-semantic-identity',
                'reuse-existing-semantic-identity',
                'reuse-existing-semantic-identity'
            )
        @($fixture.identityChangeScenarios | Where-Object classification -EQ 'non-material-control').prohibitedMutation |
            Should -Be @('overwrite-prior-history', 'overwrite-prior-history')
    }

    It 'uses explicit history rows for both non-material controls' {
        $controls = @($fixture.identityChangeScenarios | Where-Object classification -EQ 'non-material-control')
        @($controls.historyMechanism) | Should -Be @(
            'new-validity-bounded-default-row',
            'new-display-state-row'
        )
    }
}

Describe 'RPRRSBSI V4 ratified RuleVariant owner and overlay acceptance fixture' {
    It 'uses three distinct variants of one Rule without creating a copied Rule' {
        $fixture.overlayScenario.ruleCopiesCreated | Should -Be 0
        @($fixture.overlayScenario.variants).Count | Should -Be 3
        @($fixture.overlayScenario.variants.ruleVariantId | Sort-Object -Unique).Count | Should -Be 3
        @($fixture.overlayScenario.variants.owningRuleSetId | Sort-Object -Unique).Count | Should -Be 3
        ($fixture.overlayScenario.ruleId -cmatch $canonicalGuidPattern) | Should -BeTrue
        @($fixture.overlayScenario.variants | Where-Object ruleId -CNE $fixture.overlayScenario.ruleId).Count |
            Should -Be 0
    }

    It 'makes every occurrence owner pair satisfy the composite owner key' {
        foreach ($occurrence in $fixture.overlayScenario.occurrences) {
            $ownerMatches = @($fixture.overlayScenario.variants | Where-Object {
                    $_.ruleVariantId -ceq $occurrence.ruleVariantId -and
                    $_.owningRuleSetId -ceq $occurrence.ruleSetId
                })
            $ownerMatches.Count | Should -Be 1
        }
    }

    It 'uses Add for the baseline and Override for both ACE variants' {
        @($fixture.overlayScenario.occurrences.membershipRole) | Should -Be @('Add', 'Override', 'Override')
        @($fixture.overlayScenario.occurrences.buildSetOrdinal) | Should -Be @(10, 20, 30)
    }

    It 'resolves the required 1000 then 1500 then 1200 sequence by higher ordinal' {
        @($fixture.overlayScenario.asOfExpectations.effectiveValue) | Should -Be @(1000, 1500, 1200)
        foreach ($expectation in $fixture.overlayScenario.asOfExpectations) {
            $winnerOrdinal = @($expectation.activeOrdinals | Sort-Object -Descending)[0]
            $winningOccurrence = @($fixture.overlayScenario.occurrences | Where-Object buildSetOrdinal -EQ $winnerOrdinal)
            $winningVariant = @($fixture.overlayScenario.variants | Where-Object ruleVariantId -CEQ $winningOccurrence.ruleVariantId)
            $winningVariant.value | Should -Be $expectation.effectiveValue
        }
    }

    It 'enumerates the ratified owner and overlay rejection cases without ambiguity' {
        @($fixture.overlayScenario.negativeCases.name) | Should -Be @(
            'cross-owner-occurrence',
            'override-with-different-rule-id',
            'copied-rule-overlay',
            'override-without-lower-precedence-base',
            'duplicate-build-set-ordinal',
            'add-collides-with-visible-rule'
        )
        @($fixture.overlayScenario.negativeCases.expectedRejection) | Should -Be @(
            'composite-owner-foreign-key',
            'same-rule-required',
            'rule-copy-prohibited',
            'base-candidate-required',
            'unique-build-set-ordinal',
            'add-collision'
        )
    }
}

Describe 'RPRRSBSI V4 fixture scope guard' {
    It 'does not claim executable SQL or unresolved decision coverage' {
        $fixtureText | Should -Not -Match '(?i)HITL-PENDING|C-1[7-9]|C-2[1-57]|edge case'
        $fixtureText | Should -Not -Match '(?i)CREATE\s+TABLE|ALTER\s+TABLE|INSERT\s+INTO|MERGE\s+INTO'
    }
}
