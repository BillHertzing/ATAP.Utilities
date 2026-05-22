#Requires -Version 7.0

function Assert-BuildMasterReady {
  <#
.SYNOPSIS
    Verifies that BuildMaster is ready to host ATAP.Utilities builds.

.DESCRIPTION
    Runs a read-only preflight against the BuildMaster Native + Variables APIs:
      - BUILDMASTER_ADMIN_API_KEY is resolvable.
      - The Native API base URL responds to Applications_GetApplications.
      - Each expected application (default: ATAP.Utilities-CSharp and
        ATAP.Utilities-PowerShell) exists in BuildMaster.
      - Each expected pipeline (default: CSharpPackage-5Stage,
        PowerShellModule-5Stage) is resolvable via Pipelines_GetPipelines;
        marked Skipped if the endpoint is not available.
      - Each required application variable (e.g. ApplicationName, SolutionPath)
        is set on its application via /api/variables/application/{app}.
      - Repository-monitor verification: currently Skipped with a TODO marker;
        Native API does not expose a stable monitor-listing endpoint.

    Every check runs to completion regardless of earlier failures so the
    structured result captures the full diagnostic picture. With -ThrowOnFailure
    the cmdlet throws a terminating error
    (FullyQualifiedErrorId: BuildMasterNotReadyException) when AllOk is $false.

    Despite the Assert-* name, default behavior is non-throwing because the
    acceptance criterion (Sprint 0007 A07/A08) requires the structured result
    even on failure. Callers wanting fail-fast semantics use -ThrowOnFailure.

.PARAMETER ApplicationNames
    BuildMaster application names to verify. Default:
    @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell').

.PARAMETER ExpectedPipelines
    Hashtable keyed by application name with values being the expected pipeline
    names for that app. Default:
    @{ 'ATAP.Utilities-CSharp' = @('CSharpPackage-5Stage');
       'ATAP.Utilities-PowerShell' = @('PowerShellModule-5Stage') }.

.PARAMETER RequiredVariables
    Hashtable keyed by application name with values being the required variable
    names for that app. Default:
    @{ 'ATAP.Utilities-CSharp' = @('ApplicationName', 'SolutionPath');
       'ATAP.Utilities-PowerShell' = @('ApplicationName') }.

.PARAMETER BuildMasterBaseUrl
    Base URL for BuildMaster. Defaults to
    $global:settings[$global:configRootKeys['BuildMasterBaseUrlConfigRootKey']],
    then $env:BUILDMASTER_BASE_URL, then 'http://localhost:50017'.

.PARAMETER ApiKey
    BuildMaster admin API key. Defaults to BUILDMASTER_ADMIN_API_KEY at User
    scope, then Process scope.

.PARAMETER TimeoutSeconds
    HTTP timeout per API call. Default 10.

.PARAMETER ThrowOnFailure
    If supplied, throw a terminating error when AllOk is $false.

.OUTPUTS
    [PSCustomObject] with AllOk [bool], Checks [PSCustomObject], Failures
    [string[]], Timestamp [DateTime].

.EXAMPLE
    Assert-BuildMasterReady | ConvertTo-Json -Depth 5

.EXAMPLE
    Assert-BuildMasterReady -ThrowOnFailure

.NOTES
    AI assisted using Powershell.instructions.md as guidelines
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [string[]]$ApplicationNames = @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell'),

    [Parameter()]
    [hashtable]$ExpectedPipelines = @{
      'ATAP.Utilities-CSharp'     = @('CSharpPackage-5Stage')
      'ATAP.Utilities-PowerShell' = @('PowerShellModule-5Stage')
    },

    [Parameter()]
    [hashtable]$RequiredVariables = @{
      'ATAP.Utilities-CSharp'     = @('ApplicationName', 'SolutionPath')
      'ATAP.Utilities-PowerShell' = @('ApplicationName')
    },

    [Parameter()]
    [string]$BuildMasterBaseUrl,

    [Parameter()]
    [string]$ApiKey,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 10,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Assert-BuildMasterReady'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $checks = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    if (-not $PSBoundParameters.ContainsKey('BuildMasterBaseUrl')) {
      try {
        if ($global:configRootKeys -and $global:settings) {
          $k = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
          if ($k -and $global:settings.ContainsKey($k)) {
            $BuildMasterBaseUrl = [string]$global:settings[$k]
          }
        }
      } catch { }
      if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
        $BuildMasterBaseUrl = $env:BUILDMASTER_BASE_URL
      }
      if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
        $BuildMasterBaseUrl = 'http://localhost:50017'
      }
    }
    $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
    $nativeBase = "$BuildMasterBaseUrl/api/json"
    $restBase = "$BuildMasterBaseUrl/api/variables/application"

    $apiKeyOk = $false
    $apiKeySource = $null
    $apiKeyDetail = ''
    if ($PSBoundParameters.ContainsKey('ApiKey') -and -not [string]::IsNullOrWhiteSpace($ApiKey)) {
      $apiKeyOk = $true
      $apiKeySource = 'Parameter'
      $apiKeyDetail = 'API key supplied via -ApiKey'
    } else {
      $userScopeKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'User')
      if (-not [string]::IsNullOrWhiteSpace($userScopeKey)) {
        $ApiKey = $userScopeKey
        $apiKeyOk = $true
        $apiKeySource = 'EnvUser'
        $apiKeyDetail = 'BUILDMASTER_ADMIN_API_KEY resolved from User scope'
      } else {
        $procScopeKey = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_ADMIN_API_KEY', 'Process')
        if (-not [string]::IsNullOrWhiteSpace($procScopeKey)) {
          $ApiKey = $procScopeKey
          $apiKeyOk = $true
          $apiKeySource = 'EnvProcess'
          $apiKeyDetail = 'BUILDMASTER_ADMIN_API_KEY resolved from Process scope'
        } else {
          $apiKeyDetail = 'BUILDMASTER_ADMIN_API_KEY not found at User or Process scope and no -ApiKey supplied'
        }
      }
    }
    $checks['ApiKeyResolvable'] = [PSCustomObject]@{
      Ok     = $apiKeyOk
      Detail = $apiKeyDetail
      Source = $apiKeySource
    }
    if (-not $apiKeyOk) { [void]$failures.Add('ApiKeyResolvable') }

    $apiReachable = $false
    $apiDetail = ''
    $allApps = @()
    if ($apiKeyOk) {
      try {
        $uri = "$nativeBase/Applications_GetApplications"
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body @{ API_Key = $ApiKey } -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        $allApps = @($response)
        $apiReachable = $true
        $apiDetail = "Applications_GetApplications returned $($allApps.Count) application(s)"
      } catch {
        $apiDetail = "Applications_GetApplications failed: $($_.Exception.Message)"
      }
    } else {
      $apiDetail = 'Skipped because ApiKeyResolvable failed'
    }
    $checks['ApiReachable'] = [PSCustomObject]@{
      Ok      = $apiReachable
      Detail  = $apiDetail
      BaseUrl = $BuildMasterBaseUrl
    }
    if (-not $apiReachable) { [void]$failures.Add('ApiReachable') }

    $perApp = @()
    $appsExistOk = $true
    foreach ($appName in $ApplicationNames) {
      $entry = [PSCustomObject]@{
        ApplicationName = $appName
        Ok              = $false
        Detail          = ''
        ApplicationId   = $null
      }
      if (-not $apiReachable) {
        $entry.Detail = 'Skipped because ApiReachable failed'
      } else {
        $match = @($allApps | Where-Object { $_.Application_Name -eq $appName })
        if ($match.Count -eq 1) {
          $entry.Ok = $true
          $entry.ApplicationId = [int]$match[0].Application_Id
          $entry.Detail = "Found (Application_Id=$($entry.ApplicationId))"
        } elseif ($match.Count -gt 1) {
          $entry.Detail = "Application name matched $($match.Count) entries; expected exactly 1"
        } else {
          $entry.Detail = 'Application not found in BuildMaster'
        }
      }
      if (-not $entry.Ok) { $appsExistOk = $false }
      $perApp += $entry
    }
    $checks['ApplicationExistence'] = [PSCustomObject]@{
      Ok     = ($apiReachable -and $appsExistOk)
      Detail = if ($apiReachable) {
        if ($appsExistOk) { "All $($ApplicationNames.Count) expected application(s) present" } else { 'One or more expected applications are missing' }
      } else { 'Skipped because ApiReachable failed' }
      PerApp = $perApp
    }
    if (-not $checks['ApplicationExistence'].Ok) { [void]$failures.Add('ApplicationExistence') }

    $pipelineSkipped = $false
    $allPipelines = @()
    if ($apiReachable) {
      try {
        $uri = "$nativeBase/Pipelines_GetPipelines"
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body @{ API_Key = $ApiKey } -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        $allPipelines = @($response)
      } catch {
        $statusCode = $null
        if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response -and $_.Exception.Response.StatusCode) {
          $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 404 -or $statusCode -eq 405) {
          $pipelineSkipped = $true
        } else {
          $allPipelines = $null
        }
      }
    } else {
      $pipelineSkipped = $true
    }

    $perAppPipelines = @()
    $pipelinesOk = $true
    foreach ($appName in $ApplicationNames) {
      $expected = @()
      if ($ExpectedPipelines.ContainsKey($appName)) {
        $expected = @($ExpectedPipelines[$appName])
      }
      $entry = [PSCustomObject]@{
        ApplicationName = $appName
        Expected        = $expected
        Found           = @()
        Missing         = @()
        Ok              = $false
        Detail          = ''
      }
      if ($pipelineSkipped) {
        $entry.Ok = $true
        $entry.Detail = 'Skipped'
      } elseif ($null -eq $allPipelines) {
        $entry.Detail = 'Pipelines_GetPipelines call failed'
      } else {
        $names = @($allPipelines | ForEach-Object { $_.Pipeline_Name })
        $found = @()
        $missing = @()
        foreach ($p in $expected) {
          if ($names -contains $p) { $found += $p } else { $missing += $p }
        }
        $entry.Found = $found
        $entry.Missing = $missing
        if ($missing.Count -eq 0) {
          $entry.Ok = $true
          $entry.Detail = "All expected pipeline(s) present: $($found -join ', ')"
        } else {
          $entry.Detail = "Missing pipeline(s): $($missing -join ', ')"
        }
      }
      if (-not $entry.Ok) { $pipelinesOk = $false }
      $perAppPipelines += $entry
    }
    $checks['PipelineExistence'] = [PSCustomObject]@{
      Ok      = $pipelinesOk
      Detail  = if ($pipelineSkipped) {
        if (-not $apiReachable) { 'Skipped because ApiReachable failed' } else { 'Pipelines_GetPipelines endpoint unavailable; check skipped' }
      } elseif ($pipelinesOk) { 'All expected pipelines present' } else { 'One or more expected pipelines are missing' }
      PerApp  = $perAppPipelines
      Skipped = $pipelineSkipped
    }
    if (-not $pipelinesOk) { [void]$failures.Add('PipelineExistence') }

    $perAppVars = @()
    $varsOk = $true
    foreach ($appName in $ApplicationNames) {
      $required = @()
      if ($RequiredVariables.ContainsKey($appName)) {
        $required = @($RequiredVariables[$appName])
      }
      $entry = [PSCustomObject]@{
        ApplicationName = $appName
        Required        = $required
        Found           = @()
        Missing         = @()
        Ok              = $false
        Detail          = ''
      }
      if (-not $apiReachable) {
        $entry.Detail = 'Skipped because ApiReachable failed'
      } elseif ($required.Count -eq 0) {
        $entry.Ok = $true
        $entry.Detail = 'No required variables specified'
      } else {
        try {
          $uri = "$restBase/$([uri]::EscapeDataString($appName))"
          $headers = @{
            'X-ApiKey' = $ApiKey
            'Accept'   = 'application/json'
          }
          $resp = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds -ErrorAction Stop
          $variableNames = @()
          if ($null -ne $resp) {
            if ($resp -is [System.Collections.IDictionary]) {
              $variableNames = @($resp.Keys)
            } elseif ($resp.PSObject.Properties) {
              $variableNames = @($resp.PSObject.Properties.Name)
            }
          }
          $found = @()
          $missing = @()
          foreach ($v in $required) {
            if ($variableNames -contains $v) { $found += $v } else { $missing += $v }
          }
          $entry.Found = $found
          $entry.Missing = $missing
          if ($missing.Count -eq 0) {
            $entry.Ok = $true
            $entry.Detail = "All required variable(s) present: $($found -join ', ')"
          } else {
            $entry.Detail = "Missing variable(s): $($missing -join ', ')"
          }
        } catch {
          $entry.Detail = "GET /api/variables/application/$appName failed: $($_.Exception.Message)"
        }
      }
      if (-not $entry.Ok) { $varsOk = $false }
      $perAppVars += $entry
    }
    $checks['RequiredVariables'] = [PSCustomObject]@{
      Ok     = ($apiReachable -and $varsOk)
      Detail = if (-not $apiReachable) { 'Skipped because ApiReachable failed' } elseif ($varsOk) { 'All required variables present' } else { 'One or more required variables are missing' }
      PerApp = $perAppVars
    }
    if (-not $checks['RequiredVariables'].Ok) { [void]$failures.Add('RequiredVariables') }

    $checks['MonitorsDeployed'] = [PSCustomObject]@{
      Ok      = $true
      Detail  = 'Not implemented; BuildMaster Native API does not expose a stable monitor-listing endpoint. TODO: verify CSharpPackage-RepositoryMonitors.otter and PowerShellModule-RepositoryMonitors.otter are deployed.'
      Skipped = $true
    }

    $result = [PSCustomObject]@{
      AllOk     = ($failures.Count -eq 0)
      Checks    = [PSCustomObject]$checks
      Failures  = $failures.ToArray()
      Timestamp = (Get-Date)
    }

    if ($ThrowOnFailure -and -not $result.AllOk) {
      $msg = "BuildMaster is not ready. Failing checks: $($result.Failures -join ', ')"
      $exception = [System.InvalidOperationException]::new($msg)
      $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $exception,
        'BuildMasterNotReadyException',
        [System.Management.Automation.ErrorCategory]::PermissionDenied,
        $result
      )
      $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
