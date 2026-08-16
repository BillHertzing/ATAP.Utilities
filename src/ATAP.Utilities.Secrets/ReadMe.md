# ATAP.Utilities.Secrets

## Overview

The supported Windows application path resolves exact individual SecretNames
from one application-owned Bitwarden Project through Secrets Manager `bws`.
The access token is `ReadOnly`, bound to the effective identity, host,
application, and Project/grouping, and recovered from a protected DPAPI envelope.

Application hosts must not use Password Manager `bw`, `BW_SESSION`, or
`--session`. The legacy shim is obsolete, explicitly selected compatibility
only; it is neither a default nor a fallback when the supported provider fails.

## Navigation

- [INDEX.md](INDEX.md)
- [Supported Bitwarden Secrets Manager provider](BitwardenSecretsManager/ReadMe.md)
- [BWS/DPAPI migration and rollback](BitwardenSecretsManager/MigrationRollbackRunbook.md)
