function Set-SprintLoginScheduledTaskTarget {
  <#
  .SYNOPSIS
    Validates or retargets the retained login scheduled-task pair at a sprint boundary.
  .DESCRIPTION
    Changes only a recognized PowerShell -File LoginScript.ps1 argument. Both task
    definitions are preflighted, copied independently, compared before writes, and
    read back. A failed pair update restores every attempted action array in reverse
    order, including an update that changed state before throwing. No task is started.
    CheckOnly compares the current pair to the selected target without repairing it.
  .NOTES
    Private lifecycle helper. Live task maintenance requires operator authorization.
    The explicit development target is invocation-only and must retain LoginScript.ps1
    as its filename so subsequent boundary calls can recognize the retained binding.
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateSet('Start', 'End')][string] $Boundary,
    [AllowEmptyString()][string] $ATAPUtilitiesRoot,
    [AllowEmptyString()][string] $GitRoot,
    [AllowNull()][AllowEmptyString()][string] $LoginScriptPath,
    [string[]] $WorktreePaths = @(),
    [switch] $CheckOnly
  )

  begin {
    $fn = 'Set-SprintLoginScheduledTaskTarget'
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $explicitOverride = $PSBoundParameters.ContainsKey('LoginScriptPath')
    $result = [PSCustomObject]@{
      Ok = $false; Boundary = $Boundary
      SelectionMode = $(if ($explicitOverride) { 'ExplicitDevelopmentOverride' } elseif ($Boundary -eq 'Start') { 'SprintDefault' } else { 'StableDefault' })
      TargetPath = $null; TargetHash = $null; Planned = $false; Changed = $false
      Tasks = @(); Rollback = [PSCustomObject]@{ Attempted = $false; Succeeded = $false; Failures = @() }; Failures = @()
    }
    $snapshots = [Collections.Generic.List[object]]::new()
    $attempted = [Collections.Generic.List[object]]::new()

    function getLoginAbsolutePath {
      param([string] $Path)
      if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathFullyQualified($Path) -or
        [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path) -or $Path.Contains('"')) {
        throw "Expected an explicit absolute path without wildcards: '$Path'."
      }
      $full = [IO.Path]::GetFullPath($Path)
      if ($full.Length -gt [IO.Path]::GetPathRoot($full).Length) {
        $full = $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
      }
      $full
    }

    function resolveLoginPath {
      param([string] $Path, [ValidateSet('File', 'Directory')][string] $Kind, [int] $Depth = 0)
      if ($Depth -gt 32) { throw "Cannot establish link destination for '$Path'." }
      $full = getLoginAbsolutePath $Path
      $root = [IO.Path]::GetPathRoot($full)
      $current = $root
      $parts = $full.Substring($root.Length).Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries)
      foreach ($part in $parts) {
        $current = Join-Path $current $part
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        # CloudFiles placeholders also carry ReparsePoint; they are ordinary
        # filesystem entries, not symbolic-link/junction redirects.
        if ($item.LinkType -in @('SymbolicLink', 'Junction')) {
          $destination = $item.ResolveLinkTarget($true)
          if ($null -eq $destination) { throw "Cannot establish link destination for '$current'." }
          $destinationKind = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
          $current = resolveLoginPath -Path $destination.FullName -Kind $destinationKind -Depth ($Depth + 1)
        }
      }
      $resolved = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      if (($Kind -eq 'Directory') -ne [bool]$resolved.PSIsContainer) { throw "Expected $Kind at '$Path'." }
      getLoginAbsolutePath $resolved.FullName
    }

    function resolveLoginRemovalRoot {
      param([string] $Path)
      $full = getLoginAbsolutePath $Path
      $tail = [Collections.Generic.List[string]]::new()
      $existing = $full
      while ($true) {
        try {
          Get-Item -LiteralPath $existing -Force -ErrorAction Stop | Out-Null
          break
        } catch [Management.Automation.ItemNotFoundException] {
          $tail.Insert(0, [IO.Path]::GetFileName($existing))
          $parent = [IO.Path]::GetDirectoryName($existing)
          if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $existing) { throw }
          $existing = $parent
        }
      }
      $physical = resolveLoginPath -Path $existing -Kind Directory
      foreach ($part in $tail) { $physical = Join-Path $physical $part }
      getLoginAbsolutePath $physical
    }

    function readLoginXml {
      param([string] $Text)
      $settings = [Xml.XmlReaderSettings]::new()
      $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
      $settings.XmlResolver = $null
      $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($Text), $settings)
      try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.PreserveWhitespace = $false
        $document.Load($reader)
        if ($document.DocumentElement.LocalName -ne 'Task') { throw 'Expected a Task Scheduler XML definition.' }
        return ,$document
      } finally { $reader.Dispose() }
    }

    function copyLoginInstance {
      param($Instance)
      if ($Instance -is [Microsoft.Management.Infrastructure.CimInstance]) {
        $copy = [Microsoft.Management.Infrastructure.CimInstance]::new($Instance)
        foreach ($property in $Instance.CimInstanceProperties) {
          if ($property.Value -is [Microsoft.Management.Infrastructure.CimInstance]) {
            $copy.CimInstanceProperties[$property.Name].Value = copyLoginInstance $property.Value
          } elseif ($property.Value -is [Microsoft.Management.Infrastructure.CimInstance[]]) {
            $copy.CimInstanceProperties[$property.Name].Value = [Microsoft.Management.Infrastructure.CimInstance[]]@(
              foreach ($child in $property.Value) { copyLoginInstance $child }
            )
          }
        }
        return $copy
      }
      # Detached test doubles use independent deep copies as well.
      [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($Instance))
    }

    function copyLoginActions {
      param([object[]] $Actions)
      $copies = foreach ($action in $Actions) { copyLoginInstance $action }
      return ,@($copies)
    }

    function getLoginBinding {
      param([Xml.XmlDocument] $Document)
      $actionNodes = @($Document.SelectNodes('/*[local-name()="Task"]/*[local-name()="Actions"]/*'))
      $bindings = [Collections.Generic.List[object]]::new()
      for ($actionIndex = 0; $actionIndex -lt $actionNodes.Count; $actionIndex++) {
        $actionNode = $actionNodes[$actionIndex]
        if ($actionNode.LocalName -ne 'Exec') { continue }
        $commandNode = $actionNode.SelectSingleNode('*[local-name()="Command"]')
        $argumentsNode = $actionNode.SelectSingleNode('*[local-name()="Arguments"]')
        $command = if ($commandNode) { $commandNode.InnerText } else { '' }
        $arguments = if ($argumentsNode) { $argumentsNode.InnerText } else { '' }
        $isPowerShell = [IO.Path]::GetFileName($command) -match '^(pwsh|powershell)(\.exe)?$'
        if (-not $isPowerShell) {
          if ($arguments -match '(?i)LoginScript\.ps1') { throw 'Unsupported login launch executable.' }
          continue
        }
        if ($arguments -notmatch '(?i)LoginScript\.ps1') { continue }
        # Recognize only complete double-quoted or bare tokens. No expression evaluation
        # or speculative rewriting of embedded/escaped quotes is permitted.
        $tokens = @([regex]::Matches($arguments, '"[^"\r\n]*"|[^\s"\r\n]+'))
        $position = 0
        foreach ($token in $tokens) {
          if ($arguments.Substring($position, $token.Index - $position) -match '\S') { throw 'Malformed action argument quoting.' }
          if ($token.Index -eq $position -and $position -ne 0) { throw 'Unsupported adjacent action argument tokens.' }
          $position = $token.Index + $token.Length
        }
        if ($arguments.Substring($position) -match '\S') { throw 'Malformed action argument quoting.' }
        $values = @($tokens | ForEach-Object { $_.Value.Trim('"') })
        $fileIndices = @()
        for ($i = 0; $i -lt $values.Count; $i++) { if ($values[$i] -ieq '-File') { $fileIndices += $i } }
        if ($fileIndices.Count -ne 1) { throw 'PowerShell action must have exactly one recognized -File binding.' }
        $fileIndex = $fileIndices[0]
        if ($fileIndex + 1 -ge $values.Count) { throw 'PowerShell -File action has no target.' }
        for ($i = 0; $i -lt $fileIndex; $i++) {
          if ($values[$i] -match '^(?i)-(NoLogo|NoProfile|NonInteractive|NoExit|Sta|Mta)$') { continue }
          if ($values[$i] -match '^(?i)-(ExecutionPolicy|WindowStyle|InputFormat|OutputFormat)$' -and $i + 1 -lt $fileIndex) { $i++; continue }
          throw "Unsupported PowerShell launch option '$($values[$i])'."
        }
        $binding = getLoginAbsolutePath $values[$fileIndex + 1]
        if ([IO.Path]::GetFileName($binding) -ine 'LoginScript.ps1') {
          # An unrelated, well-formed PowerShell -File action is preserved.
          continue
        }
        # Keep the literal registration binding. An ephemeral alias to stable
        # is still unsafe after teardown, even when its current destination matches.
        $bindings.Add([PSCustomObject]@{
          ActionIndex = $actionIndex; Binding = $binding; Arguments = $arguments
          Token = $tokens[$fileIndex + 1]; ArgumentsNode = $argumentsNode
        })
      }
      if ($bindings.Count -ne 1) { throw "Expected exactly one LoginScript.ps1 binding; found $($bindings.Count)." }
      return $bindings[0]
    }

    function getLoginTaskSnapshot {
      param([string] $Name, [object[]] $Inventory)
      $matches = @($Inventory | Where-Object { $_.TaskName -ieq $Name })
      if ($matches.Count -ne 1) { throw "Expected exactly one scheduled task named '$Name' across folders; found $($matches.Count)." }
      $task = $matches[0]
      if ([string]::IsNullOrWhiteSpace($task.TaskPath)) { throw "Missing TaskPath for '$Name'." }
      $document = readLoginXml (Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop)
      $binding = getLoginBinding $document
      $actions = copyLoginActions @($task.Actions)
      $xmlActions = @($document.SelectNodes('/*[local-name()="Task"]/*[local-name()="Actions"]/*'))
      if ($actions.Count -ne $xmlActions.Count) { throw "Action snapshot count differs for '$Name'." }
      for ($i = 0; $i -lt $actions.Count; $i++) {
        if ($xmlActions[$i].LocalName -eq 'Exec') {
          foreach ($pair in @(@('Command', 'Execute'), @('Arguments', 'Arguments'), @('WorkingDirectory', 'WorkingDirectory'))) {
            $node = $xmlActions[$i].SelectSingleNode("*[local-name()='$($pair[0])']")
            $xmlValue = if ($node) { $node.InnerText } else { '' }
            if ($xmlValue -cne [string]$actions[$i].($pair[1])) { throw "Action snapshot changed while reading '$Name'." }
          }
        }
      }
      [PSCustomObject]@{
        TaskName = $task.TaskName; TaskPath = $task.TaskPath; Xml = $document.OuterXml
        Binding = $binding.Binding; ActionIndex = $binding.ActionIndex; Actions = $actions
        Arguments = $binding.Arguments; TokenIndex = $binding.Token.Index; TokenLength = $binding.Token.Length
      }
    }

    function assertLoginTarget {
      if ((resolveLoginPath -Path $result.TargetPath -Kind File) -ine $result.TargetPath -or
        (Get-FileHash -LiteralPath $result.TargetPath -Algorithm SHA256 -ErrorAction Stop).Hash -cne $result.TargetHash) {
        throw 'Selected login target changed after preflight.'
      }
    }

    function assertLoginPair {
      param([switch] $Original)
      $inventory = @(Get-ScheduledTask -ErrorAction Stop)
      foreach ($snapshot in $snapshots) {
        $actual = getLoginTaskSnapshot -Name $snapshot.TaskName -Inventory $inventory
        $expected = if ($Original -or -not $snapshot.Applied) { $snapshot.Xml } else { $snapshot.DesiredXml }
        if ($actual.TaskPath -cne $snapshot.TaskPath -or $actual.Xml -cne $expected) {
          throw "Scheduled task changed outside the approved binding: '$($snapshot.TaskPath)$($snapshot.TaskName)'."
        }
      }
    }
  }

  process {
    try {
      Get-Command -Name Write-PSFMessage -ErrorAction Stop | Out-Null
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Validating login task pair for boundary $Boundary."
      foreach ($command in @('Get-ScheduledTask', 'Export-ScheduledTask', 'Set-ScheduledTask')) {
        Get-Command -Name $command -ErrorAction Stop | Out-Null
      }
      $suffix = 'src/ATAP.Utilities.PowerShell/Profiles/LoginScript.ps1'
      if ($explicitOverride) {
        $target = getLoginAbsolutePath $LoginScriptPath
      } elseif ($Boundary -eq 'End') {
        $stableRoot = resolveLoginPath -Path (Join-Path (getLoginAbsolutePath $GitRoot) 'ATAP.Utilities') -Kind Directory
        $target = Join-Path $stableRoot $suffix
      } else {
        $sprintPattern = '^ATAP\.Utilities-wt-\d+-Sprint-(?<Sprint>\d{4})-work-items$'
        $sprintIds = @($WorktreePaths | ForEach-Object {
            $leaf = [IO.Path]::GetFileName((getLoginAbsolutePath $_))
            if ($leaf -match '-wt-\d+-Sprint-(\d{4})-work-items$') { $Matches[1] }
          } | Sort-Object -Unique)
        if ($sprintIds.Count -gt 1) { throw 'WorktreePaths contains multiple sprint identities.' }
        if ($PSBoundParameters.ContainsKey('ATAPUtilitiesRoot')) {
          $candidates = @($ATAPUtilitiesRoot)
        } else {
          $candidates = @($WorktreePaths | Where-Object { [IO.Path]::GetFileName((getLoginAbsolutePath $_)) -match $sprintPattern })
        }
        $roots = @($candidates | ForEach-Object { resolveLoginPath -Path $_ -Kind Directory } | Sort-Object -Unique)
        if ($roots.Count -ne 1) { throw "Expected exactly one explicit Utilities sprint root; found $($roots.Count)." }
        if ([IO.Path]::GetFileName($roots[0]) -notmatch $sprintPattern) { throw 'Start target is not an explicit Utilities sprint root.' }
        $selectedSprint = $Matches.Sprint
        if ($sprintIds.Count -eq 1 -and $selectedSprint -ne $sprintIds[0]) { throw 'Utilities root does not match the invocation sprint identity.' }
        $target = Join-Path $roots[0] $suffix
      }
      $result.TargetPath = resolveLoginPath -Path $target -Kind File
      if ([IO.Path]::GetFileName($result.TargetPath) -ine 'LoginScript.ps1') { throw 'Target must retain the LoginScript.ps1 filename.' }
      if ($Boundary -eq 'End') {
        foreach ($removalPath in $WorktreePaths) {
          $removalRoot = resolveLoginRemovalRoot $removalPath
          $removalPrefix = $removalRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
          if ($result.TargetPath -ieq $removalRoot -or $result.TargetPath.StartsWith($removalPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "End target is inside a worktree being removed: '$removalRoot'."
          }
        }
      }
      $result.TargetHash = (Get-FileHash -LiteralPath $result.TargetPath -Algorithm SHA256 -ErrorAction Stop).Hash
      $inventory = @(Get-ScheduledTask -ErrorAction Stop)
      $result.Tasks = @('ATAPLoginScript', 'Unlock BitWarden') | ForEach-Object {
        [PSCustomObject]@{
          TaskName = $_; TaskPath = $null; BeforeBinding = $null; AfterBinding = $null
          Outcome = 'Failed'; PreservedPropertiesVerified = $false
        }
      }
      foreach ($entry in $result.Tasks) {
        $taskName = $entry.TaskName
        $snapshot = getLoginTaskSnapshot -Name $taskName -Inventory $inventory
        $desiredArguments = $snapshot.Arguments.Substring(0, $snapshot.TokenIndex) + '"' + $result.TargetPath + '"' +
          $snapshot.Arguments.Substring($snapshot.TokenIndex + $snapshot.TokenLength)
        $needsChange = $snapshot.Binding -ine $result.TargetPath
        if (-not $needsChange) { $desiredArguments = $snapshot.Arguments }
        $desiredDocument = readLoginXml $snapshot.Xml
        $desiredBinding = getLoginBinding $desiredDocument
        $desiredBinding.ArgumentsNode.InnerText = $desiredArguments
        $desiredActions = copyLoginActions $snapshot.Actions
        $desiredActions[$snapshot.ActionIndex].Arguments = $desiredArguments
        $entry.TaskName = $snapshot.TaskName
        $entry.TaskPath = $snapshot.TaskPath
        $entry.BeforeBinding = $snapshot.Binding
        $entry.AfterBinding = $snapshot.Binding
        $entry.Outcome = 'Checked'
        $snapshot | Add-Member -NotePropertyMembers @{
          DesiredXml = $desiredDocument.OuterXml; DesiredActions = $desiredActions
          NeedsChange = $needsChange; Applied = $false; Entry = $entry
        }
        $snapshots.Add($snapshot)
      }
      assertLoginTarget
      assertLoginPair -Original
      if ($CheckOnly) {
        foreach ($snapshot in $snapshots) {
          if ($snapshot.NeedsChange) { $snapshot.Entry.Outcome = 'Failed'; throw "Task binding does not match selected target: '$($snapshot.TaskName)'." }
          $snapshot.Entry.PreservedPropertiesVerified = $true
        }
        $result.Ok = $true
        return $result
      }
      $changes = @($snapshots | Where-Object NeedsChange)
      if ($changes.Count -gt 0 -and -not $PSCmdlet.ShouldProcess('ATAPLoginScript and Unlock BitWarden', "Retarget login bindings to '$($result.TargetPath)'")) {
        $result.Planned = $true
        foreach ($snapshot in $snapshots) {
          $snapshot.Entry.Outcome = if ($snapshot.NeedsChange) { 'Planned' } else { 'Unchanged' }
          $snapshot.Entry.AfterBinding = $result.TargetPath
          $snapshot.Entry.PreservedPropertiesVerified = $true
        }
        $result.Ok = $true
        return $result
      }
      foreach ($snapshot in $snapshots) {
        if (-not $snapshot.NeedsChange) { $snapshot.Entry.Outcome = 'Unchanged'; continue }
        assertLoginTarget
        assertLoginPair
        # Record intent before the call: Task Scheduler can mutate and then throw.
        $attempted.Add($snapshot)
        $result.Changed = $true
        Set-ScheduledTask -TaskName $snapshot.TaskName -TaskPath $snapshot.TaskPath -Action (copyLoginActions $snapshot.DesiredActions) -ErrorAction Stop | Out-Null
        $snapshot.Applied = $true
        $result.Changed = $true
        $snapshot.Entry.Outcome = 'Applied'
      }
      assertLoginTarget
      assertLoginPair
      foreach ($snapshot in $snapshots) {
        $snapshot.Entry.AfterBinding = $result.TargetPath
        $snapshot.Entry.PreservedPropertiesVerified = $true
      }
      $result.Ok = $true
    } catch {
      $result.Failures += $_.Exception.Message
      if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $_.Exception.Message
        } catch { $result.Failures += "Failure logging: $($_.Exception.Message)" }
      }
      if ($attempted.Count -gt 0) {
        $result.Rollback.Attempted = $true
        for ($i = $attempted.Count - 1; $i -ge 0; $i--) {
          $snapshot = $attempted[$i]
          try {
            Set-ScheduledTask -TaskName $snapshot.TaskName -TaskPath $snapshot.TaskPath -Action (copyLoginActions $snapshot.Actions) -ErrorAction Stop | Out-Null
          } catch { $result.Rollback.Failures += "Restore '$($snapshot.TaskPath)$($snapshot.TaskName)': $($_.Exception.Message)" }
        }
        foreach ($snapshot in $snapshots) {
          try {
            $actual = getLoginTaskSnapshot -Name $snapshot.TaskName -Inventory @(Get-ScheduledTask -ErrorAction Stop)
            $snapshot.Entry.AfterBinding = $actual.Binding
            if ($actual.TaskPath -cne $snapshot.TaskPath -or $actual.Xml -cne $snapshot.Xml) { throw 'Snapshot readback differs after rollback.' }
            $snapshot.Entry.PreservedPropertiesVerified = $true
          } catch {
            $snapshot.Entry.PreservedPropertiesVerified = $false
            $result.Rollback.Failures += "Verify '$($snapshot.TaskPath)$($snapshot.TaskName)': $($_.Exception.Message)"
          }
          $snapshot.Entry.Outcome = 'Failed'
        }
        $result.Rollback.Succeeded = $result.Rollback.Failures.Count -eq 0
        if ($result.Rollback.Succeeded) { $result.Changed = $false }
        $result.Failures += $result.Rollback.Failures
      } else {
        foreach ($snapshot in $snapshots) { $snapshot.Entry.Outcome = 'Failed' }
      }
    }
    return $result
  }

  end { }
}
