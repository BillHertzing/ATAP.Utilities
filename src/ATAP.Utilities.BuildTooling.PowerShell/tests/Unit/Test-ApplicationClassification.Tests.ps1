#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
  $script:validatorPath = Join-Path $script:moduleRoot 'public\Test-ApplicationClassification.ps1'
  $script:schemaPath = Join-Path $script:moduleRoot 'Resources\application-classification.schema.json'
  $script:fixturePath = Join-Path $script:moduleRoot 'tests\fixtures\ApplicationClassification\valid'
  . $script:validatorPath

  function script:New-ClassificationCase {
    param([string] $Name)
    $destination = Join-Path $TestDrive $Name
    Copy-Item -LiteralPath $script:fixturePath -Destination $destination -Recurse
    return $destination
  }

  function script:Get-ClassificationManifest {
    param([string] $Root)
    Get-Content -LiteralPath (Join-Path $Root 'ApplicationClassification.json') -Raw | ConvertFrom-Json -Depth 20
  }

  function script:Set-ClassificationManifest {
    param([string] $Root, $Manifest)
    $Manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Root 'ApplicationClassification.json') -Encoding utf8NoBOM
  }

  function script:Invoke-ClassificationCase {
    param([string] $Root)
    Test-ApplicationClassification `
      -RepositoryRoot $Root `
      -ManifestPath (Join-Path $Root 'ApplicationClassification.json') `
      -SchemaPath $script:schemaPath `
      -ExcludedProjectPath 'OpenHardwareMonitorLib/OpenHardwareMonitorLib.csproj' `
      -EvaluationThrottleLimit 4
  }
}

Describe 'Test-ApplicationClassification valid contract' -Tag 'Unit', 'Task15.180.p.P4' {
  It 'classifies declared attribute SDK, child SDK, and imported evaluated executable shapes deterministically' {
    $root = New-ClassificationCase 'valid'
    $first = Invoke-ClassificationCase $root
    $second = Invoke-ClassificationCase $root

    $first.Success | Should -BeTrue
    $first.InputProjectCount | Should -Be 4
    $first.InputProjectPaths | Should -Be @(
      'Client/Client.csproj'
      'Imported/Imported.csproj'
      'Library/Library.csproj'
      'Root/Root.csproj'
    )
    $first.DetectedApplicationCount | Should -Be 3
    $first.DetectedApplicationPaths | Should -Be @(
      'Client/Client.csproj'
      'Imported/Imported.csproj'
      'Root/Root.csproj'
    )
    $first.ExecutableCount | Should -Be 3
    $first.ClassifiedCount | Should -Be 3
    $first.ParsedProjectCount | Should -Be 4
    $first.EvaluatedProjectCount | Should -Be 4
    $first.OpenHardwareMonitorAbsent | Should -BeTrue
    $first.NormalizedJson | Should -BeExactly $second.NormalizedJson
    $first.NormalizedJson | Should -Match 'Client/Client.csproj'
    $first.NormalizedJson | Should -Match 'Imported/Imported.csproj'
  }

  It 'includes executable test projects in the input universe but not the detected application set' {
    $root = New-ClassificationCase 'test-project-input'
    $testProjectDirectory = Join-Path $root 'ExecutableTests'
    $null = New-Item -ItemType Directory -Path $testProjectDirectory
    @(
      '<Project Sdk="Microsoft.NET.Sdk">'
      '  <PropertyGroup>'
      '    <OutputType>Exe</OutputType>'
      '    <IsTestProject>true</IsTestProject>'
      '  </PropertyGroup>'
      '</Project>'
    ) | Set-Content -LiteralPath (Join-Path $testProjectDirectory 'ExecutableTests.csproj') -Encoding utf8NoBOM

    $result = Invoke-ClassificationCase $root

    $result.InputProjectCount | Should -Be 5
    $result.InputProjectPaths | Should -Contain 'ExecutableTests/ExecutableTests.csproj'
    $result.DetectedApplicationCount | Should -Be 3
    $result.DetectedApplicationPaths | Should -Not -Contain 'ExecutableTests/ExecutableTests.csproj'
    $result.ClassifiedCount | Should -Be 3
  }

  It 'automatically excludes OpenHardwareMonitorLib before XML parsing without caller input' {
    $root = New-ClassificationCase 'automatic-ohm-exclusion'
    $result = Test-ApplicationClassification `
      -RepositoryRoot $root `
      -ManifestPath (Join-Path $root 'ApplicationClassification.json') `
      -SchemaPath $script:schemaPath
    $result.Success | Should -BeTrue
    $result.OpenHardwareMonitorAbsent | Should -BeTrue
    $result.ExcludedProjectPaths | Should -Contain 'OpenHardwareMonitorLib/OpenHardwareMonitorLib.csproj'
  }

  It 'parses the schema and fixture manifest as JSON' {
    { Get-Content -LiteralPath $script:schemaPath -Raw | ConvertFrom-Json -Depth 30 } | Should -Not -Throw
    { Get-Content -LiteralPath (Join-Path $script:fixturePath 'ApplicationClassification.json') -Raw | ConvertFrom-Json -Depth 30 } | Should -Not -Throw
  }
}

