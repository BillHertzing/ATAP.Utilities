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
    if (-not $PSCmdlet.ShouldProcess($projectDirectory, 'Validate static package contract')) { return }
    try {
      [xml] $project = [IO.File]::ReadAllText($projectPath)
      [xml] $targets = [IO.File]::ReadAllText($targetsPath)
      $failures = [Collections.Generic.List[string]]::new()
      function Get-XmlNodeText {
        param($Node)
        if ($Node -is [Xml.XmlElement]) { return $Node.InnerText }
        [string] $Node
      }
      $properties = $project.Project.PropertyGroup
      foreach ($pair in @(
        @('GeneratePackageOnBuild', 'false'), @('IsPackable', 'true'),
        @('BuildOutputTargetFolder', 'tools'), @('PackageReadmeFile', 'ReadMe.md'),
        @('SuppressDependenciesWhenPacking', 'true'), @('RepositoryType', 'git'),
        @('PublishRepositoryUrl', 'true'), @('EmbedUntrackedSources', 'true'))) {
        if ((Get-XmlNodeText $properties.($pair[0])) -ne $pair[1]) { $failures.Add("$($pair[0]) must equal $($pair[1]).") }
      }
      $buildReferences = @($project.Project.ItemGroup.PackageReference | Where-Object { $_.Include -like 'Microsoft.Build.*' })
      if ($buildReferences.Count -ne 2 -or @($buildReferences | Where-Object { $_.PrivateAssets -ne 'all' }).Count -ne 0) {
        $failures.Add('Microsoft.Build package references must remain private packaging inputs.')
      }
      $targetItems = @($project.Project.ItemGroup.None | Where-Object { $_.Include -eq 'ATAP.Utilities.BuildTooling.targets' -and $_.Pack -eq 'true' })
      $readmeItems = @($project.Project.ItemGroup.None | Where-Object { $_.Include -eq 'ReadMe.md' -and $_.Pack -eq 'true' -and $_.PackagePath -eq '\' })
      if ($readmeItems.Count -ne 1) { $failures.Add('ReadMe.md must be explicitly packed at the package root.') }
      $expectedPaths = @('build\ATAP.Utilities.BuildTooling.CSharp.targets', 'buildTransitive\ATAP.Utilities.BuildTooling.CSharp.targets')
      if ($targetItems.Count -ne 2 -or @(Compare-Object $expectedPaths @($targetItems.PackagePath)).Count -ne 0) {
        $failures.Add('Canonical targets must be packed exactly once into build and buildTransitive.')
      }
      $expectedProperties = [ordered]@{
        ATAPBuildToolingImported = 'true'; ATAPBuildToolingPackageId = 'ATAP.Utilities.BuildTooling.CSharp'
        ATAPBuildToolingContractVersion = '1'; ATAPBuildToolingCompatibilitySentinel = 'ATAP.Utilities.BuildTooling.CSharp/1'
        ATAPBuildToolingRequiredContractVersion = '1'; ATAPBuildToolingRequiredCompatibilitySentinel = 'ATAP.Utilities.BuildTooling.CSharp/1'
        ATAPBuildToolingImportProvenance = '$(MSBuildThisFileFullPath)'; ATAPBuildToolingImportDirectory = '$(MSBuildThisFileDirectory)'
        ATAPBuildToolingTaskTargetFramework = 'net10.0'
        ATAPUtilitiesBuildToolingTasksAssembly = '$(MSBuildThisFileDirectory)..\tools\$(ATAPBuildToolingTaskTargetFramework)\ATAP.Utilities.BuildTooling.CSharp.dll'
      }
      $propertyGroup = $targets.Project.PropertyGroup
      foreach ($entry in $expectedProperties.GetEnumerator()) {
        if ((Get-XmlNodeText $propertyGroup.($entry.Key)) -ne $entry.Value) { $failures.Add("$($entry.Key) has an unexpected value.") }
      }
      foreach ($elementName in @('Exec', 'Copy', 'Delete', 'MakeDir', 'Touch', 'WriteLinesToFile', 'UsingTask')) {
        if ($targets.SelectNodes("//*[local-name()='$elementName']").Count -ne 0) { $failures.Add("Imported targets must not contain $elementName elements.") }
      }
      $compatibilityTarget = $targets.SelectSingleNode("//*[local-name()='Target' and @Name='ATAPValidateBuildToolingCompatibility']")
      $diagnostics = @($compatibilityTarget.SelectNodes("*[local-name()='Error']") | ForEach-Object { $_.Code })
      if ($null -eq $compatibilityTarget -or @(Compare-Object @('ATAPBUILD020', 'ATAPBUILD021', 'ATAPBUILD022') $diagnostics).Count -ne 0) {
        $failures.Add('Compatibility target and diagnostics ATAPBUILD020-022 must be present exactly.')
      }
      $sourceText = [IO.File]::ReadAllText($targetsPath)
      foreach ($token in @('Get-SecretATAP', 'ProGetApiKey', 'NuGetApiKey', 'AfterTargets="Build"', 'BeforeTargets="Pack"')) {
        if ($sourceText.Contains($token, [StringComparison]::OrdinalIgnoreCase)) { $failures.Add("Forbidden token: $token") }
      }
      if ($failures.Count -ne 0) { throw [InvalidOperationException]::new(($failures -join [Environment]::NewLine)) }
      [pscustomobject]@{ Result = 'Passed'; PackagePaths = $expectedPaths; ContractVersion = 1; Diagnostics = $diagnostics; TargetElementCount = 1 }
    } catch {
      if (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue) { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message }
      throw
    }
  }

  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Test-BuildToolingPackageContract -Confirm:$false
}
