<#
.SYNOPSIS
Runs PSScriptAnalyzer against a PowerShell module and emits NUnit-style XML.

.DESCRIPTION
Tier-aware wrapper around Invoke-ScriptAnalyzer used by the 5-Tier module
build pipeline. At tier Sprint the analyzer is skipped and the gate passes
automatically (an empty XML file is still written for pipeline consistency).
At tiers Alpha and above the analyzer runs at severity Warning/Error and
GatePass is $true only when both the ErrorCount and the WarningCount are zero.

.PARAMETER Path
Path to the module root or to a specific .psm1/.ps1 file to analyze.

.PARAMETER Tier
One of Sprint, Alpha, Beta, QA, Production. Controls whether the analyzer
runs and how its findings are gated.

.PARAMETER OutputPath
Destination NUnit-style XML file to write. Parent directory is created if
necessary.

.OUTPUTS
[PSCustomObject] with Tier, ErrorCount, WarningCount, InformationCount,
GatePass, OutputFile.

.EXAMPLE
Invoke-PSModulePSScriptAnalyzer -Path ./src/MyModule -Tier Alpha -OutputPath ./_generated/psmodules/MyModule/test-results/PSScriptAnalyzerResults.xml

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>
function Invoke-PSModulePSScriptAnalyzer {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
    [string]$Tier,

    [Parameter(Mandatory)]
    [string]$OutputPath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn with Path='$Path' Tier='$Tier' OutputPath='$OutputPath'"

    # Check and populate simple parameter: Path
    if (-not $PSBoundParameters.ContainsKey('Path') -or [string]::IsNullOrWhiteSpace($Path)) {
      throw "[$fn] Parameter 'Path' is required"
    }
    # Check and populate simple parameter: Tier
    if (-not $PSBoundParameters.ContainsKey('Tier') -or [string]::IsNullOrWhiteSpace($Tier)) {
      throw "[$fn] Parameter 'Tier' is required"
    }
    # Check and populate simple parameter: OutputPath
    if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) {
      throw "[$fn] Parameter 'OutputPath' is required"
    }
  }

  process {
    try {
      # Always guarantee the parent directory exists so callers can rely on $OutputPath.
      $outDir = Split-Path -Path $OutputPath -Parent
      if ($outDir -and -not (Test-Path -Path $outDir)) {
        if ($PSCmdlet.ShouldProcess($outDir, 'Create output directory')) {
          New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
      }

      if ($Tier -eq 'Sprint') {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Tier is Sprint; skipping PSScriptAnalyzer and emitting empty XML'
        $emptyXml = @'
<?xml version="1.0" encoding="utf-8"?>
<test-results name="PSScriptAnalyzer" total="0" errors="0" failures="0" not-run="0" skipped="0">
  <test-suite type="TestFixture" name="PSScriptAnalyzer" success="True" />
</test-results>
'@
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Write empty PSScriptAnalyzer XML')) {
          Set-Content -Path $OutputPath -Value $emptyXml -Encoding UTF8
        }

        return [PSCustomObject]@{
          Tier             = $Tier
          ErrorCount       = 0
          WarningCount     = 0
          InformationCount = 0
          GatePass         = $true
          OutputFile       = $OutputPath
        }
      }

      $analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer
      if (-not $analyzer) {
        $msg = 'PSScriptAnalyzer is not installed. Install it with: Install-Module PSScriptAnalyzer -Scope CurrentUser'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }

      Import-Module PSScriptAnalyzer -ErrorAction Stop

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Running Invoke-ScriptAnalyzer on '$Path'"
      # Neutralize any ambient $PSDefaultParameterValues entry for '*:Settings' that
      # could inject a user-profile hashtable into Invoke-ScriptAnalyzer (PSSA treats
      # unknown keys as errors). Save and temporarily remove any matching default
      # so the cmdlet runs with its built-in rule set.
      $savedDefaults = @{}
      $keysToClear = @()
      if ($null -ne $PSDefaultParameterValues) {
        foreach ($k in @($PSDefaultParameterValues.Keys)) {
          if ($k -match '(?i)(Invoke-ScriptAnalyzer|\*):Settings$') {
            $savedDefaults[$k] = $PSDefaultParameterValues[$k]
            $keysToClear += $k
          }
        }
        foreach ($k in $keysToClear) { [void]$PSDefaultParameterValues.Remove($k) }
      }
      try {
        $results = @(Invoke-ScriptAnalyzer -Path $Path -Severity Warning, Error -Recurse -ErrorAction Stop)
      } finally {
        foreach ($k in $savedDefaults.Keys) { $PSDefaultParameterValues[$k] = $savedDefaults[$k] }
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "PSScriptAnalyzer returned $($results.Count) finding(s)"

      $errorCount = @($results | Where-Object { $_.Severity -eq 'Error' }).Count
      $warningCount = @($results | Where-Object { $_.Severity -eq 'Warning' }).Count
      $infoCount = @($results | Where-Object { $_.Severity -eq 'Information' }).Count

      # Build a simple NUnit-style XML with one <test-case> per finding.
      $sb = New-Object System.Text.StringBuilder
      [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
      [void]$sb.AppendLine(('<test-results name="PSScriptAnalyzer" total="{0}" errors="{1}" failures="{2}" not-run="0" skipped="0">' -f $results.Count, $errorCount, $warningCount))
      [void]$sb.AppendLine('  <test-suite type="TestFixture" name="PSScriptAnalyzer">')
      [void]$sb.AppendLine('    <results>')
      foreach ($r in $results) {
        $rule = [System.Security.SecurityElement]::Escape([string]$r.RuleName)
        $sev = [System.Security.SecurityElement]::Escape([string]$r.Severity)
        $file = [System.Security.SecurityElement]::Escape([string]$r.ScriptPath)
        $line = [int]($r.Line)
        $message = [System.Security.SecurityElement]::Escape([string]$r.Message)
        $success = if ($r.Severity -eq 'Information') { 'True' } else { 'False' }
        [void]$sb.AppendLine(('      <test-case name="{0}" success="{1}" executed="True">' -f $rule, $success))
        [void]$sb.AppendLine('        <failure>')
        [void]$sb.AppendLine(('          <message>[{0}] {1} at {2}:{3}</message>' -f $sev, $message, $file, $line))
        [void]$sb.AppendLine('        </failure>')
        [void]$sb.AppendLine('      </test-case>')
      }
      [void]$sb.AppendLine('    </results>')
      [void]$sb.AppendLine('  </test-suite>')
      [void]$sb.AppendLine('</test-results>')

      if ($PSCmdlet.ShouldProcess($OutputPath, 'Write PSScriptAnalyzer results XML')) {
        Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding UTF8
      }

      $gatePass = ($errorCount -eq 0 -and $warningCount -eq 0)
      if (-not $gatePass) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "PSScriptAnalyzer gate FAILED: Errors=$errorCount Warnings=$warningCount"
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'PSScriptAnalyzer gate passed'
      }

      return [PSCustomObject]@{
        Tier             = $Tier
        ErrorCount       = $errorCount
        WarningCount     = $warningCount
        InformationCount = $infoCount
        GatePass         = $gatePass
        OutputFile       = $OutputPath
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failure in $fn : $($_.Exception.Message)" -ErrorRecord $_
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn"
    }
  }
}

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
  Export-ModuleMember -Function Invoke-PSModulePSScriptAnalyzer
}
