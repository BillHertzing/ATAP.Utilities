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
    Runs a read-only health check covering: prohibited secret-bearing environment variables,
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
    The Bitwarden secret name containing the BuildMaster admin API key. Defaults to
    'BuildMaster.Admin.API.Key'. The value is read via Get-SecretATAP with
    SecretField='notes' and SecretStoreType='BitwardenSecretsManager' (bws +
    machine access token; no BW_SESSION). An unresolved key is reported by the
    BuildMasterApps check rather than thrown.

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

    # Retrieve the BuildMaster admin API key from Bitwarden Secrets Manager via
    # Get-SecretATAP, forcing the BWS provider so this sprint-automation path
    # never depends on BW_SESSION (SC-0175). Non-fatal: an unresolved key is
    # reported by the BuildMasterApps check rather than thrown. The key value
    # is never logged.
    $ApiKey = $null
    try {
      $candidate = Get-SecretATAP -SecretName $BuildMasterAdminApiKeySecretName -SecretField 'notes' -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
      if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $ApiKey = [string]$candidate }
    } catch {
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

    # ── SecretEnvironmentVariables ────────────────────────────────────────────
    # Sprint automation resolves secret names through $global:settings/Get-PVal
    # and retrieves values from Bitwarden. Persistent Process/User/Machine API-key
    # variables create an untracked parallel configuration path and are prohibited.
    $prohibitedSecretEnvironmentVariables = @(
      'PROGET_ADMIN_API_KEY',
      'BUILDMASTER_ADMIN_API_KEY',
      'BUILDMASTER_GH_WEBHOOK_SECRET',
      'BWS_ACCESS_TOKEN',
      'BW_SESSION'
    )
    $presentSecretEnvironmentVariables = [System.Collections.Generic.List[object]]::new()
    foreach ($scope in @('Process', 'User', 'Machine')) {
      foreach ($varName in $prohibitedSecretEnvironmentVariables) {
        $value = [System.Environment]::GetEnvironmentVariable($varName, $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
          [void]$presentSecretEnvironmentVariables.Add([PSCustomObject]@{
              Name  = $varName
              Scope = $scope
            })
        }
      }
    }
    $secretEnvironmentOk = ($presentSecretEnvironmentVariables.Count -eq 0)
    $secretEnvironmentDetail = if ($secretEnvironmentOk) {
      'No prohibited secret-bearing environment variables are present.'
    } else {
      'Prohibited secret-bearing environment variable(s) are present: ' +
      (($presentSecretEnvironmentVariables | ForEach-Object { "$($_.Scope):$($_.Name)" }) -join ', ')
    }
    $checks['SecretEnvironmentVariables'] = [PSCustomObject]@{
      Ok      = $secretEnvironmentOk
      Detail  = $secretEnvironmentDetail
      Present = $presentSecretEnvironmentVariables.ToArray()
    }
    if (-not $secretEnvironmentOk) { [void]$failures.Add('SecretEnvironmentVariables') }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "SecretEnvironmentVariables: $secretEnvironmentDetail"

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
        Ok          = $true
        Detail      = 'No SQL instance paths configured; check skipped'
        Skipped     = $true
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
          # -Absolute is required inside a git worktree: there '.git' is a file
          # pointer rather than a directory, and the default relative-path return
          # (e.g. '..\repo-wt-...') never matches the absolute 'safe.directory'
          # entries this check compares against.
          if ((Get-Command Get-RepositoryRoot).Parameters.ContainsKey('Absolute')) {
            $repoRoot = Get-RepositoryRoot -Absolute -ErrorAction SilentlyContinue
          } else {
            $repoRoot = Get-RepositoryRoot -ErrorAction SilentlyContinue
          }
        }
      } catch { }
      if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        # Walk up from current directory to find .git (file OR directory)
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

      # Defensive: if any path source yielded a relative path, resolve it to an
      # absolute path (against the current location) so the comparison below is
      # always absolute-vs-absolute.
      if (-not [string]::IsNullOrWhiteSpace($repoRoot)) {
        try {
          $resolvedRoot = Resolve-Path -LiteralPath $repoRoot -ErrorAction SilentlyContinue
          if ($resolvedRoot) { $repoRoot = $resolvedRoot.Path }
        } catch { }
      }

      # --get-all is required: safe.directory is multi-valued, and the plain
      # 'git config --global safe.directory' form silently returns only the
      # LAST-added entry, causing a false failure for every earlier repo root.
      $gitOutput = & git config --global --get-all safe.directory 2>&1
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
            Detail          = if ($appNames -contains $appName) { 'Found' } else { 'Not found in BuildMaster' }
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
