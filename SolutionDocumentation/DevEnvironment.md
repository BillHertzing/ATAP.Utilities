# Developer Environment

## Purpose

This document captures workstation and shell behaviors that affect day-to-day development in this repository. It focuses on the parts of the environment that routinely cause avoidable friction: spell-check customization, PowerShell history behavior, formatter conflicts, module installation locations, npm global tool paths, NTFS junction usage, and the differences between PowerShell hosts launched inside and outside Visual Studio Code.

## CSpell

### Default user dictionary location

On Windows, the default user dictionary used by cspell is typically stored at:

```text
%USERPROFILE%\.cspell\cspell-dict.txt
```

On Linux and macOS, the corresponding default is typically:

```text
~/.cspell/cspell-dict.txt
```

This default can be overridden by repository or workspace configuration through `dictionaryDefinitions` and `dictionaries` entries in a cspell configuration file.

### Inspecting the active dictionary set

These commands are useful when diagnosing cspell behavior:

```powershell
cspell list-dictionaries
cspell trace atap
cspell --config .vscode/cspell.json trace atap
```

`cspell trace` is the fastest way to determine whether a word is accepted by the user dictionary, a custom dictionary, or an imported package dictionary.

### ignoreRegExpList patterns

Use `ignoreRegExpList` when the text is not a normal word and should be ignored by pattern rather than added to a dictionary. This is the better approach for tokens such as GUIDs, hashes, base64 payloads, or tool-specific identifiers.

Example:

```json
{
  "version": "0.2",
  "ignoreRegExpList": ["/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/", "/(?:[A-Fa-f0-9]{2}){16,}/", "/(?:[A-Za-z0-9+\\/]{20,}={0,2})/"]
}
```

Recommended use of these examples:

- GUID-like identifiers: `"/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/"`
- Long hexadecimal material such as hashes, tokens, or signatures: `"/(?:[A-Fa-f0-9]{2}){16,}/"`
- Long base64-like payloads: `"/(?:[A-Za-z0-9+\\/]{20,}={0,2})/"`

`ignoreRegExpList` can be applied globally or inside `overrides` blocks when the pattern should only be ignored for specific file types or paths.

## PSReadLine History

### Host-specific history files

PSReadLine stores history per host, not per executable. That means a regular `pwsh` console and the Visual Studio Code PowerShell host do not share the same history file unless configured to do so.

Typical host names:

- `ConsoleHost` for standalone PowerShell terminals
- `Visual Studio Code Host` for the PowerShell extension inside Visual Studio Code

The effective file can be inspected with:

```powershell
$Host.Name
(Get-PSReadLineOption).HistorySavePath
```

### Shared history across hosts

To share command history across hosts, configure the same history path in each host profile:

```powershell
Set-PSReadLineOption -HistorySavePath "$HOME\.pwsh_shared_history.txt"
```

This is the simplest way to make both `ConsoleHost` and the Visual Studio Code host append to the same plain-text history file.

### Timestamp and hostname capture

PSReadLine history files are plain command history, not audit logs. If you want timestamped entries and machine identity, record them separately. A common pattern is to subscribe to `PSReadLine.OnCommandExecuted` and append structured entries to a second file.

Example pattern:

```powershell
Register-EngineEvent -SourceIdentifier PSReadLine.OnCommandExecuted -Action {
  $timestamp = Get-Date -Format 'o'
  $hostname = $env:COMPUTERNAME
  $command = $Event.MessageData.CommandLine
  Add-Content -Path "$HOME\.pwsh_structured_history.log" -Value "$timestamp`t$hostname`t$command"
} | Out-Null
```

Important constraint:

- A structured history file that includes timestamps and hostnames is useful for audit and analysis.
- That same structured file should not replace the PSReadLine history file, because PSReadLine expects raw commands, not decorated records.

The practical pattern is to keep two files:

- One PSReadLine-compatible history file for recall and reverse search
- One structured log for diagnostics and traceability

### Excluding sensitive commands from history

If secrets may appear in command lines, do not rely on default history behavior. Instead, disable default history persistence and implement a filtered save path.

Example direction:

```powershell
Set-PSReadLineOption -HistorySavePath $null
```

Then handle `PSReadLine.OnCommandExecuted` yourself and skip commands that match patterns such as:

- `bw unlock`
- `Get-BitWardenSecret`
- commands that contain `token`, `secret`, or `password`
- commands that assign secret-bearing environment variables

This is safer than storing everything and trying to sanitize later.

## PowerShell Formatting

### Prefer PSScriptAnalyzer for PowerShell formatting

Do not rely on Prettier to format `.ps1` or `.psm1` files. Prettier is not PowerShell-aware and can break syntactic constructs that are valid in PowerShell.

