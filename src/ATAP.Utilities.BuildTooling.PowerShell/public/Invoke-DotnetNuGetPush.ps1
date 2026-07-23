#Requires -Version 7.0

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
