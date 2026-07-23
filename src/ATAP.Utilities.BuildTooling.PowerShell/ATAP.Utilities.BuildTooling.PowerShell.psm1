# ToDo : Module comment-based help

# Import each approved child before the remaining parent implementation so its explicit
# command exports can be re-exported by the compatibility parent manifest.
$childModuleNames = @(
    'ATAP.Utilities.BuildTooling.PesterScaffolding.PowerShell'
    'ATAP.Utilities.BuildTooling.GitWorktree.PowerShell'
    'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell'
    'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
)
foreach ($childModuleName in $childModuleNames) {
    $childManifest = Join-Path $PSScriptRoot "..\$childModuleName\$childModuleName.psd1"
    $childModule = Import-Module -Name $childManifest -Force -PassThru -ErrorAction Stop
    foreach ($childCommand in @(Get-Command -Module $childModule.Name -CommandType Function)) {
        $childCommandName = $childCommand.Name
        $childModuleProxy = $childModule
        $childCommandMetadata = [System.Management.Automation.CommandMetadata]::new($childCommand)
        $childCommandProxyTemplate = [System.Management.Automation.ProxyCommand]::Create($childCommandMetadata)
        $beginOffset = $childCommandProxyTemplate.IndexOf('begin', [System.StringComparison]::Ordinal)
        if ($beginOffset -lt 0) {
            throw "Unable to derive the parameter contract for child command '$childCommandName'."
        }
        $childCommandProxyHeader = $childCommandProxyTemplate.Substring(0, $beginOffset)
        $childCommandProxyDefinition = $childCommandProxyHeader + @'
process
{
    & $childModuleProxy {
        param($commandName, $boundParameters, $remainingArguments)
        & $commandName @boundParameters @remainingArguments
    } $childCommandName $PSBoundParameters $args
}
'@
        $childCommandProxyBody = [scriptblock]::Create($childCommandProxyDefinition).GetNewClosure()
        Set-Item -Path "Function:script:$childCommandName" -Value $childCommandProxyBody
    }
}

# get the fileIO info for each file in the public and private subdirectories
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue)
$privateFunctions = @(Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue)
$allFunctions = $publicFunctions + $privateFunctions
# Dot-source the public and private files.
foreach ($import in $allFunctions) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}
# list the public functions names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)
# list the private cmdlet names for including into a .psd1 file (ToDo: automate the .psd1 file creation as part of the CI/CD/CD pipeline)

# Command alias (relocated here from public/Start-DebugPowerShell.ps1 so that file
# only DEFINES the function and executes nothing at load time). Created in module
# scope at import, exactly as the dot-sourced Set-Alias did before.
Set-Alias -Name sdp -Value Start-DebugPowerShell

# Backward-compatible aliases for the Sprint-0007 service-account BWS token cmdlet names.
Set-Alias -Name Get-ServiceAccountBWSAccessToken -Value Get-BWSAccessToken
Set-Alias -Name Initialize-ServiceAccountBWSAccessToken -Value Initialize-BWSAccessToken
