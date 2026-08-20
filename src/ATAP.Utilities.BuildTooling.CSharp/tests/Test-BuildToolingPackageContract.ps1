function Test-BuildToolingPackageContract {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  begin {
    $fn = 'Test-BuildToolingPackageContract'
    $mn = 'ATAP.Utilities.BuildTooling.CSharp.StaticTests'
    $projectDirectory = Split-Path -Parent $PSScriptRoot
    $projectPath = Join-Path $projectDirectory 'ATAP.Utilities.BuildTooling.CSharp.csproj'
    $targetsPath = Join-Path $projectDirectory 'ATAP.Utilities.BuildTooling.targets'
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($projectDirectory, 'Validate static package contract')) {
      return
    }

    try {
      [xml] $project = [System.IO.File]::ReadAllText($projectPath)
      [xml] $targets = [System.IO.File]::ReadAllText($targetsPath)

      $failures = [System.Collections.Generic.List[string]]::new()
      if ($project.Project.PropertyGroup.GeneratePackageOnBuild -ne 'false') {
        $failures.Add('GeneratePackageOnBuild must be false.')
      }
      if ($project.Project.PropertyGroup.IsPackable -ne 'true') {
        $failures.Add('IsPackable must remain true for explicit pack.')
      }
      if ($project.Project.PropertyGroup.BuildOutputTargetFolder -ne 'tools') {
        $failures.Add('BuildOutputTargetFolder must isolate the task assembly under tools/.')
      }
      $buildReferences = @($project.Project.ItemGroup.PackageReference |
        Where-Object { $_.Include -like 'Microsoft.Build.*' })
      if ($buildReferences.Count -ne 2 -or
        @($buildReferences | Where-Object { $_.PrivateAssets -ne 'all' }).Count -ne 0) {
        $failures.Add('Microsoft.Build package references must remain private packaging inputs.')
      }

      $packageItem = @($project.Project.ItemGroup.None) |
        Where-Object { $_.Update -eq 'ATAP.Utilities.BuildTooling.targets' } |
        Select-Object -First 1
      if ($null -eq $packageItem -or $packageItem.Pack -ne 'true') {
        $failures.Add('The canonical targets file must be explicitly packable.')
      } else {
        $packagePaths = @($packageItem.PackagePath -split ';' | Where-Object { $_ })
        $expectedPaths = @('build\', 'buildTransitive\')
        if (@(Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $packagePaths).Count -ne 0) {
          $failures.Add('PackagePath must contain exactly build\ and buildTransitive\.')
        }
      }

      $propertyGroup = $targets.Project.PropertyGroup
      $expectedProperties = [ordered] @{
        ATAPBuildToolingImported = 'true'
        ATAPBuildToolingContractVersion = '1'
        ATAPBuildToolingCompatibilitySentinel = 'ATAP.Utilities.BuildTooling.CSharp/1'
        ATAPBuildToolingImportProvenance = '$(MSBuildThisFileFullPath)'
        ATAPBuildToolingImportDirectory = '$(MSBuildThisFileDirectory)'
        ATAPBuildToolingTaskTargetFramework = 'net10.0'
        ATAPUtilitiesBuildToolingTasksAssembly = '$(MSBuildThisFileDirectory)..\tools\$(ATAPBuildToolingTaskTargetFramework)\ATAP.Utilities.BuildTooling.CSharp.dll'
      }
      foreach ($entry in $expectedProperties.GetEnumerator()) {
        if ($propertyGroup.($entry.Key).'#text' -and $propertyGroup.($entry.Key).'#text' -ne $entry.Value) {
          $failures.Add("$($entry.Key) has an unexpected value.")
        } elseif (-not $propertyGroup.($entry.Key).'#text' -and [string] $propertyGroup.($entry.Key) -ne $entry.Value) {
          $failures.Add("$($entry.Key) has an unexpected value.")
        }
      }

      $forbiddenElements = @('Target', 'Exec', 'Copy', 'Delete', 'MakeDir', 'Touch', 'WriteLinesToFile', 'UsingTask')
      foreach ($elementName in $forbiddenElements) {
        if ($targets.SelectNodes("//*[local-name()='$elementName']").Count -ne 0) {
          $failures.Add("Imported targets must not contain $elementName elements.")
        }
      }

      $sourceText = [System.IO.File]::ReadAllText($targetsPath)
      foreach ($forbiddenToken in @('Get-SecretATAP', 'ProGetApiKey', 'NuGetApiKey', 'AfterTargets="Build"', 'BeforeTargets="Pack"')) {
        if ($sourceText.Contains($forbiddenToken, [System.StringComparison]::OrdinalIgnoreCase)) {
          $failures.Add("Imported targets contain forbidden token: $forbiddenToken")
        }
      }

      if ($failures.Count -ne 0) {
        throw [System.InvalidOperationException]::new(($failures -join [Environment]::NewLine))
      }

      [PSCustomObject] @{
        Project = $projectPath
        Targets = $targetsPath
        PackagePaths = @('build\', 'buildTransitive\')
        BuildOutputTargetFolder = 'tools'
        PrivateBuildPackageReferences = $buildReferences.Count
        ContractVersion = 1
        TargetElementCount = $targets.SelectNodes("//*[local-name()='Target']").Count
        Result = 'Passed'
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
      throw
    }
  }

  end {
  }
}
