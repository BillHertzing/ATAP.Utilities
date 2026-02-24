# Rules Compendium

This file contains an overview of the Rules used within the ATAP.Utilites, its databases, and the Ace Commander application built from these rules.

## Overview

This file documents Rules and Rule Sets that make up modules and features.

Rules are created from Rule Primitives.

Rule Sets are created from Rules, and include a directed graph that control how execution flows from one Rule to another.

In order to define a feature or module in the ATAP.Utilities libraries or the Ace Commander application, a Rule Set is tagged with a feature identifier, which means that to implement the feature, the Ace Commander Module will include that Rule Set in its Build Set.

## The purpose of Rules, Rule Sets, and Build Sets

Here is a simplifying acronym to shorten the long name "Rules, Rule Sets and Build Sets". We will refer to all of those compositely as "RRSBS".

Everything in the ATAP.Utilities libraries and the Ace Commander application, and all bolt-on modules for Ace Commander, are built from RRSBS. There are RRSBS that define the Ace Commander GUI. There are RRSBS for all visual display elements, RRSBS for composing visual elements into screens / pages, and RRSBS for stiching the screens / pages together into logical workflows. All data elements in the ecosystem are defined by RRSBS. Hardware for the computer systems that run the backend and on which the front end application runs are defined by RRSBS. Build processes for creating .dll libraries, .so libraries, .exe programs, are all defined by RRSBS. All tests for all software component are defined by RRSBS. Test Processes are defined by RRSBS. The processes to create and maintain database schemas and data are defined by RRSBS, as are the instructions how to backup and restore these databases. Documentation about how the RRSBS work are themselves defined by RRSBS. In sum, every concept, every bit of data, every software tool, the complete Ace Commander application, interfaces to third-party hardware and software are all defined by RRSBS. Specific instantiations of the Ace Commander or ATAP.Utilities libraries owned / used by owners / users are stored in the Instantiations database, and that database, and its schema and operational processes are defined by RRSBS. The API's for the backend and how the Ace Commander front-end communicates with the back-end APIs are defined by RRSBS

## Rule Primitives

Rule Primitives are the building blocks from which a Rule is constructed.

TBD - a large set of Rule Primitives will be defined

## A single Rule definition in Backus–Naur Form (BNF)

TBD - express how the Rule Primitives can be legitimately combined.

## How Rules can be combined into Rule Sets

A Rule Set has a defined set of inputs, and a defined set of outputs. It may also cause the executing process to perform actions.

## How an instantiation processes inputs

An instantiation is a specific instance of a Build Set, itself made of Rule Sets, so the instantiation has a defined set of inputs to which it can react. Every Rule Set can be modeled as a state diagram. State Machine theory states that a system composed of multiple State Machines is itself a State Machine. The Build Set defines all of the Rule Sets and Rules, and so from a given starting state (the Initial State), the automata can execute through the directed graph of Rules, and eventually reach a final state with new output values. From this final state, changes to the inputs will again trigger execution through the directed graph of Rules, until a new final state is reached. This process repeats every time an input changes.

## Built-in Rules and reference Rule Sets, reference Build Sets, and reference instantiation

for the purpose of this paragraph 'reference' is used in the same fashion that manufactors of a computer chip will create a circuit board using that chip, and call the board a 'reference implementation'. Similarly, the following paragraph mentions 'reference Rule Sets' and 'reference Build Sets'. These are the reference implementations of a Rule Set that implements a module or feature, and a Build Set that creates a complete frontend and backend system.

ATAP.Utilities and Ace Commander have an enormous set of pre-defined Rules. From these, a large number of reference Rule Sets have been pre-defined. The reference Build Set for ATAP.Utilities creates the ATAP.Utilities libraries and databases, and the reference Build Set for Ace Commander assembles the Built-in and custom Rule Sets to create the reference implementation of Ace Commander.

## Custom rules and Rule Sets

All owners / users of Ace Commander can contribute to the ecosystem of bolt-on modules for Ace Commander. These bolt-ons are defined by a Rule Set. A uniquely new Rule Set can be created to form a completely new module. Or, an existing module can be functionally or performance enhanced by expanding on the Rules in its Rule Set. As long as a new Rule Set has a superset of the original Rule Set's inputs, and has the same or a superset of the originals' outputs, the new Rule Set can replace the original Rule Set and be used to create a new version of the original Build Set (one in which the original Rule Set has been replaced by the new Rule Set).

## Feature / Module / Rule Set

This section is where the nomenclature and taxonomy of the ATAP.Utilities and Ace Commander are specified, and the individual Rules that make up each Rule Set are referenced.

During the design phase of this project, this document will serve as the 'source of truth' for the nomenclature and taxonomy of the ATAP.Utilities and Ace Commander Rule Sets and this feature / module tagging. As the program / project evolves, the actual Rules and Rule Sets stored in the Ace Commander databases will slowly take over the 'source of truth' , and this document will be updated by Ace Commander to keep it in sync with the databases contents. MOdules and Rule Sets can be hierarchly decomposed into smaller functional units. The Module defintions in the following sections will demonstrate this by listing submodules under 'higher' modules.

### Ace Commander browser-based User Interface

This Rule Set will create the browser-based user interface to the Ace Commander program. Much of this Rule Set will be modules that define the visual look and feel of the application. Other modules will define how the application is instantiated for various browsers. Another set of modules will define how Ace Commander front-end communicates to the backend systems.

#### Ace Commander - A Blazor Web App using Auto render mode

