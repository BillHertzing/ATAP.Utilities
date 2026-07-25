# Release notes

## 0.1.6

- `Save-SprintWorkSession` now asserts the conversation archive's **contents** before
  reporting `ConversationArchiveCreated = $true` (Task 13.76.d). Previously the presence
  of the `.7z` file alone was treated as success, so a `7z a` that produced a zero-entry
  archive was recorded as a saved conversation. The archive must now list at least one
  entry and must contain the rollout JSONL by name; either failure is terminating.
- Note for anyone porting the patch published in
  `_Planning/InformationForTheFuture/CodexMisstepFixes/SaveSprintWorkSession-EmptyArchive-Defect.md`:
  that version's entry-count regex (`^\s*\d+\s+\S+`) never matches real `7z l -ba`
  output, whose lines begin with an ISO date, and would therefore have thrown on every
  checkpoint. The shipped implementation counts non-empty listing lines instead.

## 0.1.5

- Add an explicit Stage 2 profile-retarget bypass for isolated validation.
- Require every mutating Stage 2 test to use that bypass, preventing tests from changing machine-wide PowerShell profile links.

## 0.1.4

- Load the complete SprintLifecycle public command surface in SprintEnd tests so clean promoted-module runs can mock every owned command.
- Stub machine-wide PowerShell profile deployment in all mutating Stage 2 tests and enforce that isolation with a static contract test.

## 0.1.0

- Initial empty scaffold.
