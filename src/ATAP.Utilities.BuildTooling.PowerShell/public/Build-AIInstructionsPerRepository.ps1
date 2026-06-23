<#
.SYNOPSIS
Materializes all per-repo AI instruction files for the current sprint in one call.

.DESCRIPTION
Build-AIInstructionsPerRepository is the single SprintStart orchestration entry point for
per-repository AI instruction materialization. It runs the three per-repo builders in the
canonical order required by the shared-core architecture (Task 10.23):

  1. Build-CLAUDEPerRepository       — CLAUDE.md = ai-local.md + CLAUDE-base.md (Claude).
  2. Build-AGENTSPerRepository       — AGENTS.md = ai-local.md (AI-LOCAL) + AGENTS-base.md
                                       (AI-CORE), the shared core for Codex / Antigravity /
                                       GitHub Copilot.
  3. Build-AgentSpecificPerRepository — distributes GEMINI.md and
                                       .github/copilot-instructions.md (per-agent deltas only,
                                       NO core body).

Each builder performs its own Overview-workspace discovery, stable-worktree skip guard, and
idempotent compare-before-write, so this orchestrator simply forwards WorktreeRoot /
WorkspacePath to all three and aggregates their results. A builder failure is recorded and
does not stop the remaining builders; overall Success is false if any builder failed.

Prerequisites: the canonical bases must already be rendered to the SharedVSCode worktree root
(CLAUDE-base.md, AGENTS-base.md, GEMINI.md, .github/copilot-instructions.md) by
Render-AIAdapters / Initialize-SprintAIAdapters before this runs.

.PARAMETER WorktreeRoot
Optional path to the current worktree root. Defaults to the git toplevel of the current
working directory. Forwarded to each builder.

.PARAMETER WorkspacePath
Optional explicit path to the sprint Overview code-workspace file. Forwarded to each builder.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns a result object with Success, WorkspacePath, a Builders object holding the three
individual result objects (Claude, Agents, AgentSpecific), and an aggregated Errors array.

.EXAMPLE
Build-AIInstructionsPerRepository

Runs all three per-repo builders for the discovered sprint workspace, in canonical order.

.EXAMPLE
Build-AIInstructionsPerRepository -WorktreeRoot $shared -WorkspacePath $wsPath -WhatIf

Previews every per-repo write across all three builders without changing any file.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
#>

function Build-AIInstructionsPerRepository {
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $false, Position = 0,
      HelpMessage = 'Path to the current worktree root')]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false, Position = 1,
      HelpMessage = 'Path to the sprint Overview code-workspace file')]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspacePath
  )

  begin {
    $fn = 'Build-AIInstructionsPerRepository'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load the sibling builders co-located with this orchestrator and ALWAYS prefer that
    # copy. Dot-sourcing $PSScriptRoot/<builder>.ps1 binds the orchestrator to the builders
    # that ship with it: the sprint-worktree source when run from source, or the installed
    # copy when run from an installed module. Gating on Get-Command instead would let module
    # auto-loading resolve a STALE installed builder (e.g. a pre-Task-10.23 Build-AGENTSPerRepository
    # that still reads AGENTS.md instead of AGENTS-base.md), so we do not gate.
    $builderOrder = @(
      'Build-CLAUDEPerRepository'
      'Build-AGENTSPerRepository'
      'Build-AgentSpecificPerRepository'
    )
    foreach ($builder in $builderOrder) {
      $builderPath = Join-Path $PSScriptRoot "$builder.ps1"
      if (Test-Path -LiteralPath $builderPath -PathType Leaf) {
        . $builderPath
      } elseif (-not (Get-Command -Name $builder -ErrorAction SilentlyContinue)) {
        $errorMessage = "Required builder '$builder' is not available and was not found at '$builderPath'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }
    }

    # Forward only the parameters the caller actually supplied.
    $forward = @{}
    if ($PSBoundParameters.ContainsKey('WorktreeRoot') -and -not [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
      $forward['WorktreeRoot'] = $WorktreeRoot
    }
    if ($PSBoundParameters.ContainsKey('WorkspacePath') -and -not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
      $forward['WorkspacePath'] = $WorkspacePath
    }

    $result = [PSCustomObject]@{
      Success       = $false
      WorkspacePath = $null
      Builders      = [PSCustomObject]@{
        Claude        = $null
        Agents        = $null
        AgentSpecific = $null
      }
      Errors        = @()
    }
  }

  process {
    # Builder name -> the Builders result property it populates. Run in canonical order; a
    # failure in one is recorded but does not stop the others ($WhatIfPreference and other
    # preference variables propagate automatically into the called advanced functions).
    $steps = @(
      [PSCustomObject]@{ Name = 'Build-CLAUDEPerRepository'; Property = 'Claude' }
      [PSCustomObject]@{ Name = 'Build-AGENTSPerRepository'; Property = 'Agents' }
      [PSCustomObject]@{ Name = 'Build-AgentSpecificPerRepository'; Property = 'AgentSpecific' }
    )

    foreach ($step in $steps) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Running $($step.Name)"
      try {
        $builderResult = & $step.Name @forward
        $result.Builders.$($step.Property) = $builderResult

        if ($null -eq $result.WorkspacePath -and $builderResult.PSObject.Properties['WorkspacePath']) {
          $result.WorkspacePath = $builderResult.WorkspacePath
        }
        if ($builderResult.PSObject.Properties['Errors']) {
          foreach ($builderError in @($builderResult.Errors)) {
            $result.Errors += $builderError
          }
        }
        if ($builderResult.PSObject.Properties['Success'] -and -not $builderResult.Success) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "$($step.Name) reported Success=false."
        }
      } catch {
        $errorMessage = "$($step.Name) failed: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        $result.Errors += $errorMessage
      }
    }

    $result.Success = ($result.Errors.Count -eq 0)
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    $result
  }
}
