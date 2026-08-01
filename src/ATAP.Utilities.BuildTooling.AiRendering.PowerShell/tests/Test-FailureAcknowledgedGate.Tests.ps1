# AI assisted using Powershell.instructions.md as guidelines
# Pester 5+ tests for Test-FailureAcknowledgedGate

BeforeAll {
    $functionName = 'Test-FailureAcknowledgedGate'
    if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
        $functionPath = Join-Path $PSScriptRoot -ChildPath "../public/$functionName.ps1"
        if (Test-Path $functionPath) {
            . $functionPath
        }
        else {
            throw "Function file not found: $functionPath"
        }
    }

    # Helper: write a JUnit-style XML string to a temp file and return the path.
    function New-TempFile {
        param([string]$Content, [string]$Extension = '.xml')
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ("ack-gate-" + [guid]::NewGuid().ToString('N') + $Extension)
        Set-Content -Path $path -Value $Content -Encoding UTF8
        return $path
    }

    $script:tempFiles = [System.Collections.Generic.List[string]]::new()

    function New-JUnitXml {
        param(
            [int]$TotalTests,
            [string[]]$FailingTestNames,
            [string]$Classname = 'ModuleA.TestSuite'
        )
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
        [void]$sb.AppendLine("<testsuite name='ModuleA' tests='$TotalTests'>")
        for ($i = 1; $i -le $TotalTests; $i++) {
            $name = "Test$i"
            if ($FailingTestNames -contains $name) {
                [void]$sb.AppendLine("  <testcase classname='$Classname' name='$name'>")
                [void]$sb.AppendLine("    <failure message='boom'>stack trace</failure>")
                [void]$sb.AppendLine('  </testcase>')
            }
            else {
                [void]$sb.AppendLine("  <testcase classname='$Classname' name='$name' />")
            }
        }
        [void]$sb.AppendLine('</testsuite>')
        return $sb.ToString()
    }
}

AfterAll {
    foreach ($p in $script:tempFiles) {
        if (Test-Path $p) {
            Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-FailureAcknowledgedGate' {

    It 'function exists' {
        Get-Command -Name 'Test-FailureAcknowledgedGate' | Should -Not -BeNullOrEmpty
    }

    It 'passes the gate when there are no failing tests' {
        $xml = New-JUnitXml -TotalTests 3 -FailingTestNames @()
        $resultPath = New-TempFile -Content $xml
        $script:tempFiles.Add($resultPath)

        $ackPath = New-TempFile -Content '[]' -Extension '.json'
        $script:tempFiles.Add($ackPath)

        $result = Test-FailureAcknowledgedGate -ResultFile $resultPath -AcknowledgedFile $ackPath -Tier 'Beta'

        $result.Passed | Should -Be 3
        $result.Failed | Should -Be 0
        $result.Acknowledged | Should -Be 0
        $result.Unacknowledged | Should -Be 0
        $result.GatePass | Should -BeTrue
    }

    It 'passes when a failing test has a matching acknowledgment at the same tier' {
        $xml = New-JUnitXml -TotalTests 3 -FailingTestNames @('Test2')
        $resultPath = New-TempFile -Content $xml
        $script:tempFiles.Add($resultPath)

        $ack = @(
            @{
                testName       = 'Test2'
                tier           = 'T3'
                category       = 'Test is wrong'
                issueNumber    = '#100'
                acknowledgedBy = 'tester'
                date           = '2026-04-13'
                notes          = 'tracked'
            }
        )
        $ackPath = New-TempFile -Content ($ack | ConvertTo-Json -Depth 4) -Extension '.json'
        $script:tempFiles.Add($ackPath)

        $result = Test-FailureAcknowledgedGate -ResultFile $resultPath -AcknowledgedFile $ackPath -Tier 'Beta'

        $result.Failed | Should -Be 1
        $result.Acknowledged | Should -Be 1
        $result.Unacknowledged | Should -Be 0
        $result.GatePass | Should -BeTrue
    }

    It 'passes when the acknowledgment tier is below the current gate tier (T2 ack for Beta/T3)' {
        $xml = New-JUnitXml -TotalTests 2 -FailingTestNames @('Test1')
        $resultPath = New-TempFile -Content $xml
        $script:tempFiles.Add($resultPath)

        $ack = @(
            @{
                testName       = 'Test1'
                tier           = 'T2'
                category       = 'known'
                issueNumber    = '#200'
                acknowledgedBy = 'tester'
                date           = '2026-04-13'
                notes          = 'acknowledged at T2'
            }
        )
        $ackPath = New-TempFile -Content ($ack | ConvertTo-Json -Depth 4) -Extension '.json'
        $script:tempFiles.Add($ackPath)

        $result = Test-FailureAcknowledgedGate -ResultFile $resultPath -AcknowledgedFile $ackPath -Tier 'Beta'

        $result.Acknowledged | Should -Be 1
        $result.Unacknowledged | Should -Be 0
        $result.GatePass | Should -BeTrue
    }

    It 'fails the gate when a failing test has no matching acknowledgment' {
        $xml = New-JUnitXml -TotalTests 2 -FailingTestNames @('Test1')
        $resultPath = New-TempFile -Content $xml
        $script:tempFiles.Add($resultPath)

        $ackPath = New-TempFile -Content '[]' -Extension '.json'
        $script:tempFiles.Add($ackPath)

        $result = Test-FailureAcknowledgedGate -ResultFile $resultPath -AcknowledgedFile $ackPath -Tier 'Beta'

        $result.Failed | Should -Be 1
        $result.Acknowledged | Should -Be 0
        $result.Unacknowledged | Should -Be 1
        $result.GatePass | Should -BeFalse
    }

    It 'treats a missing AcknowledgedFile as an empty list (all failures unacknowledged)' {
        $xml = New-JUnitXml -TotalTests 2 -FailingTestNames @('Test2')
        $resultPath = New-TempFile -Content $xml
        $script:tempFiles.Add($resultPath)

        $missingAckPath = Join-Path ([System.IO.Path]::GetTempPath()) ("missing-ack-" + [guid]::NewGuid().ToString('N') + '.json')
        # Do NOT create the file.

        $result = Test-FailureAcknowledgedGate -ResultFile $resultPath -AcknowledgedFile $missingAckPath -Tier 'Beta'

        $result.Failed | Should -Be 1
        $result.Acknowledged | Should -Be 0
        $result.Unacknowledged | Should -Be 1
        $result.GatePass | Should -BeFalse
    }
}
