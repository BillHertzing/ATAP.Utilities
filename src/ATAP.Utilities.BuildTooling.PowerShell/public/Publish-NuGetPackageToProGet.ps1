#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes a pre-built NuGet .nupkg to a ProGet feed via
    `dotnet nuget push`. Idempotent: always passes --skip-duplicate.

.DESCRIPTION
    Publish-NuGetPackageToProGet is the single source of truth for the
    `dotnet nuget push` invocation in the immutable-build pipeline. It
    replaces inline `dotnet nuget push` calls scattered across the
    Publish-ATAPUtilities.ps1 orchestrator and BuildMaster plans.

    The cmdlet:
        - Takes a pre-built .nupkg path (FileInfo or string).
        - Resolves the ProGet feed URI from the feed name via
          Resolve-ProGetFeedFromSettings; the feed name defaults to
          'nuget-experimental'.
        - Resolves the API key from the PROGET_ADMIN_API_KEY environment
          variable at User scope (per R-10 in CLAUDE.md).
        - Invokes `dotnet nuget push` with --skip-duplicate so that
          re-pushing the same version is a no-op (idempotent).
        - Wraps the dotnet call in a private helper Invoke-DotnetNuGetPush
          so the call can be mocked in Pester without process spawning.
        - Masks the API key value in every log line (it appears in logs
          only as '***'). The full key still reaches `dotnet nuget push`
          via its --api-key argument.

    -WhatIf short-circuits before invoking dotnet.

.PARAMETER NupkgPath
    Absolute or relative path to the .nupkg file to push. Must exist and
    have a .nupkg extension.

.PARAMETER Feed
    The ProGet NuGet feed name to push to. Defaults to 'nuget-experimental'.

.OUTPUTS
    [PSCustomObject] with at least:
      - NupkgPath        : Absolute path to the .nupkg.
      - FeedName         : Feed name pushed to.
      - FeedUri          : Resolved feed URI.
      - Published        : $true when `dotnet nuget push` exited 0.
      - ResponseSummary  : Short string summary of the push result.

.EXAMPLE
    Publish-NuGetPackageToProGet `
        -NupkgPath './out/ATAP.Utilities.Foo.1.0.0-Sprint042.nupkg'

.EXAMPLE
    Publish-NuGetPackageToProGet `
        -NupkgPath ./out/X.nupkg -Feed 'nuget-development' -WhatIf

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Stream G4 of V3 plan.

.LINK
    https://github.com/whertzing/ATAP.Utilities
#>

# Private helper to wrap the actual `dotnet nuget push` invocation.
# Pester tests Mock this function so they never spawn a real process.
# The function is not exported from the module; it is dot-sourced into
# the same file as Publish-NuGetPackageToProGet so the wrapper can call it.
function Invoke-DotnetNuGetPush {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$NupkgPath,
        [Parameter(Mandatory)][string]$FeedUri,
        [Parameter(Mandatory)][string]$ApiKey
    )

    $fn = 'Invoke-DotnetNuGetPush'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    # The --skip-duplicate flag is what makes the operation idempotent: ProGet
    # rejects duplicate versions, but `dotnet nuget push --skip-duplicate`
    # surfaces that rejection as a warning instead of an error.
    $args = @(
        'nuget', 'push', $NupkgPath,
        '--source', $FeedUri,
        '--api-key', $ApiKey,
        '--skip-duplicate'
    )

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Invoking: dotnet nuget push '$NupkgPath' --source '$FeedUri' --api-key '***' --skip-duplicate" -Tag 'RestCall'

    $stdout = & dotnet @args 2>&1
    $exit = $LASTEXITCODE

    return [PSCustomObject]@{
        ExitCode = $exit
        StdOut   = ($stdout -join [Environment]::NewLine)
    }
}

