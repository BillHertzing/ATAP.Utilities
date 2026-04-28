function Initialize-DownstreamSprintFromSharedVSCode {
  <#
  .SYNOPSIS
    Points downstream workspace files at a SharedVSCode sprint worktree and
    applies the resulting context to the local Git repo.
  .DESCRIPTION
    Combines Set-WorkspaceSharedVSCodeReference and
    Set-DownstreamSharedVSCodeContext into a single workflow call.
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER TemplateRef
    The SharedVSCode sprint worktree name
    (e.g. "SharedVSCode-wt-5-sprint-0003-work-items").
  .PARAMETER Profile
    Optional profile label. Defaults to "default".
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
      -Profile 'sprint-0003'
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateRef,

    [string]$Profile = 'default',
    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )

  Set-WorkspaceSharedVSCodeReference `
    -WorkspaceFiles $WorkspaceFiles `
    -TemplateRef $TemplateRef `
    -Profile $Profile

  Set-DownstreamSharedVSCodeContext `
    -WorkspaceFiles $WorkspaceFiles `
    -GitRoot $GitRoot `
    -SharedVSCodeRepoName $SharedVSCodeRepoName `
    -SharedHooksSubPath $SharedHooksSubPath `
    -CommitTemplateRelativePath $CommitTemplateRelativePath
}
