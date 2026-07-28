param(
    [Parameter(Mandatory = $false)]
    [string] $ModuleName = '',

    [Parameter(Mandatory = $false)]
    [string] $RequiredVersion = '',

    [Parameter(Mandatory = $false)]
    [string] $Repository = '',

    [Parameter(Mandatory = $false)]
    [string] $FeedUrl = '',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string] $ExpectedSha256 = ''
)

function Get-ATAPModuleVersionInstallPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,

        [Parameter(Mandatory = $true)]
        [string] $RequiredVersion,

        [string] $ModulesRoot = 'C:\Program Files\PowerShell\Modules'
    )

    return Join-Path -Path (Join-Path -Path $ModulesRoot -ChildPath $ModuleName) -ChildPath $RequiredVersion
}

function Test-ATAPModuleFileHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $ExpectedSha256
    )

    $actual = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
    return [string]::Equals($actual, $ExpectedSha256, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ATAPModuleDependencyFloorViolations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array] $DependencyRequirements,

        [Parameter(Mandatory = $true)]
        [hashtable] $InstalledModules
    )

    $violations = New-Object System.Collections.Generic.List[pscustomobject]

    foreach ($dependency in $DependencyRequirements) {
        $dependencyName = $null
        $minimumVersion = [version]'0.0.0'

        if ($dependency -is [string]) {
            $dependencyName = $dependency
        } else {
            if ($dependency.ModuleName) {
                $dependencyName = [string] $dependency.ModuleName
            } elseif ($dependency.Name) {
                $dependencyName = [string] $dependency.Name
            }

            if ($dependency.ModuleVersion) {
                try {
                    $minimumVersion = [version] $dependency.ModuleVersion
                } catch {
                    $minimumVersion = [version]'0.0.0'
                }
            } elseif ($dependency.RequiredVersion) {
                try {
                    $minimumVersion = [version] $dependency.RequiredVersion
                } catch {
                    $minimumVersion = [version]'0.0.0'
                }
            }
        }

        if (-not $dependencyName) {
            continue
        }

        if (-not $InstalledModules.ContainsKey($dependencyName)) {
            $violations.Add([pscustomobject]@{
                    Dependency         = $dependencyName
                    RequiredMinimum    = $minimumVersion.ToString()
                    Installed          = ''
                    Status             = 'Missing'
                })
            continue
        }

        try {
            $installedVersion = [version] $InstalledModules[$dependencyName]
        } catch {
            $installedVersion = [version]'0.0.0'
        }

        if ($installedVersion -lt $minimumVersion) {
            $violations.Add([pscustomobject]@{
                    Dependency         = $dependencyName
                    RequiredMinimum    = $minimumVersion.ToString()
                    Installed          = $installedVersion.ToString()
                    Status             = 'BelowMinimum'
                })
        }
    }

    return $violations.ToArray()
}

function Get-ATAPModuleDependencyRequirementsFromManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ModuleManifestPath
    )

    $manifest = Import-PowerShellDataFile -Path $ModuleManifestPath
    if (-not $manifest.ContainsKey('RequiredModules')) {
        return @()
    }

    if ($null -eq $manifest.RequiredModules) {
        return @()
    }

    return @($manifest.RequiredModules)
}

function Get-ATAPModuleInstalledVersions {
    [CmdletBinding()]
    param()

    $installed = @{}

    foreach ($module in Get-Module -ListAvailable -ErrorAction SilentlyContinue) {
        if (-not $module -or -not $module.Name) {
            continue
        }

        if (-not $installed.ContainsKey($module.Name) -or ([version]$module.Version -gt [version]$installed[$module.Name])) {
            $installed[$module.Name] = $module.Version.ToString()
        }
    }

    return $installed
}

