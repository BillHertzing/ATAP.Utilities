# ATAP Root CA — Backup, Restore, Revocation, and Renewal Runbook

**Sprint 0014, Stream E, Task 14.42.**
Covers both independent roots: `ATAP Foundation` and `ATAP Consulting`.

This runbook is the operational half of Task 14.42. The architecture and
ownership decisions live in `Security-PowerShell-Module-Architecture.md`; the
metadata-only artifact contract lives in
`RRSBS-ADR-185-PKIArtifact-Metadata-Only-Contract.md`.

---

## 0. Standing rules

These apply to every procedure below and are not repeated in each one.

- **Private-key handling is separately authorized.** Do not run any step that
  decrypts a root key, signs with a root key, or writes to a CA database without
  explicit authorization for that step. Agents must ask; a prior authorization
  does not carry into a later session.
- **No key material, passphrase, or PFX content is ever written to Git, to
  `_generated/`, or to an evidence file.** Evidence records hashes of ciphertext,
  certificate fingerprints, subjects, and dates only.
- **A decrypted private key is never written to disk.** OpenSSL reads the
  encrypted key and emits only public artifacts. Where a passphrase is needed it
  is materialized into a short-lived, ACL-restricted file passed as
  `-passin file:<path>`, then zero-overwritten and deleted — never passed as
  `-passin pass:<value>`, which would expose it in the process command line.
- **Roots are offline-style and encrypted at rest.** Both root keys are
  EC `secp384r1`, AES-encrypted, under `C:\Dropbox\Security\PKI\<Org>\RootCA\private\`.
  Use `openssl pkey`, not `openssl rsa`.
- **Passphrase custody is Bitwarden, by SecretName.** Resolve with
  `Get-SecretATAP`; never hard-code.

| Organization      | Root passphrase SecretName             |
| ----------------- | -------------------------------------- |
| `ATAP Foundation` | `PKI.RootCA.Passphrase.ATAPFoundation` |
| `ATAP Consulting` | `PKI.RootCA.Passphrase.ATAPConsulting` |

---

## 1. On-disk layout

Each root lives at `C:\Dropbox\Security\PKI\<Organization>\RootCA\`:

| Directory   | Contents                                                        | In backup? |
| ----------- | --------------------------------------------------------------- | ---------- |
| `private\`  | `root-ca.key.pem` — AES-encrypted EC P-384 root key             | **Yes**    |
| `public\`   | `root-ca.crt`, public key PEM                                   | **Yes**    |
| `database\` | `index.txt`, `serial`, `crlnumber` and their `.old` companions  | **Yes**    |
| `config\`   | `AUdefault.cnf` — the OpenSSL CA profile                        | **Yes**    |
| `crl\`      | published CRLs — **currently empty for both roots**              | Yes        |
| `issued\`, `newcerts\` | intended to hold issued leaf certificates — **currently empty for both roots**, see §4.3 | Yes |
| `requests\` | CSRs                                                            | Optional   |
| `secrets\`  | **must be empty at rest** — transient passphrase files only     | **Never**  |

`AUdefault.cnf` resolves its paths from environment variables
(`ATAP_PKI_CA_DATABASE`, `ATAP_PKI_CA_SERIAL`, `ATAP_PKI_CA_CRLNUMBER`,
`ATAP_PKI_CA_CERTIFICATE`, `ATAP_PKI_CA_PRIVATE_KEY`, `ATAP_PKI_CA_NEW_CERTS`),
so the same config file works against a restored copy in a scratch directory
without editing. That property is what makes the rehearsal in §3 possible.

Relevant profile defaults: `default_md = sha384`, `default_days = 397`,
`default_crl_days = 30`, `unique_subject = no`, `copy_extensions = copy`.
Leaf profiles are `server_cert`, `code_signing_cert`, and `data_encryption_cert`.

### Verify `secrets\` is clean

```powershell
foreach ($org in 'ATAP Foundation', 'ATAP Consulting') {
  $secrets = "C:\Dropbox\Security\PKI\$org\RootCA\secrets"
  $leftovers = @(Get-ChildItem -LiteralPath $secrets -Force -ErrorAction SilentlyContinue)
  "{0}: {1} file(s)" -f $org, $leftovers.Count
}
```

Anything other than `0 file(s)` means a previous run aborted before its cleanup.
Zero-overwrite and delete the leftovers before doing anything else.

---

## 2. Backup

### 2.1 What a backup must contain

The **minimum restorable set** is five files per root:

```text
private\root-ca.key.pem      the encrypted key — useless without the vault passphrase
public\root-ca.crt           the CA certificate
database\index.txt           issuance ledger (drives revocation state)
database\serial              next leaf serial
database\crlnumber           next CRL number
```

plus `config\AUdefault.cnf` to reproduce issuance behavior. Losing `index.txt`
is the expensive failure: the key and certificate can still sign, but the CA can
no longer revoke a certificate it has forgotten it issued.

### 2.2 The passphrase is the other half of the backup

The encrypted key file alone cannot be restored. The backup is only complete when
the Bitwarden secret is also durable. **Back up the file set and verify the vault
secret resolves in the same session** — a backup verified against a passphrase
nobody can produce is not a backup.

### 2.3 Taking a backup

Copy the file set to the backup target and record a manifest of SHA-256 hashes of
the *ciphertext* and public artifacts. Those hashes are safe to record and are
what §3 compares against.

```powershell
$org      = 'ATAP Foundation'          # or 'ATAP Consulting'
$caRoot   = "C:\Dropbox\Security\PKI\$org\RootCA"
$stamp    = Get-Date -Format 'yyyyMMddTHHmmssZ'
$target   = Join-Path "C:\Dropbox\Security\PKI\$org\Backups" $stamp

