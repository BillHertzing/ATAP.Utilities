function New-MockTestFileStructure {
  param (
    [Parameter(Mandatory)]
    [string]$BasePath
  )

  $testRoot = Join-Path $BasePath 'TestMockRootDir'
  $src = Join-Path $testRoot 'src'
  $proj1 = Join-Path $src 'project1'
  $proj2 = Join-Path $src 'project2'

  $devLogs = Join-Path $testRoot '_devLogs'
  New-Item -ItemType Directory -Path $devLogs -Force | Out-Null

  # Define project subdirectories
  $subDirectories = @(
    'Documentation', 'private', 'public', '_generated', 'Releases',
    'Resources', 'Resources/RequiredPackagesOfflineRepository',
    'tools', 'lib'
  )
  $testsubDirectories = @('tests/Unit', 'tests/Integration')

  $proj1Dirs = @{}
  $proj2Dirs = @{}

  foreach ($dir in $subDirectories + $testsubDirectories) {
    $proj1Dirs[$dir] = Join-Path $proj1 $dir
    $proj2Dirs[$dir] = Join-Path $proj2 $dir
  }

  foreach ($dir in @($proj1Dirs.Values + $proj2Dirs.Values)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  # Common files
  $commonFiles = @{
    'ReadMe.md'                   = '# Project ReadMe'
    'ReleaseNotes.md'             = '## Release Notes'
    'toc.yml'                     = '- name: Overview'
    'module.build.ps1'            = '# Build script placeholder'
    'tools/ChocolateyInstall.ps1' = '# Chocolatey install script'
  }

  foreach ($file in $commonFiles.Keys) {
    Set-Content -Path (Join-Path $proj1 $file) -Value $commonFiles[$file]
    Set-Content -Path (Join-Path $proj2 $file) -Value $commonFiles[$file]
  }

  # Module entry files
  Set-Content -Path (Join-Path $proj1 'project1.psm1') -Value '# project1 module code'
  Set-Content -Path (Join-Path $proj1 'project1.psd1') -Value "@{ ModuleVersion = '1.0.0' }"

  Set-Content -Path (Join-Path $proj2 'project2.psm1') -Value '# project2 module code'
  Set-Content -Path (Join-Path $proj2 'project2.psd1') -Value "@{ ModuleVersion = '1.0.0' }"

  # Mock source files
  $publicFiles = @(
    @{ Path = 'mock-file1.ps1'; Content = '# mock file 1' },
    @{ Path = 'mock-file2.ps1'; Content = '# mock file 2' }
  )
  $privateFiles = @(
    @{ Path = 'mock-private1.ps1'; Content = '# private file' }
  )

  foreach ($projDirs in @($proj1Dirs, $proj2Dirs)) {
    foreach ($file in $publicFiles) {
      Set-Content -Path (Join-Path $projDirs['public'] $file.Path) -Value $file.Content
    }
    foreach ($file in $privateFiles) {
      Set-Content -Path (Join-Path $projDirs['private'] $file.Path) -Value $file.Content
    }
  }

  # Unit tests
  $testFiles = @(
    @{ Name = 'mock-file1.tests.ps1'; Content = "Describe 'mock-file1' { It 'does something' { \$true | Should -BeTrue } }" },
    @{ Name = 'mock-file2.tests.ps1'; Content = "Describe 'mock-file2' { It 'does something else' { \$true | Should -BeTrue } }" }
  )

  foreach ($projDirs in @($proj1Dirs, $proj2Dirs)) {
    foreach ($test in $testFiles) {
      Set-Content -Path (Join-Path $projDirs['tests/Unit'] $test.Name) -Value $test.Content
    }
  }

  # Root-level files
  Set-Content -Path (Join-Path $testRoot '.gitignore') -Value @'
# Ignore compiled files
*.dll
*.pdb
*.log
*_generated/
*Resources/RequiredPackagesOfflineRepository/
'@

  Set-Content -Path (Join-Path $testRoot 'toc.yml') -Value '- name: Root TOC'

  return @{
    TestMockRootDir = $testRoot
    SrcDir          = $src
    Project1Dir     = $proj1
    Project2Dir     = $proj2
    Project1Paths   = $proj1Dirs
    Project2Paths   = $proj2Dirs
    DevLogs         = $devLogs
  }
}
