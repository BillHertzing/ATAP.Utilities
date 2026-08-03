# PKI for ATAP Foundation and ATAP Consulting

This is an operator runbook. It does not authorize CA private-key creation, certificate issuance,
trust-store changes, endpoint cutover, or code signing. Obtain explicit approval for each live
phase and capture metadata-only evidence.

## Policy decisions

- Use one independent self-signed root CA per organization with an encrypted `secp384r1` private
  key. Never cross-sign or reuse a root or leaf private key between the organizations.
- Keep active PKI files under `C:\Dropbox\Security\PKI\ATAP Foundation` and
  `C:\Dropbox\Security\PKI\ATAP Consulting`. Restrict `C:\Dropbox\Security` ACLs to named PKI
  custodians and keep every private key encrypted at rest. The root keys are exportable only for
  encrypted backup; host and code-signing private keys are non-exportable after import.
- Use SHA-384 for CA, CSR, and issuance operations.
- Issue one host-identification certificate per host. SANs contain every DNS/IP identity clients
  use; the TLS common name must also appear as a DNS SAN.
- Separate Server Authentication, Code Signing, and Data Encryption EKUs. Do not issue a
  multipurpose leaf certificate.
- Resolve secret values by SecretName only at the leaf operation. Never record raw values.

## Prerequisites

1. Install the released `ATAP.Utilities.Security.PKI.PowerShell` module and OpenSSL 3.x.
2. Select exactly one organization inventory from ATAP.IAC and verify its `organization_name` and
   `pki_base_path`. Do not combine both inventories in one render context.
3. Beneath the selected organization's `RootCA` directory, create `private`, `secrets`, `public`,
   `requests`, `issued`, `newcerts`, `database`, `config`, and `crl` directories. Apply an ACL
   that grants PKI custodians full control and removes inherited broad access.
4. Copy `CertificateRequestConfigurations/AUdefault.cnf` to `RootCA\config` and hash the copy.
5. Prepare a transient, ACL-restricted passphrase file from the approved secret source. Delete it
   after the key operation. Do not pass a plaintext password on the command line.

Use `PKI.RootCA.Passphrase.ATAPFoundation` and `PKI.RootCA.Passphrase.ATAPConsulting` as the
independent root passphrase SecretNames. Resolve them through `Get-SecretATAP`; never reuse one
organization's passphrase for the other organization.

## Create the root CA

Preview each mutation first. These examples assume all paths were reviewed and authorized.

```powershell
$organizationName = 'ATAP Foundation' # Or: ATAP Consulting
$pkiRoot = Join-Path 'C:\Dropbox\Security\PKI' $organizationName
$caRoot = Join-Path $pkiRoot 'RootCA'
$passPath = Join-Path $caRoot 'secrets\root-ca.passphrase'
$keyPath = Join-Path $caRoot 'private\root-ca.key.pem'
$certPath = Join-Path $caRoot 'public\root-ca.crt'
$configPath = Join-Path $caRoot 'config\AUdefault.cnf'

New-EncryptedPrivateKey -EncryptedPrivateKeyPath $keyPath `
  -EncryptionKeyPassPhrasePath $passPath -ECCurve secp384r1 -WhatIf

$caDn = New-DistinguishedNameHash -CN "$organizationName Root CA 2026" `
  -O $organizationName -C 'US' `
  -BasicConstraints 'critical', 'CA:TRUE', 'pathlen:0' `
  -KeyUsage 'critical', 'keyCertSign', 'cRLSign'

New-CACertificate -DistinguishedNameHash $caDn `
  -EncryptedPrivateKeyPath $keyPath -EncryptionKeyPassPhrasePath $passPath `
  -ValidityPeriod 15 -ValidityPeriodUnits years -CertificatePath $certPath `
  -CertificateRequestConfigPath $configPath -WhatIf
