# Requires -Version 7.0
# Pester 5+ tests for Compress-PSModuleArtifacts (task T-1A).
# Uses a stub 7z.exe when the real one is unavailable.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Compress-PSModuleArtifacts.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }

  $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('CompressPSMod_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null

  # Create a stub 7z.exe (really a .cmd) that just creates the target archive
  # file. This is used only if real 7z.exe is not on PATH.
  $script:stubDir = Join-Path $script:testRoot '_stub7z'
  New-Item -ItemType Directory -Path $script:stubDir -Force | Out-Null

  $real7z = Get-Command -Name '7z.exe' -ErrorAction SilentlyContinue
  if ($null -eq $real7z) {
    if ($IsWindows -or [string]::IsNullOrEmpty($IsWindows)) {
      # Create a PowerShell script masquerading as 7z.exe via a .cmd shim.
      $shim = Join-Path $script:stubDir '7z.cmd'
      @'
@echo off
rem Minimal stub: "7z a -t7z <archive> <sourceGlob>" — just create the archive file.
set "ARCHIVE=%3"
echo stub7z > "%ARCHIVE%"
exit /b 0
'@ | Set-Content -LiteralPath $shim -Encoding Ascii

      # The cmdlet specifically looks for "7z.exe", not "7z.cmd".
      # Create a copy named 7z.exe by renaming — but .exe must be a real PE.
      # Workaround: create a PowerShell wrapper executable via a bat redirect isn't enough.
      # Instead, copy cmd.exe to 7z.exe in the stub dir and rely on a batch file 7z.bat?
      # The Get-Command check is for '7z.exe' exactly. To satisfy it we create a file
      # named 7z.exe that is actually a copy of an existing .exe we can't usefully run.
      # Simpler approach: create 7z.exe as a copy of a harmless .NET console that does
      # nothing. We can use powershell.exe itself as a stand-in by copying it.
      $pwshPath = (Get-Command pwsh.exe -ErrorAction SilentlyContinue)?.Source
      if (-not $pwshPath) {
        $pwshPath = (Get-Command powershell.exe -ErrorAction SilentlyContinue)?.Source
      }
      if ($pwshPath) {
        # Instead of copying pwsh (which wouldn't do what we want), create an
        # AppExecutionAlias-like script: leverage the fact that PowerShell's
        # Get-Command will find any executable file with .exe extension on PATH,
        # including ones that are actually pwsh. We'll place a small C# compiled
        # stub — but that's heavy. Fallback: generate 7z.exe as a dotnet
        # single-file stub via Add-Type + compiled exe.
        Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class Stub7zCompiler {
  public static void Compile(string outPath) {
    // Emit a minimal .NET Framework exe using CodeDom? Not available on pwsh 7.
    // Instead, write a batch file next to and a .exe shim is impossible without
    // native compile; signal to test to use .cmd path.
    throw new InvalidOperationException("not implemented");
  }
}
'@ -ErrorAction SilentlyContinue
      }

      # Final plan: just write a 7z.cmd and add the stub dir to PATH, and also
      # create a placeholder 7z.exe that is a copy of cmd.exe so Get-Command -Name '7z.exe'
      # resolves, but the cmdlet actually invokes via '& $sevenZipCmd.Source'.
      # That would run cmd.exe with wrong args. To avoid that, we override the
      # Get-Command lookup: create a function wrapper later in BeforeEach.
      $null = $shim  # keep the .cmd around as documentation
    }
  }

  $script:hasReal7z = $null -ne $real7z
}

AfterAll {
  if ($script:testRoot -and (Test-Path -LiteralPath $script:testRoot)) {
    Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'Compress-PSModuleArtifacts' {

  BeforeEach {
    # Fresh OutputRoot per test.
    $script:outputRoot = Join-Path $script:testRoot ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:outputRoot -Force | Out-Null

    # If real 7z.exe is missing, we stub Get-Command for '7z.exe' to return a
    # PSCustomObject whose .Source is a scriptblock wrapper. But & $source
    # requires a string/path to an executable. Instead, we mock Get-Command
    # and wrap the actual '&' call by redefining it via an alias 7z.exe pointing
    # at a PowerShell function. Simplest: define a function named '7z.exe' in
    # the global scope — Get-Command will find it.
    if (-not $script:hasReal7z) {
      # Note: function name cannot literally be '7z.exe' due to dot — define via
      # Set-Item Function: with a bracketed name.
      $body = {
        param([Parameter(ValueFromRemainingArguments = $true)]$argz)
        # Expect args: a -t7z <archive> <glob>
        $archiveIdx = 2
        if ($argz.Count -ge $archiveIdx + 1) {
          $archive = [string]$argz[$archiveIdx]
          Set-Content -LiteralPath $archive -Value 'stub7z' -Encoding Ascii
        }
        $global:LASTEXITCODE = 0
      }
      Set-Item -Path 'Function:7z.exe' -Value $body
    }
  }

  AfterEach {
    if (-not $script:hasReal7z) {
      Remove-Item -Path 'Function:7z.exe' -ErrorAction SilentlyContinue
    }
    if ($script:outputRoot -and (Test-Path -LiteralPath $script:outputRoot)) {
      Remove-Item -LiteralPath $script:outputRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  Context 'When all three source directories have content' {
    It 'Produces all three archives' {
      foreach ($sub in @('test-results', 'coverage', 'packages')) {
        $dir = Join-Path $script:outputRoot $sub
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'sample.txt') -Value "content for $sub" -Encoding Ascii
      }

      $result = Compress-PSModuleArtifacts -OutputRoot $script:outputRoot

      $result.TestResultsArchive | Should -Not -BeNullOrEmpty
      $result.CoverageReportArchive | Should -Not -BeNullOrEmpty
      $result.PackagesArchive | Should -Not -BeNullOrEmpty

      Test-Path -LiteralPath $result.TestResultsArchive | Should -BeTrue
      Test-Path -LiteralPath $result.CoverageReportArchive | Should -BeTrue
      Test-Path -LiteralPath $result.PackagesArchive | Should -BeTrue
    }
  }

  Context 'When some source directories are missing' {
    It 'Skips missing sources and returns $null for those fields' {
      # Only create test-results.
      $dir = Join-Path $script:outputRoot 'test-results'
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      Set-Content -LiteralPath (Join-Path $dir 'one.txt') -Value 'ok' -Encoding Ascii

      $result = Compress-PSModuleArtifacts -OutputRoot $script:outputRoot -WarningAction SilentlyContinue

      $result.TestResultsArchive | Should -Not -BeNullOrEmpty
      $result.CoverageReportArchive | Should -BeNullOrEmpty
      $result.PackagesArchive | Should -BeNullOrEmpty
    }
  }

  Context 'When source directories exist but are empty' {
    It 'Skips empty sources and returns $null for those fields' {
      foreach ($sub in @('test-results', 'coverage', 'packages')) {
        New-Item -ItemType Directory -Path (Join-Path $script:outputRoot $sub) -Force | Out-Null
      }

      $result = Compress-PSModuleArtifacts -OutputRoot $script:outputRoot -WarningAction SilentlyContinue

      $result.TestResultsArchive | Should -BeNullOrEmpty
      $result.CoverageReportArchive | Should -BeNullOrEmpty
      $result.PackagesArchive | Should -BeNullOrEmpty
    }
  }

  Context 'When OutputRoot does not exist' {
    It 'Throws' {
      { Compress-PSModuleArtifacts -OutputRoot (Join-Path $script:testRoot 'no-such-dir') } |
        Should -Throw -ExpectedMessage '*does not exist*'
    }
  }
}
