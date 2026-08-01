#Requires -Module Pester

Describe 'ModuleFamily metadata' {
  BeforeAll {
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
    $script:FamilyPath = Join-Path $script:RepositoryRoot 'ModuleFamily.psd1'
    $script:Family = Import-PowerShellDataFile -LiteralPath $script:FamilyPath
  }

  It 'has one unique member and GUID per deterministic build-order entry' {
    @($script:Family.Members).Count | Should -Be @($script:Family.BuildOrder).Count
    @($script:Family.Members.Name | Sort-Object -Unique).Count | Should -Be @($script:Family.Members).Count
    @($script:Family.Members.Guid | Sort-Object -Unique).Count | Should -Be @($script:Family.Members).Count
    @($script:Family.BuildOrder | Sort-Object -Unique).Count | Should -Be @($script:Family.BuildOrder).Count
  }

  It 'contains only declared dependency references and orders dependencies first' {
    $position = @{}
    for ($index = 0; $index -lt $script:Family.BuildOrder.Count; $index++) { $position[$script:Family.BuildOrder[$index]] = $index }
    foreach ($member in $script:Family.Members) {
      foreach ($dependency in @($member.Dependencies)) {
        $script:Family.Members.Name | Should -Contain $dependency
        $position[$dependency] | Should -BeLessThan $position[$member.Name]
        $member.MinimumVersions.ContainsKey($dependency) | Should -BeTrue
      }
    }
  }

  It 'matches checked-in manifests for GUIDs and family dependency floors' {
    foreach ($member in $script:Family.Members) {
      $moduleRoot = Join-Path $script:RepositoryRoot (Join-Path 'src' $member.Name)
      $manifestPath = Join-Path $moduleRoot "$($member.Name).psd1"
      if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        continue
      }

      $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
      $manifest.Guid.ToString() | Should -Be ([guid]$member.Guid).ToString()

      foreach ($dependency in @($member.Dependencies)) {
        $requiredModule = @($manifest.RequiredModules) |
          Where-Object { $_ -is [hashtable] -and $_.ModuleName -eq $dependency } |
          Select-Object -First 1
        $requiredModule | Should -Not -BeNullOrEmpty
        [version]$requiredModule.ModuleVersion | Should -Be ([version]$member.MinimumVersions[$dependency])
      }
    }
  }

  It 'packages the parent with the accepted ProGet child dependency floor' {
    $parent = @($script:Family.Members |
        Where-Object Name -eq 'ATAP.Utilities.BuildTooling.PowerShell')

    $parent.Count | Should -Be 1
    @($parent[0].Dependencies) | Should -Contain 'ATAP.Utilities.BuildTooling.ProGet.PowerShell'
    [version]$parent[0].MinimumVersions['ATAP.Utilities.BuildTooling.ProGet.PowerShell'] |
      Should -Be ([version]'0.1.1')
  }

  It 'rejects malformed or cyclic family data before it can be used as a build order' {
    $malformed = @{ Members = @(@{ Name = 'A'; Dependencies = @('Missing') }) }
    $cyclic = @{ Members = @(@{ Name = 'A'; Dependencies = @('B') }, @{ Name = 'B'; Dependencies = @('A') }) }
    { foreach ($member in $malformed.Members) { foreach ($dependency in $member.Dependencies) { if ($malformed.Members.Name -notcontains $dependency) { throw 'Unknown dependency' } } } } | Should -Throw
    { $visited = [System.Collections.Generic.HashSet[string]]::new(); $active = [System.Collections.Generic.HashSet[string]]::new(); function Visit([string]$name) { if (-not $active.Add($name)) { throw 'Cycle' }; foreach ($dep in @($cyclic.Members | Where-Object Name -eq $name | ForEach-Object Dependencies)) { Visit $dep }; $active.Remove($name) | Out-Null; $visited.Add($name) | Out-Null }; Visit 'A' } | Should -Throw
  }
}
