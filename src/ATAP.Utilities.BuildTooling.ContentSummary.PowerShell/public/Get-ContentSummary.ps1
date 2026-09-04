function Get-ContentSummary {
  <#
  .SYNOPSIS
    Retrieves authorized ContentSummary items from the local AceOutpost service.
  .DESCRIPTION
    Sends a JSON query to the configured AceOutpost gather-content endpoint. The function
    accepts only HTTPS loopback endpoints, uses ambient Windows authentication, performs no SQL access,
    and records each actual invocation through Write-GatherCallRecord.
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
  }

  process {
    $envelope = $null
    $recordFailure = $null
    $shouldRecord = $true
    $effectiveWorktreeRoot = $WorktreeRoot

    try {
      # Use endpoint-specific Get-PVal identities rather than generic names such as Path or
      # HostName. Generic identities collide with the ubiquitous PATH/HOSTNAME process
      # variables before the ATAP settings tree is consulted. Copy only explicitly bound
      # public parameters into these lookup maps, preserving their highest precedence.
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
      if (-not $effectivePath.StartsWith('/') -or $effectivePath.Contains('?') -or $effectivePath.Contains('#') -or $effectivePath.StartsWith('//')) {
        throw 'AceOutpost gather-content path must be one absolute path without query or fragment.'
      }

      $uriBuilder = [UriBuilder]::new('https', $effectiveHost, $effectivePort, $effectivePath)
      $uri = $uriBuilder.Uri
      if (-not $uri.IsLoopback) {
        throw 'AceOutpost gather-content endpoint did not resolve as a loopback URI.'
      }

      $query = [ordered]@{
        tags = @($Tags)
        depth = $Depth
        width = $Width
        instance = $Instance
      }
      $body = $query | ConvertTo-Json -Depth 4 -Compress

      if (-not $PSCmdlet.ShouldProcess($uri.AbsoluteUri, 'POST ContentSummary query')) {
        $shouldRecord = $false
        $envelope = [pscustomobject][ordered]@{
          agent = $AgentName
          status = 'WhatIf'
          query = [pscustomobject]$query
          items = @()
          truncated = $false
          error = $null
        }
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $($uri.AbsoluteUri)" -Tag 'RestCall'
        $headers = @{ 'Idempotency-Key' = [guid]::NewGuid().ToString('D') }
        $transportArguments = @{
          UseDefaultCredentials = $true
          MaximumRedirection = 0
          NoProxy = $true
          TimeoutSec = 30
        }
        # PowerShell 7.4 split connection and operation timeouts; retain the 7.0 alias.
        if ((Get-Command -Name Invoke-RestMethod).Parameters.ContainsKey('OperationTimeoutSeconds')) {
          $transportArguments.OperationTimeoutSeconds = 30
        }
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $body @transportArguments -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $($uri.AbsoluteUri)" -Tag 'RestCall'

        $responseStatus = if ($null -ne $response.PSObject.Properties['status'] -and -not [string]::IsNullOrWhiteSpace([string]$response.status)) { [string]$response.status } else { 'ok' }
        $responseItems = if ($null -ne $response.PSObject.Properties['items'] -and $null -ne $response.items) { @($response.items) } else { @() }
        $responseTruncated = if ($null -ne $response.PSObject.Properties['truncated']) { [bool]$response.truncated } else { $false }
        $safeError = if ($responseStatus -in @('ok', 'success')) {
          $null
        }
        else {
          [pscustomobject][ordered]@{ code = 'AceOutpostError'; message = 'AceOutpost gather-content returned an error status.' }
        }
        $envelope = [pscustomobject][ordered]@{
          agent = $AgentName
          status = $responseStatus
          query = [pscustomobject]$query
          items = $responseItems
          truncated = $responseTruncated
          error = $safeError
        }
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "AceOutpost gather-content failed with exception type $($_.Exception.GetType().FullName)."
      $envelope = [pscustomobject][ordered]@{
        agent = $AgentName
        status = 'Error'
        query = [pscustomobject][ordered]@{ tags = @($Tags); depth = $Depth; width = $Width; instance = $Instance }
        items = @()
        truncated = $false
        error = [pscustomobject][ordered]@{ code = 'GatherContentRequestFailed'; message = 'AceOutpost gather-content request failed.' }
      }
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
            Response = $envelope
            WorktreeRoot = $effectiveWorktreeRoot
          }
          if (-not [string]::IsNullOrWhiteSpace($TaskId)) { $recordArguments.TaskId = $TaskId }
          if ($envelope.status -eq 'Error') { $recordArguments.ErrorMessage = $envelope.error.message }
          Write-GatherCallRecord @recordArguments | Out-Null
        }
        catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Gather-call recording failed with exception type $($_.Exception.GetType().FullName)."
          $recordFailure = $_
        }
      }
    }

    if ($null -ne $recordFailure) {
      throw 'Gather-call recording is mandatory and did not complete.'
    }
    $envelope
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
