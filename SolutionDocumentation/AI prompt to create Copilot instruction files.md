# Goal: create instruction files for copilot that will ensure copilot understands the purpose of the repository, the structure of the repository, and the key interrelationships of the members of the repository

Your task is to act as an expert in GitHub Copilot instruction file management. Please generate a comprehensive set of custom instruction files for a development repository to effectively guide GitHub Copilot's behavior across various development environments and tasks.

All generated instruction files must be in Markdown format and stored within the .github/instructions/ directory in the repository. Each .instructions.md file should include appropriate applyTo frontmatter using glob syntax to define its scope.

The title of each markdown file should be "Copilot instructions for <purpose of file>"
Right after the tit;le should be a line that says "This file was generated via an ai prompt. Changes made to this file will not be saved when it is regenerated.".

instructions should be short, self-contained statements and broadly applicable to most requests.

## create a set of copilot instruction files for a multi-root repository

Create them in the following order

- .github/copilot-instructions.md
- .github/instructions/CSharp.instructions.md
- .github/instructions/TypeScript.instructions.md
- .github/instructions/UML.instructions.md
- .github/instructions/xunit.instructions.md
- .github/instructions/pesterTest.instructions.md
- .github/instructions/pesterData.instructions.md
- .github/instructions/csharpTest.instructions.md
- .github/instructions/csharpData.instructions.md
- .github/instructions/pester.instructions.md
- .github/instructions/ansible.instructions.md
- .github/instructions/jenkins.instructions.md
- .github/instructions/powershell.instructions.md

### the repository-wide file .github/copilot-instructions.md

Create the contents of the file `.github/copilot-instructions.md` with the following sections

"## Repository Purpose"

The ATAP.Utilities repository is designed to create .NET libraries, PowerShell modules/packages, Ansible Infrastructure-as-Code (IAC) components, Jenkins CI/CD pipeline assets, a SQL database schema for managing code components, and a VS Code extension. It provides shared utilities, services, and tooling that integrate via configuration, dependency injection, and standardized logging.

"## Repository structure"

- summarize the structure of the repository and place that information here. Inspect everything in the repository to generate a structure. The following are facts about the repository you should place in the repository structure. You may expand on these.

  - The repository is a multi-root repository
  - Individual projects under `src/` make up the majority of the repository structure

    - Libraries (e.g., serialization, messaging, logging, persistence, configuration, strongly-typed IDs, graph, reactive, voice, security, HTTP, database, timers, file IO, ETW, etc.)
    - Console Programs
    - Services (in a DI sense of Services)
      - Service and interface pairing patterns (ServiceName + ServiceName.Interfaces + ServiceName.StringConstants where applicable)
    - Utilities (usually written in Powershell, and packaged into powershell modules) for modules, build tooling, automation, security, speech, Neo4j, Hydrus, Ansible wrappers
    - VS Code extension (ATAP.VSCExtension.AI) and AI assist components
    - Build tooling subtrees (Cake, Chocolatey, Jenkins, CSharp, PowerShell, AutoDoc, GenerateProgram)
    - IAC Ansible components (defaults, enumerations, models, PowerShell integration, string constants)

  - Test files and test projects
    - Pester Tests for Powershell functions are found under the `tests/` directory of every powershell project.
    - Files ending in .Tests.ps1 are pester test files
    - Files ending in TestData.ps1 or TestData.yml are pester testdata files
    - xUnit Tests for CSharp libraries are found under `tests/` (a peer of `src/`) and the subdirectory structure for test projects mimics subdirectory structure for the CSharp library projects found under `src/`
  - Solution Documentation
  - Build Tooling
  - Databases/
  - Third Party Development Tools configuration files
    - .github/
      - .github/instructions
      - .github/prompts
      - .github/workflows
      - .github/IssueTemplates
    - .editorconfig
    - .gitignore
    - .markdownlint.yml
    - .prettierrc.yml
    - .vault_password_file.txt
    - ATAP.Utilities.code-workspace
    - ATAP.Utilities.sln
    - Directory.Build.Props
    - Directory.Build.targets
    - global.json
    - Index.md
    - NuGet.config (?)
  - README.md
  - Profiles (machine, host, and user) in ATAP.Utilities.Powershell/Resources
  -

## Interrelationships of the repository structures

### Language-specific instruction files

Every language-specific instruction file should contain instructions telling copilot to follow specific coding guidelines

