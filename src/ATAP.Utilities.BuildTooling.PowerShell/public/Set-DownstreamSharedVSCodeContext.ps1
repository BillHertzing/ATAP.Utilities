function Set-DownstreamSharedVSCodeContext {
  <#
  .SYNOPSIS
    Applies the resolver's validated Normal worktree context.
  .DESCRIPTION
    Requires separately migrated common topology. Linked routing goes only to
    registered config.worktree, with exact include before absolute overrides.
    Downstream files retain LF and UTF8 without BOM. Canonical source is never
    rendered. Repeated desired routing and unchanged outputs are not rewritten.
    Standalone failures restore only verified own postimages; partial or unknown
    postimages are held. No enclosing workspace-reference transaction is provided.
  .PARAMETER WorkspaceFiles
    Compatible .code-workspace files in one registered repository.
  .PARAMETER GitRoot
    Parent directory containing repositories.
  .PARAMETER SharedVSCodeRepoName
    Stable canonical repository folder name.
  .PARAMETER SharedHooksSubPath
    Relative canonical hooks directory.
  .PARAMETER CommitTemplateRelativePath
    Relative canonical commit template.
  .OUTPUTS
    None. Throws on invalid plan, changed observation or output failure.
  .EXAMPLE
    Set-DownstreamSharedVSCodeContext -WorkspaceFiles 'D:/Repos/Consumer-wt/Consumer.code-workspace' -GitRoot 'D:/Repos' -WhatIf
  .NOTES
    Ordinary application never enables worktreeConfig or migrates common config.
  .LINK
    Get-SharedVSCodeContext
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$WorkspaceFiles,
    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )
  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
    function writerPath([string]$Path) {
      $full = [IO.Path]::GetFullPath($Path).Replace('\', '/').TrimEnd('/')
      $item = [IO.FileInfo]::new($full)
      if ($item.LinkTarget) { throw 'SharedVSCodeWriter.RedirectedPath' }
      for ($parent = $item.Directory; $null -ne $parent; $parent = $parent.Parent) {
        if ($parent.LinkTarget) { throw 'SharedVSCodeWriter.RedirectedPath' }
      }
      return $full
    }
    function writerBytes([string]$Path) {
      $null = writerPath $Path
      if ([IO.Directory]::Exists($Path)) { throw 'SharedVSCodeWriter.OutputIsDirectory' }
      if ([IO.File]::Exists($Path)) { return ,([IO.File]::ReadAllBytes($Path)) }
      return $null
    }
    function sameBytes([byte[]]$Left, [byte[]]$Right) {
      if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left -and $null -eq $Right) }
      return [Linq.Enumerable]::SequenceEqual($Left, $Right)
    }
    function generatedBytes([string]$Source) {
      $content = New-GeneratedFileContent -SourcePath $Source
      return ,([Text.UTF8Encoding]::new($false).GetBytes(($content -replace '\r\n?', "`n") + "`n"))
    }
    function quotedConfig([string]$Value) {
      if ($Value -match '[\x00-\x1f]') { throw 'SharedVSCodeWriter.InvalidRouteValue' }
      return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
    }
  }
  process {
    $options = @{
      WorkspaceFiles = $WorkspaceFiles; GitRoot = $GitRoot
      SharedVSCodeRepoName = $SharedVSCodeRepoName; SharedHooksSubPath = $SharedHooksSubPath
      CommitTemplateRelativePath = $CommitTemplateRelativePath; ContextMode = 'Normal'; ErrorAction = 'Stop'
    }
    $contexts = @(Get-SharedVSCodeContext @options)
    if (!$contexts.Count) { throw 'SharedVSCodeWriter.MissingPlan' }
    $plan = $contexts[0].Plan
    if ($plan.SchemaVersion -ne 2 -or $plan.ContextMode -cne 'Normal' -or
      $plan.ValidationStatus -cne 'ValidatedReadOnlyPlan' -or
      $plan.CurrentRouteState -cnotin @('AlreadyDesired', 'SafeUnconfiguredLinked')) { throw 'SharedVSCodeWriter.InvalidPlan' }
    $planText = ConvertTo-Json -InputObject $plan -Depth 30 -Compress
    foreach ($context in $contexts) {
      if ((ConvertTo-Json -InputObject $context.Plan -Depth 30 -Compress) -cne $planText) { throw 'SharedVSCodeWriter.ConflictingPlans' }
    }
    $repoRoot = writerPath $plan.Target.TopLevel
    $route = $plan.Route
    $outputs = [Collections.Generic.List[object]]::new()
    if ($route.CanRenderConsumerFiles) {
      if ($plan.Role -cnotin @('DownstreamStable', 'DownstreamSprint') -or
        (writerPath $route.IncludeTarget) -ine ($repoRoot + '/.gitconfig.shared')) { throw 'SharedVSCodeWriter.InvalidRenderTarget' }
      $outputs.Add([pscustomobject]@{ Path = (writerPath ($repoRoot + '/.gitattributes')); Bytes = (generatedBytes $contexts[0].GitAttributes); Before = $null })
      $outputs.Add([pscustomobject]@{ Path = (writerPath $route.IncludeTarget); Bytes = (generatedBytes $contexts[0].GitConfig); Before = $null })
    } elseif ($plan.Role -cnotin @('CanonicalSourceStable', 'CanonicalSourceSprint')) { throw 'SharedVSCodeWriter.InvalidSourceRole' }
    if ($plan.CurrentRouteState -ceq 'SafeUnconfiguredLinked') {
      $configPath = writerPath $route.ConfigPath
      if (!$plan.Target.IsLinkedWorktree -or $configPath -ine (writerPath $plan.Target.WorktreeConfigPath) -or
        $configPath -ine ((writerPath $plan.Target.GitDir) + '/config.worktree') -or
        $route.Condition -cne ('gitdir/i:' + $plan.Target.GitDir) -or $route.Condition -match '[*?]|/$' -or
        $route.ExpectedOrder -cne 'include-before-absolute-hooks-template') { throw 'SharedVSCodeWriter.InvalidRouteTarget' }
      $oldBytes = writerBytes $configPath
      $suffix = "`n[includeIf " + (quotedConfig $route.Condition) + "]`n path = " + (quotedConfig $route.IncludeTarget) +
        "`n[core]`n hooksPath = " + (quotedConfig $route.HooksTarget) + "`n[commit]`n template = " + (quotedConfig $route.TemplateTarget) + "`n"
      # Fresh sections preserve unrelated bytes and prevent Git's setter from
      # reusing an earlier [core]/[commit] section before the include.
      $suffixBytes = [Text.UTF8Encoding]::new($false).GetBytes($suffix)
      $bytes = if ($null -eq $oldBytes) { $suffixBytes } else { [byte[]]($oldBytes + $suffixBytes) }
      $outputs.Add([pscustomobject]@{ Path = $configPath; Bytes = $bytes; Before = $null })
    }
    foreach ($output in $outputs) { $output.Before = writerBytes $output.Path }
    $changed = @($outputs | Where-Object { !(sameBytes $_.Before $_.Bytes) })
    if ($changed.Count -and $PSCmdlet.ShouldProcess($repoRoot, 'Apply validated generated files and worktree routing')) {
      # Reuse the topology resolver, including registered Git identities.
      $fresh = @(Get-SharedVSCodeContext @options)
      if (!$fresh.Count -or (ConvertTo-Json -InputObject $fresh[0].Plan -Depth 30 -Compress) -cne $planText) { throw 'SharedVSCodeWriter.ObservationChanged' }
      $written = [Collections.Generic.List[object]]::new()
      $attempted = $null
      try {
        foreach ($output in $changed) {
          if (!(sameBytes (writerBytes $output.Path) $output.Before)) { throw 'SharedVSCodeWriter.OutputChanged' }
          if ($output.Path -ieq $route.ConfigPath) {
            $fresh = @(Get-SharedVSCodeContext @options)
            foreach ($property in @('Target', 'SelectedAuthority', 'AssetPins', 'WorkspacePins', 'ConfigPins')) {
              if (!$fresh.Count -or (ConvertTo-Json -InputObject $fresh[0].Plan.$property -Depth 20 -Compress) -cne
                (ConvertTo-Json -InputObject $plan.$property -Depth 20 -Compress)) { throw 'SharedVSCodeWriter.ObservationChanged' }
            }
          }
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Writing: $($output.Path)"
          $attempted = $output
          [IO.File]::WriteAllBytes($output.Path, $output.Bytes)
          if (!(sameBytes (writerBytes $output.Path) $output.Bytes)) { throw 'SharedVSCodeWriter.PostimageMismatch' }
          $written.Add($output)
          $attempted = $null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Wrote: $($output.Path)"
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Context outputs committed'
      } catch {
        $failure = $_
        try { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Context output failed; checking recovery ownership' } catch { }
        # Preflight every own postimage before restoring any. Preserve peer or
        # uncertain partial writes for recovery instead of guessing ownership.
        $held = $null -ne $attempted
        foreach ($output in $written) {
          try { if (!(sameBytes (writerBytes $output.Path) $output.Bytes)) { $held = $true } } catch { $held = $true }
        }
        if ($held) { throw [InvalidOperationException]::new('SharedVSCodeWriter.HeldRecovery', $failure.Exception) }
        try {
          for ($index = $written.Count - 1; $index -ge 0; $index--) {
            $output = $written[$index]
            if (!(sameBytes (writerBytes $output.Path) $output.Bytes)) { throw 'PostimageChangedDuringRecovery' }
            if ($null -eq $output.Before) { [IO.File]::Delete($output.Path) }
            else { [IO.File]::WriteAllBytes($output.Path, $output.Before) }
            if (!(sameBytes (writerBytes $output.Path) $output.Before)) { throw 'RestoreMismatch' }
          }
        } catch { throw [InvalidOperationException]::new('SharedVSCodeWriter.HeldRecovery', $_.Exception) }
        throw $failure
      }
    }
  }
  end {
    # Completion logging for effects is inside the recoverable writer boundary.
  }
}
