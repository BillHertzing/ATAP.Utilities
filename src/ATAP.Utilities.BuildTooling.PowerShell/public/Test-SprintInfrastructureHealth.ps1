#Requires -Version 7.0

function Test-InfraUrlReachable {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [string]$Url,

    [Parameter()]
    [int]$TimeoutSeconds = 5,

    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  if ([string]::IsNullOrWhiteSpace($Url)) {
    return [PSCustomObject]@{
      Ok      = $true
      Detail  = "$Label base URL not supplied; reachability check skipped"
      Url     = $null
      Skipped = $true
    }
  }

  try {
    Write-PSFMessage -Level Debug -Message "Calling $Url" -Tag 'WebRequestCall'
    $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
    Write-PSFMessage -Level Debug -Message "Successfully returned from $Url" -Tag 'WebRequestCall'
    $code = [int]$response.StatusCode
    return [PSCustomObject]@{
      Ok      = ($code -lt 500)
      Detail  = "$Label HEAD $Url returned HTTP $code"
      Url     = $Url
      Skipped = $false
    }
  } catch {
    $code = $null
    if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $code = [int]$_.Exception.Response.StatusCode
    }
    if ($code -and $code -lt 500) {
      return [PSCustomObject]@{
        Ok      = $true
        Detail  = "$Label HEAD $Url returned HTTP $code (reachable; auth not asserted)"
        Url     = $Url
        Skipped = $false
      }
    }
    return [PSCustomObject]@{
      Ok      = $false
      Detail  = "$Label HEAD $Url failed: $($_.Exception.Message)"
      Url     = $Url
      Skipped = $false
    }
  }
}

