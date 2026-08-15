# Obsolete Bitwarden Password Manager compatibility

## Status

This package is quarantined compatibility code for the Bitwarden Password
Manager CLI. Its public APIs emit `ATAPSECRETS001` and target removal in release
1.0.0. New application code must use
`ATAP.Utilities.Secrets.BitwardenSecretsManager` and the `bws` Project API.

This package is not referenced by the provider-neutral
`ATAP.Utilities.Secrets` facade, is not a default provider, and must never be an
automatic fallback. It is retained only to preserve source and binary shape for
explicitly named legacy consumers during migration.

## Legacy behavior

The implementation uses `bw`, `BW_SESSION`, and `--session` with Password
Manager item-search semantics. Those mechanics are incompatible with the
application access contract. The legacy configuration provider also uses a
synchronous `Load()` bridge and therefore must not be copied into new code.

Applications resolve individual secrets from one application-owned vault
grouping. Bitwarden expresses that grouping as a Project; other vault products
may use a different provider-specific grouping mechanism. There are no secret
sets.

See the [Bitwarden Secrets Manager provider guidance](../../BitwardenSecretsManager/ReadMe.md)
for the supported asynchronous provider, Windows identity binding, DPAPI
envelope, process boundary, and failure behavior.