foreach ($relative in @(
    'private\root-ca.key.pem', 'public\root-ca.crt',
    'database\index.txt', 'database\serial', 'database\crlnumber',
    'config\AUdefault.cnf')) {
  $destination = Join-Path $target $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $caRoot $relative) -Destination $destination -Force
}

Get-ChildItem -LiteralPath $target -Recurse -File |
  ForEach-Object { [pscustomobject]@{
      Path   = $_.FullName.Substring($target.Length + 1)
      Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash } } |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $target 'manifest.json') -Encoding utf8
```

Apply the same restricted ACL the commissioning path uses (current identity,
`BUILTIN\Administrators`, `NT AUTHORITY\SYSTEM`, inheritance disabled).

### 2.4 Cadence

Re-back-up after **any** event that changes `database\`: every leaf issuance,
every revocation, every CRL publication. The key and certificate change only at
root renewal (§6).

---

## 3. Restore rehearsal

A backup is unproven until a restore has been rehearsed. The rehearsal is
automated and **read-only with respect to production**:

```powershell
pwsh -File _generated\Sprint0014\StreamE\Invoke-RootCaRestoreRehearsal.ps1
```

It restores the backup set into an isolated scratch directory outside Dropbox and
proves four things about the restored copy:

1. **`KeyDecryptable`** — the encrypted key decrypts with the vault passphrase
   (`openssl pkey -check`). This is the test that proves key and passphrase are
   still a matched pair.
2. **`KeyMatchesCertificate`** — the public key derived from the restored key is
   byte-identical to the public key inside the restored certificate. The private
   key never leaves OpenSSL.
3. **`CertificateSelfVerify`** — the CA certificate verifies against itself.
4. **`DatabaseParsed`** — `index.txt` rows are well-formed and `serial` /
   `crlnumber` are hex.

It also hashes the production tree before and after and reports
`ProductionUnchanged`, then destroys the scratch directory and zero-overwrites the
transient passphrase file.

Evidence lands at
`_generated\Sprint0014\StreamE\live-root-ca-restore-rehearsal.json`.
A rehearsal is only a pass when `AllRehearsalsPassed` **and**
`ProductionUntouched` are both `True`.

### Rehearsal of record

| Field | Result |
| ----- | ------ |
| Recorded | 2026-08-05 (Sprint 0014) on `UTAT022` |
| `ATAP Foundation` | key decryptable, key matches certificate, certificate self-verifies, database parsed |
| `ATAP Consulting` | key decryptable, key matches certificate, certificate self-verifies, database parsed |
| `ProductionUntouched` | `True` for both roots |

### Doing a real restore

A real restore is the rehearsal without the scratch directory: copy the backup set
back over `<Org>\RootCA\`, re-apply the restricted ACLs, run the rehearsal script
against a scratch copy to confirm, then resume issuance. Restore `database\` from
the **most recent** backup available — restoring a stale `index.txt` silently
reintroduces revoked certificates as valid and lets `serial` re-issue a number
already in use.

---

## 4. Revocation

> Mutates the CA database and requires the root key. **Separately authorized.**

### 4.1 When to revoke

- A leaf's private key is exposed, or is suspected exposed.
- A code-signing certificate is superseded by a re-issue (key rotation, keyspec
  change, algorithm change). The superseded certificate must not remain valid.
- A host is decommissioned and its TLS leaf is no longer wanted.

### 4.2 Currently outstanding

The Foundation CA database shows three code-signing certificates, of which only
serial `1003` (thumbprint `3B5E16C0498E1F5A92F95B9AA17FD6A40E9C406E`) is in use.
Serials `1000` and `1002` are superseded by the keyspec/RSA rotation and are still
marked `V` (valid). **They are outstanding revocation candidates** and were
deliberately left in place pending authorization.

Inspect state at any time — this is read-only and needs no authorization:

```powershell
Get-Content "C:\Dropbox\Security\PKI\ATAP Foundation\RootCA\database\index.txt"
```

Column 1 is the status flag: `V` valid, `R` revoked, `E` expired. Column 4 is the
serial.

### 4.3 Procedure

> **Prerequisite — the CA does not retain copies of what it issued.**
> `newcerts\` and `issued\` are **empty for both roots**, so the usual
> `-revoke newcerts\<serial>.pem` has no file to point at. `openssl ca -revoke`
> needs only the *public* certificate, so export it from the Windows store first
> (no private key, no authorization needed for this step):
>
> ```powershell
> $thumbprint = '<thumbprint of the certificate to revoke>'
> $exported   = Join-Path $env:TEMP "revoke-$thumbprint.pem"
> $cert = Get-Item "Cert:\LocalMachine\My\$thumbprint"
> $pem  = "-----BEGIN CERTIFICATE-----`n" +
>         [Convert]::ToBase64String($cert.RawData, 'InsertLineBreaks') +
>         "`n-----END CERTIFICATE-----"
> Set-Content -LiteralPath $exported -Value $pem -Encoding ascii
> ```
>
> Match the thumbprint to its `index.txt` serial before revoking — with
> `unique_subject = no`, three Foundation code-signing rows share one subject,
> and revoking the wrong serial revokes the certificate currently in production
> use. Then pass `-revoke $exported` below instead of the `newcerts\` path.

```powershell
$org         = 'ATAP Foundation'
$caRoot      = "C:\Dropbox\Security\PKI\$org\RootCA"
$serial      = '1000'                    # the certificate to revoke
$reason      = 'superseded'              # keyCompromise | superseded | cessationOfOperation | affiliationChanged

