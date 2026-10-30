BeforeAll {
  $null = Get-Command -Name 'Write-PSFMessage' -ErrorAction Stop
  . (Join-Path $PSScriptRoot '../../private/ConvertTo-CoordCanonicalRequest.ps1')
  $script:canonicalUtf8 = [Text.UTF8Encoding]::new($false, $true)
  # These are hand-ordered oracle texts, not output from the product serializer.
  $script:claimCanonical = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Claim","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
  $script:claimDigest = '9bcbe221b756441e947bbcf1f42e1ba04c24e194e724ff0d649e390b9d0fbc61'
  $script:claimWire = '{"requestId":"R-Claim","scope":[{"registeredRootId":"utilities-sprint","path":"src\/Owned.ps1"}],"taskId":"17.23","holder":{"sessionId":"session-A","holderId":"Senior3"},"resourceId":"board-S17","protocolVersion":"Coordination-v1","sprintId":"0017","category":"Claim","predecessors":["P1","P2"],"payload":{},"generation":"epoch-A","expectedRevision":"head-A","authorizationReference":"grant-A"}'
  $script:unicodeCanonical = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"r\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\u0008\u0009\u000a\u000b\u000c\u000d\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f/\"\\é🚀","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
  $script:unicodeDigest = '10f11381c4d16af0db9a6b07ee65edeb6676cfee845f5fd5972f51288aa4ae62'

  function New-CanonicalEnvelopeBytes {
    param([string]$RequestText, [string]$Digest, [string]$Transport = '')
    $text = '{"request":' + $RequestText + ',"digest":"' + $Digest + '"'
    if ($Transport) { $text += ',"transport":' + $Transport }
    $text += '}'
    ,$script:canonicalUtf8.GetBytes($text)
  }
}

