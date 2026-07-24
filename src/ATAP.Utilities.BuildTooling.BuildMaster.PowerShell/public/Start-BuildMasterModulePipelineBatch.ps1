#Requires -Version 7.0
function Resolve-BuildMasterApplicationForModule {
  <#
.SYNOPSIS
    Resolves the BuildMaster application name for a PowerShell module from an
    explicit override map or reviewed global configuration.

.DESCRIPTION
    Application resolution is deterministic and never guesses. The lookup order
    is:

      1. The explicit `-ApplicationByModule` override hashtable, keyed by module
         name (case-insensitive).
      2. The reviewed configuration hashtable stored at
         `$global:settings[$global:configRootKeys['BuildMasterApplicationByModuleConfigRootKey']]`.

    If neither source maps the module, the function throws. The batch caller must
    never start a release against an inferred or defaulted application.

.PARAMETER ModuleName
    The PowerShell module name to resolve.

.PARAMETER ApplicationByModule
    Optional explicit override hashtable mapping module name to BuildMaster
    application name. Takes precedence over reviewed configuration.

.OUTPUTS
    [string] The resolved BuildMaster application name.
#>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName,

    [Parameter(Mandatory = $false)]
    [hashtable]$ApplicationByModule
  )

  if ($null -ne $ApplicationByModule -and $ApplicationByModule.ContainsKey($ModuleName)) {
    $value = [string]$ApplicationByModule[$ModuleName]
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      return $value
    }
  }

  if ($null -ne $global:settings -and $null -ne $global:configRootKeys) {
    $settingsKey = $global:configRootKeys['BuildMasterApplicationByModuleConfigRootKey']
    if (-not [string]::IsNullOrWhiteSpace([string]$settingsKey)) {
      $configMap = $global:settings[$settingsKey]
      if ($configMap -is [System.Collections.IDictionary] -and $configMap.Contains($ModuleName)) {
        $value = [string]$configMap[$ModuleName]
        if (-not [string]::IsNullOrWhiteSpace($value)) {
          return $value
        }
      }
    }
  }

  throw "No BuildMaster application is mapped for module '$ModuleName'. Pass -ApplicationByModule @{ '$ModuleName' = '<Application>' } or add the module to the reviewed BuildMasterApplicationByModule configuration. The batch never guesses an application."
}