```

After authorization, rerun without `-WhatIf`, inspect the subject, issuer, basic constraints, key
usage, serial, validity, and SHA-256 thumbprint, then delete the transient passphrase file.

The Sprint 0014 `Invoke-CommissionATAPRootCAs.ps1` wrapper is not a supported module command. It
atomically commissioned exactly two named organizations and wrote sprint-specific evidence. Use
the parameterized primitives above for a new organization or root rollover so each operation has
its own approval, paths, SecretName, and evidence boundary.

## Back up and restore-test the CA

Create two encrypted backup copies in separate physical locations outside the synchronized active
tree. Each backup contains the
encrypted CA key, public CA certificate, reviewed OpenSSL config, CA database, serial, CRL number,
issued-certificate records, and current CRL. Keep the passphrase in a separate approved vault.

Quarterly, restore one backup to an isolated offline machine, verify hashes and ACLs, inspect the
CA certificate/key match, generate a disposable CSR, sign it, revoke it, generate a CRL, and then
destroy the restored working copy. Evidence records dates, custodians, media identifiers, hashes,
certificate thumbprints, and pass/fail only.

## Issue host certificates

For `utat01`, SANs include at least `DNS:utat01`. For `utat022`, SANs include at least
`DNS:utat022`. Add every FQDN, service alias, or IP literal that clients use.

```powershell
$organizationName = 'ATAP Foundation' # Or: ATAP Consulting
$pkiRoot = Join-Path 'C:\Dropbox\Security\PKI' $organizationName
$organizationToken = $organizationName -replace ' ', ''
$hostName = 'utat022'
$hostRoot = Join-Path $pkiRoot "Hosts\$hostName"
$hostDn = New-DistinguishedNameHash -CN $hostName -O $organizationName -C 'US' `
  -SubjectAlternateName "DNS:$hostName" -ExtendedkeyUsage serverAuth

New-CertificateRequest -DistinguishedNameHash $hostDn `
  -CertificateRequestPath (Join-Path $hostRoot "$hostName.csr") `
  -EncryptedPrivateKeyPath (Join-Path $hostRoot "private\$hostName.key.pem") `
  -EncryptionKeyPassPhrasePath (Join-Path $hostRoot "secrets\$hostName.passphrase") -WhatIf

New-SignedCertificate -CertificateRequestPath (Join-Path $hostRoot "$hostName.csr") `
  -CACertificatePath $certPath -CAEncryptedPrivateKeyPath $keyPath `
  -CAEncryptionKeyPassPhrasePath $passPath `
  -CASigningCertificatesCertificatesIssuedDBPath (Join-Path $caRoot 'database\index.txt') `
  -CertificateRequestConfigPath $configPath -CertificateProfile ServerAuthentication `
  -ValidityPeriod 397 -ValidityPeriodUnits days `
  -CertificatePath (Join-Path $hostRoot "public\$hostName.crt") -WhatIf
```

Verify the SAN set, Server Authentication EKU, chain, validity, and key/certificate match before
creating the host PFX. Store the PFX password under a host-specific SecretName such as
`PKI.PFX.Password.ATAPFoundation.utat022` or
`PKI.PFX.Password.ATAPConsulting.utat022`; never commit it or accept a raw password parameter.

Create the transient PFX with `New-PkiCertificatePfx`. It resolves the PFX password by SecretName
and sends it to OpenSSL over standard input, so the value is absent from the command line and
returned metadata. Import it with `Install-SSLCertificate`, validate the non-exportable installed
key and service-account ACL, and then remove the PFX and transient leaf-passphrase file.

```powershell
New-PkiCertificatePfx `
  -PrivateKeyPath (Join-Path $hostRoot "private\$hostName.key.pem") `
  -PrivateKeyPassphrasePath (Join-Path $hostRoot "secrets\$hostName.passphrase") `
  -CertificatePath (Join-Path $hostRoot "public\$hostName.crt") `
  -CACertificatePath $certPath `
  -PfxPath (Join-Path $hostRoot "pfx\$hostName.pfx") `
  -FriendlyName $hostName `
  -PasswordSecretName "PKI.PFX.Password.$organizationToken.$hostName" `
  -WhatIf
```

## Issue a code-signing certificate

For Windows Authenticode, use the reusable issuance command. It creates a non-exportable RSA-3072
machine key with KeySpec Signature, resolves only the root passphrase SecretName, installs the leaf
in `LocalMachine\My`, grants explicitly named principals read access, archives the prior canonical
public certificate during renewal, and distributes TrustedPublisher trust with pinned public data.

```powershell
$organizationName = 'ATAP Foundation' # Or: ATAP Consulting
$organizationToken = $organizationName -replace ' ', ''
$pkiRoot = Join-Path 'C:\Dropbox\Security\PKI' $organizationName

New-PkiWindowsCodeSigningCertificate `
  -OrganizationName $organizationName `
  -CARootPath (Join-Path $pkiRoot 'RootCA') `
  -CodeSigningRootPath (Join-Path $pkiRoot 'CodeSigning') `
  -CAPassphraseSecretName "PKI.RootCA.Passphrase.$organizationToken" `
  -PrivateKeyReader 'SvcBuildmaster' `
  -TrustedPublisherComputerName 'utat022', 'utat01' `
  -WhatIf
```

