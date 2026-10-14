[CmdletBinding()]
param(
  [string] $ProjectPath,
  [string] $ProviderName,
  [guid] $ProviderGuid,
  [string] $UnitId,
  [string] $ArtifactsPath,
  [string] $EvidencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-ProofResult([bool] $valid, [string] $reason) {
  [pscustomobject]@{ Valid = $valid; Reason = $reason }
}

function Get-UtilitiesProofRoot {
  (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-UtilitiesEtwArtifactProperties {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $ArtifactsPath)
  if (-not [IO.Path]::IsPathFullyQualified($ArtifactsPath)) { throw 'ArtifactsPath must be absolute.' }

  $repositoryRoot = Get-UtilitiesProofRoot
  $repositoryName = Split-Path -Leaf $repositoryRoot
  $canonicalPath = [IO.Path]::GetFullPath($ArtifactsPath).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  if ($canonicalPath.StartsWith($repositoryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'ArtifactsPath must be outside the repository worktree.' }

  $executionId = Split-Path -Leaf $canonicalPath
  $worktreeId = Split-Path -Leaf (Split-Path -Parent $canonicalPath)
  $repositorySegment = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $canonicalPath))
  $dotnetSegment = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $canonicalPath)))
  $artifactRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $canonicalPath)))
  if ([string]::IsNullOrWhiteSpace($executionId) -or $executionId -match '[\\/:]' -or $worktreeId -cne $repositoryName -or $repositorySegment -cne 'ATAP.Utilities' -or $dotnetSegment -cne 'dotnet' -or -not [IO.Path]::IsPathFullyQualified($artifactRoot)) {
    throw 'ArtifactsPath must exactly be <external-root>\dotnet\ATAP.Utilities\<full-current-worktree-directory-name>\<execution-id>.'
  }

  [pscustomobject]@{
    CanonicalPath = $canonicalPath
    Root = $artifactRoot
    WorktreeId = $worktreeId
    ExecutionId = $executionId
    BuildProperties = @(
      "-p:ATAPArtifactsRoot=$artifactRoot"
      "-p:ATAPArtifactsWorktreeId=$worktreeId"
      "-p:ATAPArtifactsExecutionId=$executionId"
      "-p:ArtifactsPath=$canonicalPath"
      '-p:GeneratePackageOnBuild=false'
    )
  }
}

