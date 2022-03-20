#############################################################################
#region Update-PackageVersion
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
Increment the semantic version in a Powershell module descriptor (.psd1) file. 
if the Package Descriptor file's Version includes a PreRelease string, the trailing digits of the PreRelease are incremented by 1
if the Package Descriptor file's Version does not include a PreRelease string, the trailing digits of the Patch Version component are incremented by 1
.PARAMETER Path
Path to a .psd1 file. 
.PARAMETER Preview
when true, modifies the .psd1 file to indicate the package is prerelease. Also recognizes the additional text string in the semantic version and updates the version substring
when false, increments th
.INPUTS
A Powershell Module .psd1 file, specified by $Path
.OUTPUTS
A modified .psd1 file with the Semantic version information incremented
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
The article at [Automatically updating the version number in a PowerShell Module – How I do regex](https://sqldbawithabeard.com/2017/09/09/automatically-updating-the-version-number-in-a-powershell-module-how-i-do-regex/) 
.LINK
https://sqldbawithabeard.com/2017/09/09/automatically-updating-the-version-number-in-a-powershell-module-how-i-do-regex/
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Update-PackageVersion {
    #region FunctionParameters
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $Path 
        ,[parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $PreReleaseNumberFormat = 'D3' 
    )
    #endregion FunctionParameters
    #region FunctionBeginBlock
    ########################################
    BEGIN {
        Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
        $DebugPreference = 'Continue'
        $preReleasePatternExtractor = '(?<PreReleasePrefix>.*?)(?<PreReleaseNumber>\d{1,4})$'
        $results = @{}
    }
    #endregion FunctionBeginBlock
    
    #region FunctionProcessBlock
    ########################################
    PROCESS {
        $manifest = Import-PowerShellDataFile $path 
        [version]$version = $Manifest.ModuleVersion
        #  Is there a PreRelease string?
        $preReleasePrefixStr = $null
        $preReleaseNumberStr = -1
        $preReleaseNumber = -1
        $newPreReleaseNumber = -1
        $newPreReleaseStr = $null
        if ($manifest['PrivateData']['PSData']['PreRelease']) {
            $matches = [RegEx]::Matches($manifest['PrivateData']['PSData']['PreRelease'] ,$preReleasePatternExtractor)
            if ($matches) {
                $preReleasePrefixStr = $matches.Captures.Groups['PreReleasePrefix'].value
                $preReleaseNumberStr = $matches.Captures.Groups['PreReleaseNumber'].value
                if (-not [int32]::TryParse($preReleaseNumberStr, [ref]$preReleaseNumber)) {
                    throw "manifest['PrivateData']['PSData']['PreRelease'] value is ($manifest['PrivateData']['PSData']['PreRelease']) and a preReleaseNumber could not be parsed from it"
                }
                # Add one to the preReleaseNumber
                $newPreReleaseNumber = $preReleaseNumber + 1
                # Reassmeble the PreRelease string
                $newPreReleaseStr = $preReleasePrefixStr + $newPreReleaseNumber.ToString($PreReleaseNumberFormat)
                if ($PSCmdlet.ShouldProcess(($path, $newPreReleaseStr), "Update-ModuleManifest -Path $path  -ModuleData $newPreReleaseStr (from $preReleasePrefixStr + $preReleaseNumberStr)")) {
                    #$privateData = $manifest['PrivateData']
                    #$privateDataPSData = $privateData['PSData']
                    #$privatePSData['PreRelease'] = $newPreReleaseStr
                    # Update the module manifest
                    Update-ModuleManifest -Path $path -Prerelease $newPreReleaseStr
                    Write-Verbose "Update-ModuleManifest for $path set 'Prerelease' = $newPreReleaseStr"
                }
            }
            else {
                throw "PreRelease value was present but could not be parsed"
            }
        }
        else {

            # Add one to the build of the version number
            [version]$newVersion = "{0}.{1}.{2}" -f $Version.Major, $Version.Minor, ($Version.Build + 1) 
            # Update the manifest file
            if ($PSCmdlet.ShouldProcess(($path, $version, $newVersion), "Update-ModuleManifest -Path $path  -ModuleVersion $newVersion (from $version)")) {
                # Update the module manifest
                Update-ModuleManifest -Path $path  -ModuleVersion $newVersion # This fails on 2022-02-16
                #region workaround
                #$manifestHash = Invoke-Expression (Get-Content $path -Raw)
                #$manifestHash.Moduleversion = $newVersion
                # ToDo: explorer BOM needs for Nuget packaging and Chocolatey installs
                #$manifestHash | Set-Content -Path $path
                #endregion Workaround
                Write-Verbose "Update-ModuleManifest for $path to NewVersion = $newVersion"
            }
        }
    }
    #endregion FunctionProcessBlock
    
    #region FunctionEndBlock
    ########################################
    END {
        Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
    }
    #endregion FunctionEndBlock
}
#endregion Update-PackageVersion
#############################################################################
    
    
    