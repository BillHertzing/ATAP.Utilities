function Invoke-SharedDotNetToolConsumerProbe {
<#
.SYNOPSIS
Writes identity-explicit shared .NET tool consumer evidence.

.DESCRIPTION
Runs the configured version and help commands from the administrator-managed
shared path under the current Windows identity. The function refuses to
impersonate, derive, or substitute an identity and writes no credentials.

.PARAMETER Policy
Schema-v1 shared .NET tool policy.

.PARAMETER LogicalIdentity
Configured logical consumer identity to prove.

.PARAMETER HostName
Host name recorded in the evidence.

.PARAMETER OutputPath
Optional output path. Defaults to the configured consumer EvidencePath.

.OUTPUTS
PSCustomObject.

.EXAMPLE
Invoke-SharedDotNetToolConsumerProbe -Policy $policy -LogicalIdentity BuildMaster

.NOTES
Run this command in a fresh process owned by the actual configured identity.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [object] $Policy,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $LogicalIdentity,

    [string] $HostName = $env:COMPUTERNAME,

    [string] $OutputPath
  )

  begin {
    $fn = 'Invoke-SharedDotNetToolConsumerProbe'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Starting shared .NET tool consumer probe for '$LogicalIdentity'."
  }

  process {
    try {
      if ([int]$Policy.SchemaVersion -ne 1) { throw 'Shared .NET tool policy SchemaVersion must be 1.' }
      $sharedPath = [string]$Policy.SharedPath
      if ([string]::IsNullOrWhiteSpace($sharedPath) -or -not [IO.Path]::IsPathFullyQualified($sharedPath)) {
        throw 'Shared .NET tool policy SharedPath must be fully qualified.'
      }
      $consumerMatches = @($Policy.Consumers | Where-Object { [string]$_.LogicalIdentity -ieq $LogicalIdentity })
      if ($consumerMatches.Count -ne 1) {
        throw "LogicalIdentity '$LogicalIdentity' must match exactly one configured consumer."
      }
      $consumer = $consumerMatches[0]
      if ([string]$consumer.EvidenceMode -ne 'EvidenceFile') {
        throw "LogicalIdentity '$LogicalIdentity' is not configured for EvidenceFile collection."
      }
      if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = [string]$consumer.EvidencePath }
      if ([string]::IsNullOrWhiteSpace($OutputPath) -or -not [IO.Path]::IsPathFullyQualified($OutputPath)) {
        throw "Evidence output path for '$LogicalIdentity' must be fully qualified."
      }

      $actualIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
      if ($actualIdentity -ine [string]$consumer.ActualIdentity) {
        throw "Current identity '$actualIdentity' does not match configured identity '$($consumer.ActualIdentity)' for '$LogicalIdentity'."
      }

      $toolResults = foreach ($tool in @($Policy.Tools)) {
        $commandPath = Join-Path $sharedPath ([string]$tool.CommandName)
        $versionArguments = if ($tool.PSObject.Properties['VersionArguments']) { @($tool.VersionArguments) } else { @('--version') }
        $helpArguments = if ($tool.PSObject.Properties['HelpArguments']) { @($tool.HelpArguments) } else { @('--help') }
        $versionResult = if (Test-Path -LiteralPath $commandPath -PathType Leaf) {
          Invoke-ParityNativeCommand -Command $commandPath -ArgumentList $versionArguments
        } else {
          [pscustomobject]@{ ExitCode = -1; Output = @('<launcher-missing>') }
        }
        $helpResult = if (Test-Path -LiteralPath $commandPath -PathType Leaf) {
          Invoke-ParityNativeCommand -Command $commandPath -ArgumentList $helpArguments
        } else {
          [pscustomobject]@{ ExitCode = -1; Output = @('<launcher-missing>') }
        }
        $versionOutput = ((@($versionResult.Output) -join ' ') -replace '\s+', ' ').Trim()
        [pscustomobject]@{
          PackageId = [string]$tool.PackageId
          ResolvedPath = $commandPath
          Version = if ($versionOutput -match "(^|\s)$([regex]::Escape([string]$tool.ExpectedVersion))(?=\+|\s|$)") {
            [string]$tool.ExpectedVersion
          } else {
            $versionOutput
          }
          VersionExitCode = [int]$versionResult.ExitCode
          HelpExitCode = [int]$helpResult.ExitCode
        }
      }

      $evidence = [pscustomobject]@{
        SchemaVersion = 1
        HostName = $HostName.ToLowerInvariant()
        LogicalIdentity = [string]$consumer.LogicalIdentity
        ActualIdentity = $actualIdentity
        CapturedAtUtc = (Get-Date).ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        Tools = @($toolResults)
      }
      if ($PSCmdlet.ShouldProcess($OutputPath, 'Write shared .NET tool consumer evidence')) {
        New-ParityDirectory -Path (Split-Path -Parent $OutputPath)
        Write-ParityJsonFile -Path $OutputPath -InputObject $evidence
      }
      $evidence
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Shared .NET tool consumer probe failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Completed shared .NET tool consumer probe for '$LogicalIdentity'."
  }
}
