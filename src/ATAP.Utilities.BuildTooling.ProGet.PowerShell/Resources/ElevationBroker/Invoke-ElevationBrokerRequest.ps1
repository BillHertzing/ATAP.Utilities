<#
.SYNOPSIS
    Elevated install broker: executes hash-pinned canonical installers on behalf of
    unelevated agents, with no UAC interaction (Task 13.76.g / plan Task 4.2.a).

.DESCRIPTION
    Agents cannot complete an AllUsers module install without elevation, and the
    2026-07-25 Codex review recorded repeated blind `Start-Process -Verb RunAs` retry
    loops as a result. This broker replaces that loop: an unelevated agent drops a
    request JSON file into the requests folder, and this script -- running as
    SvcAnsibleAdmin under a scheduled task with highest privileges -- validates and
    executes it, then writes a result JSON and a transcript.

    SECURITY MODEL. This script runs with administrator rights and takes its input from
    a folder an unelevated caller can write to, so the request file is UNTRUSTED. Every
    control below exists because of that:

      1. A request never names an executable. It names an installer *id*. The id-to-target
         mapping lives in the broker config, which only administrators may write. A request
         that could name a path or a command would be a complete local privilege escalation.
      2. The target's integrity is proven before execution, by whichever control fits its
         kind (Task 13.76.c):
           - commandType 'module' (preferred): the command must come from a module resolved
             under an admin-only trusted root, at or above a pinned minimum version, imported
             by absolute manifest path. The guarantee is that the unelevated caller cannot
             modify code under Program Files, and that PSModulePath -- which is settable
             per-user -- cannot redirect what loads.
           - commandType 'script' (legacy): the file's SHA-256 is re-verified immediately
             before execution, so replacing it on disk does not silently change what runs.
      3. Parameters are allowlisted per installer, by name AND by value pattern. No
         request-supplied string ever reaches a shell; the installer is invoked with a
         parameter hashtable, never with a constructed command line.
      4. The requests folder must not be writable by Everyone / Authenticated Users.
         The broker refuses to start if it is, because that would let any local account
         reach an administrator context.
      5. Each request is claimed by an atomic rename before execution, so a request
         cannot be processed twice or mutated between validation and use (TOCTOU).

    This script is a design deliverable. Registering the scheduled task requires admin
    and is HITL; see ATAP-ElevatedInstallBroker.xml for the registration procedure.

.PARAMETER BrokerRoot
    Root folder holding config.json, requests\, results\, transcripts\, and work\.

.PARAMETER Once
    Drain the pending requests and exit, instead of watching the folder. This is the
    mode the scheduled task uses (it is triggered per request rather than run forever).

.PARAMETER PollSeconds
    Watch-mode poll interval. Ignored when -Once is supplied.

.OUTPUTS
    PSCustomObject per processed request (also written to results\<id>.json).

.EXAMPLE
    pwsh -NoLogo -NonInteractive -File .\Invoke-ElevationBrokerRequest.ps1 -Once

.NOTES
    Task 13.76.g. Companion files: Request-ElevatedInstall.ps1 (client),
    ATAP-ElevatedInstallBroker.xml (scheduled task), Install-ATAPModule-AllUsers.ps1
    (the only installer registered by default).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string] $BrokerRoot = 'C:\ProgramData\ATAP\ElevationBroker',

    [switch] $Once,

    [ValidateRange(1, 300)]
    [int] $PollSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Identities that must NOT have write access to the requests folder. Any of these
# implies "any local account can ask for administrator execution".
$script:ForbiddenWriteIdentities = @(
    'Everyone',
    'BUILTIN\Users',
    'NT AUTHORITY\Authenticated Users',
    'NT AUTHORITY\INTERACTIVE'
)

$script:WriteRights = @(
    [System.Security.AccessControl.FileSystemRights]::Write,
    [System.Security.AccessControl.FileSystemRights]::WriteData,
    [System.Security.AccessControl.FileSystemRights]::CreateFiles,
    [System.Security.AccessControl.FileSystemRights]::Modify,
    [System.Security.AccessControl.FileSystemRights]::FullControl
)

function Write-BrokerLog {
    <#
      Deliberately not PSFramework: the broker runs as a service account under a
      scheduled task, where module autoload and the user's profile are unavailable.
      Output is captured by the per-request transcript.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Message,
        [ValidateSet('Info', 'Warn', 'Error')] [string] $Level = 'Info'
    )

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    Write-Output ('[{0}] [{1}] {2}' -f $stamp, $Level.ToUpperInvariant(), $Message)
}

