#Requires -Version 7.0
function Get-DatabasePackageManifest {
  <#
.SYNOPSIS
    Reads and parses the db-release-unit-manifest.json from a package path or nupkg file.

.DESCRIPTION
    Accepts either a folder path (expanded package) or a .nupkg file path.
    When given a .nupkg, it expands to a temp folder, locates the manifest,
    parses it as JSON, and returns a [PSCustomObject].

.PARAMETER PackagePath
    Path to an expanded database change package folder containing db-release-unit-manifest.json.

.PARAMETER NupkgPath
    Path to a .nupkg file. The file is expanded to a temp folder to locate the manifest.

.OUTPUTS
    [PSCustomObject] parsed from db-release-unit-manifest.json.

.EXAMPLE
    Get-DatabasePackageManifest -PackagePath 'C:\packages\ATAPUtilities.Database.1.2.3'

.EXAMPLE
    Get-DatabasePackageManifest -NupkgPath 'C:\packages\ATAPUtilities.Database.1.2.3.nupkg'
#>
  [CmdletBinding(DefaultParameterSetName = 'FromFolder')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'FromFolder')]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FromNupkg')]
    [ValidateNotNullOrEmpty()]
    [string]$NupkgPath
  )

  begin {
    $fn = 'Get-DatabasePackageManifest'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
  }

  process {
    $manifestPath = $null
    $tempDir = $null

    if ($PSCmdlet.ParameterSetName -eq 'FromNupkg') {
      if (-not (Test-Path $NupkgPath)) {
        $msg = "Nupkg file not found: '$NupkgPath'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
        throw $msg
      }
      $tempDir = Join-Path $env:TEMP "dbpkg-manifest-$([System.Guid]::NewGuid().ToString('N'))"
      New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Expanding nupkg to $tempDir" -Tag 'Expand'
      [System.IO.Compression.ZipFile]::ExtractToDirectory($NupkgPath, $tempDir)
      $manifestPath = Join-Path $tempDir 'db-release-unit-manifest.json'
    } else {
      if (-not (Test-Path $PackagePath)) {
        $msg = "Package folder not found: '$PackagePath'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
        throw $msg
      }
      $manifestPath = Join-Path $PackagePath 'db-release-unit-manifest.json'
    }

    if (-not (Test-Path $manifestPath)) {
      $msg = "db-release-unit-manifest.json not found at '$manifestPath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw $msg
    }

    $raw = Get-Content $manifestPath -Raw
    try {
      $parsed = $raw | ConvertFrom-Json -Depth 20
    } catch {
      $msg = "Failed to parse db-release-unit-manifest.json: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      throw $msg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Manifest parsed: changeKind=$($parsed.changeKind) version=$($parsed.appVersion)" -Tag 'Output'
    Write-Output $parsed
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