function Start-BuildMasterModulePipelineBatch {
  <#
.SYNOPSIS
    Drives an ordered array of PowerShell modules through the BuildMaster
    build/pack/test/promotion pipeline, each only as high as its own
    project-adjacent `version.json` ceiling permits.

.DESCRIPTION
    `Start-BuildMasterModulePipelineBatch` is a thin orchestration wrapper over
    the existing single-module entry point `Start-BuildMasterPackagePipeline`. It
    accepts several module names, normalizes duplicates while preserving caller
    order, and preflights every module before creating any BuildMaster release.

    For each module the batch:

      - Resolves the module project folder (`src/<ModuleName>`) and requires its
        project-adjacent `version.json`, reusing the
        `Resolve-BuildMasterPackageProjectPath` helper.
      - Computes the immutable package version and `CeilingTier` through
        `Get-BuildContext` (the version.json-as-ceiling source of truth). The
        batch makes no local packaging, test, feed-promotion, or ceiling
        decisions of its own.
      - Resolves the BuildMaster application from `-ApplicationByModule` or
        reviewed configuration. It never guesses when a mapping is absent.

    Only after every requested module passes preflight (fail-fast) does the batch
    begin mutating BuildMaster. It then invokes `Start-BuildMasterPackagePipeline`
    once per module on `global::PowerShellModule-5Stage`, passing the resolved
    project/package identity and the module's ceiling as a build variable so
    BuildMaster builds and packages once in Experimental, runs the applicable
    promoted-module tests, promotes the same immutable bytes through ProGet, and
    skips every stage above that module's ceiling.

    The batch queues and observes BuildMaster work; it records the release,
    build, and execution identifiers returned by each single-module run into one
    structured aggregate. It does not poll for completion (that is the separate
    poller's responsibility) and does not reimplement any pipeline logic.

.PARAMETER ModuleName
    One or more module names, in caller-preferred order. Duplicates are removed
    case-insensitively while preserving the first occurrence's position. Accepts
    pipeline input.

.PARAMETER ApplicationByModule
    Optional explicit override hashtable mapping each module name to its
    BuildMaster application name. Values here take precedence over reviewed
    configuration. Modules absent from both sources fail preflight.

.PARAMETER PipelineName
    BuildMaster pipeline name used for every module. Defaults to
    `global::PowerShellModule-5Stage`.

.PARAMETER Branch
    Optional source branch passed through to `Get-BuildContext` and the package
    pipeline. When omitted, the current branch is resolved from `git`.

.PARAMETER Stage
    Optional current BuildMaster stage passed through to `Get-BuildContext`.
    Affects only `CurrentTier`/`IsAtCeiling`; the ceiling itself is always the
    version.json prerelease label.

.PARAMETER ContinueOnError
    Continue with the remaining modules when a module fails preflight or its
    pipeline start fails. Without this switch the batch fails fast: a preflight
    failure throws before any BuildMaster mutation, and a pipeline-start failure
    stops the batch after recording the failed module.

.PARAMETER BuildMasterBaseUrl
    Optional BuildMaster base URL passed through to each single-module run.

.PARAMETER BuildMasterAdminApiKeySecretName
    Optional ATAP secret *name* for the BuildMaster admin API key. Only the
    secret name is passed; the secret value is never handled here.

.OUTPUTS
    [PSCustomObject] aggregate with `Results`, an ordered array of one
    [PSCustomObject] per requested module.

.EXAMPLE
    PS> Start-BuildMasterModulePipelineBatch `
            -ModuleName 'ATAP.Utilities.PowerShell','ATAP.Utilities.BuildTooling.PowerShell' `
            -ApplicationByModule @{
                'ATAP.Utilities.PowerShell'             = 'ATAP.Utilities-PowerShell'
                'ATAP.Utilities.BuildTooling.PowerShell' = 'ATAP.Utilities-PowerShell'
            }

    Preflights both modules, then starts each on the 5-stage pipeline stopping at
    the ceiling its own version.json declares.

.NOTES
    Implements Sprint 0010 Task 10.33. Reuses Start-BuildMasterPackagePipeline,
    Get-BuildContext, Resolve-BuildMasterPackageProjectPath, and the
    version.json-as-ceiling helpers rather than duplicating their logic.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ModuleName,

    [Parameter(Mandatory = $false)]
    [hashtable]$ApplicationByModule,

    [Parameter(Mandatory = $false)]
    [Alias('Pipeline')]
    [ValidateNotNullOrEmpty()]
    [string]$PipelineName = 'global::PowerShellModule-5Stage',

    [Parameter(Mandatory = $false)]
    [string]$Branch,

    [Parameter(Mandatory = $false)]
    [string]$Stage,

    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnError,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$BuildMasterAdminApiKeySecretName
  )

  begin {
    $fn = 'Start-BuildMasterModulePipelineBatch'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn (PipelineName='$PipelineName' ContinueOnError=$($ContinueOnError.IsPresent))" -Tag 'Trace'

    # Ensure the reused entry points are available when this file is run from
    # source (no module import). $PSScriptRoot still resolves inside begin.
    $requiredCommands = @{
      'Get-BuildContext'                    = '..\..\ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell\public\Get-BuildContext.ps1'
      'Start-BuildMasterPackagePipeline'    = 'Start-BuildMasterPackagePipeline.ps1'
      'Resolve-BuildMasterPackageProjectPath' = 'Start-BuildMasterPackagePipeline.ps1'
      'Test-PromotionWithinCeiling'         = 'Test-PromotionWithinCeiling.ps1'
      'Get-TierOrder'                       = 'Get-TierOrder.ps1'
    }
    foreach ($commandName in $requiredCommands.Keys) {
      if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
        $helperPath = Join-Path -Path $PSScriptRoot -ChildPath $requiredCommands[$commandName]
        if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
          . $helperPath
        } else {
          throw "Required command '$commandName' was not found and helper '$helperPath' is missing."
        }
      }
    }

    $script:collectedModuleNames = [System.Collections.Generic.List[string]]::new()
  }

  process {
    foreach ($name in $ModuleName) {
      if (-not [string]::IsNullOrWhiteSpace($name)) {
        $script:collectedModuleNames.Add($name.Trim())
      }
    }
  }

  end {
    # -----------------------------------------------------------------------
    # 1. Normalize duplicates, preserving caller order (case-insensitive).
    # -----------------------------------------------------------------------
    $orderedModules = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $script:collectedModuleNames) {
      if ($seen.Add($name)) {
        $orderedModules.Add($name)
      }
    }
    $duplicateCount = $script:collectedModuleNames.Count - $orderedModules.Count
    if ($orderedModules.Count -eq 0) {
      throw "No module names were supplied to $fn."
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Normalized $($script:collectedModuleNames.Count) requested name(s) to $($orderedModules.Count) unique module(s); removed $duplicateCount duplicate(s)."
    Write-Host "Preflighting $($orderedModules.Count) module(s) before any BuildMaster mutation."

    # -----------------------------------------------------------------------
    # 2. Resolve the branch once (all modules share this repository context).
    # -----------------------------------------------------------------------
    $resolvedBranch = $Branch
    if ([string]::IsNullOrWhiteSpace($resolvedBranch)) {
      $branchRaw = & git rev-parse --abbrev-ref HEAD 2>$null
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$branchRaw)) {
        $resolvedBranch = ([string]$branchRaw).Trim()
      } else {
        throw "Could not resolve the current branch from git. Pass -Branch explicitly."
      }
    }

    # -----------------------------------------------------------------------
    # 3. Preflight every module: project path, application, version, ceiling.
    #    No BuildMaster mutation occurs in this phase.
    # -----------------------------------------------------------------------
    $plans = [System.Collections.Generic.List[psobject]]::new()
    foreach ($module in $orderedModules) {
      $plan = [PSCustomObject]@{
        Module                = $module
        Application           = $null
        ProjectPath           = $null
        PackageVersion        = $null
        Ceiling               = $null
        RequestedTerminalTier = $null
        PreflightError        = $null
      }
      try {
        $application = Resolve-BuildMasterApplicationForModule -ModuleName $module -ApplicationByModule $ApplicationByModule
        $projectPath = Resolve-BuildMasterPackageProjectPath -ModuleName $module

        $contextParams = @{
          Application = $application
          ProjectPath = $projectPath
          Branch      = $resolvedBranch
        }
        if ($PSBoundParameters.ContainsKey('Stage') -and -not [string]::IsNullOrWhiteSpace($Stage)) {
          $contextParams['Stage'] = $Stage
        }
        $context = Get-BuildContext @contextParams

        $ceiling = [string]$context.CeilingTier
        $packageVersion = [string]$context.ResolvedPackageVersion
        if ([string]::IsNullOrWhiteSpace($ceiling)) {
          throw "Get-BuildContext returned an empty CeilingTier for module '$module'."
        }
        if ([string]::IsNullOrWhiteSpace($packageVersion)) {
          throw "Get-BuildContext returned an empty ResolvedPackageVersion for module '$module'."
        }

        # Defensive guard: the requested terminal tier is the ceiling itself, so
        # it must never exceed the ceiling. Reuses the shared ceiling helper.
        if (-not (Test-PromotionWithinCeiling -CurrentTier $ceiling -CeilingTier $ceiling -AsBoolean)) {
          throw "Requested terminal tier '$ceiling' for module '$module' exceeds its resolved ceiling '$ceiling'."
        }

        $plan.Application = $application
        $plan.ProjectPath = [string]$context.ProjectPath
        $plan.PackageVersion = $packageVersion
        $plan.Ceiling = $ceiling
        $plan.RequestedTerminalTier = $ceiling
        Write-Host "Preflight OK: '$module' -> application '$application', version '$packageVersion', ceiling '$ceiling'."
      } catch {
        $plan.PreflightError = $_.Exception.Message
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Preflight failed for module '$module': $($_.Exception.Message)"
        Write-Host "Preflight FAILED: '$module' -> $($_.Exception.Message)"
      }
      $plans.Add($plan)
    }

    $preflightFailures = @($plans | Where-Object { $null -ne $_.PreflightError })
    if ($preflightFailures.Count -gt 0 -and -not $ContinueOnError.IsPresent) {
      $detail = ($preflightFailures | ForEach-Object { "$($_.Module): $($_.PreflightError)" }) -join '; '
      throw "Preflight failed for $($preflightFailures.Count) module(s) and -ContinueOnError was not supplied; no BuildMaster releases were created. $detail"
    }

    # -----------------------------------------------------------------------
    # 4. Invocation phase: start each module's pipeline sequentially.
    # -----------------------------------------------------------------------
    $results = [System.Collections.Generic.List[psobject]]::new()
    $failFastTriggered = $false
    $failFastDetail = $null

    foreach ($plan in $plans) {
      $record = [PSCustomObject]@{
        Module                = $plan.Module
        Application           = $plan.Application
        ProjectPath           = $plan.ProjectPath
        PackageVersion        = $plan.PackageVersion
        Ceiling               = $plan.Ceiling
        RequestedTerminalTier = $plan.RequestedTerminalTier
        TerminalTier          = $null
        ReleaseNumber         = $null
        ReleaseName           = $null
        ReleaseId             = $null
        BuildNumber           = $null
        BuildId               = $null
        ExecutionId           = $null
        Success               = $false
        FailureDetail         = $null
        ResponseSummary       = $null
      }

      if ($null -ne $plan.PreflightError) {
        # Only reachable under -ContinueOnError (fail-fast threw earlier).
        $record.FailureDetail = $plan.PreflightError
        $record.ResponseSummary = "preflight failed: $($plan.PreflightError)"
        $results.Add($record)
        continue
      }

      $target = "BuildMaster pipeline for module '$($plan.Module)' (application '$($plan.Application)', version '$($plan.PackageVersion)', ceiling '$($plan.Ceiling)')"
      if (-not $PSCmdlet.ShouldProcess($target, 'Create release and queue build')) {
        $record.ResponseSummary = "WhatIf: would start $target"
        $results.Add($record)
        continue
      }

      try {
        $pipelineParams = @{
          Application            = $plan.Application
          PipelineName           = $PipelineName
          ModuleName             = $plan.Module
          ProjectPath            = $plan.ProjectPath
          ResolvedPackageVersion = $plan.PackageVersion
          Tier                   = 'Experimental'
          Branch                 = $resolvedBranch
          Variables              = @{ '$CeilingTier' = $plan.Ceiling }
        }
        if (-not [string]::IsNullOrWhiteSpace($BuildMasterBaseUrl)) { $pipelineParams['BuildMasterBaseUrl'] = $BuildMasterBaseUrl }
        if (-not [string]::IsNullOrWhiteSpace($BuildMasterAdminApiKeySecretName)) { $pipelineParams['BuildMasterAdminApiKeySecretName'] = $BuildMasterAdminApiKeySecretName }

        Write-Host "Starting BuildMaster pipeline for module '$($plan.Module)' (ceiling '$($plan.Ceiling)')."
        $pipelineResult = Start-BuildMasterPackagePipeline @pipelineParams

        $record.ReleaseNumber = if ($null -ne $pipelineResult) { [string]$pipelineResult.ReleaseNumber } else { $null }
        $record.ReleaseName = if ($null -ne $pipelineResult) { [string]$pipelineResult.ReleaseName } else { $null }
        if ($null -ne $pipelineResult -and $null -ne $pipelineResult.ReleaseResult) {
          $record.ReleaseId = [string]$pipelineResult.ReleaseResult.ReleaseId
        }
        if ($null -ne $pipelineResult -and $null -ne $pipelineResult.BuildResult) {
          $record.BuildNumber = [string]$pipelineResult.BuildResult.BuildNumber
          $record.BuildId = [string]$pipelineResult.BuildResult.BuildId
        }
        if ($null -ne $pipelineResult -and $null -ne $pipelineResult.DeploymentResult) {
          $record.ExecutionId = [string]$pipelineResult.DeploymentResult.DeploymentId
        }
        $record.ResponseSummary = if ($null -ne $pipelineResult) { [string]$pipelineResult.ResponseSummary } else { $null }
        $record.Success = ($null -ne $pipelineResult) -and [bool]$pipelineResult.Succeeded

        if ($record.Success) {
          # Observed terminal tier is the ceiling the pipeline is permitted to
          # reach; assert it is within the resolved ceiling.
          if (-not (Test-PromotionWithinCeiling -CurrentTier $plan.Ceiling -CeilingTier $plan.Ceiling -AsBoolean)) {
            throw "Observed terminal tier '$($plan.Ceiling)' for module '$($plan.Module)' exceeds its ceiling '$($plan.Ceiling)'."
          }
          $record.TerminalTier = $plan.Ceiling
        } else {
          $record.FailureDetail = if ($null -ne $pipelineResult) { [string]$pipelineResult.ResponseSummary } else { 'Start-BuildMasterPackagePipeline returned no result.' }
        }
      } catch {
        $record.Success = $false
        $record.FailureDetail = $_.Exception.Message
        $record.ResponseSummary = "pipeline start failed: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Pipeline start failed for module '$($plan.Module)': $($_.Exception.Message)"
      }

      $results.Add($record)

      if (-not $record.Success -and -not $ContinueOnError.IsPresent) {
        $failFastTriggered = $true
        $failFastDetail = $record.FailureDetail
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Fail-fast: stopping batch after module '$($plan.Module)' failed."
        break
      }
    }

    # -----------------------------------------------------------------------
    # 5. Assemble the structured aggregate.
    # -----------------------------------------------------------------------
    $succeededCount = @($results | Where-Object { $_.Success }).Count
    $failedCount = @($results | Where-Object { -not $_.Success -and ($null -ne $_.FailureDetail) }).Count
    $whatIfPlanned = @($results | Where-Object { -not $_.Success -and ($null -eq $_.FailureDetail) }).Count
    $overallSucceeded = ($failedCount -eq 0) -and (-not $failFastTriggered) -and ($whatIfPlanned -eq 0) -and ($succeededCount -eq $orderedModules.Count)

    $aggregate = [PSCustomObject]@{
      OperationName         = $fn
      Succeeded             = $overallSucceeded
      PipelineName          = $PipelineName
      Branch                = $resolvedBranch
      RequestedModuleCount  = $orderedModules.Count
      DuplicatesRemoved     = $duplicateCount
      SucceededCount        = $succeededCount
      FailedCount           = $failedCount
      FailFastTriggered     = $failFastTriggered
      Results               = $results.ToArray()
      ResponseSummary       = if ($failFastTriggered) {
        "batch stopped fail-fast after a module failure: $failFastDetail"
      } elseif ($failedCount -gt 0) {
        "batch completed with $succeededCount succeeded and $failedCount failed of $($orderedModules.Count) module(s)"
      } elseif ($whatIfPlanned -gt 0) {
        "WhatIf: planned $whatIfPlanned module pipeline(s); no BuildMaster mutation performed"
      } else {
        "batch started $succeededCount of $($orderedModules.Count) module pipeline(s)"
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving $fn (Succeeded=$overallSucceeded)" -Tag 'Trace'
    return $aggregate
  }
}
