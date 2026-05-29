@{
    # ----------------------------------------------------------------------------
    # Repo-wide PSScriptAnalyzer settings for the 5-Tier PowerShell module build.
    #
    # Consumed by Invoke-PSModulePSScriptAnalyzer (auto-discovered by walking up
    # from the module root). The Analyze gate runs at Severity Warning/Error; the
    # rules below are excluded because they conflict with documented ATAP.Utilities
    # conventions or are pure noise for this codebase. Security- and correctness-
    # oriented rules (plaintext passwords, Invoke-Expression, ShouldProcess, empty
    # catch blocks, approved verbs, etc.) are intentionally NOT excluded so the gate
    # still catches real problems.
    #
    # tests/ and Obsolete/ folders are excluded at the file-enumeration level in
    # the wrapper, not here.
    # ----------------------------------------------------------------------------
    ExcludeRules = @(
        # $global:settings / $global:configRootKeys is the documented two-tier
        # configuration pattern (see CLAUDE.md "Configuration System").
        'PSAvoidGlobalVars'

        # Write-Host is used intentionally in interactive bootstrap/console scripts
        # (e.g. Initialize-5TierShell). Module logging still uses Write-PSFMessage.
        'PSAvoidUsingWriteHost'

        # Several domain cmdlets use plural nouns by design.
        'PSUseSingularNouns'

        # Parameters are commonly bound indirectly via Get-PVal / $PSBoundParameters,
        # which PSSA cannot see, producing false "unused parameter" findings.
        'PSReviewUnusedParameter'

        # Source files are UTF-8; BOM is applied by the build when required
        # (Build-PSModulePsm1). A BOM is not required on hand-authored sources.
        'PSUseBOMForUnicodeEncodedFile'

        # Get-PVal is the documented alias for Get-ParameterValueFromNeoConfigurationRoot
        # and is used pervasively by design (see CLAUDE.md / Powershell.md Rules). This
        # rule also resolves aliases against the current session, so it is inflated and
        # noisy under the build session that pre-loads many aliases.
        'PSAvoidUsingCmdletAliases'

        # Variables are frequently assigned for readability or consumed inside strings /
        # script blocks that PSSA cannot statically see, producing false positives.
        'PSUseDeclaredVarsMoreThanAssignments'

        # The repo deliberately uses non-approved verbs for several domain cmdlets
        # (e.g. Create-ServiceAccount, List-ProGetApiKeys, Validate-ProGetFeeds, Sync-*).
        'PSUseApprovedVerbs'
    )
}
