<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function Clear-VSCCaches {
    [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    [Alias()]
    [OutputType([Object])]
    Param (
        # Param1 help description
        # ToDO: make this accept pipeline input for cachelocations
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            ValueFromRemainingArguments = $false)
        ]
        [Alias('AI')]
        $cacheLocations
    )

    BEGIN {
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
    PROCESS {
        #  ToDo: make this accept pipeline input for cachelocation
        if ($PSCmdlet.ShouldProcess("$cacheLocations", 'remove-item -recurse -force ')) {
            Remove-Item -Recurse -Force $cacheLocations -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
        }
    }

    END {
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    }
}
