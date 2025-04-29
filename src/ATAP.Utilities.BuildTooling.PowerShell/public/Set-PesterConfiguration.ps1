# Public/Set-PesterConfiguration.ps1
function Set-PesterConfiguration {
  [CmdletBinding()]
  [OutputType([PesterConfiguration])]
  param(
    [Parameter()]
    [string]$ModuleRoot = (Split-Path $PSScriptRoot -Parent),

    [Parameter()]
    [string]$TestDirectory = $PSScriptRoot,

    [Parameter()]
    [switch]$IsCICD = ($env:isCICD -eq $true)
  )

  function Test-IsVSCode {
    return $env:TERM_PROGRAM -eq 'vscode' -or $null -ne $env:VSCODE_PID
  }

  function Get-VSCodePesterSettings {
    param([string]$ProjectRoot)
    $settingsPath = Join-Path $ProjectRoot '.vscode/settings.json'
    if (-not (Test-Path $settingsPath)) { return @{} }
    try {
      return Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
      Write-Warning "Invalid VS Code settings: $_"
      return @{}
    }
  }

  function Map-VSCodeToPesterConfig {
    param(
      [hashtable]$VSCodeSettings,
      [PesterConfiguration]$PesterConfig
    )
    if ($VSCodeSettings['powershell.pester.outputVerbosity']) {
      $PesterConfig.Output.Verbosity = $VSCodeSettings['powershell.pester.outputVerbosity']
    }
    # Add other mappings as needed
  }
  # --- Detect Environment ---
  $isCICD = $env:isCICD -ieq 'true'  # Case-insensitive check

  # --- Configuration Discovery ---
  $currentDir = $PSScriptRoot
  $configFiles = @()

  if ($isCICD) {
    # CI/CD Mode: Only check the module root (parent of Tests directory)
    $moduleRoot = Split-Path $currentDir -Parent
    $configPath = Join-Path $moduleRoot 'pester.config.ps1'
    if (Test-Path $configPath -PathType Leaf) {
      $configFiles += $configPath
    }
  } else {
    # Local/VS Code Mode: Search upward until .git or filesystem root
    do {
      $gitPath = Join-Path $currentDir '.git'
      $hasGit = Test-Path $gitPath -PathType Container

      $configPath = Join-Path $currentDir 'pester.config.ps1'
      if (Test-Path $configPath -PathType Leaf) {
        $configFiles += $configPath
      }

      # Stop at .git or filesystem root
      if ($hasGit) { break }
      $parentDir = Split-Path $currentDir -Parent
      if (-not $parentDir -or $parentDir -eq $currentDir) { break }
      $currentDir = $parentDir
    } while ($true)

    # Reverse to prioritize higher-level configs (root first)
    [array]::Reverse($configFiles)
  }

  # --- Merge Configurations ---
  $mergedConfig = [PesterConfiguration]::Default
  foreach ($file in $configFiles) {
    $config = . $file  # Load the config file
    Merge-PesterConfiguration -MergedConfig $mergedConfig -ConfigToMerge $config
  }

  # --- Apply VS Code Overrides (if applicable) ---
  if (-not $isCICD -and (Test-IsVSCode)) {
    $projectRoot = $currentDir  # Use the directory where .git was found
    $vscodeSettings = Get-VSCodePesterSettings -ProjectRoot $projectRoot
    Map-VSCodeToPesterConfig -VSCodeSettings $vscodeSettings -PesterConfig $mergedConfig
  }

  # --- Apply Final Configuration ---
  $PesterPreference = $mergedConfig
}

# Discover configurations based on environment
$configFiles = if ($IsCICD) {
  # CI/CD: Only check module root
  $configPath = Join-Path $ModuleRoot 'pester.config.ps1'
  if (Test-Path $configPath) { $configPath }
} else {
  # Local/VS Code: Search upward from test directory
  $currentDir = $TestDirectory
  $files = @()
  do {
    $gitPath = Join-Path $currentDir '.git'
    $configPath = Join-Path $currentDir 'pester.config.ps1'
    if (Test-Path $configPath) { $files += $configPath }
    if (Test-Path $gitPath -PathType Container) { break }
    $currentDir = Split-Path $currentDir -Parent
  } while ($null -ne $currentDir)
  [array]::Reverse($files)
  $files
}

# Merge configurations
$mergedConfig = [PesterConfiguration]::Default
foreach ($file in $configFiles) {
  $config = . $file
  Merge-PesterConfiguration -BaseConfig $mergedConfig -OverrideConfig $config
}

# Apply VS Code overrides
if (-not $IsCICD -and (Test-IsVSCode)) {
  $vscodeSettings = Get-VSCodePesterSettings -ProjectRoot $currentDir
  Map-VSCodeToPesterConfig -VSCodeSettings $vscodeSettings -PesterConfig $mergedConfig
}

return $mergedConfig
