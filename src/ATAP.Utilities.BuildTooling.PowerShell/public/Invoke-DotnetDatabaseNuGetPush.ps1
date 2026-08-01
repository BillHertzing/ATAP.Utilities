#Requires -Version 7.0

function Invoke-DotnetDatabaseNuGetPush {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$NupkgPath,
        [Parameter(Mandatory)][string]$FeedUri,
        [Parameter(Mandatory)][string]$ApiKey
    )

    $fn = 'Invoke-DotnetDatabaseNuGetPush'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    $pushArgs = @(
        'nuget', 'push', $NupkgPath,
        '--source', $FeedUri,
        '--api-key', $ApiKey,
        '--skip-duplicate'
    )

    if ($FeedUri.StartsWith('http://', [System.StringComparison]::OrdinalIgnoreCase)) {
        $pushArgs += '--allow-insecure-connections'
    }

    $allowInsecureFlag = if ($pushArgs -contains '--allow-insecure-connections') { ' --allow-insecure-connections' } else { '' }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "Invoking: dotnet nuget push '$NupkgPath' --source '$FeedUri' --api-key '***' --skip-duplicate$allowInsecureFlag" `
        -Tag 'RestCall'

    $stdout = & dotnet @pushArgs 2>&1
    $exit = $LASTEXITCODE

    return [PSCustomObject]@{
        ExitCode = $exit
        StdOut   = ($stdout -join [Environment]::NewLine)
    }
}
