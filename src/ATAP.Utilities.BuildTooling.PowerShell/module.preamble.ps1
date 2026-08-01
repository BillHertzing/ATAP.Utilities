# Package-visible compatibility initialization for extracted child modules.
# PesterScaffolding exports command metadata that references PesterConfiguration.
# Load Pester before reflecting that child so a fresh consumer shell can construct
# compatibility proxies without relying on a prior test-session import.
if (-not ('PesterConfiguration' -as [type])) {
    Import-Module -Name Pester -ErrorAction Stop
}

$childModuleNames = @(
    'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell'
    'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'
    'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell'
    'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
    'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
    'ATAP.Utilities.BuildTooling.BuildMaster.PowerShell'
    'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
)
foreach ($childModuleName in $childModuleNames) {
    try {
        # Installed packages resolve children through RequiredModules and PSModulePath.
        $childModule = Import-Module -Name $childModuleName -Force -PassThru -ErrorAction Stop
    } catch {
        # Source worktrees retain sibling manifests for local development.
        $childManifest = Join-Path $PSScriptRoot "..\$childModuleName\$childModuleName.psd1"
        try {
            $childModule = Import-Module -Name $childManifest -Force -PassThru -ErrorAction Stop
        } catch {
            # During a dependency bootstrap, the sibling's next-version
            # RequiredModules may not be installed yet. Loading its root module
            # keeps source-worktree orchestration available; packaged imports
            # still enforce the manifest dependency graph.
            $childRootModule = Join-Path $PSScriptRoot "..\$childModuleName\$childModuleName.psm1"
            $childModule = Import-Module -Name $childRootModule -Force -PassThru -ErrorAction Stop
        }
    }
    foreach ($childCommand in @(Get-Command -Module $childModule.Name -CommandType Function)) {
        $childCommandName = $childCommand.Name
        $childModuleProxy = $childModule
        $childCommandMetadata = [System.Management.Automation.CommandMetadata]::new($childCommand)
        $childCommandProxyTemplate = [System.Management.Automation.ProxyCommand]::Create($childCommandMetadata)
        $beginOffset = $childCommandProxyTemplate.IndexOf('begin', [System.StringComparison]::Ordinal)
        if ($beginOffset -lt 0) { throw "Unable to derive the parameter contract for child command '$childCommandName'." }
        $childCommandProxyHeader = $childCommandProxyTemplate.Substring(0, $beginOffset)
        $childCommandProxyDefinition = $childCommandProxyHeader + @'
process
{
    & $childModuleProxy {
        param($commandName, $boundParameters, $remainingArguments)
        if ($null -eq $remainingArguments -or $remainingArguments.Count -eq 0) {
            & $commandName @boundParameters
        } else {
            & $commandName @boundParameters @remainingArguments
        }
    } $childCommandName $PSBoundParameters $args
}
'@
        Set-Item -Path "Function:script:$childCommandName" -Value ([scriptblock]::Create($childCommandProxyDefinition).GetNewClosure())
    }
}