function Test-BrokerElevated {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-BrokerRequestFolderAcl {
    <#
      Returns the list of over-permissive identities on the requests folder. A non-empty
      result is fatal: the whole security model rests on only trusted developer accounts
      being able to place a request.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)] [string] $Path
    )

    $offenders = [System.Collections.Generic.List[string]]::new()
    $acl = Get-Acl -LiteralPath $Path
    foreach ($rule in $acl.Access) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) { continue }

        $identityName = $rule.IdentityReference.Value
        $isForbidden = $script:ForbiddenWriteIdentities | Where-Object {
            $identityName -eq $_ -or $identityName -eq ($_ -replace '^.*\\', '')
        }
        if (-not $isForbidden) { continue }

        foreach ($right in $script:WriteRights) {
            if ($rule.FileSystemRights.HasFlag($right)) {
                if ($offenders -notcontains $identityName) { $offenders.Add($identityName) }
                break
            }
        }
    }
    return $offenders.ToArray()
}

function Get-BrokerInstallerKind {
    <#
      Returns 'module' or 'script' for a config entry.

      'module' (preferred, Task 13.76.c) runs an exported command from an installed module.
      'script' is the legacy form and still runs a hash-pinned file; it is retained so a machine
      without the module installed can still be served, and so the broker is not silently
      redefined by a config written for the older shape.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)] $Installer
    )

    if ($Installer.PSObject.Properties['commandType'] -and $Installer.commandType) {
        return ([string]$Installer.commandType).ToLowerInvariant()
    }
    if ($Installer.PSObject.Properties['moduleName']) { return 'module' }
    return 'script'
}

function Get-BrokerConfig {
    <#
      Loads and validates the admin-owned broker config. The config is the ONLY place an
      executable -- a script path or a module command -- may be named; a request supplies an
      installer id that must exist here.

      Each entry is validated against the shape its kind requires, so a half-converted entry
      (say, a module entry that still carries only a sha256) is rejected at load rather than
      failing later with the request already claimed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Broker config not found: $Path"
    }

    $config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if (-not $config.PSObject.Properties['installers'] -or -not $config.installers) {
        throw "Broker config declares no installers: $Path"
    }

    foreach ($installer in $config.installers) {
        foreach ($required in 'id', 'allowedParameters') {
            if (-not $installer.PSObject.Properties[$required]) {
                throw "Broker config installer entry is missing '$required': $Path"
            }
        }

        $kind = Get-BrokerInstallerKind -Installer $installer
        switch ($kind) {
            'module' {
                foreach ($required in 'moduleName', 'commandName', 'minimumModuleVersion', 'trustedModuleRoots') {
                    if (-not $installer.PSObject.Properties[$required]) {
                        throw "Broker config module installer '$($installer.id)' is missing '$required': $Path"
                    }
                }
                if (-not @($installer.trustedModuleRoots)) {
                    throw "Broker config module installer '$($installer.id)' declares no trustedModuleRoots. Without one, any writable PSModulePath entry could supply the command."
                }
                try { $null = [version]$installer.minimumModuleVersion }
                catch { throw "Broker config module installer '$($installer.id)' has a malformed minimumModuleVersion '$($installer.minimumModuleVersion)'." }
            }
            'script' {
                foreach ($required in 'path', 'sha256') {
                    if (-not $installer.PSObject.Properties[$required]) {
                        throw "Broker config script installer '$($installer.id)' is missing '$required': $Path"
                    }
                }
                if ($installer.sha256 -notmatch '^[0-9A-Fa-f]{64}$') {
                    throw "Broker config installer '$($installer.id)' has a malformed sha256 pin."
                }
            }
            default {
                throw "Broker config installer '$($installer.id)' declares unknown commandType '$kind'. Use 'module' or 'script'."
            }
        }
    }
    return $config
}

