BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\public\Set-ATAPJavaRuntimeStandard.ps1')
  . (Join-Path $PSScriptRoot '..\..\public\Test-ATAPJavaRuntimeParity.ps1')
}

Describe 'Task 15.182 Java runtime standard contract' {
  It 'keeps public module files function-only' {
    $setSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\public\Set-ATAPJavaRuntimeStandard.ps1') -Raw
    $testSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\public\Test-ATAPJavaRuntimeParity.ps1') -Raw

    $setSource.TrimStart() | Should -Match '^function Set-ATAPJavaRuntimeStandard'
    $testSource.TrimStart() | Should -Match '^function Test-ATAPJavaRuntimeParity'
  }

  It 'removes stale package registrations without uninstalling PlantUML dependencies' {
    $setSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\public\Set-ATAPJavaRuntimeStandard.ps1') -Raw

    $setSource | Should -Match 'uninstall \$stalePackageId --yes --skip-autouninstaller --force --limit-output'
    $setSource | Should -Not -Match '--remove-dependencies|--force-dependencies'
  }

  It 'accepts two identical compliant host inventories' {
    $canonicalHome = 'C:\Program Files\Eclipse Adoptium\jre-21.0.8.9-hotspot'
    $canonicalExe = Join-Path $canonicalHome 'bin\java.exe'
    $runtimeText = @'
    java.runtime.version = 21.0.8+9-LTS
    java.vendor = Eclipse Adoptium
    sun.arch.data.model = 64
'@
    $inventories = @('UTAT022', 'UTAT01') | ForEach-Object {
      [pscustomobject]@{
        ComputerName = $_
        MachineJavaHome = $canonicalHome
        UserJavaHome = $null
        JavaCommandPaths = @($canonicalExe)
        InstalledJava = @([pscustomobject]@{ PSChildName = '{85726190-68A9-48EF-B05C-D527D32A6C1B}' })
        JavaRuntimeDetails = @([pscustomobject]@{ VersionText = $runtimeText })
        MachineJavaPathEntries = @([pscustomobject]@{ Index = 0; ExpandedEntry = (Join-Path $canonicalHome 'bin') })
        Flyway = [pscustomobject]@{ VersionText = 'Flyway OSS Edition 10.21.0 by Redgate' }
        PlantUmlJarCandidates = @('C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar')
      }
    }

    $result = Test-ATAPJavaRuntimeParity -Inventory $inventories

    $result.IsCompliant | Should -BeTrue
    $result.Drift | Should -BeNullOrEmpty
  }

  It 'fails closed when Java 8 precedes the canonical runtime' {
    $canonicalHome = 'C:\Program Files\Eclipse Adoptium\jre-21.0.8.9-hotspot'
    $inventory = [pscustomobject]@{
      ComputerName = 'UTAT022'
      MachineJavaHome = $canonicalHome
      UserJavaHome = $null
      JavaCommandPaths = @('C:\ProgramData\Oracle\Java\javapath\java.exe', (Join-Path $canonicalHome 'bin\java.exe'))
      InstalledJava = @([pscustomobject]@{ PSChildName = '{85726190-68A9-48EF-B05C-D527D32A6C1B}' })
      JavaRuntimeDetails = @([pscustomobject]@{ VersionText = 'java.runtime.version = 1.8.0_111' })
      MachineJavaPathEntries = @([pscustomobject]@{ Index = 17; ExpandedEntry = 'C:\ProgramData\Oracle\Java\javapath' })
      Flyway = [pscustomobject]@{ VersionText = 'UnsupportedClassVersionError' }
      PlantUmlJarCandidates = @('C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar')
    }

    $result = Test-ATAPJavaRuntimeParity -Inventory $inventory

    $result.IsCompliant | Should -BeFalse
    $result.Drift.Check | Should -Contain 'CanonicalJavaFirst'
    $result.Drift.Check | Should -Contain 'FlywayCompatible'
  }
}