Describe 'ConvertTo-CoordCanonicalRequest strict S1 source slice' -Tag 'Unit' {
  BeforeEach {
    Mock Write-PSFMessage {}
  }

  It 'matches the independent literal <Category> canonical text and known SHA256' -ForEach @(
    @{ Category = 'Claim'; Canonical = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Claim","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'; KnownDigest = '9bcbe221b756441e947bbcf1f42e1ba04c24e194e724ff0d649e390b9d0fbc61' },
    @{ Category = 'ReportResult'; Canonical = '{"authorizationReference":"grant-A","category":"ReportResult","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{"claimId":"claim-A","evidence":[{"digest":{"algorithm":"SHA256","value":"proof"},"reference":"artifact-A"}],"outcome":"source-ready","statedLimits":"Source only."},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Report","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'; KnownDigest = '941c00e8eac264368764cfa36965f7c221530d5d87c7f275b51550599cd65438' },
    @{ Category = 'AcceptChange'; Canonical = '{"authorizationReference":"grant-A","category":"AcceptChange","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{"approvedChange":{"annotation":"Source ready","status":"open"},"evidence":[],"reportRequestId":"P1"},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Accept","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'; KnownDigest = '37d55b3f26189b852310fdaffaab6e9bbb1ab79969ad95a30d8af9ae27036733' },
    @{ Category = 'Release'; Canonical = '{"authorizationReference":"grant-A","category":"Release","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{"claimId":"claim-A","releaseReason":"Handed off"},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"R-Release","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'; KnownDigest = 'd333c981eb9e8d3e408a1d70cf40d768db1b2bcc95ddd9423ebfe1a788a9bbe2' }
  ) {
    $bytes = New-CanonicalEnvelopeBytes -RequestText $Canonical -Digest $KnownDigest
    $before = [Convert]::ToHexString($bytes)
    $results = @(ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length)

    $results.Count | Should -Be 1
    $result = $results[0]
    $result.Stage | Should -BeExactly 'CanonicalizedNotAdmitted'
    $result.Request.GetType().FullName | Should -BeExactly 'System.Text.Json.JsonElement'
    $script:canonicalUtf8.GetString($result.CanonicalBytes) | Should -BeExactly $Canonical
    $result.Digest | Should -BeExactly $KnownDigest
    $result.SchemaSha256 | Should -BeExactly '6266286dccf7a499ff332e0cc2384b7807eee477aecb9f9da4b7f45bfa261cde'
    # Independently check the literal oracle, not the canonicalizer's own output.
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:canonicalUtf8.GetBytes($Canonical))).ToLowerInvariant() |
      Should -BeExactly $KnownDigest
    [Convert]::ToHexString($bytes) | Should -BeExactly $before
    $result.CanonicalBytes[0] | Should -Be 0x7B
    $result.PSObject.Properties.Name | Should -Not -Contain 'Admitted'
    $result.Request.GetProperty('category').GetString() | Should -BeExactly $Category
    # Returned JsonElement must survive disposal of the internal document.
    $bytes[0] = 0x20
    $result.Request.GetProperty('taskId').GetString() | Should -BeExactly '17.23'
    $script:canonicalUtf8.GetString($result.CanonicalBytes) | Should -BeExactly $Canonical
  }

  It 'equates reordered objects, whitespace and optional slash/key escapes' {
    $wire = $script:claimWire.Replace('"authorizationReference"', '"authorizationRefer\u0065nce"')
    $envelope = '{ ' + [char]10 + '"digest":"' + $script:claimDigest + '", "request":' + $wire + ' }'
    $bytes = $script:canonicalUtf8.GetBytes($envelope)
    $result = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length
    $script:canonicalUtf8.GetString($result.CanonicalBytes) | Should -BeExactly $script:claimCanonical
    $result.Digest | Should -BeExactly $script:claimDigest
  }

  It 'excludes validated transport delivery observations from canonical bytes and digest' {
    foreach ($transport in @('{"deliveryId":"one"}', '{"receivedAt":"opaque-time","deliveryId":"two"}')) {
      $bytes = New-CanonicalEnvelopeBytes -RequestText $script:claimWire -Digest $script:claimDigest -Transport $transport
      $result = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length
      $result.Digest | Should -BeExactly $script:claimDigest
      $script:canonicalUtf8.GetString($result.CanonicalBytes) | Should -BeExactly $script:claimCanonical
      $transportValue = [Text.Json.JsonElement]::new()
      $result.Request.TryGetProperty('transport', [ref]$transportValue) | Should -BeFalse
    }
  }

  It 'emits literal Unicode and six-character lowercase escapes for every control character' {
    $wire = $script:unicodeCanonical.Replace('\u0008', '\b').Replace('\u0009', '\t').Replace('\u000a', '\n').Replace('\u000c', '\f').Replace('\u000d', '\r')
    $wire = $wire.Replace('/', '\/').Replace('é🚀', '\u00e9\ud83d\ude80')
    $bytes = New-CanonicalEnvelopeBytes -RequestText $wire -Digest $script:unicodeDigest
    $result = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length
    $script:canonicalUtf8.GetString($result.CanonicalBytes) | Should -BeExactly $script:unicodeCanonical
    $result.Digest | Should -BeExactly $script:unicodeDigest
  }

  It 'treats escaped backslash followed by u-surrogate text as literal characters' {
    $oracle = '{"authorizationReference":"grant-A","category":"Claim","expectedRevision":"head-A","generation":"epoch-A","holder":{"holderId":"Senior3","sessionId":"session-A"},"payload":{},"predecessors":["P1","P2"],"protocolVersion":"Coordination-v1","requestId":"literal\\ud800","resourceId":"board-S17","scope":[{"path":"src/Owned.ps1","registeredRootId":"utilities-sprint"}],"sprintId":"0017","taskId":"17.23"}'
    $knownHash = 'f9007809e1ab12efdf298f782f43fbb3b9f6214da888b945dc53cc7b03a889cb'
    $bytes = New-CanonicalEnvelopeBytes -RequestText $oracle -Digest $knownHash
    $result = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length
    $result.Digest | Should -BeExactly $knownHash
    $script:canonicalUtf8.GetString($result.CanonicalBytes) | Should -BeExactly $oracle
  }

  It 'rejects changed <Change> against the unchanged original digest' -ForEach @(
    @{ Change = 'array order'; Old = '["P1","P2"]'; New = '["P2","P1"]' },
    @{ Change = 'ID case'; Old = 'R-Claim'; New = 'r-claim' },
    @{ Change = 'scope path case'; Old = 'src/Owned.ps1'; New = 'src/owned.ps1' },
    @{ Change = 'scope path alias'; Old = 'src/Owned.ps1'; New = './src/Owned.ps1' },
    @{ Change = 'leading and trailing whitespace'; Old = 'grant-A'; New = ' grant-A ' },
    @{ Change = 'session'; Old = 'session-A'; New = 'session-B' },
    @{ Change = 'authorization'; Old = 'grant-A'; New = 'grant-B' }
  ) {
    $changed = $script:claimCanonical.Replace($Old, $New)
    $bytes = New-CanonicalEnvelopeBytes -RequestText $changed -Digest $script:claimDigest
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*DigestMismatch*'
  }

  It 'does not normalize Unicode scalar sequences' {
    $changed = $script:unicodeCanonical.Replace('é', 'e\u0301')
    $bytes = New-CanonicalEnvelopeBytes -RequestText $changed -Digest $script:unicodeDigest
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*DigestMismatch*'
  }

  It 'rejects duplicate decoded members in <Location>' -ForEach @(
    @{ Location = 'request' },
    @{ Location = 'escaped request name' },
    @{ Location = 'holder' },
    @{ Location = 'scope' },
    @{ Location = 'envelope' },
    @{ Location = 'transport' }
  ) {
    $request = $script:claimCanonical
    $transport = ''
    switch ($Location) {
      'request' { $request = $request.Replace('"requestId":', '"requestId":"R-Claim","requestId":') }
      'escaped request name' { $request = $request.Replace('"requestId":', '"request\u0049d":"R-Claim","requestId":') }
      'holder' { $request = $request.Replace('"holderId":"Senior3"', '"holderId":"Senior3","holder\u0049d":"Senior3"') }
      'scope' { $request = $request.Replace('"path":"src/Owned.ps1"', '"path":"src/Owned.ps1","p\u0061th":"src/Owned.ps1"') }
      'transport' { $transport = '{"deliveryId":"same","delivery\u0049d":"same"}' }
    }
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest -Transport $transport
    if ($Location -eq 'envelope') {
      $text = '{"request":' + $request + ',"request":' + $request + ',"digest":"' + $script:claimDigest + '"}'
      $bytes = $script:canonicalUtf8.GetBytes($text)
    }
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*DuplicateMember*'
  }

  It 'rejects malformed escaped Unicode <Escaped> before digest comparison' -ForEach @(
    @{ Escaped = '\ud800' },
    @{ Escaped = '\udc00' },
    @{ Escaped = '\ud800A' },
    @{ Escaped = '\ud800\u0041' },
    @{ Escaped = '\ud800\ud800' }
  ) {
    $request = $script:claimCanonical.Replace('R-Claim', $Escaped)
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest
    $failure = $null
    try { $null = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } catch { $failure = $_ }
    $failure | Should -Not -BeNullOrEmpty
    $failure.Exception.Message | Should -Match '\(Invalid(?:Unicode|Json)\)'
  }

  It 'rejects malformed UTF8 bytes without modifying the caller input' {
    [byte[]]$bytes = @(0xC3, 0x28)
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes 2 } |
      Should -Throw '*InvalidUtf8*'
    [Convert]::ToHexString($bytes) | Should -BeExactly 'C328'
  }

  It 'rejects JSON syntax extension <Syntax>' -ForEach @(
    @{ Syntax = 'comment' },
    @{ Syntax = 'trailing comma' },
    @{ Syntax = 'second root' },
    @{ Syntax = 'UTF8 BOM' },
    @{ Syntax = 'empty bytes' }
  ) {
    $bytes = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest $script:claimDigest
    $text = $script:canonicalUtf8.GetString($bytes)
    switch ($Syntax) {
      'comment' { $bytes = $script:canonicalUtf8.GetBytes('/*comment*/' + $text) }
      'trailing comma' { $bytes = $script:canonicalUtf8.GetBytes($text.Substring(0, $text.Length - 1) + ',}') }
      'second root' { $bytes = $script:canonicalUtf8.GetBytes($text + '{}') }
      'UTF8 BOM' { $bytes = [byte[]](@(0xEF, 0xBB, 0xBF) + $bytes) }
      'empty bytes' { $bytes = [byte[]]@() }
    }
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes ([Math]::Max(1, $bytes.Length)) } |
      Should -Throw '*InvalidJson*'
  }

  It 'rejects noninteger numeric lexeme <Number> before schema validation' -ForEach @(
    @{ Number = '1.0' }, @{ Number = '1e0' }, @{ Number = '-0.0' }, @{ Number = '1E1000' }
  ) {
    $request = $script:claimCanonical.Replace('"R-Claim"', $Number)
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*InvalidNumber*'
  }

  It 'does not admit integer token <Number> where v1 requires a string' -ForEach @(
    @{ Number = '0' }, @{ Number = '-0' }, @{ Number = '1234567890123456789012345678901234567890' }
  ) {
    $request = $script:claimCanonical.Replace('"R-Claim"', $Number)
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*SchemaInvalid*'
  }

  It 'rejects closed-schema violation <Violation> before digest comparison' -ForEach @(
    @{ Violation = 'unknown envelope property' },
    @{ Violation = 'unknown request property' },
    @{ Violation = 'unknown holder property' },
    @{ Violation = 'unknown scope property' },
    @{ Violation = 'unknown transport property' },
    @{ Violation = 'claim payload property' },
    @{ Violation = 'unknown version' },
    @{ Violation = 'case-wrong category' },
    @{ Violation = 'duplicate predecessor' }
  ) {
    $request = $script:claimCanonical
    $transport = ''
    switch ($Violation) {
      'unknown request property' { $request = $request.Replace('"payload":{}', '"payload":{},"extra":true') }
      'unknown holder property' { $request = $request.Replace('"holderId":"Senior3"', '"holderId":"Senior3","extra":"value"') }
      'unknown scope property' { $request = $request.Replace('"path":"src/Owned.ps1"', '"path":"src/Owned.ps1","extra":"value"') }
      'unknown transport property' { $transport = '{"extra":"value"}' }
      'claim payload property' { $request = $request.Replace('"payload":{}', '"payload":{"command":"anything"}') }
      'unknown version' { $request = $request.Replace('Coordination-v1', 'Coordination-v9') }
      'case-wrong category' { $request = $request.Replace('"Claim"', '"claim"') }
      'duplicate predecessor' { $request = $request.Replace('["P1","P2"]', '["P1","P1"]') }
    }
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest -Transport $transport
    if ($Violation -eq 'unknown envelope property') {
      $text = $script:canonicalUtf8.GetString($bytes)
      $bytes = $script:canonicalUtf8.GetBytes($text.Substring(0, $text.Length - 1) + ',"extra":true}')
    }
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*SchemaInvalid*'
  }

  It 'distinguishes optional transport absence from explicit null and rejects missing/null required inputs' {
    $validBytes = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest $script:claimDigest
    (ConvertTo-CoordCanonicalRequest -EnvelopeBytes $validBytes -MaxRequestBytes $validBytes.Length).Stage |
      Should -BeExactly 'CanonicalizedNotAdmitted'
    foreach ($request in @(
      $script:claimCanonical.Replace('"holder":{"holderId":"Senior3","sessionId":"session-A"}', '"holder":null'),
      $script:claimCanonical.Replace('"holder":{"holderId":"Senior3","sessionId":"session-A"},', '')
    )) {
      $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest
      { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
        Should -Throw '*SchemaInvalid*'
    }
    $nullTransport = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest $script:claimDigest -Transport 'null'
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $nullTransport -MaxRequestBytes $nullTransport.Length } |
      Should -Throw '*SchemaInvalid*'
  }

  It 'checks caller byte size at the exact boundary including multibyte Unicode' {
    $bytes = New-CanonicalEnvelopeBytes -RequestText $script:unicodeCanonical -Digest $script:unicodeDigest
    $characters = $script:canonicalUtf8.GetString($bytes).Length
    $bytes.Length | Should -BeGreaterThan $characters
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes ($bytes.Length - 1) } |
      Should -Throw '*SizeExceeded*'
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $characters } |
      Should -Throw '*SizeExceeded*'
    (ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length).Digest |
      Should -BeExactly $script:unicodeDigest
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes 0 } | Should -Throw
  }

  It 'rejects wrong or nonlowercase digest spelling' {
    $bytes = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest ('0' * 64)
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*DigestMismatch*'
    $bytes = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest $script:claimDigest.ToUpperInvariant()
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*SchemaInvalid*'
  }

  It 'does not mistake an existing shape vector dummy digest for a valid canonical request' {
    $vectorsPath = Join-Path $PSScriptRoot '../data/request-v1.vectors.json'
    $packet = Get-Content -LiteralPath $vectorsPath -Raw | ConvertFrom-Json
    $vector = $packet.vectors | Where-Object id -EQ 'shape-valid-Claim'
    $bytes = $script:canonicalUtf8.GetBytes($vector.json)
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } |
      Should -Throw '*DigestMismatch*'
  }

  It 'does not emit raw input in rejection errors or PSFramework log messages' {
    $request = $script:claimCanonical.Replace('R-Claim', 'DO-NOT-LOG-RAW')
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest $script:claimDigest
    $failure = $null
    try { $null = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length } catch { $failure = $_ }
    $failure.Exception.Message | Should -BeExactly 'Coordination request rejected (DigestMismatch).'
    $failure.Exception.InnerException | Should -BeNullOrEmpty
    Should -Invoke Write-PSFMessage -Exactly -Times 0 -ParameterFilter { $Message -like '*DO-NOT-LOG-RAW*' }
  }
}