The certificate subject is the publisher identity; `PrivateKeyReader` is the separate Windows
authorization value naming accounts that may use the key. Do not grant general service accounts
or interactive users unless they are deliberate signing principals. The function does not create
or retain a PFX. Use the lower-level CSR, signing, and PFX commands only for consumers whose
signing provider explicitly requires that format.

## Install trust and leaf certificates

```powershell
Install-PkiTrustCertificate -Path $certPath -CertificateRole RootCA `
  -ComputerName 'utat022', 'utat01' -ExpectedSha256 $reviewedRootSha256 -WhatIf

Install-SSLCertificate -Path (Join-Path $hostRoot 'utat022.pfx') `
  -PasswordSecretName 'PKI.PFX.Password.ATAPFoundation.utat022' -WhatIf
```

The trust command verifies the optional SHA-256 pin before transferring public DER bytes and
returns `Changed = $false` when the certificate is already installed. Confirm the CA lands in
`LocalMachine\Root`, the leaf lands in `LocalMachine\My`, the leaf private key is non-exportable,
and only the required Inedo service identities can read it.

## Stream E script disposition

The commissioning scripts under `_generated\Sprint0014\StreamE` remain evidence and should not be
copied into production automation:

| Script group | Long-term disposition |
| --- | --- |
| Root commissioning | Keep as historical evidence. Reusable CA/key/DN operations already exist as module primitives. |
| Root and TrustedPublisher distribution | Replaced by `Install-PkiTrustCertificate`. |
| Windows Signature-key code-signing issuance | Replaced by `New-PkiWindowsCodeSigningCertificate`. |
| Combined Foundation host/code-signing leaf issuance | Keep the wrapper as historical evidence; it hard-codes profiles, hosts, service accounts, and resume state. Its reusable PKCS#12 export is now `New-PkiCertificatePfx`; compose the remaining module primitives with inventory values. |
| Inedo HTTPS enablement | Keep with the product deployment/runbook layer, not the PKI module. |
| ECDSA-to-RSA and KeySpec repair | Keep as one-time migration evidence; the supported issuance command creates the correct Windows key initially. |
| Signing probes, commit, checkpoint, and evidence writers | Keep as test/session artifacts; they are not PKI product APIs. |

## HTTPS cutover and two-host validation

Follow `ATAP.IAC/Windows/AnsibleHostInventory/README.PKI-TLS.md`. Establish trust first, test a
temporary HTTPS binding from both hosts, then render the final HTTPS-only ProGet and BuildMaster
templates. Validate exact SAN names and chains without `SkipCertificateCheck`, `SkipCACheck`,
`SkipCNCheck`, `SkipRevocationCheck`, or `AllowInvalid=True`.

## Renewal, revocation, and CRL publication

Begin renewal with at least 30 days remaining. Issue the replacement with the same required SANs
and EKU, install it alongside the old leaf, validate from both hosts, update the pinned thumbprint,
and remove the old leaf only after successful cutover.

For revocation, set the `ATAP_PKI_CA_*` environment variables to the reviewed offline CA paths,
then run the OpenSSL `ca -revoke` operation and generate a CRL with `openssl ca -gencrl`. Publish
the CRL at the approved internal distribution point, verify clients reject the revoked leaf, and
record the serial, reason, CRL number, next-update time, and validation result. Never record key or
passphrase material.

If the root key is compromised, stop issuance, establish a new root under separate approval,
reissue every leaf, distribute the new trust anchor, validate both roots during a bounded overlap,
and remove the compromised root only after all consumers have migrated.

## Legacy inventory disposition

The external `SSLRelatedFilesInATAP.IAC.md` listing is discovery input, not current deployment
authority. It was generated from an older ATAP.IAC layout and still names root-level
`Ansible-Security.ps1` and `Get-AnsibleInventory.ps1` files that are absent from both the current
stable and Sprint 0014 worktrees. Review any surviving `Windows/HostSettings.ps1` or legacy
certificate-path references during migration, but use the Sprint 0014 PKI inventory, this runbook,
and the tested Inedo templates as the current source of truth.

## Rollback

Endpoint rollback restores the backed-up Inedo configuration and restarts one service at a time.
Keep the trusted CA and staged leaf certificates for diagnosis. Re-enable HTTP only for a bounded,
recorded exception while the HTTPS failure is corrected.
