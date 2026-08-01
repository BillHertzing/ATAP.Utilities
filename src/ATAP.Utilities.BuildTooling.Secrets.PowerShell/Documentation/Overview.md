# Secrets child overview

This module supplies the BuildTooling secret-provider contract. Consumers pass a
`SecretName` to `Get-SecretATAP`; providers resolve the value without exposing it in
logs. The default provider is Bitwarden Secrets Manager (`bws`) and the personal
Bitwarden vault is an explicit, quarantined opt-in path.
