#Requires -Module Pester

BeforeAll {
  . (Join-Path $PSScriptRoot 'Invoke-UtilitiesEtwProofHarness.ps1')
  $script:projectPath = 'src/ATAP.Utilities.Logging/ATAP.Utilities.Logging.csproj'
  $script:providerName = 'ATAP-Utilities-ETWProvider'
  $script:providerGuid = '9bcde067-a2a0-5ed5-ab21-ca9fc92d8811'
  $script:unitId = '15.181.n.U00'
  $script:inventory = @([pscustomobject]@{ projectPath = $script:projectPath; taxonomyDisposition = 'EligibleNotYetInstrumented' })
  $script:descriptor = @{
    schemaVersion = '15.181.n.operation.v1'
    unitId = $script:unitId
    projectPath = $script:projectPath
    tfm = 'net10.0'
    providerName = $script:providerName
    providerGuid = $script:providerGuid
    operation = @{
      declaringType = 'Example.Probe'
      methodName = 'Run'
      isStatic = $true
      parameterTypeNames = @('System.String')
      arguments = @('safe')
      expectedTerminal = 'Success'
    }
  }
}

Describe 'Utilities ETW proof harness fail-closed controls' {
  It 'accepts only canonical Utilities invocation inputs' {
    $root = Get-UtilitiesProofRoot
    $evidence = Join-Path $root '_generated\Sprint0015\Task15.181\n\U00'
    $worktreeId = Split-Path -Leaf $root
    $artifacts = Join-Path ([IO.Path]::GetTempPath()) "ATAP.Utilities-U00-Pester\dotnet\ATAP.Utilities\$worktreeId\test"
    (Test-UtilitiesEtwProofInvocation -ProjectPath $script:projectPath -ProviderName $script:providerName -ProviderGuid $script:providerGuid -UnitId $script:unitId -ArtifactsPath $artifacts -EvidencePath $evidence).Valid | Should -BeTrue
    (Test-UtilitiesEtwProofInvocation -ProjectPath '..\src\bad.csproj' -ProviderName $script:providerName -ProviderGuid $script:providerGuid -UnitId $script:unitId -ArtifactsPath $artifacts -EvidencePath $evidence).Valid | Should -BeFalse
    (Test-UtilitiesEtwProofInvocation -ProjectPath $script:projectPath -ProviderName 'ATAP-Ace-ETWProvider' -ProviderGuid $script:providerGuid -UnitId $script:unitId -ArtifactsPath $artifacts -EvidencePath $evidence).Valid | Should -BeFalse
    (Test-UtilitiesEtwProofInvocation -ProjectPath $script:projectPath -ProviderName $script:providerName -ProviderGuid $script:providerGuid -UnitId $script:unitId -ArtifactsPath (Join-Path ([IO.Path]::GetTempPath()) 'wrong-shape') -EvidencePath $evidence).Valid | Should -BeFalse
  }

  It 'accepts a valid eligible descriptor' {
    (Test-UtilitiesEtwProofDescriptor -Descriptor $script:descriptor -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeTrue
  }

  It 'rejects ineligible and wrong-provider descriptors' {
    $ineligible = @([pscustomobject]@{ projectPath = $script:projectPath; taxonomyDisposition = 'Ineligible' })
    (Test-UtilitiesEtwProofDescriptor -Descriptor $script:descriptor -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $ineligible).Valid | Should -BeFalse
    (Test-UtilitiesEtwProofDescriptor -Descriptor $script:descriptor -ExpectedProjectPath $script:projectPath -ExpectedProviderName 'ATAP-Ace-ETWProvider' -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeFalse
  }

  It 'rejects unsafe descriptor input and non-static operations' {
    $bad = @{} + $script:descriptor
    $bad.operation = @{} + $script:descriptor.operation
    $bad.operation.command = 'cmd.exe'
    (Test-UtilitiesEtwProofDescriptor -Descriptor $bad -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeFalse
    $bad.operation.Remove('command')
    $bad.operation.isStatic = $false
    (Test-UtilitiesEtwProofDescriptor -Descriptor $bad -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeFalse
  }

  It 'rejects descriptor shape expansion and malformed field types' {
    $bad = @{} + $script:descriptor
    $bad.runner = 'not-allowed'
    (Test-UtilitiesEtwProofDescriptor -Descriptor $bad -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeFalse

    $bad = @{} + $script:descriptor
    $bad.operation = @{} + $script:descriptor.operation
    $bad.operation.path = 'not-allowed'
    (Test-UtilitiesEtwProofDescriptor -Descriptor $bad -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeFalse

    $bad = @{} + $script:descriptor
    $bad.operation = @{} + $script:descriptor.operation
    $bad.operation.parameterTypeNames = 'System.String'
    (Test-UtilitiesEtwProofDescriptor -Descriptor $bad -ExpectedProjectPath $script:projectPath -ExpectedProviderName $script:providerName -ExpectedProviderGuid $script:providerGuid -ExpectedUnitId $script:unitId -InventoryRows $script:inventory).Valid | Should -BeFalse
  }

  It 'rejects missing and zero-byte traces' {
    (Test-UtilitiesEtwProofArtifacts -TracePath (Join-Path $TestDrive 'missing.nettrace') -BoundaryEventCount 1 -Payloads @()).Valid | Should -BeFalse
    $zeroTrace = Join-Path $TestDrive 'zero.nettrace'
    [System.IO.File]::WriteAllBytes($zeroTrace, @())
    (Test-UtilitiesEtwProofArtifacts -TracePath $zeroTrace -BoundaryEventCount 1 -Payloads @()).Valid | Should -BeFalse
  }

  It 'rejects duplicate events and secret markers' {
    $trace = Join-Path $TestDrive 'valid.nettrace'
    [System.IO.File]::WriteAllBytes($trace, @(1))
    (Test-UtilitiesEtwProofArtifacts -TracePath $trace -BoundaryEventCount 2 -Payloads @()).Valid | Should -BeFalse
    (Test-UtilitiesEtwProofArtifacts -TracePath $trace -BoundaryEventCount 1 -Payloads @('password=not-a-secret')).Valid | Should -BeFalse
  }

  It 'generates a DisableFody runner with a harness-derived canonical target ProjectReference' {
    $root = Get-UtilitiesProofRoot
    $targetProject = Join-Path $root 'src\ATAP.Utilities.Logging\ATAP.Utilities.Logging.csproj'
    $runner = New-UtilitiesEtwBoundedRunner -EvidencePath (Join-Path $TestDrive 'runner-evidence') -TargetProjectPath $targetProject
    [xml] $projectXml = Get-Content -Raw -LiteralPath $runner.ProjectPath
    $projectXml.Project.PropertyGroup.DisableFody | Should -Be 'true'
    $projectXml.SelectSingleNode('//TargetFramework') | Should -BeNullOrEmpty
    $projectXml.Project.PropertyGroup.TargetFrameworks | Should -Be 'net10.0'
    @($projectXml.SelectNodes('//ProjectReference') | ForEach-Object Include) | Should -Contain ([IO.Path]::GetFullPath($targetProject))
    @($projectXml.SelectNodes('//ProjectReference') | ForEach-Object Include) | Should -Contain (Join-Path $root 'src\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj')
    $projectXml.SelectSingleNode('//PackageReference').Include | Should -Be 'MethodBoundaryAspect.Fody'
  }
  It 'retains failed command output and command history for terminal evidence' {
    $commands = [Collections.ArrayList]::new()
    $failure = $null
    try {
      Invoke-UtilitiesEtwExternalCommand -FilePath 'cmd.exe' -Arguments @('/c', 'echo harness-failure 1>&2 & exit /b 17') -Commands $commands
    } catch {
      $failure = $_.Exception
    }
    $failure | Should -Not -BeNullOrEmpty
    $failure.Data.Contains('UtilitiesEtwCommands') | Should -BeTrue
    $recorded = @($failure.Data['UtilitiesEtwCommands'])
    $recorded.Count | Should -Be 1
    $recorded[0].exitCode | Should -Be 17
    $recorded[0].outputSummary | Should -Match 'harness-failure'
  }
  It 'permits non-link cloud reparse placeholders and rejects actual link targets' {
    (Test-UtilitiesEtwReparseEntry -Attributes ([IO.FileAttributes]::ReparsePoint) -LinkTarget $null -ResolvedLinkTarget $null).Valid | Should -BeTrue
    (Test-UtilitiesEtwReparseEntry -Attributes ([IO.FileAttributes]::ReparsePoint) -LinkTarget 'C:\outside' -ResolvedLinkTarget $null).Valid | Should -BeFalse
    (Test-UtilitiesEtwReparseEntry -Attributes ([IO.FileAttributes]::ReparsePoint) -LinkTarget $null -ResolvedLinkTarget ([IO.FileInfo]::new('C:\outside'))).Valid | Should -BeFalse
    (Test-UtilitiesEtwReparseEntry -Attributes ([IO.FileAttributes]::Normal) -LinkTarget 'ignored-for-non-reparse' -ResolvedLinkTarget $null).Valid | Should -BeTrue
  }
  It 'accepts only one correlated EventListener lifecycle and rejects disabled, duplicate, secret, and recursion findings' {
    $listener = @{
      disabledEventCount = 0
      enabledEvents = @(
        @{ eventId = 3; payload = '<Example.Probe.Run' }
        @{ eventId = 3; payload = '>Example.Probe.Run' }
      )
    }
    (Test-UtilitiesEtwRunnerResult -RunnerResult $listener -Descriptor $script:descriptor).Valid | Should -BeTrue
    $listener.disabledEventCount = 1
    (Test-UtilitiesEtwRunnerResult -RunnerResult $listener -Descriptor $script:descriptor).Valid | Should -BeFalse
    $listener.disabledEventCount = 0
    $listener.enabledEvents += @{ eventId = 3; payload = '<Example.Probe.Run' }
    (Test-UtilitiesEtwRunnerResult -RunnerResult $listener -Descriptor $script:descriptor).Valid | Should -BeFalse
    $listener.enabledEvents = @(@{ eventId = 3; payload = '<Example.Probe.Run' }, @{ eventId = 3; payload = '>Example.Probe.Run password=marker' })
    (Test-UtilitiesEtwRunnerResult -RunnerResult $listener -Descriptor $script:descriptor).Valid | Should -BeFalse
    $listener.enabledEvents = @(@{ eventId = 3; payload = '<Example.Probe.Run' }, @{ eventId = 3; payload = '>Example.Probe.Run ATAP.Utilities.ETW.ETWLogAttribute' })
    (Test-UtilitiesEtwRunnerResult -RunnerResult $listener -Descriptor $script:descriptor).Valid | Should -BeFalse
  }
  It 'accepts only the exact decoded synthetic row set' {
    $rows = @(
      [pscustomobject]@{ ProviderName = $script:providerName; ProviderGuid = $script:providerGuid; EventId = 3; Payload = '<U00.SyntheticRunner.Success' }
      [pscustomobject]@{ ProviderName = $script:providerName; ProviderGuid = $script:providerGuid; EventId = 3; Payload = '>U00.SyntheticRunner.Success' }
      [pscustomobject]@{ ProviderName = $script:providerName; ProviderGuid = $script:providerGuid; EventId = 3; Payload = '<U00.SyntheticRunner.Fault' }
      [pscustomobject]@{ ProviderName = $script:providerName; ProviderGuid = $script:providerGuid; EventId = 1; Payload = 'OnException: System.InvalidOperationException|<Main>$' }
      [pscustomobject]@{ ProviderName = $script:providerName; ProviderGuid = $script:providerGuid; EventId = 3; Payload = '<U00.SyntheticRunner.Cancelled' }
      [pscustomobject]@{ ProviderName = $script:providerName; ProviderGuid = $script:providerGuid; EventId = 1; Payload = 'OnException: System.OperationCanceledException|<Main>$' }
    )
    (Test-UtilitiesEtwDecodedSyntheticRows -Rows $rows).Valid | Should -BeTrue
    (Test-UtilitiesEtwDecodedSyntheticRows -Rows @($rows[0])).Valid | Should -BeFalse
    $rows[5].Payload = 'password=marker'
    (Test-UtilitiesEtwDecodedSyntheticRows -Rows $rows).Valid | Should -BeFalse
  }
}
