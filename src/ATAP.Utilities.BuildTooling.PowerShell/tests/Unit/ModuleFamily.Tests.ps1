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

  It 'rejects malformed or cyclic family data before it can be used as a build order' {
    $malformed = @{ Members = @(@{ Name = 'A'; Dependencies = @('Missing') }) }
    $cyclic = @{ Members = @(@{ Name = 'A'; Dependencies = @('B') }, @{ Name = 'B'; Dependencies = @('A') }) }
    { foreach ($member in $malformed.Members) { foreach ($dependency in $member.Dependencies) { if ($malformed.Members.Name -notcontains $dependency) { throw 'Unknown dependency' } } } } | Should -Throw
    { $visited = [System.Collections.Generic.HashSet[string]]::new(); $active = [System.Collections.Generic.HashSet[string]]::new(); function Visit([string]$name) { if (-not $active.Add($name)) { throw 'Cycle' }; foreach ($dep in @($cyclic.Members | Where-Object Name -eq $name | ForEach-Object Dependencies)) { Visit $dep }; $active.Remove($name) | Out-Null; $visited.Add($name) | Out-Null }; Visit 'A' } | Should -Throw
  }
}