function Test-SprintInfrastructureHealth {
  <#
.SYNOPSIS
    Verifies that the permanent host infrastructure required for sprint builds is healthy.

.DESCRIPTION
    Runs a read-only health check covering: Bitwarden-related environment variables,
    SQL Server instance connectivity, Flyway CLI availability, NBGV CLI availability,
    git safe.directory configuration for the ATAP.Utilities repo root, BuildMaster
    application existence, ProGet reachability, and BuildMaster reachability.

    This cmdlet is distinct from Test-SprintPrerequisites, which checks sprint-start
    working-tree state. Test-SprintInfrastructureHealth covers the permanent infrastructure
    of the host machine.

    Every check runs to completion regardless of earlier failures so the structured
    result captures the full diagnostic picture. The cmdlet always returns a
    [PSCustomObject]; with -ThrowOnFailure, it additionally throws a terminating error
    (FullyQualifiedErrorId: InfrastructureHealthFailedException) when AllOk is $false.

    Skipped checks always have Ok=$true so they do not block AllOk.

.PARAMETER BuildMasterBaseUrl
    Base URL for BuildMaster. Defaults to
    $global:settings[$global:configRootKeys['BuildMasterBaseUrlConfigRootKey']],
    then $env:BUILDMASTER_BASE_URL, then 'http://localhost:50017'.

.PARAMETER BuildMasterAdminApiKeySecretName
    The ATAP secret name containing the BuildMaster admin API key. Resolved via
    Get-PVal (parameter → env var → $global:settings → default
    'BuildMaster.Admin.API.Key'); the value is read with Get-SecretATAP. An
    unresolved key is reported by the BuildMasterApps check rather than thrown.

.PARAMETER ProGetBaseUrl
    Base URL for ProGet. Defaults to
    $global:settings[$global:configRootKeys['ProGetBaseUrlConfigRootKey']],
    then $env:PROGET_BASE_URL. Empty/null marks the check as Skipped (Ok=$true).

.PARAMETER SqlInstancePaths
    Optional override for SQL instance connection strings to test. When omitted,
    the cmdlet resolves paths from $global:settings via IntegrationSqlInstance,
    QASqlInstance, and ProductionSqlInstance keys. Falls back to empty array
    (SqlInstances check is Skipped).

.PARAMETER ReachabilityTimeoutSeconds
    HTTP timeout for reachability checks, and TCP timeout for SQL connection
    attempts. Default 5.

.PARAMETER ThrowOnFailure
    If supplied, throw a terminating error when AllOk is $false.

.OUTPUTS
    [PSCustomObject] with AllOk [bool], Checks [PSCustomObject], Failures [string[]],
    Timestamp [DateTime].

.EXAMPLE
    Test-SprintInfrastructureHealth | ConvertTo-Json -Depth 4

.EXAMPLE
    Test-SprintInfrastructureHealth -ThrowOnFailure

.NOTES
    AI assisted using Powershell.instructions.md as guidelines
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter()]
    [string]$BuildMasterBaseUrl,

    [Parameter()]
    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key',

    [Parameter()]
    [string]$ProGetBaseUrl,

    [Parameter()]
    [string[]]$SqlInstancePaths,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$ReachabilityTimeoutSeconds = 5,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Test-SprintInfrastructureHealth'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Resolve BuildMasterBaseUrl
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
        $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
      }
      if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
        $BuildMasterBaseUrl = [System.Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
      }
      if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
        $BuildMasterBaseUrl = 'http://localhost:50017'
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $BuildMasterBaseUrl = $BuildMasterBaseUrl.TrimEnd('/')
    }

    # Resolve the BuildMaster admin API key secret name, then retrieve the key
    # value via Get-SecretATAP. Non-fatal: an unresolved key is reported by the
    # BuildMasterApps check rather than thrown. The key value is never logged.
    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName
    $ApiKey = $null
    foreach ($fieldName in @($null, 'token', 'key', 'password')) {
      try {
        $candidate = if ($null -eq $fieldName) {
          Get-SecretATAP -BuildMasterAdminApiKeySecretName $BuildMasterAdminApiKeySecretName -ErrorAction Stop
        } else {
          Get-SecretATAP -BuildMasterAdminApiKeySecretName $BuildMasterAdminApiKeySecretName -SecretField $fieldName -ErrorAction Stop
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $ApiKey = [string]$candidate; break }
      } catch {
      }
    }

    # Resolve ProGetBaseUrl
    if (-not $PSBoundParameters.ContainsKey('ProGetBaseUrl')) {
      try {
        if ($global:configRootKeys -and $global:settings) {
          $k = $global:configRootKeys['ProGetBaseUrlConfigRootKey']
          if ($k -and $global:settings.ContainsKey($k)) {
            $ProGetBaseUrl = [string]$global:settings[$k]
          }
        }
      } catch { }
      if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
        $ProGetBaseUrl = [System.Environment]::GetEnvironmentVariable('PROGET_BASE_URL', 'User')
      }
      if ([string]::IsNullOrWhiteSpace($ProGetBaseUrl)) {
        $ProGetBaseUrl = [System.Environment]::GetEnvironmentVariable('PROGET_BASE_URL', 'Process')
      }
    }

    # Resolve SqlInstancePaths
    if (-not $PSBoundParameters.ContainsKey('SqlInstancePaths')) {
      $SqlInstancePaths = @()
      try {
        if ($global:configRootKeys -and $global:settings) {
          foreach ($sqlKey in @('IntegrationSqlInstanceConfigRootKey', 'QASqlInstanceConfigRootKey', 'ProductionSqlInstanceConfigRootKey')) {
            $k = $global:configRootKeys[$sqlKey]
            if ($k -and $global:settings.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace($global:settings[$k])) {
              $SqlInstancePaths += [string]$global:settings[$k]
            }
          }
        }
      } catch { }
    }
  }

  process {
    $checks = [ordered]@{}
    $failures = [System.Collections.Generic.List[string]]::new()

    # ── BitwardenEnvVars ──────────────────────────────────────────────────────
    $requiredEnvVars = @('PROGET_ADMIN_API_KEY', 'BW_SESSION', 'BUILDMASTER_GH_WEBHOOK_SECRET')
    $missingVars = [System.Collections.Generic.List[string]]::new()
    foreach ($varName in $requiredEnvVars) {
      $val = [System.Environment]::GetEnvironmentVariable($varName, 'User')
      if ([string]::IsNullOrWhiteSpace($val)) {
        $val = [System.Environment]::GetEnvironmentVariable($varName, 'Process')
      }
      if ([string]::IsNullOrWhiteSpace($val)) {
        [void]$missingVars.Add($varName)
      }
    }
    $bwVarsOk = ($missingVars.Count -eq 0)
    $bwVarsDetail = if ($bwVarsOk) {
      "All required env vars present: $($requiredEnvVars -join ', ')"
    } else {
      "Missing env var(s): $($missingVars -join ', ')"
    }
    $checks['BitwardenEnvVars'] = [PSCustomObject]@{
      Ok      = $bwVarsOk
      Detail  = $bwVarsDetail
      Missing = $missingVars.ToArray()
    }
    if (-not $bwVarsOk) { [void]$failures.Add('BitwardenEnvVars') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BitwardenEnvVars: $bwVarsDetail"

    # ── BuildMasterAdminApiKeyResolvable ──────────────────────────────────────
    $bmKeyOk = -not [string]::IsNullOrWhiteSpace($ApiKey)
    $checks['BuildMasterAdminApiKeyResolvable'] = [PSCustomObject]@{
      Ok         = $bmKeyOk
      Detail     = if ($bmKeyOk) {
        "BuildMaster admin API key resolved from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP"
      } else {
        "BuildMaster admin API key NOT resolvable from secret '$BuildMasterAdminApiKeySecretName' via Get-SecretATAP"
      }
      SecretName = $BuildMasterAdminApiKeySecretName
    }
    if (-not $bmKeyOk) { [void]$failures.Add('BuildMasterAdminApiKeyResolvable') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BuildMasterAdminApiKeyResolvable: $($checks['BuildMasterAdminApiKeyResolvable'].Detail)"

    # ── SqlInstances ─────────────────────────────────────────────────────────
    if ($null -eq $SqlInstancePaths -or $SqlInstancePaths.Count -eq 0) {
      $checks['SqlInstances'] = [PSCustomObject]@{
        Ok      = $true
        Detail  = 'No SQL instance paths configured; check skipped'
        Skipped = $true
        PerInstance = @()
      }
    } else {
      $perInstance = @()
      $sqlAllOk = $true
      foreach ($instancePath in $SqlInstancePaths) {
        $entry = [PSCustomObject]@{
          InstancePath = $instancePath
          Ok           = $false
          Detail       = ''
        }
        try {
          $connStr = "Data Source=$instancePath;Integrated Security=SSPI;Connect Timeout=$ReachabilityTimeoutSeconds"
          $conn = [System.Data.SqlClient.SqlConnection]::new($connStr)
          $conn.Open()
          $conn.Close()
          $conn.Dispose()
          $entry.Ok = $true
          $entry.Detail = "Connected successfully to $instancePath"
        } catch {
          $entry.Detail = "Connection to $instancePath failed: $($_.Exception.Message)"
          $sqlAllOk = $false
        }
        $perInstance += $entry
      }
      $checks['SqlInstances'] = [PSCustomObject]@{
        Ok          = $sqlAllOk
        Detail      = if ($sqlAllOk) { "All $($SqlInstancePaths.Count) SQL instance(s) reachable" } else { 'One or more SQL instances are unreachable' }
        Skipped     = $false
        PerInstance = $perInstance
      }
      if (-not $sqlAllOk) { [void]$failures.Add('SqlInstances') }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "SqlInstances: $($checks['SqlInstances'].Detail)"

    # ── FlywayAvailable ───────────────────────────────────────────────────────
    $flywayOk = $false
    $flywayDetail = ''
    $flywaySkipped = $false
    try {
      $flywayCmd = Get-Command -Name flyway -CommandType Application -ErrorAction Stop
      $flywayOutput = & $flywayCmd -v 2>&1
      if ($LASTEXITCODE -eq 0) {
        $flywayOk = $true
        $flywayDetail = "flyway available: $($flywayOutput | Select-Object -First 1)"
      } else {
        $flywayOutput2 = & $flywayCmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
          $flywayOk = $true
          $flywayDetail = "flyway available: $($flywayOutput2 | Select-Object -First 1)"
        } else {
          $flywayDetail = "flyway exited with code $LASTEXITCODE"
        }
      }
    } catch {
      $flywaySkipped = $true
      $flywayOk = $true
      $flywayDetail = 'flyway not found in PATH; check skipped'
    }
    $checks['FlywayAvailable'] = [PSCustomObject]@{
      Ok      = $flywayOk
      Detail  = $flywayDetail
      Skipped = $flywaySkipped
    }
    if (-not $flywayOk) { [void]$failures.Add('FlywayAvailable') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "FlywayAvailable: $flywayDetail"

    # ── NbgvAvailable ─────────────────────────────────────────────────────────
    $nbgvOk = $false
    $nbgvDetail = ''
    $nbgvSkipped = $false
    try {
      $nbgvCmd = Get-Command -Name nbgv -CommandType Application -ErrorAction Stop
      $nbgvOutput = & $nbgvCmd --version 2>&1
      if ($LASTEXITCODE -eq 0) {
        $nbgvOk = $true
        $nbgvDetail = "nbgv available: $($nbgvOutput | Select-Object -First 1)"
      } else {
        $nbgvDetail = "nbgv --version exited with code $LASTEXITCODE"
      }
    } catch {
      $nbgvSkipped = $true
      $nbgvOk = $true
      $nbgvDetail = 'nbgv not found in PATH; check skipped'
    }
    $checks['NbgvAvailable'] = [PSCustomObject]@{
      Ok      = $nbgvOk
      Detail  = $nbgvDetail
      Skipped = $nbgvSkipped
    }
    if (-not $nbgvOk) { [void]$failures.Add('NbgvAvailable') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "NbgvAvailable: $nbgvDetail"

    # ── GitSafeDirectory ──────────────────────────────────────────────────────
    $safeOk = $false
    $safeDetail = ''
    try {
      # Resolve the ATAP.Utilities repo root by walking up from the current location
      $repoRoot = $null
      try {
        if (Test-Path -LiteralPath 'Function:\Get-RepositoryRoot') {
          $repoRoot = Get-RepositoryRoot -ErrorAction SilentlyContinue
        }
      } catch { }
      if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        # Walk up from current directory to find .git
        $dir = (Get-Location).Path
        while (-not [string]::IsNullOrWhiteSpace($dir)) {
          if (Test-Path (Join-Path $dir '.git')) {
            $repoRoot = $dir
            break
          }
          $parent = Split-Path $dir -Parent
          if ($parent -eq $dir) { break }
          $dir = $parent
        }
      }

      $gitOutput = & git config --global safe.directory 2>&1
      $gitExitCode = $LASTEXITCODE
      $safeList = @($gitOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

      if ($null -ne $repoRoot -and $repoRoot -ne '') {
        $normalizedRoot = $repoRoot.Replace('\', '/')
        $matched = $safeList | Where-Object {
          $_.Replace('\', '/') -eq $normalizedRoot -or
          $_ -eq $repoRoot -or
          $_ -eq '*'
        }
        if ($matched) {
          $safeOk = $true
          $safeDetail = "git safe.directory contains repo root '$repoRoot'"
        } else {
          $safeDetail = "git safe.directory does not include repo root '$repoRoot'. Current safe.directory entries: $($safeList -join '; ')"
        }
      } else {
        # Could not determine repo root — report what we got
        if ($gitExitCode -eq 0 -and $safeList.Count -gt 0) {
          $safeOk = $true
          $safeDetail = "git safe.directory configured (repo root could not be determined); entries: $($safeList -join '; ')"
        } else {
          $safeDetail = 'Could not determine repo root and no git safe.directory entries found'
        }
      }
    } catch {
      $safeDetail = "GitSafeDirectory check failed: $($_.Exception.Message)"
    }
    $checks['GitSafeDirectory'] = [PSCustomObject]@{
      Ok     = $safeOk
      Detail = $safeDetail
    }
    if (-not $safeOk) { [void]$failures.Add('GitSafeDirectory') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "GitSafeDirectory: $safeDetail"

    # ── BuildMasterApps ───────────────────────────────────────────────────────
    $expectedApps = @('ATAP.Utilities-CSharp', 'ATAP.Utilities-PowerShell')
    if ([string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) {
      $checks['BuildMasterApps'] = [PSCustomObject]@{
        Ok      = $true
        Detail  = 'BuildMaster base URL not supplied; BuildMasterApps check skipped'
        Skipped = $true
        PerApp  = @()
      }
    } elseif ([string]::IsNullOrWhiteSpace($ApiKey)) {
      $checks['BuildMasterApps'] = [PSCustomObject]@{
        Ok      = $false
        Detail  = 'BuildMaster admin API key not resolvable via Get-SecretATAP; cannot check app existence'
        Skipped = $false
        PerApp  = @()
      }
      [void]$failures.Add('BuildMasterApps')
    } else {
      $appsUri = "$BuildMasterBaseUrl/api/applications/list"
      $appsOk = $false
      $appsDetail = ''
      $perApp = @()
      try {
        $headers = @{
          'X-ApiKey' = $ApiKey
          'Accept'   = 'application/json'
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $appsUri" -Tag 'RestCall'
        $appList = Invoke-RestMethod -Uri $appsUri -Method Get -Headers $headers -TimeoutSec $ReachabilityTimeoutSeconds -ErrorAction Stop
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $appsUri" -Tag 'RestCall'
        $appNames = @($appList | ForEach-Object {
          if ($_.PSObject.Properties['Application_Name']) { $_.Application_Name }
          elseif ($_.PSObject.Properties['name']) { $_.name }
          else { $_ }
        })
        $missingApps = @()
        $foundApps = @()
        foreach ($appName in $expectedApps) {
          $entry = [PSCustomObject]@{
            ApplicationName = $appName
            Ok              = ($appNames -contains $appName)
            Detail          = if ($appNames -contains $appName) { "Found" } else { "Not found in BuildMaster" }
          }
          if ($entry.Ok) { $foundApps += $appName } else { $missingApps += $appName }
          $perApp += $entry
        }
        if ($missingApps.Count -eq 0) {
          $appsOk = $true
          $appsDetail = "All expected app(s) present: $($foundApps -join ', ')"
        } else {
          $appsDetail = "Missing app(s): $($missingApps -join ', ')"
        }
      } catch {
        $appsDetail = "GET $appsUri failed: $($_.Exception.Message)"
      }
      $checks['BuildMasterApps'] = [PSCustomObject]@{
        Ok      = $appsOk
        Detail  = $appsDetail
        Skipped = $false
        PerApp  = $perApp
      }
      if (-not $appsOk) { [void]$failures.Add('BuildMasterApps') }
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BuildMasterApps: $($checks['BuildMasterApps'].Detail)"

    # ── ProGetReachable ───────────────────────────────────────────────────────
    $checks['ProGetReachable'] = Test-InfraUrlReachable -Url $ProGetBaseUrl -TimeoutSeconds $ReachabilityTimeoutSeconds -Label 'ProGet'
    if (-not $checks['ProGetReachable'].Ok) { [void]$failures.Add('ProGetReachable') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "ProGetReachable: $($checks['ProGetReachable'].Detail)"

    # ── BuildMasterReachable ──────────────────────────────────────────────────
    $checks['BuildMasterReachable'] = Test-InfraUrlReachable -Url $BuildMasterBaseUrl -TimeoutSeconds $ReachabilityTimeoutSeconds -Label 'BuildMaster'
    if (-not $checks['BuildMasterReachable'].Ok) { [void]$failures.Add('BuildMasterReachable') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "BuildMasterReachable: $($checks['BuildMasterReachable'].Detail)"

    # ── Assemble result ───────────────────────────────────────────────────────
    $result = [PSCustomObject]@{
      AllOk     = ($failures.Count -eq 0)
      Checks    = [PSCustomObject]$checks
      Failures  = $failures.ToArray()
      Timestamp = (Get-Date)
    }

    if ($ThrowOnFailure -and -not $result.AllOk) {
      $msg = "Infrastructure health check failed. Failing checks: $($result.Failures -join ', ')"
      $exception = [System.InvalidOperationException]::new($msg)
      $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $exception,
        'InfrastructureHealthFailedException',
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
