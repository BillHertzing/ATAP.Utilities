# Release notes

## Unreleased

- `Build-AGENTSPerRepository` composes a third region, `<!-- AI-AGENT-CODEX -->`,
  appending SharedVSCode `.ai/core/agent-specific/codex.md` after `AI-CORE`
  (Task 13.76.b). Adds the `-CodexAgentInstructionPath` parameter and the
  `HasCodexAgentInstructions` / per-repo `HasCodexBlock` result fields. The block is
  omitted when the canonical file is absent or whitespace-only, so existing callers
  compose unchanged. This replaces the direct manifest render that clobbered the
  composed carrier on 2026-07-25.

## 0.1.2

- Resolve stable/sprint worktree placeholders in the full Claude Code
  user-global overlay, omit sprint entries at the End boundary, and reject any
  unresolved worktree token before writing user settings.

## 0.1.0

- Initial AiRendering extraction from the compatibility parent.
- Adds eleven commands and the FailureAcknowledged JSON schema.
- Preserves the separate SC-0246 ownership boundary for SharedVSCode `.ai/tools`.
