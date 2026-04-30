# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Invokes Invoke-Build against a module.build.ps1 orchestrator with automatic retry.

.DESCRIPTION
For each ProjectPath, validates that the folder is a well-formed ATAP.Utilities
PowerShell module (contains <FolderName>.psm1 and <FolderName>.psd1), resolves the
5-tier promotion tier from Nerdbank.GitVersioning when -Tier is not supplied, then
sets the working directory to that folder and calls Invoke-Build. Invoke-Build walks
up the folder hierarchy until it finds the source-of-truth *.build.ps1 (typically
module.build.ps1 at the repo root), so this function no longer locates the build
script itself.

On PSResourceGet-not-found failures, attempts to install Microsoft.PowerShell.PSResourceGet
and retries. On transient network errors, retries up to MaxRetries times.

All build output is captured to a transcript under PSModuleBuildLogs in the generated
artifacts folder (SC-0033).

.PARAMETER ProjectPath
One or more paths to a PowerShell module folder. Each folder must contain a .psm1
and a .psd1 file whose base names match each other and the folder name (ATAP.Utilities
opinionated architecture). Accepts a single string, an array of strings, a
System.IO.DirectoryInfo object (e.g. from Get-ChildItem -Directory), or any piped/bound
object with a ProjectPath or FullName property. Pipeline-enabled.

.PARAMETER Configuration
UNUSED — reserved for future multi-configuration PowerShell module builds.
Valid values: Debug, ReleaseWithTrace, Release. Defaults to @('Release').

.PARAMETER Tier
The 5-tier promotion tier: Sprint, Alpha, Beta, QA, or Production. When omitted,
the tier is resolved automatically from the NBGV prerelease label returned by
`nbgv get-version --variable NuGetPackageVersion`.

.PARAMETER Task
The Invoke-Build task to execute. Valid values correspond to the chains and tasks
defined in module.build.ps1: Short, Verify, All, CI, Local, Clean, Publish.
Defaults to 'Publish'.

.PARAMETER SkipPublish
When set, passes -SkipPublish to module.build.ps1, suppressing the final push to
the ProGet PowerShellGet feed. Useful for local verification runs.

.PARAMETER MaxRetries
Maximum number of retry attempts after a PSResourceGet or network failure. Defaults to 1.

.PARAMETER BuildLogPath
Optional path for the transcript log directory. Transcript files are written as
<ProjectName>_<Task>_<Timestamp>.log inside this directory.
When omitted the path is auto-computed as:
  <GeneratedRelativePath>\PSModuleBuildLogs\<ProjectName>

.INPUTS
System.String, System.String[], System.IO.FileInfo, System.IO.FileInfo[]
Pipeline objects with a ProjectPath or FullName property are also accepted.

.OUTPUTS
PSCustomObject[] — one result object per resolved path, each with:
Project (string), Task (string), Tier (string), ExitCode (int), BuildOutput (string[]), RetryCount (int)

.EXAMPLE
Invoke-ModuleBuildWithRetry -ProjectPath 'C:\Repos\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell'

Publishes the BuildTooling module at the NBGV-derived tier with default retry.

.EXAMPLE
Get-ChildItem -Path 'C:\Repos\ATAP.Utilities\src' -Directory -Filter 'ATAP.Utilities.*.PowerShell' |
    Invoke-ModuleBuildWithRetry -Task All -MaxRetries 2

Runs the All chain for every PowerShell module folder under src/, retrying twice.

.EXAMPLE
Invoke-ModuleBuildWithRetry -ProjectPath 'C:\Repos\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell' -Tier Alpha -SkipPublish -WhatIf

