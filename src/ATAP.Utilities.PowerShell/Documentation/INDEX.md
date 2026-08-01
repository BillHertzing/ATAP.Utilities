# ATAP.Utilities.PowerShell — Documentation Index

This folder holds the concept and reference documentation for the
`ATAP.Utilities.PowerShell` module. It is the narrative counterpart to
[../INDEX.md](../INDEX.md), which indexes the module's scripts themselves.

Use this page to find the right document; use the module script index to find the right
function.

## Concept documentation

| Document | Covers |
| -------- | ------ |
| [ReadMe.md](ReadMe.md) | Profiles as the environment a PowerShell process executes in, the IAC-owned profile payloads, machine and user profile scopes, machine names and roles, nodes, testing, packaging, and a per-function narrative for the module's public commands. |
| [GettingStarted.md](GettingStarted.md) | The five-tier lifecycle flow — Experimental, Development, Integration, QA, Stable — and the promotion guidance that goes with it. |
| [Powershell Useage in ATAP.Utilities.md](Powershell%20Useage%20in%20ATAP.Utilities.md) | House conventions for writing PowerShell here: Desktop 5 versus Core 7, settings, `Join-Path` over path strings, `[Environment]` over `$env`, `Out-File` over `Get-Content`, file encoding defaults, cross-platform environment variables, classes in modules, LINQ, and logging. |

## Function reference

| Document | Function |
| -------- | -------- |
| [Write-ArrayIndented.md](Write-ArrayIndented.md) | [`Write-ArrayIndented`](../public/Write-ArrayIndented.ps1) — formats an array as an indented, recursive string representation for diagnostic display. |

Functions without a page here are documented by their comment-based help; run
`Get-Help <FunctionName> -Full` against an imported module, or read the `.ps1` file
listed in [../INDEX.md](../INDEX.md).

## Diagrams

| File | Covers |
| ---- | ------ |
| `GlobalSettingsRelationships.drawio` | Draw.io source for the relationships among `$global:configRootKeys`, `$global:settings`, and the ATAP.IAC host-settings fragments that populate them. |

## Folder conventions

- `toc.yml` lists the documents published by the documentation build. Add an entry there
  when adding a page to this folder.
- Diagram sources stay in this folder alongside the document that embeds them. Pass a
  Markdown file to `Convert-DiagramsToImages` to render its diagrams to images.
- Markdown here is linted against the repository `.markdownlint.yml`.
