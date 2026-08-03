# Security PowerShell module architecture

## Frozen target

The Security family uses independently versioned modules with compatibility re-exports:

| Module | Target owner | Current state |
| --- | --- | --- |
| `ATAP.Utilities.Security.Powershell` | Family umbrella and residual host/vault administration | Re-exports PKI and Secrets children |
| `ATAP.Utilities.Security.PKI.PowerShell` | CA, certificate, DN, protected key/passphrase, trust, and certificate discovery | Extracted; nineteen commands |
| `ATAP.Utilities.Security.Secrets.PowerShell` | Secrets compatibility umbrella | Currently owns/re-exports the shipped Bitwarden surface pending the child split |
| `ATAP.Utilities.Security.Secrets.Bitwarden.PowerShell` | Bitwarden Password Manager and Secrets Manager provider operations | Target child; current implementation remains in the Secrets compatibility module |
| `ATAP.Utilities.Security.Secrets.Hashicorp.PowerShell` | Hashicorp Vault provider operations | Target child; no active implementation moved yet |
| `ATAP.Utilities.Security.Secrets.PSSecrets.PowerShell` | Microsoft SecretManagement/SecretStore provider operations | Target child; current residual vault administration remains in the family umbrella |

The intermediate state is intentional: shipped capabilities have one explicit current owner while
the target owner is frozen. No function is duplicated between PKI and Secrets, and Secrets has no
dependency on PKI.

## Compatibility map

All nineteen PKI names remain in the Security umbrella manifest. `module.preamble.ps1` imports the
PKI and Secrets children in module scope, and the umbrella exports the child commands under its own
module identity. The repository build includes this preamble in the generated package, so source
and packaged behavior follow the same contract.

Existing consumers may continue importing `ATAP.Utilities.Security.Powershell`. New PKI consumers
should import `ATAP.Utilities.Security.PKI.PowerShell` directly. The umbrella remains in re-export
mode until a refreshed consumer map proves no consumer relies on umbrella-only imports.

## Version and release order

Each child owns `version.json` with `pathFilters: ["./"]`. Minimum-version dependencies are used,
not exact lockstep versions. Release order is PKI/Secrets child first, then the umbrella after the
child reaches the same feed tier. BuildMaster uses the consolidated `ATAP.Utilities-PowerShell`
application with module-name injection.

## Security boundaries

- Importing any family module performs no certificate, secret, network, or filesystem mutation.
- Public functions contain no top-level executable code.
- Secret values are resolved by SecretName only at the authenticated or decrypting leaf.
- CA/signing authority, private keys, PFX files, passphrases, and rendered service configuration
  containing secrets stay outside source control.
- Tests and evidence use synthetic data and metadata-only thumbprints, serials, hashes, and status.