Dry run — shows what Invoke-Build call would be made without executing it.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Tier is resolved from NBGV in the working directory at call time when -Tier is not supplied.
Only Microsoft.PowerShell.PSResourceGet installation is attempted on retry — the full
Invoke-Build task is re-invoked from the start, not individual sub-steps within it.
The source-of-truth *.build.ps1 (typically module.build.ps1 at the repo root) is located
by Invoke-Build's walk-up search; this function only sets the working directory.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Invoke-ModuleBuildWithRetry {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [object[]] $ProjectPath,

    # UNUSED — reserved for future multi-configuration PS module builds.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Debug', 'ReleaseWithTrace', 'Release')]
    [string[]] $Configuration = @('Release'),

    [Parameter(Mandatory = $false)]
    [string] $Tier,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Short', 'Verify', 'All', 'CI', 'Local', 'Clean', 'Publish')]
    [string] $Task = 'Publish',

    [Parameter(Mandatory = $false)]
    [switch] $SkipPublish,

    [Parameter(Mandatory = $false)]
    [int] $MaxRetries = 1,

    [Parameter(Mandatory = $false)]
    [string] $BuildLogPath
  )

  begin {
    $fn = 'Invoke-ModuleBuildWithRetry'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
    } catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet: "Check and populate simple parameter as Type" for every parameter.
    # Note: $ProjectPath is pipeline-bound (ValueFromPipeline), so in begin{} $PSBoundParameters will
    # not yet hold per-element pipeline values; path normalization in process{} owns the pipeline path.
    # $Tier and $Task are excluded: both have ValidateSet constraints and Get-PVal can return an empty
    # string from a config lookup that violates the constraint. $Tier is also NBGV-derived; $Task has
    # a meaningful default ('Publish') that should not be overridden by the config system.
    $ProjectPath = Get-PVal -ParameterName 'ProjectPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ProjectPath' -DefaultValue $ProjectPath -AsType ([object[]])
    $Configuration = Get-PVal -ParameterName 'Configuration' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Configuration' -DefaultValue $Configuration -AsType ([string[]])
    $MaxRetries = Get-PVal -ParameterName 'MaxRetries' -originalPSBoundParameters $PSBoundParameters -dottedPath 'MaxRetries' -DefaultValue $MaxRetries -AsType ([int])
    $BuildLogPath = Get-PVal -ParameterName 'BuildLogPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'BuildLogPath' -DefaultValue $BuildLogPath -AsType ([string])

    # Verify Invoke-Build is available once for all pipeline inputs.
    if (-not (Get-Command -Name 'Invoke-Build' -ErrorAction SilentlyContinue)) {
      $errorMessage = 'Invoke-Build is not available. Install it with: Install-Module InvokeBuild -Scope CurrentUser'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # Resolve Tier from NBGV once for all inputs when caller does not supply it.
    $resolvedTierGlobal = $Tier
    if ([string]::IsNullOrEmpty($resolvedTierGlobal)) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Calling nbgv get-version --variable NuGetPackageVersion' -Tag 'InvokeExpressionCall'
        $nbgvOutput = & nbgv get-version --variable NuGetPackageVersion 2>&1
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Successfully returned from nbgv get-version --variable NuGetPackageVersion' -Tag 'InvokeExpressionCall'
        if ($LASTEXITCODE -ne 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "NBGV exited with code $LASTEXITCODE; defaulting Tier to 'Alpha'."
          $resolvedTierGlobal = 'Alpha'
        } else {
          $prereleaseLabel = if ($nbgvOutput -match '^[0-9]+\.[0-9]+\.[0-9]+-?([A-Za-z]*)') { $Matches[1] } else { '' }
          $resolvedTierGlobal = switch ($prereleaseLabel) {
            'Sprint' { 'Sprint' }
            'Alpha'  { 'Alpha' }
            'Beta'   { 'Beta' }
            'QA'     { 'QA' }
            default  { 'Production' }
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "NBGV label='$prereleaseLabel'  resolved Tier=$resolvedTierGlobal"
        }
      } catch {
        $errorMessage = "NBGV tier resolution failed. Exception: $($_.Exception.Message). Defaulting to 'Alpha'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $errorMessage
        $resolvedTierGlobal = 'Alpha'
      }
    }

    # Patterns that identify specific retryable failure categories.
    $psResourceGetMissingPattern = 'PSResourceGet|Microsoft\.PowerShell\.PSResourceGet|Publish-PSResource.*not recognized|could not find.*PSResourceGet'
    $networkErrorPattern = 'Unable to connect|The remote name could not be resolved|SocketException|TimeoutException|503 Service Unavailable|502 Bad Gateway'
  }

  process {
    # Normalize input: accept [string], [string[]], [System.IO.FileInfo], [System.IO.FileInfo[]],
    # or any object with a FullName property (e.g. pipeline output from Get-ChildItem).
    # Each pipeline bind delivers one element at a time; direct array args arrive all at once.
    # Resolve against $PWD.ProviderPath, not the single-arg GetFullPath overload:
    # pwsh's Set-Location does not sync [Environment]::CurrentDirectory, so the
    # single-arg form resolves relative inputs against the process start directory
    # (often C:\Users\<user>) instead of the user's actual location.
    $resolvedPaths = @(
      $ProjectPath | ForEach-Object {
        $raw = if ($_ -is [System.IO.FileSystemInfo]) { $_.FullName } else { [string]$_ }
        [System.IO.Path]::GetFullPath($raw, $PWD.ProviderPath)
      }
    )

    foreach ($CurrentPath in $resolvedPaths) {

      $result = [PSCustomObject]@{
        Project     = $CurrentPath
        Task        = $Task
        Tier        = $resolvedTierGlobal
        ExitCode    = -1
        BuildOutput = @()
        RetryCount  = 0
      }

      # -----------------------------------------------------------------------
      # Validate ProjectPath folder structure (guardrail).
      # ATAP.Utilities convention: module folder contains <FolderName>.psm1 and
      # <FolderName>.psd1. Invoke-Build itself walks up from this folder until
      # it finds the source-of-truth *.build.ps1 (module.build.ps1 at repo root),
      # so this function no longer locates the build script.
      # -----------------------------------------------------------------------
      if (-not (Test-Path -LiteralPath $CurrentPath -PathType Container)) {
        $errorMessage = "ProjectPath '$CurrentPath' does not exist or is not a directory."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.ExitCode = 1
        $result.BuildOutput = @($errorMessage)
        $result
        continue
      }

      $moduleRoot = $CurrentPath
      $moduleName = Split-Path $moduleRoot -Leaf

      $expectedPsm1 = Join-Path $moduleRoot "$moduleName.psm1"
      $expectedPsd1 = Join-Path $moduleRoot "$moduleName.psd1"

      if (-not (Test-Path -LiteralPath $expectedPsm1 -PathType Leaf)) {
        $errorMessage = "ProjectPath '$moduleRoot' is missing expected module file '$moduleName.psm1' (folder name must match module file base name)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.ExitCode = 1
        $result.BuildOutput = @($errorMessage)
        $result
        continue
      }

      if (-not (Test-Path -LiteralPath $expectedPsd1 -PathType Leaf)) {
        $errorMessage = "ProjectPath '$moduleRoot' is missing expected manifest file '$moduleName.psd1' (folder name must match manifest base name)."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.ExitCode = 1
        $result.BuildOutput = @($errorMessage)
        $result
        continue
      }

      $result.Project = $moduleRoot

      # -----------------------------------------------------------------------
      # Resolve transcript log path (SC-0033: generated artifacts under _generated/)
      # -----------------------------------------------------------------------
      $resolvedBuildLogPath = if (-not [string]::IsNullOrEmpty($BuildLogPath)) {
        $BuildLogPath
      } else {
        $generatedRelPath = $null
        if ($null -ne $global:configRootKeys -and $null -ne $global:settings) {
          $generatedKey = $global:configRootKeys['GeneratedRelativePathConfigRootKey']
          if (-not [string]::IsNullOrEmpty($generatedKey)) {
            $generatedRelPath = $global:settings[$generatedKey]
          }
        }
        if ([string]::IsNullOrEmpty($generatedRelPath)) {
          # Fall back to <moduleRoot>\_generated per SC-0033 so transcripts still land
          # under a _generated folder even when globals are not initialized.
          $generatedRelPath = Join-Path (Split-Path -Parent $moduleRoot) '_generated'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message (
            'GeneratedRelativePath is not populated in $global:settings; ' +
            "falling back to '$generatedRelPath' for transcript output."
          )
        }
        Join-Path $generatedRelPath 'PSModuleBuildLogs' $moduleName
      }

      if (-not (Test-Path $resolvedBuildLogPath)) {
        New-Item -ItemType Directory -Path $resolvedBuildLogPath -Force | Out-Null
      }

      $timestamp = (Get-Date -Format 'yyyyMMdd_HHmmss')
      $transcriptFile = Join-Path $resolvedBuildLogPath "${moduleName}_${Task}_${timestamp}.log"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Transcript will be written to '$transcriptFile'"

      # -----------------------------------------------------------------------
      # WhatIf path
      # -----------------------------------------------------------------------
      if ($WhatIfPreference) {
        $skipArg = if ($SkipPublish.IsPresent) { ' -SkipPublish' } else { '' }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
          "What if: Push-Location '$moduleRoot'; Invoke-Build $Task -Tier $resolvedTierGlobal$skipArg (build script resolved by Invoke-Build walk-up). " +
          "Transcript: '$transcriptFile'. " +
          "Would retry up to $MaxRetries time(s) on PSResourceGet/network failures."
        )
        $result.ExitCode = 0
        $result
        continue
      }

      # -----------------------------------------------------------------------
      # Build phase with retry
      # -----------------------------------------------------------------------
      $retryCount = 0
      $buildSuccess = $false

      while (-not $buildSuccess -and $retryCount -le $MaxRetries) {

        if ($retryCount -gt 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Retry $retryCount of $MaxRetries for module '$moduleName'."
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message (
          "Invoke-Build $Task -Tier $resolvedTierGlobal in '$moduleRoot' " +
          "(attempt $($retryCount + 1) of $($MaxRetries + 1))"
        )

        try {
          Start-Transcript -Path $transcriptFile -Append -ErrorAction SilentlyContinue | Out-Null

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Build $Task -Tier $resolvedTierGlobal in '$moduleRoot'" -Tag 'InvokeCommandCall'

          Push-Location -LiteralPath $moduleRoot
          try {
            if ($SkipPublish.IsPresent) {
              Invoke-Build $Task -Tier $resolvedTierGlobal -ModuleRoot $moduleRoot -SkipPublish
            } else {
              Invoke-Build $Task -Tier $resolvedTierGlobal -ModuleRoot $moduleRoot
            }
          } finally {
            Pop-Location
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Build $Task in '$moduleRoot'" -Tag 'InvokeCommandCall'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Invoke-Build $Task succeeded: '$moduleName' [Tier=$resolvedTierGlobal]"

          $result.ExitCode = 0
          $result.RetryCount = $retryCount
          $result.BuildOutput = @("Invoke-Build $Task completed successfully. Transcript: $transcriptFile")
          $buildSuccess = $true
        } catch {
          $errorText = $_.Exception.Message
          $result.RetryCount = $retryCount
          $result.BuildOutput = @("EXCEPTION: $errorText", "Transcript: $transcriptFile")

          if ($errorText -match $psResourceGetMissingPattern -and $retryCount -lt $MaxRetries) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
              "Invoke-Build failed: PSResourceGet module not found. " +
              'Attempting to install Microsoft.PowerShell.PSResourceGet and retry.'
            )
            try {
              Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope CurrentUser -Force -AllowClobber
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Microsoft.PowerShell.PSResourceGet installed.'
            } catch {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message (
                "Failed to install Microsoft.PowerShell.PSResourceGet. Exception: $($_.Exception.Message)"
              )
            }
            $retryCount++
          } elseif ($errorText -match $networkErrorPattern -and $retryCount -lt $MaxRetries) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
              "Invoke-Build failed due to a transient network error; will retry. Error: $errorText"
            )
            $retryCount++
          } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message (
              "Invoke-Build $Task failed for '$moduleName' after $retryCount retry/retries. " +
              "Exception: $errorText. See transcript: $transcriptFile"
            )
            $result.ExitCode = 1
            break
          }
        } finally {
          Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        }
      } # end while retry loop

      $result
    } # end foreach $currentPath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
