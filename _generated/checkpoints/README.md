# Checkpoint: Bitwarden Password-Manager (bw) API-key service-login approach

Captured 2026-05-30 on Sprint-0007 branch, as a recovery point BEFORE the pivot to
Bitwarden Secrets Manager (bws). This preserves the session work that made service-account
login use `bw login --apikey` (2FA-exempt) instead of email/password.

- `bw-apikey-PasswordManager-architecture.patch` — this session's deltas to the four
  dead-end files; re-apply from repo root with:
      git apply _generated/checkpoints/bw-apikey-PasswordManager-architecture.patch
  Files: Get-BitWardenCredential.ps1, Update-ServiceAccountBWCredentialFile.ps1,
  Initialize-ServiceAccountBitwardenSession.ps1, SolutionDocumentation/NewComputerSetup.md (section 9.4).
- `NewOrganizationSetup.bw-version.md` — reference copy of the first (bw-model) org doc,
  kept because the live file is being rewritten for the bws architecture.
