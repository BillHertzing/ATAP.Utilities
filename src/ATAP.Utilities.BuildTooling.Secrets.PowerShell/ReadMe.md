# ATAP.Utilities.BuildTooling.Secrets.PowerShell

This child owns BuildTooling's secret-resolution and Bitwarden Secrets Manager boundary.
It exports the eleven frozen public commands, including the global contracts
`Get-SecretATAP`, `Get-BWSAccessToken`, and `Initialize-BWSAccessToken`.

The module depends on BuildTooling.Common and PSFramework. It deliberately does not
depend on its compatibility parent; downstream BuildTooling children consume it directly.
