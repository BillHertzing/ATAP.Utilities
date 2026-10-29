function Initialize-DownstreamSprintFromSharedVSCode {
  <#
  .SYNOPSIS
    Points downstream workspace files at a SharedVSCode sprint worktree and
    applies the resulting context to the local Git repo.
  .DESCRIPTION
    Combines Set-WorkspaceSharedVSCodeReference and
    Set-DownstreamSharedVSCodeContext into a single workflow call. Pins the complete
    compatible workspace group before updating references. On refusal, restores
    only verified own reference postimages. Peer or uncertain writer state is held
    for recovery; the wrapper never restores writer-owned generated/config files.
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER TemplateRef
    The SharedVSCode sprint worktree name
    (e.g. "SharedVSCode-wt-5-sprint-0003-work-items").
  .PARAMETER ProfileName
    Optional profile label. Defaults to "default". Exposed under the alias
    'Profile' for backward compatibility; the parameter is named ProfileName so
    it does not shadow the automatic $PROFILE variable.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder.
  .PARAMETER SharedHooksSubPath
    Relative path under SharedVSCode root where hooks live.
  .PARAMETER CommitTemplateRelativePath
    Relative path under SharedVSCode root for the commit template.
  .EXAMPLE
    Initialize-DownstreamSprintFromSharedVSCode `
      -WorkspaceFiles @('.\Planning.code-workspace') `
      -TemplateRef 'SharedVSCode-wt-5-sprint-0003-work-items' `
      -ProfileName 'sprint-0003'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateRef,

    [Alias('Profile')]
    [string]$ProfileName = 'default',
    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    function workspaceBytes([string]$Path) {
      $item = [IO.FileInfo]::new($Path)
      if ($item.LinkTarget -or !$item.Exists) { throw 'SharedVSCodeInitialize.WorkspacePathChanged' }
      for ($parent = $item.Directory; $null -ne $parent; $parent = $parent.Parent) {
        if ($parent.LinkTarget) { throw 'SharedVSCodeInitialize.RedirectedWorkspace' }
      }
      return ,([IO.File]::ReadAllBytes($Path))
    }
    function sameWorkspaceBytes([byte[]]$Left, [byte[]]$Right) {
      return [Linq.Enumerable]::SequenceEqual($Left, $Right)
    }
    function heldWorkspaceRecovery([string]$Reason, $Failure, [string[]]$Paths) {
      $recoveryException = [InvalidOperationException]::new(('SharedVSCodeInitialize.HeldRecovery: ' + $Reason), $Failure.Exception)
      $recoveryException.Data['WorkspaceFiles'] = $Paths -join ';'
      throw $recoveryException
    }
    $group = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $root = $null
    $originalContext = $null
    foreach ($file in $WorkspaceFiles) {
      $resolved = Resolve-Path -LiteralPath $file -ErrorAction Stop
      if ($resolved.Provider.Name -ne 'FileSystem') { throw 'SharedVSCodeInitialize.InvalidWorkspacePath' }
      $path = $resolved.ProviderPath
      if ($path -match '[*?\[\]]' -or [IO.Path]::GetExtension($path) -ine '.code-workspace') { throw 'SharedVSCodeInitialize.InvalidWorkspacePath' }
      if (!$seen.Add($path)) { continue }
      $parent = [IO.Path]::GetDirectoryName($path)
      if ($null -eq $root) { $root = $parent }
      elseif (![string]::Equals($root, $parent, [StringComparison]::OrdinalIgnoreCase)) { throw 'SharedVSCodeInitialize.WorkspaceConflict' }
      $before = workspaceBytes $path
      $text = [Text.UTF8Encoding]::new($false, $true).GetString($before).TrimStart([char]0xFEFF)
      $json = ConvertFrom-Json -InputObject $text -ErrorAction Stop
      if ($null -eq $json -or $json -isnot [pscustomobject]) { throw 'SharedVSCodeInitialize.InvalidWorkspaceJson' }
      if ($null -eq $json.PSObject.Properties['settings']) { $json | Add-Member -Name settings -Value ([pscustomobject]@{}) -MemberType NoteProperty }
      if ($json.settings -isnot [pscustomobject]) { throw 'SharedVSCodeInitialize.InvalidWorkspaceSettings' }
      $oldRef = $json.settings.'atap.sharedVSCode.templateRef'
      $oldProfile = $json.settings.'atap.sharedVSCode.profile'
      if (($null -ne $oldRef -and $oldRef -isnot [string]) -or ($null -ne $oldProfile -and $oldProfile -isnot [string])) { throw 'SharedVSCodeInitialize.InvalidWorkspaceSettings' }
      $context = ConvertTo-Json -InputObject @($oldRef, $(if ([string]::IsNullOrWhiteSpace($oldProfile)) { 'default' } else { $oldProfile })) -Compress
      if ($null -eq $originalContext) { $originalContext = $context }
      elseif ($context -cne $originalContext) { throw 'SharedVSCodeInitialize.WorkspaceConflict' }
      $json.settings | Add-Member -Name 'atap.sharedVSCode.templateRef' -Value $TemplateRef -MemberType NoteProperty -Force
      $json.settings | Add-Member -Name 'atap.sharedVSCode.profile' -Value $ProfileName -MemberType NoteProperty -Force
      # Match existing Save-WorkspaceJson's UTF8/Depth20/Set-Content contract.
      # Predict ownership BEFORE effects; a freshly observed peer write is not
      # accepted as our postimage just because the helper returned successfully.
      $rendered = ConvertTo-Json -InputObject $json -Depth 20 -WarningAction Stop
      $expected = [Text.UTF8Encoding]::new($false).GetBytes($rendered + [Environment]::NewLine)
      $group.Add([pscustomobject]@{ Path = $path; Before = $before; Expected = $expected; Attempted = $false })
    }
    if (!$group.Count) { throw 'SharedVSCodeInitialize.EmptyWorkspaceGroup' }
    foreach ($item in $group) {
      if (!(sameWorkspaceBytes (workspaceBytes $item.Path) $item.Before)) { throw 'SharedVSCodeInitialize.ObservationChanged' }
    }
    try {
      foreach ($item in $group) {
        if (!(sameWorkspaceBytes (workspaceBytes $item.Path) $item.Before)) { throw 'SharedVSCodeInitialize.ObservationChanged' }
        $item.Attempted = $true
        Set-WorkspaceSharedVSCodeReference -WorkspaceFiles @($item.Path) -TemplateRef $TemplateRef -Profile $ProfileName -ErrorAction Stop
        if (!(sameWorkspaceBytes (workspaceBytes $item.Path) $item.Expected)) { throw 'SharedVSCodeInitialize.UnexpectedPostimage' }
      }
      foreach ($item in $group) {
        if (!(sameWorkspaceBytes (workspaceBytes $item.Path) $item.Expected)) { throw 'SharedVSCodeInitialize.ObservationChanged' }
      }
      Set-DownstreamSharedVSCodeContext `
        -WorkspaceFiles @($group.Path) `
        -GitRoot $GitRoot `
        -SharedVSCodeRepoName $SharedVSCodeRepoName `
        -SharedHooksSubPath $SharedHooksSubPath `
        -CommitTemplateRelativePath $CommitTemplateRelativePath `
        -ErrorAction Stop
    } catch {
      $failure = $_
      try { Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Context application failed; checking workspace recovery ownership' } catch { }
      # Writer23 owns its own outputs. If it holds uncertain output recovery,
      # do not retarget workspace references independently of those outputs.
      for ($cause = $failure.Exception; $null -ne $cause; $cause = $cause.InnerException) {
        if ($cause.Message.Contains('SharedVSCodeWriter.HeldRecovery', [StringComparison]::Ordinal)) {
          heldWorkspaceRecovery 'WriterHeldRecovery' $failure @($group.Path)
        }
      }
      $diverged = [Collections.Generic.List[string]]::new()
      foreach ($item in $group) {
        try {
          $current = workspaceBytes $item.Path
          if (!(sameWorkspaceBytes $current $item.Before) -and
            !($item.Attempted -and (sameWorkspaceBytes $current $item.Expected))) { $diverged.Add($item.Path) }
        } catch { $diverged.Add($item.Path) }
      }
      if ($diverged.Count) { heldWorkspaceRecovery 'WorkspaceDiverged' $failure $diverged.ToArray() }
      try {
        for ($index = $group.Count - 1; $index -ge 0; $index--) {
          $item = $group[$index]
          $current = workspaceBytes $item.Path
          if (sameWorkspaceBytes $current $item.Before) { continue }
          if (!$item.Attempted -or !(sameWorkspaceBytes $current $item.Expected)) { throw 'WorkspaceChangedDuringRecovery' }
          [IO.File]::WriteAllBytes($item.Path, $item.Before)
          if (!(sameWorkspaceBytes (workspaceBytes $item.Path) $item.Before)) { throw 'WorkspaceRestoreMismatch' }
        }
      } catch { heldWorkspaceRecovery 'RestoreFailed' $_ @($group.Path) }
      throw $failure
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
