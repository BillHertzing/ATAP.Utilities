# BWS ReadOnly Service-Account Bootstrap

## Scope

The bootstrap surface is limited to `SvcBuildMaster`, `SvcProGet`, and
`SvcSQLServer`. It always targets the pre-authorized `CI-Shared` project and writes
the `CommonCIForBitwardenReadOnly` DPAPI slot. `SvcSeq`, `SvcParityAudit`,
`ansibleAdmin`, foreign-host accounts, and arbitrary identities are rejected before
mutation. There is no ReadWrite fallback.

The commands do not create accounts, passwords, certificates, private-key ACLs, logon
rights, Bitwarden grants, or access tokens. Those are separately authorized prerequisites.

## Required preconditions

- The operator has an existing `CI-Shared` ReadOnly access token as a `SecureString`.
- Each approved account has a document-encryption certificate whose simple name exactly
  equals its SAM account name.
- The envelope creator receives only the public `.cer`. The matching private key exists
  only in that service account's `Cert:\CurrentUser\My` store.
- The caller supplies an explicit `PSCredential` for that same account, which already
  has the required Task Scheduler Password-logon authority.
- The account-specific credential directory exists with its separately approved ACL.

## Procedure

Create an encrypted, account-specific one-time envelope:

    $token = Read-Host 'Existing CI-Shared ReadOnly token' -AsSecureString
    $parameters = @{
      AccountName = '.\SvcProGet'
      AccessToken = $token
      RecipientCertificatePath = 'C:\secure-staging\SvcProGet.cer'
      OutputPath = 'C:\secure-staging\SvcProGet-bootstrap.cms'
    }
    New-BWSReadOnlyBootstrapEnvelope @parameters

Preview the bounded task without registering it:

    $serviceCredential = Get-Credential "$env:COMPUTERNAME\SvcProGet"
    $parameters = @{
      AccountName = '.\SvcProGet'
      ServiceLogonCredential = $serviceCredential
      EnvelopePath = 'C:\secure-staging\SvcProGet-bootstrap.cms'
      CertificateThumbprint = '<40-hex-character-thumbprint>'
      WhatIf = $true
    }
    Invoke-BWSReadOnlyTokenBootstrap @parameters

Remove `WhatIf` only in a separately authorized provisioning session. The task action
contains paths, account identity, and certificate thumbprint only. The worker validates
its running identity and CurrentUser private key, decrypts the CMS envelope in memory,
deletes the one-time envelope, and calls `Initialize-BWSAccessToken` with
`TokenPurpose = 'ReadOnly'`.

## Idempotency and recovery

- An existing ReadOnly DPAPI file returns `ExistingUnverified` unless an operator
  supplies separately authorized `Force`. The orchestrator cannot decrypt or attest the
  existing DPAPI content from the operator context, so it does not claim it is valid.
  Because no worker consumed it, the encrypted one-time envelope remains for an explicit
  operator decision; it is not silently discarded.
- `Force` is passed to the account worker as explicit overwrite authorization. The worker
  still hard-codes `ReadOnly`, and `Initialize-BWSAccessToken` backs up the existing exact
  purpose-specific ReadOnly XML before replacing it; neither path selects a legacy
  single-slot file or any ReadWrite slot.
- A running deterministic task returns `InProgress`; a stopped stale task returns
  `NeedsOperator`. `Force` repairs only that exact deterministic task.
- On timeouts and worker failures, the orchestrator stops a running task and verifies it
  is no longer running before unregistering it or deleting the one-time envelope. If the
  stop cannot be verified, it preserves the task and envelope for operator cleanup.
- Results contain account, project, purpose, paths, task status, operation ID, and exit
  code only. They never contain a token, password, decrypted CMS content, or grant.

`Unprotect-CmsMessage` necessarily returns a short-lived managed plaintext string before
the worker converts it to `SecureString`. The worker binds decryption to the validated
account certificate, clears its reference immediately after conversion, and never places
that string in output, errors, logs, task arguments, or persisted files.

The code cannot prove that Bitwarden issued the supplied token with only the
`CI-Shared` ReadOnly grant. That grant is a prerequisite verified during the separately
authorized live integration gate; the bootstrap never broadens or creates it.
