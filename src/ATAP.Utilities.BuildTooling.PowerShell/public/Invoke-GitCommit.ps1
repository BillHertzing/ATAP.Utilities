function Invoke-GitCommit {
  <#
.SYNOPSIS
    Stages and commits git changes using Conventional Commits format.

.DESCRIPTION
    Consolidates the /git-commit workflow into a callable function that can
    gather context, block sensitive files, run the lock-file guard, stage paths,
    and create commits.

    A cohesive working tree still follows the single-commit path. When multiple
    path scopes are dirty, the function refuses to collapse them into one
    non-interactive message unless -ForceSingleCommit is supplied. Agents can
    pass -Groups to create task-scoped commits without prompts; each group stages
    only its matched paths and receives its own Conventional Commit message.

.PARAMETER Message
    Conventional Commits message for the single-commit path. When supplied the
    interactive prompt is skipped. Format: "<type>(<scope>): <summary>" with an
    optional body separated by a blank line.

.PARAMETER Groups
    Optional task/scope commit plan. Accepts hashtable mappings of path glob to
    message, or group objects/hashtables with Paths and Message properties. Each
    group is committed separately in the order supplied.

.PARAMETER RepoPath
    Path to the git working tree. Defaults to the current directory.

.PARAMETER SkipLockFileGuard
    Explicitly bypasses Assert-LockFilesClean. Use only when the caller has
    separately reviewed packages.lock.json drift and recorded the reason.

.PARAMETER ForceSingleCommit
    Allows a single supplied -Message to commit a working tree that spans more
    than one detected path scope.

.PARAMETER CoAuthorFooter
    Co-authorship footer appended to every commit message when no Co-Authored-By
    footer is already present.

.OUTPUTS
    [void] Writes confirmation lines to the information stream.

.EXAMPLE
    Invoke-GitCommit
    # Interactive: prints context, detects scopes, and prompts for messages.

.EXAMPLE
    Invoke-GitCommit -Message "feat(auth): add OAuth2 token refresh"
    # Non-interactive: creates one commit when the dirty tree is cohesive.

.EXAMPLE
    Invoke-GitCommit -Groups @(
      @{ Paths = @('src/App/**'); Message = 'feat(app): update app flow' },
      @{ Paths = @('docs/**'); Message = 'docs(runbook): update app notes' }
    )
    # Non-interactive: creates one commit per supplied group.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([void])]
  param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string] $Message = '',

    [Parameter(Mandatory = $false)]
    [object[]] $Groups = @(),

    [Parameter(Mandatory = $false)]
    [string] $RepoPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch] $SkipLockFileGuard,

    [Parameter(Mandatory = $false)]
    [switch] $ForceSingleCommit,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $CoAuthorFooter = 'Co-Authored-By: AI Commit Agent <ai-commit-agent@users.noreply.github.com>'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

    function ConvertTo-GitCommitRelativePath {
      param(
        [Parameter(Mandatory)]
        [string] $Path
      )

      $normalized = ($Path -replace '\\', '/').Trim()
      while ($normalized.StartsWith('./', [System.StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
      }
      return $normalized.TrimStart([char[]]@('/'))
    }

    function Test-GitCommitPathPattern {
      param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Pattern
      )

      $relativePath = ConvertTo-GitCommitRelativePath -Path $Path
      $relativePattern = ConvertTo-GitCommitRelativePath -Path $Pattern
      if ([string]::IsNullOrWhiteSpace($relativePattern)) {
        return $false
      }

      if ($relativePattern -notmatch '[*?\[]') {
        return ($relativePath -eq $relativePattern -or $relativePath.StartsWith("$relativePattern/", [System.StringComparison]::OrdinalIgnoreCase))
      }

      return ($relativePath -like $relativePattern)
    }

    function Get-GitCommitChangedPath {
      $trackedChanges = @(& git diff --name-only HEAD -- 2>&1)
      if ($LASTEXITCODE -ne 0) {
        throw "git diff failed while gathering changed paths. $($trackedChanges -join [Environment]::NewLine)"
      }

      $untrackedChanges = @(& git ls-files --others --exclude-standard 2>&1)
      if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed while gathering untracked paths. $($untrackedChanges -join [Environment]::NewLine)"
      }

      $all = @($trackedChanges) + @($untrackedChanges) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { ConvertTo-GitCommitRelativePath -Path ([string]$_) } |
        Sort-Object -Unique

      return @($all)
    }

    function Get-GitCommitScopeName {
      param(
        [Parameter(Mandatory)]
        [string] $Path
      )

      $relative = ConvertTo-GitCommitRelativePath -Path $Path
      $segments = @($relative -split '/' | Where-Object { $_ })
      if ($segments.Count -eq 0) {
        return '.'
      }

      if ($segments[0] -eq 'src' -and $segments.Count -gt 1) {
        return "src/$($segments[1])"
      }

      if ($segments[0] -in @('.ai', '.agents', '.claude', '.codex', '.gemini', '.github') -and $segments.Count -gt 1) {
        return "$($segments[0])/$($segments[1])"
      }

      return $segments[0]
    }

    function Get-GitCommitDictionaryValue {
      param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Dictionary,

        [Parameter(Mandatory)]
        [string[]] $Names
      )

      foreach ($key in $Dictionary.Keys) {
        foreach ($name in $Names) {
          if ([string]::Equals([string]$key, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $Dictionary[$key]
          }
        }
      }

      return $null
    }

    function ConvertTo-GitCommitGroupSpec {
      param(
        [Parameter(Mandatory)]
        [object[]] $InputGroups
      )

      $specs = [System.Collections.Generic.List[object]]::new()
      foreach ($group in $InputGroups) {
        if ($null -eq $group) {
          continue
        }

        if ($group -is [System.Collections.IDictionary]) {
          $pathsValue = Get-GitCommitDictionaryValue -Dictionary $group -Names @('Paths', 'Path', 'Patterns', 'Pattern')
          $messageValue = Get-GitCommitDictionaryValue -Dictionary $group -Names @('Message')
          $nameValue = Get-GitCommitDictionaryValue -Dictionary $group -Names @('Name')

          if ($null -ne $pathsValue -or $null -ne $messageValue) {
            $paths = @($pathsValue) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }
            [void]$specs.Add([PSCustomObject]@{
              Name = if ($nameValue) { [string]$nameValue } else { ($paths -join ', ') }
              Patterns = @($paths)
              Message = if ($messageValue) { [string]$messageValue } else { '' }
            })
            continue
          }

          foreach ($key in $group.Keys) {
            [void]$specs.Add([PSCustomObject]@{
              Name = [string]$key
              Patterns = @([string]$key)
              Message = [string]$group[$key]
            })
          }
          continue
        }

        $properties = $group.PSObject.Properties
        $pathsProperty = @('Paths', 'Path', 'Patterns', 'Pattern') | ForEach-Object { $properties[$_] } | Where-Object { $null -ne $_ } | Select-Object -First 1
        $messageProperty = $properties['Message']
        $nameProperty = $properties['Name']
        $paths = @($pathsProperty.Value) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }

        [void]$specs.Add([PSCustomObject]@{
          Name = if ($nameProperty) { [string]$nameProperty.Value } else { ($paths -join ', ') }
          Patterns = @($paths)
          Message = if ($messageProperty) { [string]$messageProperty.Value } else { '' }
        })
      }

      return @($specs)
    }

    function Resolve-GitCommitExplicitGroupPlan {
      param(
        [Parameter(Mandatory)]
        [object[]] $InputGroups,

        [Parameter(Mandatory)]
        [string[]] $ChangedPaths
      )

      $specs = @(ConvertTo-GitCommitGroupSpec -InputGroups $InputGroups)
      if ($specs.Count -eq 0) {
        throw 'At least one commit group is required when -Groups is supplied.'
      }

      $assigned = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      $plans = [System.Collections.Generic.List[object]]::new()

      foreach ($spec in $specs) {
        if ($spec.Patterns.Count -eq 0) {
          throw "Commit group '$($spec.Name)' has no path patterns."
        }
        if ([string]::IsNullOrWhiteSpace($spec.Message)) {
          throw "Commit group '$($spec.Name)' must include a Conventional Commit message."
        }

        $matched = @($ChangedPaths | Where-Object {
          $path = $_
          @($spec.Patterns | Where-Object { Test-GitCommitPathPattern -Path $path -Pattern $_ }).Count -gt 0
        })

        if ($matched.Count -eq 0) {
          throw "Commit group '$($spec.Name)' did not match any changed paths."
        }

        foreach ($path in $matched) {
          if ($assigned.Contains($path)) {
            throw "Changed path '$path' matches more than one commit group."
          }
          [void]$assigned.Add($path)
        }

        [void]$plans.Add([PSCustomObject]@{
          Name = if ([string]::IsNullOrWhiteSpace($spec.Name)) { ($spec.Patterns -join ', ') } else { $spec.Name }
          Paths = @($matched)
          Message = [string]$spec.Message
        })
      }

      $unmatched = @($ChangedPaths | Where-Object { -not $assigned.Contains($_) })
      if ($unmatched.Count -gt 0) {
        Write-Information "Leaving $($unmatched.Count) changed path(s) unstaged because they are not in -Groups." -InformationAction Continue
      }

      return @($plans)
    }

    function Resolve-GitCommitAutomaticGroupPlan {
      param(
        [Parameter(Mandatory)]
        [string[]] $ChangedPaths
      )

      $plans = foreach ($group in ($ChangedPaths | Group-Object -Property { Get-GitCommitScopeName -Path $_ })) {
        [PSCustomObject]@{
          Name = [string]$group.Name
          Paths = @($group.Group | Sort-Object -Unique)
          Message = ''
        }
      }

      return @($plans | Sort-Object -Property Name)
    }

    function Assert-GitCommitNoSensitivePath {
      param(
        [Parameter(Mandatory)]
        [string[]] $CandidatePaths
      )

      $sensitiveFound = @($CandidatePaths | Where-Object {
        $name = [System.IO.Path]::GetFileName($_)
        $name -eq '.env' -or
        $name -like '*.secret' -or
        $name -like '*.key' -or
        $_ -match '(^|[\/])node_modules([\/]|$)' -or
        $_ -match '(^|[\/])bin([\/]|$)' -or
        $_ -match '(^|[\/])obj([\/]|$)'
      })

      if ($sensitiveFound.Count -gt 0) {
        $message = "Commit blocked: sensitive or generated files detected. $($sensitiveFound -join ', ')"
        throw $message
      }
    }

    function Add-GitCommitCoAuthorFooter {
      param(
        [Parameter(Mandatory)]
        [string] $CommitMessage,

        [Parameter(Mandatory)]
        [string] $Footer
      )

      if ($CommitMessage -match '(?im)^Co-Authored-By:') {
        return $CommitMessage
      }

      $trimmed = $CommitMessage.TrimEnd()
      return "$trimmed`n`n$Footer"
    }

    function Read-GitCommitMessage {
      param(
        [Parameter(Mandatory)]
        [string] $Prompt
      )

      Write-Information $Prompt -InformationAction Continue
      Write-Information '  Format: <type>(<scope>): <summary>' -InformationAction Continue
      Write-Information '  Types: feat fix refactor docs test chore style perf ci' -InformationAction Continue
      Write-Information '  Press ENTER on a blank line to finish.' -InformationAction Continue

      $lines = [System.Collections.Generic.List[string]]::new()
      while ($true) {
        $line = Read-Host
        if ($line -eq '') {
          break
        }
        $lines.Add($line)
      }

      return ($lines -join "`n")
    }

    function Assert-GitCommitMessage {
      param(
        [Parameter(Mandatory)]
        [string] $CommitMessage
      )

      if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        throw 'Commit message cannot be empty.'
      }

      $firstLine = ($CommitMessage -split "`r?`n")[0]
      if ($firstLine.Length -gt 72) {
        Write-Information "Warning: summary line is $($firstLine.Length) chars (max 72)." -InformationAction Continue
      }
    }

    function Invoke-GitCommitLockGuard {
      param(
        [Parameter(Mandatory)]
        [string] $Path
      )

      if (-not $SkipLockFileGuard) {
        Assert-LockFilesClean -RepoPath $Path -ThrowOnFailure | Out-Null
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Skipping Assert-LockFilesClean by explicit caller request.'
      }
    }

    function Invoke-GitCommitForPlan {
      param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Plan,

        [Parameter(Mandatory)]
        [string] $Path
      )

      $messageToUse = $Plan.Message
      if ([string]::IsNullOrWhiteSpace($messageToUse)) {
        $messageToUse = Read-GitCommitMessage -Prompt "Enter Conventional Commits message for group '$($Plan.Name)'."
      }
      Assert-GitCommitMessage -CommitMessage $messageToUse
      $messageToUse = Add-GitCommitCoAuthorFooter -CommitMessage $messageToUse -Footer $CoAuthorFooter

      Invoke-GitCommitLockGuard -Path $Path

      if ($PSCmdlet.ShouldProcess($Path, "stage and commit group '$($Plan.Name)'")) {
        & git reset --mixed --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
          throw "git reset failed before staging group '$($Plan.Name)'."
        }

        & git add -- @($Plan.Paths) 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
          throw "git add failed for group '$($Plan.Name)'."
        }

        & git diff --cached --quiet --exit-code 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
          throw "Commit group '$($Plan.Name)' has no staged changes after git add."
        }

        & git commit -m $messageToUse 2>&1 | ForEach-Object { Write-Information $_ -InformationAction Continue }
        if ($LASTEXITCODE -ne 0) {
          throw "git commit failed for group '$($Plan.Name)' with exit code $LASTEXITCODE."
        }

        $result = & git log --oneline -1 2>&1
        Write-Information "Committed group '$($Plan.Name)': $result" -InformationAction Continue
      }
    }
  }

  process {
    try {
      Push-Location $RepoPath

      $repoRoot = (& git rev-parse --show-toplevel 2>&1)
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "RepoPath '$RepoPath' is not inside a git worktree. $repoRoot"
      }
      $repoRoot = [string]$repoRoot.Trim()

      $status = & git status --short 2>&1
      $log = & git log --oneline -5 2>&1
      $branch = & git branch --show-current 2>&1
      $changedPaths = @(Get-GitCommitChangedPath)

      Write-Information '' -InformationAction Continue
      Write-Information '=== git status --short ===' -InformationAction Continue
      $status | ForEach-Object { Write-Information $_ -InformationAction Continue }
      Write-Information '' -InformationAction Continue
      Write-Information '=== git log (last 5) ===' -InformationAction Continue
      $log | ForEach-Object { Write-Information $_ -InformationAction Continue }
      Write-Information '' -InformationAction Continue
      Write-Information "Current branch: $branch" -InformationAction Continue
      Write-Information '' -InformationAction Continue

      if ($changedPaths.Count -eq 0) {
        throw 'No changed paths found to commit.'
      }

      Assert-GitCommitNoSensitivePath -CandidatePaths $changedPaths

      $hasExplicitGroups = ($Groups.Count -gt 0)
      if ($hasExplicitGroups) {
        $plans = @(Resolve-GitCommitExplicitGroupPlan -InputGroups $Groups -ChangedPaths $changedPaths)
      } else {
        $plans = @(Resolve-GitCommitAutomaticGroupPlan -ChangedPaths $changedPaths)
        if ($plans.Count -gt 1 -and -not $ForceSingleCommit) {
          if (-not [string]::IsNullOrWhiteSpace($Message)) {
            $scopeList = ($plans | ForEach-Object { $_.Name }) -join ', '
            throw "Working tree spans multiple change groups ($scopeList). Pass -Groups with one message per group, or pass -ForceSingleCommit to intentionally create one commit."
          }
        }

        if ($plans.Count -eq 1 -or $ForceSingleCommit) {
          $plans = @([PSCustomObject]@{
            Name = if ($plans.Count -eq 1) { $plans[0].Name } else { 'all changes' }
            Paths = @($changedPaths)
            Message = $Message
          })
        }
      }

      foreach ($plan in $plans) {
        Invoke-GitCommitForPlan -Plan $plan -Path $repoRoot
      }

      & git reset --mixed --quiet 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw 'git reset failed after commit completion.'
      }
    } catch {
      $errorMessage = "Invoke-GitCommit failed: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Pop-Location
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
