# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Invokes dotnet restore then dotnet build with automatic retry on NuGet cache failures.

.DESCRIPTION
Runs dotnet restore followed by dotnet build for a given solution or project path.
On NU1101/NU1202 restore failures (package not found in any feed), clears only the
NuGet HTTP cache and retries. Fody file-lock errors are surfaced as actionable
warnings rather than auto-cleared, because clearing the global-packages cache while
Fody DLLs are locked by the C# language server leaves the cache partially deleted,
causing subsequent restores to fail with "Access to path 'Fody.dll' is denied".

Before the build phase, scans for 0-byte DLL files in obj\**/ref\ directories.
These are corrupted reference assemblies left behind when a prior build fails
mid-flight; MSBuild's incremental reference-assembly stabilization will not
overwrite them because the public API surface appears unchanged. If found,
attempts dotnet build -t:Rebuild on the affected project(s). If auto-repair fails,
terminates with a clear error message that includes the exact Remove-Item +
dotnet build command to run from the repository root.

.PARAMETER SolutionOrProjectPath
One or more paths to .sln or .csproj files to restore and build. Accepts a single
string, an array of strings, a System.IO.FileInfo object (e.g. from Get-ChildItem),
an array of FileInfo objects, or any piped/bound object with a SolutionOrProjectPath
or FullName property.

.PARAMETER Configuration
One or more build configurations to apply. Valid values: Debug, ReleaseWithTrace, Release.
Each path is built once per specified configuration. Defaults to @('Debug').

.PARAMETER MaxRetries
Maximum number of retry attempts after a cache-related failure. Defaults to 1.

.PARAMETER BinaryLog
Switch (alias -bl). When specified, passes /bl:<path> to dotnet build to produce an MSBuild binary log.
If -BuildLogBasePath is not also supplied the path defaults to:
  <GeneratedRelativePath>\BuildLogs\<ProjectName>\<Configuration>\<ProjectName>.binlog

.PARAMETER BuildLogBasePath
Optional explicit path for the MSBuild binary log file produced when -BinaryLog is set.
Accepts a string file path. Defaults to the computed path described in -BinaryLog above.

.INPUTS
System.String, System.String[], System.IO.FileInfo, System.IO.FileInfo[]
Pipeline objects with a SolutionOrProjectPath or FullName property are also accepted.

.OUTPUTS
PSCustomObject[] — one result object per resolved path, each with:
ExitCode (int), RestoreOutput (string[]), BuildOutput (string[]), RetryCount (int)

.EXAMPLE
Invoke-DotnetBuildWithRetry -SolutionOrProjectPath 'C:\Repos\MyApp\MyApp.sln'

Restores and builds MyApp.sln in Release, retrying once on NU1101/NU1202.

.EXAMPLE
Invoke-DotnetBuildWithRetry -SolutionOrProjectPath 'C:\Repos\MyApp\MyApp.sln' -Configuration Debug -MaxRetries 2 -WhatIf

Shows what cache-clearing would occur without executing it.

.EXAMPLE
Invoke-DotnetBuildWithRetry -SolutionOrProjectPath 'C:\Repos\MyApp\MyApp.sln' -bl

Builds MyApp.sln and writes a binary log to the default generated path under BuildLogs\MyApp\Debug\.

.EXAMPLE
Invoke-DotnetBuildWithRetry -SolutionOrProjectPath 'C:\Repos\MyApp\MyApp.sln' -bl 'C:\Logs\MyApp.binlog'

Builds MyApp.sln and writes the binary log to the explicitly specified path.

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Only the NuGet HTTP cache is cleared on retry — never the global-packages cache.
Clearing global-packages while Fody DLLs are locked by OmniSharp/Roslyn causes
restore to fail with "Access to path 'Fody.dll' is denied". If you see that error,
restart the C# language server in VS Code (Command Palette: C# Restart Language Server).

