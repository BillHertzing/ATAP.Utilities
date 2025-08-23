```
applyTo: ["**/*.ps1", "*/.ps1"]
```

# AI instructions for PowerShell files

This file is a set of instructions for AI to follow when generating or modifying PowerShell (.ps1) files in this repository.

---

## Goals

- Generate production-grade PowerShell functions and scripts that follow the repository's logging, error-handling, and cmdlet design conventions.

---

## AI Guidelines

- You are an expert in PowerShell Core (pwsh) coding standards.
- You are an expert in the PowerShell Pro VS Code extension.
- All PowerShell code must run on PowerShell Core (cross-platform).
- You may use any .NET libraries or open-source libraries with an MIT license.
- Your responses may include references to PowerShell Pro VS Code extension features and capabilities.
- When generating PowerShell code, prioritize reusing snippets from:
  - `C:\Users\whertzing\AppData\Roaming\Code\User\snippets\Powershell.json`
  - `C:\Dropbox\whertzing\GitHub\SharedVSCode\UserSnippetsPowershell.jsonc`
- If a snippet is used, include the snippet name as a comment above the snippet body, along with any substitutions made.

---

## Validation String

- For `*.ps1` files, include the validation string `"AI assisted using Powershell.instructions.md as guidelines"` under the `.NOTES` section of the comment-based help. If no comment-based help exists, include the validation string as a comment at the top of the file.

---

## Architectural Assumptions

- All PowerShell cmdlets must follow the repository's conventions for logging, error handling, and modularity.
- Use $global:settings to access global settings. The contents of the global settings are host and user specific

---

## Coding Rules for PowerShell

- **General Formatting**:
  - Use the .editorconfig file in the root of the repository for formatting rules.
  - Use spaces around operators and after commas.
  - Use single quotes for strings unless interpolation is required.
  - Avoid trailing whitespace at the end of lines.
- **Function Naming**:
  - Use PascalCase for public functions and parameters.
  - Use camelCase with a `_` prefix for private/internal functions and variables.
- **Cmdlet Design**:
  - Include `[CmdletBinding()]` and `param()` blocks with proper validation attributes.
  - Ensure all cmdlets support `-WhatIf` and `-Confirm` parameters.
- **Comment-Based Help**:
  - Add `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, `.EXAMPLE`, `.NOTES`, and `.LINK` sections for all public functions.
- **Validation String**:
  - For `*.ps1` files, include the validation string `"AI assisted using Powershell.instructions.md as guidelines"` under the `.NOTES` section of the comment-based help. If no comment-based help exists, include the validation string as a comment at the top of the file.
- **Function Returns**:
  - All functions should return a string, a filehandle, a dotnet type defined in a loaded .DLL, or a PSCustomObject.
- **Error Handling**:
  - Wrap all potentially failing operations in `try/catch/finally` blocks using the "Try-Catch-Finally" snippet pattern.
  - All calls to `Invoke-RestMethod` should be wrapped in a try/catch/finally block using the "Try-Catch-Finally" snippet pattern.
  - All calls to `Invoke-WebRequest` should be wrapped in a try/catch/finally block using the "Try-Catch-Finally" snippet pattern.
  - All calls to `Invoke-Expression` should be wrapped in a try/catch/finally block using the "Try-Catch-Finally" snippet pattern.
  - All calls to `Invoke-Command` should be wrapped in a try/catch/finally block using the "Try-Catch-Finally" snippet pattern.
  - Log errors using `Write-PSFMessage` with `-Level Error`.
- **Logging**:
  - Use `Write-PSFMessage` for logging:
    - `-Level Debug` for trace messages.
    - `-Level Verbose` for lifecycle messages.
    - `-Level Important` for notable operational messages.
    - `-Level Error` for failures.
    - use `Write-PSFMessage` for logging, never `Write-Host`, `Write-Verbose`, `Write-Debug` or `Write-Output`.
    - use `-Level Debug` for trace messages, `-Level Verbose` for lifecycle messages, `-Level Important` for notable operational messages, and `-Level Error` for failures.
    - Never use -Level Info with `Write-PSFMessage`.
    - Log using `Write-PSFMessage` - Every `Write-PSFMessage` inside a function should include the first parameter ◦ `-FunctionName '<functionName>'` where the <functionName> is replaced by the name of the function - Every `Write-PSFMessage` inside a function should include the second parameter ◦ `-ModuleName '<moduleName>'` where the <moduleName> is replaced by the name of the module
    - All calls to `Invoke-RestMethod` should have a log message just before and just after the line that calls `Invoke-RestMethod`. These log messages should have `-Level Debug`, and `-Tag 'RestCall'`. The message for the log before the call is "Calling <URLOfEndpoint>". The message for the log after the call is "Successfully returned from <URLOfEndpoint>"
    - All calls to `Invoke-WebRequest` should have a log message just before and just after the line that calls `Invoke-WebRequest`. These log messages should have `-Level Debug`, and `-Tag 'WebRequestCall'`. The message for the log before the call is "Calling <URLOfEndpoint>". The message for the log after the call is "Successfully returned from <URLOfEndpoint>"
    - All calls to `Invoke-Expression` should have a log message just before and just after the line that calls `Invoke-Expression`. These log messages should have `-Level Debug`, and `-Tag 'InvokeExpressionCall'`. The message for the log before the call is "Invoke-Expression <command>". The message for the log after the call is "Successfully returned from Invoke-Expression <command>"
    - All calls to `Invoke-Command` should have a log message just before and just after the line that calls `Invoke-Command`. These log messages should have `-Level Debug`, and `-Tag 'InvokeCommandCall'`. The message for the log before the call is
      ```Powershell
      Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message $(Calling Invoke-Command $("-ComputerName $computername -ScriptBlock {$scriptBlockToRun} -Credential $credential.ToString() $(if($useSSL){ ' -useSSL '})") + $(if ($useSelfSignedCert) { ' -SessionOption $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)' }))
      ```

---

## Example Logging Patterns

### `Invoke-RestMethod`

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message "Calling <URLOfEndpoint>" -Tag 'RestCall'
$response = Invoke-RestMethod -Uri <URLOfEndpoint> -Method GET
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message "Successfully returned from <URLOfEndpoint>" -Tag 'RestCall'
```

### `Invoke-Command`

```powershell
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message "Calling Invoke-Command on $computerName" -Tag 'InvokeCommandCall'
Invoke-Command -ComputerName $computerName -ScriptBlock { <scriptBlockToRun> }
Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message "Successfully returned from Invoke-Command on $computerName" -Tag 'InvokeCommandCall'
```

## Using PowerShell Snippets

- **Snippet Files**:
  - Snippets are stored in:
    - `C:\Users\whertzing\AppData\Roaming\Code\User\snippets\Powershell.json`
    - `C:\Dropbox\whertzing\GitHub\SharedVSCode\UserSnippetsPowershell.jsonc`
- **Snippet Usage**:
  - When generating PowerShell code, prioritize reusing snippets from the above files.
  - If a snippet is used, include the snippet name as a comment above the snippet body, along with any substitutions made.

End of instructions.