function Test-UtilitiesEtwProofInvocation {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $ProjectPath,
    [Parameter(Mandatory)] [string] $ProviderName,
    [Parameter(Mandatory)] [guid] $ProviderGuid,
    [Parameter(Mandatory)] [string] $UnitId,
    [Parameter(Mandatory)] [string] $ArtifactsPath,
    [Parameter(Mandatory)] [string] $EvidencePath
  )

  $root = Get-UtilitiesProofRoot
  if ($ProviderName -cne 'ATAP-Utilities-ETWProvider' -or $ProviderGuid -ne [guid] '9bcde067-a2a0-5ed5-ab21-ca9fc92d8811') { return New-ProofResult $false 'wrong Utilities provider identity' }
  if ($UnitId -notmatch '^15\.181\.n\.U\d{2}$') { return New-ProofResult $false 'UnitId is not a Utilities wave identifier' }
  if ([IO.Path]::IsPathFullyQualified($ProjectPath) -or $ProjectPath -match '(^|[\\/])\.\.([\\/]|$)' -or $ProjectPath -notmatch '\.csproj$') { return New-ProofResult $false 'ProjectPath must be a normalized repository-relative csproj path' }
  $canonicalProject = [IO.Path]::GetFullPath((Join-Path $root $ProjectPath)).Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
  if ($canonicalProject -cne $ProjectPath.Replace('\', '/')) { return New-ProofResult $false 'ProjectPath is not canonical beneath the repository root' }
  if (-not (Test-Path -LiteralPath (Join-Path $root $ProjectPath) -PathType Leaf)) { return New-ProofResult $false 'ProjectPath does not exist' }
  $canonicalEvidence = Join-Path $root "_generated\Sprint0015\Task15.181\n\$($UnitId.Split('.')[-1])"
  if (-not [IO.Path]::IsPathFullyQualified($EvidencePath) -or [IO.Path]::GetFullPath($EvidencePath) -cne $canonicalEvidence) { return New-ProofResult $false 'EvidencePath is not the exact unit evidence directory' }
  try { $null = Get-UtilitiesEtwArtifactProperties -ArtifactsPath $ArtifactsPath }
  catch { return New-ProofResult $false $_.Exception.Message }
  New-ProofResult $true 'invocation contract accepted'
}

function Test-UtilitiesEtwReparseEntry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [IO.FileAttributes] $Attributes,
    [AllowNull()] [string] $LinkTarget,
    [AllowNull()] [object] $ResolvedLinkTarget
  )
  if (($Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { return New-ProofResult $true 'entry is not a reparse point' }
  if (-not [string]::IsNullOrWhiteSpace($LinkTarget) -or $null -ne $ResolvedLinkTarget) { return New-ProofResult $false 'link or junction traversal is not permitted beneath EvidencePath' }
  New-ProofResult $true 'non-link reparse placeholder is permitted'
}

function Test-UtilitiesEtwEvidencePathTraversal {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $EvidencePath, [Parameter(Mandatory)] [string] $DescriptorPath)

  $root = Get-UtilitiesProofRoot
  foreach ($candidate in $EvidencePath, $DescriptorPath) {
    $current = Get-Item -LiteralPath $candidate -Force
    while ($true) {
      $resolvedLinkTarget = $null
      try { $resolvedLinkTarget = $current.ResolveLinkTarget($true) } catch { }
      $entryValidation = Test-UtilitiesEtwReparseEntry -Attributes $current.Attributes -LinkTarget $current.LinkTarget -ResolvedLinkTarget $resolvedLinkTarget
      if (-not $entryValidation.Valid) { return $entryValidation }
      if ([IO.Path]::GetFullPath($current.FullName) -ceq [IO.Path]::GetFullPath($root)) { break }
      $parent = if ($current -is [IO.DirectoryInfo]) { $current.Parent } else { $current.Directory }
      if ($null -eq $parent -or -not [IO.Path]::GetFullPath($parent.FullName).StartsWith([IO.Path]::GetFullPath($root), [StringComparison]::OrdinalIgnoreCase)) { return New-ProofResult $false 'EvidencePath traversal escaped the repository root' }
      $current = $parent
    }
  }
  New-ProofResult $true 'EvidencePath contains no link or junction traversal'
}
function Test-UtilitiesEtwProofDescriptor {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [hashtable] $Descriptor,
    [Parameter(Mandatory)] [string] $ExpectedProjectPath,
    [Parameter(Mandatory)] [string] $ExpectedProviderName,
    [Parameter(Mandatory)] [string] $ExpectedProviderGuid,
    [Parameter(Mandatory)] [string] $ExpectedUnitId,
    [Parameter(Mandatory)] [object[]] $InventoryRows
  )

  $required = 'schemaVersion', 'unitId', 'projectPath', 'tfm', 'providerName', 'providerGuid', 'operation'
  $allowed = [System.Collections.Generic.HashSet[string]]::new([string[]] $required)
  foreach ($name in $Descriptor.Keys) {
    if (-not $allowed.Contains([string] $name)) { return New-ProofResult $false "unsupported descriptor property: $name" }
  }
  foreach ($name in $required) {
    if (-not $Descriptor.ContainsKey($name)) { return New-ProofResult $false "missing descriptor property: $name" }
  }
  foreach ($name in 'schemaVersion', 'unitId', 'projectPath', 'tfm', 'providerName', 'providerGuid') {
    if ($Descriptor[$name] -isnot [string] -or [string]::IsNullOrWhiteSpace($Descriptor[$name])) { return New-ProofResult $false "descriptor property must be a non-empty string: $name" }
  }
  if ($Descriptor.schemaVersion -cne '15.181.n.operation.v1') { return New-ProofResult $false 'unsupported descriptor schemaVersion' }
  if ($Descriptor.unitId -cne $ExpectedUnitId) { return New-ProofResult $false 'descriptor unitId does not match CLI UnitId' }
  if ($Descriptor.projectPath -cne $ExpectedProjectPath) { return New-ProofResult $false 'descriptor projectPath does not match CLI ProjectPath' }
  if ($Descriptor.providerName -cne $ExpectedProviderName -or $Descriptor.providerGuid -cne $ExpectedProviderGuid) { return New-ProofResult $false 'descriptor provider identity does not match CLI' }
  $row = @($InventoryRows | Where-Object { $_.projectPath -ceq $ExpectedProjectPath })
  if ($row.Count -ne 1 -or $row[0].taxonomyDisposition -notin 'EligibleInstrumented', 'EligibleNotYetInstrumented') { return New-ProofResult $false 'project is not exactly one eligible inventory row' }
  if ($Descriptor.operation -isnot [hashtable]) { return New-ProofResult $false 'operation must be an object' }

  $operation = $Descriptor.operation
  $requiredOperation = 'declaringType', 'methodName', 'isStatic', 'parameterTypeNames', 'arguments', 'expectedTerminal'
  $allowedOperation = [System.Collections.Generic.HashSet[string]]::new([string[]] $requiredOperation)
  foreach ($name in $operation.Keys) {
    if (-not $allowedOperation.Contains([string] $name)) { return New-ProofResult $false "unsupported operation property: $name" }
  }
  foreach ($name in $requiredOperation) {
    if (-not $operation.ContainsKey($name)) { return New-ProofResult $false "missing operation property: $name" }
  }
  if ($operation.declaringType -isnot [string] -or [string]::IsNullOrWhiteSpace($operation.declaringType)) { return New-ProofResult $false 'operation declaringType must be a non-empty string' }
  if ($operation.methodName -isnot [string] -or [string]::IsNullOrWhiteSpace($operation.methodName)) { return New-ProofResult $false 'operation methodName must be a non-empty string' }
  if ($operation.parameterTypeNames -isnot [array] -or $operation.arguments -isnot [array]) { return New-ProofResult $false 'operation parameterTypeNames and arguments must be arrays' }
  foreach ($parameterTypeName in @($operation.parameterTypeNames)) {
    if ($parameterTypeName -isnot [string] -or [string]::IsNullOrWhiteSpace($parameterTypeName)) { return New-ProofResult $false 'operation parameterTypeNames must contain only non-empty strings' }
  }
  if ($operation.isStatic -ne $true) { return New-ProofResult $false 'operation must be static' }
  if ($operation.expectedTerminal -notin 'Success', 'Fault', 'Cancelled') { return New-ProofResult $false 'unsupported expectedTerminal' }
  if (@($operation.parameterTypeNames).Count -ne @($operation.arguments).Count) { return New-ProofResult $false 'argument count does not match parameterTypeNames' }
  foreach ($argument in @($operation.arguments)) {
    if ($argument -is [System.Collections.IDictionary] -or ($argument -is [System.Collections.IEnumerable] -and $argument -isnot [string])) { return New-ProofResult $false 'arguments must be JSON scalars' }
  }
  New-ProofResult $true 'descriptor contract accepted'
}