function Resolve-BrokerModuleCommand {
    <#
      Resolves a module-command installer to a concrete, trusted module manifest.

      This is the integrity control that REPLACES the script hash pin, and it rests on a
      different property: a module under an admin-only root cannot be modified by the
      unelevated caller who submits the request, whereas a script in a user-writable location
      can. Three checks, each closing a specific hole:

        1. The module must resolve from a declared trusted root. Without this, a writable
           PSModulePath entry -- and PSModulePath is settable per-user -- could shadow the real
           module and hand the broker attacker-controlled code to run as an administrator.
        2. The version must meet the configured floor, so a stale copy that predates a security
           fix cannot be selected just because it is also installed.
        3. Import is by ABSOLUTE manifest path, never by name, so PSModulePath order plays no
           part in what actually gets loaded.

      Returns the resolved PSModuleInfo-like record for logging and the result file.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)] $Installer
    )

    $moduleName = [string]$Installer.moduleName
    $commandName = [string]$Installer.commandName
    $minimumVersion = [version]$Installer.minimumModuleVersion

    $trustedRoots = @(
        @($Installer.trustedModuleRoots) | ForEach-Object { [IO.Path]::GetFullPath([string]$_).TrimEnd('\') }
    )

    $candidates = @(
        Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue | Where-Object {
            if ($_.Version -lt $minimumVersion) { return $false }
            if (-not $_.ModuleBase) { return $false }
            $moduleBase = [IO.Path]::GetFullPath($_.ModuleBase).TrimEnd('\')
            foreach ($root in $trustedRoots) {
                if ($moduleBase.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
                    $moduleBase.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
                    return $true
                }
            }
            return $false
        }
    )

    if ($candidates.Count -eq 0) {
        $seen = @(Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue |
                ForEach-Object { "$($_.Version) at $($_.ModuleBase)" }) -join '; '
        throw "No installation of '$moduleName' >= $minimumVersion was found under a trusted root ($($trustedRoots -join '; ')). Available: $(if ($seen) { $seen } else { '<none>' })."
    }

    $selected = $candidates | Sort-Object Version -Descending | Select-Object -First 1
    $manifestPath = Join-Path $selected.ModuleBase "$moduleName.psd1"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Resolved module '$moduleName' $($selected.Version) has no manifest at '$manifestPath'."
    }

    Import-Module -FullyQualifiedName $manifestPath -Force -ErrorAction Stop

    $command = Get-Command -Name $commandName -Module $moduleName -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $command) {
        throw "Module '$moduleName' $($selected.Version) does not export '$commandName'."
    }

    return [PSCustomObject]@{
        ModuleName    = $moduleName
        ModuleVersion = $selected.Version.ToString()
        ModuleBase    = $selected.ModuleBase
        ManifestPath  = $manifestPath
        CommandName   = $commandName
        Command       = $command
    }
}

function Test-BrokerRequestParameters {
    <#
      Validates request parameters against the installer's allowlist. Returns the
      validated hashtable, or throws with the precise reason.

      Both halves matter. Names are allowlisted so a request cannot reach a parameter
      the installer author never meant to expose. Values are pattern-checked so a
      permitted parameter cannot smuggle a path traversal or an argument-injection
      payload into a value the installer will use to build a filesystem path.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] $RequestParameters,
        [Parameter(Mandatory = $true)] $AllowedParameters
    )

    $validated = @{}
    $allowedByName = @{}
    foreach ($allowed in $AllowedParameters) { $allowedByName[$allowed.name] = $allowed }

    $supplied = @()
    if ($RequestParameters) {
        $supplied = @($RequestParameters.PSObject.Properties)
    }

    foreach ($property in $supplied) {
        if (-not $allowedByName.ContainsKey($property.Name)) {
            throw "Parameter '$($property.Name)' is not on this installer's allowlist."
        }
        $spec = $allowedByName[$property.Name]
        $value = [string]$property.Value

        if ($spec.PSObject.Properties['pattern'] -and $spec.pattern) {
            if ($value -notmatch $spec.pattern) {
                throw "Parameter '$($property.Name)' value does not match its required pattern."
            }
        }
        $validated[$property.Name] = $value
    }

    foreach ($allowed in $AllowedParameters) {
        $isRequired = $allowed.PSObject.Properties['required'] -and $allowed.required
        if ($isRequired -and -not $validated.ContainsKey($allowed.name)) {
            throw "Required parameter '$($allowed.name)' was not supplied."
        }
    }

    return $validated
}