This Rule Set defines the overall technology being used for the Ace Commander browser-based User Interface. This will incorporate the DotNet project template for "Blazor Web App" in the repository. Ace Commander will use the InteractiveAuto mode.

The repository will contain two projects

```text
AceCommander/                    ← Server project (ASP.NET Core host)
├── Components/
├── Program.cs
└── AceCommander.csproj

AceCommander.Client/             ← Client project (runs in browser via WASM)
├── Pages/
├── Program.cs
└── AceCommander.Client.csproj
```

### AI coding agents instruction files

This Rule Set defines how AI coding assistant instructions are organized and shared between GitHub Copilot and Claude Code within a repository, maintaining a single source of truth while supporting each tool's native file structure.

#### Rule: Central Global Instructions File

**Purpose:** Establish a single source of truth for project-wide AI instructions.

**Implementation:** Maintain `.github/copilot-instructions.md` as the authoritative file containing global repository instructions. This file is read natively by GitHub Copilot and will be referenced by Claude Code through import directives.

#### Rule: Claude Root Instructions Import

**Purpose:** Enable Claude Code to read global instructions without duplicating content.

**Implementation:** Create a file named `CLAUDE.md` (uppercase) in the repository root containing a single import directive: `@.github/copilot-instructions.md`. This approach prevents VS Code from injecting the same content twice (once from Copilot's native read, once from Claude's read) while allowing both tools to access the same instructions.

#### Rule: Language-Specific Instructions Directory

**Purpose:** Centralize language-specific coding rules and conventions.

**Implementation:** Store language-specific instruction files in `.github/instructions/` directory using the naming pattern `<language>.instructions.md` (e.g., `python.instructions.md`, `typescript.instructions.md`, `CSharp.instructions.md`). These files use GitHub Copilot's `applyTo` frontmatter field to specify file patterns.

#### Rule: Claude Rules Directory Structure

**Purpose:** Provide Claude Code with its native directory for language-specific rules.

**Implementation:** Create a `.claude/rules/` directory in the repository root. This directory will contain rule files that reference the language-specific instructions from `.github/instructions/`.

#### Rule: Language Rule Import Pattern

**Purpose:** Share language-specific instruction content between Copilot and Claude Code without duplication.

**Implementation:** For each language instruction file in `.github/instructions/`, create a corresponding file in `.claude/rules/` with:

- Filename: `<language>.md` (e.g., `python.md`, `typescript.md`)
- Frontmatter: `paths: ["**/*.<ext>"]` to specify which files the rule applies to
- Body: `@../../.github/instructions/<language>.instructions.md` to import the shared content

#### Rule: CLAUDE.md Naming Convention

**Purpose:** Ensure cross-platform compatibility for Claude Code instruction files.

**Implementation:** Use uppercase `CLAUDE.md` for the root instruction file. While Windows NTFS is case-insensitive, Linux filesystems (WSL2, containers) require exact case matching. Using uppercase consistently prevents issues across development environments.

#### Rule: Avoid Root Instruction Symlinks

**Purpose:** Prevent duplicate instruction injection in VS Code with both Copilot and Claude Code active.

**Implementation:** Do not create a symlink for `CLAUDE.md` pointing to `.github/copilot-instructions.md`. Instead, use the `@import` directive syntax. Symlinks cause VS Code to read the same content twice — once through Copilot's native path and once through Claude's, resulting in redundant context usage.

#### Rule: Frontmatter Format Differentiation

**Purpose:** Properly scope language-specific rules for each AI tool.

**Implementation:**

- GitHub Copilot files use: `applyTo: "**/*.py"`
- Claude Code files use: `paths: ["**/*.py"]`

When maintaining separate but related files, ensure each uses the appropriate frontmatter format. If symlinking instead of importing (not recommended), be aware that Claude Code will ignore `applyTo` fields and treat the rule as applying to all files.

#### Rule: Single Source Content Pattern

**Purpose:** Maintain one authoritative version of each instruction set.

**Implementation:** Each distinct instruction topic (global, per-language, per-framework) exists in exactly one file within `.github/`. All other AI tool-specific files (`CLAUDE.md`, `.claude/rules/*.md`) use import directives to reference this source, never duplicating the actual instruction content.

#### Rule: Local Override Exclusion

**Purpose:** Allow developers personal AI instruction customizations without committing them.

**Implementation:** Ensure `.gitignore` includes `CLAUDE.local.md` and `.claude/CLAUDE.local.md`. These files allow individual developers to add personal instructions that override or supplement project instructions without affecting other team members.

#### Example Repository Structure

```text
repo-root/
├── CLAUDE.md                           ← Contains: @.github/copilot-instructions.md
├── .gitignore                          ← Includes: CLAUDE.local.md
├── .github/
│   ├── copilot-instructions.md         ← Single source: global instructions
│   └── instructions/
│       ├── python.instructions.md      ← applyTo: "**/*.py"
│       ├── typescript.instructions.md  ← applyTo: "**/*.ts,**/*.tsx"
│       ├── CSharp.instructions.md      ← applyTo: "**/*.cs"
│       └── markdown.instructions.md    ← applyTo: "**/*.md"
└── .claude/
    └── rules/
        ├── python.md                   ← paths: ["**/*.py"], body: @../../.github/instructions/python.instructions.md
        ├── typescript.md               ← paths: ["**/*.ts","**/*.tsx"], body: @../../.github/instructions/typescript.instructions.md
        ├── CSharp.md                   ← paths: ["**/*.cs"], body: @../../.github/instructions/CSharp.instructions.md
        └── markdown.md                 ← paths: ["**/*.md"], body: @../../.github/instructions/markdown.instructions.md
```
