function Test-ChocoPackageUpdatesFromYaml {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ── PATH-BASED CALL ───────────────────────────────────────────────
    [Parameter(
      Position = 0,
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ParameterSetName = 'ByPath'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $YamlFilePath,

    # ── HANDLE/STREAM-BASED CALL ─────────────────────────────────────
    [Parameter(
      Position = 0,
      Mandatory = $true,
      ValueFromPipeline = $true,
      ParameterSetName = 'ByHandle'
    )]
    [ValidateNotNull()]
    [System.IO.Stream] $YamlFileHandle,

    # ── OPTIONAL EXCLUDE PATTERN (common to both sets) ───────────────
    [Parameter(ParameterSetName = 'ByPath')]
    [Parameter(ParameterSetName = 'ByHandle')]
    [string] $ExcludeRegexPattern = '\.install$'
  )

  Begin {
    Write-PSFMessage -Level Verbose -Message 'Entering function: Test-ChocoPackageUpdatesFromYaml' -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace'

    #$excludeRegexPattern = '\.install$|^KB\d|^dotnet|^vcredist|^vscode-|^netfx-|^chocolatey-|^version$'
    # ensure choco is available
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      $errorMessage = 'Chocolatey (choco) command is not available. Please ensure Chocolatey is installed and in your PATH.'
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace', 'Error'
      Throw $errorMessage
    }

    # --- normalize input so downstream code can read the YAML -----------
    $yamlContent = $null
    $YamlSource = $null
    switch ($PSCmdlet.ParameterSetName) {
      'ByPath' {
        if (-not (Test-Path $YamlFilePath)) {
          $errorMessage = "YAML file not found at path: $YamlFilePath"
          Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace', 'Error'
          Throw $errorMessage
        }
        $YamlSource = $YamlFilePath
        $yamlContent = Get-Content -Raw -Path $YamlFilePath
      }
      'ByHandle' {
        $YamlSource = 'From FileHandle'
        $reader = New-Object System.IO.StreamReader($YamlFileHandle)
        $yamlContent = $reader.ReadToEnd()
        $reader.Close()
      }
    }

    # Load and parse the YAML
    try {
      $packages = ($yamlContent | ConvertFrom-Yaml)
    }
    catch {
      $errorMessage = "Failed to parse YAML file $YamlSource : $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace', 'Error'
      Throw $errorMessage
    }

    $pinnedPackages = @{}
    $packagesToUpdate = @{}
    $packagesToInstall = @{}
    $updatedYAMLContent = @{}

    # Get a list of pinned packages

    $pinnedPackages = choco pin  --limit-output | ForEach-Object {
      $parts = $_ -split '\|'
      if ($parts.Count -eq 2) {
        @{ Name = $parts[0]; Version = $parts[1] }
      }
      else {
        Write-PSFMessage -Level Error -Message "Unexpected format in choco pin output: $_" -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace', 'Error'
        return $null
      }
    } | Where-Object { $_ -and $_.Name -notmatch $excludeRegexPattern } | Select-Object Name, Version

  }

  Process {


    # iterate over the packages found in the YAML file
    foreach ($pkgName in $($packages.Keys | sort)) {
      $pkgInfo = $packages[$pkgName]
      $YAMLVersion = $pkgInfo.Version

      # Get installed local version from Chocolatey
      $installedVersion = choco list $pkgName --exact --limit-output | ForEach-Object {
        ($_ -split '\|')[1]
      }

      # Get public latest version from Chocolatey
      $latestPublicVersion = choco search $pkgName --exact --limit-output | ForEach-Object {
        ($_ -split '\|')[1]
      }
      $message = "$pkgName YAML: $YAMLVersion, installedVersion : $installedVersion, latestPublicVersion is $latestPublicVersion"
      Write-PSFMessage -Level Verbose -Message $message -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace'

      # Create a list of package names and versions that are either not installed or not at the most recent version
      if (-not $installedVersion) {
        $packagesToInstall[$pkgName] = @{
          CurrentVersion = $installedVersion
          LatestVersion  = $latestPublicVersion
        }
      }
      if ([version]$latestPublicVersion -gt [version]$installedVersion) {
        $packagesToUpdate[$pkgName] = @{
          CurrentVersion = $installedVersion
          LatestVersion  = $latestPublicVersion
        }
      }

      if ($latestPublicVersion -gt $installedVersion) {
        # Put should process here
        if ($PSCmdlet.ShouldProcess($pkgName, $($installedVersion ? "Upgrading $pkgName to version $latestPublicVersion":"Installing $pkgName version $latestPublicVersion"))) {
          if ($installedVersion) {
            choco upgrade $pkgName --version $latestPublicVersion -y
          }
          else {
            choco install $pkgName --version $latestPublicVersion -y
          }
        }
        # Update the package version in the data that might go to a YAML file
        $packages[$pkgName].Version = $latestPublicVersion

      }
    }
  }

  End {
    # are there packages installed that are not in the YAML file?
    $packagesToAddToYAML = @{}
    $installedPackages = choco list  --limit-output | ForEach-Object {
      $parts = $_ -split '\|'
      if ($parts.Count -eq 2) {
        @{ Name = $parts[0]; Version = $parts[1] }
      }
      else {
        Write-PSFMessage -Level Error -Message "Unexpected format in choco list output: $_" -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace', 'Error'
        return $null
      }
    } | Where-Object { $_ -and $_.Name -notmatch $excludeRegexPattern } | Select-Object Name, Version, PreRelease, AddedParameters

    foreach ($installedPkg in $installedPackages) {
      if (-not $packages.ContainsKey($installedPkg.name)) {
        $message = "Package $installedPkg.name is installed but not in the YAML file."
        Write-PSFMessage -Level Warning -Message $message -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace', 'Warning'
        $packagesToAddToYAML[$installedPkg.name] = @{
          Version         = $installedPackages[$installedPkg.name].Version
          PreRelease      = $installedPackages[$installedPkg.name].PreRelease
          AddedParameters = $installedPackages[$installedPkg.name].AddedParameters
        }
        if ($PSCmdlet.ShouldProcess($installedPkg, "Adding $installedPkg to YAML file updated information")) {
          # Update packages for the YAML file
          $packages[$installedPkg.name] = @{
            Version         = $installedPackages[$installedPkg.name].Version
            PreRelease      = $installedPackages[$installedPkg.name].PreRelease
            AddedParameters = $installedPackages[$installedPkg.name].AddedParameters
          }
        }
      }
    }
    Write-PSFMessage -Level Verbose -Message 'Leaving function: Test-ChocoPackageUpdatesFromYaml' -Tag 'Test-ChocoPackageUpdatesFromYaml', 'Trace'

    Return @{
      pinnedPackages      = $pinnedPackages
      PackagesToUpdate    = $packagesToUpdate
      PackagesToInstall   = $packagesToInstall
      packagesToAddToYAML = $packagesToAddToYAML
      UpdatedYamlContent  = $packages
    }
  }
}
