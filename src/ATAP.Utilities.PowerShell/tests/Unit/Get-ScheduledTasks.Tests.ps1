# AI assisted using Powershell.instructions.md as guidelines
#
# V4-B09 — Get-ScheduledTasks "load-then-execute" contract.
# Get-ScheduledTasks.ps1 was refactored from a top-level inline script that queried
# schtasks.exe at import/dot-source time into an exported function that only runs the
# query when explicitly invoked. These tests pin the new shape:
#   1. The source file defines exactly one function and contains no top-level
#      executable statements (so dot-sourcing / module import performs no query).
#   2. Dot-sourcing the file does not invoke schtasks.exe.
#   3. Invoking the function parses schtasks.exe LIST /V output into a hashtable
#      keyed by TaskName whose values are PSCustomObject property bags.
#
# schtasks.exe is a native executable; the tests intercept it by defining a function of
# the same name in the same scope into which Get-ScheduledTasks is dot-sourced. A
# function named 'schtasks.exe' shadows the application in PowerShell command resolution.

Describe 'Get-ScheduledTasks' -Tag 'Unit' {
  BeforeAll {
    $message = 'Starting BeforeAll in Get-ScheduledTasks.tests.ps1'
    Write-PSFMessage -Level Debug -Message $message -Tag 'Trace', 'Tests'

    $script:functionPath = (Resolve-Path (Join-Path $PSScriptRoot '../../public/Get-ScheduledTasks.ps1')).Path

    # Representative `schtasks.exe /Query /FO LIST /V` output: two task blocks separated
    # by a blank line, each a run of "Key: Value" lines starting with TaskName.
    $script:sampleSchtasksOutput = @(
      'TaskName: \DemoTaskOne'
      'Status: Ready'
      'Run As User: SYSTEM'
      'Schedule Type: Daily'
      ''
      'TaskName: \Sub\DemoTaskTwo'
      'Status: Disabled'
      'Run As User: whertzing'
      ''
    )
  }

  Context 'Source file shape — load-then-execute (no import-time query)' {
    It 'parses with no syntax errors' {
      $errs = $null
      [System.Management.Automation.Language.Parser]::ParseFile($script:functionPath, [ref]$null, [ref]$errs) | Out-Null
      $errs.Count | Should -Be 0
    }

    It 'top-level body is exactly one function definition named Get-ScheduledTasks' {
      $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:functionPath, [ref]$null, [ref]$null)
      $topStatements = @($ast.EndBlock.Statements)
      $topStatements.Count | Should -Be 1
      $topStatements[0] | Should -BeOfType [System.Management.Automation.Language.FunctionDefinitionAst]
      $topStatements[0].Name | Should -Be 'Get-ScheduledTasks'
    }

    It 'does not invoke schtasks.exe when the file is dot-sourced' {
      $script:schtasksCallCount = 0
      function schtasks.exe { $script:schtasksCallCount++; @() }
      . $script:functionPath
      $script:schtasksCallCount | Should -Be 0
    }

    It 'defines Get-ScheduledTasks as a Function after dot-sourcing' {
      . $script:functionPath
      (Get-Command -Name Get-ScheduledTasks -CommandType Function -ErrorAction SilentlyContinue) |
        Should -Not -BeNullOrEmpty
    }
  }

  Context 'Invocation parses schtasks output into the documented shape' {
    It 'runs schtasks.exe exactly once and returns a hashtable keyed by TaskName' {
      $script:schtasksCallCount = 0
      function schtasks.exe { $script:schtasksCallCount++; $script:sampleSchtasksOutput }
      . $script:functionPath
      $result = Get-ScheduledTasks

      $script:schtasksCallCount | Should -Be 1
      $result | Should -BeOfType [hashtable]
      $result.Keys.Count | Should -Be 2
      $result.Keys | Should -Contain '\DemoTaskOne'
      $result.Keys | Should -Contain '\Sub\DemoTaskTwo'
    }

    It 'stores each task block as a property bag with the parsed key/value pairs' {
      function schtasks.exe { $script:sampleSchtasksOutput }
      . $script:functionPath
      $result = Get-ScheduledTasks

      $result['\DemoTaskOne'].Status | Should -Be 'Ready'
      $result['\DemoTaskOne'].'Run As User' | Should -Be 'SYSTEM'
      $result['\DemoTaskOne'].'Schedule Type' | Should -Be 'Daily'
      $result['\Sub\DemoTaskTwo'].Status | Should -Be 'Disabled'
      $result['\Sub\DemoTaskTwo'].'Run As User' | Should -Be 'whertzing'
    }

    It 'does not carry properties across the blank-line task boundary' {
      function schtasks.exe { $script:sampleSchtasksOutput }
      . $script:functionPath
      $result = Get-ScheduledTasks

      # The second task must not inherit the first task's Schedule Type.
      $result['\Sub\DemoTaskTwo'].PSObject.Properties.Name | Should -Not -Contain 'Schedule Type'
    }
  }
}
