function Remove-SprintWorktreeSafely {
  <#
  .SYNOPSIS
  Removes one Sprint worktree with process-lock checks and bounded retries.

  .DESCRIPTION
  Refuses to remove a worktree referenced by the current shell, Codex, or VS Code.
  Confirms the exact path is registered with the supplied stable repository, then
  makes at most MaxAttempts Git removal attempts. After an attempt, only explicitly
  named, empty, non-reparse-point adapter placeholder directories can be removed,
  and every directory deletion is nonrecursive. A failure writes a minimal handoff
  containing only the command needed to retry this remaining teardown step.

  .PARAMETER RepositoryPath
  Stable Git repository that owns the linked worktree.

  .PARAMETER WorktreePath
  Exact linked-worktree path to remove.

  .PARAMETER AdapterPlaceholderPath
  Explicit adapter placeholder path, relative to WorktreePath or absolute. Each
  candidate must remain inside WorktreePath and be an empty ordinary directory.

  .PARAMETER MaxAttempts
  Maximum Git removal attempts. Defaults to three and cannot exceed ten.

  .PARAMETER RetryDelayMilliseconds
  Delay between attempts. Defaults to 500 milliseconds.

  .PARAMETER HandoffPath
  Failure handoff path. It must be outside WorktreePath.

  .PARAMETER ThrowOnFailure
  Throw after writing the failure handoff.

  .OUTPUTS
  PSCustomObject describing removal, attempts, blockers, placeholder cleanup, and handoff.

  .EXAMPLE
  Remove-SprintWorktreeSafely -RepositoryPath C:\Repos\App `
    -WorktreePath C:\Repos\App-wt-42-Sprint-0013-work-items `
    -AdapterPlaceholderPath @('.agents', '.codex') -Confirm:$false

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$RepositoryPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreePath,

    [Parameter()]
    [string[]]$AdapterPlaceholderPath = @(),

    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$MaxAttempts = 3,

    [Parameter()]
    [ValidateRange(0, 60000)]
    [int]$RetryDelayMilliseconds = 500,

    [Parameter()]
    [string]$HandoffPath,

    [Parameter()]
    [switch]$ThrowOnFailure
  )

  begin {
    $fn = 'Remove-SprintWorktreeSafely'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    if (-not (Get-Command -Name 'Get-SprintEndActiveWorkspaceRoot' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Get-SprintEndActiveWorkspaceRoot.ps1')
    }
    if (-not (Get-Command -Name 'Invoke-SprintEndNativeCommand' -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot '..\private\Invoke-SprintEndNativeCommand.ps1')
    }
  }

  process {
    function ConvertTo-SprintTeardownLiteral {
      param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
      return "'" + ($Value -replace "'", "''") + "'"
    }

    $repositoryFull = [IO.Path]::GetFullPath($RepositoryPath).TrimEnd(
      [IO.Path]::DirectorySeparatorChar,
      [IO.Path]::AltDirectorySeparatorChar
    )
    $worktreeFull = [IO.Path]::GetFullPath($WorktreePath).TrimEnd(
      [IO.Path]::DirectorySeparatorChar,
      [IO.Path]::AltDirectorySeparatorChar
    )
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $worktreePrefix = $worktreeFull + [IO.Path]::DirectorySeparatorChar
    $worktreeLeaf = Split-Path -Path $worktreeFull -Leaf
    if ([string]::IsNullOrWhiteSpace($HandoffPath)) {
      $HandoffPath = Join-Path (Split-Path -Path $repositoryFull -Parent) "HANDOFF.Remove-$worktreeLeaf.md"
    }
    $handoffFull = [IO.Path]::GetFullPath($HandoffPath)
    if ($handoffFull.Equals($worktreeFull, $comparison) -or $handoffFull.StartsWith($worktreePrefix, $comparison)) {
      throw 'HandoffPath must be outside the worktree being removed.'
    }

    $placeholderFullPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($placeholderPath in @($AdapterPlaceholderPath)) {
      if ([string]::IsNullOrWhiteSpace($placeholderPath)) { continue }
      $candidate = if ([IO.Path]::IsPathRooted($placeholderPath)) {
        [IO.Path]::GetFullPath($placeholderPath)
      } else {
        [IO.Path]::GetFullPath((Join-Path $worktreeFull $placeholderPath))
      }
      if (-not $candidate.StartsWith($worktreePrefix, $comparison)) {
        throw "Adapter placeholder path is outside the worktree: $candidate"
      }
      $candidateParent = [IO.Path]::GetFullPath((Split-Path -Path $candidate -Parent)).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
      )
      if (-not $candidateParent.Equals($worktreeFull, $comparison)) {
        throw "Adapter placeholder must be a direct child of the worktree: $candidate"
      }
      [void]$placeholderFullPaths.Add($candidate.TrimEnd(
          [IO.Path]::DirectorySeparatorChar,
          [IO.Path]::AltDirectorySeparatorChar
        ))
    }

    $attempts = 0
    $removedPlaceholders = [System.Collections.Generic.List[string]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
    $activeRoots = @(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktreeFull)

    $writeHandoff = {
      param([string]$Reason)
      $repositoryLiteral = ConvertTo-SprintTeardownLiteral -Value $repositoryFull
      $worktreeLiteral = ConvertTo-SprintTeardownLiteral -Value $worktreeFull
      $handoffLiteral = ConvertTo-SprintTeardownLiteral -Value $handoffFull
      $placeholderLiterals = @($placeholderFullPaths | ForEach-Object {
          ConvertTo-SprintTeardownLiteral -Value $_
        })
      $placeholderExpression = if ($placeholderLiterals.Count -gt 0) {
        '@(' + ($placeholderLiterals -join ', ') + ')'
      } else {
        '@()'
      }
      $safeReason = $Reason -replace '[\r\n]+', ' '
      $content = @(
        '# Agent Handoff - Remaining SprintEnd Worktree Teardown'
        ''
        "Reason: $safeReason"
        ''
        'Run this one remaining step from a directory outside the worktree in PowerShell 7 with profiles enabled.'
        ''
        '```powershell'
        'Import-Module ATAP.Utilities.BuildTooling.PowerShell -Force'
        "Remove-SprintWorktreeSafely -RepositoryPath $repositoryLiteral -WorktreePath $worktreeLiteral -AdapterPlaceholderPath $placeholderExpression -MaxAttempts $MaxAttempts -RetryDelayMilliseconds $RetryDelayMilliseconds -HandoffPath $handoffLiteral -ThrowOnFailure -Confirm:`$false"
        '```'
      ) -join [Environment]::NewLine
      $directory = Split-Path -Path $handoffFull -Parent
      if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
      }
      $temporaryPath = Join-Path $directory ('.' + [IO.Path]::GetFileName($handoffFull) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
      try {
        [IO.File]::WriteAllText($temporaryPath, $content, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporaryPath -Destination $handoffFull -Force
      } finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
          Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
      }
    }

    if ($activeRoots.Count -gt 0) {
      $reason = "Active workspace references block removal: $($activeRoots.Source -join ', ')."
      if ($PSCmdlet.ShouldProcess($handoffFull, 'Write minimal remaining-step handoff')) {
        & $writeHandoff $reason
      }
      $result = [PSCustomObject]@{
        Ok = $false; Removed = $false; Planned = $false; Attempts = 0
        WorktreePath = $worktreeFull; ActiveRoots = $activeRoots
        RemovedPlaceholders = @(); HandoffPath = $handoffFull; Failures = @($reason)
      }
      if ($ThrowOnFailure) { throw $reason }
      return $result
    }

    if (-not (Test-Path -LiteralPath $worktreeFull)) {
      if ((Test-Path -LiteralPath $handoffFull -PathType Leaf) -and
        $PSCmdlet.ShouldProcess($handoffFull, 'Remove completed remaining-step handoff')) {
        [IO.File]::Delete($handoffFull)
      }
      return [PSCustomObject]@{
        Ok = $true; Removed = $true; Planned = $false; Attempts = 0
        WorktreePath = $worktreeFull; ActiveRoots = @()
        RemovedPlaceholders = @(); HandoffPath = $null; Failures = @()
      }
    }

    $listResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
      -ArgumentList @('-C', $repositoryFull, 'worktree', 'list', '--porcelain') -AllowNonZeroExitCode
    $registeredPaths = @($listResult.Output | Where-Object { $_ -like 'worktree *' } | ForEach-Object {
        [IO.Path]::GetFullPath($_.Substring(9).Trim()).TrimEnd(
          [IO.Path]::DirectorySeparatorChar,
          [IO.Path]::AltDirectorySeparatorChar
        )
      })
    $isRegistered = @($registeredPaths | Where-Object { $_.Equals($worktreeFull, $comparison) }).Count -eq 1
    if (-not $listResult.Succeeded -or -not $isRegistered) {
      $reason = if (-not $listResult.Succeeded) {
        'Could not verify the stable repository worktree registration.'
      } else {
        'The exact worktree path is not registered with the supplied stable repository.'
      }
      if ($PSCmdlet.ShouldProcess($handoffFull, 'Write minimal remaining-step handoff')) {
        & $writeHandoff $reason
      }
      $result = [PSCustomObject]@{
        Ok = $false; Removed = $false; Planned = $false; Attempts = 0
        WorktreePath = $worktreeFull; ActiveRoots = @()
        RemovedPlaceholders = @(); HandoffPath = $handoffFull; Failures = @($reason)
      }
      if ($ThrowOnFailure) { throw $reason }
      return $result
    }

    if (-not $PSCmdlet.ShouldProcess($worktreeFull, "Remove registered worktree with at most $MaxAttempts attempts")) {
      return [PSCustomObject]@{
        Ok = $true; Removed = $false; Planned = $true; Attempts = 0
        WorktreePath = $worktreeFull; ActiveRoots = @()
        RemovedPlaceholders = @(); HandoffPath = $null; Failures = @()
      }
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
      $attempts = $attempt
      $removeResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @('-C', $repositoryFull, 'worktree', 'remove', $worktreeFull, '--force') `
        -AllowNonZeroExitCode
      if (-not $removeResult.Succeeded) {
        [void]$failures.Add("Attempt $attempt failed with Git exit code $($removeResult.ExitCode).")
      }

      if (Test-Path -LiteralPath $worktreeFull -PathType Container) {
        foreach ($placeholderFull in $placeholderFullPaths) {
          if (-not (Test-Path -LiteralPath $placeholderFull -PathType Container)) { continue }
          $placeholderItem = Get-Item -LiteralPath $placeholderFull -Force
          $isReparsePoint = [bool]($placeholderItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
          $children = @(Get-ChildItem -LiteralPath $placeholderFull -Force -ErrorAction Stop)
          if ($isReparsePoint -or $children.Count -gt 0) {
            [void]$failures.Add("Refused non-empty or reparse-point adapter placeholder: $placeholderFull")
            continue
          }
          [IO.Directory]::Delete($placeholderFull, $false)
          [void]$removedPlaceholders.Add($placeholderFull)
        }

        $remainingChildren = @(Get-ChildItem -LiteralPath $worktreeFull -Force -ErrorAction Stop)
        if ($remainingChildren.Count -eq 0) {
          [IO.Directory]::Delete($worktreeFull, $false)
        }
      }

      if (-not (Test-Path -LiteralPath $worktreeFull)) {
        Invoke-SprintEndNativeCommand -FilePath 'git' `
          -ArgumentList @('-C', $repositoryFull, 'worktree', 'prune') -AllowNonZeroExitCode | Out-Null
        if (Test-Path -LiteralPath $handoffFull -PathType Leaf) {
          [IO.File]::Delete($handoffFull)
        }
        return [PSCustomObject]@{
          Ok = $true; Removed = $true; Planned = $false; Attempts = $attempts
          WorktreePath = $worktreeFull; ActiveRoots = @()
          RemovedPlaceholders = $removedPlaceholders.ToArray(); HandoffPath = $null; Failures = @()
        }
      }

      if ($attempt -lt $MaxAttempts -and $RetryDelayMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $RetryDelayMilliseconds
      }
    }

    $reason = "Worktree remains after $attempts bounded removal attempts."
    [void]$failures.Add($reason)
    & $writeHandoff $reason
    $result = [PSCustomObject]@{
      Ok = $false; Removed = $false; Planned = $false; Attempts = $attempts
      WorktreePath = $worktreeFull; ActiveRoots = @()
      RemovedPlaceholders = $removedPlaceholders.ToArray(); HandoffPath = $handoffFull
      Failures = $failures.ToArray()
    }
    if ($ThrowOnFailure) { throw $reason }
    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
