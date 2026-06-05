# Generated Diagram Pipeline

This repository keeps editable diagram sources in their owning documentation
folders and writes rendered images under the repository-level `_generated/`
tree. Do not edit generated images directly; update the `.puml`, `.uml`, or
`.drawio` source and regenerate the image.

## Sources

Current editable diagram sources include:

- `Database/Documentation/*.puml` for database schema and database package
  promotion diagrams.
- `src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/*.drawio` for the
  Ansible module diagrams.
- `src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/UML/*.uml` for the
  ProGet feed diagram.

The local PlantUML MCP server remains configured in `.mcp.json` and
`.vscode/mcp.json` for MCP-aware clients that need interactive PlantUML
rendering. The checked-in generation path uses the PowerShell command below so
the generated artifacts are reproducible without depending on a client UI.

## Generate Images

From the repository root:

```powershell
Import-Module .\src\ATAP.Utilities.BuildTooling.PowerShell\ATAP.Utilities.BuildTooling.PowerShell.psd1 -Force
Convert-DiagramsToImages -Path .\Database\Documentation, .\src\ATAP.Utilities.IAC.Ansible.Powershell\Documentation
```

The default output root is `_generated/diagrams`. The command mirrors each
source path under that directory. For example:

- `Database/Documentation/CoreSchema_Rules.puml` renders to
  `_generated/diagrams/Database/Documentation/CoreSchema_Rules.png`.
- `src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/Overview.drawio`
  renders to
  `_generated/diagrams/src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/Overview.png`.

Use `-Format SVG` when vector output is preferred. Use `-WhatIf` to preview the
render targets without writing files.

## Tooling Requirements

- Java must be available on `PATH` for PlantUML rendering.
- `PlantUmlJar` defaults to
  `C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar`.
- `DrawioExe` defaults to `C:\Program Files\draw.io\draw.io.exe`.

Override either path when a workstation uses a different install location:

```powershell
Convert-DiagramsToImages `
  -Path .\Database\Documentation `
  -PlantUmlJar 'D:\Tools\plantuml\plantuml.jar' `
  -DrawioExe 'D:\Tools\draw.io\draw.io.exe'
```
