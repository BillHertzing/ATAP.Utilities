<#
.SYNOPSIS
    Builds, packs, and publishes ATAP.Utilities libraries to the ProGet nuget-experimental feed.

.DESCRIPTION
    Each library listed in $libraries is built in Release configuration.
    The ATAP.Utilities.BuildTooling.targets pipeline handles version increment,
    pack, and push automatically (GeneratePackageOnBuild=true, PublishAfterBuild target).

    Libraries are published in dependency order (ETW before Configuration.Extensions,
    since Configuration.Extensions has a ProjectReference to ETW).

.PARAMETER Configuration
    MSBuild configuration. Default: Release.

.PARAMETER DebugVerbosity
    Set to 'Debug' to enable ATAPBuildToolingConfiguration=Debug for verbose build output.

.PARAMETER WhatIf
    Show which projects would be built without actually building them.

.EXAMPLE
    # Publish all libraries (standard)
    ./Publish-ATAPUtilities.ps1

.EXAMPLE
    # Publish with verbose build tooling output
    ./Publish-ATAPUtilities.ps1 -DebugVerbosity Debug

.EXAMPLE
    # Dry run — show what would be built
    ./Publish-ATAPUtilities.ps1 -WhatIf

.NOTES
    Requires PROGET_ADMIN_API_KEY environment variable (set by LoginScript.ps1 from Bitwarden).
    The push destination feed name is resolved via Get-ATAPIACConstant -Name 'NuGetFeedName_Experimental'
    (defaults to 'nuget-experimental'). Override with -p:ProGetExperimentalFeedUrl=<url> if needed.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Configuration = 'Release',
    [ValidateSet('', 'Debug')]
    [string] $DebugVerbosity = ''
)

$fn = $MyInvocation.MyCommand.Name
$mn = 'ATAP.Utilities.BuildTooling.PowerShell'

# ── Validate prerequisites ──────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($env:PROGET_ADMIN_API_KEY)) {
    $msg = 'PROGET_ADMIN_API_KEY is not set. Run LoginScript.ps1 to load secrets from Bitwarden.'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Publish'
    throw $msg
}

# ── Resolve solution root ────────────────────────────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$solutionRoot = Resolve-Path (Join-Path $scriptDir '..\..\..') | Select-Object -ExpandProperty Path

# ── Library list — dependency order (dependencies first) ────────────────────
# Add new libraries here as they are onboarded for NuGet publishing.
$libraries = @(
    'src\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj',
    'src\ATAP.Utilities.Configuration.Extensions\ATAP.Utilities.Configuration.Extensions.csproj'
)

# ── Build extra MSBuild properties ──────────────────────────────────────────
$extraProps = @()
if ($DebugVerbosity -eq 'Debug') {
    $extraProps += '-p:ATAPBuildToolingConfiguration=Debug'
}

# ── Build each library ───────────────────────────────────────────────────────
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($relPath in $libraries) {
    $projPath = Join-Path $solutionRoot $relPath
    $projName = [System.IO.Path]::GetFileNameWithoutExtension($projPath)

    if ($WhatIfPreference) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "WhatIf: would build $projName" -Tag 'Publish', 'WhatIf'
        continue
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Building $projName ..." -Tag 'Publish'

    $dotnetArgs = @('build', $projPath, '-c', $Configuration) + $extraProps
    & dotnet @dotnetArgs
    $exitCode = $LASTEXITCODE

    $results.Add([PSCustomObject]@{
            Project  = $projName
            Success  = ($exitCode -eq 0)
            ExitCode = $exitCode
        })

    if ($exitCode -ne 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
            -Message "Build failed for $projName (exit $exitCode). Stopping." -Tag 'Publish', 'Error'
        break
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
if (-not $WhatIfPreference) {
    $results | Format-Table -AutoSize
    $failed = $results | Where-Object { -not $_.Success }
    if ($failed) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
            -Message "$($failed.Count) project(s) failed to publish." -Tag 'Publish', 'Error'
        exit 1
    }
    # Resolve feed name via Get-ATAPIACConstant (T-31) for the status message.
    $targetFeedName = 'nuget-experimental'
    try { $targetFeedName = Get-ATAPIACConstant -Name 'NuGetFeedName_Experimental' } catch {}
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "All $($results.Count) libraries published to $targetFeedName." -Tag 'Publish'
}
