function Add-ScopeCreepIdea {
  <#
  .SYNOPSIS
    Capture a new scope-creep idea into ScopeCreep-Inbox.md.
  .DESCRIPTION
    Appends a formatted SC-NNNN entry to ScopeCreep-Inbox.md with auto-incremented ID.
    Runs interactively when parameters are omitted; fully parameterizable for profile aliases.
  .PARAMETER Title
    Short, imperative description of the idea.
  .PARAMETER SuggestedBy
    Name or handle of the person suggesting the idea. Defaults to Self.
  .PARAMETER Repo
    Primary repository affected.
  .PARAMETER Context
    Feature area, plugin, or layer the idea touches.
  .PARAMETER InitialSize
    Rough effort: XS, S, M, L, or XL.
  .PARAMETER Description
    Free-form description. Can be multi-line if passed as a here-string.
  .PARAMETER Paste
    Reads the description from the clipboard instead of prompting.
  .PARAMETER Tags
    Optional comma-separated PascalCase tags from Tags-Taxonomy.md. When omitted in
    a non-interactive session, capture continues without a Tags line.
  .PARAMETER GitCommit
    Stages ScopeCreep-Inbox.md and commits with a structured message.
  .PARAMETER PlanningRoot
    Explicit _Planning worktree root to target (must contain
    ScopeCreepManagement\ScopeCreep-Inbox.md). Overrides automatic sprint/stable
    worktree resolution. Use this to deliberately target the stable _Planning
    (main) worktree; auto-resolution will otherwise refuse to fall back to stable
    when a sprint context is detected.
  .OUTPUTS
    PSCustomObject describing the captured scope-creep entry.
  .EXAMPLE
    Add-ScopeCreepIdea
  .EXAMPLE
    Add-ScopeCreepIdea -Title 'Cache tile prefetch on WiFi' -SuggestedBy 'Self' -Repo AceCommander -Context 'Outdoor Sharing / tile cache' -InitialSize S -Description 'Pre-fetch next zoom level on WiFi to cut wait time.' -GitCommit
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    ScopeCreep-Inbox.md
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [string]$Title,

    [string]$SuggestedBy,

    [ValidateSet('AceCommander', 'ATAP.Utilities', 'SharedVSCode', '_Planning', 'Cross-Repo')]
    [string]$Repo,

    [string]$Context,

    [ValidateSet('XS', 'S', 'M', 'L', 'XL')]
    [string]$InitialSize,

    [string]$Description,

    [switch]$Paste,

    [string]$Tags,

    [switch]$GitCommit,

    [string]$PlanningRoot
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PlanningSession.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
    Set-StrictMode -Version Latest

    # Dependency fallback for direct source execution. Normal module import loads
    # GitWorktree through RequiredModules before this function is invoked.
    if (-not (Get-Command -Name 'Resolve-PlanningWorktreeRoot' -ErrorAction SilentlyContinue)) {
      Import-Module ATAP.Utilities.BuildTooling.GitWorktree.PowerShell -MinimumVersion 0.1.3 -ErrorAction Stop
    }

    function Get-ReposRootFromPSScriptRoot {
      [CmdletBinding()]
      param()

      $candidate = $PSScriptRoot
      for ($level = 0; $level -lt 4; $level++) {
        $candidate = Split-Path -Path $candidate -Parent
      }

      return $candidate
    }

    function Prompt-RequiredValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Field,

        [string]$Hint = ''
      )

      $prompt = if ($Hint) { "$Field ($Hint)" } else { $Field }
      $value = ''
      while (-not $value.Trim()) {
        $value = Read-Host "  $prompt"
        if (-not $value.Trim()) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "$Field is required and cannot be blank."
        }
      }

      return $value.Trim()
    }

    function Prompt-MenuValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Field,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Options
      )

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Host -Message "  $Field"
      for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Host -Message "    [$($i + 1)] $($Options[$i])"
      }

      $choice = ''
      while ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $Options.Count) {
        $choice = Read-Host "  Choice (1-$($Options.Count))"
      }

      return $Options[[int]$choice - 1]
    }
  }

  process {
    # Resolve the target _Planning worktree from the active git/path context.
    # The resolver refuses to silently fall back to the stable (main) worktree
    # when a sprint context is detected; pass -PlanningRoot to override.
    $contextPaths = @()
    try {
      $contextPaths += (Get-Location).Path
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Could not read current location for sprint-context detection: $($_.Exception.Message)"
    }
    if ($PSScriptRoot) { $contextPaths += $PSScriptRoot }

    $resolution = Resolve-PlanningWorktreeRoot `
      -PlanningRoot $PlanningRoot `
      -ContextPath $contextPaths `
      -ReposParent (Get-ReposRootFromPSScriptRoot)
    $planningRoot = $resolution.PlanningRoot
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "ScopeCreep target _Planning worktree: $planningRoot (method=$($resolution.Method), sprint=$($resolution.IsSprint))"

    $scopeCreepPath = Join-Path -Path $planningRoot -ChildPath 'ScopeCreepManagement'
    $inboxPath = Join-Path -Path $scopeCreepPath -ChildPath 'ScopeCreep-Inbox.md'
    $adoptedPath = Join-Path -Path $scopeCreepPath -ChildPath 'ScopeCreep-Adopted.md'
    $deferredPath = Join-Path -Path $scopeCreepPath -ChildPath 'ScopeCreep-Deferred.md'

    if (-not (Test-Path -LiteralPath $inboxPath -PathType Leaf)) {
      throw "ScopeCreep-Inbox.md not found at: $inboxPath"
    }

    $trackedPaths = @($inboxPath, $adoptedPath, $deferredPath)
    $existingIds = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($trackedPath in $trackedPaths) {
      if (-not (Test-Path -LiteralPath $trackedPath -PathType Leaf)) {
        continue
      }

      $content = Get-Content -LiteralPath $trackedPath -Raw -ErrorAction Stop
      foreach ($match in [regex]::Matches($content, '(?m)^##\s+SC-(\d{4})\b')) {
        [void]$existingIds.Add([int]$match.Groups[1].Value)
      }
    }

    $existingIdValues = @($existingIds)
    $nextNum = if ($existingIdValues.Count -gt 0) { ([int](($existingIdValues | Measure-Object -Maximum).Maximum) + 1) } else { 1 }
    while ($existingIds.Contains([int]$nextNum)) {
      $nextNum++
    }
    $scId = 'SC-{0:D4}' -f $nextNum

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Adding $scId to ScopeCreep-Inbox.md"

    if (-not $Title) { $Title = Prompt-RequiredValue -Field 'Title' -Hint 'short imperative phrase' }
    if (-not $SuggestedBy) {
      $rawSuggestedBy = Read-Host '  SuggestedBy (name/handle, Enter = Self)'
      $SuggestedBy = if ($rawSuggestedBy.Trim()) { $rawSuggestedBy.Trim() } else { 'Self' }
    }
    if (-not $Repo) {
      $Repo = Prompt-MenuValue -Field 'Repo' -Options @('AceCommander', 'ATAP.Utilities', 'SharedVSCode', '_Planning', 'Cross-Repo')
    }
    if (-not $Context) { $Context = Prompt-RequiredValue -Field 'Context' -Hint 'plugin / layer / feature area' }
    if (-not $InitialSize) {
      $InitialSize = Prompt-MenuValue -Field 'Initial size [XS <2h | S half-day to 1d | M 2-4d | L 1-2wk | XL >2wk]' -Options @('XS', 'S', 'M', 'L', 'XL')
    }
    if ($Paste -and -not $Description) {
      $Description = Get-Clipboard
      if ([string]::IsNullOrWhiteSpace($Description)) {
        throw '-Paste was specified but the clipboard is empty.'
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Description read from clipboard.'
    }
    if (-not $Description) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Host -Message '  Description (single line; you can expand in the file later):'
      $Description = Prompt-RequiredValue -Field 'Description'
    }
    if (-not $Tags) {
      $rawTags = ''
      try {
        $rawTags = Read-Host '  Tags (optional, comma-separated PascalCase from Tags-Taxonomy.md, Enter to skip)' -ErrorAction Stop
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Optional tags prompt is unavailable; continuing without tags. $($_.Exception.Message)"
      }
      $Tags = $rawTags.Trim()
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $descLines = $Description -split "`n"
    $descFormatted = $descLines[0]
    if ($descLines.Count -gt 1) {
      $rest = $descLines[1..($descLines.Count - 1)] | ForEach-Object { "  $_" }
      $descFormatted = $descFormatted + "`n" + ($rest -join "`n")
    }

    $tagsLine = if ($Tags) { "`n- **Tags**: $Tags" } else { '' }
    $entry = @"


## $scId
- **Title**: $Title
- **SuggestedBy**: $SuggestedBy
- **SuggestedDate**: $timestamp
- **Repo**: $Repo
- **Context**: $Context
- **InitialSize**: $InitialSize$tagsLine
- **Status**: Inbox
- **Description**: >
  $descFormatted
"@

    if ($PSCmdlet.ShouldProcess($inboxPath, "Append $scId")) {
      Add-Content -LiteralPath $inboxPath -Value $entry -Encoding UTF8 -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Recorded $scId - $Title"
    }

    if ($GitCommit) {
      Push-Location -LiteralPath $planningRoot
      try {
        if ($PSCmdlet.ShouldProcess($planningRoot, "Commit $scId")) {
          $relativeInboxPath = Resolve-Path -LiteralPath $inboxPath -Relative
          git add $relativeInboxPath
          git commit -m "chore(inbox): capture $scId - $Title"
          if ($LASTEXITCODE -ne 0) {
            throw "git commit failed with exit code $LASTEXITCODE."
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Committed scope-creep entry to git.'
        }
      } finally {
        Pop-Location
      }
    }

    [PSCustomObject]@{
      ScopeCreepId   = $scId
      InboxPath      = $inboxPath
      PlanningRoot   = $planningRoot
      ResolvedVia    = $resolution.Method
      IsSprintTarget = $resolution.IsSprint
      Title          = $Title
      Repo           = $Repo
      GitCommitted   = [bool]$GitCommit
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