function Get-ATAPModuleDownloadCandidateUris {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BaseFeedUrl,

        [Parameter(Mandatory = $true)]
        [string] $ModuleName,

        [Parameter(Mandatory = $true)]
        [string] $RequiredVersion
    )

    $normalizedBase = $BaseFeedUrl.Trim().TrimEnd('/')
    $candidates = New-Object System.Collections.Generic.List[string]
    $ordered = New-Object System.Collections.Generic.List[string]

    try {
        $uri = [uri] $normalizedBase
        if ($uri.Host -ieq 'utat01') {
            $builder = New-Object System.UriBuilder($uri)
            $builder.Host = 'localhost'
            $fallback = $builder.Uri.AbsoluteUri.TrimEnd('/')
            if ($fallback -notin $ordered) {
                $ordered.Add($fallback)
            }
        }
    } catch {
        # Keep caller-visible parsing for malformed URIs.
        throw
    }

    if ($normalizedBase -notin $ordered) {
        $ordered.Add($normalizedBase)
    }

    # Endpoint order matters on ProGet Free (Task 13.76.d deployment, 2026-07-25).
    #
    #   <feed>/package/<name>/<version>          works
    #   <feed>/api/v2/package/<name>/<version>   404 / "OData method is not implemented"
    #
    # The original implementation emitted ONLY the /api/v2 form, so every download failed
    # against the ProGet the ATAP feeds actually run on. Emit the direct form first and keep
    # /api/v2 as a fallback for a NuGet server that does implement OData v2.
    foreach ($base in $ordered) {
        $baseNoTrailing = $base.TrimEnd('/')
        if ($baseNoTrailing -match '/api/v2$') {
            # Caller supplied an explicit OData base; honor it, then try it without the suffix.
            $candidates.Add("$baseNoTrailing/package/$ModuleName/$RequiredVersion")
            $candidates.Add("$($baseNoTrailing -replace '/api/v2$', '')/package/$ModuleName/$RequiredVersion")
            continue
        }
        $candidates.Add("$baseNoTrailing/package/$ModuleName/$RequiredVersion")
        $candidates.Add("$baseNoTrailing/api/v2/package/$ModuleName/$RequiredVersion")
    }

    return $candidates.ToArray()
}

function Test-ATAPModuleEndpointReachable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    try {
        $null = Invoke-WebRequest -Method Head -Uri $Uri -TimeoutSec 10
        return $true
    } catch {
        return $false
    }
}

function Get-ATAPModuleDownloadUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FeedUrl,

        [Parameter(Mandatory = $true)]
        [string] $ModuleName,

        [Parameter(Mandatory = $true)]
        [string] $RequiredVersion
    )

    $downloadCandidates = Get-ATAPModuleDownloadCandidateUris -BaseFeedUrl $FeedUrl -ModuleName $ModuleName -RequiredVersion $RequiredVersion
    foreach ($downloadUri in $downloadCandidates) {
        if (Test-ATAPModuleEndpointReachable -Uri $downloadUri) {
            return $downloadUri
        }
    }

    throw "No reachable download URI was found for $ModuleName $RequiredVersion."
}

