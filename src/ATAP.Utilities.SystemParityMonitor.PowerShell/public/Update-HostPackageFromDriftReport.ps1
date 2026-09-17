#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Updates host package installations based on a SystemParityMonitor DriftReport
  so all participating hosts match the highest recorded version.

.DESCRIPTION
  Parses a ParityState DriftReport markdown file (such as emitted by
  Compare-ParityAudits), extracts package drift across hosts, determines the
  latest version recorded for each package, and executes installation or
  upgrade actions.

  Execution strategy:
    - If the target host is the local computer ($env:COMPUTERNAME), choco is
      invoked directly in the local elevated process.
    - If the target host is remote, PowerShell 7 remoting (with the managed
      profiled endpoint, e.g. 'ATAP.PS7.Profiled' or 'PowerShell.7') is used
      under the svcAnsibleAdmin identity to invoke choco on that remote host.

.PARAMETER ReportPath
  Path to the ParityState DriftReport markdown file (e.g.
  'C:\ProgramData\ATAP\ParityState\DriftReport.utat022.utat01.20260915T093007Z.md').

.PARAMETER PackageManager
  Package manager to target. Defaults to 'Chocolatey'. Prepared for extension
  to 'WinGet', 'PowerShellGet', 'npm', 'pip', and 'NuGet'.

.PARAMETER TargetHosts
  Optional list of hostnames to restrict remediation to. Defaults to all hosts
  identified in the DriftReport.

.PARAMETER PackageNames
  Optional list of specific package names to reconcile. When omitted, all
  drifted packages for the specified package manager are updated.

.PARAMETER ConfigurationName
  PowerShell remoting session configuration endpoint name. Defaults to
  'ATAP.PS7.Profiled' with fallback to 'PowerShell.7'.

.PARAMETER Credential
  Explicit PSCredential for remote execution. If omitted, the function attempts
  to resolve the svcAnsibleAdmin credential via Get-SecretATAP.

.PARAMETER SecretNamePrefix
  Prefix used when querying Get-SecretATAP for host remoting credentials.
  Defaults to 'Windows.Remoting.Credential'.

.PARAMETER ChocoTimeoutSeconds
  Timeout in seconds for individual Chocolatey install/upgrade commands.
  Defaults to 600 seconds (10 minutes).

.OUTPUTS
  PSCustomObject[] with remediation details for each package and host:
    - HostName        [string]
    - PackageManager  [string]
    - PackageName     [string]
    - CurrentVersion  [string]
    - TargetVersion   [string]
    - Action          [string] ('LocalInstall' | 'LocalUpgrade' | 'RemoteInstall' | 'RemoteUpgrade' | 'UpToDate' | 'Skipped')
    - Success         [bool]
    - Output          [string]
    - Error           [string]

.EXAMPLE
  # Remediate Chocolatey drift from a specific drift report
  Update-HostPackageFromDriftReport `
    -ReportPath 'C:\ProgramData\ATAP\ParityState\DriftReport.utat022.utat01.20260915T093007Z.md'

.EXAMPLE
  # Dry-run with -WhatIf to inspect what would be installed/upgraded
  Update-HostPackageFromDriftReport `
    -ReportPath 'C:\ProgramData\ATAP\ParityState\DriftReport.utat022.utat01.20260915T093007Z.md' `
    -WhatIf

.EXAMPLE
  # Update only utat01 for specific packages
  Update-HostPackageFromDriftReport `
    -ReportPath 'C:\ProgramData\ATAP\ParityState\DriftReport.utat022.utat01.20260915T093007Z.md' `
    -TargetHosts @('utat01') `
    -PackageNames @('autohotkey', 'graphviz')

.NOTES
  AI assisted using ATAP repository standards.
  Implements multi-host package parity remediation for SystemParityMonitor.

.LINK
  https://github.com/whertzing/ATAP.Utilities
