function Get-MergedPesterConfigurations {
  <#
  .SYNOPSIS
    Discovers and merges PesterConfiguration.psd1 files.
  .DESCRIPTION
    Creates a default Pester configuration, discovers PesterConfiguration.psd1 files
    from the supplied path, merges the discovered configuration hashtables from
    outermost to innermost, and returns the merged configuration object. No work is
    performed at file scope; all behavior occurs only when the function is called.
  .PARAMETER Path
    Directory to start discovery from, or a specific PesterConfiguration.psd1 file.
    Defaults to the module root.
  .PARAMETER IsCICD
    When specified, discovery uses only the module-root PesterConfiguration.psd1.
  .OUTPUTS
    PesterConfiguration
  .EXAMPLE
    Get-MergedPesterConfigurations -Path .\tests\Unit
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    PesterConfiguration.psd1
  #>
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [string]$Path = (Split-Path -Path $PSScriptRoot -Parent),

    [switch]$IsCICD = ($env:isCICD -ieq 'true')
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function New-DefaultPesterConfiguration {
      [CmdletBinding()]
      param()

      $newPesterConfigurationCommand = Get-Command -Name 'New-PesterConfiguration' -ErrorAction SilentlyContinue
      if ($newPesterConfigurationCommand) {
        return New-PesterConfiguration
      }

      $pesterConfigurationType = 'PesterConfiguration' -as [type]
      if ($pesterConfigurationType) {
        $defaultProperty = $pesterConfigurationType.GetProperty('Default', [System.Reflection.BindingFlags]'Public, Static')
        if ($defaultProperty) {
          return $defaultProperty.GetValue($null, $null)
        }
      }

      throw 'Pester 5 is required because no PesterConfiguration type or New-PesterConfiguration command is available.'
    }

    function Set-PesterConfigurationValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$PropertyPath,

        [AllowNull()]
        [object]$Value
      )

      if ($null -eq $Value) { return }

      $current = $Target
      for ($index = 0; $index -lt ($PropertyPath.Count - 1); $index++) {
        $property = $current.PSObject.Properties[$PropertyPath[$index]]
        if (-not $property) { return }
        $current = $property.Value
        if ($null -eq $current) { return }
      }

      $leafName = $PropertyPath[-1]
      $leafProperty = $current.PSObject.Properties[$leafName]
      if ($leafProperty) {
        try {
          $leafProperty.Value = $Value
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Could not set Pester configuration property '$($PropertyPath -join '.')': $($_.Exception.Message)"
        }
      }
    }

    function Merge-PesterConfigurationHashtable {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [hashtable]$Source,

        [string[]]$PropertyPath = @()
      )

      foreach ($key in $Source.Keys) {
        $value = $Source[$key]
        $nextPath = @($PropertyPath + [string]$key)
        if ($value -is [hashtable]) {
          Merge-PesterConfigurationHashtable -Target $Target -Source $value -PropertyPath $nextPath
        } else {
          Set-PesterConfigurationValue -Target $Target -PropertyPath $nextPath -Value $value
        }
      }
    }

    function Test-IsVSCodeHost {
      [CmdletBinding()]
      param()

      return ($env:TERM_PROGRAM -eq 'vscode' -or $null -ne $env:VSCODE_PID)
    }

    function Get-VSCodePesterSettings {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot
      )

      $settingsPath = Join-Path -Path (Join-Path -Path $ProjectRoot -ChildPath '.vscode') -ChildPath 'settings.json'
      if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) { return $null }

      try {
        return Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Invalid VS Code settings at $settingsPath`: $($_.Exception.Message)"
        return $null
      }
    }
  }

  process {
    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $pathItem = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $configFiles = [System.Collections.Generic.List[string]]::new()

    if (-not $pathItem.PSIsContainer) {
      [void]$configFiles.Add($pathItem.FullName)
      $projectRoot = Split-Path -Path $pathItem.FullName -Parent
    } elseif ($IsCICD) {
      $configPath = Join-Path -Path $moduleRoot -ChildPath 'PesterConfiguration.psd1'
      if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        [void]$configFiles.Add($configPath)
      }
      $projectRoot = $moduleRoot
    } else {
      $currentDir = $pathItem.FullName
      $projectRoot = $currentDir
      while ($true) {
        $configPath = Join-Path -Path $currentDir -ChildPath 'PesterConfiguration.psd1'
        if (Test-Path -LiteralPath $configPath -PathType Leaf) {
          [void]$configFiles.Add($configPath)
        }

        if (Test-Path -LiteralPath (Join-Path -Path $currentDir -ChildPath '.git')) {
          $projectRoot = $currentDir
          break
        }

        $parentDir = Split-Path -Path $currentDir -Parent
        if ([string]::IsNullOrWhiteSpace($parentDir) -or $parentDir -eq $currentDir) { break }
        $currentDir = $parentDir
      }

      $configFilesArray = $configFiles.ToArray()
      [array]::Reverse($configFilesArray)
      $configFiles = [System.Collections.Generic.List[string]]::new()
      foreach ($configFile in $configFilesArray) { [void]$configFiles.Add($configFile) }
    }

    $mergedConfig = New-DefaultPesterConfiguration
    foreach ($configFile in $configFiles) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Merging Pester configuration $configFile"
      $config = . $configFile
      if ($config -is [hashtable]) {
        Merge-PesterConfigurationHashtable -Target $mergedConfig -Source $config
      } elseif ($null -ne $config) {
        foreach ($property in $config.PSObject.Properties) {
          Set-PesterConfigurationValue -Target $mergedConfig -PropertyPath @($property.Name) -Value $property.Value
        }
      }
    }

    if (-not $IsCICD -and (Test-IsVSCodeHost)) {
      $vscodeSettings = Get-VSCodePesterSettings -ProjectRoot $projectRoot
      if ($vscodeSettings -and $vscodeSettings.PSObject.Properties['powershell.pester.outputVerbosity']) {
        $mergedConfig.Output.Verbosity = $vscodeSettings.'powershell.pester.outputVerbosity'
      }
    }

    return $mergedConfig
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}