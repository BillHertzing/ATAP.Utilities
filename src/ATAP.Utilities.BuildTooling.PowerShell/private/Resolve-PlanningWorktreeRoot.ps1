function Resolve-PlanningWorktreeRoot {
  <#
  .SYNOPSIS
    Resolve the _Planning worktree root that the ScopeCreep ledgers live under,
    fail-safe against silently writing to the stable (main) worktree.
  .DESCRIPTION
    Resolution order:
      1. Explicit -PlanningRoot (validated to contain
         ScopeCreepManagement\ScopeCreep-Inbox.md). Honored for sprint OR stable.
      2. Sprint context: detect a '<repo>-wt-<issue>-Sprint-<NNNN>-work-items'
         segment in one of the -ContextPath entries (current location, caller's
         script root). The Sprint token - NOT the issue number - is the stable
         anchor across repos (e.g. ATAP.Utilities-wt-110-... pairs with
         _Planning-wt-18-... because both end in 'Sprint-0009-work-items'). When a
         sprint context is detected, locate a sibling
         '_Planning*-wt-*-Sprint-<NNNN>-work-items' worktree in the repos parent,
         and failing that a widened 'OverView*.code-workspace' fallback that yields
         a sprint _Planning worktree. If a sprint context is detected but NO sprint
         _Planning worktree can be found, THROW with remediation rather than fall
         back to the stable _Planning (main) worktree.
      3. No sprint context (genuine stable maintenance): resolve the stable
         _Planning worktree (workspace file, else <ReposParent>\_Planning) and
         return it flagged IsSprint=$false.
  .PARAMETER PlanningRoot
    Explicit _Planning worktree root supplied by the caller. Overrides all
    auto-resolution.
  .PARAMETER ContextPath
    Candidate paths used to detect the active sprint context (typically the
    current location and the caller's $PSScriptRoot).
  .PARAMETER ReposParent
    Fallback GitHub repos-parent folder used when no sprint context is detected
    or when the detected context does not yield a parent.
  .OUTPUTS
    PSCustomObject with PlanningRoot, Method, IsSprint, SprintToken.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Add-ScopeCreepIdea
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [string]$PlanningRoot,

    [string[]]$ContextPath = @(),

    [string]$ReposParent
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
    Set-StrictMode -Version Latest

    function Test-PlanningRootHasInbox {
      param([string]$Root)
      if (-not $Root) { return $false }
      $candidate = Join-Path -Path $Root -ChildPath 'ScopeCreepManagement\ScopeCreep-Inbox.md'
      return [bool](Test-Path -LiteralPath $candidate -PathType Leaf)
    }

    function Get-SprintContext {
      param([string[]]$Paths)
      foreach ($p in $Paths) {
        if (-not $p) { continue }
        $segments = $p -split '[\\/]'
        for ($i = $segments.Count - 1; $i -ge 0; $i--) {
          if ($segments[$i] -match '^(?<repo>.+)-wt-(?<issue>.+?)-(?<sprint>Sprint-\d+-work-items)$') {
            $sep = [System.IO.Path]::DirectorySeparatorChar
            $parent = if ($i -ge 1) { ($segments[0..($i - 1)] -join $sep) } else { '' }
            return [pscustomobject]@{
              SprintToken = $Matches['sprint']
              ReposParent = $parent
            }
          }
        }
      }
      return $null
    }

    function Resolve-FromWorkspace {
      param(
        [string]$WorkspaceReposParent,
        [string]$SprintToken,
        [switch]$RequireSprint
      )
      if (-not $WorkspaceReposParent) { return $null }
      $wsFiles = @(
        Get-ChildItem -Path $WorkspaceReposParent -Filter 'OverView*.code-workspace' -File -ErrorAction SilentlyContinue
      )
      foreach ($wsFile in @($wsFiles | Sort-Object LastWriteTime -Descending)) {
        $wsContent = Get-Content -LiteralPath $wsFile.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $wsContent) { continue }
        foreach ($match in [regex]::Matches($wsContent, '"path"\s*:\s*"(?<Path>[^"]+)"')) {
          $candidate = $match.Groups['Path'].Value -replace '/', '\'
          if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path -Path $WorkspaceReposParent -ChildPath $candidate
          }
          $leaf = Split-Path -Path $candidate -Leaf
          if ($leaf -notlike '_Planning*') { continue }
          if ($RequireSprint) {
            if ($leaf -notmatch "-wt-.*-$([regex]::Escape($SprintToken))$") { continue }
          }
          if (Test-PlanningRootHasInbox -Root $candidate) {
            $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
            return $(if ($resolved) { $resolved.Path } else { $candidate })
          }
        }
      }
      return $null
    }
  }

  process {
    # 1. Explicit override - honored for sprint or stable; only requires a valid inbox.
    if ($PlanningRoot) {
      if (-not (Test-PlanningRootHasInbox -Root $PlanningRoot)) {
        throw "Resolve-PlanningWorktreeRoot: explicit -PlanningRoot '$PlanningRoot' does not contain ScopeCreepManagement\ScopeCreep-Inbox.md."
      }
      $resolved = Resolve-Path -LiteralPath $PlanningRoot -ErrorAction SilentlyContinue
      $rootPath = $(if ($resolved) { $resolved.Path } else { $PlanningRoot })
      $leaf = Split-Path -Path $rootPath -Leaf
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved _Planning worktree from explicit -PlanningRoot: $rootPath"
      return [pscustomobject]@{
        PlanningRoot = $rootPath
        Method       = 'ExplicitPlanningRoot'
        IsSprint     = [bool]($leaf -match '-wt-.*-Sprint-\d+-work-items$')
        SprintToken  = $null
      }
    }

    # 2. Sprint context detection.
    $ctx = Get-SprintContext -Paths $ContextPath
    if ($ctx) {
      $sprintToken = $ctx.SprintToken
      $ctxReposParent = if ($ctx.ReposParent) { $ctx.ReposParent } elseif ($ReposParent) { $ReposParent } else { '' }

      # 2a. Sibling '_Planning*-wt-*-<sprintToken>' worktree in the repos parent.
      if ($ctxReposParent) {
        $siblings = @(
          Get-ChildItem -Path $ctxReposParent -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "_Planning*-wt-*-$sprintToken" }
        )
        foreach ($sib in @($siblings | Sort-Object Name)) {
          if (Test-PlanningRootHasInbox -Root $sib.FullName) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved sprint _Planning worktree via sibling scan: $($sib.FullName)"
            return [pscustomobject]@{
              PlanningRoot = $sib.FullName
              Method       = 'SprintSiblingWorktree'
              IsSprint     = $true
              SprintToken  = $sprintToken
            }
          }
        }
      }

      # 2b. Widened workspace-file fallback - must yield a SPRINT _Planning worktree.
      $sprintFromWs = Resolve-FromWorkspace -WorkspaceReposParent $ctxReposParent -SprintToken $sprintToken -RequireSprint
      if ($sprintFromWs) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolved sprint _Planning worktree via workspace file: $sprintFromWs"
        return [pscustomobject]@{
          PlanningRoot = $sprintFromWs
          Method       = 'SprintWorkspaceFile'
          IsSprint     = $true
          SprintToken  = $sprintToken
        }
      }

      # 2c. Refuse to silently fall back to the stable (main) worktree in a sprint context.
      throw @"
