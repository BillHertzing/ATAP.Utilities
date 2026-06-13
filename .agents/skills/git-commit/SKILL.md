---
name: git-commit
description: "Create intentional git commits using Conventional Commits. Use when the user asks to commit completed work or when a task explicitly requires committing."
---

# Git Commit Skill

Use native Git and PowerShell commands. Do not prefix commands with `rtk`; RTK guidance is archived and inactive until installation is verified.

## Workflow

1. Inspect repository state:

```powershell
git status --short
git diff --stat
git diff
git diff --staged
git log --oneline -5
git branch --show-current
```

2. Identify task-owned files and unrelated dirty files. Leave unrelated files unstaged.

3. Stage the task-owned files explicitly:

```powershell
git add -- <path> [<path>...]
```

4. Compose a Conventional Commits message:

```text
<type>(<scope>): <imperative summary>

[optional body explaining why]
```

Use `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `style`, `perf`, or `ci`. Keep the subject line at or under 72 characters.

5. Commit:

```powershell
git commit -m "<subject>" -m "<body if present>"
```

6. Report the commit hash, commit message, staged file count, and files left unstaged.

## Guardrails

- Never commit secrets, `.env` files, private keys, `node_modules/`, `bin/`, or `obj/` outputs.
- Never use `git reset --hard`, `git clean`, or checkout/restore to discard user work unless the user explicitly asks.
- If unrelated files are dirty, mention them and leave them alone.
