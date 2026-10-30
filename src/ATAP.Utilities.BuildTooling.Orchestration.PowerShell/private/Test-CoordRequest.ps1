function Test-CoordRequest {
  <#
  .SYNOPSIS
    Classifies retained retries under S3 orders 2-4 without admitting new work.
  .DESCRIPTION
    Caller MUST already establish registered-resource submit/result-read permission
    and authentic validated state provenance. This helper authenticates neither.
    RetainedRecords is a JsonElement array of state.requests records, not full state.

    Incoming resourceId must equal ExpectedResourceId ordinally before records are
    inspected. Current-root record shape, originalRequestJson/request/digest and
    terminal identity/status bindings are checked. Corrupt, duplicate or unsupported
    historical Rejected requests hold with NeedsRecovery, never New or replay.

    Existing key/different bytes wins IdentityConflict before supplied DigestMismatch.
    Same bytes/bad digest returns DigestMismatch. Same bytes/valid digest returns
    the unchanged independently cloned retained record/status, without new epoch,
    revision or authority checks. New keys always need further validation; deferred
    CanonicalRequest.DigestMatches is preserved for the later order5 validator.
    This submission shortcut MUST NOT bypass a scheduler's revalidation.

    Caller already bounded/authenticated the state snapshot. Retained original JSON
    can have older formatting/size, so its derived envelopes use exact byte length
    for internal canonicalization, not the incoming limit or a new production quota.
  .PARAMETER EnvelopeBytes
    Incoming UTF8 envelope bytes.
  .PARAMETER MaxRequestBytes
    Positive caller-supplied incoming byte limit.
  .PARAMETER ExpectedResourceId
    Exact registered resource identity already authorized by the caller.
  .PARAMETER RetainedRecords
    Caller-validated JsonElement array. Foreign-resource entries are never disclosed.
  .OUTPUTS
    PSCustomObject: Stage=RetryClassifiedNotAdmitted, Decision, Reason,
    CanonicalRequest, RetainedStatus and RetainedRecord. Retained fields are nonnull
    only for an intact same-byte/valid-digest retry. Decisions are local, not wire
    admission/durable outcomes. No queue, grant, revision, custody or board changes.
  .EXAMPLE
    Test-CoordRequest -EnvelopeBytes $bytes -MaxRequestBytes $limit -ExpectedResourceId $resourceId -RetainedRecords $records
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [AllowEmptyCollection()]
    [byte[]]$EnvelopeBytes,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9223372036854775807)]
    [long]$MaxRequestBytes,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedResourceId,

    [Parameter(Mandatory)]
    [System.Text.Json.JsonElement]$RetainedRecords
  )

  begin {
    $fn = 'Test-CoordRequest'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    foreach ($required in @('Write-PSFMessage', 'Test-Json', 'ConvertFrom-Json', 'ConvertTo-Json')) {
      $null = Get-Command -Name $required -ErrorAction Stop
    }
    if (-not (Get-Command -Name 'ConvertTo-CoordCanonicalRequest' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'ConvertTo-CoordCanonicalRequest.ps1')
    }
    $null = Get-Command -Name 'ConvertTo-CoordCanonicalRequest' -ErrorAction Stop
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Classifying retry without admission'
  }

  process {
    $result = [PSCustomObject]@{
      Stage = 'RetryClassifiedNotAdmitted'
      Decision = 'InvalidRequest'
      Reason = 'EnvelopeNotCanonicalizable'
      CanonicalRequest = $null
      RetainedStatus = $null
      RetainedRecord = $null
    }
    try {
      $incoming = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $EnvelopeBytes -MaxRequestBytes $MaxRequestBytes -DeferDigestComparison
    } catch {
      return $result
    }
    $result.CanonicalRequest = $incoming
    $resourceId = $incoming.Request.GetProperty('resourceId').GetString()
    $requestId = $incoming.Request.GetProperty('requestId').GetString()
    if (-not [string]::Equals($resourceId, $ExpectedResourceId, [StringComparison]::Ordinal)) {
      $result.Decision = 'ResourceMismatch'
      $result.Reason = 'IncomingResourceDoesNotMatchExpected'
      return $result
    }

    $holdReason = 'RetainedStateInvalid'
    try {
      if ($RetainedRecords.ValueKind -ne [Text.Json.JsonValueKind]::Array) { throw 'Records array required.' }
      $snapshot = $RetainedRecords.Clone()
      $schemaPath = Join-Path $PSScriptRoot '../schemas/state-v1.schema.json'
      if ($null -ne $MyInvocation.MyCommand.Module -and $MyInvocation.MyCommand.Module.Name -ceq $mn) {
        $schemaPath = Join-Path $MyInvocation.MyCommand.Module.ModuleBase 'schemas/state-v1.schema.json'
      }
      $schemaBytes = [IO.File]::ReadAllBytes($schemaPath)
      if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($schemaBytes)) -cne '4F148321844E3F2970C7190D79FB4371E609A62BEF093E43A7ADB855C9BB9BFA') {
        throw 'Accepted state schema unavailable.'
      }
      $stateSchema = $utf8.GetString($schemaBytes) | ConvertFrom-Json -AsHashtable -ErrorAction Stop
      $projection = [ordered]@{
        '$schema' = $stateSchema['$schema']
        '$ref' = '#/definitions/stateRequestRecord'
        definitions = $stateSchema.definitions
      } | ConvertTo-Json -Depth 100 -Compress
      $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $matchedRecord = $null
      $matchedBytes = $null

      foreach ($record in $snapshot.EnumerateArray()) {
        if ($record.ValueKind -ne [Text.Json.JsonValueKind]::Object) { throw 'Record object required.' }
        # Detect ambiguous identities before selecting even a foreign namespace.
        $pending = [Collections.Generic.Stack[Text.Json.JsonElement]]::new()
        $pending.Push($record)
        while ($pending.Count -gt 0) {
          $node = $pending.Pop()
          if ($node.ValueKind -eq [Text.Json.JsonValueKind]::Object) {
            $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($property in $node.EnumerateObject()) {
              if (-not $names.Add($property.Name)) { throw 'Ambiguous record member.' }
              $pending.Push($property.Value)
            }
          } elseif ($node.ValueKind -eq [Text.Json.JsonValueKind]::Array) {
            foreach ($item in $node.EnumerateArray()) { $pending.Push($item) }
          }
        }
        $recordRequest = $record.GetProperty('request')
        $recordResource = $recordRequest.GetProperty('resourceId').GetString()
        if ([string]::IsNullOrEmpty($recordResource)) { throw 'Record resource required.' }
        if (-not [string]::Equals($recordResource, $ExpectedResourceId, [StringComparison]::Ordinal)) { continue }
        $recordId = $recordRequest.GetProperty('requestId').GetString()
        if ([string]::IsNullOrEmpty($recordId) -or -not $ids.Add($recordId)) { throw 'Invalid or duplicate retained identity.' }
        $shapeErrors = @()
        $shapeValid = Test-Json -Json $record.GetRawText() -Schema $projection -ErrorAction SilentlyContinue -ErrorVariable shapeErrors
        if ($shapeValid -ne $true -or $shapeErrors.Count -gt 0) { throw 'Retained record shape invalid.' }

        $holdReason = 'RetainedRequestUnsupportedOrCorrupt'
        $digestJson = $record.GetProperty('digest').GetRawText()
        $originalText = $record.GetProperty('originalRequestJson').GetString()
        # Original text must be exactly one object; wrapping must not absorb trailing envelope members.
        $originalDocument = [Text.Json.JsonDocument]::Parse($originalText, [Text.Json.JsonDocumentOptions]::new())
        try {
          if ($originalDocument.RootElement.ValueKind -ne [Text.Json.JsonValueKind]::Object) { throw 'Original request object required.' }
        } finally { $originalDocument.Dispose() }
        $originalEnvelope = $utf8.GetBytes('{"request":' + $originalText + ',"digest":' + $digestJson + '}')
        $storedEnvelope = $utf8.GetBytes('{"request":' + $recordRequest.GetRawText() + ',"digest":' + $digestJson + '}')
        $original = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $originalEnvelope -MaxRequestBytes $originalEnvelope.LongLength
        $stored = ConvertTo-CoordCanonicalRequest -EnvelopeBytes $storedEnvelope -MaxRequestBytes $storedEnvelope.LongLength
        $holdReason = 'RetainedRequestCorrespondenceInvalid'
        if ([Convert]::ToHexString($original.CanonicalBytes) -cne [Convert]::ToHexString($stored.CanonicalBytes)) {
          throw 'Retained request representations differ.'
        }
        $status = $record.GetProperty('status').GetString()
        if ($status -ceq 'Applied' -or $status -ceq 'Rejected') {
          $terminal = $record.GetProperty('terminalEvidence')
          if (-not [string]::Equals($terminal.GetProperty('resourceId').GetString(), $recordResource, [StringComparison]::Ordinal) -or
              -not [string]::Equals($terminal.GetProperty('requestId').GetString(), $recordId, [StringComparison]::Ordinal) -or
              $terminal.GetProperty('digest').GetString() -cne $original.Digest -or
              $terminal.GetProperty('status').GetString() -cne $status) {
            throw 'Retained terminal evidence correspondence invalid.'
          }
        }
        if ([string]::Equals($recordId, $requestId, [StringComparison]::Ordinal)) {
          $matchedRecord = $record
          $matchedBytes = $original.CanonicalBytes
        }
        $holdReason = 'RetainedStateInvalid'
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Retained retry snapshot requires recovery'
      $result.Decision = 'NeedsRecovery'
      $result.Reason = $holdReason
      return $result
    }

    if ($null -eq $matchedRecord) {
      $result.Decision = 'NewRequestNeedsFurtherValidation'
      $result.Reason = 'NoRetainedIdentity'
    } elseif ([Convert]::ToHexString($matchedBytes) -cne [Convert]::ToHexString($incoming.CanonicalBytes)) {
      $result.Decision = 'IdentityConflict'
      $result.Reason = 'ExistingIdentityCanonicalBytesDiffer'
    } elseif (-not $incoming.DigestMatches) {
      $result.Decision = 'DigestMismatch'
      $result.Reason = 'ExistingIdentitySuppliedDigestMismatch'
    } else {
      $result.Decision = 'Retained'
      $result.Reason = 'ExistingIdentityCanonicalBytesAndDigestMatch'
      $result.RetainedStatus = $matchedRecord.GetProperty('status').GetString()
      $result.RetainedRecord = $matchedRecord.Clone()
    }
    $result
  }

  end {}
}
