# Release notes

## 0.1.4 — source candidate (unpublished)

- Prepare fixed handled-error messages and sanitized error records for the BWS
  token reader and secret-read functions, limiting their own error and log payloads.
- Resolve token-reader paths per pipeline record so property-bound directory and
  purpose values are processed for each record.
- Source-only fake tests passed; internal PowerShell error history, real PSFramework
  sinks, package promotion, installation, and consumer behavior remain unverified.
- This version is an unreserved candidate. Post-commit NBGV resolution and feed
  collision checks have not been performed.

## 0.1.0

- Initial Secrets extraction from the BuildTooling compatibility parent.
