<#
.SYNOPSIS
    Clears one or more Visual Studio Code cache directories.
.DESCRIPTION
    Removes all files and subdirectories from the specified VSCode cache locations using
    Remove-Item -Recurse -Force.  When no locations are supplied the function falls back to
    a built-in default list that covers the VSCode user-data caches (Cache, Code Cache,
    CachedData, GPUCache) and the ATAP-AiAssist extension test cache directories.

    Supports -WhatIf and -Confirm so callers can preview the deletions before committing.
.PARAMETER cacheLocations
    One or more directory paths to clear.  Accepts an array of strings.
    When omitted, a default set of well-known VSCode cache paths is used.
    Alias: AI
.INPUTS
    None.  This cmdlet does not accept pipeline input.
.OUTPUTS
    None.  The cmdlet performs file-system operations and produces no output objects.
.EXAMPLE
    Clear-VSCCaches

    Removes all files in the default VSCode cache directories on the current workstation.
.EXAMPLE
    Clear-VSCCaches -WhatIf

    Shows which directories would be cleared without actually deleting anything.
.EXAMPLE
    Clear-VSCCaches -cacheLocations 'C:\Users\me\AppData\Roaming\Code\Cache',
                                    'C:\Users\me\AppData\Roaming\Code\Code Cache'

    Clears only the two specified cache directories.
.NOTES
    Default cache locations are hard-coded pending migration to $global:settings-driven
    configuration (driven by Ansible and runtime settings population).
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/BillHertzing/ATAP.Utilities
#>
function Clear-VSCCaches {
    [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    [Alias()]
    [OutputType([Object])]
    param (
        # Param1 help description
        # ToDO: make this accept pipeline input for cache locations
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)
        ]
        [Alias('AI')]
        $cacheLocations
    )

    begin {
        # ToDO: default cache locations should come from the settings (driven by ansible, and runtime settings population)
        $defaultCacheLocations = @(
            'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.VSCExtension.AI\ATAP-AiAssist\.vscode-test\user-data\Code Cache',
            'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.VSCExtension.AI\ATAP-AiAssist\.vscode-test\user-data\Cache',
            'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.VSCExtension.AI\ATAP-AiAssist\.vscode-test\user-data\DawnCache',
            'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.VSCExtension.AI\ATAP-AiAssist\_generated',
            'C:\Users\whertzing\AppData\Roaming\Code\Cache',
            'C:\Users\whertzing\AppData\Roaming\Code\Code Cache',
            'C:\Users\whertzing\AppData\Roaming\Code\CachedData',
            'C:\Users\whertzing\AppData\Roaming\Code\GPUCache'
        )
        if ( $null -eq $cacheLocations) {
            $cacheLocations = $defaultCacheLocations
        }
        Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    }
    process {
        #  ToDo: make this accept pipeline input for cachelocation
        if ($PSCmdlet.ShouldProcess("$cacheLocations", 'remove-item -recurse -force ')) {
            Remove-Item -Recurse -Force $cacheLocations -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference
        }
    }

    end {
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    }
}
