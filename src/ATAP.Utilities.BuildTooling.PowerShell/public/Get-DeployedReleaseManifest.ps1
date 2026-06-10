#Requires -Version 7.0
<#
.SYNOPSIS
    Reads and validates the manifest.json deployed with an AceCommander release.

.DESCRIPTION
    Get-DeployedReleaseManifest is the support-auditing entry point for the
    release manifest described in SolutionDocumentation/Release-Branch-and-Manifest.md.
    It reads a deployed manifest file, parses the JSON, and validates it against
    SolutionDocumentation/schemas/manifest.schema.json when that schema is
    present in the repository.

.PARAMETER Path
    Path to the deployed manifest. Defaults to
    ${env:ProgramData}\AceCommander\manifest.json on Windows.

.OUTPUTS
    [PSCustomObject] containing the parsed manifest.
#>
function Get-DeployedReleaseManifest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = $(
            $programData = if (-not [string]::IsNullOrWhiteSpace($env:ProgramData)) {
                $env:ProgramData
            } else {
                [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
            }
            Join-Path -Path $programData -ChildPath 'AceCommander\manifest.json'
        )
    )

    begin {
        $fn = 'Get-DeployedReleaseManifest'
        $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Path='$Path'" -Tag 'Trace'
    }

    process {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Release manifest file was not found at '$Path'."
        }

        try {
            $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
        } catch {
            $resolvedPath = $Path
        }

        try {
            $json = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop
        } catch {
            throw "Could not read release manifest at '$resolvedPath': $($_.Exception.Message)"
        }

        if ([string]::IsNullOrWhiteSpace($json)) {
            throw "Release manifest at '$resolvedPath' is empty or malformed JSON."
        }

        try {
            $manifest = $json | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Release manifest at '$resolvedPath' is malformed JSON: $($_.Exception.Message)"
        }

        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $srcRoot = Split-Path -Parent $moduleRoot
        $repoRoot = Split-Path -Parent $srcRoot
        $schemaPath = Join-Path -Path $repoRoot -ChildPath 'SolutionDocumentation\schemas\manifest.schema.json'

        if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
            $testJson = Get-Command -Name Test-Json -ErrorAction SilentlyContinue
            if (-not $testJson) {
                throw "Release manifest schema validation requires the Test-Json cmdlet, but Test-Json was not found."
            }

            try {
                $isValid = Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop
                if (-not $isValid) {
                    throw 'Test-Json returned false.'
                }
            } catch {
                throw "Release manifest at '$resolvedPath' failed schema validation against '$schemaPath': $($_.Exception.Message)"
            }
        } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Schema file was not found at '$schemaPath'; returning parsed manifest without schema validation."
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Loaded release manifest '$resolvedPath'."
        return $manifest
    }

    end {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn" -Tag 'Trace'
    }
}