Resolve-PlanningWorktreeRoot: detected sprint context '$sprintToken' but could not locate a sprint _Planning worktree under '$ctxReposParent'.
Refusing to fall back to the stable _Planning (main) worktree for sprint work.
Remediation: pass -PlanningRoot '<reposParent>\_Planning-wt-<issue>-$sprintToken' explicitly, or create the sprint _Planning worktree before capturing scope-creep ideas.
"@
    }

    # 3. No sprint context detected - genuine stable maintenance is acceptable.
    $stableParent = if ($ReposParent) { $ReposParent } else { @($ContextPath | Where-Object { $_ } | Select-Object -First 1) }
    if ($stableParent) {
      $fromWs = Resolve-FromWorkspace -WorkspaceReposParent $stableParent
      if ($fromWs) {
        $leaf = Split-Path -Path $fromWs -Leaf
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Resolved _Planning worktree from workspace file (no sprint context detected): $fromWs"
        return [pscustomobject]@{
          PlanningRoot = $fromWs
          Method       = 'WorkspaceFile'
          IsSprint     = [bool]($leaf -match '-wt-.*-Sprint-\d+-work-items$')
          SprintToken  = $null
        }
      }

      $stable = Join-Path -Path $stableParent -ChildPath '_Planning'
      if (Test-PlanningRootHasInbox -Root $stable) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Resolved stable _Planning worktree (no sprint context detected): $stable"
        return [pscustomobject]@{
          PlanningRoot = $stable
          Method       = 'StableReposParent'
          IsSprint     = $false
          SprintToken  = $null
        }
      }
    }

    throw "Resolve-PlanningWorktreeRoot: could not resolve any _Planning worktree (no sprint context, no workspace match, and no '_Planning\ScopeCreepManagement\ScopeCreep-Inbox.md' under '$stableParent'). Pass -PlanningRoot explicitly."
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