function Test-UtilitiesEtwProofArtifacts {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $TracePath, [Parameter(Mandatory)] [int] $BoundaryEventCount, [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Payloads)
  if (-not (Test-Path -LiteralPath $TracePath -PathType Leaf)) { return New-ProofResult $false 'trace is missing' }
  if ((Get-Item -LiteralPath $TracePath).Length -eq 0) { return New-ProofResult $false 'trace is zero-byte' }
  if ($BoundaryEventCount -ne 1) { return New-ProofResult $false 'duplicate or missing boundary event' }
  foreach ($payload in $Payloads) {
    if ($payload -match '(?i)password=|bearer\s+|secretname|connection\s*string') { return New-ProofResult $false 'secret marker found in event payload' }
  }
  New-ProofResult $true 'trace/event/redaction checks accepted'
}

function Invoke-UtilitiesEtwExternalCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $FilePath,
    [Parameter(Mandatory)] [string[]] $Arguments,
    [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.ArrayList] $Commands
  )

  $commandOutput = @(& $FilePath @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  foreach ($line in $commandOutput) { Write-Verbose ([string] $line) }
  $outputSummary = (($commandOutput | ForEach-Object { [string] $_ }) -join [Environment]::NewLine)
  if ($outputSummary.Length -gt 4000) { $outputSummary = $outputSummary.Substring(0, 4000) }
  [void] $Commands.Add([ordered]@{ filePath = $FilePath; arguments = $Arguments; exitCode = $exitCode; outputSummary = $outputSummary })
  if ($exitCode -ne 0) {
    $exception = [InvalidOperationException]::new("Command failed ($exitCode): $FilePath")
    $exception.Data['UtilitiesEtwCommands'] = @($Commands)
    throw $exception
  }
}

function Test-UtilitiesEtwDecodedSyntheticRows {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [object[]] $Rows)

  $providerName = 'ATAP-Utilities-ETWProvider'
  $providerGuid = '9bcde067-a2a0-5ed5-ab21-ca9fc92d8811'
  if ($Rows.Count -ne 6) { return New-ProofResult $false 'synthetic trace did not contain exactly six provider rows' }
  foreach ($row in $Rows) {
    if ($row.ProviderName -cne $providerName -or $row.ProviderGuid -cne $providerGuid) { return New-ProofResult $false 'decoded provider identity mismatch' }
    if ($row.EventId -notin 1, 3) { return New-ProofResult $false 'decoded event ID is outside the provider boundary schema' }
    if ($row.Payload -match '(?i)password=|bearer\s+|secretname|connection\s*string') { return New-ProofResult $false 'secret marker found in decoded payload' }
  }

  $expected = @(
    '3|<U00.SyntheticRunner.Success'
    '3|>U00.SyntheticRunner.Success'
    '3|<U00.SyntheticRunner.Fault'
    '1|OnException: System.InvalidOperationException|<Main>$'
    '3|<U00.SyntheticRunner.Cancelled'
    '1|OnException: System.OperationCanceledException|<Main>$'
  )
  $actual = @($Rows | ForEach-Object { "$($_.EventId)|$($_.Payload)" })
  if (($actual | Select-Object -Unique).Count -ne 6) { return New-ProofResult $false 'duplicate synthetic provider event found' }
  if (@(Compare-Object -ReferenceObject $expected -DifferenceObject $actual -CaseSensitive).Count -ne 0) { return New-ProofResult $false 'synthetic correlation and terminal event set is not exact' }
  New-ProofResult $true 'decoded synthetic EventPipe rows are exact, correlated, non-duplicated, and redacted'
}

