function Test-SprintEndPullOverlap {
  <#
  .SYNOPSIS
  Detects paths that would be overwritten by a SprintEnd stable-branch pull.

  .DESCRIPTION
  Optionally fetches the remote branch, then compares locally modified paths
  with paths changed between the local branch and its remote counterpart. The
  command is read-only apart from the optional remote-reference fetch.

  .PARAMETER RepoPath
  Stable repository worktree to inspect.

  .PARAMETER RemoteName
  Git remote name. Defaults to origin.

  .PARAMETER Branch
  Stable branch name. Defaults to main.

  .PARAMETER Fetch
  Fetches the named remote branch before comparing paths.

  .PARAMETER ThrowOnOverlap
  Throws with the overlapping relative paths when overlap is detected.

  .OUTPUTS
  PSCustomObject containing local paths, incoming paths, and overlap.

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$RepoPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RemoteName = 'origin',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Branch = 'main',

    [Parameter()]
    [switch]$Fetch,

    [Parameter()]
    [switch]$ThrowOnOverlap
  )

  begin {
    $fn = 'Test-SprintEndPullOverlap'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $resolvedRepoPath = [IO.Path]::GetFullPath($RepoPath)
    $fetchPerformed = $false
    if ($Fetch -and $PSCmdlet.ShouldProcess("$RemoteName/$Branch", "Fetch in '$resolvedRepoPath'")) {
      [void](Invoke-SprintEndNativeCommand -FilePath 'git' `
          -ArgumentList @('-C', $resolvedRepoPath, 'fetch', $RemoteName, $Branch))
      $fetchPerformed = $true
    }

    $statusResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
      -ArgumentList @('-C', $resolvedRepoPath, 'status', '--porcelain=v1', '--untracked-files=all')
    $localPaths = @($statusResult.Output | Where-Object { $_ } | ForEach-Object {
        $path = if ($_.Length -gt 3) { $_.Substring(3).Trim('"') } else { '' }
        if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1].Trim('"') }
        $path
      } | Where-Object { $_ } | Sort-Object -Unique)

    $incomingResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
      -ArgumentList @('-C', $resolvedRepoPath, 'diff', '--name-only', "$Branch..$RemoteName/$Branch")
    $incomingPaths = @($incomingResult.Output | Where-Object { $_ } | Sort-Object -Unique)
    $overlap = @($localPaths | Where-Object { $incomingPaths -contains $_ } | Sort-Object -Unique)

    $result = [PSCustomObject]@{
      Ok             = ($overlap.Count -eq 0)
      RepoPath       = $resolvedRepoPath
      RemoteName     = $RemoteName
      Branch         = $Branch
      FetchPerformed = $fetchPerformed
      LocalPaths     = $localPaths
      IncomingPaths  = $incomingPaths
      Overlap        = $overlap
    }
    if (-not $result.Ok -and $ThrowOnOverlap) {
      throw "Stable pull blocked in '$resolvedRepoPath'; local and incoming changes overlap: $($overlap -join ', ')."
    }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