function Test-ATAPModuleAllUsersInstalled {
    [CmdletBinding()]
    param()

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-ATAPModuleAllUsers {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ModuleName,

        [Parameter(Mandatory = $true)]
        [string] $RequiredVersion,

        [Parameter(Mandatory = $true)]
        [string] $Repository,

        [Parameter(Mandatory = $true)]
        [string] $FeedUrl,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9A-Fa-f]{64}$')]
        [string] $ExpectedSha256
    )

    $result = [ordered]@{
        ModuleName           = $ModuleName
        RequiredVersion      = $RequiredVersion
        Repository           = $Repository
        FeedUrl              = $FeedUrl
        StartTime            = (Get-Date)
        EndTime              = $null
        ExitStatus           = 0
        ActualSha256         = $null
        DownloadUri          = $null
        DependencyFailures   = @()
        VersionPath          = $null
        TranscriptPath       = $null
        ResultJsonPath       = $null
        ErrorText            = ''
        TempRepositoryName   = $null
        RolledBack           = $false
    }

    $tempPaths = @()
    $transcriptStarted = $false
    $createdVersionPath = $null

    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $deployRoot = Join-Path $repoRoot '_generated\deploy'
    if (-not (Test-Path -LiteralPath $deployRoot)) {
        New-Item -ItemType Directory -Path $deployRoot -Force | Out-Null
    }

    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $result.TranscriptPath = Join-Path $deployRoot "Install-ATAPModule-AllUsers-$ModuleName-$RequiredVersion-$ts.log"
    Start-Transcript -Path $result.TranscriptPath -Force | Out-Null
    $transcriptStarted = $true

    try {
        if (-not (Test-ATAPModuleAllUsersInstalled)) {
            $result.ExitStatus = 2
            throw "Install-ATAPModule-AllUsers requires Administrator rights. Re-run this script from an elevated shell."
        }

        if (-not (Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue)) {
            $tempName = "ATAP-Temp-Feed-Install-$([guid]::NewGuid().Guid.Replace('-', ''))"
            Register-PSRepository -Name $tempName -SourceLocation $FeedUrl -InstallationPolicy Trusted -ErrorAction Stop
            $result.TempRepositoryName = $tempName
            $tempPaths += $tempName
        }

        $result.DownloadUri = Get-ATAPModuleDownloadUri -FeedUrl $FeedUrl -ModuleName $ModuleName -RequiredVersion $RequiredVersion

        $tempRoot = Join-Path $env:TEMP "ATAP-InstallModule-$([guid]::NewGuid().Guid.Replace('-', ''))"
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $tempPaths += $tempRoot

        $nupkgPath = Join-Path $tempRoot "$ModuleName.$RequiredVersion.nupkg"
        Invoke-WebRequest -Uri $result.DownloadUri -OutFile $nupkgPath -UseBasicParsing -ErrorAction Stop

        $actualHash = (Get-FileHash -Algorithm SHA256 -Path $nupkgPath).Hash
        $result.ActualSha256 = $actualHash
        if (-not (Test-ATAPModuleFileHash -Path $nupkgPath -ExpectedSha256 $ExpectedSha256)) {
            $result.ExitStatus = 1
            throw "SHA-256 validation failed for $nupkgPath."
        }

        $extractPath = Join-Path $tempRoot 'expand'
        Expand-Archive -Path $nupkgPath -DestinationPath $extractPath -Force
        $tempPaths += $extractPath

        $moduleManifest = Get-ChildItem -Path $extractPath -Recurse -Filter '*.psd1' -File |
            Where-Object { $_.Name -like "$ModuleName*.psd1" } |
            Select-Object -First 1
        if (-not $moduleManifest) {
            $result.ExitStatus = 1
            throw "Could not locate a module manifest in downloaded package $nupkgPath."
        }

        $dependencyRequirements = Get-ATAPModuleDependencyRequirementsFromManifest -ModuleManifestPath $moduleManifest.FullName
        $installedModules = Get-ATAPModuleInstalledVersions
        $result.DependencyFailures = Get-ATAPModuleDependencyFloorViolations -DependencyRequirements $dependencyRequirements -InstalledModules $installedModules
        if ($result.DependencyFailures.Count -gt 0) {
            $result.ExitStatus = 1
            throw 'Installed module dependencies do not satisfy floor requirements.'
        }

        $versionTargetPath = Get-ATAPModuleVersionInstallPath -ModuleName $ModuleName -RequiredVersion $RequiredVersion
        if (Test-Path -LiteralPath $versionTargetPath) {
            $result.ExitStatus = 1
            throw "Version folder already exists and was not overwritten: $versionTargetPath"
        }

        if ($PSCmdlet.ShouldProcess($versionTargetPath, "Install $ModuleName v$RequiredVersion to $versionTargetPath")) {
            $stagingFolder = Join-Path $tempRoot "staging\$ModuleName\$RequiredVersion"
            New-Item -ItemType Directory -Path $stagingFolder -Force | Out-Null

            # Copy the CONTENTS of the manifest's folder, not the folder itself. Passing the
            # directory to -LiteralPath nests it, producing
            # <ModulesRoot>\<Name>\<Version>\expand\<Name>.psd1 instead of
            # <ModulesRoot>\<Name>\<Version>\<Name>.psd1 -- the post-staging manifest check
            # then fails and the version folder is left behind, blocking every retry with
            # "Version folder already exists". Observed 2026-07-25 installing
            # SprintLifecycle 0.1.6. The wildcard form matches the layout Install-Module
            # produces for the already-installed sibling versions.
            $packageContentRoot = Split-Path -Path $moduleManifest.FullName -Parent
            Copy-Item -Path (Join-Path $packageContentRoot '*') -Destination $stagingFolder -Recurse -Force

            New-Item -ItemType Directory -Path (Split-Path -Path $versionTargetPath -Parent) -Force | Out-Null
            Move-Item -LiteralPath $stagingFolder -Destination $versionTargetPath
            $result.VersionPath = $versionTargetPath
            # Remember that THIS run created the folder, so a later validation failure can
            # roll it back. Without this, a failed install leaves a half-populated version
            # folder that makes every retry fail with "Version folder already exists" -- a
            # different error than the real one, needing manual admin cleanup.
            $createdVersionPath = $versionTargetPath
        } else {
            $result.ExitStatus = 1
            throw 'Operation was cancelled by -WhatIf.'
        }

        $stagedManifest = Join-Path $versionTargetPath $moduleManifest.Name
        if (-not (Test-Path -LiteralPath $stagedManifest)) {
            $result.ExitStatus = 1
            throw "Installed module manifest was not found after staging: $stagedManifest"
        }

        Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        Import-Module -FullyQualifiedName $stagedManifest -Force -ErrorAction Stop

        # Match on ModuleBase, not Path. When a manifest declares a RootModule, PowerShell
        # sets Module.Path to the .psm1, so comparing Path to the .psd1 never matches and
        # this check failed even on a perfectly good install (observed 2026-07-25). What
        # actually matters is that the module resolved from the folder we just staged --
        # not from some other version already on PSModulePath.
        $imported = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ModuleBase -and
                ([IO.Path]::GetFullPath($_.ModuleBase).TrimEnd('\') -ieq [IO.Path]::GetFullPath($versionTargetPath).TrimEnd('\'))
            } |
            Select-Object -First 1

        if (-not $imported) {
            $result.ExitStatus = 1
            $loadedFrom = (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.ModuleBase }) -join '; '
            throw "Fresh-import validation failed for $stagedManifest. Expected a module loaded from '$versionTargetPath'; loaded module base(s): '$loadedFrom'."
        }

        if ($imported.Version -ne [version] $RequiredVersion) {
            $result.ExitStatus = 1
            throw "Installed module version '$($imported.Version)' does not match requested version '$RequiredVersion'."
        }
    } catch {
        $result.ExitStatus = if ($result.ExitStatus -gt 0) { $result.ExitStatus } else { 1 }
        $result.ErrorText = $_.Exception.Message

        # Roll back a version folder this run created so the install stays all-or-nothing and
        # the next attempt reports the real failure instead of "Version folder already exists".
        # Only a folder created in THIS run is removed; a pre-existing install is never touched.
        if ($createdVersionPath -and (Test-Path -LiteralPath $createdVersionPath)) {
            try {
                Remove-Item -LiteralPath $createdVersionPath -Recurse -Force -ErrorAction Stop
                $result.VersionPath = $null
                $result.RolledBack = $true
            } catch {
                $result.ErrorText += " Additionally, rollback of '$createdVersionPath' failed: $($_.Exception.Message). Remove it manually before retrying."
            }
        }

        Write-Error $result.ErrorText
    } finally {
        $result.EndTime = Get-Date

        $result.ResultJsonPath = Join-Path $deployRoot "Install-ATAPModule-AllUsers-$ModuleName-$RequiredVersion-$ts.json"
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $result.ResultJsonPath

        if ($result.TempRepositoryName) {
            Unregister-PSRepository -Name $result.TempRepositoryName -ErrorAction SilentlyContinue
        }

        foreach ($path in $tempPaths) {
            if (Test-Path -LiteralPath $path) {
                if ($path -like 'ATAP-Temp-Feed-Install-*') {
                    continue
                }
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        if ($transcriptStarted) {
            try {
                Stop-Transcript | Out-Null
            } catch {
                # Ignore transcript stop errors to preserve deterministic cleanup.
            }
        }
    }

    return $result
}

if (($MyInvocation.InvocationName -ne '.') -and ($MyInvocation.InvocationName -ne '&')) {
    if (-not $ModuleName -or -not $RequiredVersion -or -not $Repository -or -not $FeedUrl -or -not $ExpectedSha256) {
        throw "Install-ATAPModule-AllUsers requires: -ModuleName, -RequiredVersion, -Repository, -FeedUrl, and -ExpectedSha256."
    }

    $result = Install-ATAPModuleAllUsers -ModuleName $ModuleName -RequiredVersion $RequiredVersion -Repository $Repository -FeedUrl $FeedUrl -ExpectedSha256 $ExpectedSha256
    exit [int] $result.ExitStatus
}