function Invoke-BrokerRequestFile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)] [string] $RequestPath,
        [Parameter(Mandatory = $true)] [PSCustomObject] $Config,
        [Parameter(Mandatory = $true)] [string] $ResultsDir,
        [Parameter(Mandatory = $true)] [string] $TranscriptsDir,
        [Parameter(Mandatory = $true)] [string] $WorkDir
    )

    $requestId = [IO.Path]::GetFileNameWithoutExtension($RequestPath)
    $startedUtc = (Get-Date).ToUniversalTime()
    $status = 'failed'
    $errorText = $null
    $exitCode = $null
    $installerId = $null
    # Initialized here, not only inside the try: a failure before the config lookup (an
    # unreadable request, an unregistered id) still has to build the result record, and under
    # Set-StrictMode an unset variable throws while reporting the original error.
    $kind = $null
    $target = $null
    $resolvedModule = $null

    # -WhatIf on this broker means "resolve and validate, but do not run the installer". The
    # bookkeeping below -- claiming the request, the transcript, the result record -- is how a
    # dry run reports what it found, so it is explicitly exempt. Only the installer invocation
    # is gated by ShouldProcess. Without -WhatIf:$false here, a dry run moved nothing and then
    # failed reading a file it had only pretended to move.
    #
    # Claim the request by moving it out of the writable folder BEFORE reading it. After this
    # rename the caller can no longer alter the bytes we validate and execute, which closes the
    # validate-then-swap window.
    $claimed = Join-Path $WorkDir ("{0}.json" -f $requestId)
    Move-Item -LiteralPath $RequestPath -Destination $claimed -Force -WhatIf:$false

    $transcriptPath = Join-Path $TranscriptsDir ("{0}.log" -f $requestId)
    $transcriptStarted = $false
    try {
        Start-Transcript -LiteralPath $transcriptPath -Force -WhatIf:$false | Out-Null
        $transcriptStarted = $true
    }
    catch {
        Write-BrokerLog -Level Warn -Message "Could not start transcript for '$requestId': $($_.Exception.Message)"
    }

    try {
        $request = Get-Content -LiteralPath $claimed -Raw | ConvertFrom-Json

        if (-not $request.PSObject.Properties['installerId']) {
            throw "Request does not name an installerId."
        }
        $installerId = [string]$request.installerId

        $installer = @($Config.installers | Where-Object { $_.id -eq $installerId })
        if ($installer.Count -ne 1) {
            throw "Installer id '$installerId' is not registered with this broker."
        }
        $installer = $installer[0]

        $kind = Get-BrokerInstallerKind -Installer $installer

        # Resolve the executable and its integrity control BEFORE validating parameters, so a
        # tampered or missing installer is refused without the request's values ever being used.
        if ($kind -eq 'module') {
            $resolvedModule = Resolve-BrokerModuleCommand -Installer $installer
            $target = "$($resolvedModule.CommandName) [$($resolvedModule.ModuleName) $($resolvedModule.ModuleVersion)]"
            Write-BrokerLog -Message "Resolved '$installerId' to $target from $($resolvedModule.ModuleBase)."
        }
        else {
            if (-not (Test-Path -LiteralPath $installer.path -PathType Leaf)) {
                throw "Registered installer file is missing: $($installer.path)"
            }
            # Re-verify the pin at execution time, not at config-load time: the file could
            # have been replaced in between, and this is the check that makes "hash-pinned"
            # mean something.
            $actualHash = (Get-FileHash -LiteralPath $installer.path -Algorithm SHA256).Hash
            if (-not [string]::Equals($actualHash, $installer.sha256, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Installer hash mismatch for '$installerId'. Pinned $($installer.sha256), found $actualHash. Refusing to execute."
            }
            $target = $installer.path
        }

        $requestParameters = if ($request.PSObject.Properties['parameters']) { $request.parameters } else { $null }
        $parameters = Test-BrokerRequestParameters `
            -RequestParameters $requestParameters `
            -AllowedParameters $installer.allowedParameters

        Write-BrokerLog -Message "Executing installer '$installerId' ($kind) for request '$requestId' with parameters: $($parameters.Keys -join ', ')"

        if ($PSCmdlet.ShouldProcess($target, "run elevated installer for request $requestId")) {
            # Splatting, never a constructed command line: request-supplied values are
            # passed as bound parameters and are never parsed by a shell.
            if ($kind -eq 'module') {
                # Invoke through the resolved CommandInfo, not by name: name lookup at this point
                # could pick up something else that has since entered the session.
                $commandResult = & $resolvedModule.Command @parameters

                # The module cmdlet reports success in its result object rather than by setting
                # $LASTEXITCODE, which only native executables and scripts set. Reading
                # $LASTEXITCODE here would report a stale value from an unrelated earlier call.
                $exitCode = if ($null -ne $commandResult -and
                    $commandResult.PSObject.Properties['ExitStatus'] -and
                    $null -ne $commandResult.ExitStatus) {
                    [int]$commandResult.ExitStatus
                }
                else { 0 }

                if ($exitCode -ne 0) {
                    $detail = if ($commandResult -and $commandResult.PSObject.Properties['ErrorText'] -and $commandResult.ErrorText) {
                        " $($commandResult.ErrorText)"
                    }
                    else { '' }
                    throw "Installer '$installerId' reported ExitStatus $exitCode.$detail"
                }
            }
            else {
                & $installer.path @parameters
                $exitCode = $LASTEXITCODE
                if ($null -eq $exitCode) { $exitCode = 0 }
                if ($exitCode -ne 0) {
                    throw "Installer '$installerId' exited with code $exitCode."
                }
            }
            $status = 'succeeded'
        }
        else {
            $status = 'skipped'
        }
    }
    catch {
        $status = 'failed'
        $errorText = $_.Exception.Message
        Write-BrokerLog -Level Error -Message "Request '$requestId' failed: $errorText"
    }
    finally {
        if ($transcriptStarted) {
            try { Stop-Transcript | Out-Null } catch { }
        }
    }

    $result = [PSCustomObject]@{
        requestId      = $requestId
        installerId    = $installerId
        installerKind  = $kind
        # Records WHAT actually ran, not merely what the config named. For a module command that
        # is the resolved name, version, and base -- the audit answer to "which code executed as
        # an administrator", which a config path alone cannot give once versions coexist.
        resolvedTarget = if ($resolvedModule) {
            "$($resolvedModule.ModuleName) $($resolvedModule.ModuleVersion)::$($resolvedModule.CommandName)"
        }
        else { $target }
        resolvedModuleBase = if ($resolvedModule) { $resolvedModule.ModuleBase } else { $null }
        status         = $status
        exitCode       = $exitCode
        error          = $errorText
        startedUtc     = $startedUtc.ToString('o')
        completedUtc   = (Get-Date).ToUniversalTime().ToString('o')
        transcriptPath = $transcriptPath
        brokerAccount  = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    }

    # Write to a temp name then rename, so a client polling for the result never reads a
    # half-written JSON file. Exempt from -WhatIf for the same reason as the claim: the result
    # record is how a dry run reports what it resolved, and a waiting client would otherwise
    # hang until its timeout with nothing to read.
    $resultPath = Join-Path $ResultsDir ("{0}.json" -f $requestId)
    $resultTemp = "$resultPath.tmp"
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultTemp -Encoding UTF8 -WhatIf:$false
    Move-Item -LiteralPath $resultTemp -Destination $resultPath -Force -WhatIf:$false

    return $result
}

