function Reset-DownstreamToSharedVSCodeMain {
  <#
  .SYNOPSIS
    Resets downstream workspace files back to SharedVSCode main and re-applies context.
  .DESCRIPTION
    Sets templateRef to "main" and profile to "default" in all workspace files,
    then re-applies the SharedVSCode context so local Git plumbing points at
    the SharedVSCode main worktree.

    Per-sprint ProGet feed cleanup was removed in Sprint 0007 (task B08): the
    permanent-feed topology eliminates the per-sprint nuget-Sprint<NNNN>-* feeds
    that the previous Remove-SprintProGetFeeds private helper targeted.
  .PARAMETER WorkspaceFiles
    One or more paths to .code-workspace files.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER SharedVSCodeRepoName
    Name of the SharedVSCode repository folder.
  .PARAMETER SharedHooksSubPath
    Relative path under SharedVSCode root where hooks live.
  .PARAMETER CommitTemplateRelativePath
    Relative path under SharedVSCode root for the commit template.
  .EXAMPLE
    Reset-DownstreamToSharedVSCodeMain -WorkspaceFiles @('.\Planning.code-workspace')
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceFiles,

    [string]$GitRoot = 'C:\dropbox\whertzing\GitHub',
    [string]$SharedVSCodeRepoName = 'SharedVSCode',
    [string]$SharedHooksSubPath = '.githooks',
    [string]$CommitTemplateRelativePath = 'GitTemplates\git.commit.template.txt'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.AiRendering.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    Set-WorkspaceSharedVSCodeReference `
      -WorkspaceFiles $WorkspaceFiles `
      -TemplateRef 'main' `
      -Profile 'default'

    Set-DownstreamSharedVSCodeContext `
      -WorkspaceFiles $WorkspaceFiles `
      -GitRoot $GitRoot `
      -SharedVSCodeRepoName $SharedVSCodeRepoName `
      -SharedHooksSubPath $SharedHooksSubPath `
      -CommitTemplateRelativePath $CommitTemplateRelativePath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
