BeforeAll {
  $script:moduleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
  $script:moduleName = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
  Import-Module -Name 'ATAP.Utilities.Powershell' -MinimumVersion '0.2.1' -Force
  Import-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -MinimumVersion '0.1.10' -Force
  Import-Module -Name 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell' -MinimumVersion '0.1.34' -Force
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  $moduleToTest = if ([string]::IsNullOrWhiteSpace($promotedManifest)) {
    Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell.psd1'
  }
  else {
    $promotedManifest
  }
  Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module -Name $moduleToTest -Force -ErrorAction Stop

  $script:newHttpException = {
    param(
      [Parameter(Mandatory)]
      [int]$StatusCode,

      [AllowNull()]
      [object]$ResponseEnvelope
    )

    $responseMessage = [System.Net.Http.HttpResponseMessage]::new(
      [System.Net.HttpStatusCode]$StatusCode)
    if ($null -ne $ResponseEnvelope) {
      $json = $ResponseEnvelope | ConvertTo-Json -Depth 12 -Compress
      $responseMessage.Content = [System.Net.Http.StringContent]::new(
        $json,
        [System.Text.Encoding]::UTF8,
        'application/json')
    }
    [Microsoft.PowerShell.Commands.HttpResponseException]::new(
      "HTTP $StatusCode",
      $responseMessage)
  }
}

