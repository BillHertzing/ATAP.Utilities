# ATAP.Utilities.BuildTooling.ProGet.PowerShell

This child module owns PowerShell functions for ProGet feed administration,
package publication, immutable promotion, feed settings, and package retrieval
in the ATAP BuildTooling module family.

Version `0.1.0` is the initial extracted implementation. The aggregate
`ATAP.Utilities.BuildTooling.PowerShell` module imports this child and preserves
the established compatibility command names.

## Functional area

PowerShell Build & Packaging - START HERE: `SolutionDocumentation/PowerShell-Modules-Build-Process.md`.

## PowerShell package signature policy

`Set-PSModuleFileSignature` signs staged PowerShell files with a current Code Signing certificate
selected by Windows certificate-store thumbprint and requires an external timestamp URI.
`Test-PSModulePackageSignature` expands the immutable package, records public signature metadata,
and rejects any unsigned, invalid, or untimestamped signable file.

The package gate runs before initial publication, before every `powershellget-*` promotion, and
inside `Install-ATAPModuleAllUsers` after SHA-256 validation but before expansion or writes under
the AllUsers module root. Signing certificates and private keys are never accepted as file paths
or package content. Promotion verification requires an absolute HTTPS ProGet base URI.
