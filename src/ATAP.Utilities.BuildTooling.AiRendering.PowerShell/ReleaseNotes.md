# Release notes

## Unreleased

- `Build-AGENTSPerRepository` composes a third region, `<!-- AI-AGENT-CODEX -->`,
  appending SharedVSCode `.ai/core/agent-specific/codex.md` after `AI-CORE`
  (Task 13.76.b). Adds the `-CodexAgentInstructionPath` parameter and the
  `HasCodexAgentInstructions` / per-repo `HasCodexBlock` result fields. The block is
  omitted when the canonical file is absent or whitespace-only, so existing callers
  compose unchanged. This replaces the direct manifest render that clobbered the
  composed carrier on 2026-07-25.
## 0.1.7 (source candidate, not installed)

- Add `Build-DocumentationOverview`: catalogs tracked documentation across one or more
  repository roots and writes a catalog CSV, an unresolved-link CSV, a JSON summary and a
  statistics page under `_generated/DocumentationOverview` (SC-0033). Read-only;
  supports -WhatIf.
- Protect maintained output destinations, require PSFramework, retain headers for
  empty catalogs, separate Git diagnostics from file/revision data, and support
  relative links with angle-bracket destinations while excluding absolute URI schemes.
- Windows source verification passed 31 cases: 27 command cases and four child-module
  contract cases. Built-package and installed-consumer acceptance are separate gates;
  this entry does not claim publication or installation.

## 0.1.2

- Resolve stable/sprint worktree placeholders in the full Claude Code
  user-global overlay, omit sprint entries at the End boundary, and reject any
  unresolved worktree token before writing user settings.

## 0.1.0

- Initial AiRendering extraction from the compatibility parent.
- Adds eleven commands and the FailureAcknowledged JSON schema.
- Preserves the separate SC-0246 ownership boundary for SharedVSCode `.ai/tools`.
