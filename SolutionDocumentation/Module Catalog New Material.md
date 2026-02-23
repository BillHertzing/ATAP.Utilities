<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# You are an expert on the BitWarden password manager. You are an expert on powershell secret management, and the BitWarden vault extension for secret management. While trying to use the Bitwarden extension for Powershell secrets, I get the following error:

"Failed to retrieve secret from Bitwarden. Exception: Exception setting "match": "The property 'match' cannot be found on this object. Verify that the property exists and can be set." Look over internet postings in related forums, and tell me if this error is because the item is not correctly defined, or because there are bugs in the bitwarden secret extensions?

The specific error you are seeing is caused by a bug (or at least an unhandled data-shape change) in the Bitwarden SecretManagement extension code, not by you defining the item incorrectly in your vault.[^1_1]

## What the error means

Inside the Bitwarden SecretManagement extension, the code iterates over the URIs on each item and tries to set a **match** property on each URI object, casting it to a custom enum type:

- The extension code does something like:
  - `$_ .login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })`.[^1_1]
- This assumes that every `login.uri` object has a `match` property that can be read and set.
- If the object coming back from the Bitwarden CLI does **not** contain a `match` property (for example, because the CLI output format changed or the URI is a simple string / object without that field), PowerShell throws the exact error you are seeing:
  - “The property 'match' cannot be found on this object. Verify that the property exists and can be set.”[^1_1]

So the failure is happening entirely inside the extension while it is trying to normalize the Bitwarden JSON into its own strongly-typed objects.

## Evidence this is an extension bug

Several points from the published extension code and docs indicate this is an implementation issue:

- The extension explicitly manipulates the `login.uris` objects, setting `.match` on them; this is not something you do in your vault configuration.[^1_1]
- The code does not check for the presence of `.match` before trying to set it, so any CLI change, or any item whose URIs are shaped differently (e.g., missing match metadata), will trigger this exception.[^1_1]
- Known issues in the same extension mention that certain Bitwarden CLI versions have breaking/buggy behavior the extension has to work around when listing items, which shows the module is sensitive to upstream changes and has rough edges.[^1_1]

Nothing in the Bitwarden UI lets you “define” or “fix” a `match` property on URIs in a way that would prevent this particular PowerShell exception; it’s purely about how the extension code is handling the JSON it receives.[^1_1]

## What you can do

Given the above, the core issue is on the extension side, but there are a few practical workarounds you can try:

- Ensure you are using:
  - A recent, stable version of the Bitwarden CLI (`bw`), and
  - The latest published version of the Bitwarden SecretManagement extension (there are at least two: `SecretManagement.BitWarden` and `SecretManagement.Warden`; both wrap `bw` and have similar JSON handling).[^1_2][^1_3]
- If you are comfortable editing modules:
  - Locate the loop that does `$_ .login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })` and wrap it in a conditional check such as `if ($_.PSObject.Properties['match']) { ... }` to avoid touching URIs that do not expose that property.[^1_1]
- As an alternative, some people use custom wrapper functions around `bw` plus the built-in `Microsoft.PowerShell.SecretManagement` local vault, instead of relying on the Bitwarden extension module, to avoid these types of tightly-coupled bugs.[^1_4]