function Invoke-UtilitiesEtwSyntheticHarnessProof {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $ArtifactsPath)

  $root = Get-UtilitiesProofRoot
  $artifact = Get-UtilitiesEtwArtifactProperties -ArtifactsPath $ArtifactsPath
  $testProject = Join-Path $root 'tests\ATAP.Utilities.ETW.UnitTests\ATAP.Utilities.ETW.UnitTests.csproj'
  $runnerProject = Join-Path $root 'tests\ATAP.Utilities.ETW.UnitTests\SyntheticRunner\ATAP.Utilities.ETW.SyntheticRunner.csproj'
  $traceTool = Join-Path ([IO.Path]::GetTempPath()) 'ATAP.Utilities-Task15.181-n-U00\tools\dotnet-trace.exe'
  $syntheticPath = Join-Path $artifact.CanonicalPath 'synthetic'
  $tracePath = Join-Path $syntheticPath 'trace.nettrace'
  $rowsPath = Join-Path $syntheticPath 'decoded-rows.json'
  $commands = [System.Collections.ArrayList]::new()
  $props = $artifact.BuildProperties

  if (-not (Test-Path -LiteralPath $traceTool -PathType Leaf)) { throw 'authorized task-local dotnet-trace is missing' }
  New-Item -ItemType Directory -Path $syntheticPath -Force | Out-Null
  foreach ($stalePath in $tracePath, $rowsPath) {
    if (Test-Path -LiteralPath $stalePath -PathType Leaf) { Remove-Item -LiteralPath $stalePath -Force }
  }

  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('restore', $testProject, '--locked-mode') + $props) -Commands $commands
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('restore', $runnerProject, '--locked-mode') + $props) -Commands $commands
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('build', $runnerProject, '-c', 'Release', '--no-restore') + $props) -Commands $commands
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('test', $testProject, '-c', 'Release', '--no-restore', '--filter', 'FullyQualifiedName~HarnessSyntheticProbeTests') + $props) -Commands $commands

  $runnerDll = Join-Path $artifact.CanonicalPath 'bin\ATAP.Utilities.ETW.SyntheticRunner\release_net10.0\ATAP.Utilities.ETW.SyntheticRunner.dll'
  if (-not (Test-Path -LiteralPath $runnerDll -PathType Leaf)) { throw 'bounded synthetic runner bin output is missing' }
  Invoke-UtilitiesEtwExternalCommand -FilePath $traceTool -Arguments @(
    'collect'
    '--providers'
    'ATAP-Utilities-ETWProvider:0xFFFFFFFFFFFFFFFF:5'
    '-o'
    $tracePath
    '--'
    'dotnet'
    $runnerDll
  ) -Commands $commands

  $oldTrace = $env:U00_TRACE_PATH
  $oldRows = $env:U00_DECODED_ROWS_PATH
  try {
    $env:U00_TRACE_PATH = $tracePath
    $env:U00_DECODED_ROWS_PATH = $rowsPath
    Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('test', $testProject, '-c', 'Release', '--no-restore', '--filter', 'FullyQualifiedName~UtilitiesEtwTraceDecoderEntryPointTests') + $props) -Commands $commands
  }
  finally {
    $env:U00_TRACE_PATH = $oldTrace
    $env:U00_DECODED_ROWS_PATH = $oldRows
  }

  $rows = @(Get-Content -LiteralPath $rowsPath -Raw | ConvertFrom-Json)
  $decodedValidation = Test-UtilitiesEtwDecodedSyntheticRows -Rows $rows
  if (-not $decodedValidation.Valid) { throw $decodedValidation.Reason }
  [pscustomobject]@{
    tracePath = $tracePath
    traceBytes = (Get-Item -LiteralPath $tracePath).Length
    traceSha256 = (Get-FileHash -LiteralPath $tracePath -Algorithm SHA256).Hash
    decodedRowsPath = $rowsPath
    decodedRows = $rows.Count
    validation = $decodedValidation
    commands = $commands
  }
}

