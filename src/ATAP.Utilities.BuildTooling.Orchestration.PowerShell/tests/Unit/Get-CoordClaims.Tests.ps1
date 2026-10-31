#Requires -Version 7.4
BeforeAll {
  $script:claims436FixtureReady = $false
  $script:claims436MutationDetected = $false
  # Always isolate logging, even when the normal profile already loaded PSFramework.
  function Write-PSFMessage { param($FunctionName, $ModuleName, $Level, $Message) }
  . (Join-Path $PSScriptRoot '../../public/Get-CoordClaims.ps1')

  function Assert-ClaimsFixturePath([string] $Path) {
    if (-not [IO.Path]::IsPathFullyQualified($Path)) { throw 'UnsafeClaimsFixturePath' }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if (-not $full.StartsWith('D:\ATAPArtifacts\', [StringComparison]::OrdinalIgnoreCase)) {
      throw 'UnsafeClaimsFixturePath'
    }
    # Check existing ancestors before creating or recursively deleting anything.
    $cursor = $full
    while ($cursor) {
      if (Test-Path -LiteralPath $cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (-not $item.PSIsContainer -or $item.LinkType -or $item.Target) { throw 'UnsafeClaimsFixturePath' }
      }
      $parent = [IO.Path]::GetDirectoryName($cursor)
      if ($parent -eq $cursor) { break }
      $cursor = $parent
    }
    return $full
  }
  $base = $env:ARTIFACTS_PATH
  if ([string]::IsNullOrWhiteSpace($base)) { $base = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'User') }
  if ([string]::IsNullOrWhiteSpace($base) -or -not [IO.Path]::IsPathFullyQualified($base)) {
    throw 'Approved ARTIFACTS_PATH required'
  }
  if (-not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetFullPath($base).TrimEnd('\', '/'), 'D:\ATAPArtifacts')) {
    throw 'Approved ARTIFACTS_PATH required'
  }
  $script:claims436Fixture = Assert-ClaimsFixturePath (Join-Path $base ('Sprint0017/Task17.29.b/ClaimsTests436/Fixtures-' + [guid]::NewGuid().ToString('N')))
  if (Test-Path -LiteralPath $script:claims436Fixture) { throw 'Claims fixture must be fresh' }
  $null = [IO.Directory]::CreateDirectory($script:claims436Fixture)
  $script:claims436FixtureReady = $true
  $sentinel = Join-Path $script:claims436Fixture 'nested'
  $null = [IO.Directory]::CreateDirectory($sentinel)
  [IO.File]::WriteAllBytes((Join-Path $sentinel 'sentinel.bin'), [byte[]]@(0, 255, 13, 10))

  function Get-ClaimsFixtureSnapshot {
    $entries = [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal)
    $items = @((Get-Item -LiteralPath $script:claims436Fixture -Force -ErrorAction Stop)) +
      @(Get-ChildItem -LiteralPath $script:claims436Fixture -Recurse -Force -ErrorAction Stop)
    foreach ($item in $items) {
      # Enumeration can cache directory timestamps from fixture setup; query current metadata.
      $item.Refresh()
      if ($item.LinkType -or $item.Target) { throw 'UnsafeClaimsFixturePath' }
      $bytes = if ($item.PSIsContainer) { '' } else { [Convert]::ToBase64String([IO.File]::ReadAllBytes($item.FullName)) }
      $entries.Add($item.FullName, ($item.PSIsContainer.ToString() + '|' + $item.LastWriteTimeUtc.Ticks + '|' + $bytes))
    }
    return (ConvertTo-Json -InputObject @($entries.GetEnumerator() | ForEach-Object { @($_.Key, $_.Value) }) -Compress -Depth 4)
  }
  function Invoke-ClaimsSnapshot([string] $Path, [string] $ResourceId = 'R') {
    $before = Get-ClaimsFixtureSnapshot
    try { Get-CoordClaims -StatePath $Path -ResourceId $ResourceId }
    finally {
      try { $after = Get-ClaimsFixtureSnapshot }
      catch { $script:claims436MutationDetected = $true; throw }
      if (-not [StringComparer]::Ordinal.Equals($before, $after)) {
        $script:claims436MutationDetected = $true
        throw 'ClaimsFixtureMutated'
      }
    }
  }

  $digest = '0' * 64
  $manifest = '{"path":"D:\\fixture\\one","digest":"' + $digest + '"}'
  $reference = '{"reference":"fixture/ref","digest":"' + $digest + '"}'
  $script:stateTemplate = '{"schemaVersion":"Coordination-state-v1","resourceId":"R","lineageId":"L","registeredRoots":[{"registeredRootId":"root","path":"D:\\fixture"}],"generation":"G","committedRevision":"H","committedOutputManifest":{"markdown":' + $manifest + ',"boardHtml":' + $manifest + ',"proceduralDetailsHtml":' + $manifest + ',"accomplishedHtml":' + $manifest + '},"custodyEvidence":' + $reference + ',"compatibilityEvidence":' + $reference + ',"admissionEvidence":[' + $reference + '],"requests":[],"claims":@@CLAIMS@@,"reservations":@@RESERVATIONS@@,"preparedOperations":[],"commitReceipts":[],"mutationAdmission":{"status":"Admitted","reason":"fixture","observedOutputs":[]}}'
  $scope = '[{"registeredRootId":"root","path":"café/é.txt"}]'
  $script:claimA = '{"claimId":"A","resourceId":"R","taskId":"17.29.b","scope":' + $scope + ',"holder":{"holderId":"h","sessionId":"s"},"generation":"G","claimRequestId":"request"}'
  $script:claimLower = $script:claimA.Replace('"claimId":"A"','"claimId":"a"')
  $script:reservation = '{"reservationId":"Z","resourceId":"R","requestId":"request","taskId":"17.29.b","scope":' + $scope + ',"generation":"G"}'
  $script:claims436Schema = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../schemas/state-v1.schema.json'), [Text.UTF8Encoding]::new($false, $true))
  function Write-State([string] $Claims, [string] $Reservations) {
    $path = Join-Path $script:claims436Fixture 'state.json'
    [IO.File]::WriteAllText($path, $script:stateTemplate.Replace('@@CLAIMS@@', $Claims).Replace('@@RESERVATIONS@@', $Reservations), [Text.UTF8Encoding]::new($false))
    return $path
  }
}
AfterAll {
  if ((Get-Variable -Name claims436FixtureReady -Scope Script -ErrorAction SilentlyContinue) -and $script:claims436FixtureReady) {
    $cleanup = Assert-ClaimsFixturePath $script:claims436Fixture
    if (Test-Path -LiteralPath $cleanup) {
      foreach ($item in @(Get-ChildItem -LiteralPath $cleanup -Recurse -Force -ErrorAction Stop)) {
        if ($item.LinkType -or $item.Target) { throw 'UnsafeClaimsFixturePath' }
      }
      Remove-Item -LiteralPath $cleanup -Recurse -Force -ErrorAction Stop
    }
  }
}

Describe 'Get-CoordClaims local snapshot' -Tag 'Unit' {
BeforeEach {
  $script:claims436MutationDetected = $false
  Mock Write-PSFMessage {}
}
AfterEach {
  # Independent of Should -Throw: a no-write failure cannot count as the expected query refusal.
  $script:claims436MutationDetected | Should -BeFalse
}
  It 'returns empty raw arrays and recorded head without writes' {
    $path = Write-State '[]' '[]'
    $before = [IO.File]::ReadAllBytes($path)
    $result = Invoke-ClaimsSnapshot $path
    $result.ClaimCount | Should -Be 0
    $result.ReservationCount | Should -Be 0
    $result.Claims.GetRawText() | Should -BeExactly '[]'
    $result.Reservations.GetRawText() | Should -BeExactly '[]'
    $result.RecordedHead.generation | Should -BeExactly 'G'
    $result.StateSha256 | Should -BeExactly ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($before)).ToLowerInvariant())
  }
  It 'preserves ordinal case-distinct identities and raw JSON after cloning' {
    $claims = '[' + $script:claimA + ',' + $script:claimLower + ']'
    $reservations = '[' + $script:reservation + ',' + $script:reservation.Replace('"reservationId":"Z"', '"reservationId":"z"') + ']'
    $path = Write-State $claims $reservations
    $result = Invoke-ClaimsSnapshot $path
    $result.ClaimCount | Should -Be 2
    $result.ReservationCount | Should -Be 2
    $result.Claims.GetRawText() | Should -BeExactly $claims
    $result.Reservations.GetRawText() | Should -BeExactly $reservations
    $result.ResourceId = 'changed'
    (Invoke-ClaimsSnapshot $path).ResourceId | Should -BeExactly 'R'
  }
  It 'refuses schema-valid inconsistent snapshot: <Fault>' -ForEach @(
    @{ Fault = 'DuplicateClaim' }
    @{ Fault = 'ClaimResource' }
    @{ Fault = 'DuplicateReservation' }
    @{ Fault = 'ReservationResource' }
  ) {
    $claims = '[]'; $reservations = '[]'
    switch ($Fault) {
      'DuplicateClaim' { $claims = '[' + $script:claimA + ',' + $script:claimA + ']' }
      'ClaimResource' { $claims = '[' + $script:claimA.Replace('"resourceId":"R"', '"resourceId":"other"') + ']' }
      'DuplicateReservation' { $reservations = '[' + $script:reservation + ',' + $script:reservation + ']' }
      'ReservationResource' { $reservations = '[' + $script:reservation.Replace('"resourceId":"R"', '"resourceId":"other"') + ']' }
    }
    $path = Write-State $claims $reservations
    Test-Json -Json ([IO.File]::ReadAllText($path)) -Schema $script:claims436Schema -ErrorAction Stop | Should -BeTrue
    { Invoke-ClaimsSnapshot $path } | Should -Throw '*Get-CoordClaims: InconsistentSnapshot*'
  }
  It 'refuses ordinal resource mismatch without writes' {
    $path = Write-State '[]' '[]'
    { Invoke-ClaimsSnapshot $path 'r' } | Should -Throw '*Get-CoordClaims: ResourceMismatch*'
  }
  It 'refuses invalid state without writes: <Fault>' -ForEach @(
    @{ Fault = 'DuplicateDecodedKey' }
    @{ Fault = 'UnpairedHighScalar' }
    @{ Fault = 'UnpairedLowScalar' }
    @{ Fault = 'MalformedSyntax' }
    @{ Fault = 'UnsupportedSchemaVersion' }
    @{ Fault = 'InvalidUtf8' }
  ) {
    $path = Write-State '[]' '[]'
    $valid = [IO.File]::ReadAllText($path)
    Test-Json -Json $valid -Schema $script:claims436Schema -ErrorAction Stop | Should -BeTrue
    $invalid = switch ($Fault) {
      'DuplicateDecodedKey' {
        $duplicate = '"resourceId":"R","resour\u0063eId":"R"'
        $text = $valid.Replace('"resourceId":"R"', $duplicate)
        [StringComparer]::Ordinal.Equals($text.Replace($duplicate, '"resourceId":"R"'), $valid) | Should -BeTrue
        $document = [Text.Json.JsonDocument]::Parse($text)
        try {
          $properties = @($document.RootElement.EnumerateObject() | Where-Object { [StringComparer]::Ordinal.Equals($_.Name, 'resourceId') })
          $properties.Count | Should -Be 2
          foreach ($property in $properties) { $property.Value.GetString() | Should -BeExactly 'R' }
        } finally { $document.Dispose() }
        $text
      }
      'UnpairedHighScalar' { $valid.Replace('"lineageId":"L"', '"lineageId":"\uD800"') }
      'UnpairedLowScalar' { $valid.Replace('"lineageId":"L"', '"lineageId":"\uDC00"') }
      'MalformedSyntax' { $valid.Substring(0, $valid.Length - 1) }
      'UnsupportedSchemaVersion' { $valid.Replace('"schemaVersion":"Coordination-state-v1"', '"schemaVersion":"Coordination-state-v999"') }
      'InvalidUtf8' { $null }
    }
    if ($Fault -eq 'InvalidUtf8') { [IO.File]::WriteAllBytes($path, [byte[]]@(0xFF)) }
    else { [IO.File]::WriteAllText($path, $invalid, [Text.UTF8Encoding]::new($false)) }
    { Invoke-ClaimsSnapshot $path } | Should -Throw '*Get-CoordClaims: InvalidState*'
  }
  It 'refuses a missing state without initializing files or directories' {
    $path = Join-Path $script:claims436Fixture 'missing.json'
    Test-Path -LiteralPath $path | Should -BeFalse
    { Invoke-ClaimsSnapshot $path } | Should -Throw '*Get-CoordClaims: UnavailableState*'
    Test-Path -LiteralPath $path | Should -BeFalse
  }
}
