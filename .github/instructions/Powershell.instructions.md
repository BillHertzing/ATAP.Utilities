```
applyTo: ["**/*.ps1", "*/.ps1"]
```

# PowerShell Guidelines

## Goals

Generate production‑grade functions and scripts that follow our logging, error‑handling, and cmdlet design conventions below.

## Coding Rules

use Approved verbs: Public function names must use [approved PowerShell verbs]. Private/internal helpers are exempt.
use Pascal Case for public functions and cmdlets.
use Pascal Case for public parameters.
use camelCase with a '_'prefix for private/internal functions and cmdlets.
use camelCase with a '_'prefix for local variables.

use Write-PSFMessage for logging, never Write-Host, Write-Verbose, Write-Debug or Write-Output.
use -Level Debug for trace messages, -Level Verbose for lifecycle messages, -Level Important for notable operational messages, and -Level Error for failures.
Never use -Level Info with Write-PSFMessage.
include -FunctionName '<functionName>', -ModuleName '<moduleName>' in every Write-PSFMessage call inside a function.

Refer to the snippets file C:\Dropbox\whertzing\GitHub\SharedVSCode\UserSnippetsPowershell.jsonc which should be open in an editor window as the source of truth for Powershell programming constructs.

Wrap risk points in Try/Catch/Finally using the snippet named : Any call to Invoke-RestMethod, Invoke-WebRequest, Invoke-Expression, or Invoke-Command must be wrapped in Try { ... } Catch { ... } Finally { ... } with the logging pattern shown in the snippets file.

Cmdlet template: Use the Begin/Process/End skeleton below, including the standard entry/exit log lines.

WhatIf/Confirm: Public functions that change state must support -WhatIf and -Confirm, and use SupportsShouldProcess.

Parameter sets for path-like input: When accepting pipeline items that can be paths or streams, use parameter sets (e.g., Path vs InputObject or LiteralPath) and support pipeline binding.

Entry/exit lines for cmdlets
First executable line of Begin:
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%'
Next‑to‑last executable line of End:
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%'
Note: keep the actual return (if any) as the last statement.

Required try/catch/finally pattern
Whenever you catch an exception, you must set a local $\_errorMessage that describes the failing operation and includes the exception message. Then log it with -Level Error. Re-throw the original error object.

Network & execution call conventions
For the following cmdlets, always:

Log before the call with -Level Debug and the required -Tag.

Perform the call inside try.

Log after a successful call with -Level Debug and the same -Tag.

Use the try/catch/finally block above.

Invoke-RestMethod
Tag: 'RestCall'

Messages:

Before: "Calling <URLOfEndpoint>"

After: "Successfully returned from <URLOfEndpoint>"
try {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Tag 'RestCall' -Message "Calling $uri"

    $response = Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $body -ContentType 'application/json' @irParams

    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Tag 'RestCall' -Message "Successfully returned from $uri"

}
catch {
$_errorMessage = "REST call to $uri failed. Exception: $($_.Exception.Message)"
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Error -Message $\_errorMessage -Exception $_.Exception -Tag 'RestCall'
throw $\_
}
finally {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Verbose -Message "Exiting function: <functionName>"
}
Invoke-WebRequest
Tag: 'WebRequestCall'

Messages as above (“Calling …” / “Successfully returned …”).

try {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Tag 'WebRequestCall' -Message "Calling $uri"

    $result = Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -Body $body @iwrParams

    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Tag 'WebRequestCall' -Message "Successfully returned from $uri"

}
catch {
$_errorMessage = "Web request to $uri failed. Exception: $($_.Exception.Message)"
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Error -Message $\_errorMessage -Exception $_.Exception -Tag 'WebRequestCall'
throw $\_
}
finally {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Verbose -Message "Exiting function: <functionName>"
}
Invoke-Expression
Tag: 'InvokeExpressionCall'

Messages:

Before: "Invoke-Expression <command>"

After: "Successfully returned from Invoke-Expression <command>"

try {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Tag 'InvokeExpressionCall' -Message "Invoke-Expression $command"

    $invokeResult = Invoke-Expression -Command $command

    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Tag 'InvokeExpressionCall' -Message "Successfully returned from Invoke-Expression $command"

}
catch {
$_errorMessage = "Invoke-Expression failed for command '$command'. Exception: $($_.Exception.Message)"
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Error -Message $\_errorMessage -Exception $_.Exception -Tag 'InvokeExpressionCall'
throw $\_
}
finally {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Verbose -Message "Exiting function: <functionName>"
}
Invoke-Command
Tag: 'InvokeCommandCall'

Pre‑call log line must render the effective arguments including optional SSL and session options:

powershell
Copy
Edit
try {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message (
"Calling Invoke-Command " +
$(
            "-ComputerName $computerName -ScriptBlock {$scriptBlockToRun} -Credential $($credential.ToString())" +
$(if ($useSSL) { " -UseSSL" } else { "" }) +
$(if ($useSelfSignedCert) { " -SessionOption $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)" } else { "" })
)
) -Tag 'InvokeCommandCall'

    $icResult = Invoke-Command -ComputerName $computerName -ScriptBlock $scriptBlockToRun -Credential $credential @icParams

    Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message "Successfully returned from Invoke-Command" -Tag 'InvokeCommandCall'

}
catch {
$_errorMessage = "Invoke-Command failed on $computerName. Exception: $($_.Exception.Message)"
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Error -Message $\_errorMessage -Exception $_.Exception -Tag 'InvokeCommandCall'
throw $\_
}
finally {
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Verbose -Message "Exiting function: <functionName>"
}
Cmdlet skeleton (use this as the default for public functions)
powershell
Copy
Edit
function Verb-Noun {
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
param( # Path vs stream parameter sets for pipeline scenarios
[Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName='Path')]
[ValidateNotNullOrEmpty()]
[string] $Path,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='InputObject')]
        [ValidateNotNull()]
        [System.IO.Stream] $InputObject
    )
    begin {
        Write-PSFMessage -FunctionName 'Verb-Noun' -ModuleName '<moduleName>' -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%'
    }
    process {
        if ($PSCmdlet.ShouldProcess($Path ?? '<input>', 'Perform operation')) {
            try {
                # Do work here...
                Write-PSFMessage -FunctionName 'Verb-Noun' -ModuleName '<moduleName>' -Level Important -Message 'Operation completed'
            }
            catch {
                $_errorMessage = "Verb-Noun failed while processing '$($Path ?? '<stream>')'. Exception: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName 'Verb-Noun' -ModuleName '<moduleName>' -Level Error -Message $_errorMessage -Exception $_.Exception
                throw $_
            }
            finally {
                Write-PSFMessage -FunctionName 'Verb-Noun' -ModuleName '<moduleName>' -Level Verbose -Message "Exiting function: Verb-Noun"
            }
        }
    }
    end {
        Write-PSFMessage -FunctionName 'Verb-Noun' -ModuleName '<moduleName>' -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%'
    }

}
Additional notes for Copilot
Prefer Write-PSFMessage -Level Debug for trace, -Level Verbose for lifecycle/finally, -Level Important for user‑notable events, and -Level Error for failures. Do not emit -Level Info.

When emitting REST or web requests, include correlation data (IDs, resource names) in log messages when available, but never secrets or tokens.

When adding new public functions, ensure approved verb usage and SupportsShouldProcess—and use parameter sets to distinguish mutually exclusive inputs cleanly.

End of instructions.
