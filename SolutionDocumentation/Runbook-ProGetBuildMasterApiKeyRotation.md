# Runbook: Rotate the ProGet BuildMaster API Key

## Scope

This runbook rotates the ProGet worker credential consumed by BuildMaster:

```text
ProGet.BuildMaster.API.Key.<proget-service-host>
```

The host suffix identifies the ProGet service instance. For the current placement,
the full name is `ProGet.BuildMaster.API.Key.utat022`.

It does not rotate `ProGet.Admin.API.Key.<service-host>` or
`BuildMaster.Admin.API.Key.<service-host>`.

## BuildMaster boundary

The raw key value exists only in ProGet and Bitwarden Secrets Manager. BuildMaster
stores only `ProGetApiKeySecretName`; the authenticated PowerShell leaf resolves the
value with `Get-SecretATAP` immediately before contacting ProGet.

Consequently, a value rotation does not update a raw value in BuildMaster. Verify that
every affected application has the unchanged non-secret value
`ProGet.BuildMaster.API.Key.<proget-service-host>`, and that no raw key exists in an
application variable, plan argument, environment, transcript, log, screenshot, or
evidence artifact. Repair a missing or incorrect SecretName only as a separate
configuration correction.

## Required authorization and safe methods

Creating or deleting a ProGet API key, editing a Bitwarden secret, and starting a
BuildMaster build are live mutations and require their named human-in-the-loop gate.
Do not use package publication or promotion merely as a key test.

Use the interactive Bitwarden Secrets Manager UI for the value-bearing edit. The
installed `bws` CLI supports `bws secret edit`, but accepts the value by its
`--value` command-line argument; do not use that form. The legacy
`Set-BitWardenSecret` cmdlet writes to the personal `bw` vault and is not applicable.
`Invoke-RotateSecretsATAP` rotates BWS access tokens, not stored API keys.

Record only secret-safe evidence under the active worktree's `_generated/` directory:
change authorization, service host, SecretName, ProGet key display name or ID,
operator, timestamps, and pass/fail results. Never record the value, a derived hash,
headers, or a screenshot containing the value.

## Procedure

### 1. Preflight

1. Derive the service host from `ServicePlacementMap['ProGet']`, then form the
   SecretName. Do not hard-code a host in automation.
2. Confirm ProGet and BuildMaster are running. The current `utat022` baseline has
   ProGet on port `50000` and BuildMaster on port `50017`; obtain normal endpoints
   from the loaded profile.
3. In BuildMaster, inspect each affected application's variables. Confirm that
   `ProGetApiKeySecretName` exactly matches the derived name and no raw key is stored.
4. Confirm that `SvcBuildMaster` retains its ReadOnly BWS token and a project grant
   for the SecretName, without displaying the resolved secret.
5. Identify the old worker key by display name or ID and leave it enabled.

### 2. Create the ProGet replacement

1. In ProGet, open **Administration → Security → API Keys**.
2. Create a distinct replacement worker key with an auditable display name containing
   a change identifier or timestamp. Keep the old key active for the overlap window.
3. Grant the minimum permissions the deployed BuildMaster worker requires. Confirm
   the current ProGet edition's scope model before saving; do not silently substitute
   an administrative key.
4. Copy the new value once and paste it directly into the approved Bitwarden edit
   flow. Never place it in a terminal, script, command line, source file, chat,
   clipboard history, or evidence artifact.

### 3. Update Bitwarden Secrets Manager

1. Locate the existing secret by the exact derived SecretName and verify its project
   assignment and key name.
2. Replace only its value with the replacement ProGet key. Leave the SecretName,
   project, and required metadata unchanged.
3. Save the edit and clear the clipboard if it held the key.

### 4. Validate the BuildMaster consumer

1. From a profile-loaded `SvcBuildMaster` session, use the SecretName for a read-only,
   authenticated ProGet probe. `List-ProGetFeeds -ProGetApiKeySecretName <derived name>`
   is an available probe: it resolves through `Get-SecretATAP` in the authenticated leaf
   and returns feed metadata rather than the key.
2. Confirm that the expected ProGet endpoint and feed metadata are returned. On a 403,
   retain the old key and diagnose the new key's scope, the BWS update, and the service
   account's project grant.
3. Reinspect BuildMaster configuration; it must still contain only the unchanged
   non-secret SecretName.
4. A separately authorized non-destructive BuildMaster operation may be used as an
   additional probe. Publication and promotion need their own release gate.

### 5. Retire the old key

After Step 4 passes, disable or delete the old worker key in ProGet. Record its display
name or ID and retirement time only. Repeat the read-only `SvcBuildMaster` probe after
retirement; success proves that BuildMaster consumes the replacement from Bitwarden.

## Failure and recovery

| Failure | Response |
| --- | --- |
| Replacement key cannot be created or its scope is unclear | Stop, retain the old key, and obtain a permission decision. |
| Bitwarden edit fails | Retain the old key; retry the UI edit or remove the unused replacement key. |
| Consumer probe fails after the Bitwarden edit | Retain the old key. Restore the old Bitwarden value through the interactive UI, then diagnose BWS grant, service identity, endpoint, and ProGet scope. |
| BuildMaster contains a raw key | Stop. Handle it as a credential-exposure configuration remediation before continuing. |
| Old-key retirement fails | Retain both keys temporarily, record the exception, and schedule retirement. Rotation is not complete until the old key is retired and the post-retirement probe passes. |

## Completion checklist

- [ ] The placement-derived SecretName was used throughout.
- [ ] A new ProGet worker key was created while the old key remained active.
- [ ] Bitwarden Secrets Manager has the new value under the unchanged SecretName.
- [ ] BuildMaster contains only the correct SecretName, never the key.
- [ ] The `SvcBuildMaster` read-only probe passed before and after old-key retirement.
- [ ] The old worker key was disabled or deleted.
- [ ] Secret-safe evidence was recorded under `_generated/`.

## Related material

- [SecretName Host-Suffix Convention](SecretName-HostSuffix-Convention.md)
- [ProGet Install Runbook](ProGet-Install-Runbook.md)
- [BuildMaster Install and Configuration Runbook](BuildMaster-Install-Runbook.md)
- [Runbook: Bitwarden Secrets Manager Access Tokens](Runbook-BitwardenServiceAccounts.md)
- [BuildMaster/ProGet worker protocol](Task15.182-F04-BuildMaster-ProGet-Worker-Protocol.md)