# Take a backup FIRST (§2.3). Revocation rewrites index.txt.

$env:ATAP_PKI_CA_DATABASE    = Join-Path $caRoot 'database\index.txt'
$env:ATAP_PKI_CA_NEW_CERTS   = Join-Path $caRoot 'newcerts'
$env:ATAP_PKI_CA_SERIAL      = Join-Path $caRoot 'database\serial'
$env:ATAP_PKI_CA_CRLNUMBER   = Join-Path $caRoot 'database\crlnumber'
$env:ATAP_PKI_CA_CERTIFICATE = Join-Path $caRoot 'public\root-ca.crt'
$env:ATAP_PKI_CA_PRIVATE_KEY = Join-Path $caRoot 'private\root-ca.key.pem'

# Materialize the passphrase into a restricted, short-lived file.
$passphrasePath = Join-Path $caRoot 'secrets\root-ca.passphrase'
$secret = Get-SecretATAP -SecretName "PKI.RootCA.Passphrase.$($org -replace '\s','')"
[System.IO.File]::WriteAllText($passphrasePath, [string]$secret, [System.Text.UTF8Encoding]::new($false))
$secret = $null
# ... apply the restricted ACL here ...

try {
  # $exported comes from the prerequisite block above, because newcerts\ is empty.
  openssl ca -config (Join-Path $caRoot 'config\AUdefault.cnf') `
    -revoke $exported `
    -crl_reason $reason `
    -passin "file:$passphrasePath"

  # Publish a fresh CRL. default_crl_days = 30, so this must be reissued monthly
  # whether or not anything new was revoked.
  openssl ca -config (Join-Path $caRoot 'config\AUdefault.cnf') `
    -gencrl -out (Join-Path $caRoot 'crl\root-ca.crl') `
    -passin "file:$passphrasePath"
} finally {
  $length = (Get-Item -LiteralPath $passphrasePath).Length
  [System.IO.File]::WriteAllBytes($passphrasePath, (New-Object byte[] $length))
  Remove-Item -LiteralPath $passphrasePath -Force -ErrorAction SilentlyContinue
}
```

Confirm the row flipped from `V` to `R`, then take a fresh backup (§2.3) —
`index.txt` and `crlnumber` both changed.

### 4.4 Distributing the CRL, and its limits

The certificates issued so far carry **no CRL Distribution Point extension**, so
Windows chain-building will not fetch a CRL on its own. Until a CDP is added to
the issuing profile, revocation is enforced by **removing the certificate from
the hosts that trust it**, not by publishing a CRL:

```powershell
# Remove a superseded publisher certificate from LocalMachine\TrustedPublisher
$store = [System.Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine')
$store.Open('ReadWrite')
$store.Certificates.Find('FindByThumbprint', '<thumbprint>', $false) |
  ForEach-Object { $store.Remove($_) }
$store.Close()
```

Repeat on every host (`utat022`, `utat01`). Generating the CRL is still worth
doing — it makes the revocation durable in the CA's own records and is what a
future CDP would serve.

**Known gap:** adding a `crlDistributionPoints` entry to the `server_cert` and
`code_signing_cert` profiles in `AUdefault.cnf`, and serving `root-ca.crl` over
HTTPS, is not yet done. Certificates already issued cannot gain a CDP
retroactively — they would have to be re-issued.

---

## 5. Leaf renewal

> Requires the root key. **Separately authorized.**

Leaves are issued for 397 days (`default_days`). Current expiries:

| Certificate | Expires |
| ----------- | ------- |
| Foundation / Consulting host TLS leaves (`utat01`, `utat022`) | 2027-09-04 |
| Foundation / Consulting code-signing leaves | 2028-11-05 |

**Renew at 60 days remaining.** Check with:

```powershell
Get-ChildItem Cert:\LocalMachine\My |
  Where-Object { $_.Issuer -match 'ATAP (Foundation|Consulting) Root CA' } |
  Select-Object Subject, NotAfter, Thumbprint,
    @{n='DaysLeft';e={ [int]($_.NotAfter - (Get-Date)).TotalDays }} |
  Sort-Object DaysLeft
```

### Procedure

Renewal is re-issuance, not extension. Use the PKI module rather than raw
OpenSSL — it owns the SAN/EKU and non-exportability conventions:

1. **Generate a new key and CSR** on the host that will hold the certificate.
   - TLS: `New-SSLCertificateRequest` (DNS SAN = the host name, EKU `serverAuth`).
   - Code signing: `New-PkiWindowsCodeSigningCertificate` — a **non-exportable
     RSA-3072 Signature-key** certificate. The `Signature` keyspec matters;
     an `Exchange` keyspec certificate will not Authenticode-sign. Both
     `Foundation-CodeSigning-KeySpec-*.inf` variants under
     `_generated\Sprint0014\StreamE\` exist because of exactly that failure.
2. **Sign the CSR** with `New-SignedCertificate`, selecting the matching profile
   section (`server_cert` or `code_signing_cert`).
3. **Install** with `Install-SSLCertificate` / `Install-CodeSigningCertificate`,
   then `Install-TrustedPublisherCertificate` on every consuming host.
4. **Grant private-key read access** to the service accounts that need it
   (`Svc<Service>` on the owning host) — this is what
   `Grant-PkiPrivateKeyReadAccess` does. Missing this is the usual cause of a
   service that starts but cannot serve TLS.
5. **Repoint consumers before removing the old certificate.** For a code-signing
   renewal, update the BuildMaster `CodeSigningCertificateThumbprint` variable;
   for a TLS renewal, rebind the Inedo endpoints. Trust the new certificate on
   all hosts **first**, then cut over, then revoke the old one (§4).
6. **Validate from the peer host**, not only locally — see
   `Test-RemainingLeafCommissioning.ps1`.
7. **Revoke the superseded certificate** (§4). A renewal that leaves the old
   certificate valid is how §4.2's backlog accumulated.

### Signed artifacts survive renewal

Authenticode signatures are timestamped against
`http://timestamp.digicert.com`. Modules signed with a code-signing certificate
stay valid after that certificate expires, because the timestamp proves the
signature predated expiry. Renewal therefore does **not** require re-signing
already-published packages — ProGet feed versions are immutable anyway.

---

## 6. Root renewal

Both roots are EC P-384 (`secp384r1`) and expire **2041-07-30**. No action is
expected for well over a decade, but the shape of the work:

- A root's key and subject must not change silently. Renewing a root means
  issuing a new root certificate and distributing it to every host's
  `LocalMachine\Root` **before** retiring the old one.
- Overlap the two roots. Trust both, re-issue leaves under the new root, then
  remove the old root once no leaf chains to it.
- `Invoke-CommissionATAPRootCAs.ps1` deliberately **refuses to overwrite** an
  existing `private\root-ca.key.pem` or `public\root-ca.crt`, and refuses
  partial replacement across the two organizations. A root renewal must
  therefore stage into a new directory, not re-run commissioning in place.
- Re-run the §3 rehearsal against the new root before retiring the old one.

---

## 7. Quick reference

| I need to… | Section | Authorization |
| ---------- | ------- | ------------- |
| See what a CA has issued | §4.2 | none — read-only |
| Confirm `secrets\` is clean | §1 | none — read-only |
| Check leaf expiry | §5 | none — read-only |
| Take a backup | §2.3 | none — copies ciphertext only |
| Rehearse a restore | §3 | **decrypts a root key — authorize** |
| Perform a real restore | §3 | **authorize** |
| Revoke a certificate / publish a CRL | §4.3 | **authorize** |
| Renew a leaf | §5 | **authorize** |
| Renew a root | §6 | **authorize** |

## 8. Open items

1. **No CRL Distribution Point** in issued certificates (§4.4). Revocation is
   currently enforced by trust-store removal. Adding a CDP requires changing
   `AUdefault.cnf`, serving the CRL over HTTPS, and re-issuing every leaf.
2. **Foundation serials `1000` and `1002` are outstanding revocation
   candidates** (§4.2), and no CRL has been generated for either root —
   `crlnumber` still reads `1000` and `crl\` is empty.
3. **Backup cadence is manual.** Nothing currently enforces a re-backup after an
   issuance mutates `database\`.
4. **The CAs retain no copy of what they issued.** `newcerts\` and `issued\` are
   empty for both roots even though `index.txt` records eight issuances, so
   revocation depends on recovering the public certificate from a host's
   Windows store (§4.3). If a certificate is revoked-and-removed everywhere
   before being exported, it can no longer be revoked in the CA's own records.
   The issuance path should be changed to write `newcerts\<serial>.pem`.