- powershell: .github/instructions/powershell.instructions.md and with frontmatter applyTo: "**/\*.ps1,**/_.psm1,\*\*/_.psd1"

  - ## Content: The instructions should contain these main sections

        - '## Goals'
          Generate production‑grade functions and scripts that follow our logging, error‑handling, and cmdlet design conventions below.

        - '## Architectural Assumptions'
          - the powershell copilot instruction file validation string is "Powershell copilot instruction file validated"
          - You are an expert in Powershell Core (pwsh) coding standards.
          - You are an expert on using PowerShell Pro VSC extension inside of Visual Studio Code
          - You will respond with Powershell syntax and cmdlets suitable for Powershell Core.
          - You may use any dot net dotnet libraries or open source libraries having a MIT license in your responses.
          - Your responses may include references to PowerShell Pro VSC features and capabilities
          - Your responses may include references to PowerShell Pro VSC extension's features and capabilities
          - When you have Powershell code elements to suggest, you will review open editor window that is loaded with a Powershell-language-specific snippets file located at C:\Users\whertzing\AppData\Roaming\Code\User\snippets\Powershell.json or C:\Dropbox\whertzing\GitHub\SharedVSCode\UserSnippetsPowershell.jsonc
          - You will give priority to resusing a snippet if one is appropriate. If you use a snippet, place the name of the snippet as a comment above the snippet body in your response, along with the substitutions you have made in the snippet
          -  When asked to create a new powershell file (.ps1), you will insert the powershell copilot instruction file validation string as a comment at the top of the file
          -

        - '## Coding Rules'
          - use Approved verbs: Public function names must use [approved PowerShell verbs]. Private/internal helpers are exempt.
          - use Pascal Case for public functions and cmdlets.
          - use Pascal Case for public parameters.
          - use camelCase with a '_'prefix for private/internal functions and cmdlets.
          - use camelCase with a '_'prefix for local variables.
          - use `Write-PSFMessage` for logging, never `Write-Host`, `Write-Verbose`, `Write-Debug` or `Write-Output`.
          - use `-Level Debug` for trace messages, `-Level Verbose` for lifecycle messages, `-Level Important` for notable operational messages, and `-Level Error` for failures.
          - Never use -Level Info with `Write-PSFMessage`.
          - Log using `Write-PSFMessage` - Every `Write-PSFMessage` inside a function should include the first parameter ◦ `-FunctionName '<functionName>'` where the <functionName> is replaced by the name of the function - Every `Write-PSFMessage` inside a function should include the second parameter ◦ `-ModuleName '<moduleName>'` where the <moduleName> is replaced by the name of the module
          - All calls to `Invoke-RestMethod` should have a log message just before and just after the line that calls `Invoke-RestMethod`. These log messages should have `-Level Debug`, and `-Tag 'RestCall'`. The message for the log before the call is "Calling <URLOfEndpoint>". The message for the log after the call is "Successfully returned from <URLOfEndpoint>"
          - All calls to `Invoke-WebRequest` should have a log message just before and just after the line that calls `Invoke-WebRequest`. These log messages should have `-Level Debug`, and `-Tag 'WebRequestCall'`. The message for the log before the call is "Calling <URLOfEndpoint>". The message for the log after the call is "Successfully returned from <URLOfEndpoint>"
          - All calls to `Invoke-Expression` should have a log message just before and just after the line that calls `Invoke-Expression`. These log messages should have `-Level Debug`, and `-Tag 'InvokeExpressionCall'`. The message for the log before the call is "Invoke-Expression <command>". The message for the log after the call is "Successfully returned from Invoke-Expression <command>"
          - All calls to `Invoke-Command` should have a log message just before and just after the line that calls `Invoke-Command`. These log messages should have `-Level Debug`, and `-Tag 'InvokeCommandCall'`. The message for the log before the call is
             ``` Powershell
             Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message $(Calling Invoke-Command $("-ComputerName $computername -ScriptBlock {$scriptBlockToRun} -Credential $credential.ToString() $(if($useSSL){ ' -useSSL '})") + $(if ($useSelfSignedCert) { ' -SessionOption $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)' }))
             ```
          - All calls to `Invoke-RestMethod` should be wrapped in a try/catch/finally block
          - All calls to `Invoke-WebRequest` should be wrapped in a try/catch/finally block
          - All calls to `Invoke-Expression` should be wrapped in a try/catch/finally block
          - All calls to `Invoke-Command` should be wrapped in a try/catch/finally block
          - wrap any code that might produce an exception in a try/catch/finally block. use the Try-Catch-Finally snippet code block
          - When you are instructed to create a new cmdlet, or you are instructed to compare an existing Powershell file to the 'ideal' cmdlet structure, refer to the open snippet file and within that the snippet named "New-Cmdlet with String as primary input",