So in direct answer to your question: this error is due to how the Bitwarden SecretManagement extension is written and how it interacts with the current Bitwarden CLI output, not because your Bitwarden item is incorrectly defined.
<span style="display:none">[^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_20][^1_5][^1_6][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://www.powershellgallery.com/packages/SecretManagement.Warden/1.1.3/Content/SecretManagement.Warden.Extension\private\Invoke-BitwardenCLI.ps1

[^1_2]: https://github.com/marshallwp/SecretManagement.Warden

[^1_3]: https://www.powershellgallery.com/packages/SecretManagement.BitWarden/0.1.1/Content/SecretManagement.BitWarden.Extension\SecretManagement.BitWarden.Extension.psm1

[^1_4]: https://www.youtube.com/watch?v=0PhTVbuffEE

[^1_5]: https://community.bitwarden.com/t/error-failed-to-fetch-in-chrome-when-logging-in-to-bitwarden-vault-after-first-logout/46156

[^1_6]: https://community.bitwarden.com/t/bitwarden-extension-fails-to-login/39164

[^1_7]: https://www.reddit.com/r/PowerShell/comments/qil3e7/retrieve_secrets_from_bitwarden/

[^1_8]: https://community.bitwarden.com/t/bug-bitwarden-secrets-lookup-errors-when-no-secrets-are-available/67718

[^1_9]: https://forum.devolutions.net/topics/35611/unable-to-retrieve-bitwarden-credentials

[^1_10]: https://community.bitwarden.com/t/error-while-creating-secret-bitwarden-sdk-napi/63071

[^1_11]: https://www.reddit.com/r/kubernetes/comments/1maptgy/anyone_using_externalsecrets_and_bitwarden/

[^1_12]: https://www.reddit.com/r/Bitwarden/comments/1nklbsc/bitwarden_bugs_with_account_settings_login_fields/

[^1_13]: https://github.com/Skyvern-AI/skyvern/issues/2604

[^1_14]: https://community.bitwarden.com/t/better-match-detection-settings/62136

[^1_15]: https://community.bitwarden.com/t/exception-message-connection-failure-on-save/71713

[^1_16]: https://community.bitwarden.com/t/improvements-to-hidden-fields/84544

[^1_17]: https://community.bitwarden.com/t/unable-to-retrieve-bitwarden-credentials/56473

[^1_18]: https://community.bitwarden.com/t/match-detection-how-to-make-it-detect-my-login-path-better/46939

[^1_19]: https://github.com/bitwarden/sdk-sm/issues/34

[^1_20]: https://community.bitwarden.com/t/how-to-configure-the-field-to-match/62266

---

# I want to run a CI/CD pipeline on a build/computer that I do not login to. Thus pipeline is run by a 'JenkinsClinet' service on the build/test computer. Tell me best practices to load and unlock the BitWarden vault, so that the 'jenkindsClient' service can access the vault and read secrets from the vault

Use the Bitwarden CLI with an API key and a non-interactive unlock flow, then pass the BW session into the JenkinsClient service environment so the agent can read secrets without anyone logging in interactively.[^2_1][^2_2]

## High‑level pattern

For a headless CI/CD runner (Jenkins agent or Windows service):

- Use a **dedicated Bitwarden account or org** for CI/CD, with minimal vault access.
- Authenticate the CLI using **API key** (client_id / client_secret), not interactive master password prompts.[^2_2][^2_1]
- Unlock the vault non‑interactively and capture the **BW_SESSION** token.
- Inject **BW_SESSION** into the Jenkins agent process environment so all pipeline steps can call `bw` (or the PowerShell SecretManagement Bitwarden extension) without prompts.

## Logging in non‑interactively

Best practice is to log in with an API key and keep that API key in Jenkins credentials, not on disk or in job scripts.[^2_3][^2_1]

Typical one‑time login (per workspace / node image):

```bash
bw login --apikey    # or via BW_CLIENTID / BW_CLIENTSECRET env vars
```

For automated use, set:

- `BW_CLIENTID`
- `BW_CLIENTSECRET`

as Jenkins “secret text” / “username + password” credentials and map them into the environment of the JenkinsClient service.[^2_1][^2_3][^2_2]

Then your startup script (or first pipeline stage on that node) can run:

```bash
bw login --apikey --raw
```

or simply rely on `BW_CLIENTID`/`BW_CLIENTSECRET` and let `bw unlock` handle the unlock after login.[^2_1]

## Unlocking and managing BW_SESSION

The vault must be **unlocked** before listing or fetching items.[^2_1]

- Unlock non‑interactively with either:
  - `bw unlock --passwordenv BW_PASSWORD --raw`
  - `bw unlock --passwordfile /secure/path/mp.txt --raw`[^2_1]

This returns the session key (no shell boilerplate if you use `--raw`):

```bash
BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
export BW_SESSION
```

In PowerShell:

```powershell
$env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw
```

Key practices:

- Store `BW_PASSWORD` in Jenkins credentials, **not** in scripts or files. If you must use `--passwordfile`, lock down the file ACL so only the Jenkins service account can read it.[^2_1]
- Do **not** write `BW_SESSION` to disk; keep it only in environment scope of the JenkinsClient process / job.[^2_1]
- Use `bw lock` at the end of long‑lived jobs if you want to force re‑unlock for next run; otherwise, the CLI will treat the vault as unlocked while the session is valid.[^2_4][^2_1]

## Integrating with Jenkins service

For a Jenkins agent running as a Windows service or Linux daemon:

- Run the agent under a **dedicated OS account** (e.g., `jenkinsci` or your `JenkinsClient` identity).
- Ensure that account:
  - Has the Bitwarden CLI installed and on PATH.
  - Has a minimal home directory where `bw` can store its encrypted local cache.
- During agent startup (or in an init script that runs before any jobs):
  - Load `BW_CLIENTID`, `BW_CLIENTSECRET`, and `BW_PASSWORD` from the Jenkins credential store into environment variables.
  - Execute `bw login --apikey` (if not already logged in) and `bw unlock --passwordenv BW_PASSWORD --raw` to set `BW_SESSION` in the agent environment.
- All downstream stages then use `bw` commands with no further prompts, e.g.:

```bash
DB_PASS=$(bw get password my-db-secret --session "$BW_SESSION")
```

or via PowerShell SecretManagement:

```powershell
Get-Secret -Name 'my-db-secret'
```

as long as the Bitwarden SecretManagement extension is configured to use the CLI and sees `BW_SESSION` in the environment.

If you prefer tighter integration, consider the Jenkins Bitwarden Credentials Provider plugin, which lets Jenkins treat Bitwarden items as native Jenkins credentials and handles token management under the hood.[^2_5][^2_3]

## Security and operational best practices

- Use **separate vault / org** for CI/CD, with least privilege access to only the secrets needed for pipelines.[^2_6][^2_2]
- Rotate:
  - Bitwarden account master password / API key.
  - Any secrets fetched into jobs (DB passwords, API keys) on a regular cadence.[^2_3]
- Avoid printing secrets or the BW session in logs; mask `BW_SESSION` and secret values with Jenkins’ credential masking features.
- For containers/ephemeral agents, bake `bw` into the image and add an entrypoint or wrapper script that handles `bw login` + `bw unlock` on startup, then starts the Jenkins agent process, similar to existing Bitwarden client images that support AUTO_LOGIN/AUTO_UNLOCK.[^2_7]

If you share more about your current OS (Windows vs Linux) and whether you want to stay with the SecretManagement.BitWarden module or move to Bitwarden Secrets Manager proper, a concrete PowerShell/Jenkinsfile snippet can be sketched out.
<span style="display:none">[^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_16][^2_17][^2_18][^2_19][^2_20][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://bitwarden.com/help/cli/

[^2_2]: https://community.bitwarden.com/t/bitwarden-as-a-iaas-ci-cd-secret-vault/32013/2

[^2_3]: https://hoop.dev/blog/the-simplest-way-to-make-bitwarden-jenkins-work-like-it-should/

[^2_4]: https://github.com/bitwarden/clients/issues/16527

[^2_5]: https://plugins.jenkins.io/bitwarden-credentials-provider/

[^2_6]: https://community.bitwarden.com/t/bitwarden-as-a-iaas-ci-cd-secret-vault/32013

[^2_7]: https://hub.docker.com/r/jitesoft/bitwarden-client

[^2_8]: https://bitwarden.com/help/gitlab-integration/

[^2_9]: https://www.youtube.com/watch?v=mdbpXEzyrJY

[^2_10]: https://www.gruntwork.io/blog/how-to-securely-store-secrets-in-bitwarden-cli-and-load-them-into-your-zsh-shell-when-needed

[^2_11]: https://github.com/bitwarden/cli/issues/200

[^2_12]: https://community.bitwarden.com/t/bw-unlock-fails-when-run-at-startup-from-zsrhc-beacuse-it-no-longer-prompts-for-my-password/82643

[^2_13]: https://expert-soft.com/blog/how-to-build-an-efficient-ci-cd-pipeline-for-headless-cms/

[^2_14]: https://www.reddit.com/r/Bitwarden/comments/s930ik/noninteractive_api_login_via_powershell/

[^2_15]: https://dev.to/s1ks1/use-bwenv-to-sync-your-bitwarden-secrets-into-your-shell-environment-23fh

[^2_16]: https://community.bitwarden.com/t/do-you-use-the-cli-we-have-questions/85941

[^2_17]: https://community.bitwarden.com/t/bug-sometime-cant-t-unlock-vault/65997

[^2_18]: https://www.reddit.com/r/Bitwarden/comments/12or62q/what_is_point_of_new_secrets_manager/

[^2_19]: https://github.com/bitwarden/clients/issues/4674

[^2_20]: https://community.bitwarden.com/t/improve-the-bitwarden-cli-utility/86287

---

# following that same general process, wwwhen I launch a build /test process from VisualStudioCode on my development computer, on whihc I am logged in, ensure the build/test tasks can run scripts that access the secrets from Bitwarden. In this scenario, I already have a valid BW_Session key (set by a user login script

Make VS Code inherit your already‑set `BW_SESSION` and then keep all Bitwarden access inside PowerShell tasks that run under that environment.[^3_1][^3_2]

## Ensure BW_SESSION is visible to VS Code

You already have a login script that sets `BW_SESSION`; the key is where that runs:

- If using PowerShell:
  - Set `BW_SESSION` in your shell **before** launching VS Code, for example in your PowerShell profile (`Microsoft.PowerShell_profile.ps1`):[^3_2][^3_3]

```powershell
# Profile snippet (you already do something like this)
$env:BW_SESSION = bw unlock --raw
```

    - Start VS Code from that same shell (`code .`). VS Code inherits the environment, including `BW_SESSION`, so any integrated terminal or PowerShell task sees it.[^3_4][^3_5]

- Verify inside VS Code:
  - Open an integrated PowerShell terminal and run:

```powershell
$env:BW_SESSION
bw status
```

`bw status` should show `userEmail` and `status: "unlocked"` for the CLI.[^3_6][^3_1]

## Configure VS Code tasks to use the session

Define your build/test tasks so they run in a shell that already has `BW_SESSION` rather than trying to set it again.

Example `tasks.json` (PowerShell shell, using the inherited env):[^3_5]

```jsonc
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build-with-secrets",
      "type": "shell",
      "command": "pwsh",
      "args": ["-NoLogo", "-NoProfile", "-Command", "./build.ps1"],
      "problemMatcher": []
    }
  ]
}
```

Inside `build.ps1` you can use Bitwarden directly:

```powershell
# Optional sanity check
bw status | Out-Host    # Should say unlocked

# Using Bitwarden CLI
$DbPassword = bw get password 'my-db-secret'

# Or via SecretManagement BitWarden / Warden extension
$DbPassword = Get-Secret -Name 'my-db-secret'
```

The SecretManagement.BitWarden / Warden extensions detect `BW_SESSION` and add `--session $env:BW_SESSION` to their `bw` calls, so as long as that env var is present, there’s no interactive prompt.[^3_7][^3_8]

## If VS Code is started from GUI

If you usually start VS Code from the Windows Start menu / dock:

- That process does **not** inherit your interactive shell’s `BW_SESSION`.[^3_4]
- In that case either:
  - Add the Bitwarden unlock step to a script that you call at the start of each task:

```powershell
# unlock-if-needed.ps1
if (-not $env:BW_SESSION) {
    $env:BW_SESSION = bw unlock --raw   # will prompt once in VS Code terminal
}
```

And call it at the top of `build.ps1`. - Or make `BW_SESSION` a user‑level environment variable (less secure, but convenient), set via System Properties or `[System.Environment]::SetEnvironmentVariable()`; then restart VS Code so it picks it up.[^3_9][^3_3][^3_10]

Given your workflow, the cleanest approach is:

1. Log in / unlock Bitwarden in your normal PowerShell, setting `BW_SESSION` there.
2. Launch VS Code (`code .`) from that shell.
3. Run build/test tasks that just assume `BW_SESSION` and call `bw` or `Get-Secret`.

That keeps the login UX in your profile script, and your build scripts remain non‑interactive but still able to reach Bitwarden.
<span style="display:none">[^3_11][^3_12][^3_13][^3_14][^3_15][^3_16][^3_17][^3_18][^3_19][^3_20]</span>

<div align="center">⁂</div>

[^3_1]: https://bitwarden.com/help/cli/

[^3_2]: https://ryan.himmelwright.net/post/bitwarden-cli/

[^3_3]: https://configu.com/blog/setting-environment-variables-in-powershell-a-practical-guide/

[^3_4]: https://forums.powershell.org/t/visual-studio-code-and-environmental-variables/13349

[^3_5]: https://code.visualstudio.com/docs/debugtest/tasks

[^3_6]: https://community.bitwarden.com/t/cli-keeps-asking-for-password-in-powershell/90610

[^3_7]: https://www.powershellgallery.com/packages/SecretManagement.BitWarden/0.1.1/Content/SecretManagement.BitWarden.Extension\SecretManagement.BitWarden.Extension.psm1

[^3_8]: https://github.com/marshallwp/SecretManagement.Warden

[^3_9]: https://community.bitwarden.com/t/cli-session-key/13397

[^3_10]: https://www.reddit.com/r/Bitwarden/comments/ul3zy1/is_the_key_in_bw_session_used_by_bwcli/

[^3_11]: https://www.gruntwork.io/blog/how-to-securely-store-secrets-in-bitwarden-cli-and-load-them-into-your-zsh-shell-when-needed

[^3_12]: https://writerit.nl/productivity/bitwarden/load-bitwarden-cli-environment-variable-with-one-command/

[^3_13]: https://stackoverflow.com/questions/52953614/set-environment-variables-in-task-json-in-vscode-for-wsl

[^3_14]: https://www.powershellgallery.com/packages/SecretManagement.BitWarden/0.1.0/Content/SecretManagement.BitWarden.Extension\SecretManagement.BitWarden.Extension.psm1

[^3_15]: https://community.bitwarden.com/t/why-does-cli-export-ask-for-password/18155

[^3_16]: https://www.reddit.com/r/PowerShell/comments/qil3e7/retrieve_secrets_from_bitwarden/

[^3_17]: https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/using-vscode?view=powershell-7.5

[^3_18]: https://bitwarden.com/help/secrets-manager-cli/

[^3_19]: https://github.com/bitwarden/cli/issues/378

[^3_20]: https://dev.to/stevengonsalvez/password-manage-your-environment-and-secrets-with-bitwarden-13n5
