function Set-ClaudeSettingsSymlink {
  <#
  .SYNOPSIS
    Renders the Claude Code user settings file from the SharedVSCode overlay.
  .DESCRIPTION
    Retains the historical function name for sprint-boundary callers, but no
    longer creates a symlink. The cmdlet writes a real
    ~/.claude/settings.json file from
    .ai/config/claudecode/settings.overlay.json, resolving stable and sprint
    worktree placeholders before preserving unmanaged local root keys already
    present in the target. Existing target bytes are backed up before mutation
    and restored if a later write step fails.
  .PARAMETER SharedVSCodeWorktreePath
    Path to the SharedVSCode worktree containing the canonical Claude Code
    overlay under .ai/config/claudecode/settings.overlay.json.
  .PARAMETER OmitSprintWorktrees
    Omits standalone sprint-worktree entries and resolves the Claude hook to
    stable SharedVSCode. Use at the End boundary.
  .PARAMETER AllowUserGlobalWrite
    Required for live mutation of ~/.claude/settings.json.
  .PARAMETER CheckpointConfirmed
    Required for live mutation of ~/.claude/settings.json after a checkpoint.
  .OUTPUTS
    PSCustomObject describing the target path, backup path, and action.
  .EXAMPLE
    Set-ClaudeSettingsSymlink -SharedVSCodeWorktreePath 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-54-Sprint-0012-work-items' -AllowUserGlobalWrite -CheckpointConfirmed
  .LINK
    Set-SprintBoundaryContext
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedVSCodeWorktreePath,

    [switch]$AllowUserGlobalWrite,

    [switch]$CheckpointConfirmed,

    [switch]$OmitSprintWorktrees,

    [string]$UserProfilePath = $env:USERPROFILE,

    [string]$BackupRoot,

    [switch]$InjectFailureAfterBackup
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function ConvertTo-LocalHashtable {
      param(
        [AllowNull()]
        [object]$InputObject
      )

      if ($null -eq $InputObject) { return $null }
      if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
          $result[$key] = ConvertTo-LocalHashtable -InputObject $InputObject[$key]
        }
        return $result
      }
      if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertTo-LocalHashtable -InputObject $_ })
      }
      if ($InputObject.PSObject -and $InputObject.PSObject.Properties.Count -gt 0 -and $InputObject -isnot [string]) {
        $result = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
          $result[$property.Name] = ConvertTo-LocalHashtable -InputObject $property.Value
        }
        return $result
      }
      return $InputObject
    }

    function Get-LocalWorktreePathForToken {
      param([string]$Token, [string]$WorktreeRootFull, [string]$GhRoot, [switch]$OmitSprintWorktrees)

      if ($Token -notmatch '^\$\{(SPRINT|STABLE)_WORKTREE_PATH_([A-Z_]+)\}$') { return $null }
      $kind = $Matches[1]
      $repoKey = $Matches[2]
      $repoFolders = @{
        SHAREDVSCODE = 'SharedVSCode'; ATAP_PLANNING = '_Planning';
        ATAP_UTILITIES = 'ATAP.Utilities'; ATAP_IAC = 'ATAP.IAC'; ACECOMMANDER = 'AceCommander'
      }
      if (-not $repoFolders.ContainsKey($repoKey)) { return $null }
      $folder = $repoFolders[$repoKey]
      if ($kind -eq 'STABLE') {
        $stablePath = Join-Path $GhRoot $folder
        if (Test-Path -LiteralPath $stablePath -PathType Container) { return [IO.Path]::GetFullPath($stablePath) }
        return $null
      }
      if ($OmitSprintWorktrees) { return $null }
      $sprintPattern = '^' + [regex]::Escape($folder) + '-wt-\d+-Sprint-\d{4}-work-items$'
      if ((Split-Path $WorktreeRootFull -Leaf) -match $sprintPattern) { return $WorktreeRootFull }
      $newest = Get-ChildItem -LiteralPath $GhRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $sprintPattern } |
        Sort-Object Name -Descending |
        Select-Object -First 1
      if ($newest) { return [IO.Path]::GetFullPath($newest.FullName) }
      if ($repoKey -eq 'SHAREDVSCODE') { return $WorktreeRootFull }
      return $null
    }

    function Resolve-LocalWorktreePlaceholderNode {
      param([AllowNull()]$Node, [string]$WorktreeRootFull, [string]$GhRoot, [switch]$OmitSprintWorktrees)

      if ($null -eq $Node) { return $null }
      if ($Node -is [string]) {
        $result = $Node
        foreach ($match in [regex]::Matches($Node, '\$\{(?:SPRINT|STABLE)_WORKTREE_PATH_[A-Z_]+\}')) {
          $token = $match.Value
          $resolved = if ($OmitSprintWorktrees -and $Node -match 'PreToolUse-PwshGuard\.ps1' -and $token -eq '${SPRINT_WORKTREE_PATH_SHAREDVSCODE}') {
            Get-LocalWorktreePathForToken -Token '${STABLE_WORKTREE_PATH_SHAREDVSCODE}' -WorktreeRootFull $WorktreeRootFull -GhRoot $GhRoot
          } else {
            Get-LocalWorktreePathForToken -Token $token -WorktreeRootFull $WorktreeRootFull -GhRoot $GhRoot -OmitSprintWorktrees:$OmitSprintWorktrees
          }
          if ($null -ne $resolved) { $result = $result.Replace($token, $resolved) }
        }
        return $result
      }
      if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in @($Node.Keys)) {
          $Node[$key] = Resolve-LocalWorktreePlaceholderNode -Node $Node[$key] -WorktreeRootFull $WorktreeRootFull -GhRoot $GhRoot -OmitSprintWorktrees:$OmitSprintWorktrees
        }
        return $Node
      }
      if ($Node -is [System.Collections.IEnumerable]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($element in $Node) {
          if ($element -is [string] -and $element -match '^\$\{SPRINT_WORKTREE_PATH_[A-Z_]+\}$' -and $OmitSprintWorktrees) { continue }
          $items.Add((Resolve-LocalWorktreePlaceholderNode -Node $element -WorktreeRootFull $WorktreeRootFull -GhRoot $GhRoot -OmitSprintWorktrees:$OmitSprintWorktrees))
        }
        return , $items.ToArray()
      }
      return $Node
    }
  }

  process {
    if ([string]::IsNullOrWhiteSpace($UserProfilePath)) {
      throw 'UserProfilePath is empty; cannot resolve ~/.claude/settings.json.'
    }

    if (-not $WhatIfPreference) {
      if (-not $AllowUserGlobalWrite) {
        throw 'AllowUserGlobalWrite is required before writing ~/.claude/settings.json.'
      }
      if (-not $CheckpointConfirmed) {
        throw 'CheckpointConfirmed is required before writing ~/.claude/settings.json.'
      }
    }

    if (-not $PSBoundParameters.ContainsKey('OmitSprintWorktrees')) {
      $OmitSprintWorktrees = (Split-Path ([IO.Path]::GetFullPath($SharedVSCodeWorktreePath)) -Leaf) -ieq 'SharedVSCode'
    }

    $overlayPath = Join-Path $SharedVSCodeWorktreePath '.ai\config\claudecode\settings.overlay.json'
    $preservePath = Join-Path $SharedVSCodeWorktreePath '.ai\config\claudecode\local-preserve.json'
    $targetPath = Join-Path `
      -Path $UserProfilePath `
      -ChildPath '.claude' `
      -AdditionalChildPath 'settings.json'

    if (-not (Test-Path -LiteralPath $overlayPath -PathType Leaf)) {
      throw "Claude Code settings overlay not found at $overlayPath"
    }

    $overlay = Get-Content -LiteralPath $overlayPath -Raw |
      ConvertFrom-Json -Depth 100 -ErrorAction Stop
    $candidate = ConvertTo-LocalHashtable -InputObject $overlay
    $worktreeRootFull = [IO.Path]::GetFullPath($SharedVSCodeWorktreePath)
    $candidate = Resolve-LocalWorktreePlaceholderNode -Node $candidate -WorktreeRootFull $worktreeRootFull `
      -GhRoot (Split-Path $worktreeRootFull -Parent) -OmitSprintWorktrees:$OmitSprintWorktrees

    $unresolvedPlaceholderPattern = '\$\{(?:STABLE|SPRINT)_WORKTREE_PATH_[A-Z_]+\}'
    if (($candidate | ConvertTo-Json -Depth 100) -match $unresolvedPlaceholderPattern) {
      throw "Claude Code settings overlay contains unresolved worktree placeholders after resolution: $overlayPath"
    }

    $existingSettings = $null
    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
      try {
        $existingSettings = Get-Content -LiteralPath $targetPath -Raw |
          ConvertFrom-Json -Depth 100 -ErrorAction Stop
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Existing Claude settings at $targetPath are not valid JSON; unmanaged keys cannot be preserved. Exception: $($_.Exception.Message)"
      }
    }

    if ($existingSettings) {
      $existing = ConvertTo-LocalHashtable -InputObject $existingSettings
      foreach ($key in @($existing.Keys)) {
        if (-not $candidate.Contains($key)) {
          $candidate[$key] = $existing[$key]
        }
      }
    }

    if (Test-Path -LiteralPath $preservePath -PathType Leaf) {
      $preserve = Get-Content -LiteralPath $preservePath -Raw |
        ConvertFrom-Json -Depth 20 -ErrorAction Stop
      foreach ($key in @($preserve.preserveRootKeys)) {
        if ($existingSettings -and $existingSettings.PSObject.Properties[[string]$key]) {
          $candidate[[string]$key] = (ConvertTo-LocalHashtable -InputObject $existingSettings.PSObject.Properties[[string]$key].Value)
        }
      }
    }

    $candidateJson = ($candidate | ConvertTo-Json -Depth 100) + "`r`n"
    $targetDir = Split-Path -Path $targetPath -Parent
    $existingItem = Get-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
    $backupPath = $null
    $existingBytes = $null
    $existingLinkTarget = $null
    $existingWasLink = $false

    if ($existingItem) {
      $existingWasLink = [string]$existingItem.LinkType -eq 'SymbolicLink'
      if ($existingWasLink -and $existingItem.Target) {
        $existingLinkTarget = [string]@($existingItem.Target)[0]
      }
      if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        $existingBytes = [IO.File]::ReadAllBytes($targetPath)
      }
    }

    if (-not $BackupRoot) {
      $BackupRoot = Join-Path $SharedVSCodeWorktreePath '_generated\ClaudeSettingsBackups'
    }

    if (-not $PSCmdlet.ShouldProcess($targetPath, 'render real Claude Code settings file from SharedVSCode overlay')) {
      return [PSCustomObject]@{
        TargetPath = $targetPath
        OverlayPath = $overlayPath
        BackupPath = $null
        Action = 'whatif'
        LinkType = if ($existingItem) { [string]$existingItem.LinkType } else { $null }
      }
    }

    try {
      if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
      }
      if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
      }

      if ($existingItem) {
        $backupPath = Join-Path $BackupRoot ("settings.json.{0}.bak" -f ([DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss-ffff')))
        if ($existingBytes) {
          [IO.File]::WriteAllBytes($backupPath, $existingBytes)
        }
        else {
          [IO.File]::WriteAllText($backupPath, '', [Text.UTF8Encoding]::new($false))
        }
        Remove-Item -LiteralPath $targetPath -Force
      }

      if ($InjectFailureAfterBackup) {
        throw 'Injected failure after backup for rollback verification.'
      }

      [IO.File]::WriteAllText($targetPath, $candidateJson, [Text.UTF8Encoding]::new($false))
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Rendered real Claude Code settings file: $targetPath"

      return [PSCustomObject]@{
        TargetPath = $targetPath
        OverlayPath = $overlayPath
        PreservePath = if (Test-Path -LiteralPath $preservePath -PathType Leaf) { $preservePath } else { $null }
        BackupPath = $backupPath
        Action = 'rendered'
        LinkType = ''
      }
    }
    catch {
      try {
        if (Test-Path -LiteralPath $targetPath -ErrorAction SilentlyContinue) {
          Remove-Item -LiteralPath $targetPath -Force
        }
        if ($existingItem) {
          if ($existingWasLink -and -not [string]::IsNullOrWhiteSpace($existingLinkTarget)) {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $existingLinkTarget -Force | Out-Null
          }
          elseif ($existingBytes) {
            [IO.File]::WriteAllBytes($targetPath, $existingBytes)
          }
        }
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Rollback failed for $targetPath. Exception: $($_.Exception.Message)"
      }
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