One concrete example is the PowerShell short-circuit operator `-&&`, which Prettier may incorrectly rewrite as `- &&`, producing invalid code.

Recommended approach:

- Exclude PowerShell files from Prettier
- Use the PowerShell extension and PSScriptAnalyzer formatting instead

Example `.prettierignore` entries:

```text
*.ps1
*.psm1
*.psd1
```

### Inline formatting suppression

The PowerShell extension respects PSScriptAnalyzer formatting suppression comments.

Suppress a single line:

```powershell
$secure = Get-Credential # <# PSScriptAnalyzerDisableFormatting #>
```

Suppress a block:

```powershell
# <# PSScriptAnalyzerDisableFormatting #>
$MyComplexHash = @{
  key1 = 'value1'
  veryLongKeyName = 'value2'
}
# <# PSScriptAnalyzerEnableFormatting #>
```

Use suppression sparingly. It is appropriate when formatting would reduce readability or break intentionally aligned data structures.

## PowerShell Module Paths on Windows

### Global all-users path versus version-specific path

For PowerShell 7+, two paths are commonly confused:

```text
C:\Program Files\PowerShell\Modules
C:\Program Files\PowerShell\7\Modules
```

They do not serve the same purpose.

- `C:\Program Files\PowerShell\Modules` is the shared all-users module path intended for reusable modules available across PowerShell 7.x versions.
- `C:\Program Files\PowerShell\7\Modules` is version-specific and tied to that runtime installation.

Recommended guidance:

- Install organization or developer global modules to `C:\Program Files\PowerShell\Modules` when they are meant to be available to all PowerShell 7.x hosts.
- Treat `C:\Program Files\PowerShell\7\Modules` as runtime-specific and avoid using it as the normal target for shared module deployment.

Inspect the active search path with:

```powershell
$env:PSModulePath -split ';'
```

## npm Global Tools and NTFS Junctions

### npm global executable path on Windows

Recent npm versions do not provide `npm bin -g`. Instead, use the configured prefix:

```powershell
npm config get prefix
```

On Windows, globally installed executables are typically placed directly in that prefix directory, which is usually:

```text
%APPDATA%\npm
```

That usually expands to something like:

```text
C:\Users\<user>\AppData\Roaming\npm
```

This path should be on `PATH` if global CLI tools such as `cspell` are expected to be callable from terminals and tasks.

### Junctions versus symbolic links

On Windows, a junction is often the simplest choice when redirecting one directory tree to another local directory.

Typical PowerShell form:

```powershell
New-Item -ItemType Junction -Path 'C:\LinkPath' -Target 'D:\ActualTarget'
```

Use a junction when:

- The target is a directory
- The target is on a local NTFS volume
- You want broad compatibility with Windows tooling

Use a symbolic link when:

- You need link semantics beyond local-directory redirection
- You need file links rather than directory links
- The scenario requires behaviors junctions do not provide

Operational notes:

- Junctions are for directories only.
- Symbolic links may require elevated privileges or Developer Mode, depending on system policy.
- Many Windows workflows still handle junctions more predictably than symbolic links.

## Visual Studio Code Host Differences

### Profile selection differs by host

The PowerShell host determines which current-user current-host profile runs.

Typical examples:

- Standalone `pwsh` terminal uses `ConsoleHost`
- PowerShell inside Visual Studio Code uses `Visual Studio Code Host`

That means different host-specific profile files are used.

Common examples:

- `Microsoft.PowerShell_profile.ps1` for `ConsoleHost`
- `Microsoft.VSCode_profile.ps1` for the Visual Studio Code host

If setup logic should apply in both places, either duplicate the relevant configuration or dot-source the shared profile from the host-specific one.

### Integrated terminal versus externally launched VS Code

Visual Studio Code inherits environment variables from the process tree that launched it.

This leads to an important distinction:

- If `pwsh` is started directly, environment variables set in that shell exist only in that process and its children.
- If Visual Studio Code is launched from that shell, the integrated terminal inherits those values.
- If Visual Studio Code is launched from the Start menu or another detached GUI path, it does not inherit process-scoped variables from a separate interactive shell.

This is why values such as `$env:BW_SESSION` often appear to "flow into VS Code" only when VS Code was launched from the shell that created them.

### Why detached agent shells do not inherit interactive variables

Detached agent or task shells are commonly created by a different parent process than the interactive terminal you are looking at. Because of that, process-scoped environment variables are absent unless they were stored somewhere broader.

Practical consequences:

- A process-scoped `$env:BW_SESSION` set in one interactive shell should not be expected to exist in another unrelated shell.
- Tasks, agent shells, and editor-spawned terminals may differ depending on how the editor itself was launched.
- If a value must be consistently visible across shells, prefer deliberate startup/profile logic or a broader environment variable scope, and do so with care for secret-bearing values.

