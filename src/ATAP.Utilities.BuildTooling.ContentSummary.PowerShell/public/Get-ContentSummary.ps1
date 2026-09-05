function Get-ContentSummary {
  <#
  .SYNOPSIS
    Retrieves authorized ContentSummary items from the local AceOutpost service.
  .DESCRIPTION
    Sends a JSON query to the configured AceOutpost gather-content endpoint. The function
    accepts only HTTPS loopback endpoints, uses ambient Windows authentication, validates
    the entire response before returning any item, performs no SQL access, and records
    each actual invocation through Write-GatherCallRecord.
  .PARAMETER Tags
    One or more exact retrieval tags.
  .PARAMETER Depth
    Retrieval traversal depth.
  .PARAMETER Width
    Maximum retrieval width at each depth.
  .PARAMETER Instance
    Named ContentSummary data instance.
  .PARAMETER Scheme
    Endpoint scheme. Only https is permitted.
  .PARAMETER HostName
    Endpoint host. Only localhost, 127.0.0.1, or ::1 is permitted.
  .PARAMETER Port
    Endpoint port in the ratified 50000 through 50099 range. There is no compiled default.
  .PARAMETER Path
    Absolute endpoint resource path without query or fragment.
  .PARAMETER AgentName
    Logical caller identity recorded with the gather invocation.
  .PARAMETER WorktreeRoot
    Calling repository root recorded with the gather invocation. When omitted it is resolved
    with Get-RepositoryRoot from the current location.
  .PARAMETER TaskId
    Optional sprint task identity written to the gather-call record.
  .PARAMETER Prompt
    Optional caller prompt written only through the recorder's redaction boundary.
  .OUTPUTS
    PSCustomObject with agent, status, query, items, truncated, and error members.
  .EXAMPLE
    Get-ContentSummary -Tags @('schema', 'migration') -Port 50041
  .NOTES
    Certificate validation is mandatory and is never bypassed. Redirects and proxies are disabled.
    Windows Integrated Authentication uses the current identity; no explicit credential or secret
    is resolved by this function. Connection and supported operation timeouts are 30 seconds.
  .LINK
    Write-GatherCallRecord
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Tags,

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Depth = 3,

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Width = 2,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Instance = 'production',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Scheme,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$HostName,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AgentName = 'gather-content-summary',

    [Parameter()]
    [string]$WorktreeRoot,

    [Parameter()]
    [string]$TaskId,

    [Parameter()]
    [AllowEmptyString()]
    [string]$Prompt = ''
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'

    $callerBoundParameters = @{} + $PSBoundParameters
    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $sourceRoot = Split-Path -Path $moduleRoot -Parent

    if (-not (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)) {
      Import-Module -Name 'ATAP.Utilities.Powershell' -MinimumVersion '0.2.1' -ErrorAction SilentlyContinue
    }
    if (-not (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue)) {
      $getPValSource = Join-Path $sourceRoot 'ATAP.Utilities.PowerShell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      if (Test-Path -LiteralPath $getPValSource -PathType Leaf) { . $getPValSource }
    }

    if (-not (Get-Command -Name 'Get-RepositoryRoot' -ErrorAction SilentlyContinue)) {
      Import-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -MinimumVersion '0.1.10' -ErrorAction SilentlyContinue
    }
    if (-not (Get-Command -Name 'Get-RepositoryRoot' -ErrorAction SilentlyContinue)) {
      $repositoryRootSource = Join-Path $sourceRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell\public\Get-RepositoryRoot.ps1'
      if (Test-Path -LiteralPath $repositoryRootSource -PathType Leaf) { . $repositoryRootSource }
    }

    if (-not (Get-Command -Name 'Write-GatherCallRecord' -ErrorAction SilentlyContinue)) {
      Import-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -MinimumVersion '0.1.34' -ErrorAction SilentlyContinue
    }
    if (-not (Get-Command -Name 'Write-GatherCallRecord' -ErrorAction SilentlyContinue)) {
      $recorderModuleSource = Join-Path $sourceRoot 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell\ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell.psm1'
      if (Test-Path -LiteralPath $recorderModuleSource -PathType Leaf) {
        Import-Module -Name $recorderModuleSource -Force -ErrorAction Stop
      }
    }

    foreach ($requiredCommand in @('Get-PVal', 'Get-RepositoryRoot', 'Write-GatherCallRecord')) {
      if (-not (Get-Command -Name $requiredCommand -ErrorAction SilentlyContinue)) {
        $message = "Required command '$requiredCommand' is unavailable from installed modules and source fallback."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
        throw $message
      }
    }

    $getMember = {
      param([AllowNull()][object]$InputObject, [Parameter(Mandatory)][string]$Name)
      if ($null -eq $InputObject) { return $null }
      if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
          $value = $InputObject[$Name]
          if ($value -is [System.Collections.IEnumerable] -and
            $value -isnot [string] -and $value -isnot [System.Collections.IDictionary]) {
            return , $value
          }
          return $value
        }
        return $null
      }
      $property = $InputObject.PSObject.Properties[$Name]
      if ($null -ne $property) {
        $value = $property.Value
        if ($value -is [System.Collections.IEnumerable] -and
          $value -isnot [string] -and $value -isnot [System.Collections.IDictionary]) {
          return , $value
        }
        return $value
      }
      $null
    }

    $hasMember = {
      param([AllowNull()][object]$InputObject, [Parameter(Mandatory)][string]$Name)
      if ($null -eq $InputObject) { return $false }
      if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject.Contains($Name) }
      $null -ne $InputObject.PSObject.Properties[$Name]
    }

    $newEnvelope = {
      param(
        [string]$Status,
        [object]$Query,
        [object[]]$Items,
        [bool]$Truncated,
        [AllowNull()][object]$ErrorValue
      )
      [pscustomobject][ordered]@{
        agent = $AgentName
        status = $Status
        query = $Query
        items = @($Items)
        truncated = $Truncated
        error = $ErrorValue
      }
    }

    $newError = {
      param(
        [Parameter(Mandatory)][string]$Code,
        [AllowNull()][string]$CorrelationId,
        [Parameter(Mandatory)][string]$Message,
        [AllowNull()][Nullable[int]]$HttpStatus
      )
      [pscustomobject][ordered]@{
        code = $Code
        correlationId = if ([string]::IsNullOrWhiteSpace($CorrelationId)) { $null } else { $CorrelationId }
        message = $Message
        httpStatus = if ($null -eq $HttpStatus) { $null } else { [int]$HttpStatus }
      }
    }

    $isInteger = {
      param([AllowNull()][object]$Value)
      $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64]
    }

    $isSafeText = {
      param([AllowNull()][object]$Value, [int]$MaximumLength = 4096)
      if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $false }
      $text = [string]$Value
      $text.Length -le $MaximumLength -and
        $text.IndexOf([char]0) -lt 0 -and
        $text -notmatch '(?i)ATAP_SECRET_CANARY'
    }

    $convertQuery = {
      param([AllowNull()][object]$ResponseQuery)
      if ($null -eq $ResponseQuery -or
        (@($ResponseQuery.PSObject.Properties.Name) -join ',') -ne 'tags,depth,width,instance') {
        throw 'The response query shape is invalid.'
      }

      $responseTagsValue = & $getMember $ResponseQuery 'tags'
      if ($null -eq $responseTagsValue -or $responseTagsValue -is [string]) {
        throw 'The response query tags are invalid.'
      }
      $responseTags = @($responseTagsValue)
      $expectedTags = @($Tags | ForEach-Object { $_.Trim() })
      if ($responseTags.Count -ne $expectedTags.Count) { throw 'The response query tags do not match.' }
      for ($tagIndex = 0; $tagIndex -lt $responseTags.Count; $tagIndex++) {
        if ($responseTags[$tagIndex] -isnot [string] -or
          -not [string]::Equals([string]$responseTags[$tagIndex], $expectedTags[$tagIndex], [StringComparison]::Ordinal)) {
          throw 'The response query tags do not match.'
        }
      }

      $responseDepth = & $getMember $ResponseQuery 'depth'
      $responseWidth = & $getMember $ResponseQuery 'width'
      $responseInstance = & $getMember $ResponseQuery 'instance'
      if (-not (& $isInteger $responseDepth) -or [int64]$responseDepth -ne $Depth) {
        throw 'The response query depth does not match.'
      }
      if (-not (& $isInteger $responseWidth) -or [int64]$responseWidth -ne $Width) {
        throw 'The response query width does not match.'
      }
      if ($responseInstance -isnot [string] -or
        -not [string]::Equals([string]$responseInstance, $Instance.Trim(), [StringComparison]::Ordinal)) {
        throw 'The response query instance does not match.'
      }

      [pscustomobject][ordered]@{
        tags = [string[]]$responseTags
        depth = [int]$responseDepth
        width = [int]$responseWidth
        instance = [string]$responseInstance
      }
    }

    $convertItems = {
      param([AllowNull()][object]$ResponseItems)
      if ($null -eq $ResponseItems -or $ResponseItems -isnot [System.Collections.IEnumerable] -or
        $ResponseItems -is [string] -or
        $ResponseItems -is [System.Collections.IDictionary]) {
        throw 'The response items collection is invalid.'
      }

      $converted = [System.Collections.Generic.List[object]]::new()
      foreach ($item in @($ResponseItems)) {
        if ($null -eq $item) { throw 'A response item is null.' }
        foreach ($name in @(
            'itemId', 'sourceKind', 'sourceReference', 'text', 'matchedTags',
            'rankingContract', 'rank', 'assertedAtUtc', 'recordedAtUtc', 'producerId', 'contentHash'
          )) {
          if (-not (& $hasMember $item $name)) { throw "A response item is missing '$name'." }
        }

        $itemIdText = [string](& $getMember $item 'itemId')
        $producerIdText = [string](& $getMember $item 'producerId')
        $itemId = [guid]::Empty
        $producerId = [guid]::Empty
        if (-not [guid]::TryParse($itemIdText, [ref]$itemId) -or $itemId -eq [guid]::Empty) {
          throw 'A response item has an invalid itemId.'
        }
        if (-not [guid]::TryParse($producerIdText, [ref]$producerId) -or $producerId -eq [guid]::Empty) {
          throw 'A response item has an invalid producerId.'
        }

        $sourceKind = & $getMember $item 'sourceKind'
        $sourceReference = & $getMember $item 'sourceReference'
        $itemText = & $getMember $item 'text'
        $rankingContract = & $getMember $item 'rankingContract'
        $contentHash = & $getMember $item 'contentHash'
        if (-not (& $isSafeText $sourceKind 64)) { throw 'A response item has an invalid sourceKind.' }
        if (-not (& $isSafeText $sourceReference 4096)) { throw 'A response item has an invalid sourceReference.' }
        if (-not (& $isSafeText $itemText 65536)) { throw 'A response item has invalid text.' }
        if ($rankingContract -isnot [string] -or [string]$rankingContract -ne 'content-summary-rank-v1') {
          throw 'A response item has an unsupported rankingContract.'
        }
        if ($contentHash -isnot [string] -or [string]$contentHash -cnotmatch '^[0-9a-f]{64}$') {
          throw 'A response item has an invalid contentHash.'
        }

        $matchedTagsValue = & $getMember $item 'matchedTags'
        if ($null -eq $matchedTagsValue -or $matchedTagsValue -is [string]) {
          throw 'A response item has invalid matchedTags.'
        }
        $matchedTags = @($matchedTagsValue)
        if ($matchedTags.Count -lt 1) { throw 'A response item has no matchedTags.' }
        foreach ($matchedTag in $matchedTags) {
          if (-not (& $isSafeText $matchedTag 256)) { throw 'A response item has an invalid matched tag.' }
        }

        $rank = & $getMember $item 'rank'
        if (-not (& $isInteger $rank) -or [int64]$rank -lt 1 -or [int64]$rank -gt [int]::MaxValue) {
          throw 'A response item has an invalid rank.'
        }
        $assertedAtValue = & $getMember $item 'assertedAtUtc'
        $recordedAtValue = & $getMember $item 'recordedAtUtc'
        $assertedAt = [datetimeoffset]::MinValue
        $recordedAt = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse([string]$assertedAtValue, [ref]$assertedAt)) {
          throw 'A response item has an invalid assertedAtUtc.'
        }
        if (-not [datetimeoffset]::TryParse([string]$recordedAtValue, [ref]$recordedAt)) {
          throw 'A response item has an invalid recordedAtUtc.'
        }

        $converted.Add([pscustomobject][ordered]@{
            itemId = $itemIdText
            sourceKind = [string]$sourceKind
            sourceReference = [string]$sourceReference
            text = [string]$itemText
            matchedTags = [string[]]$matchedTags
            rankingContract = [string]$rankingContract
            rank = [int]$rank
            assertedAtUtc = [string]$assertedAtValue
            recordedAtUtc = [string]$recordedAtValue
            producerId = $producerIdText
            contentHash = [string]$contentHash
          })
      }
      , $converted.ToArray()
    }

    $convertResponse = {
      param([AllowNull()][object]$ResponseValue, [AllowNull()][Nullable[int]]$ObservedHttpStatus)
      if ($null -eq $ResponseValue) { throw 'The AceOutpost response is null.' }
      foreach ($name in @('agent', 'status', 'query', 'items', 'truncated', 'error')) {
        if (-not (& $hasMember $ResponseValue $name)) { throw "The AceOutpost response is missing '$name'." }
      }

      $responseAgent = & $getMember $ResponseValue 'agent'
      $responseStatus = & $getMember $ResponseValue 'status'
      if ($responseAgent -isnot [string] -or [string]$responseAgent -ne 'gather-content-summary') {
        throw 'The AceOutpost response agent is invalid.'
      }
      if ($responseStatus -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$responseStatus)) {
        throw 'The AceOutpost response status is invalid.'
      }

      $responseQuery = & $convertQuery (& $getMember $ResponseValue 'query')
      $itemsValue = & $getMember $ResponseValue 'items'
      $truncatedValue = & $getMember $ResponseValue 'truncated'
      if ($truncatedValue -isnot [bool]) { throw 'The AceOutpost response truncated value is invalid.' }
      $stubValue = if (& $hasMember $ResponseValue 'stub') { & $getMember $ResponseValue 'stub' } else { $null }
      $serverError = & $getMember $ResponseValue 'error'
      $normalizedStatus = ([string]$responseStatus).Trim()

      if ($normalizedStatus -in @('Success', 'success', 'ok')) {
        if ($null -ne $ObservedHttpStatus -and [int]$ObservedHttpStatus -ne 200) {
          throw 'The AceOutpost success response has an incompatible HTTP status.'
        }
        if ($null -ne $stubValue -or $null -ne $serverError) {
          throw 'A successful AceOutpost response contains stub or error data.'
        }
        $validatedItems = & $convertItems $itemsValue
        $publicEnvelope = & $newEnvelope 'ok' $responseQuery $validatedItems ([bool]$truncatedValue) $null
        return [pscustomobject]@{
          PublicEnvelope = $publicEnvelope
          RecordEnvelope = $publicEnvelope
          ErrorMessage = $null
        }
      }

      if ($normalizedStatus -eq 'NotImplemented' -or $null -ne $stubValue) {
        if ($null -ne $ObservedHttpStatus -and [int]$ObservedHttpStatus -ne 200) {
          throw 'The AceOutpost stub response has an incompatible HTTP status.'
        }
        if ($null -eq $stubValue -or $null -ne $serverError -or
          @($itemsValue).Count -ne 0 -or [bool]$truncatedValue) {
          throw 'The AceOutpost stub response is inconsistent.'
        }
        foreach ($name in @('marker', 'blockedBy', 'reason')) {
          if (-not (& $hasMember $stubValue $name)) { throw "The AceOutpost stub is missing '$name'." }
        }
        $marker = & $getMember $stubValue 'marker'
        $blockedByValue = & $getMember $stubValue 'blockedBy'
        $reason = & $getMember $stubValue 'reason'
        if ($marker -isnot [string] -or [string]$marker -ne 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED') {
          throw 'The AceOutpost stub marker is invalid.'
        }
        if ($null -eq $blockedByValue -or $blockedByValue -is [string]) {
          throw 'The AceOutpost stub blocker collection is invalid.'
        }
        $blockedBy = @($blockedByValue)
        if ($blockedBy.Count -lt 1) { throw 'The AceOutpost stub blocker collection is empty.' }
        foreach ($blocker in $blockedBy) {
          if (-not (& $isSafeText $blocker 256)) { throw 'The AceOutpost stub contains an invalid blocker.' }
        }
        if (-not (& $isSafeText $reason 1024)) { throw 'The AceOutpost stub reason is invalid.' }

        $stubError = [pscustomobject][ordered]@{
          code = [string]$marker
          correlationId = $null
          message = [string]$reason
          httpStatus = if ($null -eq $ObservedHttpStatus) { $null } else { [int]$ObservedHttpStatus }
          marker = [string]$marker
          blockedBy = [string[]]$blockedBy
          reason = [string]$reason
        }
        $publicEnvelope = & $newEnvelope 'NotImplemented' $responseQuery @() $false $stubError
        $recordEnvelope = [pscustomobject][ordered]@{
          agent = $AgentName
          status = 'NotImplemented'
          stub = [pscustomobject][ordered]@{
            marker = [string]$marker
            blockedBy = [string[]]$blockedBy
            reason = [string]$reason
          }
          query = $responseQuery
          items = @()
          truncated = $false
          error = $null
        }
        return [pscustomobject]@{
          PublicEnvelope = $publicEnvelope
          RecordEnvelope = $recordEnvelope
          ErrorMessage = $null
        }
      }

      if ($normalizedStatus -notin @('InvalidRequest', 'Forbidden', 'Conflict', 'Failed', 'Error') -or
        $null -eq $ObservedHttpStatus -or [int]$ObservedHttpStatus -eq 200) {
        throw 'The AceOutpost error response status is invalid.'
      }
      if ($null -eq $serverError -or @($itemsValue).Count -ne 0 -or [bool]$truncatedValue) {
        throw 'The AceOutpost error response is inconsistent.'
      }
      foreach ($name in @('code', 'correlationId', 'message')) {
        if (-not (& $hasMember $serverError $name)) { throw "The AceOutpost error is missing '$name'." }
      }
      $errorCode = & $getMember $serverError 'code'
      $correlationId = & $getMember $serverError 'correlationId'
      $errorMessage = & $getMember $serverError 'message'
      $codesByStatus = @{
        400 = @('CS-REQ-001', 'CS-QUERY-002', 'InvalidRequest')
        401 = @('CS-AUTH-001', 'CallerMissing')
        403 = @('CS-AUTH-002', 'CallerDenied', 'NonLoopbackPeer')
        409 = @('CS-IDEMP-001', 'CS-RULE-001', 'CS-FRESH-001', 'IdempotencyConflict')
        422 = @('CS-SRC-001', 'CS-SRC-002', 'CS-HASH-001', 'CS-CLASS-001', 'CS-CLASS-002', 'CS-QUERY-001')
        500 = @('CS-INTERNAL-001', 'SubmissionCaptureUnavailable', 'QueryUnavailable')
        503 = @('CS-HARVEST-001', 'CS-SUMMARY-001')
        504 = @('CS-QUERY-003')
      }
      $observedStatusNumber = [int]$ObservedHttpStatus
      if ($errorCode -isnot [string] -or -not $codesByStatus.ContainsKey($observedStatusNumber) -or
        [string]$errorCode -notin $codesByStatus[$observedStatusNumber]) {
        throw 'The AceOutpost error code is invalid.'
      }
      if ($correlationId -isnot [string] -or [string]$correlationId -notmatch '^[A-Za-z0-9._:/-]{1,128}$') {
        throw 'The AceOutpost error correlation ID is invalid.'
      }
      if (-not (& $isSafeText $errorMessage 1024)) { throw 'The AceOutpost error message is invalid.' }

      $safeError = & $newError ([string]$errorCode) ([string]$correlationId) ([string]$errorMessage) $ObservedHttpStatus
      $publicEnvelope = & $newEnvelope 'Error' $responseQuery @() $false $safeError
      [pscustomobject]@{
        PublicEnvelope = $publicEnvelope
        RecordEnvelope = $publicEnvelope
        ErrorMessage = [string]$errorMessage
      }
    }

    $getHttpStatus = {
      param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)
      $responseProperty = $ErrorRecord.Exception.PSObject.Properties['Response']
      if ($null -eq $responseProperty -or $null -eq $responseProperty.Value) { return $null }
      $statusProperty = $responseProperty.Value.PSObject.Properties['StatusCode']
      if ($null -eq $statusProperty -or $null -eq $statusProperty.Value) { return $null }
      try { [int]$statusProperty.Value } catch { $null }
    }

    $getHttpBody = {
      param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)
      if ($null -ne $ErrorRecord.ErrorDetails -and
        -not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        $errorDetailsText = ([string]$ErrorRecord.ErrorDetails.Message).Trim()
        if ($errorDetailsText.StartsWith('{') -or $errorDetailsText.StartsWith('[')) {
          return $errorDetailsText
        }
      }
      $responseProperty = $ErrorRecord.Exception.PSObject.Properties['Response']
      if ($null -eq $responseProperty -or $null -eq $responseProperty.Value) { return $null }
      $contentProperty = $responseProperty.Value.PSObject.Properties['Content']
      if ($null -eq $contentProperty -or $null -eq $contentProperty.Value) { return $null }
      try {
        $readTask = $contentProperty.Value.ReadAsStringAsync()
        [string]$readTask.GetAwaiter().GetResult()
      }
      catch {
        $null
      }
    }

    $newHttpFailure = {
      param([int]$HttpStatus, [object]$QueryValue)
      $code = switch ($HttpStatus) {
        400 { 'CS-REQ-001' }
        401 { 'CS-AUTH-001' }
        403 { 'CS-AUTH-002' }
        409 { 'CS-IDEMP-001' }
        422 { 'CS-QUERY-001' }
        500 { 'CS-INTERNAL-001' }
        503 { 'GatherContentUnavailable' }
        504 { 'CS-QUERY-003' }
        default { 'GatherContentRequestFailed' }
      }
      $message = switch ($HttpStatus) {
        400 { 'AceOutpost rejected the gather-content request.' }
        401 { 'AceOutpost requires an authenticated gather-content caller.' }
        403 { 'AceOutpost denied the gather-content caller.' }
        409 { 'AceOutpost reported a gather-content conflict.' }
        422 { 'AceOutpost could not process the gather-content query.' }
        500 { 'AceOutpost could not complete the gather-content query.' }
        503 { 'AceOutpost gather-content is unavailable.' }
        504 { 'AceOutpost gather-content timed out.' }
        default { 'AceOutpost gather-content request failed.' }
      }
      $safeError = & $newError $code $null $message $HttpStatus
      & $newEnvelope 'Error' $QueryValue @() $false $safeError
    }
  }

  process {
    $envelope = $null
    $recordEnvelope = $null
    $recordErrorMessage = $null
    $recordAsNoResponse = $false
    $recordFailure = $null
    $shouldRecord = $true
    $effectiveWorktreeRoot = $WorktreeRoot
    $transportReturned = $false
    $query = [pscustomobject][ordered]@{
      tags = [string[]]@($Tags)
      depth = $Depth
      width = $Width
      instance = $Instance
    }

    try {
      $schemeBound = if ($callerBoundParameters.ContainsKey('Scheme')) { @{ AceOutpostIngestionScheme = $callerBoundParameters.Scheme } } else { @{} }
      $hostBound = if ($callerBoundParameters.ContainsKey('HostName')) { @{ AceOutpostIngestionHost = $callerBoundParameters.HostName } } else { @{} }
      $portBound = if ($callerBoundParameters.ContainsKey('Port')) { @{ AceOutpostIngestionPort = $callerBoundParameters.Port } } else { @{} }
      $pathBound = if ($callerBoundParameters.ContainsKey('Path')) { @{ AceOutpostIngestionPath = $callerBoundParameters.Path } } else { @{} }

      $effectiveScheme = Get-PVal -ParameterName 'AceOutpostIngestionScheme' -originalPSBoundParameters $schemeBound -dottedPath 'AceOutpost.Ingestion.Scheme' -DefaultValue 'https' -AsType ([string])
      $effectiveHost = Get-PVal -ParameterName 'AceOutpostIngestionHost' -originalPSBoundParameters $hostBound -dottedPath 'AceOutpost.Ingestion.Host' -DefaultValue 'localhost' -AsType ([string])
      $effectivePort = Get-PVal -ParameterName 'AceOutpostIngestionPort' -originalPSBoundParameters $portBound -dottedPath 'AceOutpost.Ingestion.Port' -AllowMissing -AsType ([int])
      $effectivePath = Get-PVal -ParameterName 'AceOutpostIngestionPath' -originalPSBoundParameters $pathBound -dottedPath 'AceOutpost.Ingestion.Path' -DefaultValue '/api/v1/gather-content' -AsType ([string])

      if (-not [string]::Equals($effectiveScheme, 'https', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'AceOutpost gather-content requires the https scheme.'
      }
      if ($effectiveHost -notin @('localhost', '127.0.0.1', '::1')) {
        throw 'AceOutpost gather-content host must be localhost, 127.0.0.1, or ::1.'
      }
      if ($null -eq $effectivePort -or $effectivePort -lt 50000 -or $effectivePort -gt 50099) {
        throw 'AceOutpost gather-content port must be configured in the 50000 through 50099 range.'
      }
      if (-not $effectivePath.StartsWith('/') -or $effectivePath.Contains('?') -or
        $effectivePath.Contains('#') -or $effectivePath.StartsWith('//')) {
        throw 'AceOutpost gather-content path must be one absolute path without query or fragment.'
      }

      $uriBuilder = [UriBuilder]::new('https', $effectiveHost, $effectivePort, $effectivePath)
      $uri = $uriBuilder.Uri
      if (-not $uri.IsLoopback) { throw 'AceOutpost gather-content endpoint did not resolve as a loopback URI.' }
      $body = $query | ConvertTo-Json -Depth 4 -Compress

      if (-not $PSCmdlet.ShouldProcess($uri.AbsoluteUri, 'POST ContentSummary query')) {
        $shouldRecord = $false
        $envelope = & $newEnvelope 'WhatIf' $query @() $false $null
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $($uri.AbsoluteUri)" -Tag 'RestCall'
        $headers = @{ 'Idempotency-Key' = [guid]::NewGuid().ToString('D').ToLowerInvariant() }
        $transportArguments = @{
          UseDefaultCredentials = $true
          MaximumRedirection = 0
          NoProxy = $true
          TimeoutSec = 30
        }
        if ((Get-Command -Name Invoke-RestMethod).Parameters.ContainsKey('OperationTimeoutSeconds')) {
          $transportArguments.OperationTimeoutSeconds = 30
        }
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $body @transportArguments -ErrorAction Stop
        $transportReturned = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $($uri.AbsoluteUri)" -Tag 'RestCall'
        $mapped = & $convertResponse $response 200
        $envelope = $mapped.PublicEnvelope
        $recordEnvelope = $mapped.RecordEnvelope
        $recordErrorMessage = $mapped.ErrorMessage
      }
    }
    catch {
      $caughtError = $_
      $httpStatus = & $getHttpStatus $caughtError
      $isCancellation = $caughtError.Exception -is [OperationCanceledException] -or
        $caughtError.Exception -is [Threading.Tasks.TaskCanceledException]

      if ($isCancellation) {
        $recordAsNoResponse = $true
        $recordErrorMessage = 'AceOutpost gather-content was cancelled or timed out.'
        $safeError = & $newError 'CS-QUERY-003' $null $recordErrorMessage $null
        $envelope = & $newEnvelope 'Error' $query @() $false $safeError
      }
      elseif ($null -ne $httpStatus) {
        $responseBody = & $getHttpBody $caughtError
        $mappedHttpResponse = $null
        if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
          try {
            $parsedResponse = $responseBody | ConvertFrom-Json -ErrorAction Stop
            $mappedHttpResponse = & $convertResponse $parsedResponse $httpStatus
          }
          catch {
            $mappedHttpResponse = $null
          }
        }
        if ($null -ne $mappedHttpResponse) {
          $envelope = $mappedHttpResponse.PublicEnvelope
          $recordEnvelope = $mappedHttpResponse.RecordEnvelope
          $recordErrorMessage = $mappedHttpResponse.ErrorMessage
        }
        else {
          $envelope = & $newHttpFailure $httpStatus $query
          $recordEnvelope = $envelope
          $recordErrorMessage = $envelope.error.message
        }
      }
      elseif ($transportReturned) {
        $recordErrorMessage = 'AceOutpost gather-content returned an invalid response.'
        $safeError = & $newError 'GatherContentInvalidResponse' $null $recordErrorMessage 200
        $envelope = & $newEnvelope 'Error' $query @() $false $safeError
        $recordEnvelope = $envelope
      }
      else {
        $recordAsNoResponse = $true
        $recordErrorMessage = 'AceOutpost gather-content request failed.'
        $safeError = & $newError 'GatherContentRequestFailed' $null $recordErrorMessage $null
        $envelope = & $newEnvelope 'Error' $query @() $false $safeError
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "AceOutpost gather-content failed with exception type $($caughtError.Exception.GetType().FullName)."
    }
    finally {
      if ($shouldRecord) {
        try {
          if ([string]::IsNullOrWhiteSpace($effectiveWorktreeRoot)) {
            $effectiveWorktreeRoot = Get-RepositoryRoot -StartPath (Get-Location).Path -Absolute
          }
          $recordArguments = @{
            Tags = @($Tags)
            AgentName = $AgentName
            Depth = $Depth
            Width = $Width
            Instance = $Instance
            Prompt = $Prompt
            WorktreeRoot = $effectiveWorktreeRoot
          }
          if (-not [string]::IsNullOrWhiteSpace($TaskId)) { $recordArguments.TaskId = $TaskId }
          if ($recordAsNoResponse) {
            $recordArguments.NoResponse = $true
            $recordArguments.ErrorMessage = $recordErrorMessage
          }
          else {
            $recordArguments.Response = if ($null -eq $recordEnvelope) { $envelope } else { $recordEnvelope }
            if (-not [string]::IsNullOrWhiteSpace($recordErrorMessage)) {
              $recordArguments.ErrorMessage = $recordErrorMessage
            }
          }
          Write-GatherCallRecord @recordArguments | Out-Null
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Gather-call recording failed with exception type $($_.Exception.GetType().FullName)."
          $recordFailure = $_
        }
      }
    }

    if ($null -ne $recordFailure) { throw 'Gather-call recording is mandatory and did not complete.' }
    $envelope
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
