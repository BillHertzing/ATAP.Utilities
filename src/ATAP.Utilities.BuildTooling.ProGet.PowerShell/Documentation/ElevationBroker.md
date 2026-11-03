# Elevation broker operator guide

The broker runs an allowlisted installer under its configured service account.
`Request-ElevatedInstall` stages a request and asks the scheduled task to drain
it; it does not accept an arbitrary command or installer path. This guide
describes the corrected source behavior. Registration, release, enablement,
grants and installation require the applicable operator authorization and are
not established by this document.

## Bootstrap registration and task state

Use an elevated PowerShell session and the reviewed module source in the selected
sprint worktree when the installed module cannot bootstrap itself. Before
registration, the service account and the exact Task Scheduler folder must
already exist under the approved bootstrap ACLs. The registrar resolves the
service-account password by `SecretName` through `Get-SecretATAP`; do not place
the secret value in a file or on a command line.

From the repository root, an administrator can import the module from source and
register using its defaults:

```powershell
Import-Module ./src/ATAP.Utilities.BuildTooling.ProGet.PowerShell/ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1 -Force
Register-ElevationBrokerTask -Verbose
```

The default task is `\ATAP-Broker\ATAP-ElevatedInstallBroker`, the broker root
is `C:\ProgramData\ATAP\ElevationBroker`, and the service account is
`.\SvcAnsibleAdmin`. `-TaskPath`, `-TaskName`, `-BrokerRoot`, `-ServiceAccount`,
`-SecretName`, `-RequesterPrincipal` and `-TemplatePath` select the corresponding
configured values. `-SkipPayloadDeployment` requires the payload and config to
exist already. An existing `config.json` is preserved unless `-ForcePayload` is
explicitly selected; it is the broker's trust anchor.

For a new registration the task is **disabled**, and its BootTrigger is also
**disabled**. Registration does not enable or start either. Updating an existing
task preserves its enabled state and complete existing trigger subtree, including
an absent trigger; it does not automatically disable an already enabled task.
The registrar retains a preimage for an existing task. On a registration failure,
preserve the reported stage and backup paths, inspect the actual scheduler state,
and correct forward; there is no automatic retry or restore.

Start rights and enabling the task are distinct from registration. After separate
authorization, an administrator can grant the intended requester task read and
execute rights, without granting task modification rights:

```powershell
Grant-ElevationBrokerStartRights -Principal '<domain-or-host>\<requester>'
```

For a non-default task specify the matching `-TaskPath` and `-TaskName` to both
registration and the grant. Enabling the task or its boot trigger and starting
the task are separate operator actions; neither follows from this grant. Verify
the actual task state and access before use.

## Release and request an exact AllUsers install

Use the established `build-deploy-module` workflow and the known BuildMaster
module pipeline for the selected sprint source. Resolve the application and
package context, prepare and review the release, and recompute the resolved
package version after the release-preparation commit. Verify the selected version
is available for the intended immutable release and that the context permits
Production promotion. Start `Start-BuildMasterModulePipelineBatch -ModuleName
<ModuleName>` only through the authorized release process. A queued pipeline is
not a successful release.

Wait until the exact resolved version appears in `powershellget-stable`, then run
`Invoke-PromotedModuleTests` against that feed artifact. Stop on failure. Download
the exact tested package from the same feed and calculate its SHA-256; use that
pin and feed URL in the broker request. The hash binds installation to those
downloaded bytes; it is not an independent guarantee that the feed is trustworthy.
The installer also enforces the configured package-signature policy.

```powershell
$moduleName = '<ModuleName>'
$version = '<ResolvedPackageVersion>'
$feedUrl = (Get-PSRepository -Name powershellget-stable).SourceLocation
$stage = Join-Path '<repository-root>/_generated' ('broker-package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Save-Package -Name $moduleName -RequiredVersion $version -Source powershellget-stable `
  -Path $stage -ProviderName NuGet -Force | Out-Null
$packages = @(Get-ChildItem -LiteralPath $stage -Filter '*.nupkg' -Recurse)
if ($packages.Count -ne 1) { throw 'Expected exactly one downloaded package.' }
$expectedSha256 = (Get-FileHash -LiteralPath $packages[0].FullName -Algorithm SHA256).Hash
$result = Request-ElevatedInstall -InstallerId 'install-atap-module-allusers' -Parameters @{
  ModuleName = $moduleName
  RequiredVersion = $version
  Repository = 'powershellget-stable'
  FeedUrl = $feedUrl
  ExpectedSha256 = $expectedSha256
}
if ($result.status -ne 'succeeded') {
  throw "Broker status $($result.status): $($result.error); transcript: $($result.transcriptPath)"
}
```

The request's `-BrokerRoot`, `-BrokerTaskPath` and `-BrokerTaskName` must match
the registration when defaults differ. `-TimeoutSeconds` and `-PollMilliseconds`
control waiting; `-SkipBrokerStart` stages without starting and does not itself
guarantee a later drain. Record the request ID, status and transcript path. A
`broker-unreachable` result can leave a request staged; a timeout or failure also
requires inspection of the request, task and transcript before a separately
authorized correction. Do not blindly retry, assume a disabled boot trigger will
drain the request, or fall back to UAC or direct unelevated AllUsers installation.

After a successful broker result, verify the exact version at the AllUsers module
location and in a fresh shell. Report any earlier `PSModulePath` entry that
shadows it. Source tests, a local package, or pipeline submission alone do not
prove stable-feed promotion, installation or use by the consuming shell.
