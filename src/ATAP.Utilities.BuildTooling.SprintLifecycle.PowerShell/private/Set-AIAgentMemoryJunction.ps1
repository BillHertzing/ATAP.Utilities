function Set-AIAgentMemoryJunction {
  <#
  .SYNOPSIS
    Junctions a sprint worktree's Claude Code memory directory to the durable,
    Dropbox-backed AI agent memory store.

  .DESCRIPTION
    Sprint 0013 Task 13.88. Claude Code and the sprint checkpoint tooling resolve
    DIFFERENT project slugs under `~\.claude\projects\`:

      * Claude Code derives its slug from `git rev-parse --git-common-dir`, so from a
        worktree it resolves to the MAIN repository path. That is where it reads and
        writes memory, which is why memory is shared across all worktrees of a repo.
      * Save-SprintWorkSession derives its path from the transcript slug, which IS the
        sprint worktree. That is where /checkpoint looks for memory to archive.

    Left alone the two never meet, and the failure is SILENT: Save-SprintWorkSession
    reports `MemorySnapshotCreated=$false` with reason "Memory directory not found" and
    still exits successfully, so checkpoints look healthy while archiving zero memory
    files. Sprint 0013 lost three consecutive checkpoints to exactly that.

    This function points BOTH slugs' `memory` directories at one canonical store under
    Dropbox, outside every git repository, so memory survives sprint end, reaches every
    host via Dropbox sync, stays clear of the stable-worktree boundary rule, and is never
    committed to git.

    Directory junctions do not require elevation.

  .PARAMETER WorktreePath
    The sprint worktree whose memory junction should be provisioned.

  .PARAMETER AIAgentMemoryRoot
    Root of the durable memory store. When omitted it is derived from
    `DropboxBasePathConfigRootKey` as `<DropboxBase>\<user>\ATAP\AIAgentMemory`. When the
    key is unavailable (for example an agent shell with no PowerShell profile, where
    $global:settings is empty) the function SKIPS rather than guessing a path.

  .OUTPUTS
    PSCustomObject with Success, Skipped, SkipReason, MemoryRoot, RepositoryName,
    JunctionsCreated, Junctions, and Errors. Additive Disposition, Changed,
    HasUncertainEffects, DeclinedActions, FilesMoved and Progress describe command
    progress, not verified filesystem convergence. Planned/declined work is not
    Success. A configuration-unavailable skip retains the legacy explicit skip.

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$WorktreePath,

    [Parameter(Mandatory = $false)]
    [string]$AIAgentMemoryRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ClaudeProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects')
  )

  BEGIN {
    $fn = 'Set-AIAgentMemoryJunction'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Function started for '$WorktreePath'"

    # Claude Code slugs a path by lowercasing the drive letter and replacing
    # ':' '\' '_' '.' with '-'. Keep this in lockstep with Save-SprintWorkSession.
    $makeSlug = {
      param([string]$p)
      ($p.Substring(0, 1).ToLower() + $p.Substring(1)) -replace ':', '-' -replace '\\', '-' -replace '_', '-' -replace '\.', '-' -replace '^-', ''
    }
  }

  PROCESS {
    $result = [ordered]@{
      Success          = $false
      Skipped          = $false
      SkipReason       = $null
      MemoryRoot       = $null
      RepositoryName   = $null
      JunctionsCreated = 0
      Junctions        = @()
      Errors           = @()
      Disposition      = 'Failed'
      Changed          = $false
      HasUncertainEffects = $false
      DeclinedActions  = 0
      FilesMoved       = @()
      Progress         = @()
    }

    $activeAction = $null
    $beginAction = {
      param([string]$Kind, [string]$Source, [string]$Target)
      $entry = [PSCustomObject]@{
        Kind = $Kind; Source = $Source; Target = $Target
        State = 'Attempted'; Error = $null; Evidence = 'CommandReturnOnly'
      }
      $result.Progress += $entry
      return $entry
    }
    $finishAction = {
      param([object]$Entry)
      # Reached only after an explicit per-command ErrorAction Stop boundary.
      # A return proves command completion, not a verified filesystem postimage.
      $Entry.State = 'Completed'
      $result.Changed = $true
    }
    $readBoundary = {
      param([string]$Kind, [string]$Path, [scriptblock]$Read)
      try { & $Read } catch {
        $result.Progress += [PSCustomObject]@{
          Kind = $Kind; Source = $Path; Target = $null
          State = 'Failed'; Error = $_.Exception.Message; Evidence = 'ReadCommandError'
        }
        throw
      }
    }
    $recordDeclined = {
      param([string]$Kind, [string]$Target)
      $result.DeclinedActions++
      $result.Progress += [PSCustomObject]@{
        Kind = $Kind; Source = $null; Target = $Target
        State = $(if ($WhatIfPreference) { 'Planned' } else { 'Declined' })
        Error = $null; Evidence = 'ShouldProcessDeclined'
      }
    }

    try {
      if (-not (& $readBoundary 'ReadWorktreePath' $WorktreePath { Test-Path -LiteralPath $WorktreePath -PathType Container -ErrorAction Stop })) {
        throw "Worktree path not found: '$WorktreePath'"
      }

      # --- Resolve the MAIN repository via the git common dir -------------
      # For a worktree this is '<main>\.git\worktrees\<name>', so the main repo
      # root is the parent of the '.git' directory. Never assume the worktree
      # name can be string-trimmed back to the main repo.
      $commonDir = & $readBoundary 'ReadGitCommonDirectory' $WorktreePath {
        $value = (& git -C $WorktreePath rev-parse --git-common-dir 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
          throw "git rev-parse --git-common-dir failed for '$WorktreePath': $value"
        }
        $value
      }
      if (-not [System.IO.Path]::IsPathRooted($commonDir)) {
        $commonDir = Join-Path $WorktreePath $commonDir
      }
      $mainRepoPath = (& $readBoundary 'ResolveMainRepository' $commonDir { Resolve-Path -LiteralPath (Split-Path -Path $commonDir -Parent) -ErrorAction Stop }).Path.TrimEnd('\')
      $repoName = Split-Path -Path $mainRepoPath -Leaf
      $result.RepositoryName = $repoName

      # --- Resolve the durable memory root --------------------------------
      if ([string]::IsNullOrWhiteSpace($AIAgentMemoryRoot)) {
        $dropboxBase = $null
        if ($global:settings -and $global:configRootKeys -and $global:configRootKeys['DropboxBasePathConfigRootKey']) {
          $dropboxBase = $global:settings[$global:configRootKeys['DropboxBasePathConfigRootKey']]
        }
        if ([string]::IsNullOrWhiteSpace($dropboxBase)) {
          $result.Skipped = $true
          $result.SkipReason = 'DropboxBasePathConfigRootKey is unavailable ($global:settings is empty, e.g. a shell started without the PowerShell profile). Memory junction not provisioned; no path was guessed.'
          $result.Success = $true
          $result.Disposition = 'Skipped'
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $result.SkipReason
          return [PSCustomObject]$result
        }
        $AIAgentMemoryRoot = Join-Path ($dropboxBase -replace '/', '\') (Join-Path $env:USERNAME 'ATAP\AIAgentMemory')
      }

      $memoryTarget = Join-Path $AIAgentMemoryRoot $repoName
      $result.MemoryRoot = $memoryTarget

      if ($PSCmdlet.ShouldProcess($memoryTarget, 'Ensure durable AI agent memory store')) {
        if (-not (& $readBoundary 'ReadMemoryStore' $memoryTarget { Test-Path -LiteralPath $memoryTarget -PathType Container -ErrorAction Stop })) {
          $activeAction = & $beginAction 'CreateStore' $null $memoryTarget
          New-Item -ItemType Directory -Path $memoryTarget -Force -ErrorAction Stop | Out-Null
          & $finishAction $activeAction
          $activeAction = $null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created memory store '$memoryTarget'"
        }
      } else {
        & $recordDeclined 'EnsureStore' $memoryTarget
      }

      # --- Junction both slugs at the one store ---------------------------
      $slugs = @((& $makeSlug $mainRepoPath), (& $makeSlug ($WorktreePath.TrimEnd('\'))))
      $junctions = [System.Collections.Generic.List[object]]::new()

      foreach ($slug in ($slugs | Select-Object -Unique)) {
        $projDir = Join-Path $ClaudeProjectsRoot $slug
        $memLink = Join-Path $projDir 'memory'

        if ($PSCmdlet.ShouldProcess($memLink, "Junction -> $memoryTarget")) {
          if (-not (& $readBoundary 'ReadProjectDirectory' $projDir { Test-Path -LiteralPath $projDir -PathType Container -ErrorAction Stop })) {
            $activeAction = & $beginAction 'CreateProjectDirectory' $null $projDir
            New-Item -ItemType Directory -Path $projDir -Force -ErrorAction Stop | Out-Null
            & $finishAction $activeAction
            $activeAction = $null
          }

          if (& $readBoundary 'ReadMemoryLinkPath' $memLink { Test-Path -LiteralPath $memLink -ErrorAction Stop }) {
            $existing = & $readBoundary 'ReadMemoryLinkItem' $memLink { Get-Item -LiteralPath $memLink -Force -ErrorAction Stop }
            if ($existing.LinkType) {
              # Already a link: replace so the target is guaranteed current.
              $activeAction = & $beginAction 'RemoveExistingLink' $memLink $null
              Remove-Item -LiteralPath $memLink -Force -ErrorAction Stop
              & $finishAction $activeAction
              $activeAction = $null
            } else {
              # A REAL directory holding real memory files. Never clobber it;
              # migrate its contents into the durable store first.
              # Complete the read before migration; failed enumeration is not empty.
              $memoryFiles = @(& $readBoundary 'ReadMemoryFiles' $memLink { Get-ChildItem -LiteralPath $memLink -File -ErrorAction Stop })
              $memoryFiles | ForEach-Object {
                $dest = Join-Path $memoryTarget $_.Name
                if (-not (& $readBoundary 'ReadMigrationDestination' $dest { Test-Path -LiteralPath $dest -ErrorAction Stop })) {
                  $activeAction = & $beginAction 'MoveMemoryFile' $_.FullName $dest
                  Move-Item -LiteralPath $_.FullName -Destination $dest -ErrorAction Stop
                  & $finishAction $activeAction
                  if ($activeAction.State -eq 'Completed') {
                    $result.FilesMoved += [PSCustomObject]@{ Source = $_.FullName; Target = $dest }
                  }
                  $activeAction = $null
                  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Migrated pre-existing memory file '$($_.Name)' into '$memoryTarget'"
                }
              }
              if (@(& $readBoundary 'ReadRemainingMemoryEntries' $memLink { Get-ChildItem -LiteralPath $memLink -Force -ErrorAction Stop }).Count -gt 0) {
                throw "Refusing to replace non-empty real directory '$memLink' with a junction; migrate its contents manually."
              }
              $activeAction = & $beginAction 'RemoveEmptyMemoryDirectory' $memLink $null
              Remove-Item -LiteralPath $memLink -Recurse -Force -ErrorAction Stop
              & $finishAction $activeAction
              $activeAction = $null
            }
          }

          $activeAction = & $beginAction 'CreateJunction' $null $memLink
          New-Item -ItemType Junction -Path $memLink -Target $memoryTarget -ErrorAction Stop | Out-Null
          & $finishAction $activeAction
          if ($activeAction.State -eq 'Completed') {
            $result.JunctionsCreated++
            $junctions.Add([PSCustomObject]@{ Slug = $slug; Link = $memLink; Target = $memoryTarget })
            $result.Junctions = $junctions.ToArray()
          }
          $activeAction = $null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Junction '$memLink' -> '$memoryTarget'"
        } else {
          & $recordDeclined 'Junction' $memLink
        }
      }

      $result.Junctions = $junctions.ToArray()
      if ($result.HasUncertainEffects) {
        $result.Disposition = 'PartialFailure'
      } elseif ($result.DeclinedActions -gt 0) {
        $result.Disposition = if ($result.Changed) { 'PartialFailure' } elseif ($WhatIfPreference) { 'Planned' } else { 'Declined' }
      } else {
        $result.Success = $true
        $result.Disposition = if ($result.Changed) { 'Completed' } else { 'NoChange' }
      }
    } catch {
      $result.Success = $false
      if ($null -ne $activeAction -and $activeAction.State -eq 'Attempted') {
        $activeAction.State = 'Uncertain'
        $activeAction.Error = $_.Exception.Message
        $result.HasUncertainEffects = $true
      }
      $result.Disposition = if ($result.Changed -or $result.HasUncertainEffects) { 'PartialFailure' } else { 'Failed' }
      $result.Progress += [PSCustomObject]@{
        Kind = 'FailureBoundary'; Source = $null; Target = $WorktreePath
        State = 'Failed'; Error = $_.Exception.Message; Evidence = 'CaughtException'
      }
      $result.Errors += $_.Exception.Message
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "$fn failed for '$WorktreePath': $($_.Exception.Message)"
    }

    return [PSCustomObject]$result
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
