function Get-SprintEndActiveWorkspaceRoot {
  <#
  .SYNOPSIS
  Finds active shell, Codex, and VS Code references inside a candidate worktree.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreePath
  )

  begin {
    $fn = 'Get-SprintEndActiveWorkspaceRoot'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $worktreeFull = [IO.Path]::GetFullPath($WorktreePath).TrimEnd(
      [IO.Path]::DirectorySeparatorChar,
      [IO.Path]::AltDirectorySeparatorChar
    )
    $comparison = if ($IsWindows) {
      [StringComparison]::OrdinalIgnoreCase
    } else {
      [StringComparison]::Ordinal
    }
    $blockers = [System.Collections.Generic.List[object]]::new()

    $candidateRoots = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $PWD -and -not [string]::IsNullOrWhiteSpace($PWD.Path)) {
      [void]$candidateRoots.Add([PSCustomObject]@{ Source = 'CurrentLocation'; Value = $PWD.Path })
    }
    foreach ($environmentName in @('CODEX_WORKSPACE_ROOT', 'CODEX_CWD', 'VSCODE_CWD', 'WORKSPACE')) {
      $environmentValue = [Environment]::GetEnvironmentVariable($environmentName, 'Process')
      if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        [void]$candidateRoots.Add([PSCustomObject]@{ Source = "Environment:$environmentName"; Value = $environmentValue })
      }
    }

    foreach ($candidate in $candidateRoots) {
      try {
        $candidateFull = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($candidate.Value)).TrimEnd(
          [IO.Path]::DirectorySeparatorChar,
          [IO.Path]::AltDirectorySeparatorChar
        )
      } catch {
        continue
      }
      if ($candidateFull.Equals($worktreeFull, $comparison) -or
        $candidateFull.StartsWith($worktreeFull + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        [void]$blockers.Add([PSCustomObject]@{
            Source = $candidate.Source
            Root   = $candidateFull
            Detail = 'Active workspace root is the worktree or one of its descendants.'
          })
      }
    }

    if ($IsWindows) {
      try {
        $processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
            Where-Object { $_.Name -in @('Codex.exe', 'Code.exe') })
        foreach ($process in $processes) {
          if (-not [string]::IsNullOrWhiteSpace($process.CommandLine) -and
            $process.CommandLine.IndexOf($worktreeFull, $comparison) -ge 0) {
            [void]$blockers.Add([PSCustomObject]@{
                Source = "Process:$($process.Name):$($process.ProcessId)"
                Root   = $worktreeFull
                Detail = 'Active Codex or VS Code process command line references the worktree.'
              })
          }
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Could not inspect Codex/VS Code process command lines: $($_.Exception.Message)"
        [void]$blockers.Add([PSCustomObject]@{
            Source = 'ProcessInspectionUnavailable'
            Root   = $worktreeFull
            Detail = 'Codex/VS Code process inspection failed; teardown is blocked closed.'
          })
      }
    }

    return @($blockers | Sort-Object Source, Root -Unique)
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
