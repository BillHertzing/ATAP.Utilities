# ContentSummary module index

- `public/Get-ContentSummary.ps1` — loopback-only HTTPS client for the versioned AceOutpost
  gather-content REST endpoint with ambient Windows authentication, complete response
  validation, safe error/correlation mapping, and no-fabrication behavior.
- `public/Invoke-ContentSummaryHarvest.ps1` — deterministic source observation,
  classification/redaction, summary generation, and canonical repository submission.
- `private/*.ps1` — ContentSummary hashing, source normalization, redaction, safe error,
  and canonical harvest-envelope helpers.
- `tests/Unit/Get-ContentSummary.Tests.ps1` — isolated contract tests with mocked REST and
  recorder boundaries, including real, empty, error, cancellation, and invalid-response cases.
- `tests/Unit/Invoke-ContentSummaryHarvest.Tests.ps1` — isolated harvester contract,
  security, replay, and failure tests.
- `tests/Package/ContentSummaryPackageOnly.Tests.ps1` — builds and expands the immutable
  package outside Dropbox, then verifies its flattened function surface and runtime inventory path.
- `README.md` — configuration, security boundary, and usage notes.
- `ReleaseNotes.md` and `version.json` — version history and package version source.
