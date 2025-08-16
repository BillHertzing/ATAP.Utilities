---
applyTo: "**/AppData/Roaming/Code/User/snippets/*.json"
---

# Snippet Guidelines

Snippet instructions cannot be generated like instruction files for other languages, because the location of the language specific process files is outside the base repository. Instead, the snippet instructions are generated from the snippets files in the user's AppData folder.

The snippets files are located in the user's AppData folder, specifically under `C:\Users\<username>\AppData\Roaming\Code\User\snippets\`. The snippets files are named according to the language they support, such as `powershell.json` for PowerShell snippets; sql.json for SQL snippets. The filenames are case-sensitive; they should all be lowercase.
