function Invoke-GitCommit {
    <#
.SYNOPSIS
    Stages and commits git changes using Conventional Commits format.

.DESCRIPTION
    Consolidates all steps of the /git-commit skill into a single script
    invocation so that only one terminal-approval prompt is required.

    Steps performed:
      1. Gather context  (status, diff, log, branch)
      2. Detect and block sensitive files (.env, *.secret, *.key)
      3. Stage all relevant changes (git add -A, minus blocked paths)
      4. Prompt the caller for a Conventional Commits message
      5. Commit with the supplied message
      6. Print the resulting commit hash

.PARAMETER Message
    Conventional Commits message.  When supplied the interactive prompt is
    skipped.  Format: "<type>(<scope>): <summary>" with an optional body
    separated by a blank line.

.PARAMETER RepoPath
    Path to the git working tree.  Defaults to the current directory.

.PARAMETER SkipLockFileGuard
    Explicitly bypasses Assert-LockFilesClean. Use only when the caller has
    separately reviewed packages.lock.json drift and recorded the reason.

.OUTPUTS
    [void]  Writes confirmation lines to the host.

.EXAMPLE
    Invoke-GitCommit
    # Interactive: prints context then prompts for the commit message.

.EXAMPLE
    Invoke-GitCommit -Message "feat(auth): add OAuth2 token refresh"
    # Non-interactive: stages and commits with the supplied message.

.NOTES
    AI assisted using Powershell.instructions.md as guidelines
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Message = '',

        [Parameter(Mandatory = $false)]
        [string] $RepoPath = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [switch] $SkipLockFileGuard
    )

    begin {
        $fn = $MyInvocation.MyCommand.Name
        $mn = $MyInvocation.MyCommand.ModuleName
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

        # Load helper functions
        $helpfunctionsneeded = @(
            @{FunctionName = 'Assert-LockFilesClean'; ModuleName = 'ATAP.Utilities.BuildTooling.PowerShell'}
        )
        $repoRootParentPath = 'C:\Dropbox\whertzing\GitHub'
        $stablePath = 'ATAP.Utilities.BuildTooling.PowerShell'
        $wtFolder = $PWD.Path.Split([IO.Path]::DirectorySeparatorChar) |
            Where-Object { $_ -like '*-wt-*' } |
            Select-Object -First 1
        $resolvedModulePath = $wtFolder ? $(Join-Path $repoRootParentPath $wtFolder 'src') : $(Join-Path $repoRootParentPath $stablePath 'src')
        foreach ($helpfunction in $helpfunctionsneeded) {
            try {
                if (-not (Test-Path -LiteralPath "Function:\$($helpfunction.FunctionName)")) {
                    . (Join-Path $resolvedModulePath $($helpfunction.ModuleName) 'public' "$($helpfunction.FunctionName).ps1")
                }
            } catch {
                $errorMessage = "Failed to load $($helpfunction.FunctionName) function from module path $(Join-Path $resolvedModulePath $($helpfunction.ModuleName) 'public' "$($helpfunction.FunctionName).ps1"). Exception: $($_.Exception.Message)"
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
                throw
            }
        }

        $blocked = @('.env', '*.secret', '*.key', 'node_modules', 'bin', 'obj')
    }

    process {
        try {
            Push-Location $RepoPath

            # ── Step 1: Gather context ────────────────────────────────────────────
            $status = & git status 2>&1
            $diffHead = & git diff HEAD 2>&1
            $log = & git log --oneline -5 2>&1
            $branch = & git branch --show-current 2>&1

            Write-Host ''
            Write-Host '=== git status ===' -ForegroundColor Cyan
            $status | Write-Host
            Write-Host ''
            Write-Host '=== git log (last 5) ===' -ForegroundColor Cyan
            $log | Write-Host
            Write-Host ''
            Write-Host "Current branch: $branch" -ForegroundColor Cyan
            Write-Host ''

            if ($diffHead) {
                Write-Host '=== git diff HEAD (summary) ===' -ForegroundColor Cyan
                ($diffHead | Where-Object { $_ -match '^(diff --git|---|\+\+\+|@@)' }) | Write-Host
                Write-Host ''
            }

            # ── Step 2: Detect sensitive files ────────────────────────────────────
            $trackedChanges = & git diff --name-only HEAD 2>&1
            $untrackedNew = & git ls-files --others --exclude-standard 2>&1
            $allCandidates = @($trackedChanges) + @($untrackedNew) | Where-Object { $_ }

            $sensitiveFound = $allCandidates | Where-Object {
                $name = [System.IO.Path]::GetFileName($_)
                $name -eq '.env' -or
                $name -like '*.secret' -or
                $name -like '*.key' -or
                $_ -match '(^|[\\/])node_modules([\\/]|$)' -or
                $_ -match '(^|[\\/])bin([\\/]|$)' -or
                $_ -match '(^|[\\/])obj([\\/]|$)'
            }

            if ($sensitiveFound) {
                Write-Host 'BLOCKED — sensitive files detected. Review before committing:' -ForegroundColor Red
                $sensitiveFound | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
                throw "Commit blocked: sensitive or generated files detected. Remove them from staging or add to .gitignore."
            }

            if (-not $SkipLockFileGuard) {
                Assert-LockFilesClean -RepoPath $RepoPath -ThrowOnFailure | Out-Null
            } else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message 'Skipping Assert-LockFilesClean by explicit caller request.'
            }

            # ── Step 3: Stage all changes ─────────────────────────────────────────
            if ($PSCmdlet.ShouldProcess($RepoPath, 'git add -A')) {
                & git add -A 2>&1 | Out-Null
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Staged all changes (git add -A)'
            }

            # ── Step 4: Collect commit message ────────────────────────────────────
            if (-not $Message) {
                Write-Host 'Enter Conventional Commits message.' -ForegroundColor Yellow
                Write-Host '  Format: <type>(<scope>): <summary>' -ForegroundColor Yellow
                Write-Host '  Types: feat fix refactor docs test chore style perf ci' -ForegroundColor Yellow
                Write-Host '  Press ENTER twice to finish (first ENTER ends body, second commits):' -ForegroundColor Yellow
                Write-Host ''

                $lines = [System.Collections.Generic.List[string]]::new()
                $emptyCount = 0
                while ($emptyCount -lt 1) {
                    $line = Read-Host
                    if ($line -eq '') {
                        $emptyCount++
                    } else {
                        $emptyCount = 0
                        $lines.Add($line)
                    }
                }
                $Message = $lines -join "`n"
            }

            if (-not $Message) {
                throw 'Commit message cannot be empty.'
            }

            $firstLine = ($Message -split "`n")[0]
            if ($firstLine.Length -gt 72) {
                Write-Host "Warning: summary line is $($firstLine.Length) chars (max 72)." -ForegroundColor Yellow
            }

            # ── Step 5: Commit ────────────────────────────────────────────────────
            if ($PSCmdlet.ShouldProcess($RepoPath, "git commit -m '$firstLine'")) {
                & git commit -m $Message 2>&1 | Write-Host
                if ($LASTEXITCODE -ne 0) {
                    throw "git commit exited with code $LASTEXITCODE"
                }
            }

            # ── Step 6: Confirm ───────────────────────────────────────────────────
            $result = & git log --oneline -1 2>&1
            Write-Host ''
            Write-Host "Committed: $result" -ForegroundColor Green

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
