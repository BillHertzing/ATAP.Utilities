# AI assisted using Powershell.instructions.md as guidelines
function Test-CodeCoverageGate {
  <#
  .SYNOPSIS
    Evaluates the 5-Tier code-coverage gate against a Cobertura or JaCoCo XML coverage file.

  .DESCRIPTION
    Parses a code-coverage XML file (Cobertura or JaCoCo) and compares total line
    coverage to a threshold (default 70%). The gate is SKIPPED at Sprint, Alpha,
    and Beta tiers per the 5-Tier specification and only runs at QA and Production.

  .PARAMETER CoverageFile
    Path to the code coverage XML (Cobertura `<coverage>` root or JaCoCo `<report>` root).

  .PARAMETER Tier
    The gate tier currently being evaluated. One of Sprint, Alpha, Beta, QA, Production.

  .PARAMETER Threshold
    Minimum line-coverage percentage to pass. Defaults to 70.0.

  .OUTPUTS
    [PSCustomObject] with properties Tier, CoveragePct, Threshold, GatePass, Skipped.

  .EXAMPLE
    Test-CodeCoverageGate -CoverageFile ./coverage.xml -Tier QA -Threshold 80

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines

  .LINK
    https://docs.pester.dev/
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$CoverageFile,

    [Parameter(Mandatory)]
    [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
    [string]$Tier,

    [double]$Threshold = 70.0
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Evaluating coverage gate at tier '$Tier' with threshold $Threshold%"
  }

  process {
    # Skipped tiers per Section 9.4 / 5.4
    if ($Tier -in @('Sprint', 'Alpha', 'Beta')) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Coverage gate SKIPPED at tier '$Tier' (only runs at QA/Production)"
      return [PSCustomObject]@{
        Tier        = $Tier
        CoveragePct = $null
        Threshold   = $Threshold
        GatePass    = $true
        Skipped     = $true
      }
    }

    if (-not (Test-Path -Path $CoverageFile)) {
      $msg = "CoverageFile not found: $CoverageFile"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    try {
      [xml]$xml = Get-Content -Path $CoverageFile -Raw
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to parse CoverageFile '$CoverageFile' as XML: $_"
      throw
    }

    $root = $xml.DocumentElement
    $rootName = $root.LocalName
    $coveragePct = $null

    if ($rootName -eq 'coverage') {
      # Cobertura: <coverage line-rate="0.85" ...>
      $lineRateAttr = $root.GetAttribute('line-rate')
      if ([string]::IsNullOrWhiteSpace($lineRateAttr)) {
        $msg = "Cobertura coverage file missing 'line-rate' attribute: $CoverageFile"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      $coveragePct = [double]$lineRateAttr * 100.0
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Detected Cobertura format; line-rate=$lineRateAttr -> $coveragePct%"
    } elseif ($rootName -eq 'report') {
      # JaCoCo: top-level <counter type="LINE" missed="X" covered="Y"/>
      $lineCounter = $null
      foreach ($child in $root.ChildNodes) {
        if ($child.LocalName -eq 'counter' -and $child.GetAttribute('type') -eq 'LINE') {
          $lineCounter = $child
          break
        }
      }
      if ($null -eq $lineCounter) {
        $msg = "JaCoCo coverage file missing top-level <counter type=`"LINE`"> element: $CoverageFile"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
        throw $msg
      }
      $covered = [double]$lineCounter.GetAttribute('covered')
      $missed = [double]$lineCounter.GetAttribute('missed')
      $denom = $covered + $missed
      if ($denom -le 0) {
        $coveragePct = 0.0
      } else {
        $coveragePct = ($covered / $denom) * 100.0
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Detected JaCoCo format; covered=$covered missed=$missed -> $coveragePct%"
    } else {
      $msg = "Unrecognized coverage XML root element '$rootName' in file: $CoverageFile"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg
      throw $msg
    }

    $gatePass = ($coveragePct -ge $Threshold)

    if (-not $gatePass) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Coverage gate FAILED at tier '$Tier': measured $coveragePct% below threshold $Threshold%"
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Coverage gate PASSED at tier '$Tier': measured $coveragePct% >= threshold $Threshold%"
    }

    return [PSCustomObject]@{
      Tier        = $Tier
      CoveragePct = $coveragePct
      Threshold   = $Threshold
      GatePass    = $gatePass
      Skipped     = $false
    }
  }
}
