<#
.SYNOPSIS
  Scheduled-task action that refreshes one shared .NET tool consumer evidence file.

.DESCRIPTION
  Runs Invoke-SharedDotNetToolConsumerProbe for ONE configured EvidenceFile consumer, under the
  Windows identity that runs this script (the scheduled task's principal). Each consumer task
  runs as the account its evidence attests, so no impersonation and no credential is involved.

  Fail-closed: the probe writes to a temporary file beside the evidence first. The real evidence
  file is replaced only when every configured tool's --version and --help checks exit 0 and the
  reported version equals the policy's ExpectedVersion. A failed check therefore never advances
  CapturedAtUtc; the old evidence stays in place, ages, and the parity audit reports it.

  Every run writes a result record under <StatePath>\TaskResults. That folder is a subfolder, so
  the audit's ParityState file-name surface (top-level files only) does not change.

  Registered by Register-ParityConsumerProbeTasks through a version-independent dispatcher.
  Started by the AceOutpost ParityProbe scheduler (Plan 8510CC89, SC-0518). The task has no time
  triggers of its own.

.PARAMETER LogicalIdentity
  Configured consumer LogicalIdentity whose evidence this run refreshes (for example Developer
  or BuildMaster). Must match exactly one EvidenceFile consumer in the policy.

.PARAMETER PolicyPath
  Schema-v1 SharedDotNetTools policy file.

.PARAMETER StatePath
  ParityState root; results are written to its TaskResults subfolder.

.NOTES
  Dual-purpose script guard: the probe runs only under `pwsh -File`; dot-sourcing defines the
  function without side effects (module-loading standard). This file lives in scripts\, which
  the module never dot-sources or inlines.
#>

function Invoke-ParityConsumerProbeTask {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $LogicalIdentity,

    [string] $PolicyPath = 'C:\ProgramData\ATAP\ParityState\Configuration\SharedDotNetTools.v1.json',

    [string] $StatePath = 'C:\ProgramData\ATAP\ParityState'
  )

  begin {
    $fn = 'Invoke-ParityConsumerProbeTask'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    # Write-ParityMessage is private to the module, so this script logs through PSFramework directly.
    $writeMessage = {
      param([string] $FunctionName, [string] $ModuleName, [string] $Level, [string] $Message)
      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $FunctionName -ModuleName $ModuleName -Level $Level -Message $Message -Tag 'ParityConsumerProbe'
      }
    }
    # Load this script's own module version unless the probe is already available (tests, or an
    # interactive session that imported the module). Never resolves a different installed version.
    if (-not (Get-Command -Name 'Invoke-SharedDotNetToolConsumerProbe' -ErrorAction SilentlyContinue)) {
      $manifestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
      Import-Module -Name $manifestPath -ErrorAction Stop
    }
    & $writeMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting consumer probe task for '$LogicalIdentity'."
  }

  process {
    $startedUtc = [DateTimeOffset]::UtcNow
    $actualIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $hostName = $env:COMPUTERNAME.ToLowerInvariant()
    $outcome = 'Failed'
    $reason = $null
    $evidencePath = $null
    $capturedAtUtc = $null
    $temporaryPath = $null
    try {
      if (-not [IO.Path]::IsPathFullyQualified($PolicyPath)) { throw "PolicyPath '$PolicyPath' must be fully qualified." }
      if (-not [IO.Path]::IsPathFullyQualified($StatePath)) { throw "StatePath '$StatePath' must be fully qualified." }
      $policy = Get-Content -LiteralPath $PolicyPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      if ([int]$policy.SchemaVersion -ne 1) { throw "Shared .NET tool policy SchemaVersion must be 1; found '$($policy.SchemaVersion)'." }
      $consumers = @($policy.Consumers | Where-Object { [string]$_.LogicalIdentity -ieq $LogicalIdentity })
      if ($consumers.Count -ne 1) { throw "Policy must contain exactly one consumer named '$LogicalIdentity'; found $($consumers.Count)." }
      if ([string]$consumers[0].EvidenceMode -ne 'EvidenceFile') { throw "Consumer '$LogicalIdentity' is not an EvidenceFile consumer." }
      $evidencePath = [string]$consumers[0].EvidencePath
      if ([string]::IsNullOrWhiteSpace($evidencePath) -or -not [IO.Path]::IsPathFullyQualified($evidencePath)) {
        throw "Consumer '$LogicalIdentity' EvidencePath must be fully qualified."
      }

      $temporaryPath = '{0}.{1}.pending' -f $evidencePath, [guid]::NewGuid().ToString('N')
      $evidence = Invoke-SharedDotNetToolConsumerProbe -Policy $policy -LogicalIdentity $LogicalIdentity -OutputPath $temporaryPath -ErrorAction Stop

      $failedChecks = @(foreach ($tool in @($evidence.Tools)) {
          $expected = @($policy.Tools | Where-Object { [string]$_.PackageId -eq [string]$tool.PackageId })
          $expectedVersion = if ($expected.Count -eq 1) { [string]$expected[0].ExpectedVersion } else { '<not-in-policy>' }
          if ([int]$tool.VersionExitCode -ne 0 -or [int]$tool.HelpExitCode -ne 0 -or [string]$tool.Version -ne $expectedVersion) {
            '{0}: Version={1}; Expected={2}; VersionExitCode={3}; HelpExitCode={4}' -f $tool.PackageId, $tool.Version, $expectedVersion, $tool.VersionExitCode, $tool.HelpExitCode
          }
        })
      if (@($evidence.Tools).Count -eq 0) { $failedChecks += 'No tool results were produced.' }
      if ($failedChecks.Count -gt 0) {
        throw "Consumer checks failed; evidence NOT refreshed: $($failedChecks -join ' | ')"
      }
      if (-not (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
        throw 'The probe reported success but wrote no evidence file; evidence NOT refreshed.'
      }

      Move-Item -LiteralPath $temporaryPath -Destination $evidencePath -Force -ErrorAction Stop
      $temporaryPath = $null
      $capturedAtUtc = [string]$evidence.CapturedAtUtc
      $outcome = 'Refreshed'
      & $writeMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Refreshed '$evidencePath' for '$LogicalIdentity' as '$actualIdentity' (CapturedAtUtc $capturedAtUtc)."
    } catch {
      $reason = $_.Exception.Message
      & $writeMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Consumer probe task for '$LogicalIdentity' failed: $reason"
    } finally {
      if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
      }
    }

    $result = [pscustomobject][ordered]@{
      SchemaVersion = 1
      Task = 'ParityConsumerProbe'
      HostName = $hostName
      LogicalIdentity = $LogicalIdentity
      ActualIdentity = $actualIdentity
      StartedAtUtc = $startedUtc.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
      Outcome = $outcome
      EvidencePath = $evidencePath
      EvidenceCapturedAtUtc = $capturedAtUtc
      Reason = $reason
      ExitCode = if ($outcome -eq 'Refreshed') { 0 } else { 1 }
    }
    try {
      $resultsDirectory = Join-Path $StatePath 'TaskResults'
      if (-not (Test-Path -LiteralPath $resultsDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null
      }
      $resultPath = Join-Path $resultsDirectory ('ParityConsumerProbeTaskResult.{0}.{1}.{2}.json' -f $hostName, $LogicalIdentity.ToLowerInvariant(), $startedUtc.ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture))
      $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resultPath -Encoding utf8NoBOM -ErrorAction Stop
    } catch {
      # A result-record write failure never changes the probe outcome; it is logged only.
      & $writeMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Could not write the consumer probe task result record: $($_.Exception.Message)"
    }
    $result
  }

  end {
    & $writeMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Completed consumer probe task for '$LogicalIdentity'."
  }
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  # Fires ONLY under: pwsh -File <script>; skipped on dot-source, module import, and &.
  $taskResult = Invoke-ParityConsumerProbeTask @args
  exit ([int]$taskResult.ExitCode)
}