Describe 'Get-ContentSummary [public]' -Tag 'Unit' {
  BeforeEach {
    $global:settings = @{
      AceOutpost = @{
        Ingestion = @{
          Scheme = 'https'
          Host = 'localhost'
          Port = 50042
          Path = '/api/v1/gather-content'
        }
      }
    }
    Mock -CommandName Write-PSFMessage -ModuleName $script:moduleName
    Mock -CommandName Get-RepositoryRoot -ModuleName $script:moduleName {
      'C:\fixture\ATAP.Utilities-wt-137-Sprint-0015-work-items'
    }
    Mock -CommandName Write-GatherCallRecord -ModuleName $script:moduleName {
      [pscustomobject]@{ recorded = $true }
    }
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = [pscustomobject][ordered]@{
          tags = @($request.tags)
          depth = $request.depth
          width = $request.width
          instance = $request.instance
        }
        items = @(
          [pscustomobject][ordered]@{
            itemId = '10000000-0000-0000-0000-000000000001'
            sourceKind = 'InlineText'
            sourceReference = 'src/example.ps1'
            text = 'Verified summary text.'
            matchedTags = @([string]$request.tags[0])
            rankingContract = 'content-summary-rank-v1'
            rank = 1
            assertedAtUtc = '2026-09-04T00:00:00.0000000+00:00'
            recordedAtUtc = '2026-09-04T00:01:00.0000000+00:00'
            producerId = '20000000-0000-0000-0000-000000000002'
            contentHash = ('a' * 64)
          }
        )
        truncated = $false
        error = $null
      }
    }
  }

  It 'loads exactly one target module from the selected manifest' {
    $loadedModules = @(Get-Module -Name $script:moduleName)
    $loadedModules.Count | Should -Be 1

    $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
    if (-not [string]::IsNullOrWhiteSpace($promotedManifest)) {
      [System.IO.Path]::GetFullPath($loadedModules[0].ModuleBase) |
        Should -BeExactly ([System.IO.Path]::GetFullPath((Split-Path -Path $promotedManifest -Parent)))
    }
  }

  It 'exports the client and harvester at module version 0.1.5' {
    Get-Command -Name Get-ContentSummary -Module $script:moduleName | Should -Not -BeNullOrEmpty
    Get-Command -Name Invoke-ContentSummaryHarvest -Module $script:moduleName | Should -Not -BeNullOrEmpty
    (Get-Module -Name $script:moduleName).Version.ToString() | Should -BeExactly '0.1.5'
  }

  It 'preserves the established public parameter interface' {
    $parameters = (Get-Command -Name Get-ContentSummary -Module $script:moduleName).Parameters
    foreach ($name in @(
        'Tags', 'Depth', 'Width', 'Instance', 'Scheme', 'HostName', 'Port', 'Path',
        'AgentName', 'WorktreeRoot', 'TaskId', 'Prompt'
      )) {
      $parameters.ContainsKey($name) | Should -BeTrue
    }
  }

  It 'posts the exact request contract and maps a real item without changing its content' {
    $result = Get-ContentSummary -Tags @('schema', 'migration') -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'ok'
    @($result.items).Count | Should -Be 1
    $result.items[0].text | Should -BeExactly 'Verified summary text.'
    $result.items[0].contentHash | Should -BeExactly ('a' * 64)
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Method -eq 'Post' -and
      $ContentType -eq 'application/json' -and
      $Uri.AbsoluteUri -eq 'https://localhost:50042/api/v1/gather-content' -and
      $Headers.Count -eq 1 -and
      $Headers.ContainsKey('Idempotency-Key') -and
      [guid]::Parse([string]$Headers['Idempotency-Key']) -ne [guid]::Empty -and
      (($Body | ConvertFrom-Json).PSObject.Properties.Name -join ',') -eq 'tags,depth,width,instance'
    }
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Response.status -eq 'ok' -and @($Response.items).Count -eq 1 -and
      -not $PSBoundParameters.ContainsKey('NoResponse')
    }
  }

  It 'returns authorized empty as success without fabricating content' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @()
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('no-match') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'ok'
    @($result.items).Count | Should -Be 0
    $result.truncated | Should -BeFalse
    $result.error | Should -BeNullOrEmpty
  }

  It 'preserves server truncation only after validating every returned item' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @(
          [pscustomobject][ordered]@{
            itemId = '10000000-0000-0000-0000-000000000001'
            sourceKind = 'InlineText'
            sourceReference = 'src/example.ps1'
            text = 'First bounded result.'
            matchedTags = @('bounded')
            rankingContract = 'content-summary-rank-v1'
            rank = 1
            assertedAtUtc = '2026-09-04T00:00:00Z'
            recordedAtUtc = '2026-09-04T00:01:00Z'
            producerId = '20000000-0000-0000-0000-000000000002'
            contentHash = ('b' * 64)
          }
        )
        truncated = $true
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('bounded') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'ok'
    $result.truncated | Should -BeTrue
    @($result.items).Count | Should -Be 1
  }

  It 'retains stub marker and blockers within the six-field public envelope and recorder contract' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'NotImplemented'
        stub = [pscustomobject][ordered]@{
          marker = 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
          blockedBy = @('RDB-190', 'Stream D')
          reason = 'The query adapter is not available.'
        }
        query = $request
        items = @()
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('stub') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    ($result.PSObject.Properties.Name -join ',') | Should -BeExactly 'agent,status,query,items,truncated,error'
    $result.status | Should -BeExactly 'NotImplemented'
    $result.error.marker | Should -BeExactly 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
    $result.error.blockedBy | Should -Be @('RDB-190', 'Stream D')
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Response.stub.marker -eq 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED' -and
      @($Response.stub.blockedBy).Count -eq 2
    }
  }

  It 'preserves a safe server error code correlation and observed HTTP status' {
    $query = [pscustomobject][ordered]@{
      tags = @('forbidden')
      depth = 3
      width = 2
      instance = 'production'
    }
    $serverEnvelope = [pscustomobject][ordered]@{
      agent = 'gather-content-summary'
      status = 'Forbidden'
      stub = $null
      query = $query
      items = @()
      truncated = $false
      error = [pscustomobject][ordered]@{
        code = 'CS-AUTH-002'
        correlationId = 'trace-403'
        message = 'The caller is not authorized for gather-content.'
      }
    }
    $script:httpException = & $script:newHttpException 403 $serverEnvelope
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName { throw $script:httpException }

    $result = Get-ContentSummary -Tags @('forbidden') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'CS-AUTH-002'
    $result.error.correlationId | Should -BeExactly 'trace-403'
    $result.error.httpStatus | Should -Be 403
    @($result.items).Count | Should -Be 0
  }

  It 'maps a bare authentication challenge without inventing response content' {
    $script:httpException = & $script:newHttpException 401 $null
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName { throw $script:httpException }

    $result = Get-ContentSummary -Tags @('auth') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'CS-AUTH-001'
    $result.error.httpStatus | Should -Be 401
    $result.error.correlationId | Should -BeNullOrEmpty
    @($result.items).Count | Should -Be 0
  }

  It 'keeps bare HTTP failures distinguishable for status <StatusCode>' -ForEach @(
    @{ StatusCode = 400; ExpectedCode = 'CS-REQ-001' }
    @{ StatusCode = 403; ExpectedCode = 'CS-AUTH-002' }
    @{ StatusCode = 409; ExpectedCode = 'CS-IDEMP-001' }
    @{ StatusCode = 500; ExpectedCode = 'CS-INTERNAL-001' }
    @{ StatusCode = 504; ExpectedCode = 'CS-QUERY-003' }
  ) {
    $script:httpException = & $script:newHttpException $StatusCode $null
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName { throw $script:httpException }

    $result = Get-ContentSummary -Tags @('http') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly $ExpectedCode
    $result.error.httpStatus | Should -Be $StatusCode
    @($result.items).Count | Should -Be 0
  }

  It 'maps cancellation to CS-QUERY-003 and records that no response was received' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      throw [System.OperationCanceledException]::new('sensitive cancellation details')
    }

    $result = Get-ContentSummary -Tags @('cancel') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'CS-QUERY-003'
    ($result | ConvertTo-Json -Depth 8 -Compress) | Should -Not -Match 'sensitive cancellation'
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $NoResponse -and $ErrorMessage -eq 'AceOutpost gather-content was cancelled or timed out.'
    }
  }

  It 'returns a stable transport error and records that no response was received' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      throw 'secret-value-should-never-escape'
    }

    $result = Get-ContentSummary -Tags @('failure') -Port 50041 -WorktreeRoot 'C:\fixture\repo'
    $serialized = $result | ConvertTo-Json -Depth 8 -Compress

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'GatherContentRequestFailed'
    $serialized | Should -Not -Match 'secret-value-should-never-escape'
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $NoResponse -and $ErrorMessage -eq 'AceOutpost gather-content request failed.'
    }
  }

  It 'rejects an item missing one required field without returning partial content' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @([pscustomobject]@{ itemId = [guid]::NewGuid().ToString('D'); text = 'partial' })
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('invalid') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'GatherContentInvalidResponse'
    @($result.items).Count | Should -Be 0
  }

  It 'rejects a bare item object that masquerades as the items array' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = [pscustomobject][ordered]@{
          itemId = '10000000-0000-0000-0000-000000000001'
          sourceKind = 'InlineText'
          sourceReference = 'src/example.ps1'
          text = 'A bare object is not an array.'
          matchedTags = @('invalid')
          rankingContract = 'content-summary-rank-v1'
          rank = 1
          assertedAtUtc = '2026-09-04T00:00:00Z'
          recordedAtUtc = '2026-09-04T00:01:00Z'
          producerId = '20000000-0000-0000-0000-000000000002'
          contentHash = ('d' * 64)
        }
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('invalid') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.error.code | Should -BeExactly 'GatherContentInvalidResponse'
    @($result.items).Count | Should -Be 0
  }

  It 'rejects an HTTP error body that falsely claims success' {
    $serverEnvelope = [pscustomobject][ordered]@{
      agent = 'gather-content-summary'
      status = 'Success'
      stub = $null
      query = [pscustomobject][ordered]@{
        tags = @('conflict')
        depth = 3
        width = 2
        instance = 'production'
      }
      items = @()
      truncated = $false
      error = $null
    }
    $script:httpException = & $script:newHttpException 409 $serverEnvelope
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName { throw $script:httpException }

    $result = Get-ContentSummary -Tags @('conflict') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'CS-IDEMP-001'
    $result.error.httpStatus | Should -Be 409
    @($result.items).Count | Should -Be 0
  }

  It 'rejects the exact secret canary without returning or recording it' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @(
          [pscustomobject][ordered]@{
            itemId = '10000000-0000-0000-0000-000000000001'
            sourceKind = 'InlineText'
            sourceReference = 'src/example.ps1'
            text = 'ATAP_SECRET_CANARY'
            matchedTags = @('secret')
            rankingContract = 'content-summary-rank-v1'
            rank = 1
            assertedAtUtc = '2026-09-04T00:00:00Z'
            recordedAtUtc = '2026-09-04T00:01:00Z'
            producerId = '20000000-0000-0000-0000-000000000002'
            contentHash = ('c' * 64)
          }
        )
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('secret') -Port 50041 -WorktreeRoot 'C:\fixture\repo'
    $serialized = $result | ConvertTo-Json -Depth 8 -Compress

    $result.error.code | Should -BeExactly 'GatherContentInvalidResponse'
    @($result.items).Count | Should -Be 0
    $serialized | Should -Not -Match 'ATAP_SECRET_CANARY'
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      ($Response | ConvertTo-Json -Depth 8 -Compress) -notmatch 'ATAP_SECRET_CANARY'
    }
  }

  It 'rejects a response query that does not match the request' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = [pscustomobject][ordered]@{
          tags = @('different')
          depth = 3
          width = 2
          instance = 'production'
        }
        items = @()
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('requested') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.error.code | Should -BeExactly 'GatherContentInvalidResponse'
    @($result.items).Count | Should -Be 0
  }

  It 'rejects an unexpected response agent' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'different-agent'
        status = 'Success'
        stub = $null
        query = $request
        items = @()
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('agent') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.error.code | Should -BeExactly 'GatherContentInvalidResponse'
  }

  It 'rejects a success response that also carries error data' {
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @()
        truncated = $false
        error = [pscustomobject]@{
          code = 'CS-INTERNAL-001'
          correlationId = 'trace-invalid'
          message = 'Inconsistent success.'
        }
      }
    }

    $result = Get-ContentSummary -Tags @('invalid') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.error.code | Should -BeExactly 'GatherContentInvalidResponse'
  }

  It 'protects the authenticated request to <EndpointHost>' -ForEach @(
    @{ EndpointHost = 'localhost' }
    @{ EndpointHost = '127.0.0.1' }
    @{ EndpointHost = '::1' }
  ) {
    $script:transportCall = $null
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $script:transportCall = @{} + $PesterBoundParameters
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @()
        truncated = $false
        error = $null
      }
    }

    $result = Get-ContentSummary -Tags @('transport') -HostName $EndpointHost -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    $result.status | Should -BeExactly 'ok'
    $script:transportCall.UseDefaultCredentials | Should -BeTrue
    $script:transportCall.MaximumRedirection | Should -Be 0
    $script:transportCall.NoProxy | Should -BeTrue
    $timeoutParameter = if ($script:transportCall.ContainsKey('ConnectionTimeoutSeconds')) {
      'ConnectionTimeoutSeconds'
    }
    else {
      'TimeoutSec'
    }
    $script:transportCall[$timeoutParameter] | Should -Be 30
    if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey('OperationTimeoutSeconds')) {
      $script:transportCall.OperationTimeoutSeconds | Should -Be 30
    }
    foreach ($forbiddenParameter in @(
        'Credential', 'Proxy', 'ProxyCredential', 'ProxyUseDefaultCredentials',
        'SkipCertificateCheck', 'AllowInsecureRedirect', 'PreserveAuthorizationOnRedirect'
      )) {
      $script:transportCall.ContainsKey($forbiddenParameter) | Should -BeFalse
    }
  }

  It 'does not authenticate or record a valid WhatIf request' {
    $result = Get-ContentSummary -Tags @('whatif') -Port 50041 -WorktreeRoot 'C:\fixture\repo' -WhatIf

    $result.status | Should -BeExactly 'WhatIf'
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 0
    Should -Invoke Write-GatherCallRecord -ModuleName $script:moduleName -Times 0
  }

  It 'gives explicit endpoint parameters precedence over global settings' {
    Get-ContentSummary -Tags @('precedence') -Scheme https -HostName 127.0.0.1 -Port 50041 -Path '/custom/gather' -WorktreeRoot 'C:\fixture\repo' | Out-Null

    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Uri.AbsoluteUri -eq 'https://127.0.0.1:50041/custom/gather'
    }
  }

  It 'builds a bracketed IPv6 loopback URI' {
    Get-ContentSummary -Tags @('ipv6') -HostName '::1' -Port 50043 -WorktreeRoot 'C:\fixture\repo' | Out-Null

    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Uri.AbsoluteUri -eq 'https://[::1]:50043/api/v1/gather-content'
    }
  }

  It 'rejects invalid endpoint configuration before REST I/O for <Case>' -ForEach @(
    @{ Case = 'scheme'; Arguments = @{ Scheme = 'http'; HostName = 'localhost'; Port = 50041 } }
    @{ Case = 'host'; Arguments = @{ Scheme = 'https'; HostName = '192.0.2.10'; Port = 50041 } }
    @{ Case = 'port'; Arguments = @{ Scheme = 'https'; HostName = 'localhost'; Port = 50300 } }
    @{ Case = 'path'; Arguments = @{ Port = 50041; Path = '/api/v1/gather-content?token=value' } }
  ) {
    $arguments = @{} + $Arguments
    $arguments.Tags = @('unsafe')
    $arguments.WorktreeRoot = 'C:\fixture\repo'

    $result = Get-ContentSummary @arguments

    $result.status | Should -BeExactly 'Error'
    $result.error.code | Should -BeExactly 'GatherContentRequestFailed'
    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 0
  }

  It 'fails closed when mandatory recording fails' {
    Mock -CommandName Write-GatherCallRecord -ModuleName $script:moduleName { throw 'record unavailable' }

    { Get-ContentSummary -Tags @('record') -Port 50041 -WorktreeRoot 'C:\fixture\repo' } |
      Should -Throw 'Gather-call recording is mandatory and did not complete.'
  }

  It 'does not send prompt text or secret-shaped values in the REST body' {
    Get-ContentSummary -Tags @('safe') -Port 50041 -Prompt 'token=super-secret' -WorktreeRoot 'C:\fixture\repo' | Out-Null

    Should -Invoke Invoke-RestMethod -ModuleName $script:moduleName -Times 1 -ParameterFilter {
      $Body -notmatch 'super-secret|token|prompt|authorization|connectionstring'
    }
  }

  It 'generates a distinct lowercase idempotency UUID for each invocation' {
    $script:observedIdempotencyKeys = [System.Collections.Generic.List[string]]::new()
    Mock -CommandName Invoke-RestMethod -ModuleName $script:moduleName {
      $script:observedIdempotencyKeys.Add([string]$Headers['Idempotency-Key'])
      $request = $Body | ConvertFrom-Json
      [pscustomobject][ordered]@{
        agent = 'gather-content-summary'
        status = 'Success'
        stub = $null
        query = $request
        items = @()
        truncated = $false
        error = $null
      }
    }

    Get-ContentSummary -Tags @('first') -Port 50041 -WorktreeRoot 'C:\fixture\repo' | Out-Null
    Get-ContentSummary -Tags @('second') -Port 50041 -WorktreeRoot 'C:\fixture\repo' | Out-Null

    $script:observedIdempotencyKeys.Count | Should -Be 2
    $script:observedIdempotencyKeys[0] | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    $script:observedIdempotencyKeys[1] | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    $script:observedIdempotencyKeys[0] | Should -Not -BeExactly $script:observedIdempotencyKeys[1]
  }

  It 'returns the stable six-member agent envelope' {
    $result = Get-ContentSummary -Tags @('shape') -Port 50041 -WorktreeRoot 'C:\fixture\repo'

    ($result.PSObject.Properties.Name -join ',') | Should -BeExactly 'agent,status,query,items,truncated,error'
    ($result.query.PSObject.Properties.Name -join ',') | Should -BeExactly 'tags,depth,width,instance'
  }
}