Describe 'Canonical request deferred digest comparison for retry classification' -Tag 'Unit' {
  BeforeEach { Mock Write-PSFMessage {} }

  It 'keeps default strict output and only adds comparison evidence when explicitly deferred' {
    $bytes = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest $script:claimDigest
    $strict = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length
    $strict.PSObject.Properties.Name | Should -Not -Contain 'DigestMatches'
    $strict.PSObject.Properties.Name | Should -Not -Contain 'SuppliedDigest'
    $deferred = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -DeferDigestComparison
    $deferred.Stage | Should -BeExactly 'CanonicalizedNotAdmitted'
    $deferred.DigestMatches | Should -BeTrue
    $deferred.SuppliedDigest | Should -BeExactly $script:claimDigest
  }

  It 'retains computed bytes and mismatched supplied digest without accepting it' {
    $bytes = New-CanonicalEnvelopeBytes -RequestText $script:claimCanonical -Digest ('0' * 64)
    $deferred = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -DeferDigestComparison
    $deferred.DigestMatches | Should -BeFalse
    $deferred.SuppliedDigest | Should -BeExactly ('0' * 64)
    $deferred.Digest | Should -BeExactly $script:claimDigest
    $script:canonicalUtf8.GetString($deferred.CanonicalBytes) | Should -BeExactly $script:claimCanonical
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -DeferDigestComparison:$false } |
      Should -Throw '*DigestMismatch*'
  }

  It 'does not defer schema rejection' {
    $request = $script:claimCanonical.Replace('"payload":{}', '"payload":{"extra":"invalid"}')
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest ('0' * 64)
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -DeferDigestComparison } |
      Should -Throw '*SchemaInvalid*'
  }

  It 'does not defer strict duplicate-member rejection' {
    $request = $script:claimCanonical.Replace('"requestId":', '"requestId":"R-Claim","requestId":')
    $bytes = New-CanonicalEnvelopeBytes -RequestText $request -Digest ('0' * 64)
    { ConvertTo-CoordCanonicalRequest -EnvelopeBytes $bytes -MaxRequestBytes $bytes.Length -DeferDigestComparison } |
      Should -Throw '*DuplicateMember*'
  }
}
