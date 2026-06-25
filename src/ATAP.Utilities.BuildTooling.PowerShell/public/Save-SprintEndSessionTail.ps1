function Save-SprintEndSessionTail {
  <#
  .SYNOPSIS
  Checkpoints and commits the final SprintEnd session tail in stable Planning.

  .DESCRIPTION
  Runs Save-SprintWorkSession against the stable Planning repository after its
  sprint PR has merged, then stages and commits only the canonical conversation,
  memory, and roster directories. This preserves work created after the Planning
  PR merge without treating any agent-local memory directory as the shared
  system of record. The command does not push.

  .PARAMETER PlanningRoot
  Stable Planning repository on its main branch.

  .PARAMETER SprintNumber
  Closing sprint number.

  .PARAMETER Agent
  Agent family forwarded to Save-SprintWorkSession.

  .PARAMETER ConversationId
  Optional Antigravity conversation identifier.

  .PARAMETER SessionId
  Optional Codex session identifier.

  .PARAMETER ConversationFile
  Optional reconstructed Copilot conversation file.

  .PARAMETER CommitMessage
  Commit message for the canonical final-tail artifacts.

  .OUTPUTS
  PSCustomObject containing checkpoint, changed-path, and commit information.

  .EXAMPLE
  Save-SprintEndSessionTail -PlanningRoot C:\Repos\_Planning `
    -SprintNumber 10 -Agent Codex -SessionId $sessionId

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$PlanningRoot,

    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidateSet('ClaudeCode', 'Antigravity', 'Codex', 'Copilot')]
    [string]$Agent,

    [Parameter()]
    [string]$ConversationId,

    [Parameter()]
    [string]$SessionId,

    [Parameter()]
    [string]$ConversationFile,

    [Parameter()]
    [string]$CommitMessage
  )

  begin {
    $fn = 'Save-SprintEndSessionTail'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $planningRootFull = [IO.Path]::GetFullPath($PlanningRoot)
    $branchResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
      -ArgumentList @('-C', $planningRootFull, 'branch', '--show-current') `
      -AllowNonZeroExitCode
    $branch = ($branchResult.Output -join '').Trim()
    if (-not $branchResult.Succeeded -or $branch -notin @('main', 'master')) {
      throw "Final session tail must be committed from stable Planning main/master; current branch is '$branch'."
    }

    $sprintText = '{0:D4}' -f $SprintNumber
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
      $CommitMessage = "chore(sprint-$sprintText): preserve final session tail"
    }
    $checkpointParameters = @{
      Agent             = $Agent
      SprintN           = $sprintText
      PlanningRoot      = $planningRootFull
      GitHubRoot        = Split-Path -Path $planningRootFull -Parent
      AllowMainFallback = $true
      Confirm           = $false
    }
    if (-not [string]::IsNullOrWhiteSpace($ConversationId)) {
      $checkpointParameters.ConversationId = $ConversationId
    }
    if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
      $checkpointParameters.SessionId = $SessionId
    }
    if (-not [string]::IsNullOrWhiteSpace($ConversationFile)) {
      $checkpointParameters.ConversationFile = $ConversationFile
    }
    if ($WhatIfPreference) {
      $checkpointParameters.WhatIf = $true
    }

    $savedLocation = Get-Location
    try {
      Set-Location -LiteralPath $planningRootFull
      Save-SprintWorkSession @checkpointParameters
    } finally {
      Set-Location -LiteralPath $savedLocation
    }

    $canonicalPaths = @(
      'SprintWorkSessionConversations',
      'SprintWorkSessionMemorys',
      'SprintWorkSessionRoster'
    )
    $statusArguments = @(
      '-C',
      $planningRootFull,
      'status',
      '--porcelain=v1',
      '--'
    ) + $canonicalPaths
    $statusResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
      -ArgumentList $statusArguments `
      -AllowNonZeroExitCode
    $changedPaths = @($statusResult.Output | Where-Object { $_ })
    $commitHash = $null
    $committed = $false

    if ($changedPaths.Count -gt 0 -and $PSCmdlet.ShouldProcess(
        $planningRootFull,
        "Commit final Sprint $sprintText checkpoint tail"
      )) {
      $addArguments = @('-C', $planningRootFull, 'add', '--') + $canonicalPaths
      $addResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList $addArguments `
        -AllowNonZeroExitCode
      if (-not $addResult.Succeeded) {
        throw "Failed to stage final session-tail artifacts: $($addResult.Output -join '; ')"
      }
      $commitResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @(
          '-C',
          $planningRootFull,
          '-c',
          'core.editor=true',
          'commit',
          '--no-edit',
          '-m',
          $CommitMessage
        ) `
        -AllowNonZeroExitCode
      if (-not $commitResult.Succeeded) {
        throw "Failed to commit final session-tail artifacts: $($commitResult.Output -join '; ')"
      }
      $hashResult = Invoke-SprintEndNativeCommand -FilePath 'git' `
        -ArgumentList @('-C', $planningRootFull, 'rev-parse', 'HEAD') `
        -AllowNonZeroExitCode
      $commitHash = ($hashResult.Output -join '').Trim()
      $committed = $true
    }

    return [PSCustomObject]@{
      Ok             = $statusResult.Succeeded
      SprintNumber   = $sprintText
      PlanningRoot   = $planningRootFull
      Agent          = $Agent
      CanonicalPaths = $canonicalPaths
      ChangedPaths   = $changedPaths
      Committed      = $committed
      CommitHash     = $commitHash
      Pushed         = $false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
