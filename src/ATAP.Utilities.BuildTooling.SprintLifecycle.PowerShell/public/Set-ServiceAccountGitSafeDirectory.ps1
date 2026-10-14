function Set-ServiceAccountGitSafeDirectory {
  <#
  .SYNOPSIS
    Adds or removes exact sprint worktree trust entries in a service account Git configuration.
  .DESCRIPTION
    Implements SC-0321 for sprint boundaries. Only worktrees whose leaf names match
    one of RepositoryNames and the standard sprint-worktree suffix are selected.
    Start adds missing exact safe.directory values idempotently. End removes only
    exact selected values by using git config --fixed-value. Unrelated and stable
    trust entries are preserved.
  .PARAMETER Boundary
    Start adds selected entries; End removes selected entries.
  .PARAMETER WorktreePaths
    Exact sprint worktree paths considered for service-account trust.
  .PARAMETER GitConfigPath
    Explicit service-account Git configuration file. Defaults to SvcBuildmaster.
  .PARAMETER RepositoryNames
    Repository names eligible for lifecycle trust. Defaults to Ace and ATAP.Utilities.
  .PARAMETER GitExecutable
    Git executable used to read and update the explicit configuration file.
  .OUTPUTS
    PSCustomObject describing selected, added, removed, unchanged, before, and after values.
  .EXAMPLE
    Set-ServiceAccountGitSafeDirectory -Boundary Start `
      -WorktreePaths $worktreePaths `
      -GitConfigPath 'C:\Users\SvcBuildmaster\.gitconfig' -Confirm:$false
  .NOTES
    SC-0321. AI assisted using Powershell.instructions.md as guidelines.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('Start', 'End')]
    [string]$Boundary,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]]$WorktreePaths,

    [ValidateNotNullOrEmpty()]
    [string]$GitConfigPath = 'C:\Users\SvcBuildmaster\.gitconfig',

    [ValidateNotNullOrEmpty()]
    [string[]]$RepositoryNames = @('Ace', 'ATAP.Utilities'),

    [ValidateNotNullOrEmpty()]
    [string]$GitExecutable = 'git'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn (Boundary=$Boundary)"

    function ConvertTo-GitSafeDirectoryValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
      )

      return ([IO.Path]::GetFullPath($Path)).TrimEnd('\', '/').Replace('\', '/')
    }

    function Get-ExplicitGitSafeDirectoryValues {
      [CmdletBinding()]
      param()

      $gitOutput = @(& $GitExecutable config --file $GitConfigPath --get-all safe.directory 2>&1)
      $gitExitCode = $LASTEXITCODE
      if ($gitExitCode -eq 1) {
        return @()
      }
      if ($gitExitCode -ne 0) {
        throw "git config could not read safe.directory from '$GitConfigPath' (exit $gitExitCode): $($gitOutput -join '; ')"
      }
      return @($gitOutput | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $selectedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($worktreePath in @($WorktreePaths)) {
      if ([string]::IsNullOrWhiteSpace($worktreePath)) {
        continue
      }

      $leaf = Split-Path -Path $worktreePath -Leaf
      $matchedRepository = $null
      foreach ($repositoryName in $RepositoryNames) {
        $expectedPrefix = "$repositoryName-wt-"
        if ($leaf.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) -and
          $leaf.Substring($expectedPrefix.Length) -match '^\d+-Sprint-\d+-work-items$') {
          $matchedRepository = $repositoryName
          break
        }
      }

      if ($null -ne $matchedRepository) {
        $normalizedPath = ConvertTo-GitSafeDirectoryValue -Path $worktreePath
        if (-not ($selectedPaths | Where-Object { [StringComparer]::OrdinalIgnoreCase.Equals($_, $normalizedPath) })) {
          [void]$selectedPaths.Add($normalizedPath)
        }
      }
    }
  }

  process {
    $before = @(Get-ExplicitGitSafeDirectoryValues)
    $projected = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $before) {
      [void]$projected.Add($entry)
    }

    $added = [System.Collections.Generic.List[string]]::new()
    $removed = [System.Collections.Generic.List[string]]::new()
    $unchanged = [System.Collections.Generic.List[string]]::new()

    foreach ($selectedPath in $selectedPaths) {
      $matchingEntries = @($projected | Where-Object {
          [StringComparer]::OrdinalIgnoreCase.Equals((ConvertTo-GitSafeDirectoryValue -Path $_), $selectedPath)
        })

      if ($Boundary -eq 'Start') {
        if ($matchingEntries.Count -gt 0) {
          [void]$unchanged.Add($selectedPath)
          continue
        }

        if ($PSCmdlet.ShouldProcess($GitConfigPath, "Add exact safe.directory '$selectedPath'")) {
          $gitOutput = @(& $GitExecutable config --file $GitConfigPath --add safe.directory $selectedPath 2>&1)
          $gitExitCode = $LASTEXITCODE
          if ($gitExitCode -ne 0) {
            throw "git config could not add safe.directory '$selectedPath' to '$GitConfigPath' (exit $gitExitCode): $($gitOutput -join '; ')"
          }
        }
        [void]$projected.Add($selectedPath)
        [void]$added.Add($selectedPath)
      } else {
        if ($matchingEntries.Count -eq 0) {
          [void]$unchanged.Add($selectedPath)
          continue
        }

        if ($PSCmdlet.ShouldProcess($GitConfigPath, "Remove exact safe.directory '$selectedPath'")) {
          $gitOutput = @(& $GitExecutable config --file $GitConfigPath --unset-all --fixed-value safe.directory $selectedPath 2>&1)
          $gitExitCode = $LASTEXITCODE
          if ($gitExitCode -ne 0) {
            throw "git config could not remove safe.directory '$selectedPath' from '$GitConfigPath' (exit $gitExitCode): $($gitOutput -join '; ')"
          }
        }
        for ($index = $projected.Count - 1; $index -ge 0; $index--) {
          if ([StringComparer]::OrdinalIgnoreCase.Equals((ConvertTo-GitSafeDirectoryValue -Path $projected[$index]), $selectedPath)) {
            $projected.RemoveAt($index)
          }
        }
        [void]$removed.Add($selectedPath)
      }
    }

    $after = if ($WhatIfPreference) { @($projected) } else { @(Get-ExplicitGitSafeDirectoryValues) }
    foreach ($selectedPath in $selectedPaths) {
      $presentAfter = @($after | Where-Object {
          [StringComparer]::OrdinalIgnoreCase.Equals((ConvertTo-GitSafeDirectoryValue -Path $_), $selectedPath)
        }).Count -gt 0
      if (($Boundary -eq 'Start' -and -not $presentAfter) -or ($Boundary -eq 'End' -and $presentAfter)) {
        throw "Postcondition failed for '$selectedPath' at boundary '$Boundary' in '$GitConfigPath'."
      }
    }

    [PSCustomObject]@{
      Boundary       = $Boundary
      GitConfigPath  = $GitConfigPath
      SelectedPaths  = $selectedPaths.ToArray()
      Added          = $added.ToArray()
      Removed        = $removed.ToArray()
      Unchanged      = $unchanged.ToArray()
      Before         = $before
      After          = $after
      DryRun         = [bool]$WhatIfPreference
      Success        = $true
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}