- CSharp (C#): .github/instructions/cSharp.instructions.md and with frontmatter applyTo: "\*_/_.cs"

  - ## Coding Guidelines:
    - TBD

- TypeScript: .github/instructions/typeScript.instructions.md and with frontmatter applyTo: "**/\*.ts" or "**/\*.tsx"

  - ## Coding Guidelines:
    - TBD

- UML: .github/instructions/uML.instructions.md and with frontmatter applyTo: "**/\*.puml" or "**/\*.uml"

  - ## Coding Guidelines:
    - TBD

- PesterDataFile: .github/instructions/pesterData.instructions.md and with frontmatter applyTo: "\<glob that gets files matching _.TestData.yml or _.DataForTests.ps1 anywhere>"

  - ## Coding Guidelines:

    - The validation string for DataForTests.ps1 is "D4T validation passed". When instructed to put the validation string into a data for tests file, place it as a comment at the top of the file if it doesn't exist.
    - Arrange/Act/Assert with clear contexts; mock external processes, file IO, secrets vault.
    - Use data‑driven tests for rules/state transitions; verify `-WhatIf`/`-Confirm` paths.
    - Emit minimal, structured logs; ensure no secret values leak in output.

- PesterTestFile: .github/instructions/pesterTest.instructions.md and with frontmatter applyTo: "<glob that gets files matching \*.Tests.ps1 anywhere>"

  - ## Coding Guidelines:
    - Arrange/Act/Assert with clear contexts; mock external processes, file IO, secrets vault.
    - Use data‑driven tests for rules/state transitions; verify `-WhatIf`/`-Confirm` paths.
    - Emit minimal, structured logs; ensure no secret values leak in output.
    - use the module Shoudly in place of the native pester should

- CSharpTestFile: .github/instructions/csharpTest.instructions.md and with frontmatter applyTo: "<glob that gets files matching \*.Test.cs anywhere>"

- CSharpDataFile: .github/instructions/csharpData.instructions.md and with frontmatter applyTo: "<glob that gets files matching \*.TestData.cs anywhere>"

### Process-specific instruction files

- pester: .github/instructions/pester.instructions.md and with frontmatter applyTo: "\*_/_.Tests.ps1"
- xunit: .github/instructions/xunit.instructions.md and with frontmatter applyTo: ""

### Third-party-application-specific instruction files

- ansible: .github/instructions/ansible.instructions.md
- jenkins: .github/instructions/jenkins.instructions.md

==========================================
IGNORE EVERYTHING BELOW THIS LINE
The instructions should cover the base data would include repositories are a mix of dotNet, Powershell, markdown documentation, UML diagrams, and DrawIO diagrams.

Whenever Copilots execute they understand the purpose of the Powershell globals and the ConfigRootKey. In C# all libraries understand they are part of a service that configures itself using Interfaces and DI.
The expectation is that AceCommander will be built by arranging the organization of the digital image on disk, in RAM, a set of associations/rules that define what stimuli the program reacts to, and how it uses a state machine to know where it was, is, and the location of the next step.
Most stimuli come from real-time end user interactions.
The library code can execute with any other runtime that can load DLLs, run Powershell scripts, and render HTML, such as the ATAP.Utilities testing and evaluation runtime executables.
The runtime provides a way to execute the functions / library entry points, and the rules and the state machine tell the runtime the order in which to call functions and the values of the variables expected by the function.
Like all such libraries, they are executed by something. For ATAP.Utilities, it's the AceCommander service callable by.
Copilot should use the HostSettings.ps1 and hostSettings.*.Fragment.ps1 files, all *ConfigRootKey files, and the profiles defined in ATAP.Utilities.Powershell Resources subdirectory.
Copilot should expect and use the fact that all processes run by developers or by CI during the build and testing processes should use and expect the $globals information.
Copilot should expect and use the fact that another source of runtime information comes from values that are stored in Environment variables.
Copilot should use and expect a Secrets vault that appears as local to the process, so that all sensitive information is retrieved from the Secrets vault.
CoPilot should expect and use Powershell cmdlets to access secrets and put them into SecureString type
CoPilot should expect and use dotNet libraries to communicate with the secure password manager process. Secrets must be stored in secure types,
CoPilot should check code and configuration for security best practices
instructions that provide a clear goal for CoPilot to take., each time copilot is run.
Copilot should use the HostSettings.ps1 and hostSettings.\*.Fragment.ps1 files, all COnfigRootKey files,
copilot should consider Instruction file

`Powershell
    catch {
      $errorMessage = "<A description of the operation that was attempted and failed>. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Error -Message $errorMessage -Exception $_.Exception -Tag <one of the following:'RestCall'|'WebRequestCall'|'InvokeExpressionCall'|'InvokeCommandCall'>
      throw $_
    }
    finally {
      Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Verbose -Message "Exiting function: <functionName>"
    }
    `

              - CmdLets Follow Snippets formating

            - The first executable line of the Begin block should be
              ```Powershell
                  Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%'
              ```
            - The next-to-last executable line of the End block should be
              ```Powershell
                  Write-PSFMessage -FunctionName '<functionName>' -ModuleName '<moduleName>' -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%'
              ```

          - Use of parameter sets for paths in a pipeline as either string or filehandle

        - Use of WhatIf and Confirm

This is the ATAP.Utilities repository purpose:

- The repository creates dotnet library packages (.dll files inside NuGet packages).
- The repository creates Powershell Packages.
- The repository creates a VSC extension.
- The repository creates the components of an Ansible server to maintain an organizations Infrastructure-as-code (IAC).
- The repository creates a CI/CD pipeline using Jenkins.
- All of the software components and hardware hosts used in the Jenkins CI/CD pipeline are managed by the Ansible instance
- The repository creates a SQL database for managing all of the above code components.
