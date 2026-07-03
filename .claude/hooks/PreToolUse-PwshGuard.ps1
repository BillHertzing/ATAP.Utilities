# PreToolUse-PwshGuard.ps1
#
# PreToolUse hook guard for the Bash and PowerShell tools (Task 8.16, SC-prop-0007-1/-2).
# Data-driven policy loader (Task 11.18.e): the deny/ask rules live in the canonical policy
# file .ai/policy/command-guard.json. The guard loads that file and walks its rules to emit
# the permissionDecision, so deny/ask behavior changes by editing the JSON - not this script.
# The two original hardcoded checks are the seed rules:
#   1. Any pwsh/powershell invocation that passes -NoProfile (or an abbreviation such as
#      -nop). The ATAP AllUsersAllHosts profile builds $global:settings; BuildTooling
#      reads configuration via Get-PVal, which now fails loudly without it.
#   2. Raw Verb-Noun PowerShell commands sent to the Bash tool (Git Bash / POSIX sh),
#      where cmdlets fail with "command not found" (rule R-01).
# Task 11.18.h characterization keeps Check 2 scoped to Bash: under Claude Code's
# PowerShell tool, raw Verb-Noun commands are native PowerShell and should not be blocked.
#
# Protocol: receives the tool-call JSON on stdin; to deny/ask, emits a PreToolUse
# permissionDecision JSON on stdout and exits 0; to allow, emits nothing and exits 0.
# Fails open on any internal error so a guard bug can never break legitimate tool calls.
# Policy-file load is robust: a missing or corrupt policy file falls back to the in-code
# seed rules (Get-CommandGuardSeedPolicy) so the guard is never silently wide-open.
#
# Canonical source (Task 10.20.q): this body is the single source of truth under
# .ai/hooks/pretooluse-pwshguard/hook.ps1 and is materialized to each caller's hook
# location by Render-AIAdapters -Domain hooks. Edit here, never the rendered copy.
#
# NOTE - documented exception to the -NoProfile ban (Task 11.18.d): the canonical hook
# registration in .ai/config/claudecode/settings.overlay.json invokes this script WITH
# -NoProfile via the parameterized command:
#   pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${SPRINT_WORKTREE_PATH_SHAREDVSCODE}\.claude\hooks\PreToolUse-PwshGuard.ps1"
# -NoProfile is correct HERE, and only here: the guard reads only stdin, never touches
# $global:settings, must start in milliseconds (it runs on every Bash/PowerShell tool call),
# and must keep stdout free of profile noise so the JSON decision parses. The ATAP -NoProfile
# ban enforced by the no-profile-ban seed rule governs ATAP work, not this guard's invocation.

[CmdletBinding()]
param()

function Write-GuardDecision {
  param(
    [Parameter(Mandatory)][ValidateSet('deny', 'ask')][string]$Decision,
    [Parameter(Mandatory)][string]$Reason
  )
  $response = @{
    hookSpecificOutput = @{
      hookEventName            = 'PreToolUse'
      permissionDecision       = $Decision
      permissionDecisionReason = $Reason
    }
  }
  [Console]::Out.Write(($response | ConvertTo-Json -Depth 5 -Compress))
  exit 0
}