function Publish-NuGetPackageToProGet {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NupkgPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Feed = 'nuget-experimental'
    )

    begin {
        $fn = 'Publish-NuGetPackageToProGet'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with NupkgPath='$NupkgPath' Feed='$Feed'" -Tag 'Trace'

        # Dot-source the feed-resolver if not already loaded.
        $helperPath = Join-Path $PSScriptRoot '..\private\Resolve-ProGetFeedFromSettings.ps1'
        if (-not (Get-Command -Name 'Resolve-ProGetFeedFromSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
                . $helperPath
            }
        }
    }

    process {
        # 1. Validate NupkgPath.
        if (-not (Test-Path -LiteralPath $NupkgPath -PathType Leaf)) {
            $msg = "NupkgPath does not exist or is not a file: '$NupkgPath'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        if ([System.IO.Path]::GetExtension($NupkgPath) -ne '.nupkg') {
            $msg = "NupkgPath must have a .nupkg extension: '$NupkgPath'"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        $resolvedNupkg = (Resolve-Path -LiteralPath $NupkgPath).ProviderPath -replace '\\', '/'

        # 2. Resolve feed URI. The Feed parameter is a feed name; map it to a
        #    URI using the settings collection. We derive the tier from the
        #    feed name suffix so Resolve-ProGetFeedFromSettings can find it.
        $tierFromFeedName = $null
        if ($Feed -match '^(nuget|powershellget|chocolatey)-([a-zA-Z]+)(-push)?$') {
            $tierFromFeedName = $Matches[2]
        }
        if ([string]::IsNullOrWhiteSpace($tierFromFeedName)) {
            $msg = "Cannot parse tier from feed name '$Feed'. Expected '<type>-<tier>[-push]'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        $feedInfo = Resolve-ProGetFeedFromSettings -FeedType 'nuget' -Tier $tierFromFeedName
        $feedName = $feedInfo.FeedName
        $feedUri = $feedInfo.EndpointUri
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved feed '$feedName' at '$feedUri' from global settings"

        # 3. Resolve the API key from PROGET_ADMIN_API_KEY (User scope per R-10).
        $apiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'User')
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $apiKey = [Environment]::GetEnvironmentVariable('PROGET_ADMIN_API_KEY', 'Process')
        }
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            $msg = "Unable to resolve ProGet API key. Set the User-scope environment variable 'PROGET_ADMIN_API_KEY'."
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
            throw $msg
        }
        # NEVER log the API key value; only confirm it was resolved.
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'ProGet API key resolved from PROGET_ADMIN_API_KEY (value redacted as ***)'

        # 4. WhatIf short-circuit.
        $target = $resolvedNupkg
        $action = "dotnet nuget push to '$feedName' ($feedUri) with --skip-duplicate"
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "WhatIf: would push '$resolvedNupkg' to '$feedName' --skip-duplicate"
            return [PSCustomObject]@{
                NupkgPath       = $resolvedNupkg
                FeedName        = $feedName
                FeedUri         = $feedUri
                Published       = $false
                ResponseSummary = "WhatIf: planned push of '$resolvedNupkg' to '$feedName' with --skip-duplicate"
            }
        }

        # 5. Invoke the dotnet helper. Pester mocks Invoke-DotnetNuGetPush.
        $published = $false
        $summary = $null
        try {
            $pushResult = Invoke-DotnetNuGetPush -NupkgPath $resolvedNupkg -FeedUri $feedUri -ApiKey $apiKey
            $exit = [int]$pushResult.ExitCode
            $stdout = [string]$pushResult.StdOut

            # IMPORTANT: redact the API key from any captured output before
            # logging, in case `dotnet nuget push` echoes it.
            $redactedStdout = $stdout
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                $redactedStdout = $redactedStdout.Replace($apiKey, '***')
            }

            if ($exit -eq 0) {
                $published = $true
                if ($redactedStdout -match '(?i)already exists|conflict|409|skipping') {
                    $summary = "already present: push of '$resolvedNupkg' was skipped via --skip-duplicate."
                } else {
                    $summary = "Pushed '$resolvedNupkg' to '$feedName'."
                }
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message $summary
                if (-not [string]::IsNullOrWhiteSpace($redactedStdout)) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "dotnet stdout: $redactedStdout"
                }
            } else {
                $msg = "dotnet nuget push failed with exit code $exit. Output: $redactedStdout"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
                throw $msg
            }
        } catch {
            $exceptionMessage = [string]$_.Exception.Message
            # Redact API key from exception text too, defensively.
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                $exceptionMessage = $exceptionMessage.Replace($apiKey, '***')
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Push failed: $exceptionMessage"
            throw
        }

        return [PSCustomObject]@{
            NupkgPath       = $resolvedNupkg
            FeedName        = $feedName
            FeedUri         = $feedUri
            Published       = $published
            ResponseSummary = $summary
        }
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