#>
function Update-HostPackageFromDriftReport {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReportPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Chocolatey', 'WinGet', 'PowerShellGet', 'NuGet', 'npm', 'pip')]
    [string]$PackageManager = 'Chocolatey',

    [Parameter(Mandatory = $false)]
    [string[]]$TargetHosts,

    [Parameter(Mandatory = $false)]
    [string[]]$PackageNames,

    [Parameter(Mandatory = $false)]
    [string]$ConfigurationName = 'ATAP.PS7.Profiled',

    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$SecretNamePrefix = 'Windows.Remoting.Credential',

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 3600)]
    [int]$ChocoTimeoutSeconds = 600
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Entering $fn with PackageManager='$PackageManager', ReportPath='$ReportPath'"

    # ── Helper: Safe Version Comparator ─────────────────────────────────────
    function Compare-PackageVersionString {
      param([string]$VersionA, [string]$VersionB)
      if ([string]::IsNullOrWhiteSpace($VersionA) -or $VersionA -eq '<missing>') { return -1 }
      if ([string]::IsNullOrWhiteSpace($VersionB) -or $VersionB -eq '<missing>') { return 1 }
      if ($VersionA -eq $VersionB) { return 0 }

      # Normalize and split version components
      $cleanA = ($VersionA -replace '[^\d\.]', '') -replace '\.+', '.'
      $cleanB = ($VersionB -replace '[^\d\.]', '') -replace '\.+', '.'

      try {
        $vA = [System.Version]::new(($cleanA.Split('.') + @(0,0,0,0))[0..3] -join '.')
        $vB = [System.Version]::new(($cleanB.Split('.') + @(0,0,0,0))[0..3] -join '.')
        return $vA.CompareTo($vB)
      } catch {
        # Fallback to lexical comparison
        return [string]::Compare($VersionA, $VersionB, [System.StringComparison]::OrdinalIgnoreCase)
      }
    }

    # ── Helper: Resolve Remoting Credential ──────────────────────────────────
    function Resolve-HostRemotingCredential {
      param([string]$ComputerName, [PSCredential]$ExplicitCredential, [string]$SecretPrefix)
      if ($null -ne $ExplicitCredential) { return $ExplicitCredential }

      if (Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue) {
        try {
          $hostSecretName = "$SecretPrefix.$($ComputerName.ToUpper())"
          $u = Get-SecretATAP -SecretName $hostSecretName -SecretField 'username' -ErrorAction SilentlyContinue
          $p = Get-SecretATAP -SecretName $hostSecretName -SecretField 'password' -ErrorAction SilentlyContinue
          if (-not [string]::IsNullOrWhiteSpace($u) -and -not [string]::IsNullOrWhiteSpace($p)) {
            return [PSCredential]::new($u, (ConvertTo-SecureString $p -AsPlainText -Force))
          }

          # Generic svcAnsibleAdmin fallback secret
          $genericSecretName = 'Windows.Identity.svcAnsibleAdmin'
          $gu = Get-SecretATAP -SecretName $genericSecretName -SecretField 'username' -ErrorAction SilentlyContinue
          $gp = Get-SecretATAP -SecretName $genericSecretName -SecretField 'password' -ErrorAction SilentlyContinue
          if (-not [string]::IsNullOrWhiteSpace($gu) -and -not [string]::IsNullOrWhiteSpace($gp)) {
            return [PSCredential]::new($gu, (ConvertTo-SecureString $gp -AsPlainText -Force))
          }
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Get-SecretATAP resolution skipped/failed for $ComputerName: $($_.Exception.Message)"
        }
      }
      return $null
    }
  }

  process {
    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
      $errMsg = "DriftReport file was not found at '$ReportPath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
      throw $errMsg
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Reading DriftReport: $ReportPath"
    $reportLines = Get-Content -LiteralPath $ReportPath

    # ── Parse DriftReport Header for Participating Hosts ───────────────────
    $leftHost = $null
    $rightHost = $null
    $headerMatch = $reportLines | Select-String -Pattern '^#\s+Parity\s+Drift\s+Report:\s+([^\s]+)\s+vs\s+([^\s]+)' | Select-Object -First 1
    if ($headerMatch) {
      $leftHost = $headerMatch.Matches[0].Groups[1].Value.Trim().ToLowerInvariant()
      $rightHost = $headerMatch.Matches[0].Groups[2].Value.Trim().ToLowerInvariant()
    }

    # ── Parse Undeclared Drift for Package Manager ─────────────────────────
    # Format: - PackageManager/Machine/Chocolatey/autohotkey: utat022='2.0.28' vs utat01='2.0.27'
    $inUndeclaredDrift = $false
    $driftRecords = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in $reportLines) {
      if ($line -match '^##\s+Undeclared Drift') {
        $inUndeclaredDrift = $true
        continue
      } elseif ($line -match '^##\s+' -and $inUndeclaredDrift) {
        $inUndeclaredDrift = $false
      }

      if ($inUndeclaredDrift) {
        $pattern = "^-\s+PackageManager/(?:Machine|[^/]+)/$([regex]::Escape($PackageManager))/([^:]+):\s+([^=]+)='([^']*)'\s+vs\s+([^=]+)='([^']*)'"
        if ($line -match $pattern) {
          $pkgName   = $Matches[1].Trim()
          $host1Name = $Matches[2].Trim().ToLowerInvariant()
          $host1Ver  = $Matches[3].Trim()
          $host2Name = $Matches[4].Trim().ToLowerInvariant()
          $host2Ver  = $Matches[5].Trim()

          # Filter package names if specified
          if ($PackageNames -and ($PackageNames -notcontains $pkgName)) {
            continue
          }

          # Determine the latest version across participating hosts
          $cmp = Compare-PackageVersionString -VersionA $host1Ver -VersionB $host2Ver
          $latestVer = if ($cmp -ge 0) { $host1Ver } else { $host2Ver }

          if ($latestVer -eq '<missing>' -or [string]::IsNullOrWhiteSpace($latestVer)) {
            continue
          }

          $driftRecords.Add([PSCustomObject]@{
            PackageName   = $pkgName
            LatestVersion = $latestVer
            HostVersions  = @{
              $host1Name = $host1Ver
              $host2Name = $host2Ver
            }
          })
        }
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found $($driftRecords.Count) drifted '$PackageManager' package entries in report."

    # ── Execution Plan Formulation ─────────────────────────────────────────
    $localComputerName = $env:COMPUTERNAME.ToLowerInvariant()
    $remediationResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($record in $driftRecords) {
      $pkg = $record.PackageName
      $targetVersion = $record.LatestVersion

      foreach ($hostEntry in $record.HostVersions.GetEnumerator()) {
        $targetHost = $hostEntry.Key.ToLowerInvariant()
        $currentVersion = $hostEntry.Value

        if ($TargetHosts -and ($TargetHosts -notcontains $targetHost)) {
          continue
        }

        # Check if this host already has the latest version
        if ($currentVersion -eq $targetVersion) {
          $remediationResults.Add([PSCustomObject]@{
            HostName       = $targetHost
            PackageManager = $PackageManager
            PackageName    = $pkg
            CurrentVersion = $currentVersion
            TargetVersion  = $targetVersion
            Action         = 'UpToDate'
            Success        = $true
            Output         = "Package '$pkg' is already at latest version '$targetVersion'."
            Error          = $null
          })
          continue
        }

        $isMissing = ($currentVersion -eq '<missing>' -or [string]::IsNullOrWhiteSpace($currentVersion))
        $isLocal = ($targetHost -eq $localComputerName -or $targetHost -eq 'localhost')

        # Determine operation kind
        $actionName = if ($isLocal) {
          if ($isMissing) { 'LocalInstall' } else { 'LocalUpgrade' }
        } else {
          if ($isMissing) { 'RemoteInstall' } else { 'RemoteUpgrade' }
        }

        $actionDescription = "$actionName of $PackageManager package '$pkg' (current: '$currentVersion' -> target: '$targetVersion') on host '$targetHost'"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Planning $actionDescription"

        if (-not $PSCmdlet.ShouldProcess($targetHost, $actionDescription)) {
          $remediationResults.Add([PSCustomObject]@{
            HostName       = $targetHost
            PackageManager = $PackageManager
            PackageName    = $pkg
            CurrentVersion = $currentVersion
            TargetVersion  = $targetVersion
            Action         = 'Skipped'
            Success        = $true
            Output         = "Dry run (-WhatIf): $actionDescription"
            Error          = $null
          })
          continue
        }

        # ── Execute: Local vs Remote ─────────────────────────────────────────
        if ($isLocal) {
          # Direct invocation on local host
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Invoking choco directly for '$pkg' on local host $targetHost"
            $chocoArgs = if ($isMissing) {
              @('install', $pkg, '--version', $targetVersion, '-y', '--no-progress')
            } else {
              @('upgrade', $pkg, '--version', $targetVersion, '-y', '--no-progress', '--allow-downgrade')
            }

            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = 'choco.exe'
            $psi.Arguments = $chocoArgs -join ' '
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            $process = [System.Diagnostics.Process]::Start($psi)
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $completed = $process.WaitForExit($ChocoTimeoutSeconds * 1000)

            if (-not $completed) {
              $process.Kill()
              throw "Local choco execution timed out after $ChocoTimeoutSeconds seconds."
            }

            $exitCode = $process.ExitCode
            $success = ($exitCode -eq 0 -or $exitCode -eq 3010) # 3010 = reboot required

            $remediationResults.Add([PSCustomObject]@{
              HostName       = $targetHost
              PackageManager = $PackageManager
              PackageName    = $pkg
              CurrentVersion = $currentVersion
              TargetVersion  = $targetVersion
              Action         = $actionName
              Success        = $success
              Output         = $stdout
              Error          = if ($success) { $null } else { $stderr }
            })
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed local choco execution for '$pkg': $($_.Exception.Message)"
            $remediationResults.Add([PSCustomObject]@{
              HostName       = $targetHost
              PackageManager = $PackageManager
              PackageName    = $pkg
              CurrentVersion = $currentVersion
              TargetVersion  = $targetVersion
              Action         = $actionName
              Success        = $false
              Output         = $null
              Error          = $_.Exception.Message
            })
          }
        } else {
          # Remote execution via PowerShell 7 Remoting
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Invoking choco via remoting on target host '$targetHost' (endpoint: '$ConfigurationName')"
            $targetCred = Resolve-HostRemotingCredential -ComputerName $targetHost -ExplicitCredential $Credential -SecretPrefix $SecretNamePrefix

            $remoteScriptBlock = {
              param($RemotePkg, $RemoteVer, $RemoteIsMissing)
              $chocoCmd = if ($RemoteIsMissing) {
                "choco.exe install `"$RemotePkg`" --version `"$RemoteVer`" -y --no-progress"
              } else {
                "choco.exe upgrade `"$RemotePkg`" --version `"$RemoteVer`" -y --no-progress --allow-downgrade"
              }

              $output = & cmd.exe /c "$chocoCmd 2>&1"
              $exitCode = $LASTEXITCODE

              [PSCustomObject]@{
                ExitCode = $exitCode
                Output   = ($output -join "`n")
                Success  = ($exitCode -eq 0 -or $exitCode -eq 3010)
              }
            }

            $invokeParams = @{
              ComputerName      = $targetHost
              ConfigurationName = $ConfigurationName
              ScriptBlock       = $remoteScriptBlock
              ArgumentList      = @($pkg, $targetVersion, $isMissing)
              ErrorAction       = 'Stop'
            }
            if ($targetCred) {
              $invokeParams['Credential'] = $targetCred
            }

            $remoteResult = Invoke-Command @invokeParams

            $remediationResults.Add([PSCustomObject]@{
              HostName       = $targetHost
              PackageManager = $PackageManager
              PackageName    = $pkg
              CurrentVersion = $currentVersion
              TargetVersion  = $targetVersion
              Action         = $actionName
              Success        = $remoteResult.Success
              Output         = $remoteResult.Output
              Error          = if ($remoteResult.Success) { $null } else { "Process exited with code $($remoteResult.ExitCode)" }
            })
          } catch {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Remote remoting execution failed for '$pkg' on '$targetHost': $($_.Exception.Message)"
            $remediationResults.Add([PSCustomObject]@{
              HostName       = $targetHost
              PackageManager = $PackageManager
              PackageName    = $pkg
              CurrentVersion = $currentVersion
              TargetVersion  = $targetVersion
              Action         = $actionName
              Success        = $false
              Output         = $null
              Error          = $_.Exception.Message
            })
          }
        }
      }
    }

    $remediationResults
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Leaving $fn"
  }
}
