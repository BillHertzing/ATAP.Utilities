# AGENTS.md

## Headroom Workflow

- Use Headroom MCP tools before reasoning over large build/test logs, long search results, large JSON arrays, or long generated traces.
- Start with `headroom_compress` when the task is triage, summarization, or pattern-finding across bulky output.
- Use `headroom_retrieve` when exact line-level evidence, full raw output, or literal values are needed.
- Do not compress source files before editing unless the task is broad exploration or summarization; exact edits still require exact file reads.
- If `headroom_retrieve` fails, assume the local or proxy retention window may have expired and reacquire the original content.


## RTK Status

RTK command-prefix guidance is archived and inactive because `rtk` is not installed on development computers. Run native PowerShell, Git, dotnet, node, and other tool commands directly unless a future task explicitly reinstates RTK after installation verification.

Archived guidance and restoration gates are recorded in `SharedVSCode/SolutionDocumentation/RTK-Instruction-Archive.md`.
