# Release notes

## 0.1.2

- Promote verified Root and TrustedPublisher distribution into `Install-PkiTrustCertificate`.
- Promote stdin-only, SecretName-backed PKCS#12 export into `New-PkiCertificatePfx`.
- Promote the successful Windows Authenticode issuance path into the organization-parameterized
  `New-PkiWindowsCodeSigningCertificate` command.
- Keep RSA signing keys non-exportable, require explicit private-key readers, resolve the root
  passphrase by SecretName, and transfer public certificate data only.
- Retain commissioning, Inedo cutover, and certificate-repair scripts as historical Sprint
  evidence rather than product APIs.

This version is source-prepared only. No module was rebuilt, packaged, published, promoted, or
installed as part of this documentation and reuse pass.

## 0.1.1

- Replace Windows PKI-module certificate imports with PowerShell 7 native .NET store operations.
- Add idempotent TrustedPublisher distribution for code-signing certificates.

## 0.1.0

- Extract the approved eighteen-command PKI boundary from the Security umbrella.
- Preserve all moved command names through umbrella re-exports.
- Replace undefined-variable, no-op, and `Invoke-Expression` implementations.
- Add cryptographically secure key/passphrase generation and explicit overwrite gates.
- Add OpenSSL CA, CSR, server-authentication, code-signing, data-encryption, and CRL profiles.
- Add idempotent Windows trust and leaf-certificate installation with EKU checks and
  non-exportable PFX private keys.
- Add source/package compatibility tests and secret-redaction/security contracts.

No live CA, certificate, trust store, endpoint, signing authority, package feed, or installed
module state is created by this source release.
