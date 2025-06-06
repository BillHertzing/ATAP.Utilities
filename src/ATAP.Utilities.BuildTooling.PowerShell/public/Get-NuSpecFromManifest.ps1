#Requires -Modules PowerShellGet
#Requires -Version 5.0
#region Get-NuSpecFromManifest
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER  ManifestPath
  Specifies the path to the Powershell Manifest file (.psd1)
.PARAMETER DestinationFolder
  Specifies the path to the directory where the .nuspec file will be written

.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
    AUTHOR:  Tao Yang
    DATE:    05/09/2018
    Version: 1.0
    Comment: generate nuget specification file (.nuspec) based on PowerShell module manifest (.psd1) file
.LINK
https://gist.githubusercontent.com/tyconsulting/c567e5cc66fc522d46743d744579be27/raw/c1b2047f1a22b6f1690d47d996dec845ff3f67b1/psd1-to-nuspec.ps1
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-NuSpecFromManifest {
  [CmdletBinding(PositionalBinding = $false)]
  Param
  (
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        Test-Path $_ -PathType leaf -Include '*.psd1'
      })]
    [string]
    $ManifestPath,

    [Parameter(Mandatory = $true)]
    # ToDo: Replace with enumeration
    [ValidateSet('NuGet', 'PowershellGet', 'ChocolateyGet', 'ChocolateyCLI')]
    [string]
    $ProviderName,

    [Parameter(Mandatory = $false)]
    [ValidateScript({
        Test-Path $_ -PathType 'Container'
      })]
    [string]
    $DestinationFolder
  )
  #region functions
  function Get-EscapedString {
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
      [Parameter()]
      [string]
      $ElementValue
    )

    return [System.Security.SecurityElement]::Escape($ElementValue)
  }
  function Get-ExportedDscResources {
    [CmdletBinding(PositionalBinding = $false)]
    Param
    (
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [PSModuleInfo]
      $PSModuleInfo
    )

    $dscResources = @()

    if (Get-Command -Name Get-DscResource -Module PSDesiredStateConfiguration -ErrorAction Ignore) {
      $OldPSModulePath = $env:PSModulePath

      try {
        $env:PSModulePath = Join-Path -Path $PSHOME -ChildPath 'Modules'
        $env:PSModulePath = "$env:PSModulePath;$(Split-Path -Path $PSModuleInfo.ModuleBase -Parent)"

        $dscResources = PSDesiredStateConfiguration\Get-DscResource -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
          Microsoft.PowerShell.Core\ForEach-Object {
            if ($_.Module -and ($_.Module.Name -eq $PSModuleInfo.Name)) {
              $_.Name
            }
          }
      } finally {
        $env:PSModulePath = $OldPSModulePath
      }
    } else {
      $dscResourcesDir = Join-PathUtility -Path $PSModuleInfo.ModuleBase -ChildPath 'DscResources' -PathType Directory
      if (Test-Path $dscResourcesDir) {
        $dscResources = Get-ChildItem -Path $dscResourcesDir -Directory -Name
      }
    }

    return $dscResources
  }
  function Get-AvailableRoleCapabilityName {
    [CmdletBinding(PositionalBinding = $false)]
    Param
    (
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [PSModuleInfo]
      $PSModuleInfo
    )

    $RoleCapabilityNames = @()

    $RoleCapabilitiesDir = Join-PathUtility -Path $PSModuleInfo.ModuleBase -ChildPath 'RoleCapabilities' -PathType Directory
    if (Test-Path -Path $RoleCapabilitiesDir -PathType Container) {
      $RoleCapabilityNames = Get-ChildItem -Path $RoleCapabilitiesDir `
        -Name -Filter *.psrc |
        ForEach-Object -Process {
          [System.IO.Path]::GetFileNameWithoutExtension($_)
        }
    }

    return $RoleCapabilityNames
  }
  function Join-PathUtility {
    <#
      .DESCRIPTION
      Utility to get the case-sensitive path, if exists.
      Otherwise, returns the output of Join-Path cmdlet.
      This is required for getting the case-sensitive paths on non-Windows platforms.
  #>
    param
    (
      [Parameter(Mandatory = $true)]
      [string]
      $Path,

      [Parameter(Mandatory = $false)]
      [string]
      $ChildPath,

      [Parameter(Mandatory = $false)]
      [string]
      [ValidateSet('File', 'Directory', 'Any')]
      $PathType = 'Any'
    )

    $JoinedPath = Join-Path -Path $Path -ChildPath $ChildPath
    if (Test-Path -Path $Path -PathType Container) {
      $GetChildItem_params = @{
        Path          = $Path
        ErrorAction   = 'SilentlyContinue'
        WarningAction = 'SilentlyContinue'
      }
      if ($PathType -eq 'File') {
        $GetChildItem_params['File'] = $true
      } elseif ($PathType -eq 'Directory') {
        $GetChildItem_params['Directory'] = $true
      }

      $FoundPath = Get-ChildItem @GetChildItem_params |
        Where-Object -FilterScript {
          $_.Name -eq $ChildPath
        } |
        ForEach-Object -Process {
          $_.FullName
        } |
        Select-Object -First 1 -ErrorAction SilentlyContinue

      if ($FoundPath) {
        $JoinedPath = $FoundPath
      }
    }

    return $JoinedPath
  }
  function Get-ManifestHashTable {
    param
    (
      [Parameter(Mandatory = $true)]
      [ValidateNotNullOrEmpty()]
      [string]
      $Path
    )

    $Lines = $null

    try {
      $Lines = Get-Content -Path $Path -Force
    } catch {
      Throw "Unable to parse manifest file '$path'"
      Exit -1
    }

    if (-not $Lines) {
      return
    }

    $scriptBlock = [ScriptBlock]::Create( $Lines -join "`n" )

    $allowedVariables = [System.Collections.Generic.List[String]] @('PSEdition', 'PSScriptRoot')
    $allowedCommands = [System.Collections.Generic.List[String]] @()
    $allowEnvironmentVariables = $false

    try {
      $scriptBlock.CheckRestrictedLanguage($allowedCommands, $allowedVariables, $allowEnvironmentVariables)
    } catch {
      return
    }

    return $scriptBlock.InvokeReturnAsIs()
  }

  function New-NuSpecFile {
    [CmdletBinding(PositionalBinding = $false)]
    Param
    (
      [Parameter(Mandatory = $true, ParameterSetName = 'PublishModule')]
      [ValidateNotNullOrEmpty()]
      [string]
      $ManifestPath,

      [Parameter(Mandatory = $false)]
      [string]
      $DestinationFolder
    )

    #variables
    $Name = $null
    $Description = $null
    $Version = ''
    $Author = $null
    $CompanyName = $null
    $Copyright = $null
    $requireLicenseAcceptance = 'false'

    $PSModuleInfo = Test-ModuleManifest -Path $ManifestPath
    If (-not $PSModuleInfo) {
      Throw "Failed to retrieve module information from manifest '$ManifestPath'"
      exit -1
    }

    $Name = $PSModuleInfo.Name
    $Description = $PSModuleInfo.Description
    $Version = $PSModuleInfo.Version
    $Author = $PSModuleInfo.Author
    $CompanyName = $PSModuleInfo.CompanyName
    $Copyright = $PSModuleInfo.Copyright

    If (-not $PSBoundParameters.ContainsKey('DestinationFolder')) {
      $DestinationFolder = $PSModuleInfo.ModuleBase
    }
    $NuspecPath = Join-Path -Path $DestinationFolder -ChildPath "$($PSModuleInfo.Name).nuspec"

    if ($PSModuleInfo.PrivateData -and
    ($PSModuleInfo.PrivateData.GetType().ToString() -eq 'System.Collections.Hashtable') -and
      $PSModuleInfo.PrivateData['PSData'] -and
    ($PSModuleInfo.PrivateData['PSData'].GetType().ToString() -eq 'System.Collections.Hashtable')
    ) {
      if ($PSModuleInfo.PrivateData.PSData['Tags']) {
        $Tags = $PSModuleInfo.PrivateData.PSData.Tags
      }

      if ($PSModuleInfo.PrivateData.PSData['ReleaseNotes']) {
        $ReleaseNotes = $PSModuleInfo.PrivateData.PSData.ReleaseNotes
      }

      if ($PSModuleInfo.PrivateData.PSData['LicenseUri']) {
        $LicenseUri = $PSModuleInfo.PrivateData.PSData.LicenseUri
      }

      if ($PSModuleInfo.PrivateData.PSData['IconUri']) {
        $IconUri = $PSModuleInfo.PrivateData.PSData.IconUri
      }

      if ($PSModuleInfo.PrivateData.PSData['ProjectUri']) {
        $ProjectUri = $PSModuleInfo.PrivateData.PSData.ProjectUri
      }

      if ($PSModuleInfo.PrivateData.PSData['Prerelease']) {
        $psmoduleInfoPrereleaseString = $PSModuleInfo.PrivateData.PSData.Prerelease
        if ($psmoduleInfoPrereleaseString -and $psmoduleInfoPrereleaseString.StartsWith('-')) {
          $Version = [string]$Version + $psmoduleInfoPrereleaseString
        } else {
          $Version = [string]$Version + '-' + $psmoduleInfoPrereleaseString
        }
      }

      if ($PSModuleInfo.PrivateData.PSData['RequireLicenseAcceptance']) {
        $requireLicenseAcceptance = $PSModuleInfo.PrivateData.PSData.requireLicenseAcceptance.ToString().ToLower()
        if ($requireLicenseAcceptance -eq 'true') {
          if (-not $LicenseUri) {
            $message = "'LicenseUri' is not specified. 'LicenseUri' must be provided when user license acceptance is required."
            Throw $message
          }

          $LicenseFilePath = Join-PathUtility -Path $PSModuleInfo.ModuleBase -ChildPath 'License.txt' -PathType File
          if (-not $LicenseFilePath -or -not (Test-Path -Path $LicenseFilePath -PathType Leaf)) {
            $message = 'License.txt not Found. License.txt must be provided when user license acceptance is required.'
            Throw $message
          }

          if ($null -eq ${Get-Content -LiteralPath $LicenseFilePath}) {
            $message = 'License.txt is empty.'
            Throw $message
          }
        } elseif ($requireLicenseAcceptance -ne 'false') {
          $InvalidValueForRequireLicenseAcceptance = "The specified value '{0}' for the parameter '{1}' is invalid. It should be $true or $false." -f ($requireLicenseAcceptance, 'requireLicenseAcceptance')
          Write-PSFMessage -Level Warning -Message $InvalidValueForRequireLicenseAcceptance
        }
      }
    }

    # Add PSModule and PSGet format version tags
    if (-not $Tags) {
      $Tags = @()
    }


    $DependentModuleDetails = @()
    $Tags += 'PSModule'
    $ModuleManifestHashTable = Get-ManifestHashTable -Path $ManifestPath
    if ($PSModuleInfo.ExportedCommands.Count) {
      if ($PSModuleInfo.ExportedCmdlets.Count) {
        $Tags += 'PSIncludes_Cmdlet'
        $Tags += $PSModuleInfo.ExportedCmdlets.Keys | Microsoft.PowerShell.Core\ForEach-Object {
          "PSCmdlet_$_"
        }
      }

      if ($PSModuleInfo.ExportedFunctions.Count) {
        $Tags += 'PSIncludes_Function'
        $Tags += $PSModuleInfo.ExportedFunctions.Keys | Microsoft.PowerShell.Core\ForEach-Object {
          "PSFunction_$_"
        }
      }

      $Tags += $PSModuleInfo.ExportedCommands.Keys | Microsoft.PowerShell.Core\ForEach-Object {
        "PSCommand_$_"
      }
    }
    # Suppress progress output
    $storedProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $dscResourceNames = Get-ExportedDscResources -PSModuleInfo $PSModuleInfo
    $ProgressPreference = $storedProgressPreference
    if ($dscResourceNames) {
      $Tags += 'PSIncludes_DscResource'

      $Tags += $dscResourceNames | Microsoft.PowerShell.Core\ForEach-Object {
        "PSDscResource_$_"
      }
    }

    $RoleCapabilityNames = Get-AvailableRoleCapabilityName -PSModuleInfo $PSModuleInfo
    if ($RoleCapabilityNames) {
      $Tags += 'PSIncludes_RoleCapability'

      $Tags += $RoleCapabilityNames | Microsoft.PowerShell.Core\ForEach-Object {
        "PSRoleCapability_$_"
      }
    }

    # Populate the module dependencies elements from RequiredModules and
    # NestedModules properties of the current PSModuleInfo
    $DependentModuleDetails = @()
    $requiredModules = @()
    #$requiredModules += $PSModuleInfo.RequiredModules
    #$requiredModules += $PSModuleInfo.NestedModules
    if ($ModuleManifestHashTable.RequiredModules) {
      $requiredModules += $ModuleManifestHashTable.RequiredModules
    }
    if ($ModuleManifestHashTable.NestedModules) {
      $requiredModules += $ModuleManifestHashTable.NestedModules
    }

    Write-PSFMessage -Level Debug -Message "Total dependent modules: $($requiredModules.count)"
    Foreach ($requiredModule in $requiredModules) {
      $DependentModuleDetail = @{}
      if ($requiredModule.GetType().ToString() -eq 'System.Collections.Hashtable') {
        $ModuleName = $requiredModule.ModuleName
        Write-PSFMessage -Level Debug -Message "Processing dependency module '$ModuleName'"
        if ($requiredModule.Keys -Contains 'RequiredVersion') {
          Write-PSFMessage -Level Debug -Message "'$ModuleName': Required version: $($requiredModule.RequiredVersion)"
          $DependentModuleDetail.add('RequiredVersion', $requiredModule.RequiredVersion)
        } elseif ($requiredModule.Keys -Contains 'ModuleVersion') {
          Write-PSFMessage -Level Debug -Message "$ModuleName': Module version: $($requiredModule.ModuleVersion)"
          $DependentModuleDetail.add('ModuleVersion', $requiredModule.ModuleVersion)
        }
      } else {
        # Just module name was specified
        Write-PSFMessage -Level Debug -Message "'$ModuleName': Module version not specified."
        $ModuleName = $requiredModule.ToString()
      }
      $DependentModuleDetail.add('Name', $ModuleName)
      $DependentModuleDetails += $DependentModuleDetail
    }

    $dependencies = @()
    ForEach ($Dependency in $DependentModuleDetails) {
      $ModuleName = $Dependency.Name
      $VersionString = $null

      # Version format in NuSpec:
      # "[2.0]" --> (== 2.0) Required Version
      # "2.0" --> (>= 2.0) Minimum Version
      #
      # When only MaximumVersion is specified in the ModuleSpecification
      # (,1.0]  = x <= 1.0
      #
      # When both Minimum and Maximum versions are specified in the ModuleSpecification
      # [1.0,2.0] = 1.0 <= x <= 2.0

      if ($Dependency.Keys -Contains 'RequiredVersion') {
        $VersionString = "[$($Dependency.RequiredVersion)]"
      } elseif ($Dependency.Keys -Contains 'ModuleVersion') {
        $VersionString = "$($Dependency.ModuleVersion)"
      }

      if ([System.string]::IsNullOrWhiteSpace($VersionString)) {
        $dependencies += "<dependency id='$($ModuleName)'/>"
      } else {
        $dependencies += "<dependency id='$($ModuleName)' version='$($VersionString)' />"
      }
    }

    # Populate the nuspec elements
    $nuspec = @"
<?xml version="1.0"?>
<package >
    <metadata>
        <id>$([System.Security.SecurityElement]::Escape($Name))</id>
        <version>$($Version)</version>
        <authors>$([System.Security.SecurityElement]::Escape($Author))</authors>
        <owners>$([System.Security.SecurityElement]::Escape($CompanyName))</owners>
        <description>$([System.Security.SecurityElement]::Escape($Description))</description>
        <releaseNotes>$([System.Security.SecurityElement]::Escape($ReleaseNotes))</releaseNotes>
        <requireLicenseAcceptance>$($requireLicenseAcceptance.ToString())</requireLicenseAcceptance>
        <copyright>$([System.Security.SecurityElement]::Escape($Copyright))</copyright>
        <tags>$(if($Tags){[System.Security.SecurityElement]::Escape(($Tags -join ' '))})</tags>
        $(if($LicenseUri)
{
         "<licenseUrl>$([System.Security.SecurityElement]::Escape($LicenseUri))</licenseUrl>"
})
        $(if($ProjectUri)
{
        "<projectUrl>$([System.Security.SecurityElement]::Escape($ProjectUri))</projectUrl>"
})
        $(if($IconUri)
{
        "<iconUrl>$([System.Security.SecurityElement]::Escape($IconUri))</iconUrl>"
})
        <dependencies>
            $dependencies
        </dependencies>
    </metadata>
</package>
"@
    # Remove existing nuspec file

    if ($NuspecPath -and (Test-Path -Path $NuspecPath -PathType Leaf)) {
      #Write-PSFMessage -Level Warning -Message "Nuspec file '$NuspecPath' already exists. It will be overwritten."
      Remove-Item $NuspecPath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
    }

    Set-Content -Value $nuspec -Path $NuspecPath -Force -Confirm:$false -WhatIf:$false

    if ($LASTEXITCODE -or -not $NuspecPath -or -not (Test-Path -Path $NuspecPath -PathType Leaf)) {
      Write-PSFMessage -Level Error -Message "failed to create nuspec file '$NuspecPath'" # ToDO add tags
      #ToDo: implement errorId ? $errorId = 'FailedToCreateNuspecFile'
      # Write-Error -Message $message -ErrorId $errorId -Category InvalidOperation
      # returning a null indicates an error occurred
      return
    }
    # ensure the file is not empty
    if (-not $(Get-Content -LiteralPath $NuspecPath -Raw)) {
      Write-PSFMessage -Level Error -Message "Empty nuspec file '$NuspecPath'" # ToDO add tags
      #ToDo: implement errorId ? $errorId = 'EmptyNuspecFile'
      # returning a null indicates an error occurred
      return
    }

    return $NuspecPath
  }
  #endregion

  #region main
  $message = "Generating .nuspec file based on PowerShell Module Manifest '$ManifestPath'"
  Write-PSFMessage -Level Debug -Message $message
  $param = @{
    'ManifestPath' = $ManifestPath
  }
  If ($PSBoundParameters.ContainsKey('DestinationFolder')) {
    $param.Add('DestinationFolder', $DestinationFolder)
  }
  $NuspecFile = New-NuSpecFile @param
  If ($NuspecFile) {
    Write-PSFMessage -Level Debug -Message "Nuspec file created: $NuspecFile"
  } else {
    Write-PSFMessage -Level Error -Message 'Failed to create Nuspec file.'
  }
  #endregion
}