Describe 'Test-ApplicationClassification one-to-one and path safety' -Tag 'Unit', 'Task15.180.p.P4' {
  It 'rejects an unclassified evaluated executable' {
    $root = New-ClassificationCase 'unclassified'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications = @($manifest.applications | Where-Object projectPath -ne 'Imported/Imported.csproj')
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP011*Imported/Imported.csproj*'
  }

  It 'rejects a stale manifest entry' {
    $root = New-ClassificationCase 'stale'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[2].projectPath = 'Library/Library.csproj'
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP011*ATAPAPP012*'
  }

  It 'rejects exact and case-folded duplicate paths' {
    $root = New-ClassificationCase 'duplicate'
    $manifest = Get-ClassificationManifest $root
    $duplicate = $manifest.applications[2].PSObject.Copy()
    $duplicate.projectPath = 'imported/IMPORTED.csproj'
    $manifest.applications = @($manifest.applications) + $duplicate
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP010*'
  }

  It 'rejects absolute and traversal paths' {
    $root = New-ClassificationCase 'unsafe'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[2].projectPath = '../Imported/Imported.csproj'
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP006*'
  }

  It 'rejects non-canonical source casing' {
    $root = New-ClassificationCase 'case'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[2].projectPath = 'imported/Imported.csproj'
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP008*'
  }
}

Describe 'Test-ApplicationClassification topology and policy gates' -Tag 'Unit', 'Task15.180.p.P4' {
  It 'rejects an orphan shipping component' {
    $root = New-ClassificationCase 'orphan'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[1].componentOf = 'Missing/Missing.csproj'
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP016*'
  }

  It 'rejects more than one shipping root' {
    $root = New-ClassificationCase 'roots'
    $manifest = Get-ClassificationManifest $root
    $secondRoot = $manifest.applications[0].PSObject.Copy()
    $secondRoot.projectPath = 'Imported/Imported.csproj'
    $manifest.applications[2] = $secondRoot
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP013*'
  }

  It 'rejects independent component publish metadata' {
    $root = New-ClassificationCase 'client-publish'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[1] | Add-Member -NotePropertyName publish -NotePropertyValue $manifest.applications[0].publish
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP016*'
  }

  It 'rejects changed or missing exact AG02 switches' {
    $root = New-ClassificationCase 'ag02'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[0].publish.publishTrimmed = $true
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*publishTrimmed*'
  }

  It 'rejects any OpenHardwareMonitorLib manifest entry' {
    $root = New-ClassificationCase 'ohm'
    $manifest = Get-ClassificationManifest $root
    $manifest.applications[2].projectPath = 'OpenHardwareMonitorLib/OpenHardwareMonitorLib.csproj'
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP007*'
  }

  It 'rejects ATAP.Utilities sample promotion' {
    $root = New-ClassificationCase 'atap-sample'
    $manifest = Get-ClassificationManifest $root
    $manifest.repository = 'ATAP.Utilities'
    $manifest.applications[2].projectPath = 'samples/Imported.csproj'
    $manifest.applications[2].classification = 'ShippingRoot'
    $manifest.applications[2].shipping = $true
    $manifest.applications[2] | Add-Member -NotePropertyName publish -NotePropertyValue $manifest.applications[0].publish
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP018*'
  }

  It 'rejects AceOutpost promotion' {
    $root = New-ClassificationCase 'ace-outpost'
    $manifest = Get-ClassificationManifest $root
    $manifest.repository = 'Ace'
    $manifest.applications[2].projectPath = 'AceOutpost.Windows/AceOutpost.Windows.csproj'
    $manifest.applications[2].classification = 'ShippingRoot'
    $manifest.applications[2].shipping = $true
    $manifest.applications[2] | Add-Member -NotePropertyName publish -NotePropertyValue $manifest.applications[0].publish
    Set-ClassificationManifest $root $manifest
    { Invoke-ClassificationCase $root } | Should -Throw '*ATAPAPP019*'
  }
}