# ── main ──────────────────────────────────────────────────────────────────────
if (-not (Test-BrokerElevated)) {
    throw 'Invoke-ElevationBrokerRequest must run elevated. It is intended to run as the ATAP-ElevatedInstallBroker scheduled task (SvcAnsibleAdmin, highest privileges).'
}

$requestsDir = Join-Path $BrokerRoot 'requests'
$resultsDir = Join-Path $BrokerRoot 'results'
$transcriptsDir = Join-Path $BrokerRoot 'transcripts'
$workDir = Join-Path $BrokerRoot 'work'
$configPath = Join-Path $BrokerRoot 'config.json'

foreach ($dir in $requestsDir, $resultsDir, $transcriptsDir, $workDir) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# @() because an empty array returned from a function is unwrapped to $null by the pipeline,
# and under Set-StrictMode reading .Count on $null throws -- which would take down the broker
# on precisely the good case where the ACL has no offenders.
$aclOffenders = @(Test-BrokerRequestFolderAcl -Path $requestsDir)
if ($aclOffenders.Count -gt 0) {
    throw ("Refusing to run: the requests folder '{0}' grants write access to {1}. Any local account could then obtain administrator execution. Restrict it to the developer account/group and the broker service account." -f $requestsDir, ($aclOffenders -join ', '))
}

$config = Get-BrokerConfig -Path $configPath
Write-BrokerLog -Message "Broker started as $([Security.Principal.WindowsIdentity]::GetCurrent().Name); $(@($config.installers).Count) installer(s) registered; watching '$requestsDir'."

do {
    $pending = @(Get-ChildItem -LiteralPath $requestsDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object CreationTimeUtc)

    foreach ($requestFile in $pending) {
        Invoke-BrokerRequestFile `
            -RequestPath $requestFile.FullName `
            -Config $config `
            -ResultsDir $resultsDir `
            -TranscriptsDir $transcriptsDir `
            -WorkDir $workDir `
            -WhatIf:$WhatIfPreference `
            -Confirm:$false
    }

    if (-not $Once) { Start-Sleep -Seconds $PollSeconds }
} while (-not $Once)