function Get-CommandGuardSeedPolicy {
  # In-code fallback policy used when the canonical policy file is missing or corrupt.
  # Mirror these seed rules in .ai/policy/command-guard.json; the JSON is the primary
  # source of truth and this fallback guarantees the guard is never wide-open.
  return [pscustomobject]@{
    deny = @(
      [pscustomobject]@{
        id            = 'no-profile-ban'
        appliesToTool = '*'
        match         = 'pwsh-noprofile'
        reason        = 'BLOCKED: -NoProfile is banned for ATAP work (SC-prop-0007-1, Task 8.16). The AllUsersAllHosts profile builds $global:settings; BuildTooling reads configuration via Get-PVal and fails loudly without it. Remediation: re-run the same command WITHOUT -NoProfile so profiles load, e.g. pwsh -Command "<command>". If you genuinely need to prove a module loads in a bare engine, ask the user first.'
      },
      [pscustomobject]@{
        id            = 'verb-noun-to-bash'
        appliesToTool = 'Bash'
        match         = 'powershell-verb-noun-first-token'
        reason        = "BLOCKED: '{0}' looks like a raw PowerShell Verb-Noun command sent to the Bash tool (SC-prop-0007-2, Task 8.16, rule R-01). The Bash tool runs Git Bash / POSIX sh, so PowerShell cmdlets fail there with 'command not found'. Remediation: use the PowerShell tool instead, or wrap the command: pwsh -Command `"{0} ...`" (escape PowerShell `$ as \`$ when calling from bash - rule R-16). Never add -NoProfile."
      }
    )
    ask = @()
  }
}

function Get-CommandGuardPolicy {
  param([string[]]$CandidatePath)
  foreach ($candidate in $CandidatePath) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    try {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $obj = Get-Content -LiteralPath $candidate -Raw -ErrorAction Stop |
          ConvertFrom-Json -ErrorAction Stop
        $names = @($obj.PSObject.Properties.Name)
        if ($null -ne $obj -and ($names -contains 'deny' -or $names -contains 'ask')) {
          return $obj
        }
      }
    }
    catch {
      # Corrupt or unreadable policy file: skip it and fall through to the seed policy.
    }
  }
  return $null
}

function Test-CommandGuardRule {
  # Returns a hashtable @{ Token = <matched token> } on a match, otherwise $null.
  param(
    [Parameter(Mandatory)]$Rule,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Command,
    [Parameter(Mandatory)][AllowEmptyString()][string]$ToolName
  )

  # A bare string rule is shorthand for a regex pattern.
  if ($Rule -is [string]) {
    $Rule = [pscustomobject]@{ pattern = $Rule; reason = "BLOCKED by command-guard policy: matched /$Rule/." }
  }

  $ruleNames = @($Rule.PSObject.Properties.Name)
  $appliesTo = if ($ruleNames -contains 'appliesToTool') { [string]$Rule.appliesToTool } else { '*' }
  if (
    $appliesTo -ne '*' -and
    -not [string]::Equals($appliesTo, $ToolName, [StringComparison]::OrdinalIgnoreCase)
  ) {
    return $null
  }

  $match = if ($ruleNames -contains 'match') { [string]$Rule.match } else { $null }
  switch ($match) {
    'pwsh-noprofile' {
      # Both a pwsh/powershell reference AND a -NoProfile (or abbreviation) must be present,
      # so option flags of non-PowerShell tools do not false-positive.
      $referencesPwsh = $Command -match '(?i)(^|[\s"''=(;&|`/\\])(pwsh|powershell)(\.exe)?($|[\s"''])'
      $hasNoProfileSwitch = $Command -match '(?i)(^|[\s"''=(])-nop\w*'
      if ($referencesPwsh -and $hasNoProfileSwitch) { return @{ Token = '' } }
      return $null
    }
    'powershell-verb-noun-first-token' {
      $firstToken = ($Command.TrimStart() -split '[\s(]', 2)[0]
      if ($firstToken -match '^([A-Za-z]+)-([A-Za-z][A-Za-z0-9]*)$') {
        $verb = $Matches[1]
        # Get-Verb covers approved verbs; the supplement covers common unapproved-verb cmdlets.
        $isPsVerb = [bool](Get-Verb -Verb $verb -ErrorAction SilentlyContinue) -or
          ($verb -in @('Sort', 'Tee', 'ForEach', 'Where'))
        if ($isPsVerb) { return @{ Token = $firstToken } }
      }
      return $null
    }
    default {
      # Generic regex pattern matcher (the mechanism new policy rules use).
      $pattern = if ($ruleNames -contains 'pattern') { [string]$Rule.pattern } else { $null }
      if (-not [string]::IsNullOrEmpty($pattern) -and $Command -match $pattern) {
        return @{ Token = [string]$Matches[0] }
      }
      return $null
    }
  }
}

try {
  $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop
  $toolName = [string]$payload.tool_name
  $command = [string]$payload.tool_input.command
  if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

  # Resolve the canonical policy file relative to this script. The rendered hook lives at
  # <worktree>/.claude/hooks/; the canonical body lives at .ai/hooks/pretooluse-pwshguard/.
  $candidatePaths = @(
    (Join-Path $PSScriptRoot 'command-guard.json')
    (Join-Path $PSScriptRoot '../../.ai/policy/command-guard.json')
    (Join-Path $PSScriptRoot '../../policy/command-guard.json')
  )
  $policy = Get-CommandGuardPolicy -CandidatePath $candidatePaths
  if ($null -eq $policy) { $policy = Get-CommandGuardSeedPolicy }

  foreach ($bucket in @('deny', 'ask')) {
    if (@($policy.PSObject.Properties.Name) -notcontains $bucket) { continue }
    foreach ($rule in @($policy.$bucket)) {
      $hit = Test-CommandGuardRule -Rule $rule -Command $command -ToolName $toolName
      if ($null -ne $hit) {
        $reason = if ($rule -is [string]) {
          "BLOCKED by command-guard policy: matched /$rule/."
        }
        else {
          [string]$rule.reason
        }
        $reason = $reason.Replace('{0}', [string]$hit.Token)
        Write-GuardDecision -Decision $bucket -Reason $reason
      }
    }
  }

  exit 0
}
catch {
  # Fail open: a guard bug must never block legitimate tool calls.
  exit 0
}