Zero-byte obj\ref\ DLLs: if a prior build crashed mid-flight, the reference assembly
in obj\{Config}\{TFM}\ref\ may be 0 bytes. MSBuild skips overwriting it because the
API surface comparison silently passes with an empty file. This function detects such
files before the build, attempts dotnet build -t:Rebuild on the owning project, and
if auto-repair fails emits the exact Remove-Item + dotnet build command to run from
the repo root. See Explainer 0107-build-artifacts-trace-etw.md Section 5.1.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Invoke-DotnetBuildWithRetry {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [object[]] $SolutionOrProjectPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Debug', 'ReleaseWithTrace', 'Release')]
    [string[]] $Configuration = @('Debug'),

    [Parameter(Mandatory = $false)]
    [int] $MaxRetries = 1,

    [Parameter(Mandatory = $false)]
    [Alias('bl')]
    [switch] $BinaryLog,

    [Parameter(Mandatory = $false)]
    [string] $BuildLogBasePath
  )

  begin {
    $fn = 'Invoke-DotnetBuildWithRetry'
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

    # Normalize Configuration to an array for the per-configuration build loop.
    $configurationsToProcess = @($Configuration)

    # Snippet used: "Check and populate simple parameter as Type"
    $MaxRetries = Get-PVal -ParameterName 'MaxRetries' -originalPSBoundParameters $PSBoundParameters -dottedPath 'MaxRetries' -DefaultValue $MaxRetries -AsType ([int])

    # Patterns that identify specific failure categories
    $nuGetNotFoundPattern = 'NU1101|NU1202'
    $fodyLockPattern = 'Fody.*IOException|cannot access the file.*\.pdb.*being used by another process|Access to the path.*[Ff]ody.*is denied'
    $webcilLockPattern = 'tmp-webcil|Cannot access.*\.webcil|Access to the path.*tmp-webcil.*is denied|being used by another process.*tmp-webcil'

    # Test whether any file inside a directory is exclusively locked by another process.
    function Test-PathLocked {
      param([string] $LockTestPath)
      $isLocked = $false
      Get-ChildItem -LiteralPath $LockTestPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($isLocked) { return }
        try {
          $stream = [System.IO.File]::Open($_.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
          $stream.Close()
          $stream.Dispose()
        } catch {
          $isLocked = $true
        }
      }
      return $isLocked
    }

    # Identify which process(es) lock files in $HandlePath.
    # Uses handle.exe (Sysinternals) when found on PATH or in common install locations.
    function Get-LockingProcesses {
      param([string] $HandlePath)
      $handleExe = (Get-Command -Name 'handle.exe' -ErrorAction SilentlyContinue)?.Source
      if (-not $handleExe) {
        foreach ($candidate in @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\handle.exe",
            'C:\Sysinternals\handle.exe',
            "$env:USERPROFILE\Downloads\handle.exe")) {
          if (Test-Path $candidate) { $handleExe = $candidate; break }
        }
      }
      if ($handleExe) {
        return (& $handleExe -accepteula -nobanner $HandlePath 2>&1)
      }
      return $null
    }

    # Find all tmp-webcil directories under $RootPath, diagnose locks, and attempt removal.
    # Returns $true if every located directory was successfully removed.
    function Remove-WebcilTempDirectories {
      param([string] $RootPath)
      $webcilDirs = @(Get-ChildItem -LiteralPath $RootPath -Filter 'tmp-webcil' -Recurse -Directory -ErrorAction SilentlyContinue)
      if ($webcilDirs.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "No tmp-webcil directories found under '$RootPath'."
        return $false
      }
      $allRemoved = $true
      foreach ($dir in $webcilDirs) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Found tmp-webcil directory: $($dir.FullName)"
        if (Test-PathLocked -LockTestPath $dir.FullName) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Directory '$($dir.FullName)' has one or more locked files."
          $lockInfo = Get-LockingProcesses -HandlePath $dir.FullName
          if ($lockInfo) {
            $lockDetails = $lockInfo -join "`n"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Locking process detail (handle.exe):`n$lockDetails"
          } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
              'handle.exe (Sysinternals) not found — cannot identify the locking process. ' +
              'Likely culprits: dotnet.exe, MSBuild.exe, VBCSCompiler.exe.'
            )
          }
        }
        # Try PowerShell Remove-Item first; fall back to cmd.exe /c rd /s /q.
        $removed = $false
        try {
          Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
          $removed = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Removed '$($dir.FullName)' via Remove-Item."
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Remove-Item failed for '$($dir.FullName)': $($_.Exception.Message). Trying cmd /c rd..."
          $rdOutput = & cmd.exe /c "rd /s /q `"$($dir.FullName)`"" 2>&1
          if ($LASTEXITCODE -eq 0) {
            $removed = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Removed '$($dir.FullName)' via cmd /c rd /s /q."
          } else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "cmd /c rd /s /q also failed (exit $LASTEXITCODE): $($rdOutput -join ' ')"
          }
        }
        if (-not $removed) { $allRemoved = $false }
      }
      return $allRemoved
    }

    # Scan for 0-byte .dll files that reside directly inside an obj\**/ref\ directory.
    # A 0-byte ref assembly is left behind when a build fails mid-flight; MSBuild's
    # incremental reference-assembly stabilization then skips overwriting it because
    # the API comparison silently passes against an empty file.  These corrupt stubs
    # cause downstream compile errors and corrupt dotnet pack ref/ folder contents.
    # Returns an array of FileInfo objects for every zero-byte ref DLL found.
    function Find-ZeroByteRefAssemblies {
      param([string] $RootPath)
      return @(
        Get-ChildItem -LiteralPath $RootPath -Recurse -Filter '*.dll' -File -ErrorAction SilentlyContinue |
          Where-Object {
            $_.Length -eq 0 -and
            [System.IO.Path]::GetFileName($_.DirectoryName) -eq 'ref'
          }
      )
    }
  }

  process {
    # Normalize input: accept [string], [string[]], [System.IO.FileInfo], [System.IO.FileInfo[]],
    # or any object with a FullName property (e.g. pipeline output from Get-ChildItem).
    # Each pipeline bind delivers one element at a time; direct array args arrive all at once.
    $resolvedPaths = @(
      $SolutionOrProjectPath | ForEach-Object {
        if ($_ -is [System.IO.FileSystemInfo]) { $_.FullName }
        else { [System.IO.Path]::GetFullPath([string]$_) }
      }
    )

    foreach ($SolutionOrProjectPath in $resolvedPaths) {

      foreach ($Configuration in $configurationsToProcess) {

        $result = [PSCustomObject]@{
          ExitCode      = -1
          RestoreOutput = @()
          BuildOutput   = @()
          RetryCount    = 0
        }

        # -------------------------------------------------------------------------
        # Restore phase — with HTTP-cache-only retry on NU1101/NU1202
        # -------------------------------------------------------------------------
        # Resolve binary log path for this project/configuration pair
        $blArgs = @()
        if ($BinaryLog) {
          $resolvedBuildLogPath = $BuildLogBasePath
          if (-not $PSBoundParameters.ContainsKey('BuildLogBasePath') -or [string]::IsNullOrEmpty($resolvedBuildLogPath)) {
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionOrProjectPath)
            $generatedRelPath = $global:settings[$global:configRootKeys['GeneratedRelativePathConfigRootKey']]
            $resolvedBuildLogPath = Join-Path $generatedRelPath 'BuildLogs' $projectName $Configuration ("$projectName.binlog")
          }
          $blDir = Split-Path -Parent $resolvedBuildLogPath
          if (-not (Test-Path $blDir)) {
            New-Item -ItemType Directory -Path $blDir -Force | Out-Null
          }
          $blArgs = @("/bl:$resolvedBuildLogPath")
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Binary log will be written to '$resolvedBuildLogPath'"
        }

        if ($WhatIfPreference) {
          $blWhatIf = if ($BinaryLog) { " Binary log: '$resolvedBuildLogPath'." } else { '' }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
            "What if: dotnet restore '$SolutionOrProjectPath'; " +
            "dotnet build '$SolutionOrProjectPath' -c $Configuration --no-restore.$blWhatIf " +
            "On NU1101/NU1202, would also: dotnet nuget locals http-cache --clear and retry up to $MaxRetries time(s)."
          )
          $result.ExitCode = 0
          $result
          continue
        }

        $retryCount = 0
        $restoreSuccess = $false

        while (-not $restoreSuccess -and $retryCount -le $MaxRetries) {

          if ($retryCount -gt 0) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Retry $retryCount of $MaxRetries : clearing NuGet HTTP cache before re-running restore."

            if ($PSCmdlet.ShouldProcess('NuGet HTTP cache', 'Clear http-cache')) {
              try {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Invoke-Expression: dotnet nuget locals http-cache --clear' -Tag 'InvokeExpressionCall'
                & dotnet nuget locals http-cache --clear 2>&1 | Out-Null
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Successfully returned from Invoke-Expression: dotnet nuget locals http-cache --clear' -Tag 'InvokeExpressionCall'
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'NuGet HTTP cache cleared.'
              } catch {
                $errorMessage = "Failed to clear NuGet HTTP cache. Exception: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw
              }
            }
          }

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Running dotnet restore '$SolutionOrProjectPath' (attempt $($retryCount + 1) of $($MaxRetries + 1))"

          try {
            $restoreOutput = & dotnet restore $SolutionOrProjectPath 2>&1
            $restoreExitCode = $LASTEXITCODE
            $result.RestoreOutput = $restoreOutput
            $result.RetryCount = $retryCount

            if ($restoreExitCode -eq 0) {
              $restoreSuccess = $true
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'dotnet restore succeeded.'
            } else {
              $restoreText = $restoreOutput -join "`n"

              # Fody file-lock: cannot auto-fix; clearing global-packages makes it worse
              if ($restoreText -match $fodyLockPattern) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                  'dotnet restore failed due to a Fody/Mono.Cecil DLL file-lock held by the C# language server. ' +
                  'DO NOT clear the global-packages cache — that makes it worse. ' +
                  'Fix: In VS Code open the Command Palette and run "C#: Restart Language Server", then retry.'
                )
                $result.ExitCode = $restoreExitCode
                return $result
              }

              # NU1101/NU1202: stale HTTP cache or package genuinely missing
              if ($restoreText -match $nuGetNotFoundPattern -and $retryCount -lt $MaxRetries) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'dotnet restore failed with NU1101/NU1202 (package not found). Will clear HTTP cache and retry.'
                $retryCount++
              } else {
                $nuGetErrors = ($restoreOutput | Select-String $nuGetNotFoundPattern) -join "`n"
                if ($nuGetErrors) {
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message (
                    "dotnet restore still failed after $retryCount retry/retries. Missing packages:`n$nuGetErrors`n" +
                    'Ensure the package has been built and pushed to a configured ProGet feed.'
                  )
                } else {
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "dotnet restore failed (exit code $restoreExitCode).`n$restoreText"
                }
                $result.ExitCode = $restoreExitCode
                return $result
              }
            }
          } catch {
            $errorMessage = "Unexpected exception running dotnet restore. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
          }
        }

        # -------------------------------------------------------------------------
        # Pre-build check: detect and repair 0-byte obj\ref\ reference assemblies
        # -------------------------------------------------------------------------
        $projectDir = Split-Path -Parent $SolutionOrProjectPath
        $zeroByteRefs = Find-ZeroByteRefAssemblies -RootPath $projectDir

        if ($zeroByteRefs.Count -gt 0) {
          $zeroByteList = ($zeroByteRefs | ForEach-Object { $_.FullName }) -join "`n  "
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
            "Found $($zeroByteRefs.Count) zero-byte reference assembl$(if ($zeroByteRefs.Count -eq 1) { 'y' } else { 'ies' }) " +
            "under obj\ref\. MSBuild incremental build will NOT self-heal these.`n" +
            "Affected file(s):`n  $zeroByteList`n" +
            'Attempting forced rebuild (-t:Rebuild) of affected project(s)...'
          )

          # Walk 4 directory levels up from each zero-byte DLL to locate its .csproj:
          #   ref\ -> {TFM}\ -> {Config}\ -> obj\ -> <project-root>\
          $affectedProjects = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
          )
          foreach ($dll in $zeroByteRefs) {
            $dir = $dll.Directory  # start at the ref\ directory
            for ($i = 0; $i -lt 4; $i++) {
              if ($null -eq $dir) { break }
              $dir = $dir.Parent
            }
            if ($null -ne $dir) {
              $csproj = Get-ChildItem -LiteralPath $dir.FullName -Filter '*.csproj' -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
              if ($csproj) {
                [void] $affectedProjects.Add($csproj.FullName)
              } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                  "No .csproj found under '$($dir.FullName)' for zero-byte ref assembly '$($dll.FullName)'. " +
                  'Manual inspection required.'
                )
              }
            }
          }

          if ($affectedProjects.Count -eq 0) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
              'Could not determine owning project(s) for zero-byte ref assemblies. ' +
              "Manual fix: delete the listed files and run: dotnet build '$SolutionOrProjectPath' -t:Rebuild"
            )
          }

          $rebuildFailed = [System.Collections.Generic.List[string]]::new()
          foreach ($proj in $affectedProjects) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
              "Running: dotnet build '$proj' -t:Rebuild -c $Configuration"
            )
            $rbOut = & dotnet build $proj -t:Rebuild -c $Configuration 2>&1
            if ($LASTEXITCODE -ne 0) {
              [void] $rebuildFailed.Add($proj)
              $rbErrors = ($rbOut | Select-String '\berror\b') -join "`n"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message (
                "Forced rebuild failed for '$proj' (exit $LASTEXITCODE).`n$rbErrors"
              )
            } else {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                "Forced rebuild succeeded for '$proj'. Zero-byte ref assembly corrected."
              )
            }
          }

          if ($rebuildFailed.Count -gt 0) {
            $fixCmds = $rebuildFailed | ForEach-Object {
              $relProj = [System.IO.Path]::GetRelativePath($projectDir, $_)
              $relObj = Join-Path ([System.IO.Path]::GetDirectoryName($relProj)) 'obj'
              "Remove-Item -Recurse -Force '$relObj'; dotnet build '$relProj'"
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message (
              "Auto-repair of zero-byte obj\ref\ assemblies failed.`n" +
              "Run the following from the repository root ('$projectDir'):`n" +
              ($fixCmds -join "`n") +
              "`nSee Explainer 0107-build-artifacts-trace-etw.md Section 5.1 for background."
            )
            $result.ExitCode = 1
            return $result
          }
        }

        # -------------------------------------------------------------------------
        # Build phase
        # -------------------------------------------------------------------------
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Running dotnet build '$SolutionOrProjectPath' -c $Configuration --no-restore$(if ($blArgs) { " $($blArgs -join ' ')" })"

        try {
          $buildOutput = & dotnet build $SolutionOrProjectPath -c $Configuration --no-restore @blArgs 2>&1
          $buildExitCode = $LASTEXITCODE
          $result.BuildOutput = $buildOutput
          $result.ExitCode = $buildExitCode

          if ($buildExitCode -eq 0) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "dotnet build succeeded: '$SolutionOrProjectPath' [$Configuration]"
          } else {
            $buildText = $buildOutput -join "`n"

            if ($buildText -match $fodyLockPattern) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                'dotnet build failed due to a Fody/PDB file-lock held by the C# language server. ' +
                'DO NOT clear the global-packages cache — that makes it worse. ' +
                'Fix: In VS Code open the Command Palette and run "C#: Restart Language Server", then retry.'
              )
            } elseif ($buildText -match $webcilLockPattern) {
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                'dotnet build failed due to a locked tmp-webcil WebAssembly temp directory. Attempting to locate and remove it...'
              )
              $projectDir = Split-Path -Parent $SolutionOrProjectPath
              $allRemoved = Remove-WebcilTempDirectories -RootPath $projectDir
              if ($allRemoved) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                  'All tmp-webcil directories removed. Re-run the build to confirm the fix.'
                )
              } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message (
                  'Could not remove all tmp-webcil directories. ' +
                  'Manual fix: stop any running dotnet.exe / VBCSCompiler.exe processes, ' +
                  'then delete the obj/**/wasm/**/tmp-webcil folder(s) manually and retry.'
                )
              }
            } else {
              $errorLines = ($buildOutput | Select-String '\berror\b') -join "`n"
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "dotnet build failed (exit code $buildExitCode).`n$errorLines"
            }
          }
        } catch {
          $errorMessage = "Unexpected exception running dotnet build. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw
        }

        $result
      } # end foreach $Configuration
    } # end foreach $SolutionOrProjectPath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