For debugging these issues, inspect both the host and the current history path:

```powershell
$Host.Name
$PROFILE | Format-List *
(Get-PSReadLineOption).HistorySavePath
```

---

## Appendix: Launch Configuration Strategies

_Migrated from `_Planning/Explainers/MultiTFMConfigurationTaskandLaunchOptions.md`. Captures the five launch.json design options considered for AceCommander multi-TFM × multi-build-configuration scenarios. **The project's chosen approach is Option B (`${input:}` pickers).**_

**Context.** AceCommander (`AceCommander.Server`, `AceCommander.Client`) has three base
VS Code launch configurations (`Launch-Server`, `Launch-Server-With-Debugging`,
`Launch-Server-With-Browser-Debug`). Each needs to span:

| Axis                | Values                                 |
| ------------------- | -------------------------------------- |
| TFM                 | `net8.0`, `net9.0`, `net10.0`          |
| Build Configuration | `Debug`, `Release`, `ReleaseWithTrace` |

That is 9 variants per base config — 27 launch combinations total. The options below were
evaluated against this matrix.

### Option A — Explicit Combinatorial Entries (27 configs)

Name each config explicitly, e.g., `AceCommander-Launch-Server [Debug/net10.0]`.

- **Pros:** Fully discoverable in the Run & Debug dropdown; no prompts; works with Compounds.
- **Cons:** 27 entries — very noisy; high maintenance burden; tedious to add a new TFM.

### Option B — VS Code Input Variables (`${input:}`) — **CHOSEN**

Define an `inputs` array in `launch.json` with `pickString` for each axis. Reference
them in the `program` path and (critically) in the `preLaunchTask` name.

```jsonc
"program": "${workspaceFolder}/AceCommander.Server/bin/${input:buildConfig}/${input:tfm}/AceCommander.dll",
"inputs": [
  { "id": "tfm",         "type": "pickString",
    "description": "Target Framework Moniker",
    "options": ["net10.0", "net9.0", "net8.0"], "default": "net10.0" },
  { "id": "buildConfig", "type": "pickString",
    "description": "Build Configuration",
    "options": ["Debug", "Release", "ReleaseWithTrace"], "default": "Debug" }
]
```

**Key constraint:** The `preLaunchTask` must also be parameterized to forward the
chosen values to `dotnet build` as `/p:Configuration=...` and `/p:TargetFramework=...`
MSBuild arguments.

- **Pros:** Only 3 launch configs; trivial to add new TFMs / configs; self-documenting.
- **Cons:** Two picker prompts on every F5; no "remember last choice"; the
  parameterized `preLaunchTask` is the non-trivial implementation work.

### Option C — Environment Variables (`${env:ACE_TFM}`, `${env:ACE_CONFIG}`)

Set two env vars in the shell before launching; reference them in `launch.json`.

- **Pros:** Zero changes to `launch.json` per combination; scriptable / CI-friendly.
- **Cons:** Must set vars before each VS Code session — easy to forget; env vars are
  process-scoped (must be set BEFORE VS Code starts); not discoverable in UI.

### Option D — `.env` File + `envFile` Property

Point `launch.json` at a `.env` file via `"envFile": "${workspaceFolder}/.vscode/ace.env"`.
Keep multiple `.env` files (per combination) and copy the desired one to `ace.env`.

- **Pros:** No prompts at launch; `.env` can be gitignored for per-dev overrides;
  works well when active combination changes infrequently.
- **Cons:** Two-step workflow (edit file, then launch); not discoverable.

### Option E — Pre-launch Task Variants

Keep 3 launch configs but define 9 build tasks (one per TFM/config combination).
Switching combinations means changing the `preLaunchTask` name inside the launch config.

- **Pros:** Launch configs stay small; build and launch cleanly separated.
- **Cons:** Task list grows to 9+ entries; `preLaunchTask` must be edited manually
  in JSON to switch.

### Recommendation Summary

| Best for…                                               | Choose                      |
| ------------------------------------------------------- | --------------------------- |
| Frequent switching between combos with minimal friction | **B (Input Variables)**     |
| Stable single active combo that rarely changes          | **D (.env file)**           |
| Scripted / CI workflows                                 | **C (Env vars)**            |
| Maximum discoverability, no tooling changes             | **A (Explicit 27 configs)** |

**Option B is the project's chosen direction for interactive development.** The main
implementation work is parameterizing the pre-launch build task so it receives
`${input:buildConfig}` and `${input:tfm}` and forwards them to `dotnet build` as MSBuild
properties.
