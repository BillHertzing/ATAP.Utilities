# Release notes

## 0.1.5

- Add an explicit Stage 2 profile-retarget bypass for isolated validation.
- Require every mutating Stage 2 test to use that bypass, preventing tests from changing machine-wide PowerShell profile links.

## 0.1.4

- Load the complete SprintLifecycle public command surface in SprintEnd tests so clean promoted-module runs can mock every owned command.
- Stub machine-wide PowerShell profile deployment in all mutating Stage 2 tests and enforce that isolation with a static contract test.

## 0.1.0

- Initial empty scaffold.
