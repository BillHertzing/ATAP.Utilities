function Remove-SprintWorktreeSafely {
  <#
  .SYNOPSIS
  Removes an exact Git worktree with durable recovery and bounded residual cleanup.
  .DESCRIPTION
  Journals pre-removal registration, preserved HEAD, native attempts and individual
  residual effects outside the target. A successful deregistration is never retried.
  Recovery JSON is operator-reviewed evidence, not cryptographic authentication.
  .PARAMETER ReceiptPath
  Durable versioned JSON receipt outside WorktreePath. Defaults under the owning
  repository _generated/SprintWorktreeRemoval folder.
  .PARAMETER ApprovedJunctionTarget
  Map of canonical relative junction paths to exact expected absolute targets.
  Nested paths must be beneath an explicitly selected ResidualDirectoryRoot.
  .PARAMETER ResidualDirectoryRoot
  Direct child directory names permitting a zero-file ordinary/cloud directory tree.
  .PARAMETER OwningRepositoryPath
  Explicit complete set of repositories owning nested registrations in the subtree.
  .PARAMETER SelectedNestedWorktree
  Exact selected child plan objects: RepositoryPath, WorktreePath, Head,
  RecoveryReference and (for prunable slots) AdministrativePath. All nested
  registrations must be selected before parent Git removal can proceed.
  .PARAMETER LegacyRecoveryEvidencePath
  Reviewed SchemaVersion=1 JSON with RepositoryPath, WorktreePath, Head,
  RecoveryReference, BeforeSnapshotPath, FailedReceiptPath, InstalledModulePath,
  InstalledModuleSha256. Requires AcceptLegacy043Recovery and pinned .43 provenance.
  .PARAMETER AcceptLegacy043Recovery
  Explicit opt-in to reviewed legacy evidence import.
  .OUTPUTS
  PSCustomObject with Ok, Removed, Planned, Attempts, Failures and ReceiptPath.
  .EXAMPLE
  Remove-SprintWorktreeSafely -RepositoryPath C:\Repos\App -WorktreePath C:\Repos\App-wt-42 -Confirm:$false
  .NOTES
  Every filesystem removal is nonrecursive. No global Git pruning is performed.
  .LINK
  Get-SprintEndActiveWorkspaceRoot
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })][string]$RepositoryPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WorktreePath,
    [string[]]$AdapterPlaceholderPath = @(),
    [ValidateRange(1, 10)][int]$MaxAttempts = 3,
    [ValidateRange(0, 60000)][int]$RetryDelayMilliseconds = 500,
    [string]$HandoffPath, [switch]$ThrowOnFailure,
    [string]$ReceiptPath,
    [hashtable]$ApprovedJunctionTarget = @{},
    [string[]]$ResidualDirectoryRoot = @(),
    [string[]]$OwningRepositoryPath = @(),
    [object[]]$SelectedNestedWorktree = @(),
    [string]$LegacyRecoveryEvidencePath,
    [switch]$AcceptLegacy043Recovery
  )
  begin {
    $fn = 'Remove-SprintWorktreeSafely'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
    foreach ($helper in @('Get-SprintEndActiveWorkspaceRoot', 'Invoke-SprintEndNativeCommand', 'Get-SprintWorktreeRecoveryState', 'Remove-SprintWorktreeResidual', 'Remove-SprintWorktreeRecoveryMetadata')) {
      if (-not (Get-Command $helper -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot "..\private\$helper.ps1") }
    }
  }
  process {
    function Get-RemovalPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\', '/') }
    function Assert-RemovalPath([string]$Path) {
      $ancestor = $Path
      while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
          $entry = Get-Item -LiteralPath $ancestor -Force
          if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $tag = Invoke-SprintEndNativeCommand -FilePath fsutil.exe -ArgumentList @('reparsepoint', 'query', $ancestor) -AllowNonZeroExitCode
            if ($entry.LinkType -or -not $tag.Succeeded -or ($tag.Output -join "`n") -notmatch '(?im)^\s*Reparse Tag Value\s*:\s*0x9000[0-9a-f]01a\s*$') { throw "Unsafe removal path ancestor: $ancestor" }
          }
        }
        $ancestor = Split-Path $ancestor -Parent
      }
    }
    function Invoke-RemovalGit([string]$Owner, [string[]]$Arguments) {
      Invoke-SprintEndNativeCommand -FilePath git -ArgumentList (@('-C', $Owner) + $Arguments) -AllowNonZeroExitCode
    }
    $repositoryFull = Get-RemovalPath $RepositoryPath
    $worktreeFull = Get-RemovalPath $WorktreePath
    $prefix = $worktreeFull + [IO.Path]::DirectorySeparatorChar
    if ($repositoryFull -ieq $worktreeFull -or $repositoryFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Repository must be outside target worktree.' }
    $worktreeLeaf = Split-Path $worktreeFull -Leaf
    if (-not $ReceiptPath) { $ReceiptPath = Join-Path $repositoryFull "_generated\SprintWorktreeRemoval\$worktreeLeaf.json" }
    $receiptFull = [IO.Path]::GetFullPath($ReceiptPath)
    if (-not $HandoffPath) { $HandoffPath = [IO.Path]::ChangeExtension($receiptFull, '.handoff.md') }
    $handoffFull = [IO.Path]::GetFullPath($HandoffPath)
    foreach ($outputPath in @($receiptFull, $handoffFull)) {
      if ($outputPath -ieq $worktreeFull -or $outputPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'ReceiptPath and HandoffPath must be outside the worktree being removed.' }
      $ancestor = Split-Path $outputPath -Parent
      while ($ancestor) {
        if (-not (Test-Path -LiteralPath $ancestor)) { $ancestor = Split-Path $ancestor -Parent; continue }
        $ancestorItem = Get-Item -LiteralPath $ancestor -Force
        if ($ancestorItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
          $tag = Invoke-SprintEndNativeCommand -FilePath fsutil.exe -ArgumentList @('reparsepoint', 'query', $ancestor) -AllowNonZeroExitCode
          if ($ancestorItem.LinkType -or -not $tag.Succeeded -or ($tag.Output -join "`n") -notmatch '(?im)^\s*Reparse Tag Value\s*:\s*0x9000[0-9a-f]01a\s*$') { throw "Unsafe output ancestor: $ancestor" }
        }
        $ancestor = Split-Path $ancestor -Parent
      }
      Assert-RemovalPath $outputPath
    }
    $placeholderNames = @($AdapterPlaceholderPath | ForEach-Object {
      $candidate = if ([IO.Path]::IsPathRooted($_)) { Get-RemovalPath $_ } else { Get-RemovalPath (Join-Path $worktreeFull $_) }
      if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Adapter placeholder is outside the worktree: $candidate" }
      if ((Split-Path $candidate -Parent) -ine $worktreeFull) { throw 'Adapter placeholder must be a direct child.' }
      Split-Path $candidate -Leaf
    })
    foreach ($name in @($ResidualDirectoryRoot)) {
      if (-not $name -or $name -in @('.', '..') -or $name -match '[\\/:]' -or $name -in $placeholderNames) { throw 'Directory manifest must contain distinct direct child names.' }
    }
    $canonicalJunctions = @{}
    foreach ($key in @($ApprovedJunctionTarget.Keys)) {
      $relative = $key.Replace('\', '/')
      $segments = @($relative.Split('/'))
      if ([IO.Path]::IsPathRooted($key) -or $key -match ':' -or @($segments | Where-Object { $_ -in @('', '.', '..') }).Count -or $canonicalJunctions.ContainsKey($relative)) { throw 'Junction manifest must contain unique canonical relative paths without traversal.' }
      if (($segments.Count -eq 1 -and ($relative -in $ResidualDirectoryRoot -or $relative -in $placeholderNames)) -or ($segments.Count -gt 1 -and $segments[0] -notin $ResidualDirectoryRoot)) { throw 'Nested junction must be beneath an explicitly allowed directory root.' }
      if (-not [IO.Path]::IsPathRooted($ApprovedJunctionTarget[$key])) { throw 'Approved junction target must be absolute.' }
      $canonicalJunctions[$relative] = [IO.Path]::GetFullPath($ApprovedJunctionTarget[$key]).TrimEnd('\', '/')
    }
    $ApprovedJunctionTarget = $canonicalJunctions
    $retryParameters = @{
      RepositoryPath = $repositoryFull; WorktreePath = $worktreeFull; ReceiptPath = $receiptFull; HandoffPath = $handoffFull
      AdapterPlaceholderPath = @($AdapterPlaceholderPath); MaxAttempts = $MaxAttempts; RetryDelayMilliseconds = $RetryDelayMilliseconds
      ApprovedJunctionTarget = $ApprovedJunctionTarget; ResidualDirectoryRoot = @($ResidualDirectoryRoot)
      OwningRepositoryPath = @($OwningRepositoryPath); SelectedNestedWorktree = @($SelectedNestedWorktree)
    }
    if ($LegacyRecoveryEvidencePath) { $retryParameters.LegacyRecoveryEvidencePath = $LegacyRecoveryEvidencePath; $retryParameters.AcceptLegacy043Recovery = [bool]$AcceptLegacy043Recovery }
    $attempts = 0
    $removed = @()
    $failures = [Collections.Generic.List[string]]::new()
    $state = $null
    $activeRoots = @(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktreeFull)
    $planned = $false
    $complete = $false
    $receiptPresentAtEntry = Test-Path -LiteralPath $receiptFull -PathType Leaf
    $effectsStarted = $false
    $writeJson = {
      $directory = Split-Path $receiptFull -Parent
      [IO.Directory]::CreateDirectory($directory) | Out-Null
      $temporary = $receiptFull + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
      try {
        [IO.File]::WriteAllText($temporary, ($state | ConvertTo-Json -Depth 35), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $receiptFull, $true)
      } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    }
    $record = {
      param($Event, $Detail)
      $state.Events += @{ TimeUtc = [DateTime]::UtcNow.ToString('o'); Event = $Event; Detail = $Detail }
      & $writeJson
    }
    try {
      if ($activeRoots.Count) { throw "Active workspace references block removal: $($activeRoots.Source -join ', ')." }
      Assert-RemovalPath $worktreeFull
      $recovery = Get-SprintWorktreeRecoveryState -RepositoryPath $repositoryFull -WorktreePath $worktreeFull -ReceiptPath $receiptFull -LegacyRecoveryEvidencePath $LegacyRecoveryEvidencePath -AcceptLegacy043Recovery:$AcceptLegacy043Recovery
      $state = $recovery.State
      # Receipt permissions cannot be widened by a later caller.
      $sortedJunctions = [ordered]@{}
      foreach ($key in @($ApprovedJunctionTarget.Keys | Sort-Object)) { $sortedJunctions[$key] = $ApprovedJunctionTarget[$key] }
      $manifest = [ordered]@{ Placeholder = @($placeholderNames | Sort-Object); Junction = $sortedJunctions; Directory = @($ResidualDirectoryRoot | Sort-Object) }
      $manifestText = $manifest | ConvertTo-Json -Depth 8 -Compress
      if ($state.ContainsKey('Manifest') -and $state.Manifest -cne $manifestText) { throw 'Residual manifest changed since receipt.' }
      $owners = @($repositoryFull) + @($OwningRepositoryPath | ForEach-Object { Get-RemovalPath $_ }) | Select-Object -Unique
      $canonicalChildren = @(
        foreach ($selection in $SelectedNestedWorktree) {
          $childJunctions = [ordered]@{}
          if ($selection.ApprovedJunctionTarget) {
            foreach ($key in @($selection.ApprovedJunctionTarget.Keys | Sort-Object)) {
              $canonicalKey = $key.Replace('\', '/').ToLowerInvariant()
              if ($childJunctions.Contains($canonicalKey)) { throw 'Duplicate canonical nested child junction path.' }
              $childJunctions[$canonicalKey] = (Get-RemovalPath $selection.ApprovedJunctionTarget[$key]).ToLowerInvariant()
            }
          }
          [ordered]@{
            RepositoryPath = (Get-RemovalPath $selection.RepositoryPath).ToLowerInvariant()
            WorktreePath = (Get-RemovalPath $selection.WorktreePath).ToLowerInvariant()
            Head = ([string]$selection.Head).ToLowerInvariant()
            RecoveryReference = [string]$selection.RecoveryReference
            AdministrativePath = if ($selection.AdministrativePath) { (Get-RemovalPath $selection.AdministrativePath).ToLowerInvariant() } else { '' }
            AdapterPlaceholderPath = @($selection.AdapterPlaceholderPath | Where-Object { $_ } | ForEach-Object { $_.Replace('\', '/').ToLowerInvariant() } | Sort-Object)
            ApprovedJunctionTarget = $childJunctions
            ResidualDirectoryRoot = @($selection.ResidualDirectoryRoot | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object)
          }
        }
      )
      $canonicalPlan = [ordered]@{
        Owners = @($owners | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
        Children = @($canonicalChildren | Sort-Object { $_.RepositoryPath + '|' + $_.WorktreePath })
      } | ConvertTo-Json -Depth 15 -Compress
      if (($state.ContainsKey('NestedPlan') -and $state.NestedPlan -cne $canonicalPlan) -or ((Test-Path -LiteralPath $receiptFull) -and -not $state.ContainsKey('NestedPlan'))) { throw 'Owning repositories or selected nested recovery plan changed since receipt.' }
      $state.Manifest = $manifestText
      $state.NestedPlan = $canonicalPlan
      $state.Invocation = $retryParameters
      $nested = @()
      foreach ($owner in $owners) {
        $list = Invoke-RemovalGit $owner @('worktree', 'list', '--porcelain')
        if (-not $list.Succeeded) { throw "Cannot inventory nested owner: $owner" }
        $entry = $null
        foreach ($line in @($list.Output) + @('worktree __end__')) {
          if ($line -like 'worktree *') {
            if ($entry -and $entry.WorktreePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $nested += [pscustomobject]$entry }
            if ($line -eq 'worktree __end__') { break }
            $entry = @{ RepositoryPath = $owner; WorktreePath = Get-RemovalPath $line.Substring(9); Head = ''; Prunable = $false }
          } elseif ($line -like 'HEAD *') { $entry.Head = $line.Substring(5) }
          elseif ($line -like 'prunable*') { $entry.Prunable = $true }
        }
      }
      foreach ($journalChild in @($state.NestedChildren)) {
        if (-not $journalChild -or $journalChild.Completed) { continue }
        $existingChild = @($nested | Where-Object { $_.RepositoryPath -ieq $journalChild.RepositoryPath -and $_.WorktreePath -ieq $journalChild.WorktreePath })
        if ($existingChild.Count -and $journalChild.Deregistered) { throw 'Deregistered child was registered again; explicit review required.' }
        if (-not $existingChild.Count -and $journalChild.Deregistered) {
          $nested += [pscustomobject]@{ RepositoryPath=$journalChild.RepositoryPath; WorktreePath=$journalChild.WorktreePath; Head=$journalChild.Head; Prunable=$false; NativeDeregistered=$true }
        }
      }
      foreach ($slot in @($state.MetadataSlots)) {
        if (-not $slot -or $slot.Completed) { continue }
        $existing = @($nested | Where-Object { $_.RepositoryPath -ieq $slot.RepositoryPath -and $_.WorktreePath -ieq $slot.WorktreePath })
        if ($existing.Count) { $existing[0].Head = $slot.Head; $existing[0].Prunable = $true }
        else { $nested += [pscustomobject]@{ RepositoryPath = $slot.RepositoryPath; WorktreePath = $slot.WorktreePath; Head = $slot.Head; Prunable = $true } }
      }
      foreach ($child in $nested) {
        $selected = @($SelectedNestedWorktree | Where-Object { (Get-RemovalPath $_.RepositoryPath) -ieq $child.RepositoryPath -and (Get-RemovalPath $_.WorktreePath) -ieq $child.WorktreePath })
        if ($selected.Count -ne 1 -or $selected[0].Head -ine $child.Head -or $selected[0].RecoveryReference -notmatch '^refs/archive/[a-zA-Z0-9/._-]+$') { throw "Nested registration lacks exact preservation plan: $($child.WorktreePath)" }
        $preserved = Invoke-RemovalGit $child.RepositoryPath @('rev-parse', '--verify', "$($selected[0].RecoveryReference)^{commit}")
        if (-not $preserved.Succeeded -or $preserved.Output[0] -ine $child.Head) { throw 'Nested HEAD recovery reference mismatch.' }
        if (@(Get-SprintEndActiveWorkspaceRoot -WorktreePath $child.WorktreePath).Count) { throw 'Nested active workspace blocks removal.' }
      }
      foreach ($selection in $SelectedNestedWorktree) {
        if (-not (Get-RemovalPath $selection.WorktreePath).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or (Get-RemovalPath $selection.RepositoryPath) -notin $owners) { throw 'Nested selection is outside selected subtree or explicit owners.' }
        if ($selection.Head -notmatch '^[0-9a-f]{40,64}$' -or $selection.RecoveryReference -notmatch '^refs/archive/[a-zA-Z0-9/._-]+$') { throw 'Nested selected HEAD or recovery reference is invalid.' }
        $selectedRef = Invoke-RemovalGit $selection.RepositoryPath @('rev-parse', '--verify', "$($selection.RecoveryReference)^{commit}")
        if (-not $selectedRef.Succeeded -or $selectedRef.Output[0] -ine $selection.Head) { throw 'Selected recovery reference changed, including completed selections.' }
      }
      foreach ($child in @($nested | Where-Object Prunable)) {
        $selection = @($SelectedNestedWorktree | Where-Object { (Get-RemovalPath $_.RepositoryPath) -ieq $child.RepositoryPath -and (Get-RemovalPath $_.WorktreePath) -ieq $child.WorktreePath })[0]
        Remove-SprintWorktreeRecoveryMetadata -Selection $selection -State $state -Record {} -InventoryOnly
      }
      if ($state.Deregistered) {
        Remove-SprintWorktreeResidual -Root $worktreeFull -PlaceholderPath $placeholderNames -JunctionTarget $ApprovedJunctionTarget -DirectoryRoot $ResidualDirectoryRoot -Record {} -InventoryOnly | Out-Null
      }
      if (-not $PSCmdlet.ShouldProcess($worktreeFull, 'Journal and remove exact worktree and explicitly selected residuals')) { $planned = $true }
      else {
        $effectsStarted = $true
        if (-not $state.Deregistered) {
          $save = Invoke-RemovalGit $repositoryFull @('update-ref', $state.RecoveryReference, $state.Head)
          if (-not $save.Succeeded) { throw 'Could not preserve root HEAD before removal.' }
        }
        & $record 'PreRemoval' @{ Nested = $nested; Selected = $SelectedNestedWorktree; OwningRepositories = @($owners) }
        foreach ($child in @($nested | Sort-Object { $_.WorktreePath.Length } -Descending)) {
          $selection = @($SelectedNestedWorktree | Where-Object { $_.WorktreePath -ieq $child.WorktreePath -and $_.RepositoryPath -ieq $child.RepositoryPath })[0]
          if ($child.Prunable) {
            Remove-SprintWorktreeRecoveryMetadata -Selection $selection -State $state -Record $record
          } else {
            if (-not $state.ContainsKey('NestedChildren')) { $state.NestedChildren = @() }
            $childJournal = @($state.NestedChildren | Where-Object { $_.RepositoryPath -ieq $child.RepositoryPath -and $_.WorktreePath -ieq $child.WorktreePath })
            if (-not $childJournal.Count) {
              $state.NestedChildren += @{ RepositoryPath=$child.RepositoryPath; WorktreePath=$child.WorktreePath; Head=$child.Head; RecoveryReference=$selection.RecoveryReference; Deregistered=$false; Completed=$false }
              $childJournal = @($state.NestedChildren | Select-Object -Last 1)
            }
            if (-not $childJournal[0].Deregistered) {
              & $record 'BeforeNestedGitRemoval' $child
              $childResult = Invoke-RemovalGit $child.RepositoryPath @('worktree', 'remove', $child.WorktreePath, '--force')
              & $record 'NestedGitResult' $childResult
              $childAfter = Invoke-RemovalGit $child.RepositoryPath @('worktree', 'list', '--porcelain')
              if (-not $childResult.Succeeded -or -not $childAfter.Succeeded -or @($childAfter.Output | Where-Object { $_ -like 'worktree *' -and (Get-RemovalPath $_.Substring(9)) -ieq $child.WorktreePath }).Count) { throw 'Selected nested Git removal failed or remains registered; parent retained.' }
              $childJournal[0].Deregistered = $true
              & $record 'NestedDeregistered' $child
            }
            $childJunctions = if ($selection.ApprovedJunctionTarget) { $selection.ApprovedJunctionTarget } else { @{} }
            Remove-SprintWorktreeResidual -Root $child.WorktreePath -PlaceholderPath @($selection.AdapterPlaceholderPath | Where-Object { $_ }) -JunctionTarget $childJunctions -DirectoryRoot @($selection.ResidualDirectoryRoot | Where-Object { $_ }) -Record $record | Out-Null
            $childJournal[0].Completed = $true
            & $record 'NestedComplete' $child
          }
        }
        if (-not $state.Deregistered) {
          for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            if (@(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktreeFull).Count) { throw 'Active workspace appeared before native removal.' }
            $attempts++
            & $record 'BeforeNativeRemoval' @{ Attempt = $attempts }
            $native = Invoke-RemovalGit $repositoryFull @('worktree', 'remove', $worktreeFull, '--force')
            $state.NativeAttempts += @{ Attempt = $attempts; Result = $native }
            & $record 'NativeResult' $native
            $after = Invoke-RemovalGit $repositoryFull @('worktree', 'list', '--porcelain')
            if (-not $after.Succeeded) { throw 'Cannot verify post-removal registration.' }
            $stillRegistered = @($after.Output | Where-Object { $_ -like 'worktree *' -and (Get-RemovalPath $_.Substring(9)) -ieq $worktreeFull }).Count -gt 0
            $state.AfterRegistration = @($after.Output)
            if (-not $stillRegistered) {
              if (-not $native.Succeeded) { throw "Git failed with exit code $($native.ExitCode) despite deregistration; explicit review required." }
              $state.Deregistered = $true
              & $record 'Deregistered' $worktreeFull
              break
            }
            if (-not $native.Succeeded) { $failures.Add("Attempt $attempts failed with Git exit code $($native.ExitCode).") }
            if ($native.Succeeded) { throw 'Git returned success but worktree remains registered.' }
            if ($attempt -lt $MaxAttempts -and $RetryDelayMilliseconds) { Start-Sleep -Milliseconds $RetryDelayMilliseconds }
          }
        }
        if (-not $state.Deregistered) { throw "Worktree remains registered after $attempts bounded attempts." }
        if (@(Get-SprintEndActiveWorkspaceRoot -WorktreePath $worktreeFull).Count) { throw 'Active workspace appeared before residual cleanup.' }
        $removed = @(Remove-SprintWorktreeResidual -Root $worktreeFull -PlaceholderPath $placeholderNames -JunctionTarget $ApprovedJunctionTarget -DirectoryRoot $ResidualDirectoryRoot -Record $record)
        $final = Invoke-RemovalGit $repositoryFull @('worktree', 'list', '--porcelain')
        if (-not $final.Succeeded -or @($final.Output | Where-Object { $_ -like 'worktree *' -and (Get-RemovalPath $_.Substring(9)) -ieq $worktreeFull }).Count -or (Test-Path -LiteralPath $worktreeFull)) { throw 'Independent final absence checks failed.' }
        & $record 'Complete' $worktreeFull
        $complete = $true
        if (Test-Path -LiteralPath $handoffFull -PathType Leaf) { [IO.File]::Delete($handoffFull) }
      }
    } catch {
      $failures.Add($_.Exception.Message)
      if ($state -and -not $WhatIfPreference -and ($receiptPresentAtEntry -or $effectsStarted)) { & $record 'Failure' $_.Exception.Message }
      if ($PSCmdlet.ShouldProcess($handoffFull, 'Write remaining-step handoff')) {
        [IO.Directory]::CreateDirectory((Split-Path $handoffFull -Parent)) | Out-Null
        $literalReceipt = "'" + ($receiptFull -replace "'", "''") + "'"
        $retry = if ($state -and $state.Invocation -and (Test-Path -LiteralPath $receiptFull -PathType Leaf)) {
          '$retry = (Get-Content -LiteralPath ' + $literalReceipt + ' -Raw | ConvertFrom-Json -AsHashtable).Invocation' + "`n" + 'Remove-SprintWorktreeSafely @retry -ThrowOnFailure -Confirm:$false'
        } else {
          $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($retryParameters | ConvertTo-Json -Depth 20 -Compress)))
          '$retry = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(' + "'" + $encoded + "'" + ')) | ConvertFrom-Json -AsHashtable' + "`n" + 'Remove-SprintWorktreeSafely @retry -ThrowOnFailure -Confirm:$false'
        }
        [IO.File]::WriteAllText($handoffFull, ("# Remaining SprintEnd worktree teardown`n`n" + ($failures -join "`n") + "`n`nRun from outside the worktree in profile-enabled PowerShell7:`n`n~~~powershell`n" + $retry + "`n~~~`n"))
      }
      if ($ThrowOnFailure) { throw }
    }
    return [pscustomobject]@{
      Ok = ($complete -or $planned)
      Removed = $complete
      Planned = $planned; Attempts = $attempts; WorktreePath = $worktreeFull; ActiveRoots = $activeRoots
      RemovedPlaceholders = @($removed); Failures = $failures.ToArray(); ReceiptPath = $receiptFull
      HandoffPath = if ($failures.Count) { $handoffFull } else { $null }
    }
  }
  end { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' }
}
