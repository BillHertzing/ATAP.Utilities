# AI assisted using Powershell.instructions.md as guidelines
function Invoke-FailureAcknowledgedGate {
  <#
  .SYNOPSIS
    Validates FailureAcknowledged.json against its schema, then runs the Failure-Acknowledged gate.

  .DESCRIPTION
    Wraps Test-FailureAcknowledgedGate with two additional responsibilities:
      1. Structural validation of FailureAcknowledged.json against the bundled JSON schema
         (requires each entry to have a 'testName' string and a 'tier' matching T1-T5).
      2. Automatic translation of OtterScript tier names (Experimental, Development,
         Integration, QA, Production) to the PS-tier names expected by
         Test-FailureAcknowledgedGate (Sprint, Alpha, Beta, QA, Production).
      3. TRX-file support: when -ResultFile is a .trx file or a directory containing
         .trx files, the function parses them and synthesises a JUnit-style XML that
         Test-FailureAcknowledgedGate can consume, then cleans up the temp file.

    Designed to be called directly from OtterScript Exec blocks that use 'dotnet test'
    with '--logger trx', removing the need for a separate JUnit XML logger package.

  .PARAMETER ResultFile
    Path to a JUnit XML file, a TRX file, or a directory containing one or more TRX files.
    When a directory is provided every *.trx file under that directory (recursive) is merged.

  .PARAMETER AcknowledgedFile
    Path to the FailureAcknowledged.json file.  If the file does not exist the gate
    runs with an empty acknowledgement list (no entry can be acknowledged).

  .PARAMETER Tier
    The pipeline tier.  Accepts both OtterScript tier names and PS-tier names:
      Experimental  ->  Sprint   (gate is skipped — all failures pass)
      Development   ->  Alpha
      Integration   ->  Beta
      QA            ->  QA
      Production    ->  Production
    Sprint / Alpha / Beta are also accepted directly.

  .PARAMETER SchemaPath
    Optional explicit path to the JSON schema file.  Defaults to the
    'Resources\FailureAcknowledged.schema.json' file bundled with this module.

  .OUTPUTS
    [PSCustomObject] with properties:
      Passed, Failed, Acknowledged, Unacknowledged, GatePass (bool), Skipped (bool)
    Same shape as Test-FailureAcknowledgedGate output.

  .EXAMPLE
    # Called from OtterScript Development stage
    $r = Invoke-FailureAcknowledgedGate `
        -ResultFile 'C:\repo\_generated\testresults\Development' `
        -AcknowledgedFile 'C:\repo\FailureAcknowledged.json' `
        -Tier 'Development'
    if (-not $r.GatePass) { throw "Gate FAILED: $($r.Unacknowledged) unacknowledged failure(s)." }
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [string]$ResultFile,

    [Parameter(Mandatory)]
    [string]$AcknowledgedFile,

    [Parameter(Mandatory)]
    [ValidateSet(
      'Experimental', 'Development', 'Integration', 'QA', 'Production',
      'Sprint', 'Alpha', 'Beta'
    )]
    [string]$Tier,

    [Parameter()]
    [string]$SchemaPath
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    if (-not $mn) { $mn = 'ATAP.Utilities.BuildTooling.PowerShell' }

    # Map OtterScript tier names -> PS-tier names consumed by Test-FailureAcknowledgedGate.
    $tierMap = @{
      'Experimental' = 'Sprint'
      'Development'  = 'Alpha'
      'Integration'  = 'Beta'
      'QA'           = 'QA'
      'Production'   = 'Production'
      'Sprint'       = 'Sprint'
      'Alpha'        = 'Alpha'
      'Beta'         = 'Beta'
    }
    $psTier = $tierMap[$Tier]

    # Resolve default schema path via module base when available.
    if (-not $SchemaPath) {
      $moduleBase = $MyInvocation.MyCommand.Module.ModuleBase
      if ($moduleBase) {
        $SchemaPath = Join-Path $moduleBase 'Resources' 'FailureAcknowledged.schema.json'
      } else {
        # Fallback for direct dot-sourcing during tests.
        $SchemaPath = Join-Path $PSScriptRoot '..' 'Resources' 'FailureAcknowledged.schema.json'
      }
    }
  }

  process {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Invoke-FailureAcknowledgedGate: Tier='$Tier' -> psTier='$psTier', ResultFile='$ResultFile', AcknowledgedFile='$AcknowledgedFile'"

    # ------------------------------------------------------------------
    # Step 1: Structural validation of FailureAcknowledged.json
    # ------------------------------------------------------------------
    if (Test-Path -LiteralPath $AcknowledgedFile) {
      $rawJson = Get-Content -LiteralPath $AcknowledgedFile -Raw -ErrorAction Stop
      if ($rawJson -and $rawJson.Trim().Length -gt 0) {
        try {
          $entries = $rawJson | ConvertFrom-Json -ErrorAction Stop
        } catch {
          throw "FailureAcknowledged.json is not valid JSON: $_"
        }
        $entryArray = @($entries)
        $violations = [System.Collections.Generic.List[string]]::new()
        $idx = 0
        foreach ($entry in $entryArray) {
          if ($null -eq $entry) { $idx++; continue }
          if (-not $entry.testName -or [string]::IsNullOrWhiteSpace($entry.testName)) {
            $violations.Add("Entry[$idx]: missing or empty required field 'testName'")
          }
          if (-not $entry.tier) {
            $violations.Add("Entry[$idx] ('$($entry.testName)'): missing required field 'tier'")
          } elseif ($entry.tier -notmatch '^[Tt][1-5]$') {
            $violations.Add("Entry[$idx] ('$($entry.testName)'): tier '$($entry.tier)' is invalid — must match T1..T5")
          }
          $idx++
        }
        if ($violations.Count -gt 0) {
          $msg = "FailureAcknowledged.json schema validation failed with $($violations.Count) error(s):`n" +
          ($violations | ForEach-Object { "  - $_" } | Out-String)
          throw $msg
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "FailureAcknowledged.json schema validated: $($entryArray.Count) entries OK"
      }
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "FailureAcknowledged.json not found at '$AcknowledgedFile' — gate will run with empty acknowledgement list"
    }

    # ------------------------------------------------------------------
    # Step 2: Resolve ResultFile — handle directory (merge TRX files)
    #         or single TRX file (convert to temp JUnit XML).
    # ------------------------------------------------------------------
    $tempJUnitPath = $null
    $resultFileToPass = $ResultFile

    $isDirectory = Test-Path -LiteralPath $ResultFile -PathType Container
    $isTrxFile = (-not $isDirectory) -and ($ResultFile -match '\.trx$') -and (Test-Path -LiteralPath $ResultFile -PathType Leaf)

    if ($isDirectory -or $isTrxFile) {
      # Collect all TRX files.
      if ($isDirectory) {
        $trxFiles = @(Get-ChildItem -LiteralPath $ResultFile -Filter '*.trx' -Recurse -ErrorAction SilentlyContinue)
      } else {
        $trxFiles = @(Get-Item -LiteralPath $ResultFile)
      }

      if ($trxFiles.Count -eq 0) {
        if ($psTier -eq 'Sprint') {
          # Sprint tier skips; no result file needed.
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'No TRX files found; Sprint tier skips gate.'
        } else {
          throw "No TRX files found under '$ResultFile' for tier '$Tier'."
        }
      }

      # Convert all TRX files into a single merged JUnit XML.
      $tempJUnitPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),
        "FailureAcknowledgedGate-$([guid]::NewGuid().ToString('N')).xml")
      try {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
        [void]$sb.AppendLine('<testsuite name="MergedTrxResults">')

        $totalConverted = 0
        foreach ($trxFile in $trxFiles) {
          [xml]$trxXml = Get-Content -LiteralPath $trxFile.FullName -Raw -ErrorAction Stop
          $nsm = New-Object System.Xml.XmlNamespaceManager($trxXml.NameTable)
          $nsm.AddNamespace('ms', 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010')

          # Build test-definition lookup: testId -> { Name, ClassName }
          $testDefs = @{}
          foreach ($td in @($trxXml.SelectNodes('//ms:UnitTest', $nsm))) {
            $id = [string]$td.GetAttribute('id')
            $method = $td.SelectSingleNode('ms:TestMethod', $nsm)
            if ($method -and $id) {
              $testDefs[$id] = @{
                Name      = [string]$method.GetAttribute('name')
                ClassName = [string]$method.GetAttribute('className')
              }
            }
          }

          foreach ($result in @($trxXml.SelectNodes('//ms:UnitTestResult', $nsm))) {
            $outcome = [string]$result.GetAttribute('outcome')
            $testId = [string]$result.GetAttribute('testId')
            $rawName = [string]$result.GetAttribute('testName')

            $name = $rawName
            $className = ''
            if ($testDefs.ContainsKey($testId)) {
              $name = $testDefs[$testId].Name
              $className = $testDefs[$testId].ClassName
            }

            # Escape XML special characters.
            $safeName = [System.Security.SecurityElement]::Escape($name)
            $safeClassName = [System.Security.SecurityElement]::Escape($className)

            if ($outcome -eq 'Failed') {
              [void]$sb.AppendLine("  <testcase classname='$safeClassName' name='$safeName'>")
              [void]$sb.AppendLine("    <failure message='failed'/>")
              [void]$sb.AppendLine('  </testcase>')
            } else {
              [void]$sb.AppendLine("  <testcase classname='$safeClassName' name='$safeName' />")
            }
            $totalConverted++
          }
        }
        [void]$sb.AppendLine('</testsuite>')
        Set-Content -LiteralPath $tempJUnitPath -Value $sb.ToString() -Encoding UTF8
        $resultFileToPass = $tempJUnitPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
          -Message "Converted $($trxFiles.Count) TRX file(s) ($totalConverted total test result(s)) to JUnit XML at '$tempJUnitPath'"
      } catch {
        if ($tempJUnitPath -and (Test-Path -LiteralPath $tempJUnitPath)) {
          Remove-Item -LiteralPath $tempJUnitPath -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to convert TRX result(s) from '$ResultFile' to JUnit XML: $_"
      }
    }

    # ------------------------------------------------------------------
    # Step 3: Invoke the underlying gate.
    # ------------------------------------------------------------------
    try {
      $result = Test-FailureAcknowledgedGate `
        -ResultFile $resultFileToPass `
        -AcknowledgedFile $AcknowledgedFile `
        -Tier $psTier
      return $result
    } finally {
      if ($tempJUnitPath -and (Test-Path -LiteralPath $tempJUnitPath -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $tempJUnitPath -Force -ErrorAction SilentlyContinue
      }
    }
  }
}