function Get-UtilitiesEtwBuiltAssembly {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $ProjectPath, [Parameter(Mandatory)] [string] $TargetFramework, [Parameter(Mandatory)] [pscustomobject] $Artifact)
  $assemblyName = [IO.Path]::GetFileNameWithoutExtension($ProjectPath)
  $outputDirectory = Join-Path $Artifact.CanonicalPath "bin\$assemblyName\release_$TargetFramework"
  $candidates = @(Get-ChildItem -LiteralPath $outputDirectory -Filter "$assemblyName.dll" -File -ErrorAction SilentlyContinue)
  if ($candidates.Count -ne 1) { throw "Expected exactly one Release $TargetFramework output assembly for $ProjectPath; found $($candidates.Count)." }
  $candidates[0].FullName
}

function Resolve-UtilitiesEtwOperation {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [hashtable] $Descriptor, [Parameter(Mandatory)] [string] $AssemblyPath, [Parameter(Mandatory)] [string] $DependencyDirectory)
  if (-not (Test-Path -LiteralPath $DependencyDirectory -PathType Container)) { throw 'bounded runner dependency closure directory is missing' }
  foreach ($dependency in Get-ChildItem -LiteralPath $DependencyDirectory -Filter '*.dll' -File) {
    if ([IO.Path]::GetFullPath($dependency.FullName) -ceq [IO.Path]::GetFullPath($AssemblyPath)) { continue }
    try { [Reflection.Assembly]::LoadFrom($dependency.FullName) | Out-Null } catch { }
  }
  $operation = $Descriptor.operation
  $assembly = [Reflection.Assembly]::LoadFrom($AssemblyPath)
  $type = $assembly.GetType($operation.declaringType, $false, $false)
  if ($null -eq $type -or $type.FullName -match '[<>]') { throw 'descriptor declaringType is not a supported target-assembly type' }
  $parameterTypes = [Collections.Generic.List[type]]::new()
  foreach ($parameterTypeName in @($operation.parameterTypeNames)) {
    $parameterType = [type]::GetType($parameterTypeName, $false) ?? $assembly.GetType($parameterTypeName, $false, $false)
    if ($null -eq $parameterType) { throw "descriptor parameter type is not supported: $parameterTypeName" }
    [void] $parameterTypes.Add($parameterType)
  }
  $method = $type.GetMethod($operation.methodName, [Reflection.BindingFlags]'Public,NonPublic,Static', $null, $parameterTypes.ToArray(), $null)
  if ($null -eq $method -or $method.IsSpecialName -or $method.IsGenericMethod -or $method.Name -match '^(get_|set_|add_|remove_|<)') { throw 'descriptor method is not a supported synchronous static method' }
  if ($method.ReturnType -eq [Threading.Tasks.Task] -or ($method.ReturnType.IsGenericType -and $method.ReturnType.GetGenericTypeDefinition() -eq [Threading.Tasks.Task``1])) { throw 'async methods are not supported by the bounded runner' }
  [pscustomobject]@{ Assembly = $assembly; Type = $type; Method = $method; ParameterTypes = $parameterTypes.ToArray() }
}

function Test-UtilitiesEtwWovenIl {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [pscustomobject] $ResolvedOperation)
  $body = $ResolvedOperation.Method.GetMethodBody()
  if ($null -eq $body) { return New-ProofResult $false 'target method has no inspectable IL body' }
  $il = $body.GetILAsByteArray(); $calls = [Collections.Generic.List[string]]::new()
  for ($index = 0; $index -le $il.Length - 5; $index++) {
    if ($il[$index] -in 0x28, 0x6F) {
      try { $member = $ResolvedOperation.Method.Module.ResolveMethod([BitConverter]::ToInt32($il, $index + 1)); if ($member.DeclaringType.Assembly.GetName().Name -eq 'ATAP.Utilities.ETW') { [void] $calls.Add("$($member.DeclaringType.FullName).$($member.Name)") } } catch { }
    }
  }
  if ($calls.Count -eq 0) { return New-ProofResult $false 'post-weave IL contains no ATAP.Utilities.ETW call from the selected method' }
  [pscustomobject]@{ Valid = $true; Reason = 'post-weave IL contains a Utilities provider/aspect call'; Calls = @($calls | Select-Object -Unique); IlByteCount = $il.Length }
}

