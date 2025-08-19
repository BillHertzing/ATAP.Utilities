```
applyTo: ["**/*.ps1", "*/.ps1"]
```

# Copilot instructions for PowerShell files

This file was generated via an AI prompt. Changes made to this file will not be saved when it is regenerated.
This file was created by stiching together three different AI responses to the meta-prompt.

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
- Use `Write-PSFMessage` for logging:
  - `-Level Debug` for trace messages.
  - `-Level Verbose` for lifecycle messages.
  - `-Level Important` for notable operational messages.
  - `-Level Error` for failures.
- All calls to `Invoke-RestMethod`, `Invoke-WebRequest`, `Invoke-Expression`, and `Invoke-Command` must:
  - Be wrapped in a `try/catch/finally` block.
  - Include log messages before and after the call with appropriate tags (e.g., `RestCall`, `WebRequestCall`, `InvokeExpressionCall`, `InvokeCommandCall`).

---

## Coding Rules for PowerShell

- **Function Naming**:
  - Use PascalCase for public functions and parameters.
  - Use camelCase with a `_` prefix for private/internal functions and variables.
- **Cmdlet Design**:
  - Include `[CmdletBinding()]` and `param()` blocks with proper validation attributes.
  - Ensure all cmdlets support `-WhatIf` and `-Confirm` parameters.
- **Comment-Based Help**:
  - Add `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`, and `.LINK` sections for all public functions.
  - Include log messages before and after calls to `Invoke-RestMethod`, `Invoke-WebRequest`, `Invoke-Expression`, and `Invoke-Command`.
- **Error Handling**:
  - Wrap all potentially failing operations in `try/catch/finally` blocks.
  - Log errors using `Write-PSFMessage` with `-Level Error`.
  - ToDO: work on metaprompt - there are many more rules there that did not get output into the language specific instructions.
- **Logging**:
  - Use `Write-PSFMessage` for logging:
    - `-Level Debug` for trace messages.
    - `-Level Verbose` for lifecycle messages.
    - `-Level Important` for notable operational messages.
    - `-Level Error` for failures.

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
- **Validation String**:
  - For `*.ps1` files, include the validation string `"AI assisted using Powershell.instructions.md as guidelines"` under the `.NOTES` section of the comment-based help. If no comment-based help exists, include the validation string as a comment at the top of the file.

End of instructions.
