# ReadMe for ATAP.Utilities.BuildTooling.BuildMaster

## ProGet authentication

Active plans pass `ProGet.BuildMaster.API.Key` only as a SecretName to their
PowerShell runners. Publishing and promotion leaves resolve that name with
`Get-SecretATAP` immediately before authentication. Raw API-key parameters and
ProGet API-key environment-variable fallbacks are rejected; there is no fallback
from the BuildMaster key to the administrator key.