function Test-UtilitiesEtwRunnerResult {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [hashtable] $RunnerResult, [Parameter(Mandatory)] [hashtable] $Descriptor)
  if ($RunnerResult.disabledEventCount -ne 0) { return New-ProofResult $false 'disabled provider emitted one or more events' }
  $events = @($RunnerResult.enabledEvents)
  if ($events.Count -eq 0) { return New-ProofResult $false 'enabled provider emitted no events' }
  $payloads = @($events | ForEach-Object { [string] $_.payload })
  if (($payloads | Select-Object -Unique).Count -ne $payloads.Count) { return New-ProofResult $false 'duplicate boundary event payload detected' }
  foreach ($payload in $payloads) {
    if ($payload -match '(?i)password=|bearer\s+|secretname|connection\s*string') { return New-ProofResult $false 'secret marker found in runner payload' }
    if ($payload -match '(?i)ATAP\.Utilities\.ETW\.(ETWLogAttribute|ATAPUtilitiesETWProvider)') { return New-ProofResult $false 'provider recursion marker found in runner payload' }
  }
  $operationName = "$($Descriptor.operation.declaringType).$($Descriptor.operation.methodName)"
  $starts = @($events | Where-Object { $_.eventId -eq 3 -and $_.payload -like "<$operationName*" })
  if ($starts.Count -ne 1) { return New-ProofResult $false 'expected exactly one correlated boundary start event' }
  switch ($Descriptor.operation.expectedTerminal) {
    'Success' { if (@($events | Where-Object { $_.eventId -eq 3 -and $_.payload -like ">$operationName*" }).Count -ne 1) { return New-ProofResult $false 'expected exactly one correlated success terminal event' } }
    'Cancelled' { if (@($events | Where-Object { $_.eventId -eq 1 -and $_.payload -match 'OperationCanceledException' }).Count -ne 1) { return New-ProofResult $false 'expected exactly one cancellation terminal event' } }
    'Fault' { if (@($events | Where-Object { $_.eventId -eq 1 -and $_.payload -notmatch 'OperationCanceledException' }).Count -ne 1) { return New-ProofResult $false 'expected exactly one fault terminal event' } }
  }
  New-ProofResult $true 'EventListener lifecycle, disabled-provider, redaction, duplicate, and recursion checks accepted'
}

function New-UtilitiesEtwBoundedRunner {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $EvidencePath, [Parameter(Mandatory)] [string] $TargetProjectPath)
  $root = Get-UtilitiesProofRoot; $runnerPath = Join-Path $EvidencePath 'runner'
  $canonicalTargetProjectPath = [IO.Path]::GetFullPath($TargetProjectPath)
  if (-not $canonicalTargetProjectPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $canonicalTargetProjectPath -PathType Leaf)) { throw 'bounded runner target project must be the canonical repository project selected by the harness' }
  $escapedTargetProjectPath = [Security.SecurityElement]::Escape($canonicalTargetProjectPath)
  $providerProjectPath = Join-Path $root 'src\ATAP.Utilities.ETW\ATAP.Utilities.ETW.csproj'
  if (-not (Test-Path -LiteralPath $providerProjectPath -PathType Leaf)) { throw 'canonical Utilities provider project is missing' }
  $escapedProviderProjectPath = [Security.SecurityElement]::Escape([IO.Path]::GetFullPath($providerProjectPath))
  New-Item -ItemType Directory -Path $runnerPath -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $root 'tests\ATAP.Utilities.ETW.UnitTests\BoundedOperationRunner.cs.template') -Destination (Join-Path $runnerPath 'Program.cs') -Force
  @"
<Project Sdk='Microsoft.NET.Sdk'><PropertyGroup><OutputType>Exe</OutputType><TargetFrameworks>net10.0</TargetFrameworks><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><DisableFody>true</DisableFody><AssemblyName>ATAP.Utilities.ETW.BoundedOperationRunner</AssemblyName><GeneratePackageOnBuild>false</GeneratePackageOnBuild></PropertyGroup><ItemGroup><ProjectReference Include='$escapedTargetProjectPath' /><ProjectReference Include='$escapedProviderProjectPath' /></ItemGroup><ItemGroup><PackageReference Include='MethodBoundaryAspect.Fody' /></ItemGroup></Project>
"@ | Set-Content -LiteralPath (Join-Path $runnerPath 'ATAP.Utilities.ETW.BoundedOperationRunner.csproj') -Encoding utf8
  [pscustomobject]@{ Directory = $runnerPath; ProjectPath = (Join-Path $runnerPath 'ATAP.Utilities.ETW.BoundedOperationRunner.csproj'); TargetProjectPath = $canonicalTargetProjectPath }
}

function Invoke-UtilitiesEtwProjectProof {
  [CmdletBinding()]
  param([Parameter(Mandatory)] [string] $ProjectPath, [Parameter(Mandatory)] [hashtable] $Descriptor, [Parameter(Mandatory)] [pscustomobject] $Artifact, [Parameter(Mandatory)] [string] $EvidencePath)
  $root = Get-UtilitiesProofRoot; $targetProject = Join-Path $root $ProjectPath; $testProject = Join-Path $root 'tests\ATAP.Utilities.ETW.UnitTests\ATAP.Utilities.ETW.UnitTests.csproj'
  $traceTool = Join-Path ([IO.Path]::GetTempPath()) 'ATAP.Utilities-Task15.181-n-U00\tools\dotnet-trace.exe'
  if (-not (Test-Path -LiteralPath $traceTool -PathType Leaf)) { throw 'authorized task-local dotnet-trace is missing' }
  $commands = [Collections.ArrayList]::new(); $props = $Artifact.BuildProperties
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('restore', $targetProject, '--locked-mode') + $props) -Commands $commands
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('build', $targetProject, '-c', 'Release', '--no-restore') + $props) -Commands $commands
  $assemblyPath = Get-UtilitiesEtwBuiltAssembly -ProjectPath $ProjectPath -TargetFramework $Descriptor.tfm -Artifact $Artifact
  $runner = New-UtilitiesEtwBoundedRunner -EvidencePath $EvidencePath -TargetProjectPath $targetProject
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('restore', $runner.ProjectPath, '--ignore-failed-sources') + $props) -Commands $commands
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('build', $runner.ProjectPath, '-c', 'Release', '--no-restore') + $props) -Commands $commands
  $runnerDll = Get-UtilitiesEtwBuiltAssembly -ProjectPath 'ATAP.Utilities.ETW.BoundedOperationRunner.csproj' -TargetFramework 'net10.0' -Artifact $Artifact
  $resolved = Resolve-UtilitiesEtwOperation -Descriptor $Descriptor -AssemblyPath $assemblyPath -DependencyDirectory (Split-Path -Parent $runnerDll); $ilValidation = Test-UtilitiesEtwWovenIl -ResolvedOperation $resolved
  if (-not $ilValidation.Valid) { throw $ilValidation.Reason }
  $parameterJson = ConvertTo-Json -InputObject ([object[]] @($Descriptor.operation.parameterTypeNames)) -Compress
  $argumentJson = '[' + ((@($Descriptor.operation.arguments) | ForEach-Object { ConvertTo-Json -InputObject $_ -Compress }) -join ',') + ']'
  $runnerResultPath = Join-Path $runner.Directory 'runner-result.json'
  $runnerArguments = @($runnerDll, $assemblyPath, $Descriptor.operation.declaringType, $Descriptor.operation.methodName, [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($parameterJson)), [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($argumentJson)), $Descriptor.operation.expectedTerminal, $runnerResultPath, 'Lifecycle')
  $traceRunnerArguments = @($runnerArguments[0..7] + 'Trace')
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments $runnerArguments -Commands $commands
  $listenerResult = Get-Content -LiteralPath $runnerResultPath -Raw | ConvertFrom-Json -AsHashtable; $listenerValidation = Test-UtilitiesEtwRunnerResult -RunnerResult $listenerResult -Descriptor $Descriptor
  if (-not $listenerValidation.Valid) { throw $listenerValidation.Reason }
  $tracePath = Join-Path $runner.Directory 'trace.nettrace'
  Invoke-UtilitiesEtwExternalCommand -FilePath $traceTool -Arguments (@('collect', '--providers', 'ATAP-Utilities-ETWProvider:0xFFFFFFFFFFFFFFFF:5', '-o', $tracePath, '--', 'dotnet') + $traceRunnerArguments) -Commands $commands
  $rowsPath = Join-Path $runner.Directory 'decoded-rows.json'
  Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('restore', $testProject, '--locked-mode') + $props) -Commands $commands
  $oldTrace = $env:U00_TRACE_PATH; $oldRows = $env:U00_DECODED_ROWS_PATH
  try { $env:U00_TRACE_PATH = $tracePath; $env:U00_DECODED_ROWS_PATH = $rowsPath; Invoke-UtilitiesEtwExternalCommand -FilePath 'dotnet' -Arguments (@('test', $testProject, '-c', 'Release', '--no-restore', '--filter', 'FullyQualifiedName~UtilitiesEtwTraceDecoderEntryPointTests') + $props) -Commands $commands }
  finally { $env:U00_TRACE_PATH = $oldTrace; $env:U00_DECODED_ROWS_PATH = $oldRows }
  $rows = @(Get-Content -LiteralPath $rowsPath -Raw | ConvertFrom-Json -AsHashtable)
  $traceValidation = Test-UtilitiesEtwProofArtifacts -TracePath $tracePath -BoundaryEventCount (@($rows | Where-Object { $_.EventId -eq 3 -and $_.Payload -like "<$($Descriptor.operation.declaringType).$($Descriptor.operation.methodName)*" }).Count) -Payloads @($rows | ForEach-Object { $_.Payload })
  if (-not $traceValidation.Valid) { throw $traceValidation.Reason }
  [pscustomobject]@{ assemblyPath = $assemblyPath; runnerPath = $runner.Directory; ilValidation = $ilValidation; listenerValidation = $listenerValidation; eventPipeValidation = $traceValidation; tracePath = $tracePath; traceBytes = (Get-Item -LiteralPath $tracePath).Length; traceSha256 = (Get-FileHash -LiteralPath $tracePath -Algorithm SHA256).Hash; decodedRowsPath = $rowsPath; decodedRows = $rows.Count; commands = $commands }
}
function Invoke-UtilitiesEtwProofHarness {
  [CmdletBinding()]
  param([string] $ProjectPath, [string] $ProviderName, [guid] $ProviderGuid, [string] $UnitId, [string] $ArtifactsPath, [string] $EvidencePath)

  $result = [ordered]@{
    unitId = $UnitId
    terminalDisposition = 'FailClosed'
    productionProjectDisposition = 'NotEvaluated'
    descriptorSha256 = $null
    descriptorValidation = $null
    artifactChecks = $null
    commands = @()
  }
  try {
    $invocationValidation = Test-UtilitiesEtwProofInvocation @PSBoundParameters
    if (-not $invocationValidation.Valid) { throw $invocationValidation.Reason }
    if ($UnitId -ceq '15.181.n.U00') {
      $result.syntheticHarnessProof = Invoke-UtilitiesEtwSyntheticHarnessProof -ArtifactsPath $ArtifactsPath
      $result.commands = $result.syntheticHarnessProof.commands
      $result.terminalDisposition = 'SyntheticHarnessVerified'
      return 0
    }

    $root = Get-UtilitiesProofRoot
    $artifact = Get-UtilitiesEtwArtifactProperties -ArtifactsPath $ArtifactsPath
    $descriptorPath = Join-Path $EvidencePath 'operation.json'
    if (-not (Test-Path -LiteralPath $descriptorPath -PathType Leaf)) { throw 'operation descriptor is missing' }
    $evidenceTraversal = Test-UtilitiesEtwEvidencePathTraversal -EvidencePath $EvidencePath -DescriptorPath $descriptorPath
    if (-not $evidenceTraversal.Valid) { throw $evidenceTraversal.Reason }
    $result.descriptorSha256 = (Get-FileHash -LiteralPath $descriptorPath -Algorithm SHA256).Hash
    $descriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json -AsHashtable
    $inventoryPath = Join-Path (Split-Path $root -Parent) '_Planning-wt-35-Sprint-0015-work-items\InformationForTheFuture\Sprint0015\StreamR\Task-15.181.m-ETW-Disposition-Inventory.json'
    $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json -AsHashtable
    $result.descriptorValidation = Test-UtilitiesEtwProofDescriptor -Descriptor $descriptor -ExpectedProjectPath $ProjectPath -ExpectedProviderName $ProviderName -ExpectedProviderGuid $ProviderGuid.Guid -ExpectedUnitId $UnitId -InventoryRows $inventory.rows
    if (-not $result.descriptorValidation.Valid) { throw $result.descriptorValidation.Reason }
    $inventoryRow = @($inventory.rows | Where-Object { $_.projectPath -ceq $ProjectPath })[0]
    $result.projectPath = $ProjectPath
    $result.providerName = $ProviderName
    $result.providerGuid = $ProviderGuid.Guid
    $result.inventoryRowSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($inventoryRow | ConvertTo-Json -Depth 16 -Compress))))
    $result.artifactPath = $artifact.CanonicalPath
    $result.evidencePath = $EvidencePath
    $result.projectProof = Invoke-UtilitiesEtwProjectProof -ProjectPath $ProjectPath -Descriptor $descriptor -Artifact $artifact -EvidencePath $EvidencePath
    $result.commands = $result.projectProof.commands
    $result.artifactChecks = $result.projectProof.eventPipeValidation
    $result.productionProjectDisposition = 'VerifiedWoven'
    $result.terminalDisposition = 'VerifiedWoven'
    return 0
  }
  catch {
    $result.failure = $_.Exception.Message
    if ($_.Exception.Data.Contains('UtilitiesEtwCommands')) { $result.commands = @($_.Exception.Data['UtilitiesEtwCommands']) }
  }
  finally {
    New-Item -ItemType Directory -Path $EvidencePath -Force | Out-Null
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $EvidencePath 'result.json') -Encoding utf8
  }
  return 1
}

if ($MyInvocation.InvocationName -notin '.', '&') {
  if ([string]::IsNullOrWhiteSpace($ProjectPath) -or [string]::IsNullOrWhiteSpace($ProviderName) -or $ProviderGuid -eq [guid]::Empty -or [string]::IsNullOrWhiteSpace($UnitId) -or [string]::IsNullOrWhiteSpace($ArtifactsPath) -or [string]::IsNullOrWhiteSpace($EvidencePath)) {
    throw 'ProjectPath, ProviderName, ProviderGuid, UnitId, ArtifactsPath, and EvidencePath are required.'
  }
  exit (Invoke-UtilitiesEtwProofHarness @PSBoundParameters)
}